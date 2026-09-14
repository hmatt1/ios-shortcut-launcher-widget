import XCTest
import SwiftUI
@testable import LauncherBoard

/// `SidePanel<PanelContent>.draggedBack`/`.releaseAction` - the pure
/// decision logic behind the panel's drag-to-dismiss gesture
/// (App/SidePanel.swift), factored out so it's testable without a live
/// gesture/view hierarchy. Neither function actually uses the generic
/// `PanelContent` parameter, so any concrete type works here - `EmptyView`
/// is the simplest.
final class SidePanelLogicTests: XCTestCase {
    private typealias Panel = SidePanel<EmptyView>

    // MARK: - draggedBack

    func testDraggedBackForLeadingEdgePullsLeftward() {
        let result = Panel.draggedBack(translation: CGSize(width: -40, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(result, 40)
    }

    func testDraggedBackForTrailingEdgePullsRightward() {
        let result = Panel.draggedBack(translation: CGSize(width: 40, height: 0), edge: .trailing, width: 300)
        XCTAssertEqual(result, 40)
    }

    func testDraggedBackClampsToZeroWhenPushedThePresentingDirection() {
        // A leading panel dragged further open (positive/rightward) should
        // never go negative.
        let result = Panel.draggedBack(translation: CGSize(width: 40, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(result, 0)
    }

    func testDraggedBackClampsToWidthWhenPulledPastFullyClosed() {
        let result = Panel.draggedBack(translation: CGSize(width: -1000, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(result, 300)
    }

    func testDraggedBackReturnsNilForAVerticalDominantDrag() {
        let result = Panel.draggedBack(translation: CGSize(width: -10, height: 30), edge: .leading, width: 300)
        XCTAssertNil(result, "a mostly-vertical drag (e.g. scrolling the panel's own List) shouldn't move the panel")
    }

    func testDraggedBackHorizontalDominanceRatioIsStrict() {
        // horizontal must be STRICTLY greater than 1.5x vertical.
        let atRatio = Panel.draggedBack(translation: CGSize(width: -15, height: 10), edge: .leading, width: 300)
        XCTAssertNil(atRatio, "exactly 1.5x should not count as horizontal-dominant")
        let justOver = Panel.draggedBack(translation: CGSize(width: -15.1, height: 10), edge: .leading, width: 300)
        XCTAssertNotNil(justOver)
    }

    // MARK: - releaseAction

    func testReleaseActionClosesPastThirtyPercentThreshold() {
        let action = Panel.releaseAction(translation: CGSize(width: -100, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(action, .close)
    }

    func testReleaseActionSnapsBackUnderThirtyPercentThreshold() {
        let action = Panel.releaseAction(translation: CGSize(width: -50, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(action, .snapBack)
    }

    func testReleaseActionForTrailingEdgeUsesOppositeSign() {
        let closes = Panel.releaseAction(translation: CGSize(width: 100, height: 0), edge: .trailing, width: 300)
        XCTAssertEqual(closes, .close)
        let snapsBack = Panel.releaseAction(translation: CGSize(width: -100, height: 0), edge: .trailing, width: 300)
        XCTAssertEqual(snapsBack, .snapBack, "dragging a trailing panel further open should snap back, not close")
    }

    func testReleaseActionExactlyAtThresholdSnapsBack() {
        // pull > width * 0.3 is strict - exactly 30% should not close.
        let action = Panel.releaseAction(translation: CGSize(width: -90, height: 0), edge: .leading, width: 300)
        XCTAssertEqual(action, .snapBack)
    }
}
