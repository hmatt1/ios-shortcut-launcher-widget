import WidgetKit

/// Everything but this registration itself now lives in `Shared/`
/// (`LauncherEntry`, `LauncherProvider`, `BoardSize(family:)`,
/// `LauncherWidgetView` in Shared/LauncherWidgetView.swift; `LauncherIntent`
/// and its AppIntents entities in Shared/LauncherIntent.swift) - moved out of
/// this app-extension target specifically so `WidgetLogicTests` can link
/// against `LauncherBoard` (the app target) instead, since an
/// `.app-extension`'s compiled `.appex` isn't a linkable library the way an
/// `.application` is (see Shared/LauncherWidgetView.swift's header comment).
/// `@main` has to stay exactly here, though: it's this target's one true
/// entry point, and a second target compiling this same file would collide
/// with it.
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
