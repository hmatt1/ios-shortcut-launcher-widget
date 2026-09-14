import XCTest
@testable import LauncherBoard

/// Regression coverage for the hand-hardened fallback paths in
/// `BoardPresetStore`/`BoardThemeStore` (force-unwraps removed earlier this
/// session, verified only by reasoning until now) and their stateful
/// mutation methods' edge-case guards.
///
/// `BoardPresetStore.shared`/`BoardThemeStore.shared` are true singletons
/// shared with every other test file in this process, and their public API
/// has no way to reset them between tests. Every test here is written to
/// hold regardless of whatever state precedes it - asserting invariants and
/// before/after deltas within the same test, never an assumed absolute
/// starting count - rather than relying on test execution order.
@MainActor
final class StoreFallbackTests: XCTestCase {
    // MARK: - loadPreset(id:) / loadTheme(id:) fallback

    func testLoadPresetWithUnknownIdReturnsSafeFallbackNotCrash() {
        let preset = BoardPresetStore.loadPreset(id: UUID())
        XCTAssertFalse(preset.name.isEmpty)
        XCTAssertGreaterThanOrEqual(preset.columns, 0)
    }

    func testLoadThemeWithUnknownIdReturnsSafeFallbackNotCrash() {
        let theme = BoardThemeStore.loadTheme(id: UUID())
        XCTAssertFalse(theme.name.isEmpty)
        XCTAssertFalse(theme.spec.labels.isEmpty)
    }

    /// `loadRaw()` falls back to `createDefaultPresets()` whenever the App
    /// Group container is unavailable (the expected environment for this
    /// host-less test target - see project.yml's WidgetLogicTests comment),
    /// so `loadPreset(id:)` should resolve to one of those real defaults in
    /// that case, never needing its own hardcoded literal at all.
    func testLoadPresetFallsBackToARealDefaultWhenContainerUnavailable() throws {
        guard AppGroup.defaults == nil else {
            throw XCTSkip("App Group container is available in this environment - the no-container fallback path isn't exercised here.")
        }
        let defaults = BoardPresetStore.createDefaultPresets()
        let loaded = BoardPresetStore.loadPreset(id: UUID())
        XCTAssertTrue(defaults.contains(where: { $0.name == loaded.name }))
    }

    // MARK: - delete(id:) never empties the list

    func testDeletingNeverEmptiesThePresetList() {
        let store = BoardPresetStore.shared
        while store.presets.count > 1 {
            store.delete(id: store.presets[0].id)
        }
        XCTAssertEqual(store.presets.count, 1)
        store.delete(id: store.presets[0].id) // must be a no-op, not empty the list
        XCTAssertEqual(store.presets.count, 1)
    }

    func testDeletingNeverEmptiesTheThemeList() {
        let store = BoardThemeStore.shared
        while store.themes.count > 1 {
            store.delete(id: store.themes[0].id)
        }
        XCTAssertEqual(store.themes.count, 1)
        store.delete(id: store.themes[0].id)
        XCTAssertEqual(store.themes.count, 1)
    }

    // MARK: - restoreDefaults idempotence

    func testRestoringDefaultPresetsTwiceInARowAddsNothingTheSecondTime() {
        let store = BoardPresetStore.shared
        store.restoreDefaultPresets()
        let countAfterFirstRestore = store.presets.count
        store.restoreDefaultPresets()
        XCTAssertEqual(store.presets.count, countAfterFirstRestore, "a second restore should add nothing new")
        XCTAssertFalse(store.canRestoreDefaultPresets)
    }

    func testRestoringDefaultThemesTwiceInARowAddsNothingTheSecondTime() {
        let store = BoardThemeStore.shared
        store.restoreDefaultThemes()
        let countAfterFirstRestore = store.themes.count
        store.restoreDefaultThemes()
        XCTAssertEqual(store.themes.count, countAfterFirstRestore, "a second restore should add nothing new")
        XCTAssertFalse(store.canRestoreDefaultThemes)
    }

    /// Deleting a built-in preset, then restoring, brings back an entry
    /// with the same look (restoreDefaultPresets() dedups by look, not by
    /// id/name) - matched here against the exact field set
    /// BoardPresetStore's own private `samePreset` compares, since that
    /// function isn't reachable through `@testable import`.
    func testDeletingABuiltInThenRestoringBringsItBack() {
        let store = BoardPresetStore.shared
        store.restoreDefaultPresets()
        guard let defaultLook = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("createDefaultPresets() returned nothing")
        }
        func matches(_ preset: BoardPreset) -> Bool {
            preset.columns == defaultLook.columns
                && preset.marginX == defaultLook.marginX && preset.marginY == defaultLook.marginY
                && preset.spacingX == defaultLook.spacingX && preset.spacingY == defaultLook.spacingY
                && preset.paddingX == defaultLook.paddingX && preset.paddingY == defaultLook.paddingY
                && preset.cornerRadius == defaultLook.cornerRadius && preset.outerCornerRadius == defaultLook.outerCornerRadius
                && preset.themeId == defaultLook.themeId && preset.background == defaultLook.background
        }
        guard let target = store.presets.first(where: matches) else {
            return XCTFail("expected the first built-in's look to be present after restoreDefaultPresets()")
        }

        store.delete(id: target.id)
        XCTAssertFalse(store.presets.contains(where: matches))

        store.restoreDefaultPresets()
        XCTAssertTrue(store.presets.contains(where: matches), "restoring should bring the deleted built-in's look back")
    }

    // MARK: - duplicate(id:)

    func testDuplicatingAPresetInsertsAnIdenticalLookRightAfterTheOriginal() {
        let store = BoardPresetStore.shared
        let original = store.create(name: "StoreFallbackTests-duplicate-source")
        store.duplicate(id: original.id)

        guard let originalIndex = store.presets.firstIndex(where: { $0.id == original.id }) else {
            return XCTFail("the original preset should still be present")
        }
        let copy = store.presets[originalIndex + 1]
        XCTAssertEqual(copy.name, original.name + " Copy")
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.columns, original.columns)
        XCTAssertEqual(copy.marginX, original.marginX)
        XCTAssertEqual(copy.themeId, original.themeId)
        XCTAssertEqual(copy.background, original.background)
    }

    func testDuplicatingAThemeInsertsAnIdenticalLookRightAfterTheOriginal() {
        let store = BoardThemeStore.shared
        let original = store.create(name: "StoreFallbackTests-duplicate-source-theme")
        store.duplicate(id: original.id)

        guard let originalIndex = store.themes.firstIndex(where: { $0.id == original.id }) else {
            return XCTFail("the original theme should still be present")
        }
        let copy = store.themes[originalIndex + 1]
        XCTAssertEqual(copy.name, original.name + " Copy")
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.spec, original.spec)
    }

    func testDuplicatingAnUnknownIdIsANoOp() {
        let store = BoardPresetStore.shared
        let countBefore = store.presets.count
        store.duplicate(id: UUID())
        XCTAssertEqual(store.presets.count, countBefore)
    }
}
