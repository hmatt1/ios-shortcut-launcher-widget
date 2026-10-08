import XCTest

/// The pure logic behind the theme Shortcuts actions.
final class ThemeEditTests: XCTestCase {

    private var base: BoardTheme { BoardThemeStore.createDefaultThemes()[2] }

    func testAnEmptyEditChangesNothing() throws {
        XCTAssertEqual(try ThemeEdit().applying(to: base), base)
    }

    func testParsesHexWithAndWithoutHashAnyCase() throws {
        XCTAssertEqual(try ThemeEdit.parseColor("#FF8000"), RGB(0xFF8000))
        XCTAssertEqual(try ThemeEdit.parseColor("ff8000"), RGB(0xFF8000))
        XCTAssertEqual(try ThemeEdit.parseColor("  #0a0B0c "), RGB(0x0A0B0C))
    }

    func testRejectsBadColors() {
        for bad in ["", "#", "#FFF", "#GG0000", "12345", "1234567", "#12 456", "ＦＦ0000"] {
            XCTAssertThrowsError(try ThemeEdit.parseColor(bad), bad)
        }
    }

    func testOnlyGivenFieldsChange() throws {
        var edit = ThemeEdit()
        edit.label = "#112233"
        let result = try edit.applying(to: base)
        var expected = base
        expected.spec.labels = Array(repeating: RGB(0x112233), count: 12)
        XCTAssertEqual(result, expected)
        XCTAssertEqual(result.spec.accents, base.spec.accents)
        XCTAssertEqual(result.spec.background, base.spec.background)
    }

    func testBackgroundTakesOneOrTwoColors() throws {
        var edit = ThemeEdit()
        edit.background = ["#000000"]
        XCTAssertEqual(try edit.applying(to: base).spec.background, [RGB(0x000000)])
        edit.background = ["#000000", "#FFFFFF"]
        XCTAssertEqual(try edit.applying(to: base).spec.background.count, 2)
        edit.background = []
        XCTAssertThrowsError(try edit.applying(to: base))
        edit.background = ["#000000", "#111111", "#222222"]
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testEmptyAccentListMakesTheThemeMonochrome() throws {
        var edit = ThemeEdit()
        edit.accents = []
        XCTAssertTrue(try edit.applying(to: base).spec.accents.isEmpty)
    }

    func testAccentsAreCappedAtTwelve() throws {
        var edit = ThemeEdit()
        edit.accents = Array(repeating: "#123456", count: 12)
        XCTAssertEqual(try edit.applying(to: base).spec.accents.count, 12)
        edit.accents = Array(repeating: "#123456", count: 13)
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testABadColorChangesNothing() {
        var edit = ThemeEdit()
        edit.name = "Renamed"
        edit.label = "nope"
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testNameIsTrimmedAndBlankIgnored() throws {
        var edit = ThemeEdit()
        edit.name = "  Dusk "
        XCTAssertEqual(try edit.applying(to: base).name, "Dusk")
        edit.name = " "
        XCTAssertEqual(try edit.applying(to: base).name, base.name)
    }
}
