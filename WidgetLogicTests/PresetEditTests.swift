import XCTest

/// The pure logic behind the "Update Preset" and button-image Shortcuts actions.
final class PresetEditTests: XCTestCase {

    private var base: BoardPreset { BoardPresetStore.createDefaultPresets()[0] }

    func testAnEmptyEditChangesNothing() {
        XCTAssertEqual(PresetEdit().applying(to: base), base)
    }

    func testOnlyGivenFieldsChange() {
        var edit = PresetEdit()
        edit.columns = 3
        edit.fontFamily = .georgia
        let result = edit.applying(to: base)
        var expected = base
        expected.columns = 3
        expected.fontFamily = .georgia
        XCTAssertEqual(result, expected)
    }

    func testValuesAreClampedToTheEditorRanges() {
        var edit = PresetEdit()
        edit.columns = 99
        edit.marginX = -5
        edit.spacingY = 500
        edit.cornerRadius = 100
        edit.outerCornerRadius = -1
        let result = edit.applying(to: base)
        XCTAssertEqual(result.columns, 12)
        XCTAssertEqual(result.marginX, 0)
        XCTAssertEqual(result.spacingY, 40)
        XCTAssertEqual(result.cornerRadius, 32)
        XCTAssertEqual(result.outerCornerRadius, 0)
    }

    func testNameIsTrimmedAndBlankNamesAreIgnored() {
        var edit = PresetEdit()
        edit.name = "  Posters  "
        XCTAssertEqual(edit.applying(to: base).name, "Posters")
        edit.name = "   "
        XCTAssertEqual(edit.applying(to: base).name, base.name)
    }

    func testFontWeightAndBackgroundApply() {
        var edit = PresetEdit()
        edit.fontWeight = .bold
        edit.background = .transparent
        let result = edit.applying(to: base)
        XCTAssertEqual(result.fontWeight, .bold)
        XCTAssertEqual(result.background, .transparent)
    }

    func testThemeApplies() {
        let theme = BoardThemeStore.createDefaultThemes()[3]
        var edit = PresetEdit()
        edit.themeId = theme.id
        XCTAssertEqual(edit.applying(to: base).themeId, theme.id)
    }

    func testButtonNumbersAreValidatedOneThroughMaxSlots() throws {
        XCTAssertEqual(try PresetIntentError.validatedButton(1), 1)
        XCTAssertEqual(try PresetIntentError.validatedButton(BoardGrid.maxSlots), BoardGrid.maxSlots)
        XCTAssertThrowsError(try PresetIntentError.validatedButton(0))
        XCTAssertThrowsError(try PresetIntentError.validatedButton(BoardGrid.maxSlots + 1))
    }
}
