import XCTest
@testable import CrappyMonitor

// Lens prototype — delete together with CrappyMonitor/LensPrototype/.
final class LensPrototypeTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "com.crappymonitor.tests.lens"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeModel() -> (LensModel, FilterSettings) {
        let fs = FilterSettings()
        return (LensModel(presetsStore: PresetsStore(), filterSettings: fs, defaults: defaults), fs)
    }

    // MARK: Age

    func testNewAgeChangesNothing() {
        var p = LensParams()
        p.brightness = -0.1; p.contrast = 0.9; p.colorTemp = 7000; p.blackLevel = 0.02
        XCTAssertEqual(p.aged(.new), p)
    }

    func testSixYearsFollowsHandoffFormula() {
        let aged = LensParams().aged(.six)
        XCTAssertEqual(aged.brightness, -0.09, accuracy: 1e-9)
        XCTAssertEqual(aged.contrast, 0.88, accuracy: 1e-9)
        XCTAssertEqual(aged.colorTemp, 6140, accuracy: 1e-9)
        XCTAssertEqual(aged.blackLevel, 0.024, accuracy: 1e-9)
    }

    func testAgeStaysInsideSliderRanges() {
        var p = LensParams()
        p.brightness = -0.95; p.contrast = 0.55; p.colorTemp = 3100; p.blackLevel = 0.14
        let aged = p.aged(.ten)
        XCTAssertEqual(aged.brightness, -1.0)
        XCTAssertEqual(aged.contrast, 0.5)
        XCTAssertEqual(aged.colorTemp, 3000)
        XCTAssertEqual(aged.blackLevel, 0.15)
    }

    // MARK: One filter, two pipelines

    func testWholeScreenGetsTheSameTablesAsTheLens() {
        let (model, fs) = makeModel()
        model.age = .ten
        model.overrides.contrast = 0.7
        model.mode = .wholeScreen

        XCTAssertTrue(fs.isEnabled)
        XCTAssertEqual(fs.activePresetID, model.activeID)
        let lens = model.lensParams.tables()
        let whole = GammaController().buildTables(fs)
        XCTAssertEqual(lens.r, whole.0)
        XCTAssertEqual(lens.g, whole.1)
        XCTAssertEqual(lens.b, whole.2)
    }

    func testLensModeTurnsDisplayGammaOff() {
        let (model, fs) = makeModel()
        model.mode = .wholeScreen
        XCTAssertTrue(fs.isEnabled)
        model.mode = .lens
        XCTAssertFalse(fs.isEnabled, "lens captures the clean screen; gamma on top would degrade it twice")
    }

    // MARK: Model behaviour

    func testAdjustEditsOnlyAffectTheActiveMonitorAndResetOnSwitch() {
        let (model, _) = makeModel()
        let other = model.favourites.first { $0 != model.activeID }!
        let before = model.params(for: other)
        model.overrides.brightness = -0.5
        XCTAssertEqual(model.activeParams.brightness, -0.5)
        XCTAssertEqual(model.params(for: other), before)
        XCTAssertTrue(model.isEdited)

        model.use(other)
        XCTAssertFalse(model.isEdited)
    }

    func testPreviewWinsOverActiveInTheLens() {
        let (model, _) = makeModel()
        let other = model.favourites.first { $0 != model.activeID }!
        model.previewID = other
        XCTAssertEqual(model.lensParams, model.params(for: other))
        model.leftStrip()
        XCTAssertEqual(model.lensParams, model.activeParams)
    }

    func testSearchSplitsFavouritesAndOthers() {
        let (model, _) = makeModel()
        model.searchText = "phil"
        let r = model.searchResults()
        XCTAssertEqual(r.favourites.map(\.id), ["philips-241v8"])
        XCTAssertTrue(r.others.isEmpty, "medical IntelliVue presets have no specs and stay out of the lens")
        XCTAssertEqual(model.stripFavourites, ["philips-241v8"])
    }

    func testMoveAndFavouriteShortcuts() {
        let (model, _) = makeModel()
        let first = model.favourites[0], second = model.favourites[1]
        model.move(first, by: 1)
        XCTAssertEqual(Array(model.favourites.prefix(2)), [second, first])
        model.useFavourite(at: 0)
        XCTAssertEqual(model.activeID, second)
    }

    func testPresetsHaveEnoughSpecBasedMonitors() {
        let monitors = PresetsStore().presets.filter { $0.panelType != nil }
        XCTAssertGreaterThanOrEqual(monitors.count, 6)
        for m in monitors {
            XCTAssertNotNil(m.shortName, m.id)
            XCTAssertNotNil(m.sizeInches, m.id)
        }
    }
}
