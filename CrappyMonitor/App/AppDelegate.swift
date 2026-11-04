import AppKit

/// Crappy Monitor 2.0 is a regular app (Dock icon, main menu) whose one window is
/// the lens (PRD §5, §6.1). It never touches the display itself: no gamma tables,
/// no display modes, no status item.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var lens: LensWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let library: MonitorLibrary
        do {
            library = try MonitorLibrary.bundled()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Crappy Monitor can’t load its monitor library."
            alert.informativeText = "Reinstall the app. (\(error))"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        // The controller lives as long as the app: closing the window keeps ⌃⌘L and
        // the Dock icon working to bring the lens back.
        lens = LensWindowController(library: library)
        lens?.show()

        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--lens-snapshots"), i + 1 < args.count {
            lens?.runSnapshotTour(to: URL(fileURLWithPath: args[i + 1]))
        }
        #endif
    }

    /// Clicking the Dock icon with no window open brings the lens back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { lens?.show() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
