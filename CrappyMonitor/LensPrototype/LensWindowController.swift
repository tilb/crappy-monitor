import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

private extension NSToolbarItem.Identifier {
    static let strip = Self("lens.strip")
    static let search = Self("lens.search")
}

/// The lens window (HANDOFF D1, D3–D5; PRD §5). The app is a regular app whose one
/// window is this lens.
final class LensWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate,
                                  NSSearchFieldDelegate, NSMenuDelegate, NSMenuItemValidation {
    let model: LensModel

    private let capture = ScreenCapture()
    private let geometry = LensGeometry()
    private let renderer = LensRenderer()
    private var thumbnailsBusy = false
    private let hotKeys = HotKeys()
    private var cancellables = Set<AnyCancellable>()
    private var thumbTimer: Timer?
    private var optionMonitors: [Any] = []
    private var outsideClickMonitor: Any?
    private var expandedFrame: NSRect?
    private var isCompact = false
    private var askedForPermission = false
    private var chromeUpdatePending = false
    private var lastPointerInLens: CGPoint?

    private var stripButton = NSButton()
    private var searchItem: NSSearchToolbarItem?
    private var resultsPanel: ResultsPanel?
    private var resultsHost: NSHostingView<SearchResultsView>?
    private let favouritesMenu = NSMenu(title: "Monitor")

    init(library: MonitorLibrary) {
        model = LensModel(library: library)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 678),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 400, height: 170)
        // A lens floats over the app you are looking at, like Sim Daltonism.
        window.level = .floating
        // Over full-screen apps and along to the active Space (PRD R6); never its own
        // full-screen Space, so the green button zooms (PRD 6.1A). Verified by the spike.
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.setFrameAutosaveName("LensPrototypeWindow")
        super.init(window: window)

        window.delegate = self
        geometry.renderer = renderer
        let host = NSHostingView(rootView: LensRootView(model: model, capture: capture, geometry: geometry))
        host.sizingOptions = []   // the controller owns the window size
        window.contentView = host
        setupToolbar()
        bind()

        model.retryCapture = { [weak self] in self?.startCapture() }
        capture.onStop = { [weak self] _ in
            guard let self else { return }
            // A display that went away is fine: cover what is left. Anything else is shown.
            guard ScreenCapture.hasPermission else { self.model.captureState = .needsPermission; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.updateCapture() }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    #if DEBUG
    var lensViewForSnapshot: LensMTKView? { geometry.view }
    #endif

    // MARK: - Open / close

    func show() {
        if NSApp.mainMenu?.items.count ?? 0 < 2 { installMainMenu() }
        registerHotKeys()
        watchOptionKey()
        if window?.isVisible != true, !(window?.setFrameUsingName("LensPrototypeWindow") ?? false) {
            window?.center()
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startCaptureIfAllowed()
        restartThumbTimer()
        #if SANDBOX_SPIKE
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.runSandboxChecks(nil) }
        #endif
    }

    func windowWillClose(_ notification: Notification) {
        thumbTimer?.invalidate()
        hideResults()
        optionMonitors.forEach(NSEvent.removeMonitor)
        optionMonitors.removeAll()
        let capture = self.capture
        Task { await capture.stop() }
    }

    /// Hold ⌥ to see the original (global and local, like v1's A/B compare).
    private func watchOptionKey() {
        guard optionMonitors.isEmpty else { return }
        let update: (NSEvent) -> Void = { [weak self] e in
            let held = e.modifierFlags.contains(.option)
            if self?.model.optionHeld != held { self?.model.optionHeld = held }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: update) { optionMonitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { update($0); return $0 }) {
            optionMonitors.append(m)
        }
    }

    // MARK: - Capture

    private func startCaptureIfAllowed() {
        guard ScreenCapture.hasPermission else {
            if !askedForPermission {
                askedForPermission = true
                CGRequestScreenCaptureAccess()   // system prompt, once
            }
            model.captureState = .needsPermission
            return
        }
        startCapture()
    }

    private func startCapture() {
        model.captureState = .starting
        updateCapture()
    }

    /// The rect the capture must cover: the lens, or the whole window before it has a lens.
    private var lensRect: CGRect? { geometry.view?.rectOnScreen ?? window?.frame }

    /// Starts streams for the displays under the lens and stops the others (PRD §6, Vraag 9).
    /// Called on start and whenever the window moves, resizes or the displays change.
    private func updateCapture() {
        guard model.captureState == .running || model.captureState == .starting,
              let rect = lensRect else { return }
        Task { @MainActor in
            do {
                try await capture.cover(rect)
                if model.captureState != .running {
                    model.captureState = .running
                    renderThumbnails(force: true)
                }
            } catch {
                model.captureState = ScreenCapture.hasPermission
                    ? .failed(error.localizedDescription)
                    : .needsPermission
            }
        }
    }

    func windowDidMove(_ notification: Notification) { updateCapture() }
    func windowDidResize(_ notification: Notification) { updateCapture() }
    func windowDidChangeScreen(_ notification: Notification) { updateCapture() }

    @objc private func screensDidChange() {
        // Display frames may have moved: restart every stream with the new geometry.
        guard model.captureState == .running else { return }
        Task { @MainActor in
            await capture.stop()
            updateCapture()
        }
    }

    @objc private func appDidBecomeActive() {
        if model.captureState == .needsPermission, ScreenCapture.hasPermission { startCapture() }
    }

    // MARK: - State → window

    private func bind() {
        model.objectWillChange
            .sink { [weak self] in self?.scheduleChromeUpdate() }
            .store(in: &cancellables)

        // @Published emits on willSet, so hop to the next runloop turn to read new values.
        model.$stripVisible.dropFirst().removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.layoutForState()
                self?.updateCapture()   // the lens grows or shrinks inside the window
                self?.renderThumbnails(force: true)
            }
            .store(in: &cancellables)
        model.$resultsVisible.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in $0 ? self?.showResults() : self?.hideResults() }
            .store(in: &cancellables)
        model.$stillThumbnails.dropFirst().removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restartThumbTimer() }
            .store(in: &cancellables)
        Publishers.Merge4(model.$age.map { _ in () }, model.$favourites.map { _ in () },
                          model.$activeID.map { _ in () }, model.$edits.map { _ in () })
            .dropFirst(4)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.renderThumbnails(force: true) }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensDidChange),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func scheduleChromeUpdate() {
        guard !chromeUpdatePending else { return }
        chromeUpdatePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.chromeUpdatePending = false
            self.updateChrome()
        }
    }

    private func updateChrome() {
        guard let window else { return }
        stripButton.state = model.stripVisible ? .on : .off
        if let field = searchItem?.searchField, field.stringValue != model.searchText {
            field.stringValue = model.searchText
        }

        let name = model.name(model.activeID)
        // D5 has no title: in 440 pt it would push the buttons into the » menu.
        window.titleVisibility = model.stripVisible ? .visible : .hidden
        if model.optionHeld {
            window.title = "Original"
            window.subtitle = "Release ⌥ to return to \(name)"
        } else {
            window.title = model.isEdited ? "\(name) — Edited" : name
            window.subtitle = ""
        }
        if model.resultsVisible { positionResults() }
    }

    /// D5 uses a small window; the strip layout gets its old size back.
    private func layoutForState() {
        guard let window else { return }
        syncToolbarItems()
        let compact = !model.stripVisible
        if compact {
            if !isCompact { expandedFrame = window.frame }
            let size = NSSize(width: 440, height: 330)
            let f = window.frame
            window.setFrame(NSRect(x: f.minX, y: f.maxY - size.height, width: size.width, height: size.height),
                            display: true, animate: true)
        } else if let f = expandedFrame {
            let top = window.frame.maxY
            window.setFrame(NSRect(x: window.frame.minX, y: top - f.height, width: f.width, height: f.height),
                            display: true, animate: true)
            expandedFrame = nil
        }
        isCompact = compact
    }

    /// D5 shows only the strip toggle and no search; otherwise a narrow window pushes the
    /// buttons into the » overflow menu.
    private func syncToolbarItems() {
        guard let toolbar = window?.toolbar else { return }
        let wanted: [NSToolbarItem.Identifier]
        if model.stripVisible {
            wanted = toolbarDefaultItemIdentifiers(toolbar)
        } else {
            wanted = [.flexibleSpace, .strip]
        }
        guard toolbar.items.map(\.itemIdentifier) != wanted else { return }
        while !toolbar.items.isEmpty { toolbar.removeItem(at: 0) }
        for (i, id) in wanted.enumerated() { toolbar.insertItem(withItemIdentifier: id, at: i) }
        if !wanted.contains(.search) { searchItem = nil }
        updateChrome()
    }

    func windowDidResignKey(_ notification: Notification) {
        model.resultsVisible = false
    }

    // MARK: - Thumbnails (H4)

    private func restartThumbTimer() {
        thumbTimer?.invalidate()
        let interval = model.stillThumbnails ? 3.0 : 0.5
        thumbTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.renderThumbnails()
        }
        renderThumbnails(force: true)
    }

    private func renderThumbnails(force: Bool = false) {
        guard model.stripVisible, let window, window.isVisible,
              force || window.isKeyWindow,
              let lens = geometry.view?.rectOnScreen else { return }

        let pointer = NSEvent.mouseLocation
        if lens.contains(pointer) { lastPointerInLens = pointer }
        let center = lastPointerInLens.flatMap { lens.contains($0) ? $0 : nil } ?? CGPoint(x: lens.midX, y: lens.midY)

        var ids = [model.activeID]
        for id in model.favourites where !ids.contains(id) { ids.append(id) }
        let jobs = ids.compactMap { id in model.filter(for: id).map { (id: id, filter: $0) } }
        // The display under the crop centre; the crop stays inside that display.
        let frames = capture.frames
        guard !thumbnailsBusy, let renderer,
              let frame = frames.first(where: { $0.displayFrame.contains(center) }) ?? frames.first,
              let source = renderer.source(for: frame.buffer) else { return }

        // A 1:1 crop of the display around the pointer (or the lens centre), drawn by the
        // same shader as the lens, one offscreen pass per tile (PRD §6).
        let ppp = frame.pixelsPerPoint
        let w = Int(LensModel.thumbnailSize.width * ppp), h = Int(LensModel.thumbnailSize.height * ppp)
        let bufW = Double(CVPixelBufferGetWidth(frame.buffer)), bufH = Double(CVPixelBufferGetHeight(frame.buffer))
        let cx = (center.x - frame.displayFrame.minX) * ppp, cy = (frame.displayFrame.maxY - center.y) * ppp
        let origin = SIMD2(Float(min(max(cx - Double(w) / 2, 0), max(bufW - Double(w), 0)).rounded()),
                           Float(min(max(cy - Double(h) / 2, 0), max(bufH - Double(h), 0)).rounded()))
        let original = model.showsOriginal
        let block = Int(max(1, ppp.rounded()))
        let part = LensRenderer.Part(source: source, region: RenderRegion(origin: origin), nonRetinaBlock: block)
        let renderJobs = jobs.map {
            LensRenderer.Job(parts: [part], width: w, height: h, filter: $0.filter, original: original)
        }
        thumbnailsBusy = true
        renderer.render(renderJobs) { [weak self] images in
            guard let self else { return }
            self.thumbnailsBusy = false
            var out: [String: NSImage] = [:]
            for (job, image) in zip(jobs, images) {
                if let image { out[job.id] = NSImage(cgImage: image, size: LensModel.thumbnailSize) }
            }
            self.model.thumbnails.merge(out) { $1 }
        }
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "LensPrototypeToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .strip, .search]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case .strip:
            stripButton = toggleButton("rectangle.bottomthird.inset.filled", "Show Strip", #selector(toggleStrip(_:)))
            stripButton.toolTip = "Show or Hide Strip (⌥⌘S)"
            stripButton.state = .on
            let item = NSToolbarItem(itemIdentifier: id)
            item.view = stripButton
            item.label = "Strip"
            return item
        case .search:
            let item = NSSearchToolbarItem(itemIdentifier: id)
            item.searchField.placeholderString = "Search brand or model"
            item.searchField.delegate = self
            item.searchField.sendsSearchStringImmediately = true
            item.preferredWidthForSearchField = 220
            searchItem = item
            return item
        default:
            return nil
        }
    }

    private func symbol(_ name: String, _ description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    private func toggleButton(_ symbolName: String, _ label: String, _ action: Selector) -> NSButton {
        let b = NSButton(image: symbol(symbolName, label) ?? NSImage(), target: self, action: action)
        b.setButtonType(.pushOnPushOff)
        b.bezelStyle = .texturedRounded
        b.setAccessibilityLabel(label)
        return b
    }

    // MARK: - Actions

    @objc func showLens(_ sender: Any?) {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func toggleStrip(_ sender: Any?) { model.stripVisible.toggle() }
    @objc func toggleAdjust(_ sender: Any?) { model.adjustShown.toggle() }
    @objc func showInfo(_ sender: Any?) {
        guard model.stripVisible else { return }
        model.showInfo()
    }
    @objc func focusSearch(_ sender: Any?) {
        if !model.stripVisible { model.stripVisible = true }   // search lives in the full layout
        DispatchQueue.main.async { [weak self] in
            guard let item = self?.searchItem else { return }
            item.beginSearchInteraction()
            self?.window?.makeFirstResponder(item.searchField)
        }
    }
    @objc func useFavourite(_ sender: NSMenuItem) { model.useFavourite(at: sender.tag) }
    @objc func toggleStillThumbnails(_ sender: Any?) { model.stillThumbnails.toggle() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleStrip(_:)):
            item.title = model.stripVisible ? "Hide Strip" : "Show Strip"
        case #selector(toggleStillThumbnails(_:)): item.state = model.stillThumbnails ? .on : .off
        case #selector(useFavourite(_:)): item.state = model.favourites[safe: item.tag] == model.activeID ? .on : .off
        default: break
        }
        return true
    }

    // MARK: - Shortcuts

    private func registerHotKeys() {
        hotKeys.unregisterAll()
        hotKeys.register(kVK_ANSI_L) { [weak self] in self?.showLens(nil) }
    }

    private func installMainMenu() {
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem], delegate: NSMenuDelegate? = nil, menu: NSMenu? = nil) {
            let m = menu ?? NSMenu(title: title)
            m.removeAllItems()
            items.forEach(m.addItem)
            m.delegate = delegate
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            top.submenu = m
            main.addItem(top)
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.target = target
            return i
        }

        add("Crappy Monitor", [
            item("About Crappy Monitor", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp),
            .separator(),
            item("Hide Crappy Monitor", #selector(NSApplication.hide(_:)), "h", target: NSApp),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option], target: NSApp),
            .separator(),
            item("Quit Crappy Monitor", #selector(NSApplication.terminate(_:)), "q", target: NSApp),
        ])
        add("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ])
        add("View", [
            item("Show Lens", #selector(showLens(_:)), "l", [.control, .command], target: self),
            .separator(),
            item("Hide Strip", #selector(toggleStrip(_:)), "s", [.command, .option], target: self),
        ])
        add("Monitor", [], delegate: self, menu: favouritesMenu)
        rebuildMonitorMenu()
        add("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
        ])
        add("Debug", [
            item("Still Thumbnails (Every 3 s)", #selector(toggleStillThumbnails(_:)), target: self),
            .separator(),
            item("Run Sandbox Checks", #selector(runSandboxChecks(_:)), target: self),
        ])
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === favouritesMenu { rebuildMonitorMenu() }
    }

    private func rebuildMonitorMenu() {
        let m = favouritesMenu
        m.removeAllItems()
        func add(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags = .command) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.target = self
            m.addItem(i)
        }
        add("Search…", #selector(focusSearch(_:)), "f")
        add("Show Info", #selector(showInfo(_:)), "i")
        add("Adjust…", #selector(toggleAdjust(_:)), "a", [.command, .option])
        m.addItem(.separator())
        for (n, id) in model.favourites.prefix(9).enumerated() {
            let i = NSMenuItem(title: model.name(id), action: #selector(useFavourite(_:)), keyEquivalent: "\(n + 1)")
            i.tag = n
            i.target = self
            m.addItem(i)
        }
        m.addItem(.separator())
        let hint = NSMenuItem(title: "Hold ⌥ to Compare", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        m.addItem(hint)
    }

    // MARK: - Search (D3)

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        model.searchText = field.stringValue
        model.searchSelection = 0
        model.showAllResults = false
        model.resultsVisible = !model.searchText.isEmpty || model.browseAll
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            if !model.resultsVisible { model.resultsVisible = true } else { model.moveSearchSelection(1) }
            return true
        case #selector(NSResponder.moveUp(_:)):
            model.moveSearchSelection(-1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            if model.resultsVisible { model.useSearchSelection() }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            model.clearSearch()
            window?.makeFirstResponder(nil)
            return true
        default:
            return false
        }
    }

    private func showResults() {
        guard let window else { return }
        if resultsPanel == nil {
            let panel = ResultsPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            let effect = NSVisualEffectView()
            effect.material = .menu
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 10
            effect.layer?.masksToBounds = true
            let host = FirstMouseHostingView(rootView: SearchResultsView(model: model))
            host.autoresizingMask = [.width, .height]
            effect.addSubview(host)
            panel.contentView = effect
            resultsPanel = panel
            resultsHost = host
        }
        positionResults()
        if let panel = resultsPanel, panel.parent == nil { window.addChildWindow(panel, ordered: .above) }
        resultsPanel?.orderFront(nil)
        if let field = searchItem?.searchField, window.firstResponder !== field.currentEditor() {
            window.makeFirstResponder(field)   // arrow keys and ↩ go through the field
        }

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] e in
                guard let self, let panel = self.resultsPanel else { return e }
                if e.window === panel { return e }
                if let field = self.searchItem?.searchField, e.window === field.window,
                   field.bounds.contains(field.convert(e.locationInWindow, from: nil)) { return e }
                self.model.resultsVisible = false
                self.model.browseAll = false
                return e
            }
        }
    }

    private func positionResults() {
        guard let panel = resultsPanel, let host = resultsHost, let window else { return }
        let size = host.fittingSize
        let anchor: NSRect
        if let field = searchItem?.searchField, let fw = field.window, field.visibleRect.width > 40 {
            anchor = fw.convertToScreen(field.convert(field.bounds, to: nil))
        } else {
            let f = window.frame
            anchor = NSRect(x: f.maxX - 12, y: f.maxY - 52, width: 0, height: 0)
        }
        panel.setFrame(NSRect(x: anchor.maxX - size.width, y: anchor.minY - 6 - size.height,
                              width: size.width, height: size.height), display: true)
        host.frame = panel.contentView?.bounds ?? .zero
    }

    private func hideResults() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
        guard let panel = resultsPanel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }
}

/// The search results list: never becomes key, so typing stays in the search field.
final class ResultsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
