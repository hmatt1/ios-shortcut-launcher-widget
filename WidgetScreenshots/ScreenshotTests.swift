import XCTest

/// Captures the App Store screenshot set described in AppStore/screenshots.md
/// by driving PresetEditorView's live preview, which shares its rendering
/// pipeline with the real widget (see Shared/BoardGrid.swift and
/// Shared/BoardView.swift - both targets compile the same source files).
/// Every preset name below is one of the built-in showcase presets from
/// BoardPresetStore.createDefaultPresets(), so these tests work against a
/// completely fresh Simulator install with nothing configured.
///
/// Shot 6 (transparent wallpaper background) is deliberately not covered
/// here - see AppStore/screenshots.md for why.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    /// Shot 1: hero - the Default preset, Medium size.
    func testHeroDefault() {
        let app = launchApp()
        selectPreset(named: "Default", in: app)
        selectSize(.medium, in: app)
        captureScreenshot(named: "01-hero-default")
    }

    /// Shot 2: theme variety - one screenshot per showcase preset, clearly
    /// different looks (Ink/sharp-edged, Meadow/light, Ember/tight).
    func testThemeVariety() {
        let app = launchApp()
        for name in ["Slate", "Field", "Console"] {
            selectPreset(named: name, in: app)
            selectSize(.medium, in: app)
            captureScreenshot(named: "02-theme-\(name.lowercased())")
        }
    }

    /// Shot 3: the Extra Large widget - the one genuinely new thing in this
    /// release (systemExtraLargePortrait).
    func testExtraLargeWidget() {
        let app = launchApp()
        selectPreset(named: "Default", in: app)
        selectSize(.extraLarge, in: app)
        captureScreenshot(named: "03-extra-large")
    }

    /// Shot 4: pinned columns, on purpose - Keypad (3 columns) next to Grid
    /// (2 columns), so the difference reads at a glance.
    func testColumnsOnPurpose() {
        let app = launchApp()
        selectPreset(named: "Keypad", in: app)
        selectSize(.medium, in: app)
        captureScreenshot(named: "04-columns-keypad")

        selectPreset(named: "Grid", in: app)
        selectSize(.medium, in: app)
        captureScreenshot(named: "04-columns-grid")
    }

    /// Shot 5: the editor itself - the Form's Preview section already
    /// renders inline above the controls, so one full-screen capture shows
    /// editor and live preview together with no extra setup.
    func testEditorItself() {
        let app = launchApp()
        selectPreset(named: "Panel", in: app)
        selectSize(.large, in: app)
        captureScreenshot(named: "05-editor")
    }
}
