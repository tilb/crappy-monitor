#if DEBUG
import AppKit

// Debug only. `--lens-snapshots <dir>` walks through the D1–D5
// states and writes every visible app window to PNG, so layout can be checked
// without Screen Recording permission for the terminal. The lens area itself
// (Metal) is not part of these images.
extension LensWindowController {
    func runSnapshotTour(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let m = model
        let steps: [(String, () -> Void)] = [
            ("welcome-0", { m.captureState = .welcome }),
            ("welcome-1", {}),
            ("welcome-2", {}),
            ("welcome-3", {}),
            ("welcome-4", {}),
            ("permission", { m.captureState = .needsPermission }),
            ("relaunch", { m.captureState = .needsRelaunch }),
            ("D1-strip", { m.captureState = .starting }),
            ("age-new", { m.age = .new }),
            ("age-10", { m.age = .ten }),
            ("nonretina-off", { m.age = .six; m.edits.nonRetina = false }),
            ("compare-original", { m.edits = MonitorFilter.Edits(); m.optionHeld = true }),
            ("preview-tn", { m.optionHeld = false; m.previewID = "lenovo-lt2252p" }),
            ("D3-search", { m.leftStrip(); m.searchText = "dell"; m.resultsVisible = true }),
            ("D3-more", { m.clearSearch(); m.openBrowseAll() }),
            ("D4-info", { m.clearSearch(); m.infoKey = "fav:\(m.favourites[safe: 1] ?? "")" }),
            ("D4-info-estimated", { m.infoKey = "fav:hp-la2205wg"; m.addFavourite("hp-la2205wg") }),
            ("adjust", { m.infoKey = nil; m.edits.contrastRatio = 300; m.adjustShown = true }),
            ("D5-collapsed", { m.adjustShown = false; m.stripVisible = false }),
            ("back", { m.stripVisible = true; m.edits = MonitorFilter.Edits() }),
            ("zoomed", { self.window?.performZoom(nil) }),
            ("zoomed-strip", { m.stripVisible = true }),
            ("unzoomed", { self.window?.performZoom(nil) }),
        ]
        func run(_ i: Int) {
            guard i < steps.count else { NSApp.terminate(nil); return }
            steps[i].1()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if let view = self.lensViewForSnapshot, let img = view.driver?.snapshot(of: view) {
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
