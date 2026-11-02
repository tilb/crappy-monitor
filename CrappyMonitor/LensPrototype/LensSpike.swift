import AppKit
import os.log
import ScreenCaptureKit

// LENS PROTOTYPE — M0 sandbox spike (PRD §9, task T1). Throwaway.
// Proves inside the App Sandbox: capture of every display, window collection
// behaviour, click-through with ⌘ hand-back, and Carbon hot keys. Results go to
// the unified log (subsystem com.crappymonitor.app, category Spike).

private let spikeLog = Logger(subsystem: "com.crappymonitor.app", category: "Spike")

extension LensWindowController {

    /// Click-through without Follow Pointer: clicks pass to the app below; hold ⌘
    /// to use the lens window. ⌃⌘T toggles it from any app.
    @objc func toggleSpikeClickThrough(_ sender: Any?) {
        spikeClickThrough.toggle()
        spikeMonitors.forEach(NSEvent.removeMonitor)
        spikeMonitors.removeAll()
        guard let window else { return }
        window.ignoresMouseEvents = spikeClickThrough
        spikeLog.notice("SPIKE click-through=\(self.spikeClickThrough, privacy: .public)")
        guard spikeClickThrough else { return }
        let update: (NSEvent) -> Void = { [weak self] _ in
            guard let self, self.spikeClickThrough, let window = self.window else { return }
            window.ignoresMouseEvents = !NSEvent.modifierFlags.contains(.command)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: update) { spikeMonitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { update($0); return $0 }) { spikeMonitors.append(m) }
    }

    @objc func runSandboxChecks(_ sender: Any?) {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        spikeLog.notice("SPIKE sandboxed=\(sandboxed, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        if let w = window {
            spikeLog.notice("SPIKE collectionBehavior=\(w.collectionBehavior.rawValue, privacy: .public) fullScreenAuxiliary=\(w.collectionBehavior.contains(.fullScreenAuxiliary), privacy: .public) level=\(w.level.rawValue, privacy: .public)")
        }
        spikeLog.notice("SPIKE screenCapturePreflight=\(CGPreflightScreenCaptureAccess(), privacy: .public)")
        Self.checkGammaTables()
        Task { await Self.checkEveryDisplay() }
    }

    /// Whole Screen question: can a sandboxed app set display gamma tables?
    /// Dims the main display to 60 % for 2 seconds, reads the table back, restores.
    private static func checkGammaTables() {
        let display = CGMainDisplayID()
        let size = 256
        let dim = (0..<size).map { CGGammaValue(Float($0) / Float(size - 1) * 0.6) }
        let setErr = CGSetDisplayTransferByTable(display, UInt32(size), dim, dim, dim)
        var r = [CGGammaValue](repeating: 0, count: size), g = r, b = r
        var count: UInt32 = 0
        let getErr = CGGetDisplayTransferByTable(display, UInt32(size), &r, &g, &b, &count)
        let top = count > 0 ? r[Int(count) - 1] : -1
        spikeLog.notice("SPIKE gamma set=\(setErr.rawValue, privacy: .public) get=\(getErr.rawValue, privacy: .public) samples=\(count, privacy: .public) readbackTop=\(top, privacy: .public) (expect ≈0.6 if applied)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            CGDisplayRestoreColorSyncSettings()
            var r2 = [CGGammaValue](repeating: 0, count: size), g2 = r2, b2 = r2
            var c2: UInt32 = 0
            CGGetDisplayTransferByTable(display, UInt32(size), &r2, &g2, &b2, &c2)
            spikeLog.notice("SPIKE gamma restored readbackTop=\(c2 > 0 ? r2[Int(c2) - 1] : -1, privacy: .public)")
        }
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
