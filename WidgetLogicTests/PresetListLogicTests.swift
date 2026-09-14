import XCTest
import SwiftUI
@testable import LauncherBoard

/// `PresetListView.deletePreset`/`ThemeListView.deleteTheme`'s
/// delete-reassigns-selection logic (App/PresetList.swift,
/// App/ThemeList.swift) - previously `private`, extracted only by dropping
/// that modifier (no logic change), tested here with a locally-backed
/// `Binding` rather than driving the real List UI.
@MainActor
final class PresetListLogicTests: XCTestCase {
    private final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    func testDeletingTheSelectedPresetReassignsSelectionToTheNewFirstItem() {
        let store = BoardPresetStore.shared
        let created = store.create(name: "PresetListLogicTests-selected")
        let selectedId = Box(created.id.uuidString)
        let isPresented = Box(true)
        let view = PresetListView(
            selectedId: Binding(get: { selectedId.value }, set: { selectedId.value = $0 }),
            isPresented: Binding(get: { isPresented.value }, set: { isPresented.value = $0 })
        )

        view.deletePreset(created)

        XCTAssertNotEqual(selectedId.value, created.id.uuidString, "selection must move off a preset that no longer exists")
        XCTAssertEqual(selectedId.value, store.presets.first?.id.uuidString ?? "")
    }

    func testDeletingANonSelectedPresetLeavesSelectionUntouched() {
        let store = BoardPresetStore.shared
        let created = store.create(name: "PresetListLogicTests-unselected")
        let selectedId = Box("some-other-id-entirely")
        let isPresented = Box(true)
        let view = PresetListView(
            selectedId: Binding(get: { selectedId.value }, set: { selectedId.value = $0 }),
            isPresented: Binding(get: { isPresented.value }, set: { isPresented.value = $0 })
        )

        view.deletePreset(created)

        XCTAssertEqual(selectedId.value, "some-other-id-entirely")
    }

    func testDeletingTheSelectedThemeReassignsSelectionToTheNewFirstItem() {
        let store = BoardThemeStore.shared
        let created = store.create(name: "PresetListLogicTests-selected-theme")
        let selectedId = Box(created.id.uuidString)
        let isPresented = Box(true)
        let view = ThemeListView(
            selectedId: Binding(get: { selectedId.value }, set: { selectedId.value = $0 }),
            isPresented: Binding(get: { isPresented.value }, set: { isPresented.value = $0 })
        )

        view.deleteTheme(created)

        XCTAssertNotEqual(selectedId.value, created.id.uuidString)
        XCTAssertEqual(selectedId.value, store.themes.first?.id.uuidString ?? "")
    }

    func testDeletingANonSelectedThemeLeavesSelectionUntouched() {
        let store = BoardThemeStore.shared
        let created = store.create(name: "PresetListLogicTests-unselected-theme")
        let selectedId = Box("some-other-id-entirely")
        let isPresented = Box(true)
        let view = ThemeListView(
            selectedId: Binding(get: { selectedId.value }, set: { selectedId.value = $0 }),
            isPresented: Binding(get: { isPresented.value }, set: { isPresented.value = $0 })
        )

        view.deleteTheme(created)

        XCTAssertEqual(selectedId.value, "some-other-id-entirely")
    }
}
