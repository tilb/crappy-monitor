import AppKit
import Combine
import MetalKit

/// The lens: the part of the captured display under this view, drawn by `LensRenderer`.
final class LensMTKView: MTKView {
    fileprivate(set) var driver: LensViewDriver?

    /// This view's rect in global (Cocoa, bottom-left origin) screen points.
    var rectOnScreen: CGRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }

    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// When to draw (PRD §6, review Vraag 13): only after something changed, at most 30
/// times a second. Window moves draw at once so dragging stays smooth.
struct RedrawPacer {
    static let minimumInterval: CFTimeInterval = 1.0 / 30

    /// Seconds to wait before the next draw, given when the last one happened.
    static func delay(now: CFTimeInterval, lastDraw: CFTimeInterval) -> CFTimeInterval {
        max(0, lastDraw + minimumInterval - now)
    }
}

/// Feeds the latest capture frames and the model's filter to the renderer. The view only
/// draws on request: a new captured frame, a change that affects the lens, ⌥, a window
/// move or a resize.
final class LensViewDriver: NSObject, MTKViewDelegate {
    private let renderer: LensRenderer
    private let capture: ScreenCapture
    private weak var model: LensModel?
    private weak var view: LensMTKView?
    private var cancellables = Set<AnyCancellable>()
    private var lastDraw: CFTimeInterval = 0
    private var redrawPending = false
    /// Draws so far, for tests and the debug log.
    private(set) var drawCount = 0

    @discardableResult
    init(view: LensMTKView, renderer: LensRenderer, capture: ScreenCapture, model: LensModel) {
        self.renderer = renderer
        self.capture = capture
        self.model = model
        self.view = view
        super.init()
        view.device = renderer.device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        // Draw on request only, never on a fixed 30 fps timer.
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)   // off every display
        if let layer = view.layer as? CAMetalLayer {
            layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)   // matches ScreenCapture
        }
        view.delegate = self
        view.driver = self   // the view keeps its driver

        let redraw = WeakRedraw(self)
        capture.onFrame = { DispatchQueue.main.async { redraw.fire() } }
        // Everything `lensFilter` and `showsOriginal` read. @Published fires on willSet,
        // and setNeedsRedraw draws on a later turn, so the new values are in place.
        Publishers.MergeMany(model.$activeID.map { _ in () }.eraseToAnyPublisher(),
                             model.$age.map { _ in () }.eraseToAnyPublisher(),
                             model.$edits.map { _ in () }.eraseToAnyPublisher(),
                             model.$previewID.map { _ in () }.eraseToAnyPublisher(),
                             model.$optionHeld.map { _ in () }.eraseToAnyPublisher())
            .dropFirst(5)
            .sink { [weak self] in self?.setNeedsRedraw() }
            .store(in: &cancellables)
    }

    /// Something under or about the lens changed: draw soon, at most 30 times a second.
    func setNeedsRedraw() {
        guard !redrawPending else { return }
        redrawPending = true
        let wait = RedrawPacer.delay(now: CACurrentMediaTime(), lastDraw: lastDraw)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self else { return }
            self.redrawPending = false
            self.view?.draw()
        }
    }

    /// The window moved: draw now so the lens keeps up with the drag.
    func redrawNow() { view?.draw() }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { setNeedsRedraw() }

    func draw(in view: MTKView) {
        guard let view = view as? LensMTKView,
              let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = renderer.makeCommandBuffer() else { return }
        lastDraw = CACurrentMediaTime()
        drawCount += 1
        if let job = job(for: view) {
            renderer.encode(into: cmd, pass: pass, job: job)
        } else if let enc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            enc.endEncoding()   // clear only
        }
        cmd.present(drawable)
        cmd.commit()
    }

    /// The render job for `view`: one part per display under it, each from that display's
    /// own capture (PRD §6, Vraag 9). Nil before the first frame.
    private func job(for view: LensMTKView) -> LensRenderer.Job? {
        guard let model, let rect = view.rectOnScreen else { return nil }
        let frames = capture.frames
        guard !frames.isEmpty else { return nil }
        let size = view.drawableSize
        let target = (width: Int(size.width), height: Int(size.height))
        let scale = rect.width > 0 ? size.width / rect.width : (view.window?.backingScaleFactor ?? 2)
        let displays = frames.map { LensLayout.Display(id: $0.displayID, frame: $0.displayFrame, pixelsPerPoint: $0.pixelsPerPoint) }
        let parts: [LensRenderer.Part] = LensLayout.placements(for: rect, targetScale: scale, size: target, displays: displays)
            .compactMap { p in
                guard let frame = frames.first(where: { $0.displayID == p.displayID }),
                      let source = renderer.source(for: frame.buffer) else { return nil }
                return LensRenderer.Part(source: source, region: p.region, scissor: p.scissor, nonRetinaBlock: p.block)
            }
        return LensRenderer.Job(parts: parts, width: target.width, height: target.height,
                                filter: model.lensFilter, original: model.showsOriginal)
    }

    #if DEBUG
    /// One lens frame rendered offscreen (snapshot tour only).
    func snapshot(of view: LensMTKView) -> CGImage? {
        guard let job = job(for: view), let px = renderer.renderNow(job) else { return nil }
        return LensRenderer.image(fromBGRA: px, job.width, job.height)
    }
    #endif
}

/// Lets a capture queue ask the main thread for a redraw without holding the driver.
private final class WeakRedraw: @unchecked Sendable {
    private weak var driver: LensViewDriver?
    init(_ driver: LensViewDriver) { self.driver = driver }
    func fire() { driver?.setNeedsRedraw() }   // main thread only
}
