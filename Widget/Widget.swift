import SwiftUI
import WidgetKit
import AppIntents

/// Just the `@main` widget-bundle registration. `LauncherIntent` and
/// `LauncherWidgetView` live beside it in `Widget/`, not in `Shared/` (which
/// the app also compiles - a second copy of the intents in the app binary
/// breaks widget taps). `WidgetLogicTests` compiles every file in `Widget/`
/// except this one, since `@main` must exist in exactly one target.
@main
struct LauncherBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LauncherBoard",
            intent: LauncherIntent.self,
            provider: LauncherProvider()
        ) { entry in
            LauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Shortcut Launcher")
        .description("Run your shortcuts from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
        .contentMarginsDisabled()
    }
}
