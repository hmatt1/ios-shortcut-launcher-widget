# App Store listing copy

Reference copy for the "Prepare for Submission" page in App Store Connect
(see issue #3). Character counts are approximate — ASC will tell you exactly
if something's over, and none of this is locked in until you submit.

## Name (≤30 chars)

    Shortcut Launcher Widget

Matches `CFBundleDisplayName` already — no reason for the store listing to
say something different from what's on the Home Screen.

## Subtitle (≤30 chars)

    Run your Shortcuts, tap once

## Promotional text (≤170 chars, editable anytime without a new build)

    New: the Extra Large widget fills a whole Home Screen page. Ten themes,
    five densities, your own columns — all running the Shortcuts you already
    built.

## Description (≤4000 chars)

    Shortcut Launcher Widget turns your Home Screen into a typographic
    launchpad for the Shortcuts you already have.

    Pick the shortcuts you want — up to 64 — and they become a grid of named
    tiles. Tap one and it runs right there, in place. Nothing opens.

    • Four widget sizes, including the new Extra Large full-page widget
    • 10 built-in color themes, or build your own
    • Five density presets from edge-to-edge to roomy, or dial in exact
      margins, spacing, and corner radius yourself
    • Explicit column control — auto-fit, or pin 1, 2, 3, or more
    • Three backgrounds: a solid theme color, the system's own material, or
      your own wallpaper blended in behind the widget
    • Save multiple board presets and switch between them instantly

    No accounts. No network access. No analytics. No ads. Nothing to buy.
    It's a Home Screen tool, not a service.

## Keywords (≤100 chars total, comma-separated, no spaces after commas)

    shortcuts,widget,launcher,home screen,automation,productivity,theme,icons,appintents

## Category

- Primary: **Utilities**
- Secondary: **Productivity**

## Support URL

    https://hmatt1.github.io/ios-shortcut-launcher-widget/support/

(Built in this repo — see `docs/support/index.html`. Real FAQ, not a
placeholder.)

## Marketing URL

Leave blank — optional, and there's no separate marketing site.

## Notes for Review

Paste this into the Notes for Review field when submitting (see issue #6):

    Shortcut Launcher Widget is a Home Screen widget configurator. Each tile
    on the widget is a button built with iOS 27's RunSystemShortcutIntent —
    tapping it runs one of the person's own Shortcuts in place, via the
    system's own widget-button API; the app itself never sees what that
    shortcut does.

    The app (this target) is the configuration surface: pick a density,
    theme, background, and column layout, then choose which of the person's
    Shortcuts appear on the widget via Edit Widget on the Home Screen.

    Because the board's content depends on Shortcuts already existing on the
    test device, a stock/empty Shortcuts library will show an empty-state
    message ("Edit Widget") rather than a populated board. Apple's own
    Shortcuts app ships with a handful of default shortcuts, so even a fresh
    device has something to select — but for the fullest picture, creating
    3-6 shortcuts first (e.g. from the Shortcuts app's own gallery) before
    testing the widget will show the intended experience.

    No accounts, no network access, no analytics, no ads, no in-app
    purchases.
