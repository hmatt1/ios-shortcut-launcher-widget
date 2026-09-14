#!/usr/bin/env python3
"""Reads a JSON file produced by `footprint -pid <pid> -j <path>` (Apple's
real memory-footprint tool - see WidgetMemoryCheck/EnterJiggleModeTests.swift
and .github/workflows/widget-memory-check.yml) and prints the process's real
physical-footprint reading in a human-readable form.

`phys_footprint` is the same ledger value the kernel's own jetsam/memory-
pressure accounting uses - not just RSS - which is why this project uses
`footprint` instead of a simpler tool like `ps`.

The exact shape of footprint's JSON output wasn't confirmed by this
project's own research before the first real CI run could produce a sample
to check against - so this searches the whole parsed structure for a
'phys_footprint' key at any depth, rather than assuming one fixed path.

Usage:
    print-footprint.py <footprint.json> [max_mb]

With an optional `max_mb`, exits 1 (after still printing the reading) if
phys_footprint exceeds it. Apple doesn't publish an official per-widget
limit, so this isn't a precise cutoff - just a guard against a gross
regression, set with real headroom above the current real baseline
reading (see widget-memory-check.yml).
"""
import json
import sys


def find_phys_footprint(data):
    """Recursively search a parsed JSON structure for a 'phys_footprint'
    key at any depth, returning its value, or None if it isn't present
    anywhere."""
    if isinstance(data, dict):
        if "phys_footprint" in data:
            return data["phys_footprint"]
        for value in data.values():
            found = find_phys_footprint(value)
            if found is not None:
                return found
    elif isinstance(data, list):
        for item in data:
            found = find_phys_footprint(item)
            if found is not None:
                return found
    return None


def format_bytes(n):
    """A plain byte count as human-readable MB, to 2 decimal places."""
    return f"{n / (1024 * 1024):.2f} MB"


def main(argv):
    if len(argv) not in (2, 3):
        print("usage: print-footprint.py <footprint.json> [max_mb]", file=sys.stderr)
        return 2

    with open(argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)

    phys_footprint = find_phys_footprint(data)
    if phys_footprint is None:
        print("No 'phys_footprint' key found anywhere in the JSON.", file=sys.stderr)
        return 1

    print(f"phys_footprint: {phys_footprint} bytes ({format_bytes(phys_footprint)})")

    if len(argv) == 3:
        max_bytes = float(argv[2]) * 1024 * 1024
        if phys_footprint > max_bytes:
            print(
                f"FAIL: phys_footprint ({format_bytes(phys_footprint)}) exceeds "
                f"the {argv[2]} MB threshold.",
                file=sys.stderr,
            )
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
