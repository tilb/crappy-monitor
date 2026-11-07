import XCTest
@testable import CrappyMonitor

/// Table tests for the window-layout rules (PRD §5.4, task T12).
final class WindowLayoutTests: XCTestCase {
    private let normal = CGRect(x: 100, y: 200, width: 1040, height: 730)
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
    private var compact: CGRect { WindowLayout.anchoredTopLeft(normal, size: WindowLayout.compactSize) }

    func testCollapsingByHandShrinksAndShowingRestores() {
        var l = WindowLayout()
        XCTAssertEqual(l.toggleStrip(current: normal), compact)
        XCTAssertTrue(l.stripCollapsed)
        XCTAssertEqual(l.toggleStrip(current: compact), normal, "the old size comes back, top-left kept")
        XCTAssertFalse(l.stripCollapsed)
    }

    func testZoomFillsAndCollapsesTheStripThenRestores() {
        var l = WindowLayout()
        XCTAssertEqual(l.toggleZoom(current: normal, visible: visible), visible)
        XCTAssertTrue(l.stripCollapsed, "zoomed: strip collapses automatically")
        XCTAssertEqual(l.toggleZoom(current: visible, visible: visible), normal)
        XCTAssertFalse(l.stripCollapsed, "un-zoomed: strip back")
    }

    func testCollapsingWhileZoomedDoesNotShrink() {
        var l = WindowLayout()
        _ = l.toggleZoom(current: normal, visible: visible)
        XCTAssertNil(l.toggleStrip(current: visible), "show strip while zoomed: no frame change")
        XCTAssertFalse(l.stripCollapsed)
        XCTAssertNil(l.toggleStrip(current: visible))
        XCTAssertTrue(l.stripCollapsed)
    }

    func testManualChoiceWhileZoomedHoldsUntilUnzoomed() {
        var l = WindowLayout()
        _ = l.toggleZoom(current: normal, visible: visible)
        _ = l.toggleStrip(current: visible)                  // show the strip while zoomed
        XCTAssertFalse(l.stripCollapsed)
        _ = l.toggleZoom(current: visible, visible: visible) // un-zoom
        _ = l.toggleZoom(current: normal, visible: visible)  // zoom again: automatic again
        XCTAssertTrue(l.stripCollapsed)
    }

    func testZoomFromCompactRestoresCompact() {
        var l = WindowLayout()
        _ = l.toggleStrip(current: normal)                   // compact
        XCTAssertEqual(l.toggleZoom(current: compact, visible: visible), visible)
        XCTAssertTrue(l.stripCollapsed)
        _ = l.toggleStrip(current: visible)                  // show strip while zoomed
        XCTAssertEqual(l.toggleZoom(current: visible, visible: visible), compact, "earlier frame")
        XCTAssertTrue(l.stripCollapsed, "earlier strip state")
        XCTAssertEqual(l.toggleStrip(current: compact), normal, "and the size from before compact")
    }

    func testMovingAZoomedWindowEndsTheZoomInPlace() {
        var l = WindowLayout()
        _ = l.toggleZoom(current: normal, visible: visible)
        l.userChangedFrame(visible, visible: visible)
        XCTAssertTrue(l.zoomed, "our own zoom frame is not a user change")
        let dragged = visible.offsetBy(dx: 40, dy: -30)
        l.userChangedFrame(dragged, visible: visible)
        XCTAssertFalse(l.zoomed)
        XCTAssertFalse(l.stripCollapsed)
        XCTAssertEqual(l.toggleZoom(current: dragged, visible: visible), visible, "zooming again starts from here")
        XCTAssertEqual(l.toggleZoom(current: visible, visible: visible), dragged)
    }

    func testUserResizingANormalWindowChangesNothing() {
        var l = WindowLayout()
        l.userChangedFrame(normal.insetBy(dx: 10, dy: 10), visible: visible)
        XCTAssertEqual(l, WindowLayout())
    }
}

final class FirstRunTests: XCTestCase {
    typealias P = ScreenRecordingPermission

    func testFirstRunShowsTheIntro() {
        XCTAssertEqual(P.step(active: false, granted: false, continued: false), .welcome)
    }

    func testAfterContinueItExplainsSystemSettings() {
        XCTAssertEqual(P.step(active: false, granted: false, continued: true), .askSettings)
    }

    func testGrantedButNotActiveOffersRelaunch() {
        XCTAssertEqual(P.step(active: false, granted: true, continued: true), .relaunch)
        XCTAssertEqual(P.step(active: false, granted: true, continued: false), .relaunch)
    }

    func testActivePermissionGoesStraightToTheLens() {
        XCTAssertEqual(P.step(active: true, granted: true, continued: false), .lens, "Quit & Reopen lands in the lens")
        XCTAssertEqual(P.step(active: true, granted: false, continued: true), .lens)
    }
}
