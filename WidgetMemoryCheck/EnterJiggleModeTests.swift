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
        func attachTree(named name: String) {
            let tree = XCTAttachment(data: Data(springboard.debugDescription.utf8))
            tree.name = name
            tree.lifetime = .keepAlways
            add(tree)
        }
        attachTree(named: "02-springboard-accessibility-tree")

        // 6. The first real run confirmed jiggle mode does engage (every
        // icon gets a delete badge) - but the top bar shows "Edit"/"Done"
        // buttons, not the classic "+", suggesting iOS 26/27's redesigned
        // Home Screen customization menu. Tap "Edit" and capture what it
        // reveals, rather than guessing blindly past it.
        let editButton = springboard.buttons["Edit"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
        }

        let afterEdit = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterEdit.name = "03-after-tapping-edit"
        afterEdit.lifetime = .keepAlways
        add(afterEdit)
        attachTree(named: "04-springboard-accessibility-tree-after-edit")

        // 7. Confirmed by round 2: "Edit" opens a menu whose first item is
        // a real, directly-tappable "Add Widget" button (with a
        // "widget.small.badge.plus" icon). Tap it and capture the widget
        // gallery it should open.
        let addWidgetButton = springboard.buttons["Add Widget"]
        if addWidgetButton.waitForExistence(timeout: 3) {
            addWidgetButton.tap()
        }

        let afterAddWidget = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterAddWidget.name = "05-after-tapping-add-widget"
        afterAddWidget.lifetime = .keepAlways
        add(afterAddWidget)
        attachTree(named: "06-springboard-accessibility-tree-after-add-widget")

        // 8. Confirmed by round 3: this opens the widget gallery directly -
        // a search field ("Search Widgets") plus an alphabetical list of
        // cells in a collection view (identifier 'add-sheet-collection-view').
        //
        // Round 4/5 found the real reason a direct `cells["Shortcut Launcher
        // Widget"]` query kept failing: it's not a query-syntax problem, it's
        // that the cell is never realized in XCUITest's accessibility
        // snapshot in the first place. Round 5's failure diagnostics (an
        // XCTest-captured "Complete Issue Description" + this cell's own
        // "Debug description") listed the full set of cells the snapshot
        // actually saw - eleven, ending at "Reminders" - and "Shortcut
        // Launcher Widget" (alphabetically last, right after "Safari") was
        // not among them. Round 5's screenshot confirmed why: it's the very
        // last row, clipped at the bottom edge of the collection view's own
        // frame, effectively off-screen. Scrolling by a guessed offset would
        // be another guess; searching is the documented purpose of the
        // search field that's already right there, so it's what this round
        // uses instead.
        let searchField = springboard.searchFields["Search Widgets"]
        let searchFieldExisted = searchField.waitForExistence(timeout: 3)
        if searchFieldExisted {
            searchField.tap()
            searchField.typeText("Shortcut Launcher Widget")
        }

        let afterSearch = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterSearch.name = "07-after-searching"
        afterSearch.lifetime = .keepAlways
        add(afterSearch)
        attachTree(named: "08-springboard-accessibility-tree-after-searching")

        // .frame (like most XCUIElement properties) isn't a cached snapshot
        // from waitForExistence/tap() - it live-queries the current UI tree
        // whenever it's read. Round 9's real CI failure: capturing it AFTER
        // the tap (inside this string, evaluated lazily at that point) raced
        // against the tap's own navigation to the widget's config screen -
        // a screen with no Cell elements at all - and the re-query threw
        // instead of finding anything. It happened to race favorably in
        // round 7's run, which is exactly the kind of flakiness a "worked
        // once" result can hide. Every value below is now captured BEFORE
        // the tap, while the cell's own screen is still on screen.
        let widgetCell = springboard.cells["Shortcut Launcher Widget"]
        let existedBeforeTap = widgetCell.waitForExistence(timeout: 3)
        let hittableBeforeTap = widgetCell.isHittable
        let frameBeforeTap = widgetCell.frame
        if existedBeforeTap {
            widgetCell.tap()
        }
        let existsAfterTap = widgetCell.exists

        let status = """
        searchField existed: \(searchFieldExisted)
        widgetCell existed before tap: \(existedBeforeTap)
        widgetCell was hittable before tap: \(hittableBeforeTap)
        widgetCell frame before tap: \(frameBeforeTap)
        widgetCell still exists after tap (by the same query): \(existsAfterTap)
        """
        let statusAttachment = XCTAttachment(data: Data(status.utf8))
        statusAttachment.name = "09-tap-status"
        statusAttachment.lifetime = .keepAlways
        add(statusAttachment)

        let afterSelectingWidget = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterSelectingWidget.name = "10-after-selecting-widget"
        afterSelectingWidget.lifetime = .keepAlways
        add(afterSelectingWidget)
        attachTree(named: "11-springboard-accessibility-tree-after-selecting-widget")

        // 9. Confirmed by round 6: tapping the cell opened the widget's own
        // configuration screen - title "Shortcut Launcher Widget", a
        // 4-page family carousel (small/medium/large/XL, matching this
        // widget's real supported families), a live preview, and a
        // directly-tappable "Add Widget" button. Its accessibility label is
        // " Add Widget" (a leading space, from the "+" glyph sharing the
        // label) - matched with a CONTAINS predicate instead of an exact
        // identifier so that leading space can't cause a silent mismatch.
        // No swipe through the carousel: the default page (Small) is enough
        // to get the extension process running for a memory reading, which
        // is this whole check's actual goal - not exhaustively exercising
        // every family size.
        let addWidgetInSheet = springboard.buttons.element(
            matching: NSPredicate(format: "label CONTAINS[c] 'Add Widget'")
        )
        let addWidgetInSheetExisted = addWidgetInSheet.waitForExistence(timeout: 3)
        if addWidgetInSheetExisted {
            addWidgetInSheet.tap()
        }

        let afterAddingWidget = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterAddingWidget.name = "12-after-tapping-add-widget-in-sheet"
        afterAddingWidget.lifetime = .keepAlways
        add(afterAddingWidget)
        attachTree(named: "13-springboard-accessibility-tree-after-adding-widget")

        // 10. Exit jiggle mode via the same "Done" button whose presence
        // (instead of the expected "+") kicked off this whole phased
        // investigation back in round 1 - confirming the loop closes.
        let doneButton = springboard.buttons["Done"]
        let doneButtonExisted = doneButton.waitForExistence(timeout: 3)
        if doneButtonExisted {
            doneButton.tap()
        }

        let addWidgetStatus = """
        addWidgetInSheet existed: \(addWidgetInSheetExisted)
        doneButton existed: \(doneButtonExisted)
        """
        let addWidgetStatusAttachment = XCTAttachment(data: Data(addWidgetStatus.utf8))
        addWidgetStatusAttachment.name = "14-add-widget-and-done-status"
        addWidgetStatusAttachment.lifetime = .keepAlways
        add(addWidgetStatusAttachment)

        let final = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        final.name = "15-final-home-screen"
        final.lifetime = .keepAlways
        add(final)
        attachTree(named: "16-springboard-accessibility-tree-final")
    }
}
