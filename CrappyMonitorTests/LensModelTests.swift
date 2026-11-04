import XCTest
@testable import CrappyMonitor

/// Lens window state (PRD §5): favourites, search, Adjust edits.
final class LensModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "com.crappymonitor.tests.lens"
    private var library: MonitorLibrary!

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        library = try MonitorLibrary.bundled(Bundle(for: AppDelegate.self))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeModel() -> LensModel { LensModel(library: library, defaults: defaults) }

    func testFirstRunStartsOnRankOneWithRanksTwoToFiveAsFavourites() {
        let model = makeModel()
        XCTAssertEqual(model.activeID, "dell-p2419h")
        XCTAssertEqual(model.favourites, Array(library.monitors.map(\.id)[1...4]))
        XCTAssertEqual(model.age, .six)
    }

    func testChoicesSurviveARelaunch() {
        let model = makeModel()
        model.use("eizo-ev2450")
        model.age = .ten
        model.removeFavourite(model.favourites[0])
        let again = makeModel()
        XCTAssertEqual(again.activeID, "eizo-ev2450")
        XCTAssertEqual(again.age, .ten)
        XCTAssertEqual(again.favourites, model.favourites)
    }

    func testUnknownSavedIDsAreDropped() {
        defaults.set("samsung-s24f350", forKey: "lens.activeID")
        defaults.set(["philips-241v8", "dell-u2412m"], forKey: "lens.favourites")
        let model = makeModel()
        XCTAssertEqual(model.activeID, "dell-p2419h")
        XCTAssertEqual(model.favourites, ["dell-u2412m"])
    }

    func testAdjustEditsOnlyAffectTheActiveMonitorAndResetOnSwitch() {
        let model = makeModel()
        let other = model.favourites[0]
        let before = model.filter(for: other)
        model.edits.contrastRatio = 300
        XCTAssertEqual(model.activeFilter?.blackFloor ?? 0, 1.0 / 300, accuracy: 1e-12)
        XCTAssertEqual(model.filter(for: other), before)
        XCTAssertTrue(model.isEdited)

        model.use(other)
        XCTAssertFalse(model.isEdited)
    }

    func testAgeReachesEveryFilter() {
        let model = makeModel()
        model.age = .ten
        XCTAssertEqual(model.lensFilter?.age, .ten)
        XCTAssertEqual(model.filter(for: model.favourites[0])?.age, .ten)
    }

    func testLensShowsTheActiveMonitorUnlessTheSnapshotTourPreviews() {
        let model = makeModel()
        XCTAssertEqual(model.lensFilter?.profile.id, model.activeID)
        model.previewID = "lenovo-lt2252p"
        XCTAssertEqual(model.lensFilter?.profile.id, "lenovo-lt2252p")
        model.leftStrip()
        XCTAssertEqual(model.lensFilter?.profile.id, model.activeID)
    }

    func testOptionShowsTheOriginal() {
        let model = makeModel()
        XCTAssertFalse(model.showsOriginal)
        model.optionHeld = true
        XCTAssertTrue(model.showsOriginal)
    }

    func testSearchSplitsFavouritesAndOthers() {
        let model = makeModel()
        model.searchText = "dell"
        let r = model.searchResults()
        XCTAssertEqual(r.favourites.map(\.id), ["dell-u2412m", "dell-p2417h"])
        XCTAssertEqual(r.others.map(\.id), ["dell-p2419h"])
        XCTAssertEqual(model.stripFavourites, ["dell-u2412m", "dell-p2417h"])
    }

    func testSearchShowsFourOthersUntilAskedForAll() {
        let model = makeModel()
        model.searchText = " "
        let r = model.searchResults()
        XCTAssertEqual(r.others.count, 4)
        XCTAssertEqual(r.hiddenCount, library.monitors.count - model.favourites.count - 4)
        model.openBrowseAll()
        XCTAssertEqual(model.searchResults().hiddenCount, 0)
    }

    func testSearchSelectionWrapsAndUses() {
        let model = makeModel()
        model.searchText = "dell"
        model.moveSearchSelection(-1)
        XCTAssertEqual(model.searchSelection, 2)
        model.useSearchSelection()
        XCTAssertEqual(model.activeID, "dell-p2419h")
        XCTAssertEqual(model.searchText, "")
        XCTAssertFalse(model.resultsVisible)
    }

    func testMoveAndFavouriteShortcuts() {
        let model = makeModel()
        let first = model.favourites[0], second = model.favourites[1]
        model.move(first, by: 1)
        XCTAssertEqual(Array(model.favourites.prefix(2)), [second, first])
        model.move(second, by: -1)
        XCTAssertEqual(model.favourites[0], second, "moving past the start does nothing")
        model.useFavourite(at: 0)
        XCTAssertEqual(model.activeID, second)
    }

    func testIssueLinksNameTheMonitorAndAge() {
        let model = makeModel()
        let url = model.reportURL(for: "dell-p2419h").absoluteString
        XCTAssertTrue(url.contains("Dell%20P2419H"), url)
        XCTAssertTrue(url.contains("6%20years"), url)
    }
}
