import XCTest

/// The four preview sizes shown by `PresetEditorView`'s segmented Size
/// picker (App/PresetEditor.swift) - the raw case values match its "S"/"M"/
/// "L"/"XL" segment labels exactly, so they double as the strings XCUITest
/// matches against.
enum PreviewSizeLabel: String {
    case small = "S"
    case medium = "M"
    case large = "L"
    case extraLarge = "XL"
}

/// Shared navigation helpers for driving `PresetEditorView` from a UI test.
/// Everything here matches on accessibility identifiers added specifically
/// for these tests (see App/PresetEditor.swift, App/PresetList.swift,
/// App/ThemeList.swift) - there is no test-only backdoor in the app itself,
/// this drives the exact same UI a person would use.
extension XCTestCase {
    /// Opens the leading Presets side panel, taps the row for `name`, and
    /// waits for its close animation to settle. The panel is a custom
    /// `SidePanel` overlay (App/SidePanel.swift), not a system sheet, so
    /// this polls for the row's existence rather than a system presentation
    /// wait, then pads past the animation before the next screenshot.
    func selectPreset(named name: String, in app: XCUIApplication) {
        let openButton = app.buttons["openPresetList"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5), "Preset list trigger button not found")
        openButton.tap()

        let row = app.buttons["preset-row-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Preset row '\(name)' not found")
        row.tap()

        settle()
    }

    /// Same as `selectPreset(named:in:)`, for the trailing Themes panel.
    func selectTheme(named name: String, in app: XCUIApplication) {
        let openButton = app.buttons["openThemeList"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5), "Theme list trigger button not found")
        openButton.tap()

        let row = app.buttons["theme-row-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Theme row '\(name)' not found")
        row.tap()

        settle()
    }

    /// Taps the S/M/L/XL segment in the Preview section's size picker.
    func selectSize(_ size: PreviewSizeLabel, in app: XCUIApplication) {
        let segment = app.segmentedControls.buttons[size.rawValue]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "Size segment '\(size.rawValue)' not found")
        segment.tap()
        settle()
    }

    /// Captures the full Simulator screen and attaches it to the test's
    /// result bundle under a stable, sortable name - extracted later by
    /// Tools/organize-screenshots.py via `xcresulttool export attachments`.
    func captureScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A short fixed pause past SidePanel's documented 0.32s spring
    /// response, covering CI Simulator timing variance. Polling on
    /// `isHittable` alone isn't enough here since the board preview
    /// underneath is already hittable before the panel finishes sliding
    /// away.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }
}
