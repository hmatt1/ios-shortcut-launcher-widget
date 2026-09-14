import XCTest

/// Phase A of a real `.appex` memory-footprint check (see
/// `.github/workflows/widget-memory-check.yml`). Getting a real reading
/// needs the actual widget extension process running, which means placing
/// it on a Simulator Home Screen - undocumented SpringBoard automation this
/// project has zero prior grounding in, doubly so on iOS 27, a brand-new OS
/// with no existing examples to check element identifiers against.
///
/// Deliberately stops here rather than guessing the rest of the flow (tap
/// "+", search, select, swipe to size, "Add Widget", "Done"): this test's
/// whole job is to get real ground truth - a screenshot and SpringBoard's
/// own accessibility tree - out of an actual CI run, so the rest of the
/// automation can be written from real iOS 27 element names instead of
/// guesses. Same "diagnose first" approach the code-signing pipeline used
/// earlier in this project's history, applied to a UI instead of a build
/// system. Deliberately has no assertions: the point of this test is the
/// two attachments below, not a pass/fail verdict on whether jiggle mode
/// visibly engaged - that's for a human to read out of the diagnostics.
final class EnterJiggleModeTests: XCTestCase {
    func testEnterJiggleModeAndCaptureDiagnostics() {
        // 1. Launch the app once - confirms it installs and runs at all,
        // and gets it (and its widget) registered with the system, before
        // ever touching SpringBoard.
        let app = XCUIApplication()
        app.launch()

        // 2. Home Screen via the documented, stable device API - not a
        // SpringBoard guess.
        XCUIDevice.shared.press(.home)

        // 3. Attach to SpringBoard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        _ = springboard.wait(for: .runningForeground, timeout: 5)

        // 4. Long-press an area expected to be empty Home Screen space. A
        // fresh Simulator with only this one app installed has very little
        // on its first page - pick a coordinate away from both the dock
        // (bottom edge) and the single icon (top-left, where iOS places the
        // first-installed app).
        let emptySpot = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        emptySpot.press(forDuration: 1.5)

        // 5. Diagnostics - the actual deliverable of this test, captured
        // regardless of whether step 4 visibly worked. Extracted the same
        // way screenshots.yml already extracts XCTAttachments:
        // `xcrun xcresulttool export attachments` + Tools/organize-screenshots.py
        // (that script's shot_name(...) strips the same "_<index>_<uuid>"
        // suffix regardless of what name it's given, so reusing it here
        // needs no changes).
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "01-after-long-press"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // XCTAttachment(data:), not the less-certainly-documented
        // XCTAttachment(string:) - this form is unambiguously real and
        // documented, and a plain UTF-8 Data round-trips as readable text
        // in the extracted file either way.
        let tree = XCTAttachment(data: Data(springboard.debugDescription.utf8))
        tree.name = "02-springboard-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
