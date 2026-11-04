import AppKit
import Foundation

/// All state of the lens window. Main thread only.
final class LensModel: ObservableObject {
    enum CaptureState: Equatable { case starting, running, needsPermission, failed(String) }

    let library: MonitorLibrary
    private let defaults: UserDefaults

    static let repoURL = "https://github.com/tilb/crappy-monitor"

    // MARK: Published state

    @Published var activeID: String {
        didSet {
            guard activeID != oldValue else { return }
            edits = MonitorFilter.Edits()
            defaults.set(activeID, forKey: "lens.activeID")
        }
    }
    @Published var favourites: [String] {
        didSet { defaults.set(favourites, forKey: "lens.favourites") }
    }
    @Published var age: MonitorAge {
        didSet { defaults.set(age.rawValue, forKey: "lens.age") }
    }
    /// Adjust edits for the active monitor; reset when another monitor becomes active.
    @Published var edits = MonitorFilter.Edits()
    @Published var stillThumbnails: Bool {
        didSet { defaults.set(stillThumbnails, forKey: "lens.stillThumbnails") }
    }

    @Published var previewID: String?      // only used by the debug snapshot tour
    @Published var stripVisible = true
    @Published var optionHeld = false      // hold ⌥ to compare; set by the window controller

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

    /// Set by the window controller; the "Try Again" button calls it.
    var retryCapture: (() -> Void)?

    init(library: MonitorLibrary, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults

        let ids = library.monitors.map(\.id)
        let savedActive = defaults.string(forKey: "lens.activeID")
        activeID = savedActive.flatMap { ids.contains($0) ? $0 : nil }
            ?? library.firstRunDefault?.id ?? ""
        let savedFavs = defaults.stringArray(forKey: "lens.favourites")
            ?? Array(ids.dropFirst().prefix(4))     // research ranks 2–5
        favourites = savedFavs.filter { ids.contains($0) }
        age = MonitorAge(rawValue: defaults.object(forKey: "lens.age") as? Int ?? 6) ?? .six
        stillThumbnails = defaults.bool(forKey: "lens.stillThumbnails")
    }

    // MARK: Monitors

    var monitors: [MonitorProfile] { library.monitors }
    func monitor(_ id: String?) -> MonitorProfile? { library.monitor(id) }
    var active: MonitorProfile? { monitor(activeID) }
    func name(_ id: String?) -> String { monitor(id)?.displayName ?? "—" }

    var isEdited: Bool { !edits.isEmpty }

    /// Profile + age, plus Adjust edits for the active monitor only.
    func filter(for id: String) -> MonitorFilter? {
        guard let p = monitor(id) else { return nil }
        return MonitorFilter(profile: p, age: age, edits: id == activeID ? edits : MonitorFilter.Edits())
    }
    var activeFilter: MonitorFilter? { filter(for: activeID) }

    /// What the big lens shows right now.
    var lensFilter: MonitorFilter? { filter(for: previewID ?? activeID) }
    var showsOriginal: Bool { optionHeld }

    func use(_ id: String) {
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

    // MARK: Hover (no preview: the lens changes on click only, decided 2026-11-02)

    func hoverBegan(_ id: String, key: String) { hoveredKey = key }

    func hoverEnded(key: String) {
        if hoveredKey == key { hoveredKey = nil }
    }

    func leftStrip() {
        hoveredKey = nil
        previewID = nil
    }

    // MARK: Info (D4)

    func showInfo() {
        infoKey = hoveredKey ?? "last:\(activeID)"
    }

    // MARK: Search (D3)

    struct SearchResults {
        var favourites: [MonitorProfile]
        var others: [MonitorProfile]
        var hiddenCount: Int
        var flat: [String] { favourites.map(\.id) + others.map(\.id) }
    }

    var query: String { searchText.trimmingCharacters(in: .whitespaces).lowercased() }

    private func matches(_ p: MonitorProfile) -> Bool {
        let q = query
        return q.isEmpty || p.displayName.lowercased().contains(q)
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
