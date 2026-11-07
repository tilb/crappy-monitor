import AppKit
import CoreGraphics

/// Screen Recording permission and the first-run flow (PRD §5.2, tasks DT2 and T11).
enum ScreenRecordingPermission {

    /// What the lens window shows before it can capture.
    enum Step: Equatable {
        case lens         // permission active: start capturing
        case welcome      // first run: the intro, with Continue
        case askSettings  // asked (or declined): how to turn it on in System Settings
        case relaunch     // turned on, but this process only sees it after a relaunch
    }

    /// The pure rule. `active`: this process may capture now. `granted`: the switch is on in
    /// System Settings (seen live). `continued`: the user got past the intro once.
    static func step(active: Bool, granted: Bool, continued: Bool) -> Step {
        if active { return .lens }
        if granted { return .relaunch }
        return continued ? .askSettings : .welcome
    }

    /// The current step for this process.
    static func currentStep(defaults: UserDefaults = .standard) -> Step {
        step(active: isActive, granted: isGrantedLive, continued: defaults.bool(forKey: continuedKey))
    }

    static let continuedKey = "onboarding.continued"

    /// Granted and usable by this process (macOS caches this until the app relaunches).
    static var isActive: Bool { CGPreflightScreenCaptureAccess() }

    /// Turned on in System Settings, checked live: other apps' window titles are only
    /// visible to an app with Screen Recording, and that check is not cached.
    static var isGrantedLive: Bool {
        let me = getpid()
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != me,
                  let owner = w[kCGWindowOwnerName as String] as? String,
                  owner != "Window Server", owner != "Dock",
                  let title = w[kCGWindowName as String] as? String else { return false }
            return !title.isEmpty
        }
    }

    /// Shows the system prompt (once per app) and adds the app to the Screen Recording list.
    static func request(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: continuedKey)
        CGRequestScreenCaptureAccess()
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    static let helpURL = URL(string: "https://support.apple.com/guide/mac-help/mchld6aa7d23/mac")!

    /// Quits and opens this same app bundle again, so the new grant takes effect.
    static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, error in
            DispatchQueue.main.async {
                if error == nil { NSApp.terminate(nil) }
            }
        }
    }
}
