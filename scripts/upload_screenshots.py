#!/usr/bin/env python3
"""Upload the captured App Store screenshots to App Store Connect.

    scripts/upload_screenshots.py [--version 2.2] [--dir screenshots/nl-NL] [--locale nl-NL]
                                  [--create-version] [--keep-other-sets] [--dry-run] [--yes]

Replaces every screenshot in the iPhone 6.9" set of the given App Store version.
The version must be editable (e.g. PREPARE_FOR_SUBMISSION); a version that is live
cannot be changed. --create-version creates the version when it does not exist yet.
Older iPhone sets (6.5", 6.1", 5.5") are removed so the 6.9" shots are scaled for
every device, unless --keep-other-sets is given.
"""
import argparse
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import asc_api as asc  # noqa: E402

BUNDLE_ID = "com.squashanalyzer.app"
DISPLAY_TYPE = "APP_IPHONE_69"
OTHER_IPHONE_TYPES = {"APP_IPHONE_65", "APP_IPHONE_61", "APP_IPHONE_58", "APP_IPHONE_55", "APP_IPHONE_47", "APP_IPHONE_40", "APP_IPHONE_35"}
EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW", "INVALID_BINARY"}


def marketing_version() -> str:
    pbxproj = os.path.join(os.path.dirname(__file__), "..", "SquashAnalyzer.xcodeproj", "project.pbxproj")
    with open(pbxproj) as f:
        match = re.search(r"MARKETING_VERSION = ([\d.]+);", f.read())
    return match.group(1)


def find_app():
    apps = asc.get("/v1/apps", {"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"No app with bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def find_version(app_id, version_string, create):
    versions = asc.get(f"/v1/apps/{app_id}/appStoreVersions", {"filter[versionString]": version_string, "filter[platform]": "IOS"})["data"]
    if versions:
        v = versions[0]
        state = v["attributes"]["appStoreState"]
        if state not in EDITABLE_STATES:
            sys.exit(f"Version {version_string} is {state}; screenshots can only be changed on an editable version.")
        return v["id"], state
    if not create:
        sys.exit(f"Version {version_string} does not exist in App Store Connect. Re-run with --create-version to create it.")
    created = asc.post("/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version_string},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})
    return created["data"]["id"], created["data"]["attributes"]["appStoreState"]


def find_localization(version_id, locale):
    locs = asc.get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    for loc in locs:
        if loc["attributes"]["locale"] == locale:
            return loc["id"]
    created = asc.post("/v1/appStoreVersionLocalizations", {"data": {
        "type": "appStoreVersionLocalizations",
        "attributes": {"locale": locale},
        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
    }})
    return created["data"]["id"]


def screenshot_sets(localization_id):
    return {s["attributes"]["screenshotDisplayType"]: s["id"]
            for s in asc.get(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]}


def upload_file(set_id, path):
    size = os.path.getsize(path)
    name = os.path.basename(path)
    reservation = asc.post("/v1/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": name, "fileSize": size},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    with open(path, "rb") as f:
        data = f.read()
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        asc.request(op["method"], op["url"], body=chunk, headers=headers, raw=True)
    asc.patch(f"/v1/appScreenshots/{reservation['id']}", {"data": {
        "type": "appScreenshots",
        "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
    }})
    return reservation["id"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", default=marketing_version())
    ap.add_argument("--dir", default=os.path.join(os.path.dirname(__file__), "..", "screenshots", "nl-NL"))
    ap.add_argument("--locale", default="nl-NL")
    ap.add_argument("--create-version", action="store_true")
    ap.add_argument("--keep-other-sets", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true", help="skip the confirmation prompt")
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(args.dir) if f.lower().endswith(".png"))
    if not files:
        sys.exit(f"No PNG files in {args.dir}")

    app_id = find_app()
    if args.dry_run:
        versions = asc.get(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS", "limit": 5})["data"]
        print("Versions:", ", ".join(f"{v['attributes']['versionString']} ({v['attributes']['appStoreState']})" for v in versions))
        print(f"Would upload {len(files)} files to {args.version} / {args.locale} / {DISPLAY_TYPE}:")
        for f in files:
            print("  ", f)
        return

    version_id, state = find_version(app_id, args.version, args.create_version)
    localization_id = find_localization(version_id, args.locale)
    sets = screenshot_sets(localization_id)
    existing_69 = list(asc.paged(f"/v1/appScreenshotSets/{sets[DISPLAY_TYPE]}/appScreenshots")) if DISPLAY_TYPE in sets else []
    other = {t: i for t, i in sets.items() if t in OTHER_IPHONE_TYPES}

    print(f"Version {args.version} ({state}), locale {args.locale}")
    print(f"  replace {len(existing_69)} existing {DISPLAY_TYPE} screenshots with {len(files)} new ones")
    if other and not args.keep_other_sets:
        print(f"  remove outdated sets: {', '.join(sorted(other))}")
    if not args.yes and input("Continue? [y/N] ").strip().lower() != "y":
        sys.exit("Aborted")

    if DISPLAY_TYPE not in sets:
        sets[DISPLAY_TYPE] = asc.post("/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": localization_id}}},
        }})["data"]["id"]
    for shot in existing_69:
        asc.delete(f"/v1/appScreenshots/{shot['id']}")
    for f in files:
        upload_file(sets[DISPLAY_TYPE], os.path.join(args.dir, f))
        print("  ↑", f)
    if not args.keep_other_sets:
        for display_type, set_id in other.items():
            asc.delete(f"/v1/appScreenshotSets/{set_id}")
            print("  ✕ removed", display_type)
    print("Done. Check the order in App Store Connect → App Store → iPhone screenshots.")


if __name__ == "__main__":
    main()
