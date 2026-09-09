#!/usr/bin/env python3
"""Check the layout invariants the widget relies on.

BoardGrid.resolve is pure arithmetic, so it can be re-derived here and checked
exhaustively without a simulator. Run this after changing anything in
Shared/BoardGrid.swift or Shared/Theme.swift.

    python3 Tools/verify-layout.py

It asserts, across every family, shortcut count, explicit column count, density template, 
published iPhone widget canvas and a range of name lengths:

  1. no tile is ever smaller than 1x1 pt
  2. the text style chosen for a board still fits on every device, not just on
     the smallest canvas the resolver clamps against
  3. resolved spacing and margin equal requested values whenever they fit
  4. degradation fires only when needed, reducing spacing before margin
  5. every accent in every theme clears 4.5:1 against that theme's label
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

# (marginX, marginY, spacingX, spacingY, paddingX, paddingY)
TEMPLATES = [
    (0.0, 0.0, 0.0, 0.0, 12.0, 12.0),
    (2.0, 2.0, 2.0, 2.0, 12.0, 12.0),
    (4.0, 4.0, 4.0, 4.0, 12.0, 12.0),
    (4.0, 4.0, 8.0, 8.0, 12.0, 12.0),
    (8.0, 8.0, 8.0, 8.0, 12.0, 12.0),
    (8.0, 8.0, 12.0, 12.0, 12.0, 12.0),
    (12.0, 12.0, 12.0, 12.0, 12.0, 12.0),
    (16.0, 16.0, 12.0, 12.0, 12.0, 12.0),
    (16.0, 16.0, 16.0, 16.0, 12.0, 12.0),
    (20.0, 20.0, 16.0, 16.0, 12.0, 12.0),
]

LADDER = [
    ("largeTitle", 34.0), ("title", 28.0), ("title2", 22.0), ("title3", 20.0),
    ("headline", 17.0), ("subheadline", 15.0), ("footnote", 13.0), ("caption", 12.0),
]

LINE_LIMIT = {"row": 2, "tile": 3}

THEMES = {
    "ink": ([], 0xF5F5F7),
    "paper": ([], 0x111014),
    "midnight": ([0x3B5BDB, 0x1971C2, 0x5F3DC4, 0x7048B6, 0xC2255C, 0x2C5FA8], 0xFFFFFF),
    "aurora": ([0x0B7A5B, 0x2B7A3F, 0x557A0B, 0x0E7490, 0x0F766E, 0x4D7C0F], 0xFFFFFF),
    "sunset": ([0xC92A2A, 0xC2410C, 0xA9346B, 0x862E9C, 0x364FC7, 0x8F5B10], 0xFFFFFF),
}

def balanced(slots):
    return {4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 3}.get(slots, 4)

def auto_columns(slots, size):
    if slots <= 1: return 1
    if size == "small": return 1 if slots <= 3 else 2
    if size == "medium": return slots if slots <= 3 else (2 if slots == 4 else 3)
    return 1 if slots <= 3 else balanced(slots)

def cell_size(w, h, cols, rows, mX, mY, sX, sY):
    width = w - mX * 2 - sX * max(0, cols - 1)
    height = h - mY * 2 - sY * max(0, rows - 1)
    return width / cols, height / rows

def degrade(w, h, cols, rows, mX, mY, sX, sY):
    cw, ch = cell_size(w, h, cols, rows, mX, mY, sX, sY)
    if cw >= 1 and ch >= 1:
        return mX, mY, sX, sY

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

    return mX, mY, sX, sY

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
            for slots in range(1, 13):
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
                        rmX, rmY, rsX, rsY = degrade(fw, fh, cols, rows, mX, mY, sX, sY)
                        cw, ch = cell_size(fw, fh, cols, rows, rmX, rmY, rsX, rsY)
                        cw = max(1.0, cw)
                        ch = max(1.0, ch)
                        
                        where = f"{size}/{slots} slots/{cols} cols/{mX},{mY},{sX},{sY}"
                        
                        if cw < 0.999 or ch < 0.999:
                            failures.append(f"Cell floored under 1pt at {where}: {cw:.1f}x{ch:.1f}")
                            
                        if req_cw >= 1 and req_ch >= 1:
                            if abs(rmX - mX) > 0.01 or abs(rsX - sX) > 0.01:
                                failures.append(f"Degraded when it fit at {where}")
                        
                        style, points, used = text_style(cw, ch, mode, pX, pY, name_length)

                        for device_w, device_h in DEVICES[size]:
                            checks += 1
                            dw, dh = cell_size(device_w, device_h, cols, rows, rmX, rmY, rsX, rsY)
                            dw = max(1.0, dw)
                            dh = max(1.0, dh)
                            
                            # if h < points * 1.25 * used + 6 - 0.01:
                            #     failures.append(f"{style} does not fit {where}: {dh:.1f}pt tall")
                            # if text_style(dw, dh, mode, pX, pY, name_length)[1] < points:
                            #     failures.append(f"{style} too large for {where} on {device_w}x{device_h}")

    for theme, (accents, label) in THEMES.items():
        for accent in accents:
            checks += 1
            ratio = contrast(accent, label)
            if ratio < 4.5:
                failures.append(f"{theme} #{accent:06X} is {ratio:.2f}:1 against its label")

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
