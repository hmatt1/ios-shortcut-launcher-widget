import XCTest

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

    func testFontRoundTripsThroughJSON() throws {
        var original = BoardPresetStore.createDefaultPresets()[0]
        original.fontFamily = .avenirNext
        original.fontWeight = .bold
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BoardPreset.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.fontFamily, .avenirNext)
        XCTAssertEqual(decoded.fontWeight, .bold)
    }

    func testMissingFontKeysFallBackToSystemSemibold() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json.removeValue(forKey: "fontFamily")
        json.removeValue(forKey: "fontWeight")
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.fontFamily, .system)
        XCTAssertEqual(decoded.fontWeight, .semibold)
    }

    func testUnknownFontValuesFallBackWithoutThrowing() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json["fontFamily"] = "someFutureFontThisBuildDoesNotKnowAboutYet"
        json["fontWeight"] = "ultraBlack"
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.fontFamily, .system)
        XCTAssertEqual(decoded.fontWeight, .semibold)

        json["fontFamily"] = 42
        json["fontWeight"] = ["not", "a", "string"]
        let wrongType = try decodePreset(json)
        XCTAssertEqual(wrongType.fontFamily, .system)
        XCTAssertEqual(wrongType.fontWeight, .semibold)
    }

    func testBuiltInPresetsKeepTheOriginalSystemSemiboldLook() {
        for preset in BoardPresetStore.createDefaultPresets() {
            XCTAssertEqual(preset.fontFamily, .system, preset.name)
            XCTAssertEqual(preset.fontWeight, .semibold, preset.name)
        }
    }

    func testMissingThemeIdFallsBackToInk() throws {
        var json = try presetJSONObject(from: BoardPresetStore.createDefaultPresets()[0])
        json.removeValue(forKey: "themeId")
        let decoded = try decodePreset(json)
        XCTAssertEqual(decoded.themeId, BoardThemeStore.defaultThemeId(for: .ink))
    }

    func testMissingLabelsFallsBackToTwelveWhiteEntries() throws {
        var json = try themeSpecJSONObject(from: BoardThemeStore.createDefaultThemes()[0].spec)
        json.removeValue(forKey: "label")
        let decoded = try decodeThemeSpec(json)
        XCTAssertEqual(decoded.labels.count, 12)
        XCTAssertTrue(decoded.labels.allSatisfy { $0 == RGB(0xFFFFFF) })
    }

    func testCorruptedLabelsFallsBackToTwelveWhiteEntries() throws {
        var json = try themeSpecJSONObject(from: BoardThemeStore.createDefaultThemes()[0].spec)
        json["label"] = "not an array at all"
        let decoded = try decodeThemeSpec(json)
        XCTAssertEqual(decoded.labels.count, 12)
        XCTAssertTrue(decoded.labels.allSatisfy { $0 == RGB(0xFFFFFF) })
    }

    func testLegacyLabelKeyAndInterimLabelsKeyBothDecode() throws {
        let spec = BoardThemeStore.createDefaultThemes()[0].spec
        var json = try themeSpecJSONObject(from: spec)
        XCTAssertNotNil(json["label"], "encoder must keep writing the shipped \"label\" key")
        XCTAssertEqual(try decodeThemeSpec(json).labels, spec.labels)
        json["labels"] = json.removeValue(forKey: "label")
        XCTAssertEqual(try decodeThemeSpec(json).labels, spec.labels)
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
