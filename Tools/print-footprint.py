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
    if len(argv) != 2:
        print("usage: print-footprint.py <footprint.json>", file=sys.stderr)
        return 2

    with open(argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)

    phys_footprint = find_phys_footprint(data)
    if phys_footprint is None:
        print("No 'phys_footprint' key found anywhere in the JSON.", file=sys.stderr)
        return 1

    print(f"phys_footprint: {phys_footprint} bytes ({format_bytes(phys_footprint)})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
