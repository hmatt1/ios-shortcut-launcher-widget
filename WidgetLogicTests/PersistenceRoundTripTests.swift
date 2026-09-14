import XCTest
@testable import LauncherBoard

/// Codable round-trip fidelity for the current schema, plus the defensive
/// fallbacks `BoardPreset`/`ThemeSpec`'s decoders keep on purpose (see
/// Shared/BoardPreset.swift and Shared/Theme.swift). Their two actual
/// legacy-schema-migration branches were deleted outright rather than
/// tested here - this app has never shipped, so there's no real data
/// anywhere in either old shape to migrate.
final class PersistenceRoundTripTests: XCTestCase {
    func testBoardPresetRoundTripsThroughJSON() throws {
        let original = BoardPresetStore.createDefaultPresets()[0]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BoardPreset.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testBoardThemeRoundTripsThroughJSON() throws {
        let original = BoardThemeStore.createDefaultThemes()[0]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BoardTheme.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMissingOuterCornerRadiusFallsBackToCornerRadius() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json.removeValue(forKey: "outerCornerRadius")
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.outerCornerRadius, decoded.cornerRadius)
    }

    func testUnknownBackgroundStyleFallsBackToTheme() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json["background"] = "someFutureStyleThisBuildDoesNotKnowAboutYet"
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.background, .theme)
    }

    func testMissingThemeIdFallsBackToInk() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json.removeValue(forKey: "themeId")
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.themeId, BoardThemeStore.defaultThemeId(for: .ink))
    }

    func testMissingLabelsFallsBackToTwelveWhiteEntries() throws {
        var json = try themeSpecJSONObject(from: BoardThemeStore.createDefaultThemes()[0].spec)
        json.removeValue(forKey: "labels")
        let decoded = try decodeThemeSpec(json)
        XCTAssertEqual(decoded.labels.count, 12)
        XCTAssertTrue(decoded.labels.allSatisfy { $0 == RGB(0xFFFFFF) })
    }

    func testCorruptedLabelsFallsBackToTwelveWhiteEntries() throws {
        var json = try themeSpecJSONObject(from: BoardThemeStore.createDefaultThemes()[0].spec)
        json["labels"] = "not an array at all"
        let decoded = try decodeThemeSpec(json)
        XCTAssertEqual(decoded.labels.count, 12)
        XCTAssertTrue(decoded.labels.allSatisfy { $0 == RGB(0xFFFFFF) })
    }

    // MARK: - Helpers

    private func presetJSONObject(from preset: BoardPreset) throws -> [String: Any] {
        let data = try JSONEncoder().encode(preset)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodePreset(_ json: [String: Any]) throws -> BoardPreset {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(BoardPreset.self, from: data)
    }

    private func themeSpecJSONObject(from spec: ThemeSpec) throws -> [String: Any] {
        let data = try JSONEncoder().encode(spec)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodeThemeSpec(_ json: [String: Any]) throws -> ThemeSpec {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ThemeSpec.self, from: data)
    }
}
