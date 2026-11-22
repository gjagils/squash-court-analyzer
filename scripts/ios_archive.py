#!/usr/bin/env python3
"""Archive the iOS app for TestFlight/App Store with the Firebase API key filled in, check the
result and (only with --upload) send it to App Store Connect.

    scripts/ios_archive.py              # archive + check, uploads nothing
    scripts/ios_archive.py --upload     # the same, then export with destination upload

Why this exists: SQUASH_FIREBASE_API_KEY is empty in the Xcode project (the key never goes in git).
An archive without it builds fine but nobody can log in. This script reads the key from
~/.android-keys/google-services.json, passes it on the xcodebuild line and refuses to continue
when the archived Info.plist does not contain it. The key is never printed.

Needs the App Store Connect API key (see the TestFlight upload notes): ~/.appstoreconnect/private_keys/
AuthKey_AN4XF9Y8MM.p8. Bump the build first (scripts/version.py upload) and commit.
"""
import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOOGLE_SERVICES = os.path.expanduser("~/.android-keys/google-services.json")
ASC_KEY_ID = "AN4XF9Y8MM"
ASC_ISSUER = "8131d42a-11cd-481c-aba6-8a9ca9b4b906"
ASC_KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{ASC_KEY_ID}.p8")
ARCHIVE = os.path.join(ROOT, "build", "ios", "SquashAnalyzer.xcarchive")


def firebase_key():
    try:
        with open(GOOGLE_SERVICES) as f:
            key = json.load(f)["client"][0]["api_key"][0]["current_key"]
    except (OSError, KeyError, IndexError, ValueError) as e:
        sys.exit(f"Firebase-sleutel niet te lezen uit {GOOGLE_SERVICES}: {type(e).__name__}")
    if not key:
        sys.exit("Firebase-sleutel in google-services.json is leeg")
    return key


def auth_flags():
    if not os.path.exists(ASC_KEY_PATH):
        sys.exit(f"App Store Connect-sleutel ontbreekt: {ASC_KEY_PATH}")
    return ["-allowProvisioningUpdates", "-authenticationKeyPath", ASC_KEY_PATH,
            "-authenticationKeyID", ASC_KEY_ID, "-authenticationKeyIssuerID", ASC_ISSUER]


def run(cmd):
    print("+", " ".join(a if "API_KEY=" not in a else "SQUASH_FIREBASE_API_KEY=***" for a in cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def check_archive(key):
    """Fail unless the archived app carries the key, the player-account switch and a version."""
    apps = os.path.join(ARCHIVE, "Products", "Applications")
    app = next((os.path.join(apps, n) for n in os.listdir(apps) if n.endswith(".app")), None)
    if not app:
        sys.exit("Geen .app in het archief")
    with open(os.path.join(app, "Info.plist"), "rb") as f:
        plist = plistlib.load(f)
    problems = []
    if plist.get("SquashFirebaseAPIKey") != key:
        problems.append("SquashFirebaseAPIKey in het archief is leeg of wijkt af")
    if plist.get("SquashAccountServer") not in ("", None) and "squashanalyzer.com" not in str(plist.get("SquashAccountServer")):
        problems.append(f"SquashAccountServer wijst niet naar de echte server: {plist.get('SquashAccountServer')!r}")
    if problems:
        sys.exit("ARCHIEF AFGEKEURD, niet uploaden:\n- " + "\n- ".join(problems))
    print(f"Archief gecontroleerd: {plist.get('CFBundleShortVersionString')} ({plist.get('CFBundleVersion')}), "
          "Firebase-sleutel aanwezig.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--upload", action="store_true", help="na de controle exporteren en uploaden naar App Store Connect")
    args = ap.parse_args()

    key = firebase_key()
    shutil.rmtree(os.path.dirname(ARCHIVE), ignore_errors=True)
    run(["xcodebuild", "archive", "-project", "SquashAnalyzer.xcodeproj", "-scheme", "SquashAnalyzer",
         "-configuration", "Release", "-destination", "generic/platform=iOS", "-archivePath", ARCHIVE,
         "-skipPackagePluginValidation", *auth_flags(), f"SQUASH_FIREBASE_API_KEY={key}"])
    check_archive(key)

    if not args.upload:
        print(f"Niets geüpload. Archief: {ARCHIVE}\nUploaden: scripts/ios_archive.py --upload "
              "(of exporteer dit archief zelf).")
        return
    with tempfile.TemporaryDirectory() as tmp:
        opts = os.path.join(tmp, "ExportOptions.plist")
        with open(opts, "wb") as f:
            plistlib.dump({"method": "app-store-connect", "destination": "upload", "signingStyle": "automatic",
                           "manageAppVersionAndBuildNumber": False, "teamID": "65FAHRU88M"}, f)
        run(["xcodebuild", "-exportArchive", "-archivePath", ARCHIVE, "-exportOptionsPlist", opts,
             "-exportPath", os.path.join(tmp, "export"), *auth_flags()])
    print("Geüpload. Volgende stap: scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md")


if __name__ == "__main__":
    main()
