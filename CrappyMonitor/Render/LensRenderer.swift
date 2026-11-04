import AppKit
import CoreVideo
import Metal
import os.log
import simd

private let log = Logger(subsystem: "com.crappymonitor.app", category: "LensRenderer")

/// Where a render target sits on the captured display.
struct RenderRegion: Equatable {
    /// The target's top-left corner on the capture, in capture pixels (top-left origin).
    var origin: SIMD2<Float>
    /// Capture pixels per target pixel (1 = a 1:1 crop).
    var scale: Float = 1
}

/// The one place that applies a `MonitorFilter` to pixels (PRD §6): the lens view and
/// the strip thumbnails are both drawn by `encode`, with the same shader and uniforms.
/// `MonitorFilter.apply(_:)` is the CPU reference; tests compare the two.
final class LensRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
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
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    func makeCommandBuffer() -> MTLCommandBuffer? { queue.makeCommandBuffer() }

    // MARK: Source

    /// A capture frame as a Metal texture. Keep the value alive until the GPU is done:
    /// it holds the IOSurface.
    struct Source {
        let texture: MTLTexture
        fileprivate let backing: AnyObject?
    }

    func source(for buffer: CVPixelBuffer) -> Source? {
        guard let cache = textureCache else { return nil }
        var cv: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm,
                                                  CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &cv)
        guard let cv, let texture = CVMetalTextureGetTexture(cv) else { return nil }
        return Source(texture: texture, backing: cv)
    }

    func source(for texture: MTLTexture) -> Source { Source(texture: texture, backing: nil) }

    // MARK: Drawing

    /// One display's share of a target: its capture, where the target sits on it, and
    /// which target pixels it covers (nil = all of them).
    struct Part {
        var source: Source
        var region: RenderRegion
        var scissor: MTLScissorRect? = nil
        /// Capture pixels per monitor pixel when the filter asks for non-retina.
        var nonRetinaBlock = 1
    }

    /// A target of `width` × `height` pixels, drawn from one or more displays.
    struct Job {
        var parts: [Part]
        var width: Int
        var height: Int
        var filter: MonitorFilter?
        var original = false
    }

    /// Draws `job` into `pass`, one draw per part. `filter == nil` or `original` shows the
    /// capture unchanged (hold ⌥). Pixels no part covers keep the clear colour.
    func encode(into cmd: MTLCommandBuffer, pass: MTLRenderPassDescriptor, job: Job) {
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.setRenderPipelineState(pipeline)
        let nonRetina = (job.filter?.nonRetina ?? false) && !job.original
        for part in job.parts {
            let full = MTLScissorRect(x: 0, y: 0, width: job.width, height: job.height)
            let s = Self.clamp(part.scissor ?? full, to: full)
            guard s.width > 0, s.height > 0 else { continue }
            enc.setScissorRect(s)
            var u = ShaderUniforms(filter: job.filter, original: job.original,
                                   block: nonRetina ? part.nonRetinaBlock : 1, region: part.region,
                                   sourceSize: SIMD2(Float(part.source.texture.width), Float(part.source.texture.height)))
            enc.setFragmentTexture(part.source.texture, index: 0)
            enc.setFragmentBytes(&u, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        enc.endEncoding()
        let keep = job.parts.map(\.source)
        cmd.addCompletedHandler { _ in _ = keep }
    }

    private static func clamp(_ s: MTLScissorRect, to b: MTLScissorRect) -> MTLScissorRect {
        let x0 = min(max(s.x, 0), b.width), y0 = min(max(s.y, 0), b.height)
        let x1 = min(max(s.x + s.width, x0), b.width), y1 = min(max(s.y + s.height, y0), b.height)
        return MTLScissorRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Renders every job offscreen in one command buffer and hands back the pixels
    /// (BGRA, sRGB-encoded) on the main thread. Used for the strip thumbnails.
    func render(_ jobs: [Job], completion: @escaping ([CGImage?]) -> Void) {
        guard let cmd = queue.makeCommandBuffer() else { completion(jobs.map { _ in nil }); return }
        let targets = encodeOffscreen(jobs, into: cmd)
        cmd.addCompletedHandler { _ in
            let images = zip(targets, jobs).map { t, j in t.flatMap { Self.image(from: $0, j.width, j.height) } }
            DispatchQueue.main.async { completion(images) }
        }
        cmd.commit()
    }

    /// Synchronous version, for tests and the snapshot tour.
    func renderNow(_ job: Job) -> [UInt8]? {
        guard let cmd = queue.makeCommandBuffer() else { return nil }
        let targets = encodeOffscreen([job], into: cmd)
        cmd.commit()
        cmd.waitUntilCompleted()
        return targets[0].map { Self.bytes(of: $0, job.width, job.height) }
    }

    private func encodeOffscreen(_ jobs: [Job], into cmd: MTLCommandBuffer) -> [MTLTexture?] {
        let targets: [MTLTexture?] = jobs.map { job in
            guard job.width > 0, job.height > 0 else { return nil }
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: job.width,
                                                              height: job.height, mipmapped: false)
            td.usage = [.renderTarget, .shaderRead]
            td.storageMode = .managed
            return device.makeTexture(descriptor: td)
        }
        for (job, target) in zip(jobs, targets) {
            guard let target else { continue }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            encode(into: cmd, pass: pass, job: job)
        }
        if let blit = cmd.makeBlitCommandEncoder() {
            targets.compactMap { $0 }.forEach { blit.synchronize(resource: $0) }
            blit.endEncoding()
        }
        return targets
    }

    private static func bytes(of t: MTLTexture, _ w: Int, _ h: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        t.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return bytes
    }

    static func image(from t: MTLTexture, _ w: Int, _ h: Int) -> CGImage? {
        image(fromBGRA: bytes(of: t, w, h), w, h)
    }

    static func image(fromBGRA pixels: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        var data = pixels
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        return CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)?.makeImage()
    }
}

/// Mirrors `struct Uniforms` in the shader, field for field (same order, simd alignment).
struct ShaderUniforms {
    var gamut = matrix_identity_float3x3     // monitor linear RGB → sRGB linear
    var whiteGain = SIMD3<Float>(1, 1, 1)
    var origin = SIMD2<Float>(0, 0)          // target top-left on the capture, capture pixels
    var sourceSize = SIMD2<Float>(1, 1)      // capture size = the whole display, capture pixels
    var scale: Float = 1
    var block: Float = 1
    var original: Float = 1                  // 1 = show the capture unchanged
    var gamma: Float = 2.2
    var midtoneDrift: Float = 0
    var shadowCrush: Float = 0
    var shadowKnee: Float = 0.1
    var blackFloor: Float = 0
    var wear: Float = 1
    var officeLight: Float = 0
    var cornerFalloff: Float = 0

    init(filter: MonitorFilter?, original: Bool, block: Int, region: RenderRegion, sourceSize: SIMD2<Float>) {
        origin = region.origin
        scale = region.scale
        self.sourceSize = sourceSize
        self.block = Float(max(1, block))
        guard let f = filter, !original else { return }
        self.original = 0
        let m = f.gamutMatrix
        gamut = simd_float3x3(columns: (SIMD3<Float>(m.columns.0), SIMD3<Float>(m.columns.1), SIMD3<Float>(m.columns.2)))
        whiteGain = SIMD3<Float>(f.whiteMultipliers)
        gamma = Float(f.gamma)
        midtoneDrift = Float(f.midtoneDrift)
        shadowCrush = Float(f.shadowCrush)
        shadowKnee = Float(MonitorFilter.Constants.vaShadowKnee)
        blackFloor = Float(f.blackFloor)
        wear = Float(f.wear)
        officeLight = Float(f.officeLight)
        cornerFalloff = Float(f.cornerFalloff)
    }
}

extension LensRenderer {
    /// The fragment shader is `MonitorFilter.apply(_:at:)` step for step, plus the
    /// crop, the non-retina block average and the corner falloff position.
    static let shaderSource = """
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
        float3x3 gamut;
        float3   whiteGain;
        float2   origin;
        float2   sourceSize;
        float    scale;
        float    block;
        float    original;
        float    gamma;
        float    midtoneDrift;
        float    shadowCrush;
        float    shadowKnee;
        float    blackFloor;
        float    wear;
        float    officeLight;
        float    cornerFalloff;
    };

    static float3 decodeSRGB(float3 v) {
        return select(pow((v + 0.055) / 1.055, float3(2.4)), v / 12.92, v <= 0.04045);
    }

    static float3 encodeSRGB(float3 l) {
        return select(1.055 * pow(l, float3(1.0 / 2.4)) - 0.055, 12.92 * l, l <= 0.0031308);
    }

    static float panelLinear(float v, constant Uniforms& u) {
        v = saturate(v);
        float g = u.gamma + u.midtoneDrift * (1.0 - abs(2.0 * v - 1.0));
        if (u.shadowCrush > 0.0 && v < u.shadowKnee) {
            g += u.shadowCrush * (1.0 - v / u.shadowKnee);
        }
        return pow(v, g);
    }

    fragment float4 lens_fragment(VOut in [[stage_in]],
                                  texture2d<float, access::read> src [[texture(0)]],
                                  constant Uniforms& u [[buffer(0)]]) {
        float2 sp = u.origin + in.pos.xy * u.scale;
        int b = int(u.block);
        if (b > 1) {
            // Snap to the display's own grid so the blocks don't swim while dragging.
            sp = floor(sp / u.block) * u.block;
        }
        if (sp.x < 0.0 || sp.y < 0.0 || sp.x >= u.sourceSize.x || sp.y >= u.sourceSize.y) {
            return float4(0.0, 0.0, 0.0, 1.0);   // target hangs off the display
        }

        float3 c;
        float2 centre;   // where on the display this output pixel comes from
        if (b > 1) {
            // Non-retina: one monitor pixel per block = the average of the block in
            // linear light. Picking a single pixel instead drops thin font strokes.
            float3 acc = float3(0.0);
            int n = 0;
            for (int y = 0; y < b; y++) {
                for (int x = 0; x < b; x++) {
                    float2 p = sp + float2(x, y);
                    if (p.x < u.sourceSize.x && p.y < u.sourceSize.y) {
                        acc += decodeSRGB(src.read(uint2(p)).rgb);
                        n++;
                    }
                }
            }
            c = encodeSRGB(acc / float(max(n, 1)));
            centre = sp + u.block * 0.5;
        } else {
            c = src.read(uint2(sp)).rgb;
            centre = floor(sp) + 0.5;
        }
        if (u.original > 0.5) { return float4(c, 1.0); }

        // 1. panel tone curve per channel → linear light
        float3 lin = float3(panelLinear(c.r, u), panelLinear(c.g, u), panelLinear(c.b, u));
        // 2. the panel's own primaries → sRGB linear
        lin = u.gamut * lin;
        // 3. white point
        lin *= u.whiteGain;
        // 4. black floor, backlight wear dimmed towards the corners, office light
        float2 q = centre / u.sourceSize * 2.0 - 1.0;   // -1…1 across the display
        float w = u.wear * (1.0 - u.cornerFalloff * dot(q, q) * 0.5);
        float3 outL = (w * (u.blackFloor + (1.0 - u.blackFloor) * lin) + u.officeLight) / (1.0 + u.officeLight);
        // 5. back to sRGB for the Mac display
        return float4(encodeSRGB(saturate(outL)), 1.0);
    }
    """
}
