import Metal
import simd
import XCTest
@testable import CrappyMonitor

/// Shader vs CPU reference, for a lens target and a thumbnail target (PRD §10, Vraag 4).
/// The reference below is the shader's crop and block average around
/// `MonitorFilter.apply(_:at:)`, written plainly in Swift.
final class LensRendererTests: XCTestCase {

    private var renderer: LensRenderer!
    private var library: MonitorLibrary!

    // A test "capture": gradients plus a fixed pseudo-random pattern, so every channel
    // sees dark, mid and bright values and neighbours differ (block averaging).
    private let sw = 64, sh = 40
    private lazy var pixels: [UInt8] = {
        var px = [UInt8](repeating: 255, count: sw * sh * 4)
        var seed: UInt32 = 12345
        for y in 0..<sh { for x in 0..<sw {
            seed = seed &* 1_103_515_245 &+ 12345
            let i = (y * sw + x) * 4
            px[i] = UInt8((x * 4) & 255)                       // B
            px[i + 1] = UInt8((y * 6 + x) & 255)               // G
            px[i + 2] = UInt8(truncatingIfNeeded: seed >> 16)  // R
        } }
        return px
    }()

    override func setUpWithError() throws {
        renderer = try XCTUnwrap(LensRenderer(), "no Metal device")
        library = try MonitorLibrary.bundled()
    }

    private func profile(_ id: String) -> MonitorProfile { library.monitor(id)! }

    private func source(_ px: [UInt8]? = nil) -> LensRenderer.Source {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: sw, height: sh, mipmapped: false)
        td.usage = .shaderRead
        td.storageMode = .managed
        let t = renderer.device.makeTexture(descriptor: td)!
        (px ?? pixels).withUnsafeBytes {
            t.replace(region: MTLRegionMake2D(0, 0, sw, sh), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: sw * 4)
        }
        return renderer.source(for: t)
    }

    // MARK: CPU reference of the shader

    private func reference(_ job: LensRenderer.Job, _ src: [UInt8]) -> [UInt8] {
        func read(_ x: Int, _ y: Int) -> SIMD3<Double> {
            let i = (y * sw + x) * 4
            return SIMD3(Double(src[i + 2]), Double(src[i + 1]), Double(src[i])) / 255
        }
        let size = SIMD2(Double(sw), Double(sh))
        let b = Double(job.block)
        var out = [UInt8](repeating: 0, count: job.width * job.height * 4)
        for y in 0..<job.height { for x in 0..<job.width {
            var sp = SIMD2(Double(job.region.origin.x), Double(job.region.origin.y))
                + SIMD2(Double(x) + 0.5, Double(y) + 0.5) * Double(job.region.scale)
            if job.block > 1 { sp = (sp / b).rounded(.down) * b }
            var c = SIMD3<Double>(0, 0, 0)
            if sp.x >= 0, sp.y >= 0, sp.x < size.x, sp.y < size.y {
                let centre: SIMD2<Double>
                if job.block > 1 {
                    var acc = SIMD3<Double>(0, 0, 0), n = 0.0
                    for dy in 0..<job.block { for dx in 0..<job.block {
                        let px = Int(sp.x) + dx, py = Int(sp.y) + dy
                        guard px < sw, py < sh else { continue }
                        let v = read(px, py)
                        acc += SIMD3(MonitorFilter.decode(v.x), MonitorFilter.decode(v.y), MonitorFilter.decode(v.z))
                        n += 1
                    } }
                    acc /= max(n, 1)
                    c = SIMD3(MonitorFilter.encode(acc.x), MonitorFilter.encode(acc.y), MonitorFilter.encode(acc.z))
                    centre = sp + b / 2
                } else {
                    c = read(Int(sp.x), Int(sp.y))
                    centre = sp.rounded(.down) + 0.5
                }
                if let f = job.filter, !job.original { c = f.apply(c, at: centre / size) }
            }
            let i = (y * job.width + x) * 4
            let q = (simd_clamp(c, SIMD3<Double>(repeating: 0), SIMD3<Double>(repeating: 1)) * 255)
                .rounded(.toNearestOrAwayFromZero)
            out[i] = UInt8(q.z); out[i + 1] = UInt8(q.y); out[i + 2] = UInt8(q.x); out[i + 3] = 255
        } }
        return out
    }

    /// Largest per-channel difference (alpha ignored), with where it happened.
    private func compare(_ job: LensRenderer.Job, _ name: String, source px: [UInt8]? = nil,
                         file: StaticString = #filePath, line: UInt = #line) {
        let gpu = renderer.renderNow(job, from: source(px))!
        let cpu = reference(job, px ?? pixels)
        var worst = 0, at = 0
        for i in gpu.indices where i % 4 != 3 {
            let d = abs(Int(gpu[i]) - Int(cpu[i]))
            if d > worst { worst = d; at = i }
        }
        XCTAssertLessThanOrEqual(worst, 1, "\(name): GPU \(gpu[at]) vs CPU \(cpu[at]) at pixel \(at / 4)",
                                 file: file, line: line)
    }

    // MARK: Lens and thumbnail targets

    func testLensMatchesReferenceForEveryMonitor() {
        for monitor in library.monitors {
            let f = MonitorFilter(profile: monitor, age: .six)
            compare(.init(region: RenderRegion(origin: .zero), width: sw, height: sh, filter: f), monitor.id)
        }
    }

    func testLensMatchesReferenceAtEveryAgeWithNonRetinaBlocks() {
        for age in MonitorAge.allCases {
            let f = MonitorFilter(profile: profile("lenovo-lt2252p"), age: age)   // TN: midtone drift
            compare(.init(region: RenderRegion(origin: .zero), width: sw, height: sh, filter: f, block: 2), "\(age)")
        }
    }

    func testLensMatchesReferenceWithAdjustEdits() {
        var e = MonitorFilter.Edits()
        e.backlight = 0.6; e.contrastRatio = 300; e.colorTemperature = 5000; e.gamma = 2.5; e.officeLight = 2.5
        let f = MonitorFilter(profile: profile("hp-la2205wg"), age: .ten, edits: e)
        compare(.init(region: RenderRegion(origin: .zero), width: sw, height: sh, filter: f), "edits")
    }

    func testThumbnailCropMatchesReference() {
        // A tile-shaped crop away from the origin, on an odd offset so the block grid
        // must follow the display, not the crop.
        let f = MonitorFilter(profile: profile("dell-u2412m"), age: .ten)
        compare(.init(region: RenderRegion(origin: SIMD2(21, 13)), width: 31, height: 17, filter: f, block: 2), "thumb")
        compare(.init(region: RenderRegion(origin: SIMD2(21, 13)), width: 31, height: 17, filter: f), "thumb 1:1")
    }

    func testScaledLensMatchesReference() {
        // A lens on a 1× display looking at a 2× capture samples every other pixel.
        let f = MonitorFilter(profile: profile("eizo-ev2450"), age: .three)
        compare(.init(region: RenderRegion(origin: SIMD2(3, 2), scale: 2), width: 30, height: 19, filter: f), "scaled")
    }

    func testOriginalPassesTheCaptureThrough() {
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .ten)
        let job = LensRenderer.Job(region: RenderRegion(origin: .zero), width: sw, height: sh, filter: f, original: true)
        let gpu = renderer.renderNow(job, from: source())!
        for i in gpu.indices where i % 4 != 3 { XCTAssertEqual(gpu[i], pixels[i]); if gpu[i] != pixels[i] { break } }
    }

    func testOffTheDisplayIsBlack() {
        let f = MonitorFilter(profile: profile("dell-p2419h"))
        let job = LensRenderer.Job(region: RenderRegion(origin: SIMD2(-8, 0)), width: 16, height: 4, filter: f)
        let gpu = renderer.renderNow(job, from: source())!
        XCTAssertEqual(Array(gpu[0..<3]), [0, 0, 0], "left of the display")
        XCTAssertNotEqual(Array(gpu[(12 * 4)..<(12 * 4 + 3)]), [0, 0, 0], "on the display")
        compare(job, "off display")
    }

    // MARK: Corners (PRD §7.3, 5)

    func testCornersDarkenWithAgeAcrossTheDisplay() {
        let white = [UInt8](repeating: 255, count: sw * sh * 4)
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .ten)
        let job = LensRenderer.Job(region: RenderRegion(origin: .zero), width: sw, height: sh, filter: f)
        let gpu = renderer.renderNow(job, from: source(white))!
        let corner = Int(gpu[1]), centre = Int(gpu[((sh / 2) * sw + sw / 2) * 4 + 1])
        XCTAssertLessThan(corner, centre)
        compare(job, "white", source: white)

        let fresh = MonitorFilter(profile: profile("dell-p2419h"), age: .new)
        XCTAssertEqual(fresh.uniformity(at: SIMD2(0, 0)), 1)
        XCTAssertEqual(f.uniformity(at: SIMD2(0.5, 0.5)), 1)
        XCTAssertEqual(f.uniformity(at: SIMD2(0, 0)), 0.9, accuracy: 1e-12, "10 % at 10 years in the corners")
        XCTAssertEqual(f.uniformity(at: SIMD2(1, 1)), 0.9, accuracy: 1e-12)
        XCTAssertGreaterThan(f.uniformity(at: SIMD2(0.5, 0)), 0.9, "edge centres lose less than corners")
    }
}
