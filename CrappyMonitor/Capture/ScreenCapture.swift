import AppKit
import CoreMedia
import os.log
import ScreenCaptureKit

private let log = Logger(subsystem: "com.crappymonitor.app", category: "Capture")

/// Captures every display the lens overlaps, one `SCStream` per display (PRD §6, Vraag 9).
/// Each stream is the whole display at backing resolution, minus every window of this
/// app, so moving the window inside a display only changes the crop. Streams start when
/// the lens reaches a display and stop when it leaves.
@MainActor
final class ScreenCapture {

    struct Frame {
        let buffer: CVPixelBuffer
        let displayID: CGDirectDisplayID
        let displayFrame: CGRect      // NSScreen.frame of that display (global points)
        var pixelsPerPoint: CGFloat { CGFloat(CVPixelBufferGetWidth(buffer)) / displayFrame.width }
    }

    private var streams: [CGDirectDisplayID: DisplayStream] = [:]
    private var starting: Set<CGDirectDisplayID> = []
    private nonisolated let store = FrameStore()

    /// Called when a running stream dies (permission revoked, display gone…).
    var onStop: ((Error) -> Void)?

    /// Called on a capture queue for every new frame (the screen under it changed).
    nonisolated var onFrame: (@Sendable () -> Void)? {
        get { store.onFrame }
        set { store.onFrame = newValue }
    }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// The latest frame of every running display. Safe from any thread.
    nonisolated var frames: [Frame] { store.all }

    var runningDisplays: Set<CGDirectDisplayID> { Set(streams.keys) }

    /// Starts streams for the displays `rect` (global points) overlaps and stops the rest.
    /// Throws if a needed stream can't start.
    func cover(_ rect: CGRect) async throws {
        let screens = NSScreen.screens.compactMap { s in s.displayID.map { (id: $0, frame: s.frame, scale: s.backingScaleFactor) } }
        let wanted = Set(LensLayout.displays(overlapping: rect, in: screens.map { ($0.id, $0.frame) }))

        for id in streams.keys where !wanted.contains(id) { await stop(id) }

        let new = screens.filter { wanted.contains($0.id) && streams[$0.id] == nil && !starting.contains($0.id) }
        guard !new.isEmpty else { return }
        new.forEach { starting.insert($0.id) }
        defer { new.forEach { starting.remove($0.id) } }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Leave out every window of this app: the lens window, popovers, the search list.
        let me = content.applications.filter { $0.processID == getpid() }
        for screen in new {
            guard let display = content.displays.first(where: { $0.displayID == screen.id }) else {
                throw CaptureError.noDisplay
            }
            let stream = DisplayStream(id: screen.id, frame: screen.frame, store: store)
            stream.onStop = { [weak self] error in
                guard let self, self.streams[screen.id] === stream else { return }
                self.streams[screen.id] = nil
                self.store.remove(screen.id)
                self.onStop?(error)
            }
            try await stream.start(display: display, excluding: me, scale: screen.scale)
            streams[screen.id] = stream
        }
    }

    func stop() async {
        for id in streams.keys { await stop(id) }
    }

    private func stop(_ id: CGDirectDisplayID) async {
        guard let s = streams.removeValue(forKey: id) else { return }
        s.markStopped()   // no frames from it after this
        store.remove(id)
        await s.stop()
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        var errorDescription: String? { "The display under the window isn't available." }
    }
}

/// Latest frame per display, written on the capture queues and read by the renderer.
private final class FrameStore: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [CGDirectDisplayID: ScreenCapture.Frame] = [:]
    private var _onFrame: (@Sendable () -> Void)?

    var onFrame: (@Sendable () -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onFrame }
        set { lock.lock(); _onFrame = newValue; lock.unlock() }
    }

    var all: [ScreenCapture.Frame] {
        lock.lock(); defer { lock.unlock() }
        return frames.keys.sorted().compactMap { frames[$0] }
    }
    func set(_ f: ScreenCapture.Frame) {
        lock.lock(); frames[f.displayID] = f; let notify = _onFrame; lock.unlock()
        notify?()
    }
    func remove(_ id: CGDirectDisplayID) { lock.lock(); frames[id] = nil; lock.unlock() }
}

/// One display's stream.
private final class DisplayStream: NSObject, SCStreamOutput, SCStreamDelegate {
    let id: CGDirectDisplayID
    let frame: CGRect
    var onStop: (@MainActor (Error) -> Void)?

    private let store: FrameStore
    private var stream: SCStream?
    private var stopped = false   // only touched on `queue`
    private let queue = DispatchQueue(label: "com.crappymonitor.capture", qos: .userInteractive)

    init(id: CGDirectDisplayID, frame: CGRect, store: FrameStore) {
        self.id = id
        self.frame = frame
        self.store = store
    }

    func markStopped() { queue.sync { stopped = true } }

    func start(display: SCDisplay, excluding apps: [SCRunningApplication], scale: CGFloat) async throws {
        let filter = SCContentFilter(display: display, excludingApplications: apps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // sRGB on both ends (here and the lens layer), so pixel values pass through unchanged.
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.queueDepth = 3   // the minimum (review, Vraag 14)

        let s = SCStream(filter: filter, configuration: config, delegate: self)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await s.startCapture()
        stream = s
        log.info("Capture started on display \(self.id) at \(config.width)×\(config.height)")
    }

    func stop() async {
        markStopped()
        if let s = stream {
            stream = nil
            try? await s.stopCapture()
            log.info("Capture stopped on display \(self.id)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                  as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let buffer = sampleBuffer.imageBuffer,
              !stopped
        else { return }
        store.set(.init(buffer: buffer, displayID: id, displayFrame: frame))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("Capture stopped on display \(self.id): \(error.localizedDescription)")
        Task { @MainActor [weak self] in self?.onStop?(error) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
