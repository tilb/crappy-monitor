#if DEBUG
import AppKit

// LENS PROTOTYPE — debug only. `--lens-snapshots <dir>` walks through the D1–D5
// states and writes every visible app window to PNG, so layout can be checked
// without Screen Recording permission for the terminal. The lens area itself
// (Metal) is not part of these images.
extension LensWindowController {
    func runSnapshotTour(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let m = model
        let steps: [(String, () -> Void)] = [
            ("D1-strip", {}),
            ("age-new", { m.age = .new }),
            ("age-10", { m.age = .ten }),
            ("nonretina-off", { m.age = .six; m.overrides.nonRetina = false }),
            ("compare-original", { m.overrides = LensOverrides(); m.optionHeld = true }),
            ("preview-samsung", { m.optionHeld = false; m.previewID = "samsung-s24f350" }),
            ("D2-preview", { m.previewID = nil; m.hoveredKey = "fav:\(m.favourites.last ?? "")"; m.previewID = m.favourites.last }),
            ("D3-search", { m.leftStrip(); m.searchText = "phil"; m.resultsVisible = true }),
            ("D3-more", { m.clearSearch(); m.openBrowseAll() }),
            ("D4-info", { m.clearSearch(); m.infoKey = "fav:\(m.favourites[safe: 1] ?? "")" }),
            ("adjust", { m.infoKey = nil; m.overrides.contrast = 0.7; m.adjustShown = true }),
            ("D5-collapsed", { m.adjustShown = false; m.stripVisible = false }),
            ("whole-screen", { m.stripVisible = true; m.mode = .wholeScreen }),
            ("back-to-lens", { m.mode = .lens; m.overrides = LensOverrides() }),
        ]
        func run(_ i: Int) {
            guard i < steps.count else { NSApp.terminate(nil); return }
            steps[i].1()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if let view = self.lensViewForSnapshot, let img = view.renderer?.snapshot(of: view) {
                    let rep = NSBitmapImageRep(cgImage: img)
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: dir.appendingPathComponent("\(steps[i].0)-lens.png"))
                }
                for (n, w) in NSApp.windows.filter({ $0.isVisible && $0.frame.width > 40 }).enumerated() {
                    Self.write(w, to: dir.appendingPathComponent("\(steps[i].0)-\(n).png"))
                }
                run(i + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { run(0) }
    }

    private static func write(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
