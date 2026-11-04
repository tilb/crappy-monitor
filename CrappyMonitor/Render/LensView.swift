import AppKit
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

/// Feeds the latest capture frames and the model's filter to the renderer, 30 times a second.
final class LensViewDriver: NSObject, MTKViewDelegate {
    private let renderer: LensRenderer
    private let capture: ScreenCapture
    private weak var model: LensModel?

    @discardableResult
    init(view: LensMTKView, renderer: LensRenderer, capture: ScreenCapture, model: LensModel) {
        self.renderer = renderer
        self.capture = capture
        self.model = model
        super.init()
        view.device = renderer.device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)   // off every display
        if let layer = view.layer as? CAMetalLayer {
            layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)   // matches ScreenCapture
        }
        view.delegate = self
        view.driver = self   // the view keeps its driver
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let view = view as? LensMTKView,
              let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = renderer.makeCommandBuffer() else { return }
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
