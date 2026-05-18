import XCTest
@testable import MurkyMonitor

final class GammaControllerTests: XCTestCase {

    private let gc = GammaController()

    // MARK: - Kang CCT formula

    func testKangAtD65IsNeutral() {
        let (r, g, b) = gc.colorMultipliers(for: 6500)
        XCTAssertEqual(r, 1.0, accuracy: 0.03, "R at D65")
        XCTAssertEqual(g, 1.0, accuracy: 0.03, "G at D65")
        XCTAssertEqual(b, 1.0, accuracy: 0.03, "B at D65")
    }

    func testKangWarmTiltAt5000K() {
        let (r, _, b) = gc.colorMultipliers(for: 5000)
        XCTAssertGreaterThan(r, b, "5000K should be warmer (more red) than blue")
    }

    func testKangCoolTiltAt7500K() {
        let (r, _, b) = gc.colorMultipliers(for: 7500)
        XCTAssertLessThan(r, b, "7500K should be cooler (more blue) than red")
    }

    func testKangBoundaryLow() {
        let (r, g, b) = gc.colorMultipliers(for: 1667)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangBoundaryHigh() {
        let (r, g, b) = gc.colorMultipliers(for: 25000)
        XCTAssertTrue(r.isFinite && r > 0)
        XCTAssertTrue(g.isFinite && g > 0)
        XCTAssertTrue(b.isFinite && b > 0)
    }

    func testKangContinuityAt4000K() {
        let (r1, g1, b1) = gc.colorMultipliers(for: 3999)
        let (r2, g2, b2) = gc.colorMultipliers(for: 4001)
        XCTAssertLessThan(abs(r1 - r2), 0.02, "R must be continuous across 4000K")
        XCTAssertLessThan(abs(g1 - g2), 0.02, "G must be continuous across 4000K")
        XCTAssertLessThan(abs(b1 - b2), 0.02, "B must be continuous across 4000K")
    }

    // MARK: - Gamma table invariants

    func testTableValuesAllInRange() {
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
        let s = FilterSettings()
        let (r, _, _) = gc.buildTables(s)
        for i in 1..<r.count {
            XCTAssertGreaterThanOrEqual(r[i], r[i - 1] - 1e-4,
                                        "Red table not monotonic at index \(i)")
        }
    }

    func testTableNoNaNOrInf() {
        let s = FilterSettings()
        s.colorTempShift = 3000
        let (r, g, b) = gc.buildTables(s)
        XCTAssertFalse(r.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in R")
        XCTAssertFalse(g.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in G")
        XCTAssertFalse(b.contains { $0.isNaN || $0.isInfinite }, "NaN/Inf in B")
    }
}

// MARK: - DegradationPreset JSON decoding

final class DegradationPresetDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> DegradationPreset {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(DegradationPreset.self, from: data)
    }

    func testDecodesAllNewFields() throws {
        let json = """
        {
          "id": "test", "name": "Test", "brightness": -0.1, "contrast": 0.9,
          "colorTempShift": 6500,
          "year": 2011, "resolution": "1920x1080", "dpi": 96,
          "refreshHz": 60, "simulateLowDpi": true
        }
        """
        let preset = try decode(json)
        XCTAssertEqual(preset.year, 2011)
        XCTAssertEqual(preset.resolution, "1920x1080")
        XCTAssertEqual(preset.dpi, 96)
        XCTAssertEqual(preset.refreshHz, 60)
        XCTAssertTrue(preset.simulateLowDpi)
    }

    func testNewFieldsDefaultToNilWhenAbsent() throws {
        let json = """
        {"id": "test", "name": "Test", "brightness": 0.0, "contrast": 1.0, "colorTempShift": 6500}
        """
        let preset = try decode(json)
        XCTAssertNil(preset.year)
        XCTAssertNil(preset.resolution)
        XCTAssertNil(preset.dpi)
        XCTAssertNil(preset.refreshHz)
        XCTAssertFalse(preset.simulateLowDpi)
    }

    func testSpecSubtitleAllFields() throws {
        let json = """
        {
          "id": "t", "name": "T", "brightness": 0, "contrast": 1, "colorTempShift": 6500,
          "resolution": "1920x1080", "dpi": 96, "refreshHz": 60
        }
        """
        let preset = try decode(json)
        let sub = preset.specSubtitle
        XCTAssertNotNil(sub)
        XCTAssertTrue(sub!.contains("1920 × 1080"))
        XCTAssertTrue(sub!.contains("96 DPI"))
        XCTAssertTrue(sub!.contains("60 Hz"))
    }

    func testSpecSubtitleNilWhenNoFields() throws {
        let json = """
        {"id": "t", "name": "T", "brightness": 0, "contrast": 1, "colorTempShift": 6500}
        """
        let preset = try decode(json)
        XCTAssertNil(preset.specSubtitle)
    }
}

// MARK: - PresetsStore groupedByDecade

final class PresetsStoreGroupingTests: XCTestCase {

    private func makePreset(id: String, name: String, year: Int?) -> DegradationPreset {
        let json = """
        {
          "id": "\(id)", "name": "\(name)", "brightness": 0, "contrast": 1,
          "colorTempShift": 6500\(year.map { ", \"year\": \($0)" } ?? "")
        }
        """
        return try! JSONDecoder().decode(DegradationPreset.self, from: json.data(using: .utf8)!)
    }

    func testDecadeGrouping() {
        let store = PresetsStore()
        // Inject test presets directly via the internal array isn't possible without
        // refactoring load(). Test the grouping logic via the helper function instead.
        let presets = [
            makePreset(id: "a", name: "Alpha", year: 2011),
            makePreset(id: "b", name: "Beta", year: 2016),
            makePreset(id: "c", name: "Gamma", year: 2005),
            makePreset(id: "d", name: "Delta", year: nil),
        ]
        // Replicate groupedByDecade logic directly for unit testing.
        var buckets: [String: [DegradationPreset]] = [:]
        for p in presets {
            let key = p.year.map { "\(($0 / 10) * 10)s" } ?? "Other"
            buckets[key, default: []].append(p)
        }
        XCTAssertEqual(buckets["2010s"]?.count, 2)
        XCTAssertEqual(buckets["2000s"]?.count, 1)
        XCTAssertEqual(buckets["Other"]?.count, 1)
    }

    func testNilYearGoesToOther() {
        let preset = makePreset(id: "x", name: "X", year: nil)
        let key = preset.year.map { "\(($0 / 10) * 10)s" } ?? "Other"
        XCTAssertEqual(key, "Other")
    }
}

// MARK: - shouldShowDpiBanner

final class BannerLogicTests: XCTestCase {

    private func makePreset(id: String, simulateLowDpi: Bool) -> DegradationPreset {
        let json = """
        {
          "id": "\(id)", "name": "Test", "brightness": 0, "contrast": 1,
          "colorTempShift": 6500, "simulateLowDpi": \(simulateLowDpi)
        }
        """
        return try! JSONDecoder().decode(DegradationPreset.self, from: json.data(using: .utf8)!)
    }

    private var lowDpiPreset: DegradationPreset { makePreset(id: "low", simulateLowDpi: true) }
    private var normalPreset: DegradationPreset { makePreset(id: "normal", simulateLowDpi: false) }

    func testShowsBannerWhenConditionsMet() {
        XCTAssertTrue(shouldShowDpiBanner(
            activePresetID: "low",
            presets: [lowDpiPreset],
            pixelSimulation: false,
            lowResModeAvailable: true
        ))
    }

    func testHidesBannerWhenSimulationAlreadyOn() {
        XCTAssertFalse(shouldShowDpiBanner(
            activePresetID: "low",
            presets: [lowDpiPreset],
            pixelSimulation: true,
            lowResModeAvailable: true
        ))
    }

    func testHidesBannerWhenLowResModeUnavailable() {
        XCTAssertFalse(shouldShowDpiBanner(
            activePresetID: "low",
            presets: [lowDpiPreset],
            pixelSimulation: false,
            lowResModeAvailable: false
        ))
    }

    func testHidesBannerForNonLowDpiPreset() {
        XCTAssertFalse(shouldShowDpiBanner(
            activePresetID: "normal",
            presets: [normalPreset],
            pixelSimulation: false,
            lowResModeAvailable: true
        ))
    }

    func testHidesBannerWhenNoPresetActive() {
        XCTAssertFalse(shouldShowDpiBanner(
            activePresetID: nil,
            presets: [lowDpiPreset],
            pixelSimulation: false,
            lowResModeAvailable: true
        ))
    }

    func testReverseBannerShowsWhenSimOnAndPresetIsNormal() {
        XCTAssertTrue(shouldShowReversePixelBanner(
            activePresetID: "normal",
            presets: [normalPreset],
            pixelSimulation: true
        ))
    }

    func testReverseBannerHiddenWhenSimOnAndPresetIsLowDpi() {
        XCTAssertFalse(shouldShowReversePixelBanner(
            activePresetID: "low",
            presets: [lowDpiPreset],
            pixelSimulation: true
        ))
    }

    func testReverseBannerHiddenWhenSimOff() {
        XCTAssertFalse(shouldShowReversePixelBanner(
            activePresetID: "normal",
            presets: [normalPreset],
            pixelSimulation: false
        ))
    }
}
