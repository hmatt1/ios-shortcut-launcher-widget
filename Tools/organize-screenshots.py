#!/usr/bin/env python3
"""Extract XCTAttachment screenshots from an xcresult bundle (already
exported via `xcrun xcresulttool export attachments`) and organize them
into a clean, predictably-named folder for zipping.

xcresulttool's `export attachments` subcommand writes a manifest file into
the output directory alongside the exported attachment files (themselves
given opaque/hashed names). This script reads that manifest, matches each
entry back to the name given via `XCTAttachment.name` in the UI test (see
WidgetScreenshots/Navigation.swift's captureScreenshot(named:)), and copies
each PNG into <dest>/<prefix-><shot-name>.png.

The exact manifest schema is unconfirmed against a real Xcode 27
xcresulttool run - there's no Mac/Simulator available where this was
written. Written defensively on purpose: an unrecognized entry is logged
and skipped rather than crashing the workflow, since the actual schema is
exactly the kind of thing expected to need one corrective round once real
CI output is in hand (same as the earlier code-signing pipeline's
PKCS12/base64 fixes) - if that happens, print the manifest's real contents
and adjust attachment_display_name()/exported_file_path() below to match.

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
    # xcresulttool has used more than one manifest filename across Xcode
    # versions - check the documented current one first, then fall back.
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


def attachment_display_name(entry):
    # Try every key name xcresulttool has plausibly used for the
    # human-readable name (the one set via XCTAttachment.name in the test).
    # A key that isn't present is quietly skipped, not treated as an error.
    for key in ("name", "suggestedHumanReadableName", "attachmentName", "exportedFileName"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def exported_file_path(entry, export_dir):
    for key in ("exportedFileName", "filename", "fileName", "path"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            candidate = export_dir / value
            if candidate.exists():
                return candidate
    return None


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

    # The manifest's top-level shape (a bare list vs. {"attachments": [...]})
    # is unconfirmed - accept either.
    if isinstance(manifest, list):
        entries = manifest
    elif isinstance(manifest, dict):
        entries = manifest.get("attachments", manifest.get("data", []))
    else:
        entries = []
    if not isinstance(entries, list):
        raise SystemExit(f"Unexpected manifest shape in {manifest_path} - inspect it by hand.")

    copied = 0
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        name = attachment_display_name(entry)
        src = exported_file_path(entry, export_dir)
        if not name or not src:
            print(f"  skipping unrecognized manifest entry: {entry}")
            continue
        dest = dest_dir / f"{prefix}{name}{src.suffix}"
        shutil.copy2(src, dest)
        print(f"  {src.name} -> {dest}")
        copied += 1

    if copied == 0:
        raise SystemExit(
            f"No screenshots copied from {export_dir} - the manifest was read "
            f"but no entry matched the expected shape. Print {manifest_path}'s "
            "contents and adjust attachment_display_name()/exported_file_path() "
            "above to match its real keys."
        )
    print(f"Copied {copied} screenshot(s) into {dest_dir}")


if __name__ == "__main__":
    main()
