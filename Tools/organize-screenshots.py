#!/usr/bin/env python3
"""Extract XCTAttachment screenshots from an xcresult bundle (already
exported via `xcrun xcresulttool export attachments`) and organize them
into a clean, predictably-named folder for zipping.

xcresulttool's `export attachments` subcommand writes a manifest.json file
into the output directory alongside the exported attachment files
(themselves given opaque/hashed names). Confirmed against a real Xcode 27
run: the manifest is a JSON list with one entry per TEST METHOD, each
carrying a nested "attachments" list of per-screenshot dicts shaped like:

    {"exportedFileName": "263386A9-....png",
     "suggestedHumanReadableName": "04-columns-grid_0_4CA571A8-....png",
     ...}

"suggestedHumanReadableName" is the name given via `XCTAttachment.name` in
the UI test (see WidgetScreenshots/Navigation.swift's
captureScreenshot(named:)) with an xcresulttool-appended "_<index>_<uuid>"
suffix before the extension - stripped back off here by splitting on the
first "_", which works because none of this repo's shot names contain one
(see WidgetScreenshots/ScreenshotTests.swift).

Usage:
    python3 Tools/organize-screenshots.py <xcresulttool-export-dir> <dest-dir> [--prefix name]

<xcresulttool-export-dir> is the --output-path passed to
`xcrun xcresulttool export attachments`. <dest-dir> is where renamed PNGs
land, created if missing. --prefix optionally namespaces output filenames
(e.g. "iphone", "ipad") when this runs once per device class.
"""
import json
import shutil
import sys
from pathlib import Path


def find_manifest(export_dir):
    for name in ("manifest.json", "Manifest.json"):
        candidate = export_dir / name
        if candidate.exists():
            return candidate
    raise SystemExit(
        f"No manifest found in {export_dir} - list its contents and check "
        "xcresulttool's actual output shape for this Xcode version; the "
        "manifest filename or location may differ from what this script "
        "expects."
    )


def collect_attachments(manifest):
    """Flattens the manifest's per-test entries into a single list of
    attachment dicts. Accepts a couple of alternate shapes defensively,
    since only the list-of-tests-with-nested-attachments shape has actually
    been confirmed against real xcresulttool output."""
    if isinstance(manifest, dict):
        manifest = manifest.get("attachments", manifest.get("data", manifest.get("tests", [])))
    if not isinstance(manifest, list):
        return []

    attachments = []
    for entry in manifest:
        if not isinstance(entry, dict):
            continue
        nested = entry.get("attachments")
        if isinstance(nested, list):
            attachments.extend(a for a in nested if isinstance(a, dict))
        elif "exportedFileName" in entry:
            # Already a flat attachment dict - an older/alternate schema.
            attachments.append(entry)
    return attachments


def shot_name(attachment):
    """Recovers the exact string passed to XCTAttachment.name from
    xcresulttool's "<name>_<index>_<uuid>" suggested name."""
    suggested = attachment.get("suggestedHumanReadableName") or attachment.get("name")
    if not suggested:
        return None
    return Path(suggested).stem.split("_")[0]


def main():
    args = sys.argv[1:]
    prefix = ""
    if "--prefix" in args:
        i = args.index("--prefix")
        prefix = args[i + 1] + "-"
        del args[i:i + 2]

    if len(args) != 2:
        raise SystemExit(__doc__)

    export_dir = Path(args[0])
    dest_dir = Path(args[1])
    dest_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = find_manifest(export_dir)
    manifest = json.loads(manifest_path.read_text())
    attachments = collect_attachments(manifest)

    copied = 0
    for attachment in attachments:
        exported = attachment.get("exportedFileName")
        name = shot_name(attachment)
        if not exported or not name:
            print(f"  skipping unrecognized attachment entry: {attachment}")
            continue
        src = export_dir / exported
        if not src.exists():
            print(f"  exported file not found: {src}")
            continue
        dest = dest_dir / f"{prefix}{name}{src.suffix}"
        shutil.copy2(src, dest)
        print(f"  {src.name} -> {dest}")
        copied += 1

    if copied == 0:
        raise SystemExit(
            f"No screenshots copied from {export_dir} - the manifest was read "
            f"but no entry matched the expected shape. Print {manifest_path}'s "
            "contents and adjust collect_attachments()/shot_name() above to "
            "match its real keys."
        )
    print(f"Copied {copied} screenshot(s) into {dest_dir}")


if __name__ == "__main__":
    main()
