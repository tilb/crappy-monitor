import simd
import XCTest
@testable import CrappyMonitor

// MARK: - Kang white point (moved unchanged from GammaControllerTests, Vraag 12)

final class WhitePointTests: XCTestCase {

    func testKangAtD65IsNeutral() {
        let (r, g, b) = WhitePoint.multipliers(for: 6500)
        XCTAssertEqual(r, 1.0, accuracy: 0.03, "R at D65")
        XCTAssertEqual(g, 1.0, accuracy: 0.03, "G at D65")
        XCTAssertEqual(b, 1.0, accuracy: 0.03, "B at D65")
    }

    func testKangWarmTiltAt5000K() {
        let (r, _, b) = WhitePoint.multipliers(for: 5000)
        XCTAssertGreaterThan(r, b, "5000K should be warmer (more red) than blue")
    }

    func testKangCoolTiltAt7500K() {
        let (r, _, b) = WhitePoint.multipliers(for: 7500)
        XCTAssertLessThan(r, b, "7500K should be cooler (more blue) than red")
    }

    func testKangBoundaryLow() {
        let (r, g, b) = WhitePoint.multipliers(for: 1667)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangBoundaryHigh() {
        let (r, g, b) = WhitePoint.multipliers(for: 25000)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangContinuityAt4000K() {
        let (r1, g1, b1) = WhitePoint.multipliers(for: 3999)
        let (r2, g2, b2) = WhitePoint.multipliers(for: 4001)
        XCTAssertLessThan(abs(r1 - r2), 0.02, "R must be continuous across 4000K")
        XCTAssertLessThan(abs(g1 - g2), 0.02, "G must be continuous across 4000K")
        XCTAssertLessThan(abs(b1 - b2), 0.02, "B must be continuous across 4000K")
    }

    func testD65WhiteIsAbout6500K() {
        let t = WhitePoint.correlatedTemperature(of: .init(0.3127, 0.3290))
        XCTAssertEqual(t, 6504, accuracy: 10)
    }
}

// MARK: - MonitorFilter

final class MonitorFilterTests: XCTestCase {

    private var library: MonitorLibrary!

    override func setUpWithError() throws {
        library = try MonitorLibrary.bundled()
    }

    private func profile(_ id: String) -> MonitorProfile { library.monitor(id)! }

    private func luminance(_ v: SIMD3<Double>) -> Double {
        let l = SIMD3(MonitorFilter.decode(v.x), MonitorFilter.decode(v.y), MonitorFilter.decode(v.z))
        return 0.2126 * l.x + 0.7152 * l.y + 0.0722 * l.z
    }

    // Table invariants (moved from GammaControllerTests, re-pointed at the grey ramp)

    func testTableValuesAllInRange() {
        var edits = MonitorFilter.Edits()
        edits.backlight = 0.2; edits.contrastRatio = 100; edits.officeLight = 3; edits.gamma = 2.6
        let f = MonitorFilter(profile: profile("hp-la2205wg"), age: .ten, edits: edits)
        let (r, g, b) = f.greyRamp()
        XCTAssertTrue(r.allSatisfy { (0...1).contains($0) }, "R out of [0,1]")
        XCTAssertTrue(g.allSatisfy { (0...1).contains($0) }, "G out of [0,1]")
        XCTAssertTrue(b.allSatisfy { (0...1).contains($0) }, "B out of [0,1]")
    }

    func testTableIsMonotonic() {
        for monitor in library.monitors {
            let (r, _, _) = MonitorFilter(profile: monitor).greyRamp()
            for i in 1..<r.count {
                XCTAssertGreaterThanOrEqual(r[i], r[i - 1] - 1e-4, "\(monitor.id) not monotonic at \(i)")
            }
        }
    }

    func testTableNoNaNOrInf() {
        var edits = MonitorFilter.Edits()
        edits.colorTemperature = 3000
        let (r, g, b) = MonitorFilter(profile: profile("dell-p2419h"), edits: edits).greyRamp()
        XCTAssertFalse(r.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in R")
        XCTAssertFalse(g.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in G")
        XCTAssertFalse(b.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in B")
    }

    // Wear model directions (PRD §7.3)

    func testNewMonitorHasNoWearAndKeepsItsWhitePoint() {
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .new)
        XCTAssertEqual(f.wear, 1)
        XCTAssertEqual(f.cornerFalloff, 0)
        XCTAssertEqual(f.whiteMultipliers.x, 1, accuracy: 1e-9)
        XCTAssertEqual(f.whiteMultipliers.z, 1, accuracy: 1e-9)
        XCTAssertEqual(luminance(f.apply(SIMD3(1, 1, 1), gamut: false)), 1, accuracy: 1e-6)
    }

    func testWhiteFallsWithAge() {
        let p = profile("lenovo-t24i-10")
        let whites = MonitorAge.allCases.map { luminance(MonitorFilter(profile: p, age: $0).apply(SIMD3(1, 1, 1))) }
        for i in 1..<whites.count { XCTAssertLessThan(whites[i], whites[i - 1], "white must fall with age") }
    }

    func testBlackRelativeToWhiteRisesWithAge() {
        let p = profile("lenovo-t24i-10")
        let ratios = MonitorAge.allCases.map { age -> Double in
            let f = MonitorFilter(profile: p, age: age)
            return luminance(f.apply(SIMD3(0, 0, 0))) / luminance(f.apply(SIMD3(1, 1, 1)))
        }
        for i in 1..<ratios.count { XCTAssertGreaterThan(ratios[i], ratios[i - 1], "lifted black must grow with age") }
    }

    func testPanelContrastUnchangedWithoutOfficeLight() {
        let p = profile("dell-u2412m")
        var edits = MonitorFilter.Edits()
        edits.officeLight = 0
        edits.colorTemperature = MonitorFilter(profile: p).newWhiteTemperature   // isolate contrast from warm drift
        for age in MonitorAge.allCases {
            let f = MonitorFilter(profile: p, age: age, edits: edits)
            let white = MonitorFilter.decode(f.apply(SIMD3(1, 1, 1), gamut: false).y)
            let black = MonitorFilter.decode(f.apply(SIMD3(0, 0, 0), gamut: false).y)
            XCTAssertEqual(white / black, 1000, accuracy: 30, "panel contrast at \(age)")
        }
    }

    func testCCFLWearsFasterThanLED() {
        let ccfl = MonitorFilter(profile: profile("hp-la2205wg"), age: .ten)
        let led = MonitorFilter(profile: profile("lenovo-lt2252p"), age: .ten)
        XCTAssertEqual(ccfl.wear, 0.70, accuracy: 1e-9)
        XCTAssertEqual(led.wear, 0.85, accuracy: 1e-9)
    }

    func testWhiteDriftsWarmerWithAge() {
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .ten)
        XCTAssertEqual(f.whiteTemperature, f.newWhiteTemperature - 600, accuracy: 1e-6)
        XCTAssertGreaterThan(f.whiteMultipliers.x, f.whiteMultipliers.z, "warmer: more red than blue")
    }

    // Gamut (PRD §7.2)

    func testSRGBPrimariesGiveAnIdentityMatrix() throws {
        let m = MonitorFilter.rgbToXYZ(.sRGB).inverse * MonitorFilter.rgbToXYZ(.sRGB)
        for c in 0..<3 { for r in 0..<3 { XCTAssertEqual(m[c][r], c == r ? 1 : 0, accuracy: 1e-9) } }
    }

    func testNarrowRedDesaturatesPureRed() {
        // HP E24 G4: red at x 0.623, inside sRGB, so pure red picks up green and blue.
        let red = MonitorFilter(profile: profile("hp-e24-g4"), age: .new).apply(SIMD3(1, 0, 0))
        XCTAssertGreaterThan(red.y, 0.05)
        XCTAssertLessThan(red.x, 1.0001)
    }

    func testGamutMatrixKeepsGreysNearNeutral() {
        for monitor in library.monitors {
            let g = MonitorFilter(profile: monitor, age: .new).apply(SIMD3(0.5, 0.5, 0.5))
            XCTAssertLessThan(max(g.x, g.y, g.z) - min(g.x, g.y, g.z), 0.02, "\(monitor.id) grey is tinted")
        }
    }

    // Edits and non-retina

    func testEditsOverrideTheProfile() {
        var edits = MonitorFilter.Edits()
        edits.backlight = 0.5; edits.contrastRatio = 200; edits.colorTemperature = 5000; edits.nonRetina = false
        let f = MonitorFilter(profile: profile("dell-p2419h"), age: .new, edits: edits)
        XCTAssertEqual(f.wear, 0.5)
        XCTAssertEqual(f.blackFloor, 1.0 / 200)
        XCTAssertEqual(f.whiteTemperature, 5000)
        XCTAssertFalse(f.nonRetina)
        XCTAssertEqual(f.blockSize(displayPPI: 254), 1)
        XCTAssertFalse(edits.isEmpty)
        XCTAssertTrue(MonitorFilter.Edits().isEmpty)
    }

    func testBlockSizeFollowsPixelDensity() {
        let f = MonitorFilter(profile: profile("dell-p2419h"))
        XCTAssertEqual(f.profile.pixelsPerInch, 92.6, accuracy: 0.1)
        XCTAssertEqual(f.blockSize(displayPPI: 254), 254 / 92.56, accuracy: 0.02)
    }

    func testVAShadowCrushAndTNDrift() {
        let tn = MonitorFilter(profile: profile("lenovo-lt2252p"))
        let ips = MonitorFilter(profile: profile("dell-p2419h"))
        XCTAssertLessThan(tn.panelLinear(0.5), ips.panelLinear(0.5), "TN drift darkens mid-grey")
        XCTAssertEqual(tn.panelLinear(0), 0)
        XCTAssertEqual(tn.panelLinear(1), 1)
    }
}

// MARK: - Library decoding (PRD §8.2)

final class MonitorLibraryTests: XCTestCase {

    func testBundledLibraryHasTheTenResearchedMonitors() throws {
        let lib = try MonitorLibrary.bundled()
        XCTAssertEqual(lib.schemaVersion, 2)
        XCTAssertEqual(lib.monitors.count, 10)
        XCTAssertEqual(Set(lib.monitors.map(\.id)).count, 10, "ids must be unique")
        XCTAssertEqual(lib.firstRunDefault?.id, "dell-p2419h")
    }

    func testFirstRunDefaultIsFullySourced() throws {
        let first = try XCTUnwrap(try MonitorLibrary.bundled().firstRunDefault)
        XCTAssertNotNil(first.released)
        XCTAssertNotNil(first.gamutSpec)
        XCTAssertTrue(first.estimated.isEmpty)
        XCTAssertNotNil(first.sources["specs"])
        XCTAssertNotNil(first.sources["primaries"])
    }

    func testEveryMonitorHasSourcesAndSaneValues() throws {
        for m in try MonitorLibrary.bundled().monitors {
            XCTAssertNotNil(m.sources["specs"], m.id)
            XCTAssertNotNil(m.sources["primaries"], m.id)
            XCTAssertEqual(m.resolution.count, 2, m.id)
            XCTAssertGreaterThan(m.contrastRatio, 100, m.id)
            XCTAssertGreaterThan(m.maxBrightness, 100, m.id)
            XCTAssertGreaterThan(m.sRGBCoverage, 0.85, m.id)
            XCTAssertLessThanOrEqual(m.sRGBCoverage, 1.0001, m.id)
        }
    }

    func testCoverageMatchesTheResearch() throws {
        let lib = try MonitorLibrary.bundled()
        XCTAssertEqual(lib.monitor("dell-u2412m")!.sRGBCoverage, 0.998, accuracy: 0.002)
        XCTAssertEqual(lib.monitor("hp-e243")!.sRGBCoverage, 0.924, accuracy: 0.002)
    }

    func testUnknownSchemaVersionIsRejected() {
        let json = #"{"schemaVersion": 3, "monitors": []}"#.data(using: .utf8)!
        XCTAssertThrowsError(try MonitorLibrary.decode(json)) { error in
            XCTAssertEqual(error as? MonitorLibrary.LoadError, .unsupportedSchema(3))
        }
    }

    func testMissingOptionalFieldsDecode() throws {
        let json = """
        {"schemaVersion": 2, "monitors": [{"id":"x","brand":"B","model":"M","released":null,
         "panelType":"TN","backlight":"CCFL","sizeInches":22,"resolution":[1680,1050],
         "contrastRatio":1000,"maxBrightness":250,"gamutSpec":null,
         "primaries":{"red":[0.64,0.33],"green":[0.3,0.6],"blue":[0.15,0.06],"white":[0.3127,0.329]},
         "sources":{},"estimated":["backlight"]}]}
        """.data(using: .utf8)!
        let m = try XCTUnwrap(try MonitorLibrary.decode(json).monitors.first)
        XCTAssertNil(m.released)
        XCTAssertNil(m.gamutSpec)
        XCTAssertTrue(m.isEstimated("backlight"))
        XCTAssertEqual(m.displayName, "B M")
    }
}
