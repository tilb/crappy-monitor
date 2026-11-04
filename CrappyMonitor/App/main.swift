import AppKit

// Entry point. AppDelegate owns the lifecycle; SwiftUI is only used inside the window.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.regular)
NSApp.run()
