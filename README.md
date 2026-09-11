# Launcher Board

Shortcuts on your Home Screen. Every tile runs a shortcut in place through the system `RunSystemShortcutIntent`, so nothing opens.

iOS 27. XcodeGen. Unsigned `.ipa` from GitHub Actions. No accounts, no purchases, no analytics, no network.

## Configure

Touch and hold the widget, choose **Edit Widget**. Three rows:

```
Preset     which board preset to draw
Position   which slot it sits in, for the transparent background
Shortcuts  a multi-select list, one tile per entry (up to 64)
```

The number of shortcuts you choose is the slot count. Pick three and you get three tiles filling the widget, with no separate count to keep in sync. Because a widget cannot know its own family until it is placed, the board fits whatever you chose to whatever family it lands in, shrinking tiles as the count climbs; past `BoardGrid.maxSlots` (64) the overflow is dropped.

Tiles are typographic. A tile shows the shortcut's own name, so it can never show the wrong icon, and there is nothing to type.

One text size is chosen for the whole board, from the longest name it has to hold. Short names get a large size; a long one steps the whole board down together rather than shrinking its own tile, because on a board with no icons the name is the only thing telling tiles apart, and mixed sizes take that away.

`Theme = Ink` with `Density = Flush` is the minimum: one near-black field, names in faint chips, edge to edge.

## Layout Configuration Rework

The old layout engine computed gaps and paddings mathematically, clamping separation to ensure tiles never shrank below 44pt. It was configured using `Density` and `LayoutPattern` enums strictly inside the `LauncherIntent` widget menu, which is limited by iOS to 14 rows. 

The new layout engine is explicit. `BoardPreset` holds precise `marginX`, `spacingX`, `paddingX`, `columns`, and `cornerRadius` properties. When these exact dimensions can't fit on the canvas, the engine degrades by gracefully reducing gap space first, then margin, before finally flooring cell size at 1pt (no more 44pt clamp).

Because the configuration surface requires sliders and steppers to edit these exact values, presets are authored in the main iOS app instead of the widget menu.

### BoardPresetStore and App Groups
Presets are managed by `BoardPresetStore`, which persists them as JSON via `UserDefaults`. Because the Widget runs in a separate process from the App, they must communicate through an App Group (`group.com.hmatt1.launcherboard`). 

The widget reads the preset via `BoardPresetStore.loadRaw()`. Saving an edit in the app triggers `WidgetCenter.shared.reloadAllTimelines()` to push the changes instantly.

If an existing widget on a user's home screen was placed with the older version of the app, its `LauncherIntent` will have outdated properties. The `LauncherIntent` now uses an `EntityQuery` to look up the new `preset` parameter. By fallback, any corrupted or unreadable store automatically resolves to a built-in `Default` preset, avoiding blank widgets during upgrades.

`BoardGrid.resolve` is pure arithmetic, so its invariants are checkable without a simulator:

```bash
python3 Tools/verify-layout.py
```

That walks every family, shortcut count, explicit column count, template, published iPhone widget canvas and a range of name lengths, and asserts that no cell shrinks below 1pt, that the chosen text style still fits on every device rather than only on the smallest, that resolved values match requested values when space permits, and that every accent clears 4.5:1 against its label and 1.5:1 against both background stops. Run it after touching `Shared/BoardGrid.swift`, `Shared/BoardPreset.swift`, or `Shared/Theme.swift`.

### Density templates

Five bundled steps — `Flush`, `Hairline`, `Standard`, `Relaxed`, `Open` (`DensityTemplate.all` in `Shared/BoardPresetStore.swift`) — on one "breathing room" axis. Each step moves margin, spacing, padding, and corner radius together, so applying one gives a complete, coherent look rather than a set of independent sliders. Margin never falls below spacing (an even ladder: margin +4, spacing +3 per step); padding is kept the smallest gap value and only climbs once a step's 8pt legibility floor is behind it, because `BoardGrid.resolve` degrades spacing and margin under pressure but can never claw back padding; inner corner radius is capped at 15 so no step turns a small widget's tiles into pills; outer corner radius is a constant 22, matching the iOS widget's own container corner so a board's outer tiles fuse into the system mask.

## Rendering

Accented mode was designed first. When someone picks a tinted or clear Home Screen the system switches the widget out of `WidgetRenderingMode.fullColor`, tints content white and replaces the container background. The widget then draws no background and no color, and each tile keeps a translucent white chip, because the system preserves the opacity of translucent content and tints it. That chip is what keeps the board readable as a grid once the color is gone. All widget content is one group, so there is nothing for `.widgetAccentable()` to separate.

Tiles keep their rounded corners even at `Flush`, where there is no gap at all: at zero separation the corner notch is the only thing marking where one tap target ends and the next begins, and in accented mode every tile carries the same fill.

Full color adds exactly one thing on top: a flat surface per tile and a background. No gradients on tiles, no strokes, no shadows, and no `Material` or `.glassEffect` on a tile anywhere. Liquid Glass belongs to the system.

Every accent in the eight chromatic themes (`Shared/Theme.swift`; `Ink` and `Paper` are monochrome) clears 4.5:1 against its label color and 1.5:1 against both of its theme's background stops. Contrast is fixed in the palette and checked by `Tools/verify-layout.py`, never computed at runtime.

## Background

Three styles: **Solid Color** (the theme background), **System Default** (a plain system material), and **Transparent**.

Transparent blends the widget into the wallpaper. iOS never lets a widget read the Home Screen, so the person uploads a screenshot of their wallpaper and picks which of nine slots the widget sits in. On upload the app normalises the screenshot to the device's exact native pixels — once, in the app process, with no JPEG pass and no rescale — then slices one small PNG per slot (`Shared/WidgetGeometry.swift` holds the per-device grid) into the App Group container. The widget loads only its single slice, so it never carries a full-screen bitmap into the extension's tight memory budget. `Tools/verify-widget-geometry.py` asserts every slice rectangle stays fully on screen.

The slice is drawn as widget *content*, beneath the board, and the container background is kept clear, so the system's Liquid Glass never composites over it. A faint Liquid Glass rim around the widget itself is drawn by iOS 27 and is not app-removable; `Settings › Display & Brightness › Liquid Glass` is the only control over it.

## Build

On a Mac:

```bash
brew install xcodegen
xcodegen generate
open LauncherBoard.xcodeproj
```

Set your Personal Team under **Signing & Capabilities** for both targets, enable **Developer Mode** under **Settings > Privacy & Security** on the iPhone, then run. The generated project carries no signing overrides, so this works; the unsigned build for release passes them on the `xcodebuild` command line instead.

From Windows, download `LauncherBoard.ipa` from **Releases** and sideload it using [Impactor](https://impactor.claration.dev/). Enable **Developer Mode** on the iPhone first, then trust the developer under **Settings > General > VPN & Device Management**. Free-signed apps expire after seven days, so you will need to re-sideload weekly unless you use a paid developer account.

Tag a release to publish a new build:

```bash
gh release create v2.0.0 --generate-notes
```

## Files

```
Shared/Theme.swift            the 10 default themes, as a plain enum
Shared/BoardPresetStore.swift  density templates, default presets, persistence
Shared/BoardGrid.swift        columns, rows, tile mode, touch-target clamp, type scale, sample names
Shared/BoardView.swift        tiles, empty state
Shared/WidgetBackground.swift background resolver, wallpaper-slice view
Shared/WidgetGeometry.swift   per-device widget grid; maps a slot to a wallpaper rectangle
Shared/WallpaperStore.swift   normalises the screenshot and pre-renders one slice per slot
App/App.swift                 the whole app
App/Assets.xcassets           app icon and accent color
Widget/LauncherIntent.swift   parameters, AppEnum conformances
Widget/Widget.swift           provider, entry view, widget
Tools/verify-layout.py           re-derives the layout arithmetic and checks it
Tools/verify-widget-geometry.py  re-derives the wallpaper-slice rectangles and checks they stay on screen
```

`Shared/` never imports AppIntents. `BoardView` takes a tile builder, so the widget wraps each tile in `Button(intent:)` and the app renders the same `SlotFace` inert.

## Development Lessons Learned

While building this widget, we encountered and resolved several strict Apple requirements for iOS 27 widgets:

1. **App Extensions Must be Embedded:** Widgets must be explicitly embedded into the main app for them to be signed and installed properly via tools like Sideloadly. This requires the `embed: true` flag in the `project.yml` dependencies.
2. **Synchronized Version Strings:** Apple strictly mandates that App Extensions share the exact same `CFBundleVersion` and `CFBundleShortVersionString` as their parent App. Our `project.yml` sets these dynamically using Xcode variables `$(CURRENT_PROJECT_VERSION)` and `$(MARKETING_VERSION)`, which are injected by the GitHub Action at compile time.
3. **Globally Unique Bundle Identifiers:** Bundle IDs must be globally unique to bypass Apple's free-tier signing restrictions (e.g., `com.hmatt1.launcherboard` and `com.hmatt1.launcherboard.Widget`).
4. **Xcode 27 Cloud Compilation:** iOS 27 features like `RunSystemShortcutIntent` require the Xcode 27 SDK. Our GitHub Action uses `runs-on: xcode-27` to ensure the cloud compiler recognizes these new APIs.
5. **Widget Intent Constraints:** The iOS 27 `RunSystemShortcutIntent` is only valid when explicitly passed into a `Button(intent:)` initializer within the widget's view.

## License

MIT. Take it, change it, ship it.
