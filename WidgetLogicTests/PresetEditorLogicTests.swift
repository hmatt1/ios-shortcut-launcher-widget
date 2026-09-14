import XCTest
@testable import LauncherBoard

/// `CustomStepper.clamped(_:advancingBy:range:)` and
/// `PresetEditorView.edgeSwipeAction(...)`/`.applyTemplate`/
/// `.currentTemplateName` (App/PresetEditor.swift) - all previously
/// `private`-scoped logic inline inside SwiftUI closures, extracted so
/// they're directly testable without driving the real UI.
@MainActor
final class PresetEditorLogicTests: XCTestCase {
    // MARK: - CustomStepper.clamped

    func testClampedStaysInRangeForAnOrdinaryStep() {
        XCTAssertEqual(CustomStepper<Int>.clamped(5, advancingBy: 1, range: 0...10), 6)
        XCTAssertEqual(CustomStepper<Int>.clamped(5, advancingBy: -1, range: 0...10), 4)
    }

    func testClampedStopsAtTheLowerBound() {
        XCTAssertEqual(CustomStepper<Int>.clamped(0, advancingBy: -1, range: 0...10), 0)
    }

    func testClampedStopsAtTheUpperBound() {
        XCTAssertEqual(CustomStepper<Int>.clamped(10, advancingBy: 1, range: 0...10), 10)
    }

    func testClampedNeverOvershootsPastTheBoundInOneStep() {
        // A step larger than the remaining room should still land exactly
        // on the bound, not past it.
        XCTAssertEqual(CustomStepper<Int>.clamped(9, advancingBy: 5, range: 0...10), 10)
        XCTAssertEqual(CustomStepper<Int>.clamped(1, advancingBy: -5, range: 0...10), 0)
    }

    func testClampedWorksForCGFloatToo() {
        XCTAssertEqual(CustomStepper<CGFloat>.clamped(38, advancingBy: 4, range: 0...40), 40)
    }

    // MARK: - PresetEditorView.edgeSwipeAction

    func testEdgeSwipeOpensPresetsFromNearLeftEdge() {
        let action = PresetEditorView.edgeSwipeAction(
            startLocationX: 10, translation: CGSize(width: 60, height: 0), containerWidth: 300
        )
        XCTAssertEqual(action, .openPresets)
    }

    func testEdgeSwipeOpensThemesFromNearRightEdge() {
        let action = PresetEditorView.edgeSwipeAction(
            startLocationX: 290, translation: CGSize(width: -60, height: 0), containerWidth: 300
        )
        XCTAssertEqual(action, .openThemes)
    }

    func testEdgeSwipeDoesNothingFromTheCenterOfTheScreen() {
        let action = PresetEditorView.edgeSwipeAction(
            startLocationX: 150, translation: CGSize(width: 60, height: 0), containerWidth: 300
        )
        XCTAssertEqual(action, .none)
    }

    func testEdgeSwipeDoesNothingUnderTheTriggerDistance() {
        let action = PresetEditorView.edgeSwipeAction(
            startLocationX: 10, translation: CGSize(width: 40, height: 0), containerWidth: 300
        )
        XCTAssertEqual(action, .none, "a drag under the 50pt trigger distance shouldn't open anything")
    }

    func testEdgeSwipeDoesNothingForAVerticalDominantDragEvenNearAnEdge() {
        let action = PresetEditorView.edgeSwipeAction(
            startLocationX: 10, translation: CGSize(width: 60, height: 50), containerWidth: 300
        )
        XCTAssertEqual(action, .none, "a mostly-vertical drag shouldn't open anything, even starting at the edge")
    }

    /// This is exactly the bug the iPad width fix addressed: with the real
    /// container width passed in (not a hardcoded screen size), a touch
    /// starting near the edge of a NARROWER window (e.g. iPad Split View)
    /// still correctly resolves against that window's own edge.
    func testEdgeSwipeUsesTheProvidedContainerWidthNotAFixedScreenSize() {
        let narrowWindow = PresetEditorView.edgeSwipeAction(
            startLocationX: 390, translation: CGSize(width: -60, height: 0), containerWidth: 400
        )
        XCTAssertEqual(narrowWindow, .openThemes, "390 is near the right edge of a 400pt-wide window")

        let sameStartInAWiderWindow = PresetEditorView.edgeSwipeAction(
            startLocationX: 390, translation: CGSize(width: -60, height: 0), containerWidth: 1200
        )
        XCTAssertEqual(sameStartInAWiderWindow, .none, "390 is nowhere near the right edge of a 1200pt-wide window")
    }

    // MARK: - applyTemplate / currentTemplateName

    func testApplyTemplateThenCurrentTemplateNameRoundTripsForEveryTemplate() {
        let view = PresetEditorView(presetId: UUID())
        for template in DensityTemplate.all {
            view.applyTemplate(template)
            XCTAssertEqual(view.currentTemplateName, template.name)
        }
    }

    func testCurrentTemplateNameReturnsCustomForANonTemplateMatchingPreset() {
        BoardPresetStore.shared.restoreDefaultPresets()
        // "Slate" uses Flush's margin/spacing/padding but overrides
        // cornerRadius to 0 (Shared/BoardPresetStore.swift's showcases) -
        // it matches no DensityTemplate exactly.
        guard let slate = BoardPresetStore.shared.presets.first(where: { $0.name == "Slate" }) else {
            return XCTFail("expected the built-in 'Slate' preset to be present after restoreDefaultPresets()")
        }
        let view = PresetEditorView(presetId: slate.id)
        XCTAssertEqual(view.currentTemplateName, "Custom")
    }
}
