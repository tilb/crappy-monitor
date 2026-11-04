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

    /// A single-display job on the test capture.
    private func job(_ region: RenderRegion, _ w: Int, _ h: Int, _ f: MonitorFilter?,
                     block: Int = 1, original: Bool = false, source px: [UInt8]? = nil) -> LensRenderer.Job {
        LensRenderer.Job(parts: [.init(source: source(px), region: region, nonRetinaBlock: block)],
                         width: w, height: h, filter: f, original: original)
    }

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
        let region = job.parts[0].region
        let block = (job.filter?.nonRetina ?? false) && !job.original ? job.parts[0].nonRetinaBlock : 1
        func read(_ x: Int, _ y: Int) -> SIMD3<Double> {
            let i = (y * sw + x) * 4
            return SIMD3(Double(src[i + 2]), Double(src[i + 1]), Double(src[i])) / 255
        }
        let size = SIMD2(Double(sw), Double(sh))
        let b = Double(block)
        var out = [UInt8](repeating: 0, count: job.width * job.height * 4)
        for y in 0..<job.height { for x in 0..<job.width {
            var sp = SIMD2(Double(region.origin.x), Double(region.origin.y))
                + SIMD2(Double(x) + 0.5, Double(y) + 0.5) * Double(region.scale)
            if block > 1 { sp = (sp / b).rounded(.down) * b }
            var c = SIMD3<Double>(0, 0, 0)
            if sp.x >= 0, sp.y >= 0, sp.x < size.x, sp.y < size.y {
                let centre: SIMD2<Double>
                if block > 1 {
                    var acc = SIMD3<Double>(0, 0, 0), n = 0.0
                    for dy in 0..<block { for dx in 0..<block {
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
        let gpu = renderer.renderNow(job)!
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
            compare(job(RenderRegion(origin: .zero), sw, sh, f), monitor.id)
        }
    }

    func testLensMatchesReferenceAtEveryAgeWithNonRetinaBlocks() {
        for age in MonitorAge.allCases {
            let f = MonitorFilter(profile: profile("lenovo-lt2252p"), age: age)   // TN: midtone drift
            compare(job(RenderRegion(origin: .zero), sw, sh, f, block: 2), "\(age)")
        }
    }

    func testLensMatchesReferenceWithAdjustEdits() {
        var e = MonitorFilter.Edits()
        e.backlight = 0.6; e.contrastRatio = 300; e.colorTemperature = 5000; e.gamma = 2.5; e.officeLight = 2.5
        let f = MonitorFilter(profile: profile("hp-la2205wg"), age: .ten, edits: e)
        compare(job(RenderRegion(origin: .zero), sw, sh, f), "edits")
    }

    func testThumbnailCropMatchesReference() {
        // A tile-shaped crop away from the origin, on an odd offset so the block grid
        // must follow the display, not the crop.
        let f = MonitorFilter(profile: profile("dell-u2412m"), age: .ten)
        compare(job(RenderRegion(origin: SIMD2(21, 13)), 31, 17, f, block: 2), "thumb")
        compare(job(RenderRegion(origin: SIMD2(21, 13)), 31, 17, f), "thumb 1:1")
    }

    func testScaledLensMatchesReference() {
        // A lens on a 1× display looking at a 2× capture samples every other pixel.
        let f = MonitorFilter(profile: profile("eizo-ev2450"), age: .three)
        compare(job(RenderRegion(origin: SIMD2(3, 2), scale: 2), 30, 19, f), "scaled")
    }

    func testOriginalPassesTheCaptureThrough() {
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .ten)
        let gpu = renderer.renderNow(job(RenderRegion(origin: .zero), sw, sh, f, original: true))!
        for i in gpu.indices where i % 4 != 3 { XCTAssertEqual(gpu[i], pixels[i]); if gpu[i] != pixels[i] { break } }
    }

    func testOffTheDisplayIsBlack() {
        let f = MonitorFilter(profile: profile("dell-p2419h"))
        let offJob = job(RenderRegion(origin: SIMD2(-8, 0)), 16, 4, f)
        let gpu = renderer.renderNow(offJob)!
        XCTAssertEqual(Array(gpu[0..<3]), [0, 0, 0], "left of the display")
        XCTAssertNotEqual(Array(gpu[(12 * 4)..<(12 * 4 + 3)]), [0, 0, 0], "on the display")
        compare(offJob, "off display")
    }

    // MARK: Corners (PRD §7.3, 5)

    func testCornersDarkenWithAgeAcrossTheDisplay() {
        let white = [UInt8](repeating: 255, count: sw * sh * 4)
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .ten)
        let whiteJob = job(RenderRegion(origin: .zero), sw, sh, f, source: white)
        let gpu = renderer.renderNow(whiteJob)!
        let corner = Int(gpu[1]), centre = Int(gpu[((sh / 2) * sw + sw / 2) * 4 + 1])
        XCTAssertLessThan(corner, centre)
        compare(whiteJob, "white", source: white)

        let fresh = MonitorFilter(profile: profile("dell-p2419h"), age: .new)
        XCTAssertEqual(fresh.uniformity(at: SIMD2(0, 0)), 1)
        XCTAssertEqual(f.uniformity(at: SIMD2(0.5, 0.5)), 1)
        XCTAssertEqual(f.uniformity(at: SIMD2(0, 0)), 0.9, accuracy: 1e-12, "10 % at 10 years in the corners")
        XCTAssertEqual(f.uniformity(at: SIMD2(1, 1)), 0.9, accuracy: 1e-12)
        XCTAssertGreaterThan(f.uniformity(at: SIMD2(0.5, 0)), 0.9, "edge centres lose less than corners")
    }

    // MARK: Two displays (PRD §6, Vraag 9)

    func testLensSpanningTwoDisplaysSamplesBothCaptures() {
        // Left: a 2× display that is all dark red. Right: a 1× display that is all light blue.
        let left = LensLayout.Display(id: 1, frame: CGRect(x: 0, y: 0, width: 32, height: 20), pixelsPerPoint: 2)
        let right = LensLayout.Display(id: 2, frame: CGRect(x: 32, y: 0, width: 64, height: 40), pixelsPerPoint: 1)
        func solid(_ w: Int, _ h: Int, _ bgr: [UInt8]) -> LensRenderer.Source {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
            td.usage = .shaderRead; td.storageMode = .managed
            let t = renderer.device.makeTexture(descriptor: td)!
            let px: [UInt8] = Array(repeatElement(bgr + [255], count: w * h).joined())
            px.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: w * 4) }
            return renderer.source(for: t)
        }
        let sources: [CGDirectDisplayID: LensRenderer.Source] = [1: solid(64, 40, [0, 0, 120]), 2: solid(64, 40, [230, 180, 90])]

        // A 2× lens from x 20 to 44 pt: 12 pt on each display.
        let lens = CGRect(x: 20, y: 4, width: 24, height: 10)
        let placements = LensLayout.placements(for: lens, targetScale: 2, size: (48, 20), displays: [left, right])
        XCTAssertEqual(placements.map(\.displayID), [1, 2])
        let parts = placements.map {
            LensRenderer.Part(source: sources[$0.displayID]!, region: $0.region, scissor: $0.scissor, nonRetinaBlock: $0.block)
        }
        let gpu = renderer.renderNow(LensRenderer.Job(parts: parts, width: 48, height: 20, filter: nil))!
        func px(_ x: Int, _ y: Int) -> [UInt8] { Array(gpu[((y * 48 + x) * 4)..<((y * 48 + x) * 4 + 3)]) }
        XCTAssertEqual(px(0, 0), [0, 0, 120])
        XCTAssertEqual(px(23, 19), [0, 0, 120], "last pixel on the left display")
        XCTAssertEqual(px(24, 0), [230, 180, 90], "first pixel on the right display")
        XCTAssertEqual(px(47, 19), [230, 180, 90])

        // Through a filter, each half still matches the CPU reference for its own capture.
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .new)
        let filtered = renderer.renderNow(LensRenderer.Job(parts: parts, width: 48, height: 20, filter: f))!
        let red = f.apply(SIMD3(120.0 / 255, 0, 0), at: SIMD2(0.5, 0.5))
        XCTAssertEqual(Int(filtered[(10 * 48 + 2) * 4 + 2]), Int((red.x * 255).rounded()), accuracy: 2)
    }
}

final class LensLayoutTests: XCTestCase {
    private let main = LensLayout.Display(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), pixelsPerPoint: 2)
    private let side = LensLayout.Display(id: 2, frame: CGRect(x: 1512, y: -100, width: 1920, height: 1080), pixelsPerPoint: 1)
    private var screens: [(id: CGDirectDisplayID, frame: CGRect)] { [(1, main.frame), (2, side.frame)] }

    func testOverlapFindsOneOrBothDisplays() {
        XCTAssertEqual(LensLayout.displays(overlapping: CGRect(x: 100, y: 100, width: 800, height: 500), in: screens), [1])
        XCTAssertEqual(LensLayout.displays(overlapping: CGRect(x: 1400, y: 100, width: 800, height: 500), in: screens), [1, 2])
        XCTAssertEqual(LensLayout.displays(overlapping: CGRect(x: 2000, y: 0, width: 300, height: 300), in: screens), [2])
        XCTAssertEqual(LensLayout.displays(overlapping: CGRect(x: 5000, y: 0, width: 10, height: 10), in: screens), [])
        XCTAssertEqual(LensLayout.displays(overlapping: CGRect(x: 1312, y: 0, width: 200, height: 10), in: screens), [1],
                       "touching the edge is not overlapping")
    }

    func testSingleDisplayPlacementMatchesTheOldCrop() {
        let lens = CGRect(x: 100, y: 200, width: 400, height: 300)
        let p = LensLayout.placements(for: lens, targetScale: 2, size: (800, 600), displays: [main, side])
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p[0].region, RenderRegion(origin: SIMD2(200, Float((982 - 500) * 2)), scale: 1))
        XCTAssertEqual(p[0].scissor.width, 800)
        XCTAssertEqual(p[0].scissor.height, 600)
        XCTAssertEqual(p[0].block, 2)
    }

    func testPlacementsTileTheTargetAcrossTwoDisplays() {
        let lens = CGRect(x: 1400.3, y: 300, width: 600, height: 400)
        let size = (width: 1200, height: 800)
        let p = LensLayout.placements(for: lens, targetScale: 2, size: size, displays: [main, side])
        XCTAssertEqual(p.map(\.displayID), [1, 2])
        XCTAssertEqual(p[0].scissor.x, 0)
        XCTAssertEqual(p[0].scissor.x + p[0].scissor.width, p[1].scissor.x, "no gap and no overlap")
        XCTAssertEqual(p[1].scissor.x + p[1].scissor.width, size.width)
        XCTAssertEqual(p[1].region.scale, 0.5, "1× display under a 2× lens")
        XCTAssertEqual(p[1].block, 1)
        XCTAssertEqual(p[1].region.origin.x, Float(1400.3 - 1512), accuracy: 1e-3, "starts left of the side display")
    }

    func testDisplaysAtDifferentHeightsClipVertically() {
        // The lens hangs below the main display's bottom edge but inside the taller side display.
        let lens = CGRect(x: 1412, y: -50, width: 200, height: 100)
        let p = LensLayout.placements(for: lens, targetScale: 1, size: (200, 100), displays: [main, side])
        XCTAssertEqual(p.map(\.displayID), [1, 2])
        XCTAssertEqual(p[0].scissor.y, 0)
        XCTAssertEqual(p[0].scissor.height, 50, "only the top half is on the main display")
        XCTAssertEqual(p[1].scissor.height, 100)
    }
}
