import XCTest
import Combine
import UIKit

/// The editor and the Shortcuts actions edit the same data, so there must be
/// one source of truth: the stores. These cover the store-level guarantees the
/// editor now relies on (it holds no copy of its own).
@MainActor
final class SingleSourceOfTruthTests: XCTestCase {

    // MARK: - Which preset the editor shows

    func testSelectionKeepsAnExistingPreset() {
        let presets = BoardPresetStore.createDefaultPresets()
        XCTAssertEqual(PresetSelection.effectiveId(requested: presets[3].id, in: presets), presets[3].id)
    }

    func testSelectionFallsToTheFirstPresetWhenTheRequestedOneIsGone() {
        let presets = BoardPresetStore.createDefaultPresets()
        XCTAssertEqual(PresetSelection.effectiveId(requested: UUID(), in: presets), presets[0].id)
        XCTAssertEqual(PresetSelection.effectiveId(requested: nil, in: presets), presets[0].id)
    }

    func testSelectionIsNilOnlyForAnEmptyList() {
        XCTAssertNil(PresetSelection.effectiveId(requested: UUID(), in: []))
    }

    // MARK: - A shortcut's change and the editor's change both survive

    /// What the Update Preset action does, then what the editor now does (a
    /// single-field change built from the CURRENT store value).
    func testAnEditorChangeKeepsAShortcutsChange() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let store = BoardPresetStore.shared
        let created = store.create(name: "SingleSource-regression")
        defer { store.delete(id: created.id) }

        // The shortcut changes the font.
        var edit = PresetEdit()
        edit.fontFamily = .georgia
        store.update(edit.applying(to: created))

        // The editor changes the columns, starting from what the store holds now.
        var current = try XCTUnwrap(store.presets.first { $0.id == created.id })
        current.columns = 4
        store.update(current)

        let final = try XCTUnwrap(store.presets.first { $0.id == created.id })
        XCTAssertEqual(final.fontFamily, .georgia, "the shortcut's change must survive the editor's")
        XCTAssertEqual(final.columns, 4)
    }

    /// Why the editor must not keep its own copy: writing back a stale one
    /// loses the shortcut's change.
    func testWritingBackAStaleCopyLosesTheShortcutsChange() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let store = BoardPresetStore.shared
        let created = store.create(name: "SingleSource-stale")
        defer { store.delete(id: created.id) }

        let staleCopy = created
        var edit = PresetEdit()
        edit.fontFamily = .georgia
        store.update(edit.applying(to: created))

        var fromStale = staleCopy
        fromStale.columns = 4
        store.update(fromStale)

        let final = try XCTUnwrap(store.presets.first { $0.id == created.id })
        XCTAssertEqual(final.fontFamily, .system, "this is the bug the single source of truth prevents")
    }

    // MARK: - Reloading from storage

    func testReloadFromDiskAdoptsASavedChangeAndPublishesOnce() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let store = BoardPresetStore.shared
        let created = store.create(name: "SingleSource-reload")
        defer { store.delete(id: created.id) }

        // Something else rewrites the saved presets behind the singleton's back.
        var renamed = try XCTUnwrap(store.presets.first { $0.id == created.id })
        renamed.name = "SingleSource-reload-renamed"
        var saved = store.presets
        let index = try XCTUnwrap(saved.firstIndex { $0.id == created.id })
        saved[index] = renamed
        AppGroup.defaults?.set(try JSONEncoder().encode(saved), forKey: "board_presets")

        var emissions = 0
        let cancellable = store.$presets.dropFirst().sink { _ in emissions += 1 }
        defer { cancellable.cancel() }

        store.reloadFromDisk()
        XCTAssertEqual(store.presets.first { $0.id == created.id }?.name, "SingleSource-reload-renamed")
        XCTAssertEqual(emissions, 1)

        store.reloadFromDisk()
        XCTAssertEqual(emissions, 1, "nothing changed, so nothing is republished")
    }

    func testReloadFromDiskIgnoresUnreadableData() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let store = BoardPresetStore.shared
        let created = store.create(name: "SingleSource-unreadable")
        defer { store.delete(id: created.id) }
        let before = store.presets

        AppGroup.defaults?.set(Data("not json".utf8), forKey: "board_presets")
        store.reloadFromDisk()
        XCTAssertEqual(store.presets, before, "unreadable saved data must never replace good presets")

        // Put the good data back for the tests that follow.
        store.update(try XCTUnwrap(before.first { $0.id == created.id }))
    }

    func testThemeStoreReloadsAndIgnoresUnreadableData() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let store = BoardThemeStore.shared
        let created = store.create(name: "SingleSource-theme")
        defer { store.delete(id: created.id) }
        let before = store.themes

        var renamed = try XCTUnwrap(before.first { $0.id == created.id })
        renamed.name = "SingleSource-theme-renamed"
        var saved = before
        saved[try XCTUnwrap(saved.firstIndex { $0.id == created.id })] = renamed
        AppGroup.defaults?.set(try JSONEncoder().encode(saved), forKey: "board_themes")
        store.reloadFromDisk()
        XCTAssertEqual(store.themes.first { $0.id == created.id }?.name, "SingleSource-theme-renamed")

        AppGroup.defaults?.set(Data("not json".utf8), forKey: "board_themes")
        let afterGood = store.themes
        store.reloadFromDisk()
        XCTAssertEqual(store.themes, afterGood)
        store.update(try XCTUnwrap(afterGood.first { $0.id == created.id }))
    }

    // MARK: - Button images announce changes

    private func pngData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }.pngData()!
    }

    func testButtonImageChangesPostANotificationForThePreset() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        let presetId = UUID()
        let other = UUID()
        defer {
            ButtonImageStore.removeAll(presetId: presetId)
            ButtonImageStore.removeAll(presetId: other)
        }

        func expectChange(for id: UUID, _ action: () -> Void) {
            let expectation = XCTNSNotificationExpectation(name: .buttonImagesDidChange)
            expectation.handler = { notification in
                notification.userInfo?[ButtonImageStore.presetIdKey] as? UUID == id
            }
            action()
            wait(for: [expectation], timeout: 2)
        }

        expectChange(for: presetId) { XCTAssertTrue(ButtonImageStore.save(data: pngData(), presetId: presetId, button: 1)) }
        expectChange(for: other) { ButtonImageStore.copyAll(from: presetId, to: other) }
        expectChange(for: presetId) { ButtonImageStore.remove(presetId: presetId, button: 1) }
        expectChange(for: other) { ButtonImageStore.removeAll(presetId: other) }
    }
}
