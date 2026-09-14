import XCTest
@testable import LauncherBoard

/// `CustomStepper.clamped(_:advancingBy:range:)` and
/// `PresetEditorView.edgeSwipeAction(...)`/`.currentTemplateName`
/// (App/PresetEditor.swift) - all previously `private`-scoped logic inline
/// inside SwiftUI closures, extracted so they're directly testable without
/// driving the real UI. `applyTemplate` is not covered here - see the
/// comment above `testCurrentTemplateNameMatchesEveryDensityTemplateViaARealPreset`.
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

    // MARK: - currentTemplateName

    // Not tested here, and not an oversight: a real CI run proved that
    // mutating a `@State` property (`preset`) via a method called directly
    // on a manually-constructed `PresetEditorView` - bypassing SwiftUI's own
    // render cycle entirely - does not reliably persist to a later property
    // read on that same instance (`applyTemplate` then `currentTemplateName`
    // always saw the ORIGINAL preset, for every template, in the actual CI
    // run this was first tried in). `@State`'s storage evidently isn't
    // guaranteed live outside SwiftUI's real view graph, whatever the
    // in-process appearance suggested. `currentTemplateName`'s matching
    // logic is still fully covered below, through the one construction path
    // that DID prove reliable - reading a `@State` value assigned at
    // `init` time, never mutated afterward - which is exactly how
    // `testCurrentTemplateNameReturnsCustomForANonTemplateMatchingPreset`
    // already worked (and passed) even before this was discovered.
    // `applyTemplate` itself (a direct, unconditional field-by-field
    // assignment with no branching to get wrong) is left unverified by an
    // automated test for this same reason.
    func testCurrentTemplateNameMatchesEveryDensityTemplateViaARealPreset() {
        let store = BoardPresetStore.shared
        for template in DensityTemplate.all {
            let created = store.create(name: "PresetEditorLogicTests-\(template.id)")
            var withTemplateLook = created
            withTemplateLook.marginX = template.layout.marginX
            withTemplateLook.marginY = template.layout.marginY
            withTemplateLook.spacingX = template.layout.spacingX
            withTemplateLook.spacingY = template.layout.spacingY
            withTemplateLook.paddingX = template.layout.paddingX
            withTemplateLook.paddingY = template.layout.paddingY
            withTemplateLook.cornerRadius = template.layout.cornerRadius
            withTemplateLook.outerCornerRadius = template.layout.outerCornerRadius
            store.update(withTemplateLook)
            defer { store.delete(id: created.id) }

            let view = PresetEditorView(presetId: created.id)
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
