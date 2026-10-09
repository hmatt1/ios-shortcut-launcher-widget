import XCTest

/// `DensityTemplate.apply(to:)` / `matching(_:)` (shared by the editor and the
/// Update Preset action) and the property summary Shortcuts reads from a preset.
final class DensityApplyTests: XCTestCase {

    private var base: BoardPreset {
        var preset = BoardPresetStore.createDefaultPresets()[0]
        preset.columns = 3
        return preset
    }

    func testApplySetsTheEightLayoutFieldsAndLeavesColumnsAlone() {
        for template in DensityTemplate.all {
            var preset = base
            template.apply(to: &preset)
            XCTAssertEqual(preset.marginX, template.layout.marginX, template.id)
            XCTAssertEqual(preset.marginY, template.layout.marginY, template.id)
            XCTAssertEqual(preset.spacingX, template.layout.spacingX, template.id)
            XCTAssertEqual(preset.spacingY, template.layout.spacingY, template.id)
            XCTAssertEqual(preset.paddingX, template.layout.paddingX, template.id)
            XCTAssertEqual(preset.paddingY, template.layout.paddingY, template.id)
            XCTAssertEqual(preset.cornerRadius, template.layout.cornerRadius, template.id)
            XCTAssertEqual(preset.outerCornerRadius, template.layout.outerCornerRadius, template.id)
            XCTAssertEqual(preset.columns, 3, "columns are not part of a density")
        }
    }

    func testApplyDoesNotTouchNonLayoutFields() {
        var preset = base
        preset.fontFamily = .georgia
        let before = preset
        DensityTemplate.all[0].apply(to: &preset)
        XCTAssertEqual(preset.fontFamily, before.fontFamily)
        XCTAssertEqual(preset.themeId, before.themeId)
        XCTAssertEqual(preset.name, before.name)
    }

    func testMatchingFindsEveryTemplateAfterApplying() {
        for template in DensityTemplate.all {
            var preset = base
            template.apply(to: &preset)
            XCTAssertEqual(DensityTemplate.matching(preset)?.id, template.id)
        }
    }

    func testMatchingIsNilForAHandTunedLayout() {
        var preset = base
        DensityTemplate.all[2].apply(to: &preset)
        preset.marginX += 1
        XCTAssertNil(DensityTemplate.matching(preset))
    }

    func testEveryDensityChoiceMapsToATemplate() {
        for choice in PresetDensity.allCases {
            XCTAssertEqual(choice.template.id, choice.rawValue)
        }
        XCTAssertEqual(PresetDensity.allCases.count, DensityTemplate.all.count)
    }

    func testPresetEditAppliesDensityBeforeExplicitLayoutFields() {
        var edit = PresetEdit()
        edit.density = .flush
        edit.marginX = 20
        let result = edit.applying(to: base)
        XCTAssertEqual(result.marginX, 20, "an explicit field wins over the density")
        XCTAssertEqual(result.marginY, DensityTemplate.all[0].layout.marginY)
    }

    func testPresetSummaryNamesTheDensityOrCustom() {
        var preset = base
        DensityTemplate.all[1].apply(to: &preset)
        XCTAssertEqual(PresetSummary(preset, themeName: "Midnight").density, "Hairline")
        preset.spacingX += 1
        XCTAssertEqual(PresetSummary(preset, themeName: "Midnight").density, "Custom")
    }

    func testPresetSummaryReportsTheSettings() {
        var preset = base
        preset.fontFamily = .menlo
        preset.fontWeight = .bold
        preset.background = .liquidGlass
        let summary = PresetSummary(preset, themeName: "Ember")
        XCTAssertEqual(summary.name, preset.name)
        XCTAssertEqual(summary.themeName, "Ember")
        XCTAssertEqual(summary.fontFamily, .menlo)
        XCTAssertEqual(summary.fontWeight, .bold)
        XCTAssertEqual(summary.background, .liquidGlass)
        XCTAssertEqual(summary.columns, 3)
        XCTAssertEqual(summary.marginX, Int(preset.marginX))
        XCTAssertEqual(summary.outerCornerRadius, Int(preset.outerCornerRadius))
    }
}
