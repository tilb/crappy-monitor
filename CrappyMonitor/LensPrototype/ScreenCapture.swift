import AppKit
import CoreMedia
import os.log
import ScreenCaptureKit

// LENS PROTOTYPE — throwaway.

private let log = Logger(subsystem: "com.crappymonitor.app", category: "LensCapture")

/// Captures one whole display (minus every window of this app) at backing
/// resolution and keeps the latest frame. The lens and the thumbnails crop
/// from that frame, so moving the window never needs a stream reconfigure and
/// never shows empty edges.
final class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate {

    struct Frame {
        let buffer: CVPixelBuffer
        let displayID: CGDirectDisplayID
        let displayFrame: CGRect      // NSScreen.frame of that display (global points)
        var pixelsPerPoint: CGFloat { CGFloat(CVPixelBufferGetWidth(buffer)) / displayFrame.width }
    }

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.crappymonitor.lens.capture", qos: .userInteractive)
    private let lock = NSLock()
    private var _latest: Frame?
    private var _currentDisplay: (id: CGDirectDisplayID, frame: CGRect)?
    private var currentDisplay: (id: CGDirectDisplayID, frame: CGRect)? {
        get { lock.lock(); defer { lock.unlock() }; return _currentDisplay }
        set { lock.lock(); _currentDisplay = newValue; lock.unlock() }
    }

    /// Called on the main thread when the stream dies (permission revoked, display gone…).
    var onStop: ((Error) -> Void)?

    var latest: Frame? {
        lock.lock(); defer { lock.unlock() }
        return _latest
    }

    var displayID: CGDirectDisplayID? { currentDisplay?.id }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    func start(screen: NSScreen) async throws {
        await stop()
        guard let id = screen.displayID else { throw CaptureError.noDisplay }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw CaptureError.noDisplay
        }
        // Leave out every window of this app: the lens window, popovers, the search list.
        let me = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])

        let scale = screen.backingScaleFactor
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // sRGB on both ends (here and the lens layer), so pixel values pass through
        // unchanged and the curves act on encoded values, like a gamma table does.
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.queueDepth = 5

        let s = SCStream(filter: filter, configuration: config, delegate: self)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await s.startCapture()
        stream = s
        currentDisplay = (id, screen.frame)
        log.info("Capture started on display \(id) at \(config.width)×\(config.height)")
    }

    func stop() async {
        if let s = stream {
            stream = nil
            try? await s.stopCapture()
        }
        currentDisplay = nil
        lock.lock(); _latest = nil; lock.unlock()
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                  as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let buffer = sampleBuffer.imageBuffer,
              let display = currentDisplay
        else { return }
        let frame = Frame(buffer: buffer, displayID: display.id, displayFrame: display.frame)
        lock.lock(); _latest = frame; lock.unlock()
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("Capture stopped: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil
            self.currentDisplay = nil
            self.onStop?(error)
        }
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        var errorDescription: String? { "The display under the window isn't available." }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
