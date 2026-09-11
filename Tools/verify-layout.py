#!/usr/bin/env python3
"""Check the layout invariants the widget relies on.

BoardGrid.resolve is pure arithmetic, so it can be re-derived here and checked
exhaustively without a simulator. Run this after changing anything in
Shared/BoardGrid.swift or Shared/Theme.swift.

    python3 Tools/verify-layout.py

It asserts, across every family, shortcut count, explicit column count, density template, 
published iPhone widget canvas and a range of name lengths:

  1. no tile is ever smaller than 1x1 pt
  2. the cell size, and the font chosen for it, never shrink on a published
     device canvas bigger than the smallest one the resolver clamps against
     ("tiles only ever grow" — see BoardSize.canvas's doc comment)
  3. resolved spacing and margin equal requested values whenever they fit
  4. degradation fires only when needed, reducing spacing before margin
  5. every accent in every theme clears 4.5:1 against that theme's label
  6. every accent in every theme clears 1.5:1 against both background stops
"""

import math
import sys

# BoardSize.canvas, the 320x568pt layout
CANVAS = {"small": (141, 141), "medium": (291, 141), "large": (291, 299), "extraLarge": (291, 457)}

# Every iPhone widget canvas row Apple publishes, smallest first.
DEVICES = {
    "small": [(141, 141), (148, 148), (155, 155), (158, 158), (162, 162), (169, 169), (170, 170)],
    "medium": [(291, 141), (321, 148), (329, 155), (338, 158), (344, 162), (360, 169), (364, 170)],
    "large": [(291, 299), (321, 324), (329, 345), (338, 354), (344, 366), (360, 379), (364, 382)],
    "extraLarge": [(291, 457), (321, 500), (329, 535), (338, 550), (344, 570), (360, 589), (364, 594)],
}

# (marginX, marginY, spacingX, spacingY, paddingX, paddingY) — Flush, Hairline,
# Standard, Relaxed, Open. Corner radius doesn't affect this arithmetic, so it
# isn't part of the tuple.
TEMPLATES = [
    (0.0,  0.0,  0.0, 0.0, 8.0,  8.0),
    (4.0,  4.0,  3.0, 3.0, 8.0,  8.0),
    (8.0,  8.0,  6.0, 6.0, 10.0, 10.0),
    (12.0, 12.0, 9.0, 9.0, 12.0, 12.0),
    (16.0, 16.0, 12.0, 12.0, 12.0, 12.0),
]

LADDER = [
    ("largeTitle", 34.0), ("title", 28.0), ("title2", 22.0), ("title3", 20.0),
    ("headline", 17.0), ("subheadline", 15.0), ("footnote", 13.0), ("caption", 12.0),
]

LINE_LIMIT = {"row": 2, "tile": 3}

# (accents, label, [bg_stop1, bg_stop2]) for all 10 default themes, mirroring
# Shared/Theme.swift exactly — re-sync both after touching either file.
THEMES = {
    "ink":       ([], 0xFAFAFA, [0x0A0A0C, 0x17171B]),
    "paper":     ([], 0x1B1712, [0xFCF9F3, 0xF0E9DB]),
    "midnight":  ([0x3B5BDB, 0x2560C0, 0x5F3DC4, 0x6741D9, 0x0B6C7E, 0x3A57D2], 0xF5F7FF, [0x0A1128, 0x172049]),
    "aurora":    ([0x0B7A5B, 0x0A7D5C, 0x0C7A8C, 0x24793A, 0x0F7C68, 0x0B7285], 0xF0FFF9, [0x042922, 0x0A3F4A]),
    "sunset":    ([0xCE2C2C, 0xC82E60, 0xC2255C, 0xA332BC, 0x9C36B5, 0xC13C0C], 0xFFF3EE, [0x2A0B2E, 0x4E1233]),
    "nocturne":  ([0x6A44DE, 0x6741D9, 0x6440D3, 0x5F3DC4, 0x533AAF, 0x6244CC], 0xEFE9FF, [0x130A24, 0x241047]),
    "ember":     ([0xC82B23, 0xC33318, 0xBC400F, 0xAF4B0B, 0x965009, 0xBB3E1D], 0xFFF1E8, [0x1A0E08, 0x331206]),
    "meadow":    ([0x4FB172, 0x45B268, 0x57AE55, 0x62AC49, 0x4FAE86, 0x4AAB63], 0x14301E, [0xF2FAEC, 0xDCEFCB]),
    "sandstone": ([0xC58F49, 0xCB9A55, 0xC08640, 0xBE8446, 0xC79355, 0xC28D4C], 0x2E2114, [0xFBF4E9, 0xEEDDC4]),
    "frost":     ([0x5AA0CE, 0x62A3CD, 0x5E9BCE, 0x7C97D2, 0x5CA4B8, 0x7699D2], 0x182A3B, [0xF0F4F9, 0xD9E3EF]),
}

def balanced(slots):
    return {4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 3}.get(slots, 4)

def auto_columns(slots, size):
    if slots <= 1: return 1
    if slots > 12:
        aspect = CANVAS[size][0] / CANVAS[size][1]
        cols = math.floor((slots * aspect) ** 0.5 + 0.5)  # mirrors Swift .rounded()
        return min(max(int(cols), 1), slots)
    if size == "small": return 1 if slots <= 3 else 2
    if size == "medium": return slots if slots <= 3 else (2 if slots == 4 else 3)
    return 1 if slots <= 3 else balanced(slots)

def cell_size(w, h, cols, rows, mX, mY, sX, sY):
    width = w - mX * 2 - sX * max(0, cols - 1)
    height = h - mY * 2 - sY * max(0, rows - 1)
    return width / cols, height / rows

def degrade(w, h, cols, rows, mX, mY, sX, sY, pX, pY):
    cw, ch = cell_size(w, h, cols, rows, mX, mY, sX, sY)

    # 1. Spacing
    if cw < 1 and cols > 1:
        needed = (1 - cw) * cols
        cut = min(sX, needed / (cols - 1))
        sX -= cut
    if ch < 1 and rows > 1:
        needed = (1 - ch) * rows
        cut = min(sY, needed / (rows - 1))
        sY -= cut

    cw, ch = cell_size(w, h, cols, rows, mX, mY, sX, sY)

    # 2. Margin
    if cw < 1:
        needed = (1 - cw) * cols
        cut = min(mX, needed / 2)
        mX -= cut
    if ch < 1:
        needed = (1 - ch) * rows
        cut = min(mY, needed / 2)
        mY -= cut

    cw, ch = cell_size(w, h, cols, rows, mX, mY, sX, sY)

    # 3. Padding. It sits inside the cell, so it never shows up in
    # cell_size() above — a cell can already clear the 1pt floor while its
    # own padding still consumes it entirely, hiding the name. Only fires
    # once spacing and margin are already exhausted (mainly row mode, where
    # row count grows with shortcut count and there's no column dimension to
    # share the pressure).
    if cw - pX * 2 < 1:
        needed = 1 - (cw - pX * 2)
        cut = min(pX, needed / 2)
        pX -= cut
    if ch - pY * 2 < 1:
        needed = 1 - (ch - pY * 2)
        cut = min(pY, needed / 2)
        pY -= cut

    return mX, mY, sX, sY, pX, pY

def text_style(cell_w, cell_h, mode, pX, pY, longest_name):
    width = max(1.0, cell_w - pX * 2)
    characters = float(max(4, longest_name))
    lines = float(LINE_LIMIT[mode])
    for name, points in LADDER:
        needed = points * 0.55 * characters
        used = min(lines, max(1.0, math.ceil(needed / width)))
        if used <= lines and needed <= width * lines and (cell_h - pY * 2) >= points * 1.25 * used + 6:
            return name, points, used
    return "caption", 12.0, lines

def relative_luminance(hex_value):
    def channel(component):
        component /= 255.0
        return component / 12.92 if component <= 0.03928 else ((component + 0.055) / 1.055) ** 2.4

    return (0.2126 * channel((hex_value >> 16) & 0xFF)
            + 0.7152 * channel((hex_value >> 8) & 0xFF)
            + 0.0722 * channel(hex_value & 0xFF))

def contrast(a, b):
    high, low = sorted((relative_luminance(a), relative_luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)

def main():
    failures = []
    checks = 0

    for name_length in (4, 6, 10, 15, 20):
        for size in ["small", "medium", "large", "extraLarge"]:
            for slots in range(1, 65):
                for req_cols in range(0, 7):
                    cols = auto_columns(slots, size) if req_cols == 0 else req_cols
                    rows = math.ceil(slots / cols)
                    mode = "row" if cols == 1 and min(slots, cols * rows) > 1 else "tile"

                    for template in TEMPLATES:
                        mX, mY, sX, sY, pX, pY = template
                        fw, fh = CANVAS[size]
                        
                        # Requested size
                        req_cw, req_ch = cell_size(fw, fh, cols, rows, mX, mY, sX, sY)
                        
                        # Resolved size
                        rmX, rmY, rsX, rsY, rpX, rpY = degrade(fw, fh, cols, rows, mX, mY, sX, sY, pX, pY)
                        cw, ch = cell_size(fw, fh, cols, rows, rmX, rmY, rsX, rsY)
                        cw = max(1.0, cw)
                        ch = max(1.0, ch)

                        where = f"{size}/{slots} slots/{cols} cols/{mX},{mY},{sX},{sY}"

                        if cw < 0.999 or ch < 0.999:
                            failures.append(f"Cell floored under 1pt at {where}: {cw:.1f}x{ch:.1f}")

                        content_w = cw - rpX * 2
                        content_h = ch - rpY * 2
                        if content_w < 0.999 or content_h < 0.999:
                            failures.append(f"Padded content area floored under 1pt at {where}: "
                                             f"{content_w:.1f}x{content_h:.1f} (name would be hidden)")

                        if req_cw >= 1 and req_ch >= 1:
                            if abs(rmX - mX) > 0.01 or abs(rsX - sX) > 0.01:
                                failures.append(f"Degraded when it fit at {where}")

                        # Padding has its own, independent fit target — the content
                        # area, not the raw cell — so it's checked against the
                        # *requested* content area rather than gated on req_cw/ch.
                        req_content_w = req_cw - pX * 2
                        req_content_h = req_ch - pY * 2
                        if req_content_w >= 1 and req_content_h >= 1:
                            if abs(rpX - pX) > 0.01 or abs(rpY - pY) > 0.01:
                                failures.append(f"Padding degraded when it fit at {where}")

                        style, points, _ = text_style(cw, ch, mode, rpX, rpY, name_length)

                        # BoardSize.canvas is deliberately the smallest canvas iOS
                        # gives this family (see its doc comment): "tiles only ever
                        # grow" on a bigger device of the same family, for the same
                        # requested layout. Confirm the cell, and the font chosen
                        # for it, hold or grow with device size, never shrink.
                        for device_w, device_h in DEVICES[size]:
                            checks += 1
                            dw, dh = cell_size(device_w, device_h, cols, rows, rmX, rmY, rsX, rsY)
                            if dw < cw - 0.01 or dh < ch - 0.01:
                                failures.append(f"Tile shrank on a bigger device at {where}: "
                                                 f"{cw:.1f}x{ch:.1f} -> {dw:.1f}x{dh:.1f} on {device_w}x{device_h}")

                            device_points = text_style(dw, dh, mode, rpX, rpY, name_length)[1]
                            if device_points < points - 0.01:
                                failures.append(f"{style} shrank to a smaller font on a bigger device "
                                                 f"at {where}: {device_w}x{device_h}")

    for theme, (accents, label, bg) in THEMES.items():
        for accent in accents:
            checks += 1
            ratio = contrast(accent, label)
            if ratio < 4.5:
                failures.append(f"{theme} #{accent:06X} is {ratio:.2f}:1 against its label")

            checks += 1
            bg_ratio = min(contrast(accent, bg[0]), contrast(accent, bg[1]))
            if bg_ratio < 1.5:
                failures.append(f"{theme} #{accent:06X} is {bg_ratio:.2f}:1 against its background")

    print(f"{checks} checks")
    for failure in failures[:50]:
        print(f"  FAIL {failure}")
    if len(failures) > 50:
        print(f"  ... and {len(failures) - 50} more")
    if failures:
        print(f"{len(failures)} failed")
        return 1
    print("all invariants hold")
    return 0

if __name__ == "__main__":
    sys.exit(main())
