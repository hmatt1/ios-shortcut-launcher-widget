import XCTest
import SwiftUI
import UIKit
import WidgetKit
import Darwin
@testable import LauncherBoardWidget

/// Memory-leak and memory-ceiling coverage for the widget's rendering path.
///
/// WidgetKit extensions run under an OS-enforced hard memory ceiling of
/// roughly 30MB - well corroborated across many Apple Developer Forum
/// threads and a public feedback-assistant report, though not pinned down
/// in a single official Apple doc page - past which the extension process
/// is killed outright with `EXC_RESOURCE`. This widget draws only text and
/// flat colors (no images, no heavy state), so a real regression toward
/// that ceiling is far more likely to come from a leak piling up across
/// timeline reloads than from any one frame's legitimate cost - which is
/// what these tests are shaped around.
@MainActor
final class MemoryTests: XCTestCase {
    private func makeEntry(presetId: UUID, sample: [String]) -> LauncherEntry {
        var intent = LauncherIntent()
        intent.preset = BoardPresetEntity(id: presetId, name: "Test")
        return LauncherEntry(date: Date(), configuration: intent, sample: sample)
    }

    private func makeView(presetId: UUID) -> some View {
        LauncherWidgetView(entry: makeEntry(presetId: presetId, sample: BoardSample.names))
            .environment(\.widgetFamily, .systemExtraLargePortrait)
            .environment(\.widgetRenderingMode, .fullColor)
            .environment(\.showsWidgetContainerBackground, true)
            .frame(width: 364, height: 594)
    }

    // MARK: - Leak checks

    /// `ImageRenderer` (used throughout RenderSmokeTests and here) must not
    /// outlive its own scope - a retain cycle here would mean every
    /// rendered frame permanently keeps its whole view hierarchy alive.
    func testImageRendererDoesNotLeak() {
        guard let preset = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("no default presets")
        }
        let renderer = ImageRenderer(content: makeView(presetId: preset.id))
        _ = renderer.uiImage // force an actual render before checking teardown
        trackForMemoryLeaks(renderer)
    }

    /// A `UIHostingController` wrapping the real widget view, forced through
    /// a layout pass - catches a retain cycle specifically in the hosted
    /// SwiftUI view's own closures/environment objects (e.g. through
    /// `Button(intent:)` or `@ObservedObject` store subscriptions), which
    /// `ImageRenderer`'s own internal machinery might not exercise the same
    /// way.
    func testHostingControllerDoesNotLeak() {
        guard let preset = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("no default presets")
        }
        let hosting = UIHostingController(rootView: makeView(presetId: preset.id))
        hosting.view.frame = CGRect(x: 0, y: 0, width: 364, height: 594)
        hosting.view.layoutIfNeeded()
        trackForMemoryLeaks(hosting)
    }

    // MARK: - Memory ceiling

    /// Real resident-memory delta across many render passes, measured via
    /// the standard Darwin `task_info(MACH_TASK_BASIC_INFO)` pattern for a
    /// process's own memory footprint - NOT `XCTMemoryMetric`, whose
    /// `measure(metrics:)` only fails a test against a previously-recorded
    /// `.xcbaseline` file, which doesn't exist for this fresh target. Without
    /// one, `XCTMemoryMetric` alone would just record a number with nothing
    /// to gate against - the informational test below keeps that metric
    /// visible in CI output, but this one is the actual enforced budget.
    ///
    /// The threshold is deliberately generous: this widget renders only
    /// text and flat colors, so legitimate cost per render is tiny, and
    /// process memory measurements are inherently a little noisy (Swift
    /// runtime/ARC timing). The point is catching an actual leak that scales
    /// with iteration count, not pinning an exact byte budget.
    func testRepeatedRenderingStaysWithinMemoryBudget() {
        let presets = BoardPresetStore.createDefaultPresets()
        let before = currentResidentMemoryBytes()

        for _ in 0..<20 {
            autoreleasepool {
                for preset in presets {
                    let renderer = ImageRenderer(content: makeView(presetId: preset.id))
                    _ = renderer.uiImage
                }
            }
        }

        let after = currentResidentMemoryBytes()
        let deltaMB = Double(after) - Double(before)
        let deltaMBRounded = (deltaMB / 1_048_576 * 100).rounded() / 100

        XCTAssertLessThan(
            deltaMBRounded, 50,
            "rendering 20x\(presets.count) timeline entries grew resident memory by \(deltaMBRounded)MB - " +
            "check for a retain cycle before assuming this is legitimate cost"
        )
    }

    /// Informational only (see the comment above `testRepeatedRenderingStaysWithinMemoryBudget`)
    /// - keeps XCTMemoryMetric's own reporting visible in CI output/Xcode's
    /// test reports, in case a `.xcbaseline` is set up for this target later.
    func testMemoryMetricIsRecorded() {
        guard let preset = BoardPresetStore.createDefaultPresets().first else {
            return XCTFail("no default presets")
        }
        measure(metrics: [XCTMemoryMetric()]) {
            let renderer = ImageRenderer(content: makeView(presetId: preset.id))
            _ = renderer.uiImage
        }
    }
}

/// The standard Darwin pattern for reading the CURRENT process's own
/// resident memory footprint - safe and unprivileged for a process to query
/// about itself (unlike querying another process's memory, which would need
/// entitlements this doesn't and shouldn't have).
private func currentResidentMemoryBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
        }
    }
    return result == KERN_SUCCESS ? info.resident_size : 0
}
