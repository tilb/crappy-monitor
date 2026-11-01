import AppKit
import CoreVideo
import Metal
import MetalKit
import os.log

// LENS PROTOTYPE — throwaway.

private let log = Logger(subsystem: "com.crappymonitor.app", category: "LensRenderer")

/// Draws the part of the captured display that lies under this view, run through
/// the 3 × 256 tables from `GammaController.buildTables`. The tables are looked
/// up per channel on encoded values, which is exactly what
/// `CGSetDisplayTransferByTable` does for Whole Screen.
final class LensMTKView: MTKView {
    var renderer: LensRenderer?

    /// This view's rect in global (Cocoa, bottom-left origin) screen points.
    var rectOnScreen: CGRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }

    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class LensRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private let tableTexture: MTLTexture
    private var tableParams: LensParams?

    private let capture: ScreenCapture
    private weak var model: LensModel?

    init?(view: LensMTKView, capture: ScreenCapture, model: LensModel) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        self.capture = capture
        self.model = model

        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "lens_vertex")
            desc.fragmentFunction = library.makeFunction(name: "lens_fragment")
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            log.error("Shader setup failed: \(error.localizedDescription)")
            return nil
        }

        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 256, height: 1, mipmapped: false)
        td.usage = .shaderRead
        guard let table = device.makeTexture(descriptor: td) else { return nil }
        tableTexture = table
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        super.init()

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        if let layer = view.layer as? CAMetalLayer {
            layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)   // matches ScreenCapture
        }
        view.delegate = self
        view.renderer = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let view = view as? LensMTKView,
              let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = queue.makeCommandBuffer() else { return }
        encode(into: cmd, pass: pass, view: view)
        cmd.present(drawable)
        cmd.commit()
    }

    private func encode(into cmd: MTLCommandBuffer, pass: MTLRenderPassDescriptor, view: LensMTKView) {
        guard let model else { return }

        let params = model.lensParams
        if params != tableParams { upload(params) }

        var sourceTexture: CVMetalTexture?
        var uniforms = Uniforms()
        if let frame = capture.latest,
           let rect = view.rectOnScreen,
           let cache = textureCache {
            let w = CVPixelBufferGetWidth(frame.buffer), h = CVPixelBufferGetHeight(frame.buffer)
            CVMetalTextureCacheCreateTextureFromImage(nil, cache, frame.buffer, nil, .bgra8Unorm, w, h, 0, &sourceTexture)
            let ppp = frame.pixelsPerPoint
            let viewScale = view.window?.backingScaleFactor ?? 2
            // Display-local, top-left origin, in capture pixels.
            uniforms.origin = SIMD2(Float((rect.minX - frame.displayFrame.minX) * ppp),
                                    Float((frame.displayFrame.maxY - rect.maxY) * ppp))
            uniforms.scale = Float(ppp / viewScale)
            uniforms.block = params.nonRetina && !model.showsOriginal ? Float(max(1, ppp.rounded())) : 1
            uniforms.original = model.showsOriginal ? 1 : 0
            uniforms.texSize = SIMD2(Float(w), Float(h))
        }

        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        if let src = sourceTexture.flatMap(CVMetalTextureGetTexture) {
            enc.setRenderPipelineState(pipeline)
            enc.setFragmentTexture(src, index: 0)
            enc.setFragmentTexture(tableTexture, index: 1)
            enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        enc.endEncoding()
        // Keep the CVMetalTexture (and its IOSurface) alive until the GPU is done.
        cmd.addCompletedHandler { _ in _ = sourceTexture }
    }

    #if DEBUG
    /// Renders one lens frame offscreen and returns it (snapshot tour only).
    func snapshot(of view: LensMTKView) -> CGImage? {
        let size = view.drawableSize
        let w = Int(size.width), h = Int(size.height)
        guard w > 0, h > 0 else { return nil }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .managed
        guard let target = device.makeTexture(descriptor: td), let cmd = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        encode(into: cmd, pass: pass, view: view)
        if let blit = cmd.makeBlitCommandEncoder() { blit.synchronize(resource: target); blit.endEncoding() }
        cmd.commit()
        cmd.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        target.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        return CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)?.makeImage()
    }
    #endif

    private func upload(_ params: LensParams) {
        let (r, g, b) = params.tables()
        var data = [Float](repeating: 1, count: 256 * 4)
        for i in 0..<256 {
            data[i * 4] = r[i]; data[i * 4 + 1] = g[i]; data[i * 4 + 2] = b[i]
        }
        data.withUnsafeBytes { raw in
            tableTexture.replace(region: MTLRegionMake2D(0, 0, 256, 1), mipmapLevel: 0,
                                 withBytes: raw.baseAddress!, bytesPerRow: 256 * 4 * MemoryLayout<Float>.size)
        }
        tableParams = params
    }

    private struct Uniforms {
        var origin = SIMD2<Float>(0, 0)
        var scale: Float = 1
        var block: Float = 1
        var texSize = SIMD2<Float>(1, 1)
        var original: Float = 0
        var _pad: Float = 0
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 pos [[position]]; };

    vertex VOut lens_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return o;
    }

    struct Uniforms {
        float2 origin;     // lens top-left in capture pixels
        float  scale;      // capture pixels per drawable pixel
        float  block;      // >1 = non-retina: snap to blocks of this many capture pixels
        float2 texSize;
        float  original;   // 1 = show unfiltered (hold ⌥)
        float  pad;
    };

    fragment float4 lens_fragment(VOut in [[stage_in]],
                                  texture2d<float, access::read> src [[texture(0)]],
                                  texture2d<float, access::read> table [[texture(1)]],
                                  constant Uniforms& u [[buffer(0)]]) {
        float2 sp = u.origin + in.pos.xy * u.scale;
        if (u.block > 1.0) {
            // Snap to the display's own grid so the blocks don't swim while dragging.
            sp = floor(sp / u.block) * u.block;
        }
        if (sp.x < 0.0 || sp.y < 0.0 || sp.x >= u.texSize.x || sp.y >= u.texSize.y) {
            return float4(0.0, 0.0, 0.0, 1.0);   // lens hangs off the display
        }
        float4 c = src.read(uint2(sp));
        if (u.original > 0.5) { return float4(c.rgb, 1.0); }
        uint3 i = uint3(round(saturate(c.rgb) * 255.0));
        return float4(table.read(uint2(i.r, 0)).r,
                      table.read(uint2(i.g, 0)).g,
                      table.read(uint2(i.b, 0)).b,
                      1.0);
    }
    """
}
