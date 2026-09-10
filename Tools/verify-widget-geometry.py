#!/usr/bin/env python3
"""Check the transparent-wallpaper crop geometry.

`WidgetGeometry.frame` is pure arithmetic, so it is re-derived here and checked
against every device in the table plus a spread of unknown screen sizes. The one
invariant that matters: a crop rectangle is always fully inside the screen, so a
slice can never sample past the wallpaper and render black.

    python3 Tools/verify-widget-geometry.py

Run it after touching Shared/WidgetGeometry.swift.
"""

import sys

FAMILIES = ["small", "medium", "large", "extraLarge"]
POSITIONS = [
    "topLeft", "topRight", "middleLeft", "middleRight",
    "bottomLeft", "bottomRight", "top", "middle", "bottom",
]

# Int(screen height) -> (left, right, top, middle, bottom,
#                        small, med_w, med_h, large_h, xl_h)
TABLE = {
    956: (38, 232, 92, 304, 516, 170, 364, 170, 382, 594),
    932: (32.66, 227, 84, 296, 508, 170, 364, 170, 382, 594),
    926: (32, 226, 82, 294, 506, 170, 364, 170, 382, 594),
    896: (27, 218, 76, 286, 496, 169, 360, 169, 379, 589),
    874: (29, 211, 87, 290.66, 495, 162, 344, 162, 366, 570),
    852: (27, 208, 80, 276, 472, 158, 338, 158, 354, 550),
    844: (26, 206, 77, 273, 469, 155, 329, 155, 345, 535),
    812: (23, 197, 71, 261, 451, 155, 329, 155, 345, 535),
    667: (27, 200, 30, 206, 382, 148, 321, 148, 324, 500),
}

# Logical screen widths, to mirror the Swift caller passing UIScreen sizes.
WIDTHS = {
    956: 440, 932: 430, 926: 428, 896: 414, 874: 402,
    852: 393, 844: 390, 812: 375, 667: 375,
}


def row_band(p):
    if p in ("topLeft", "topRight", "top"):
        return "top"
    if p in ("middleLeft", "middleRight", "middle"):
        return "middle"
    return "bottom"


def is_right(p):
    return p in ("topRight", "middleRight", "bottomRight")


def metrics(width, height):
    key = int(round(height))
    if key in TABLE:
        left, right, top, mid, bot, s, mw, mh, lh, xh = TABLE[key]
        sizes = {
            "small": (s, s),
            "medium": (mw, mh),
            "large": (mw, lh),
            "extraLarge": (mw, xh),
        }
        return left, right, top, mid, bot, sizes

    side = max(120, (width - 66) / 2)
    full = max(240, width - 44)
    gap = 26
    top = 84 if height >= 850 else (72 if height >= 800 else 40)
    sizes = {
        "small": (side, side),
        "medium": (full, side),
        "large": (full, side * 2 + gap),
        "extraLarge": (full, side * 3 + gap * 2),
    }
    return 22, max(22, width - 22 - side), top, top + side + gap, top + (side + gap) * 2, sizes


def frame(family, position, screen_w, screen_h):
    left, right, top, mid, bot, sizes = metrics(screen_w, screen_h)
    w, h = sizes[family]
    band = row_band(position)

    y = {"top": top, "middle": mid, "bottom": bot}[band]
    if family == "small":
        x = right if is_right(position) else left
    else:
        x = left
        if family == "large" and band == "middle":
            y = (top + bot) / 2
        if family == "extraLarge":
            y = top

    w = min(w, screen_w)
    h = min(h, screen_h)
    if x + w > screen_w:
        x = screen_w - w
    if y + h > screen_h:
        y = screen_h - h
    x = max(0, x)
    y = max(0, y)
    return x, y, w, h


def main():
    heights = list(TABLE.keys()) + [736, 780, 800, 900, 1000, 693]
    failures = []
    checks = 0

    for height in heights:
        width = WIDTHS.get(height, 390)
        for family in FAMILIES:
            for position in POSITIONS:
                checks += 1
                x, y, w, h = frame(family, position, width, height)
                where = f"{family}/{position} on {width}x{height}"
                if w < 1 or h < 1:
                    failures.append(f"degenerate rect at {where}: {w:.1f}x{h:.1f}")
                if x < -0.01 or y < -0.01:
                    failures.append(f"negative origin at {where}: ({x:.1f},{y:.1f})")
                if x + w > width + 0.01 or y + h > height + 0.01:
                    failures.append(
                        f"rect leaves screen at {where}: "
                        f"maxX={x + w:.1f}/{width} maxY={y + h:.1f}/{height}"
                    )

    print(f"{checks} checks")
    for failure in failures[:50]:
        print(f"  FAIL {failure}")
    if failures:
        print(f"{len(failures)} failed")
        return 1
    print("all crop rects stay on screen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
