import XCTest

/// The pure logic behind the theme Shortcuts actions.
final class ThemeEditTests: XCTestCase {

    private var base: BoardTheme { BoardThemeStore.createDefaultThemes()[2] }   // Midnight: 6 accents, gradient

    func testAnEmptyEditChangesNothing() throws {
        XCTAssertEqual(try ThemeEdit().applying(to: base), base)
    }

    // MARK: - Colors

    func testParsesHexWithAndWithoutHashAnyCase() throws {
        XCTAssertEqual(try ThemeEdit.parseColor("#FF8000"), RGB(0xFF8000))
        XCTAssertEqual(try ThemeEdit.parseColor("ff8000"), RGB(0xFF8000))
        XCTAssertEqual(try ThemeEdit.parseColor("  #0a0B0c "), RGB(0x0A0B0C))
    }

    func testShortHexExpands() throws {
        XCTAssertEqual(try ThemeEdit.parseColor("#F80"), RGB(0xFF8800))
        XCTAssertEqual(try ThemeEdit.parseColor("abc"), RGB(0xAABBCC))
    }

    func testRejectsBadColors() {
        for bad in ["", "#", "#GG0000", "12345", "1234567", "#12 456", "ＦＦ0000", "#12"] {
            XCTAssertThrowsError(try ThemeEdit.parseColor(bad), bad)
        }
    }

    func testHexFormattingRoundTrips() throws {
        for value: UInt32 in [0x000000, 0xFFFFFF, 0x1A2B3C, 0xFF8000] {
            XCTAssertEqual(ThemeEdit.hex(RGB(value)), String(format: "#%06X", value))
            XCTAssertEqual(try ThemeEdit.parseColor(ThemeEdit.hex(RGB(value))), RGB(value))
        }
    }

    // MARK: - Fields

    func testLabelColorChangesOnlyTheLabels() throws {
        var edit = ThemeEdit()
        edit.labelColor = "#112233"
        let result = try edit.applying(to: base)
        var expected = base
        expected.spec.labels = Array(repeating: RGB(0x112233), count: 12)
        XCTAssertEqual(result, expected)
    }

    func testBackgroundColorAloneMakesAFlatBackground() throws {
        var edit = ThemeEdit()
        edit.backgroundColor = "#000000"
        XCTAssertEqual(try edit.applying(to: base).spec.background, [RGB(0x000000)])
    }

    func testBothBackgroundColorsMakeAGradient() throws {
        var edit = ThemeEdit()
        edit.backgroundColor = "#000000"
        edit.backgroundColor2 = "#FFFFFF"
        XCTAssertEqual(try edit.applying(to: base).spec.background, [RGB(0x000000), RGB(0xFFFFFF)])
    }

    func testBackgroundColor2AloneKeepsTheCurrentFirstColor() throws {
        var edit = ThemeEdit()
        edit.backgroundColor2 = "#FFFFFF"
        let result = try edit.applying(to: base)
        XCTAssertEqual(result.spec.background, [base.spec.background[0], RGB(0xFFFFFF)])
    }

    func testButtonColorsReplaceTheAccents() throws {
        var edit = ThemeEdit()
        edit.buttonColors = ["#FF0000", "#00FF00"]
        XCTAssertEqual(try edit.applying(to: base).spec.accents, [RGB(0xFF0000), RGB(0x00FF00)])
    }

    func testButtonColorsAreCappedAtTwelve() throws {
        var edit = ThemeEdit()
        edit.buttonColors = Array(repeating: "#123456", count: 12)
        XCTAssertEqual(try edit.applying(to: base).spec.accents.count, 12)
        edit.buttonColors = Array(repeating: "#123456", count: 13)
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testAnEmptyButtonColorListLeavesTheAccentsAlone() throws {
        var edit = ThemeEdit()
        edit.buttonColors = []
        XCTAssertEqual(try edit.applying(to: base).spec.accents, base.spec.accents)
    }

    // MARK: - Monochrome

    func testMonochromeClearsTheButtonColors() throws {
        var edit = ThemeEdit()
        edit.monochrome = true
        XCTAssertTrue(try edit.applying(to: base).spec.accents.isEmpty)
    }

    func testMonochromeFalseChangesNothing() throws {
        var edit = ThemeEdit()
        edit.monochrome = false
        XCTAssertEqual(try edit.applying(to: base), base)
    }

    func testExplicitButtonColorsWinOverMonochrome() throws {
        var edit = ThemeEdit()
        edit.monochrome = true
        edit.buttonColors = ["#FF0000"]
        XCTAssertEqual(try edit.applying(to: base).spec.accents, [RGB(0xFF0000)])
    }

    func testButtonColorsCanBeRestoredAfterMonochrome() throws {
        var mono = ThemeEdit()
        mono.monochrome = true
        let cleared = try mono.applying(to: base)
        var restore = ThemeEdit()
        restore.buttonColors = ["#0000FF"]
        XCTAssertEqual(try restore.applying(to: cleared).spec.accents, [RGB(0x0000FF)])
    }

    // MARK: - Failure and names

    func testABadColorChangesNothing() {
        var edit = ThemeEdit()
        edit.name = "Renamed"
        edit.backgroundColor = "#000000"
        edit.labelColor = "nope"
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testNameIsTrimmedAndBlankIgnored() throws {
        var edit = ThemeEdit()
        edit.name = "  Dusk "
        XCTAssertEqual(try edit.applying(to: base).name, "Dusk")
        edit.name = " "
        XCTAssertEqual(try edit.applying(to: base).name, base.name)
    }

    // MARK: - Properties exposed to Shortcuts

    func testThemeSummaryReportsHexColors() {
        let summary = ThemeSummary(base)
        XCTAssertEqual(summary.name, base.name)
        XCTAssertEqual(summary.buttonColors.count, base.spec.accents.count)
        XCTAssertEqual(summary.backgroundColors, base.spec.background.map(ThemeEdit.hex))
        XCTAssertTrue(summary.buttonColors.allSatisfy { $0.hasPrefix("#") && $0.count == 7 })
    }

    func testMonochromeThemeSummaryHasNoButtonColors() {
        let ink = BoardThemeStore.createDefaultThemes()[0]
        XCTAssertTrue(ThemeSummary(ink).buttonColors.isEmpty)
    }

    // MARK: - Per-button label colors

    func testLabelColorsSetEachButtonAndRepeat() throws {
        var edit = ThemeEdit()
        edit.labelColors = ["#FF0000", "#00FF00", "#0000FF"]
        let labels = try edit.applying(to: base).spec.labels
        XCTAssertEqual(labels.count, 12)
        XCTAssertEqual(Array(labels.prefix(4)), [RGB(0xFF0000), RGB(0x00FF00), RGB(0x0000FF), RGB(0xFF0000)])
    }

    func testLabelColorsWinOverASingleLabelColor() throws {
        var edit = ThemeEdit()
        edit.labelColor = "#111111"
        edit.labelColors = ["#222222", "#333333"]
        let labels = try edit.applying(to: base).spec.labels
        XCTAssertEqual(labels[0], RGB(0x222222))
        XCTAssertEqual(labels[1], RGB(0x333333))
    }

    func testLabelColorsAreCappedAtTwelveAndEmptyIsIgnored() throws {
        var edit = ThemeEdit()
        edit.labelColors = Array(repeating: "#123456", count: 13)
        XCTAssertThrowsError(try edit.applying(to: base))
        edit.labelColors = []
        XCTAssertEqual(try edit.applying(to: base), base)
    }

    func testABadLabelColorChangesNothing() {
        var edit = ThemeEdit()
        edit.labelColors = ["#FF0000", "nope"]
        XCTAssertThrowsError(try edit.applying(to: base))
    }

    func testThemeSummaryReportsEveryLabelColor() {
        let summary = ThemeSummary(base)
        XCTAssertEqual(summary.labelColors, base.spec.labels.map(ThemeEdit.hex))
        XCTAssertEqual(summary.labelColor, summary.labelColors.first)
    }
}
