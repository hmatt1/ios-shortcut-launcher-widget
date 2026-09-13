import XCTest
import SwiftUI
import UIKit
import WidgetKit
@testable import LauncherBoardWidget

/// Forces `LauncherWidgetView.body` to actually evaluate, not just
/// construct - merely building a `View` struct never runs `body` at all
/// (SwiftUI is lazy about that), and the XL widget crash lived exactly
/// inside a real layout/render pass, not in construction. `ImageRenderer`
/// (iOS 16+) rasterizes a real SwiftUI view hierarchy standalone, with no
/// host window needed, which is what makes this possible headlessly in a
/// unit test at all.
///
/// `PresetEditorView`'s own board preview (App/PresetEditor.swift) isn't
/// reachable from here - it lives in the `LauncherBoard` app target, and
/// this test target deliberately depends on `LauncherBoardWidget` only (see
/// project.yml's WidgetLogicTests comment on why importing both targets'
/// modules together would be worse, not better). That's not a real coverage
/// gap: `PresetEditorView.boardView` and `LauncherWidgetView.body` both
/// build on the exact same shared `BoardView`/`SlotFace`
/// (Shared/BoardView.swift) - rendering `LauncherWidgetView` here already
/// exercises that shared pipeline directly.
@MainActor
final class RenderSmokeTests: XCTestCase {
    /// The families Widget/Widget.swift's `.supportedFamilies(...)` actually
    /// declares - kept in sync manually with `WidgetProviderTests`'
    /// `testDeclaredSupportedFamiliesAllMapCorrectly`, since both exist to
    /// guard the same declaration from drifting unnoticed.
    private let supportedFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait]

    private func canvasSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        case .systemLarge: return CGSize(width: 364, height: 382)
        case .systemExtraLargePortrait: return CGSize(width: 364, height: 594)
        default: return CGSize(width: 364, height: 382)
        }
    }

    private func makeEntry(presetId: UUID, sample: [String]) -> LauncherEntry {
        var intent = LauncherIntent()
        intent.preset = BoardPresetEntity(id: presetId, name: "Test")
        return LauncherEntry(date: Date(), configuration: intent, sample: sample)
    }

    /// Renders `LauncherWidgetView` for every supported family x every
    /// built-in preset x populated/empty data. This is the direct
    /// regression test for the XL crash's actual failure mode: injecting
    /// `.systemExtraLargePortrait` via the environment and forcing a real
    /// render exercises `BoardSize(family:)` -> `BoardGrid.resolve` ->
    /// `BoardView`/`SlotFace` exactly as WidgetKit itself would.
    func testEveryFamilyAndPresetRendersWithoutCrashing() {
        let presets = BoardPresetStore.createDefaultPresets()
        var rendered = 0
        for family in supportedFamilies {
            for preset in presets {
                for sample in [BoardSample.names, []] {
                    let entry = makeEntry(presetId: preset.id, sample: sample)
                    let size = canvasSize(for: family)
                    let view = LauncherWidgetView(entry: entry)
                        .environment(\.widgetFamily, family)
                        .environment(\.widgetRenderingMode, .fullColor)
                        .environment(\.showsWidgetContainerBackground, true)
                        .frame(width: size.width, height: size.height)

                    let renderer = ImageRenderer(content: view)
                    XCTAssertNotNil(
                        renderer.uiImage,
                        "render failed: \(family), preset '\(preset.name)', sample.count=\(sample.count)"
                    )
                    rendered += 1
                }
            }
        }
        XCTAssertEqual(rendered, supportedFamilies.count * presets.count * 2)
    }

    /// The same matrix at `BoardGrid.maxSlots`, to force the row/column
    /// degradation cascade (Shared/BoardGrid.swift) through a real render,
    /// not just check its returned numbers the way BoardGridTests does.
    func testMaxSlotsRendersWithoutCrashing() {
        let presets = BoardPresetStore.createDefaultPresets()
        let fullSample = (0..<BoardGrid.maxSlots).map { "Shortcut \($0)" }
        for family in supportedFamilies {
            for preset in presets {
                let entry = makeEntry(presetId: preset.id, sample: fullSample)
                let size = canvasSize(for: family)
                let view = LauncherWidgetView(entry: entry)
                    .environment(\.widgetFamily, family)
                    .environment(\.widgetRenderingMode, .fullColor)
                    .environment(\.showsWidgetContainerBackground, true)
                    .frame(width: size.width, height: size.height)

                let renderer = ImageRenderer(content: view)
                XCTAssertNotNil(renderer.uiImage, "maxSlots render failed: \(family), preset '\(preset.name)'")
            }
        }
    }

    /// Accented (Lock Screen / non-full-color) rendering is a distinct code
    /// path in `LauncherWidgetView.body` (`accented = renderingMode != .fullColor`),
    /// worth its own pass rather than assuming it shares every branch the
    /// full-color path above already covered.
    func testAccentedRenderingModeRendersWithoutCrashing() {
        guard let preset = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("no default presets")
        }
        for family in supportedFamilies {
            let entry = makeEntry(presetId: preset.id, sample: BoardSample.names)
            let size = canvasSize(for: family)
            let view = LauncherWidgetView(entry: entry)
                .environment(\.widgetFamily, family)
                .environment(\.widgetRenderingMode, .accented)
                .environment(\.showsWidgetContainerBackground, true)
                .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: view)
            XCTAssertNotNil(renderer.uiImage, "accented render failed: \(family)")
        }
    }

    /// `showsWidgetContainerBackground: false` (Standby / certain display
    /// contexts) is the other branch of `LauncherWidgetView`'s
    /// `showsWallpaper` condition alongside rendering mode - covered
    /// separately from the accented-mode test above since the two
    /// environment values are independent.
    func testHiddenContainerBackgroundRendersWithoutCrashing() {
        guard let preset = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("no default presets")
        }
        for family in supportedFamilies {
            let entry = makeEntry(presetId: preset.id, sample: BoardSample.names)
            let size = canvasSize(for: family)
            let view = LauncherWidgetView(entry: entry)
                .environment(\.widgetFamily, family)
                .environment(\.widgetRenderingMode, .fullColor)
                .environment(\.showsWidgetContainerBackground, false)
                .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: view)
            XCTAssertNotNil(renderer.uiImage, "hidden-container-background render failed: \(family)")
        }
    }
}
