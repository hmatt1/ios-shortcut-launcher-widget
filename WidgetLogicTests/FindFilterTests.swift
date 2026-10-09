import XCTest

/// The name filter behind the Find Presets / Find Themes actions and the
/// entity pickers' search.
final class FindFilterTests: XCTestCase {

    private let names = ["Ember", "Midnight", "Café Au Lait", "ember glow", "Frost"]

    private func filter(_ text: String?) -> [String] {
        NameFilter.matching(names, name: { $0 }, containing: text)
    }

    func testNilEmptyAndBlankFiltersReturnEverythingInOrder() {
        XCTAssertEqual(filter(nil), names)
        XCTAssertEqual(filter(""), names)
        XCTAssertEqual(filter("   "), names)
    }

    func testMatchesPartialNamesIgnoringCase() {
        XCTAssertEqual(filter("ember"), ["Ember", "ember glow"])
        XCTAssertEqual(filter("NIGHT"), ["Midnight"])
        XCTAssertEqual(filter("ros"), ["Frost"])
    }

    func testMatchesIgnoringDiacritics() {
        XCTAssertEqual(filter("cafe"), ["Café Au Lait"])
        XCTAssertEqual(filter("café"), ["Café Au Lait"])
    }

    func testNoMatchReturnsAnEmptyListNotAnError() {
        XCTAssertEqual(filter("zzz"), [])
    }

    func testSurroundingWhitespaceInTheFilterIsIgnored() {
        XCTAssertEqual(filter("  frost "), ["Frost"])
    }

    func testDuplicateNamesAreAllReturned() {
        let result = NameFilter.matching(["A", "B", "A"], name: { $0 }, containing: "a")
        XCTAssertEqual(result, ["A", "A"])
    }

    func testAppliedToTheBuiltInPresetsAndThemes() {
        let presets = BoardPresetStore.createDefaultPresets()
        let presetName = presets[0].name
        let presetMatches = NameFilter.matching(presets, name: \.name, containing: presetName.uppercased())
        XCTAssertTrue(presetMatches.contains { $0.id == presets[0].id })
        XCTAssertEqual(NameFilter.matching(presets, name: \.name, containing: nil).map(\.id), presets.map(\.id))

        let themes = BoardThemeStore.createDefaultThemes()
        let ember = NameFilter.matching(themes, name: \.name, containing: "ember")
        XCTAssertEqual(ember.map(\.name), ["Ember"])
        XCTAssertEqual(NameFilter.matching(themes, name: \.name, containing: nil).count, themes.count)
    }

    // MARK: - first(named:)

    func testFirstNamedIsCaseInsensitiveAndExact() {
        XCTAssertEqual(NameFilter.first(names, name: { $0 }, named: "EMBER"), "Ember")
        XCTAssertEqual(NameFilter.first(names, name: { $0 }, named: "  frost "), "Frost")
        XCTAssertNil(NameFilter.first(names, name: { $0 }, named: "Embe"), "partial names don't count")
        XCTAssertNil(NameFilter.first(names, name: { $0 }, named: "zzz"))
    }

    func testFirstNamedReturnsTheFirstOfDuplicatesAndNilForBlank() {
        XCTAssertEqual(NameFilter.first(["A", "a", "B"], name: { $0 }, named: "a"), "A")
        XCTAssertNil(NameFilter.first(names, name: { $0 }, named: ""))
        XCTAssertNil(NameFilter.first(names, name: { $0 }, named: "   "))
    }
}
