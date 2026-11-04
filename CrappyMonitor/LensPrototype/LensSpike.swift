import AppKit
import os.log
import ScreenCaptureKit

// LENS PROTOTYPE — M0 sandbox spike (PRD §9, task T1). Throwaway.
// Proves inside the App Sandbox: capture of every display, window collection
// behaviour and Carbon hot keys. (Click-through and display gamma were checked on
// 2026-11-02 and removed with those features; results in PRD §9.) Results go to
// the unified log (subsystem com.crappymonitor.app, category Spike).

private let spikeLog = Logger(subsystem: "com.crappymonitor.app", category: "Spike")

extension LensWindowController {

    @objc func runSandboxChecks(_ sender: Any?) {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        spikeLog.notice("SPIKE sandboxed=\(sandboxed, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        if let w = window {
            spikeLog.notice("SPIKE collectionBehavior=\(w.collectionBehavior.rawValue, privacy: .public) fullScreenAuxiliary=\(w.collectionBehavior.contains(.fullScreenAuxiliary), privacy: .public) level=\(w.level.rawValue, privacy: .public)")
        }
        spikeLog.notice("SPIKE screenCapturePreflight=\(CGPreflightScreenCaptureAccess(), privacy: .public)")
        Task { await Self.checkEveryDisplay() }
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
