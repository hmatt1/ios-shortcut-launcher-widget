import XCTest
import SwiftUI

/// Data written by builds that predate fonts, button images and the Shortcuts
/// actions must keep decoding and rendering exactly as before: existing widgets
/// are configured with a preset id, and everything else is read from the
/// stored presets and themes. These fixtures are literal JSON, written the way
/// the 3.4.x builds wrote it, not derived from today's encoder.
@MainActor
final class LegacyConfigurationTests: XCTestCase {

    private let legacyPreset = """
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "name": "Old Preset",
      "columns": 2,
      "marginX": 8, "marginY": 8,
      "spacingX": 6, "spacingY": 6,
      "paddingX": 10, "paddingY": 10,
      "cornerRadius": 10,
      "outerCornerRadius": 10,
      "themeId": "11111111-1111-1111-1111-000000000002",
      "background": "theme"
    }
    """

    /// Older still: no outerCornerRadius, no themeId.
    private let veryOldPreset = """
    {
      "id": "33333333-3333-3333-3333-333333333333",
      "name": "Very Old Preset",
      "columns": 0,
      "marginX": 12, "marginY": 12,
      "spacingX": 9, "spacingY": 9,
      "paddingX": 12, "paddingY": 12,
      "cornerRadius": 13,
      "background": "liquidGlass"
    }
    """

    private func decode(_ json: String) throws -> BoardPreset {
        try JSONDecoder().decode(BoardPreset.self, from: Data(json.utf8))
    }

    func testAPresetFromBeforeFontsDecodesWithItsOriginalValuesAndLook() throws {
        let preset = try decode(legacyPreset)
        XCTAssertEqual(preset.name, "Old Preset")
        XCTAssertEqual(preset.columns, 2)
        XCTAssertEqual(preset.marginX, 8)
        XCTAssertEqual(preset.cornerRadius, 10)
        XCTAssertEqual(preset.outerCornerRadius, 10)
        XCTAssertEqual(preset.background, .theme)
        XCTAssertEqual(preset.themeId, BoardThemeStore.defaultThemeId(for: .midnight))
        XCTAssertEqual(preset.fontFamily, .system, "no font stored means the original system font")
        XCTAssertEqual(preset.fontWeight, .semibold, "and the original semibold weight")
    }

    func testAnEvenOlderPresetStillDecodes() throws {
        let preset = try decode(veryOldPreset)
        XCTAssertEqual(preset.outerCornerRadius, preset.cornerRadius)
        XCTAssertEqual(preset.background, .liquidGlass)
        XCTAssertEqual(preset.fontFamily, .system)
    }

    func testAWholeLegacyStoreDecodesAsOneArray() throws {
        let array = "[\(legacyPreset), \(veryOldPreset)]"
        let presets = try JSONDecoder().decode([BoardPreset].self, from: Data(array.utf8))
        XCTAssertEqual(presets.map(\.name), ["Old Preset", "Very Old Preset"])
    }

    func testALegacyPresetResolvesTheSameBoardAsExplicitSystemSemibold() throws {
        let preset = try decode(legacyPreset)
        for size in BoardSize.allCases {
            for count in [1, 4, 9, 24] {
                let legacy = BoardGrid.resolve(
                    count: count, size: size, longestName: 14, layout: preset.layoutValues,
                    fontFamily: preset.fontFamily, fontWeight: preset.fontWeight
                )
                let original = BoardGrid.resolve(count: count, size: size, longestName: 14, layout: preset.layoutValues)
                XCTAssertEqual(legacy.grid.columns, original.grid.columns)
                XCTAssertEqual(legacy.grid.rows, original.grid.rows)
                XCTAssertEqual(legacy.grid.fontPoints, original.grid.fontPoints)
                XCTAssertEqual(legacy.visibleSlots, original.visibleSlots)
            }
        }
    }

    func testAPresetWithoutImagesRendersTheTextTile() throws {
        let preset = try decode(legacyPreset)
        XCTAssertTrue(ButtonImageStore.buttons(presetId: preset.id).isEmpty, "a preset from before images has none")
        let resolved = BoardGrid.resolve(count: 4, size: .medium, longestName: 6, layout: preset.layoutValues)
        let grid = resolved.grid
        let view = BoardView(grid: grid, count: 4) { index, col, row in
            SlotFace(
                name: BoardSample.names[index], surface: .gray, label: .white, mode: grid.mode, font: grid.font,
                paddingX: grid.layout.paddingX, paddingY: grid.layout.paddingY,
                topLeadingRadius: grid.topLeadingRadius(col: col, row: row),
                bottomLeadingRadius: grid.bottomLeadingRadius(col: col, row: row),
                bottomTrailingRadius: grid.bottomTrailingRadius(col: col, row: row),
                topTrailingRadius: grid.topTrailingRadius(col: col, row: row)
            )
        }
        .frame(width: BoardSize.medium.canvas.width, height: BoardSize.medium.canvas.height)
        XCTAssertNotNil(ImageRenderer(content: view).uiImage)
    }

    func testTheWidgetsConfigurationEntityStillResolvesByPresetId() {
        // Widgets store only the preset's id (BoardPresetEntity, in Widget/).
        let preset = BoardPresetStore.createDefaultPresets()[0]
        let entity = BoardPresetEntity(id: preset.id, name: "whatever name was saved")
        XCTAssertEqual(BoardPresetStore.loadPreset(id: entity.id).id, BoardPresetStore.loadPreset(id: preset.id).id)
    }

    func testAnUnknownPresetIdStillFallsBackToARealPreset() {
        // E.g. a widget pointing at a preset that was since deleted.
        let loaded = BoardPresetStore.loadPreset(id: UUID())
        XCTAssertFalse(loaded.name.isEmpty)
        XCTAssertEqual(loaded.fontFamily, .system)
    }
}
