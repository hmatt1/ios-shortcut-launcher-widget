# Screenshot shot list

For issue #4. I can't capture these myself — no simulator or device in this
environment — but here's exactly what to set up for each one, in an order
that tells the app's actual story rather than just showing random screens.
5-6 shots is plenty; Apple allows up to 10 per device class.

Suggested caption text in *italics* — short, matches how the app actually
talks about itself (see `AppStore/listing.md`), not generic marketing-speak.

1. **Hero: a populated widget on the Home Screen.**
   The `Default` preset (Midnight theme, Standard density, Medium size),
   5-6 real-looking shortcut names selected, on an actual Home Screen.
   *Run your Shortcuts, right from the Home Screen.*

2. **Theme variety.**
   Two or three widgets side by side (or a quick sequence) showing clearly
   different looks — e.g. `Slate` (Ink, sharp edge-to-edge), `Field`
   (Meadow, light, System Default background), `Console` (Ember, tight).
   *Ten built-in themes. Or build your own.*

3. **The Extra Large widget.**
   A `systemExtraLargePortrait` widget filling a whole Home Screen page —
   this is the one genuinely new thing in this release, worth its own shot.
   *New in iOS 27: one widget, a whole page.*

4. **Columns, on purpose.**
   The in-app editor or Home Screen showing `Keypad` (pinned 3 columns) or
   `Grid` (pinned 2) next to an Auto-column board, so the difference reads
   at a glance.
   *Auto-fit, or pin the exact grid you want.*

5. **The editor itself.**
   `PresetEditorView` open, live preview visible, a density/theme control
   mid-adjustment. Shows there's real configuration depth, not just presets.
   *Every margin, corner, and color — yours to tune.*

6. **Transparent background blending into wallpaper.**
   A widget with Background set to Transparent, a real wallpaper uploaded,
   positioned so the blend is obviously working (not just a solid color by
   coincidence).
   *Blends right into your wallpaper.*

## Automated: `.github/workflows/screenshots.yml`

Built, not just drafted — trigger it by hand with
`gh workflow run screenshots.yml` whenever the UI changes enough to be worth
reshooting (it doesn't run on every push). It boots an iPhone and an iPad
Simulator on the `xcode-27` CI runner, drives the app's real editor UI (a
`WidgetScreenshotsUITests` target, `project.yml`) through shots 1-5 above,
and attaches the results as a zip on a new `screenshots-run-<N>` release —
a separate tag namespace from the app's real `v*` version releases.

Deliberately not Fastlane: this repo has no Ruby toolchain today, and a
plain XCUITest target does the same job without adding one. It drives
`PresetEditorView`'s live preview rather than a real Home Screen widget
placement — that preview shares its exact rendering pipeline with the real
widget (`Shared/BoardGrid.swift`, `Shared/BoardView.swift`), so the shots
are genuinely representative, no WidgetKit-hosting trickery needed.

Shot 6 (transparent wallpaper background) isn't covered — it needs a
bundled placeholder wallpaper and a way to get it into `WallpaperStore`
without fighting the system Photos picker in CI, which was left for a
follow-up rather than blocking the other five on it. Take that one by hand
for now, the same way you always could.

Like the code-signing pipeline before it, this couldn't be verified
end-to-end without a real CI run — expect the first `workflow_dispatch` to
need at least one small correction (`xcresulttool`'s exact flags, a
Simulator device-type name, animation timing), not a sign anything is
fundamentally wrong.
