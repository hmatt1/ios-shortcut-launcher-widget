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

## If you want this automated instead of shot by hand

Fastlane's `snapshot` tool drives the Simulator through a UI-test target and
captures screenshots at every required size automatically, from a script
you write once. Setting that up (a UI test target in `project.yml` + a
`Snapfile` + the driver script) is a real option if you'd rather not take
these by hand every release — but it needs an actual Mac with a simulator to
write and verify, which isn't available in this environment, so I didn't
build it blind. Say the word if you want me to draft it anyway for you to
verify on your own machine.
