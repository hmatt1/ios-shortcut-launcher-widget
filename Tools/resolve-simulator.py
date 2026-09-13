#!/usr/bin/env python3
"""Resolve which iOS Simulator device types + runtime to boot for
.github/workflows/screenshots.yml, without hardcoding a specific
iPhone/iPad generation or iOS version that might not exist on a given
Xcode's simulator runtime list.

Picks the newest "iPhone ... Pro Max"-class device type, the newest
"iPad Pro"-class device type, and the newest available iOS runtime, all by
querying `xcrun simctl list ... -j` directly - so this always matches
whatever Xcode is actually installed on the CI runner, instead of a value
hardcoded when this script was written.

Prints three `KEY=value` lines to stdout, meant to be captured and appended
to $GITHUB_ENV by the workflow (see screenshots.yml's "Boot Simulators"
step) - kept as a standalone script rather than an inline `python3 -c`
heredoc in the YAML, since a multi-line quoted heredoc inside a `run: |`
block inherits the surrounding shell indentation verbatim and breaks
Python's own indentation rules.

Exits non-zero with the raw `simctl list` output printed to stderr if
either device-type category or the runtime can't be resolved, so a CI
failure here always shows exactly what was actually available.
"""
import json
import subprocess
import sys


def simctl_json(*args):
    result = subprocess.run(["xcrun", "simctl", "list", *args, "-j"], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def newest(candidates, key):
    if not candidates:
        return None
    return sorted(candidates, key=key)[-1]


def main():
    devicetypes = simctl_json("devicetypes")["devicetypes"]

    # Device-type identifiers embed the generation as a plain number (e.g.
    # "...iPhone-17-Pro-Max"), so a plain string sort orders them correctly
    # as long as the number stays 2 digits - true today, and cheap to
    # revisit if it ever isn't.
    iphone = newest(
        [t for t in devicetypes if "iPhone" in t["name"] and "Pro Max" in t["name"]],
        key=lambda t: t["identifier"],
    )
    ipad = newest(
        [t for t in devicetypes if "iPad Pro" in t["name"]],
        key=lambda t: t["identifier"],
    )
    if not iphone or not ipad:
        print("Could not resolve a simulator device type. Available device types:", file=sys.stderr)
        print(json.dumps(devicetypes, indent=2), file=sys.stderr)
        sys.exit(1)

    runtimes = simctl_json("runtimes")["runtimes"]
    runtime = newest(
        [r for r in runtimes if r["name"].startswith("iOS") and r.get("isAvailable", True)],
        key=lambda r: r["version"],
    )
    if not runtime:
        print("Could not resolve an iOS simulator runtime. Available runtimes:", file=sys.stderr)
        print(json.dumps(runtimes, indent=2), file=sys.stderr)
        sys.exit(1)

    print(f"IPHONE_TYPE={iphone['identifier']}")
    print(f"IPAD_TYPE={ipad['identifier']}")
    print(f"RUNTIME={runtime['identifier']}")


if __name__ == "__main__":
    main()
