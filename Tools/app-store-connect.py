#!/usr/bin/env python3
"""Push App Store listing metadata and the Age Rating declaration via the
App Store Connect API, instead of clicking through App Store Connect by
hand. Covers issue #3 (listing copy) and the Age Rating half of issue #5.

It does NOT and CANNOT touch the App Privacy "nutrition label" ("Does this
app collect data?"). Apple's API has no resource for it at all — verified
by walking the full API reference tree (App Metadata group, the App
resource's complete relationships list, the API's own release notes).
That one question still has to be answered by hand in App Store Connect's
web UI: App Privacy → Get Started → "No, we do not collect data from this
app".

Requires:
    pip install pyjwt cryptography
    (on a Homebrew-managed macOS Python: pip install --break-system-packages
    pyjwt cryptography, or use a venv - PEP 668 blocks the plain form)

Credentials — reuse the same App Store Connect API key already used for
TestFlight uploads in .github/workflows/build.yml (same key, it already has
whatever role is needed):
    ASC_KEY_ID            Key ID (matches the ADMIN_APPSTORE_KEY_ID secret)
    ASC_ISSUER_ID         Issuer ID (matches the APPSTORE_ISSUER_ID secret)
    ASC_PRIVATE_KEY_PATH  path to the downloaded AuthKey_<KEY_ID>.p8 file

Usage:
    python3 Tools/app-store-connect.py              # dry run - prints, writes nothing
    python3 Tools/app-store-connect.py --apply       # actually writes

Run the dry run first and read the printed payloads before --apply — this
has not been exercised against a real App Store Connect record, since
there's no access to one from where it was written. Every write is a PATCH
(or create-if-missing) of the same fixed values below, so re-running it is
safe; it just won't change anything the second time.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # pip install pyjwt cryptography

API_BASE = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.hmatt1.shortcutlauncherwidget"  # project.yml
LOCALE = "en-US"

# ---------------------------------------------------------------------------
# Keep these in sync with AppStore/listing.md — that file is the same copy,
# written in prose for a human to review; this is what actually gets sent.
# ---------------------------------------------------------------------------
NAME = "Shortcut Launcher Widget"
SUBTITLE = "Run your Shortcuts, tap once"
PRIVACY_POLICY_URL = "https://hmatt1.github.io/ios-shortcut-launcher-widget/"
PROMOTIONAL_TEXT = (
    "New: the Extra Large widget fills a whole Home Screen page. Ten "
    "themes, five densities, your own columns — all running the "
    "Shortcuts you already built."
)
DESCRIPTION = """Shortcut Launcher Widget turns your Home Screen into a typographic launchpad for the Shortcuts you already have.

Pick the shortcuts you want — up to 64 — and they become a grid of named tiles. Tap one and it runs right there, in place. Nothing opens.

• Four widget sizes, including the new Extra Large full-page widget
• 10 built-in color themes, or build your own
• Five density presets from edge-to-edge to roomy, or dial in exact margins, spacing, and corner radius yourself
• Explicit column control — auto-fit, or pin 1, 2, 3, or more
• Three backgrounds: a solid theme color, the system's own material, or your own wallpaper blended in behind the widget
• Save multiple board presets and switch between them instantly

No accounts. No network access. No analytics. No ads. Nothing to buy. It's a Home Screen tool, not a service."""
KEYWORDS = "shortcuts,widget,launcher,home screen,automation,productivity,theme,icons,appintents"
SUPPORT_URL = "https://hmatt1.github.io/ios-shortcut-launcher-widget/support/"
MARKETING_URL = None  # left blank, per AppStore/listing.md

# A clean 4+ profile: every content descriptor "none", every capability
# false/off. See issue #5 and AgeRatingDeclaration.Attributes research.
# Deliberately omits the rare override fields (ageRatingOverrideV2,
# koreaAgeRatingOverride, developerAgeRatingInfoUrl) — a partial PATCH only
# touches the fields it's given, so leaving them out leaves them alone.
AGE_RATING_ATTRIBUTES = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "violenceRealistic": "NONE",
    "advertising": False,
    "healthOrWellnessTopics": False,
    "lootBox": False,
    "messagingAndChat": False,
    "parentalControls": False,
    "ageAssurance": False,
    "socialMedia": False,
    "socialMediaAgeRestricted": False,
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "kidsAgeBand": None,
}

DRY_RUN = "--apply" not in sys.argv
_token = None


def make_jwt():
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_PRIVATE_KEY_PATH"]
    with open(key_path) as f:
        private_key = f.read()
    now = int(time.time())
    # 19, not 20, minutes - Apple's hard cap is exactly 20; leave a little room.
    payload = {"iss": issuer_id, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})


def api(method, path, body=None):
    global _token
    if _token is None:
        _token = make_jwt()
    url = path if path.startswith("http") else f"{API_BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {_token}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit(f"{method} {url} -> {e.code}\n{detail}")


def write(method, path, body, label):
    print(f"{'[DRY RUN] ' if DRY_RUN else ''}{method} {path}")
    print(json.dumps(body, indent=2, ensure_ascii=False))
    if DRY_RUN:
        print(f"  (not sent - rerun with --apply to actually {label})\n")
        return None
    api(method, path, body)
    print("  done\n")


def find_app():
    result = api("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")
    apps = result.get("data", [])
    if not apps:
        raise SystemExit(f"No app found in App Store Connect for bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def find_app_info_id(app_id):
    result = api("GET", f"/apps/{app_id}/appInfos")
    infos = result.get("data", [])
    if not infos:
        raise SystemExit("App has no appInfos - unexpected")
    editable_states = {None, "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"}
    editable = [i for i in infos if i["attributes"].get("appStoreState") in editable_states]
    return (editable or infos)[0]["id"]


def find_editable_version(app_id):
    result = api("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=5")
    versions = result.get("data", [])
    editable_states = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
    for v in versions:
        if v["attributes"].get("appVersionState") in editable_states:
            return v["id"], v["attributes"].get("versionString")
    if versions:
        v = versions[0]
        print(f"  warning: no version in an editable state - using "
              f"{v['attributes'].get('versionString')} anyway, this may fail\n")
        return v["id"], v["attributes"].get("versionString")
    raise SystemExit("App has no appStoreVersions yet - create one in App Store Connect first")


def set_name_and_subtitle(app_info_id):
    result = api("GET", f"/appInfos/{app_info_id}/appInfoLocalizations")
    existing = next((l for l in result.get("data", []) if l["attributes"].get("locale") == LOCALE), None)
    attrs = {"name": NAME, "subtitle": SUBTITLE, "privacyPolicyUrl": PRIVACY_POLICY_URL}
    if existing:
        write("PATCH", f"/appInfoLocalizations/{existing['id']}",
              {"data": {"type": "appInfoLocalizations", "id": existing["id"], "attributes": attrs}},
              "update name/subtitle/privacy policy URL")
    else:
        write("POST", "/appInfoLocalizations",
              {"data": {"type": "appInfoLocalizations",
                        "attributes": {**attrs, "locale": LOCALE},
                        "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}}}},
              "create name/subtitle/privacy policy URL")


def set_version_metadata(version_id):
    result = api("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    existing = next((l for l in result.get("data", []) if l["attributes"].get("locale") == LOCALE), None)
    attrs = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMOTIONAL_TEXT,
        "supportUrl": SUPPORT_URL,
    }
    if MARKETING_URL:
        attrs["marketingUrl"] = MARKETING_URL
    if existing:
        write("PATCH", f"/appStoreVersionLocalizations/{existing['id']}",
              {"data": {"type": "appStoreVersionLocalizations", "id": existing["id"], "attributes": attrs}},
              "update version metadata")
    else:
        write("POST", "/appStoreVersionLocalizations",
              {"data": {"type": "appStoreVersionLocalizations",
                        "attributes": {**attrs, "locale": LOCALE},
                        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}},
              "create version metadata")


def set_age_rating(app_info_id):
    result = api("GET", f"/appInfos/{app_info_id}/ageRatingDeclaration")
    declaration_id = result["data"]["id"]
    write("PATCH", f"/ageRatingDeclarations/{declaration_id}",
          {"data": {"type": "ageRatingDeclarations", "id": declaration_id, "attributes": AGE_RATING_ATTRIBUTES}},
          "set age rating")


def main():
    missing = [v for v in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_PATH") if v not in os.environ]
    if missing:
        raise SystemExit(f"Missing environment variable(s): {', '.join(missing)} - see the script's docstring.")

    print('App Privacy ("no data collected") has NO API - Apple doesn\'t expose it.\n'
          "Answer that by hand in App Store Connect's web UI; this script only\n"
          "handles Age Rating and listing copy.\n")
    if DRY_RUN:
        print("=== DRY RUN - nothing will be written. Pass --apply to actually push these. ===\n")

    app_id = find_app()
    print(f"App: {BUNDLE_ID} -> id {app_id}\n")

    app_info_id = find_app_info_id(app_id)
    set_name_and_subtitle(app_info_id)
    set_age_rating(app_info_id)

    version_id, version_string = find_editable_version(app_id)
    print(f"Version: {version_string} -> id {version_id}\n")
    set_version_metadata(version_id)


if __name__ == "__main__":
    main()
