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

/// Feeds the latest capture frame and the model's filter to the renderer, 30 times a second.
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
        view.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
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
        if let job = job(for: view), let source = capture.latest.flatMap({ renderer.source(for: $0.buffer) }) {
            renderer.encode(into: cmd, pass: pass, source: source, region: job.region,
                            filter: job.filter, original: job.original, block: job.block)
        } else if let enc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            enc.endEncoding()   // clear only
        }
        cmd.present(drawable)
        cmd.commit()
    }

    /// The render job that covers `view`, or nil without a frame.
    private func job(for view: LensMTKView) -> LensRenderer.Job? {
        guard let model, let frame = capture.latest, let rect = view.rectOnScreen else { return nil }
        let ppp = frame.pixelsPerPoint
        let viewScale = view.window?.backingScaleFactor ?? 2
        let filter = model.lensFilter
        let size = view.drawableSize
        return LensRenderer.Job(
            region: RenderRegion(origin: SIMD2(Float((rect.minX - frame.displayFrame.minX) * ppp),
                                               Float((frame.displayFrame.maxY - rect.maxY) * ppp)),
                                 scale: Float(ppp / viewScale)),
            width: Int(size.width), height: Int(size.height),
            filter: filter, original: model.showsOriginal,
            block: (filter?.nonRetina ?? false) && !model.showsOriginal ? Int(max(1, ppp.rounded())) : 1)
    }

    #if DEBUG
    /// One lens frame rendered offscreen (snapshot tour only).
    func snapshot(of view: LensMTKView) -> CGImage? {
        guard let job = job(for: view), let frame = capture.latest,
              let source = renderer.source(for: frame.buffer),
              let px = renderer.renderNow(job, from: source) else { return nil }
        return LensRenderer.image(fromBGRA: px, job.width, job.height)
    }
    #endif
}
