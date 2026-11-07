#if DEBUG
import AppKit
import os.log
import ScreenCaptureKit

// Debug › Run Sandbox Checks (PRD §9, tasks T1 and T13). The app itself runs in the
// App Sandbox; this proves on a given Mac that capture of every display, the window
// behaviour (full-screen auxiliary, green button zooms) and the hot keys work in it.
// Results go to the unified log (subsystem com.crappymonitor.app, category Spike):
//   log show --last 2m --predicate 'subsystem == "com.crappymonitor.app" AND category == "Spike"'

private let spikeLog = Logger(subsystem: "com.crappymonitor.app", category: "Spike")

extension LensWindowController {

    @objc func runSandboxChecks(_ sender: Any?) {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        spikeLog.notice("SPIKE sandboxed=\(sandboxed, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        if let w = window {
            spikeLog.notice("SPIKE collectionBehavior=\(w.collectionBehavior.rawValue, privacy: .public) fullScreenAuxiliary=\(w.collectionBehavior.contains(.fullScreenAuxiliary), privacy: .public) level=\(w.level.rawValue, privacy: .public)")
        }
        spikeLog.notice("SPIKE screenCapturePreflight=\(CGPreflightScreenCaptureAccess(), privacy: .public)")
        checkGreenButton()
        Task { await Self.checkEveryDisplay() }
    }

    /// T13: the green button must zoom to the visible area and back, never full screen.
    private func checkGreenButton() {
        guard let w = window, let visible = w.screen?.visibleFrame else { return }
        let before = w.frame
        let primary = w.collectionBehavior.contains(.fullScreenPrimary)
        w.performZoom(nil)
        let zoomed = w.frame
        w.performZoom(nil)
        let restored = w.frame
        func same(_ a: NSRect, _ b: NSRect) -> Bool { abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1 }
        spikeLog.notice("SPIKE greenButton fullScreenPrimary=\(primary, privacy: .public) fillsVisible=\(same(zoomed, visible), privacy: .public) restores=\(same(restored, before), privacy: .public) inFullScreen=\(w.styleMask.contains(.fullScreen), privacy: .public)")
    }

    /// Starts a 2-second stream on every display and counts complete frames.
    private static func checkEveryDisplay() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            spikeLog.notice("SPIKE displays=\(content.displays.count, privacy: .public)")
            for display in content.displays {
                let counter = FrameCounter()
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
                config.queueDepth = 3
                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                                      configuration: config, delegate: nil)
                try stream.addStreamOutput(counter, type: .screen, sampleHandlerQueue: .global())
                try await stream.startCapture()
                try await Task.sleep(nanoseconds: 2_000_000_000)
                try await stream.stopCapture()
                spikeLog.notice("SPIKE display=\(display.displayID, privacy: .public) \(display.width, privacy: .public)x\(display.height, privacy: .public) frames=\(counter.count, privacy: .public)")
            }
        } catch {
            spikeLog.error("SPIKE capture error: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private final class FrameCounter: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        lock.lock(); _count += 1; lock.unlock()
    }
}
#endif
