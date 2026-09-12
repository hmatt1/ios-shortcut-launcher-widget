#!/usr/bin/env python3
"""One-time setup for fixed CI code signing: creates one Apple Distribution
certificate and two App Store provisioning profiles (app + widget), and
writes everything CI needs into .signing/ (gitignored - never committed).

Why this exists: CODE_SIGN_STYLE: Automatic mints a brand-new development
certificate on every fresh CI runner that can't find one cached, since each
runner's keychain is empty and the private key never leaves the runner it
was generated on. These pile up until Apple's account-wide certificate cap
is hit ("Choose a certificate to revoke"). A fixed, manually-managed
Distribution certificate never needs to be regenerated, so this never
recurs.

Run this LOCALLY, not in CI. The private key this creates must never touch
a public GitHub Actions log or artifact — both are visible on this public
repo. Local generation, then you paste the results into GitHub's secret UI
yourself, is the only step in this whole pipeline that has to happen
outside CI.

Requires:
    pip install pyjwt cryptography
    openssl on PATH (ships with Git for Windows / any Mac / any Linux)

Credentials — same three as Tools/app-store-connect.py, same API key
already in GitHub secrets for TestFlight uploads:
    ASC_KEY_ID            Key ID (matches the ADMIN_APPSTORE_KEY_ID secret)
    ASC_ISSUER_ID         Issuer ID (matches the APPSTORE_ISSUER_ID secret)
    ASC_PRIVATE_KEY_PATH  path to the downloaded AuthKey_<KEY_ID>.p8 file

Usage:
    python3 Tools/setup-signing.py

This creates real resources on your Apple Developer account (one
certificate, two profiles) — it is not a dry run, there's nothing
meaningful to preview beforehand. It checks first whether a Distribution
certificate already exists and warns (not blocks) rather than silently
creating a duplicate, since piling up duplicate signing resources is
exactly the problem this script exists to stop.

After it finishes, follow the printed instructions: four values go into
GitHub secrets, then `git rm -rf --cached .signing` is unnecessary (it was
never committed - .gitignore already excludes it) but do delete the local
.signing/ directory once the secrets are safely stored.
"""
import json
import os
import subprocess
import time
import urllib.error
import urllib.request

import jwt  # pip install pyjwt cryptography

API_BASE = "https://api.appstoreconnect.apple.com/v1"
APP_BUNDLE_ID = "com.hmatt1.shortcutlauncherwidget"
WIDGET_BUNDLE_ID = "com.hmatt1.shortcutlauncherwidget.Widget"

# These exact strings are also what project.yml's PROVISIONING_PROFILE_SPECIFIER
# needs to reference - keep both in sync if you rename either.
APP_PROFILE_NAME = "Shortcut Launcher Widget App Store"
WIDGET_PROFILE_NAME = "Shortcut Launcher Widget Extension App Store"

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".signing")


# make_jwt()/api() duplicate Tools/app-store-connect.py's (and, inline,
# .github/workflows/list-certificates.yml's) JWT auth logic rather than
# sharing it - each is a standalone one-off script/step run in a different
# context (local, local, CI-YAML-heredoc), and this repo doesn't have a
# proper installable Python package for them to import from. If Apple ever
# changes the JWT shape or the 20-minute expiry, all three need the same
# fix by hand.
def make_jwt():
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_PRIVATE_KEY_PATH"]
    with open(key_path) as f:
        private_key = f.read()
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})


_token = None


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


def run(*cmd, input_bytes=None):
    # MSYS_NO_PATHCONV: Git Bash on Windows rewrites any argument starting
    # with "/" (like openssl's "/CN=..." subject string) into a Windows
    # path before openssl ever sees it. Harmless to set on macOS/Linux,
    # where this env var means nothing.
    env = {**os.environ, "MSYS_NO_PATHCONV": "1"}
    result = subprocess.run(cmd, input=input_bytes, capture_output=True, env=env)
    if result.returncode != 0:
        raise SystemExit(
            f"Command failed: {' '.join(cmd)}\n{result.stderr.decode(errors='replace')}"
        )
    return result.stdout


def check_prerequisites():
    missing = [v for v in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_PATH") if v not in os.environ]
    if missing:
        raise SystemExit(f"Missing environment variable(s): {', '.join(missing)} - see the script's docstring.")
    try:
        subprocess.run(["openssl", "version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        raise SystemExit("openssl not found on PATH - it ships with Git for Windows, or any Mac/Linux install.")


def warn_if_distribution_certificate_exists():
    result = api("GET", "/certificates?filter[certificateType]=DISTRIBUTION&limit=50")
    existing = result.get("data", [])
    if existing:
        print(f"NOTE: {len(existing)} existing DISTRIBUTION certificate(s) already on this account:")
        for c in existing:
            a = c["attributes"]
            print(f"  id={c['id']}  name={a.get('name')!r}  expires={a.get('expirationDate')}")
        print("Proceeding to create one more anyway, since you're running this deliberately.\n"
              "If you meant to reuse one of the above instead of creating a new one, Ctrl-C now.\n")


def find_bundle_id(identifier):
    result = api("GET", f"/bundleIds?filter[identifier]={identifier}")
    matches = result.get("data", [])
    if not matches:
        raise SystemExit(f"No Bundle ID registered for {identifier} - register it in the Developer Portal first.")
    return matches[0]["id"]


def create_certificate(csr_pem):
    print("Creating Apple Distribution certificate...")
    result = api("POST", "/certificates", {
        "data": {
            "type": "certificates",
            "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_pem},
        }
    })
    cert = result["data"]
    print(f"  created id={cert['id']}  name={cert['attributes'].get('name')!r}\n")
    return cert["id"], cert["attributes"]["certificateContent"]


def create_profile(name, bundle_id, certificate_id):
    print(f"Creating profile {name!r}...")
    result = api("POST", "/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    })
    profile = result["data"]
    print(f"  created id={profile['id']}  uuid={profile['attributes'].get('uuid')}\n")
    return profile["attributes"]["profileContent"]  # already base64 - passed straight through to a GitHub secret


def main():
    check_prerequisites()
    os.makedirs(OUT_DIR, exist_ok=True)

    warn_if_distribution_certificate_exists()

    key_path = os.path.join(OUT_DIR, "distribution.key")
    csr_path = os.path.join(OUT_DIR, "distribution.csr")
    cer_path = os.path.join(OUT_DIR, "distribution.cer")
    pem_path = os.path.join(OUT_DIR, "distribution.pem")
    p12_path = os.path.join(OUT_DIR, "distribution.p12")

    print("Generating a 2048-bit RSA key and CSR locally (never sent anywhere but Apple)...")
    run("openssl", "genrsa", "-out", key_path, "2048")
    run("openssl", "req", "-new", "-key", key_path, "-out", csr_path,
        "-subj", "/CN=Shortcut Launcher Widget CI Distribution")
    with open(csr_path) as f:
        csr_pem = f.read()
    print("  done\n")

    cert_id, cert_content_b64 = create_certificate(csr_pem)
    with open(cer_path, "wb") as f:
        import base64
        f.write(base64.b64decode(cert_content_b64))
    run("openssl", "x509", "-inform", "DER", "-in", cer_path, "-out", pem_path)

    import secrets
    p12_password = secrets.token_urlsafe(24)
    run("openssl", "pkcs12", "-export",
        "-inkey", key_path, "-in", pem_path,
        "-out", p12_path, "-passout", f"pass:{p12_password}")

    with open(p12_path, "rb") as f:
        import base64
        p12_b64 = base64.b64encode(f.read()).decode()
    p12_b64_path = os.path.join(OUT_DIR, "distribution.p12.b64")
    with open(p12_b64_path, "w") as f:
        f.write(p12_b64)
    password_path = os.path.join(OUT_DIR, "distribution.p12.password.txt")
    with open(password_path, "w") as f:
        f.write(p12_password)
    print(f"Wrote {p12_path}, its base64 form, and its password to {OUT_DIR}\n")

    app_bundle_id = find_bundle_id(APP_BUNDLE_ID)
    widget_bundle_id = find_bundle_id(WIDGET_BUNDLE_ID)

    app_profile_b64 = create_profile(APP_PROFILE_NAME, app_bundle_id, cert_id)
    widget_profile_b64 = create_profile(WIDGET_PROFILE_NAME, widget_bundle_id, cert_id)

    app_profile_path = os.path.join(OUT_DIR, "app.mobileprovision.b64")
    widget_profile_path = os.path.join(OUT_DIR, "widget.mobileprovision.b64")
    with open(app_profile_path, "w") as f:
        f.write(app_profile_b64)
    with open(widget_profile_path, "w") as f:
        f.write(widget_profile_b64)

    print("=" * 72)
    print("Done. Four GitHub secrets need these values - none of them should")
    print("ever be pasted anywhere but the GitHub secret UI (or `gh secret set`).")
    print("=" * 72)
    print(f"""
  IOS_DIST_CERT_P12_BASE64   <- contents of {p12_b64_path}
  IOS_DIST_CERT_PASSWORD     <- {p12_password}
  IOS_PROFILE_APP_BASE64     <- contents of {app_profile_path}
  IOS_PROFILE_WIDGET_BASE64  <- contents of {widget_profile_path}

If you have the gh CLI locally, this sets all four in one go:

  gh secret set IOS_DIST_CERT_P12_BASE64 < "{p12_b64_path}"
  gh secret set IOS_DIST_CERT_PASSWORD --body "{p12_password}"
  gh secret set IOS_PROFILE_APP_BASE64 < "{app_profile_path}"
  gh secret set IOS_PROFILE_WIDGET_BASE64 < "{widget_profile_path}"

Once those four secrets are set in GitHub, delete the local .signing/
directory - everything in it is now redundant with what's in GitHub, and
it holds a private key.
""")


if __name__ == "__main__":
    main()
