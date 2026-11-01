import AppKit
import Combine
import Foundation

// LENS PROTOTYPE — throwaway.

/// All state of the lens window. Main thread only.
final class LensModel: ObservableObject {
    enum Mode: Int { case lens = 0, wholeScreen = 1 }
    enum CaptureState: Equatable { case starting, running, needsPermission, failed(String) }

    let presetsStore: PresetsStore
    let filterSettings: FilterSettings
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var hoverWork: DispatchWorkItem?

    static let repoURL = "https://github.com/tilb/crappy-monitor"

    // MARK: Published state

    @Published var mode: Mode = .lens {
        didSet { if mode != oldValue { applyGammaForMode() } }
    }
    @Published var activeID: String {
        didSet {
            guard activeID != oldValue else { return }
            overrides = LensOverrides()
            defaults.set(activeID, forKey: "lens.activeID")
            pushWholeScreen()
        }
    }
    @Published var favourites: [String] {
        didSet { defaults.set(favourites, forKey: "lens.favourites") }
    }
    @Published var age: MonitorAge {
        didSet { defaults.set(age.rawValue, forKey: "lens.age"); pushWholeScreen() }
    }
    @Published var overrides = LensOverrides() {
        didSet { pushWholeScreen() }
    }
    @Published var stillThumbnails: Bool {
        didSet { defaults.set(stillThumbnails, forKey: "lens.stillThumbnails") }
    }

    @Published var previewID: String?
    @Published var followPointer = false   // H3: off by default (decided 2026-11-01)
    @Published var stripVisible = true
    @Published var optionHeld = false

    @Published var searchText = ""
    @Published var resultsVisible = false
    @Published var browseAll = false       // "More…" opens the results list empty
    @Published var searchSelection = 0
    @Published var showAllResults = false

    @Published var infoKey: String?        // "slot:id" of the tile whose info popover is open
    @Published var hoveredKey: String?
    @Published var adjustShown = false

    @Published var captureState: CaptureState = .starting
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var displayName = ""        // display the window is on (Whole Screen subtitle)

    /// Set by the window controller; the "Try Again" button calls it.
    var retryCapture: (() -> Void)?

    init(presetsStore: PresetsStore, filterSettings: FilterSettings, defaults: UserDefaults = .standard) {
        self.presetsStore = presetsStore
        self.filterSettings = filterSettings
        self.defaults = defaults

        let monitorIDs = presetsStore.presets.filter { $0.panelType != nil }.map(\.id)
        let savedActive = defaults.string(forKey: "lens.activeID")
        activeID = savedActive.flatMap { monitorIDs.contains($0) ? $0 : nil }
            ?? (monitorIDs.contains("dell-p2419h") ? "dell-p2419h" : monitorIDs.first ?? "")
        let savedFavs = defaults.stringArray(forKey: "lens.favourites")
            ?? ["hp-e24-g4", "philips-241v8", "lenovo-thinkvision-t23i", "samsung-s24f350"]
        favourites = savedFavs.filter { monitorIDs.contains($0) }
        age = MonitorAge(rawValue: defaults.object(forKey: "lens.age") as? Int ?? 6) ?? .six
        stillThumbnails = defaults.bool(forKey: "lens.stillThumbnails")

        filterSettings.$isABActive
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.optionHeld = $0 }
            .store(in: &cancellables)
    }

    // MARK: Monitors

    var monitors: [DegradationPreset] { presetsStore.presets.filter { $0.panelType != nil } }
    func monitor(_ id: String?) -> DegradationPreset? { monitors.first { $0.id == id } }
    var active: DegradationPreset? { monitor(activeID) }
    func name(_ id: String?) -> String { monitor(id)?.displayName ?? "—" }

    var isEdited: Bool { !overrides.isEmpty }

    /// Spec profile + age, plus Adjust edits for the active monitor only.
    func params(for id: String) -> LensParams {
        guard let preset = monitor(id) else { return LensParams() }
        let base = LensParams(preset: preset).aged(age)
        return id == activeID ? overrides.applied(to: base) : base
    }
    var activeParams: LensParams { params(for: activeID) }

    /// What the big lens shows right now: hovered preview wins over the active monitor.
    var lensParams: LensParams { params(for: previewID ?? activeID) }
    var showsOriginal: Bool { optionHeld }

    func use(_ id: String) {
        cancelHover()
        previewID = nil
        activeID = id
    }

    // MARK: Favourites

    func isFavourite(_ id: String) -> Bool { favourites.contains(id) }
    func addFavourite(_ id: String) { if !isFavourite(id) { favourites.append(id) } }
    func removeFavourite(_ id: String) { favourites.removeAll { $0 == id } }
    func move(_ id: String, by delta: Int) {
        guard let i = favourites.firstIndex(of: id) else { return }
        let j = i + delta
        guard favourites.indices.contains(j) else { return }
        favourites.swapAt(i, j)
    }
    func useFavourite(at index: Int) {
        guard favourites.indices.contains(index) else { return }
        use(favourites[index])
    }

    // MARK: Hover preview (D2)

    func hoverBegan(_ id: String, key: String) {
        hoveredKey = key
        cancelHover()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.previewID = (id == self.activeID) ? nil : id
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func hoverEnded(key: String) {
        if hoveredKey == key { hoveredKey = nil }
        cancelHover()   // keep the current preview until the pointer leaves the strip
    }

    func leftStrip() {
        cancelHover()
        hoveredKey = nil
        previewID = nil
    }

    private func cancelHover() { hoverWork?.cancel(); hoverWork = nil }

    // MARK: Info (D4)

    func showInfo() {
        infoKey = hoveredKey ?? "last:\(activeID)"
    }

    // MARK: Search (D3)

    struct SearchResults {
        var favourites: [DegradationPreset]
        var others: [DegradationPreset]
        var hiddenCount: Int
        var flat: [String] { favourites.map(\.id) + others.map(\.id) }
    }

    var query: String { searchText.trimmingCharacters(in: .whitespaces).lowercased() }

    private func matches(_ p: DegradationPreset) -> Bool {
        let q = query
        return q.isEmpty || p.displayName.lowercased().contains(q) || p.name.lowercased().contains(q)
    }

    func searchResults() -> SearchResults {
        let favs = favourites.compactMap { monitor($0) }.filter(matches)
        let others = monitors.filter { !isFavourite($0.id) && matches($0) }
            .sorted { $0.displayName < $1.displayName }
        let limit = (showAllResults || browseAll) ? others.count : 4
        return SearchResults(favourites: favs,
                             others: Array(others.prefix(limit)),
                             hiddenCount: max(0, others.count - limit))
    }

    /// Favourites shown in the strip, filtered while searching.
    var stripFavourites: [String] {
        query.isEmpty ? favourites : favourites.filter { monitor($0).map(matches) ?? false }
    }

    func moveSearchSelection(_ delta: Int) {
        let count = searchResults().flat.count
        guard count > 0 else { return }
        searchSelection = (searchSelection + delta + count) % count
    }

    func useSearchSelection() {
        let flat = searchResults().flat
        guard flat.indices.contains(searchSelection) else { return }
        use(flat[searchSelection])
        clearSearch()
    }

    func clearSearch() {
        searchText = ""
        browseAll = false
        showAllResults = false
        searchSelection = 0
        resultsVisible = false
    }

    func openBrowseAll() {
        browseAll = true
        searchSelection = 0
        resultsVisible = true
    }

    // MARK: Whole Screen (existing gamma pipeline)

    func applyGammaForMode() {
        switch mode {
        case .lens:
            // The lens captures the clean framebuffer; display gamma must be off
            // or the user sees the screen degraded twice.
            filterSettings.isEnabled = false
            previewID = nil
        case .wholeScreen:
            pushWholeScreen()
        }
    }

    private func pushWholeScreen() {
        guard mode == .wholeScreen, let preset = active else { return }
        preset.apply(to: filterSettings)          // sets activePresetID for the control panel
        activeParams.write(to: filterSettings)    // age + Adjust edits on top
        filterSettings.isEnabled = true
    }

    // MARK: Links

    func reportURL(for id: String) -> URL {
        issueURL(title: "Profile looks wrong: \(name(id))",
                 body: "Monitor: \(name(id)) (`\(id)`)\nAge setting: \(age.label)\n\nWhat looks wrong:\n")
    }

    func requestURL() -> URL {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return issueURL(title: "Monitor request: \(q.isEmpty ? "<brand model>" : q)",
                        body: "Brand and model:\nWhere it is common (optional):\n")
    }

    private func issueURL(title: String, body: String) -> URL {
        var c = URLComponents(string: Self.repoURL + "/issues/new")!
        c.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "body", value: body)]
        return c.url!
    }
}
