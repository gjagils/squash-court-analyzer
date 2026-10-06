#!/usr/bin/env python3
"""Upload the Android app to Google Play's internal test track (the Android
counterpart of testflight_distribute.py). No third-party packages: the
service-account JWT (RS256) is signed with openssl.

The service-account key never leaves ~/.android-keys (PLAY_KEY_PATH overrides;
by default play-api.json there, else the only *.json in that folder). It is only
sent to Google's token endpoint; uploads use the short-lived access token.

    scripts/play_upload.py --check                      # can we reach the app?
    scripts/version.py upload                           # version and build for the next upload (see there)
    scripts/play_upload.py --aab PATH --notes FILE      # upload, release to all test tracks

The release goes to internal testing and both closed tests: "alpha" (the
mailing lists AllInnSquash, Bombardino, overig) and "Google Group testers"
(members of squashanalyzer@googlegroups.com). Play Console allows either
mailing lists or Google Groups per closed test, hence two (--tracks overrides).

See docs/google-play.md ("Uploaden met het script").
"""
import argparse
import base64
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PACKAGE = "com.squashanalyzer.android"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + PACKAGE
UPLOAD_API = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/" + PACKAGE
TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import version as versions  # noqa: E402  (scripts/version.py: the numbers of both apps)


def key_path() -> str:
    if os.environ.get("PLAY_KEY_PATH"):
        return os.path.expanduser(os.environ["PLAY_KEY_PATH"])
    folder = os.path.expanduser("~/.android-keys")
    preferred = os.path.join(folder, "play-api.json")
    if os.path.exists(preferred):
        return preferred
    found = glob.glob(os.path.join(folder, "*.json"))
    if len(found) != 1:
        sys.exit(f"Geen of meerdere sleutelbestanden in {folder}; zet PLAY_KEY_PATH.")
    return found[0]


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token() -> str:
    with open(key_path()) as handle:
        key = json.load(handle)
    now = int(time.time())
    header = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = _b64url(json.dumps({
        "iss": key["client_email"], "scope": SCOPE, "aud": TOKEN_URL,
        "iat": now, "exp": now + 3600,
    }).encode())
    signing_input = f"{header}.{claims}".encode()
    # The private key goes to a private temp file for openssl, removed right after
    fd, pem = tempfile.mkstemp(suffix=".pem")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as out:
            out.write(key["private_key"])
        signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", pem],
                                   input=signing_input, capture_output=True, check=True).stdout
    finally:
        os.remove(pem)
    assertion = f"{header}.{claims}.{_b64url(signature)}"
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion,
    }).encode()
    request = urllib.request.Request(TOKEN_URL, data=body, method="POST",
                                     headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(request) as response:
        return json.load(response)["access_token"]


def call(token: str, method: str, url: str, body=None, data: bytes = None, content_type: str = "application/json"):
    payload = data if data is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(url, data=payload, method=method,
                                     headers={"Authorization": f"Bearer {token}", "Content-Type": content_type})
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            text = response.read()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {url} -> {error.code}: {error.read().decode()[:800]}")


def check(token: str) -> None:
    edit = call(token, "POST", f"{API}/edits", body={})
    tracks = call(token, "GET", f"{API}/edits/{edit['id']}/tracks")
    call(token, "DELETE", f"{API}/edits/{edit['id']}")
    for track in tracks.get("tracks", []):
        releases = [f"{r.get('name', '?')} ({r.get('status')}, codes {r.get('versionCodes')})" for r in track.get("releases", [])]
        print(f"{track['track']}: {', '.join(releases) or '-'}")
    print("Toegang tot", PACKAGE, "werkt.")


TRACKS = ["internal", "alpha", "Google Group testers"]


def upload(token: str, aab: str, notes: str, name: str, tracks: list) -> None:
    edit = call(token, "POST", f"{API}/edits", body={})
    edit_id = edit["id"]
    with open(aab, "rb") as handle:
        bundle = call(token, "POST", f"{UPLOAD_API}/edits/{edit_id}/bundles?uploadType=media",
                      data=handle.read(), content_type="application/octet-stream")
    code = bundle["versionCode"]
    print("Geüpload, versionCode", code)
    for track in tracks:
        call(token, "PUT", f"{API}/edits/{edit_id}/tracks/{urllib.parse.quote(track)}", body={
            "track": track,
            "releases": [{
                "name": name or str(code),
                "versionCodes": [str(code)],
                "status": "completed",
                "releaseNotes": [{"language": "nl-NL", "text": notes[:500]}],
            }],
        })
    call(token, "POST", f"{API}/edits/{edit_id}:commit")
    print("Uitgerold naar:", ", ".join(tracks))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--aab", default=os.path.join(os.path.dirname(__file__), "..", "Android", "app",
                                                      "build", "outputs", "bundle", "release", "app-release.aab"))
    parser.add_argument("--notes", help="file with the Dutch release notes (max 500 characters)")
    parser.add_argument("--name", help="release name (default: versionName from build.gradle.kts, e.g. 3.1 (4))")
    parser.add_argument("--tracks", default=",".join(TRACKS), help="comma-separated tracks (default: all test tracks)")
    args = parser.parse_args()
    token = access_token()
    if args.check:
        check(token)
        return
    if not args.notes:
        sys.exit("--notes is nodig")
    with open(args.notes) as handle:
        notes = handle.read().strip()
    version, build = versions.read_ios()
    name = args.name or versions.android_name(version, build)
    print("Release:", name, "(versionCode", versions.android_code(version, build), "in de app)")
    upload(token, args.aab, notes, name, [t.strip() for t in args.tracks.split(",") if t.strip()])


if __name__ == "__main__":
    import urllib.parse  # noqa: E402  (after argparse so --help works without it)
    main()
