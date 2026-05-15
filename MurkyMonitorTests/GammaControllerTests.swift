import XCTest
@testable import MurkyMonitor

final class GammaControllerTests: XCTestCase {

    private let gc = GammaController()

    // MARK: - Kang CCT formula

    func testKangAtD65IsNeutral() {
        // At 6500K (D65), all multipliers must be very close to 1.0.
        let (r, g, b) = gc.colorMultipliers(for: 6500)
        XCTAssertEqual(r, 1.0, accuracy: 0.03, "R at D65")
        XCTAssertEqual(g, 1.0, accuracy: 0.03, "G at D65")
        XCTAssertEqual(b, 1.0, accuracy: 0.03, "B at D65")
    }

    func testKangWarmTiltAt5000K() {
        // 5000K is warm — red should dominate over blue.
        let (r, _, b) = gc.colorMultipliers(for: 5000)
        XCTAssertGreaterThan(r, b, "5000K should be warmer (more red) than blue")
    }

    func testKangCoolTiltAt7500K() {
        // 7500K is cool — blue should be higher relative to red.
        let (r, _, b) = gc.colorMultipliers(for: 7500)
        XCTAssertLessThan(r, b, "7500K should be cooler (more blue) than red")
    }

    func testKangBoundaryLow() {
        // Lower boundary — must not produce NaN or Inf.
        let (r, g, b) = gc.colorMultipliers(for: 1667)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangBoundaryHigh() {
        // Upper boundary.
        let (r, g, b) = gc.colorMultipliers(for: 25000)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangContinuityAt4000K() {
        // The piecewise boundary at 4000K must not produce a visible jump (> 0.02).
        let (r1, g1, b1) = gc.colorMultipliers(for: 3999)
        let (r2, g2, b2) = gc.colorMultipliers(for: 4001)
        XCTAssertLessThan(abs(r1 - r2), 0.02, "R must be continuous across 4000K")
        XCTAssertLessThan(abs(g1 - g2), 0.02, "G must be continuous across 4000K")
        XCTAssertLessThan(abs(b1 - b2), 0.02, "B must be continuous across 4000K")
    }

    // MARK: - Gamma table invariants

    func testTableValuesAllInRange() {
        // No entry may be outside [0, 1] regardless of extreme inputs.
        let s = FilterSettings()
        s.brightness = -1.0
        s.contrast = 0.5
        s.blackLevel = 0.15
        s.gammaDrift = 0.5
        let (r, g, b) = gc.buildTables(s)
        XCTAssertTrue(r.allSatisfy { (0...1).contains($0) }, "R out of [0,1]")
        XCTAssertTrue(g.allSatisfy { (0...1).contains($0) }, "G out of [0,1]")
        XCTAssertTrue(b.allSatisfy { (0...1).contains($0) }, "B out of [0,1]")
    }

    func testTableIsMonotonic() {
        // The red channel must be non-decreasing (higher input → higher or equal output).
        let s = FilterSettings()
        let (r, _, _) = gc.buildTables(s)
        for i in 1..<r.count {
            XCTAssertGreaterThanOrEqual(r[i], r[i - 1] - 1e-4,
                                        "Red table not monotonic at index \(i)")
        }
    }

    func testTableNoNaNOrInf() {
        // NaN in any table entry corrupts every display.
        let s = FilterSettings()
        s.colorTempShift = 3000
        let (r, g, b) = gc.buildTables(s)
        XCTAssertFalse(r.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in R")
        XCTAssertFalse(g.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in G")
        XCTAssertFalse(b.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in B")
    }
}
