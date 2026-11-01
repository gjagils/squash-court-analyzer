#!/usr/bin/env python3
"""Prepare an App Store version in App Store Connect from the repo, without
submitting it: create the version when it does not exist, set the texts of
every locale from release-notes/store-<version>/ and, with --build N, attach
that processed build. Screenshots: scripts/upload_screenshots.py.

    scripts/asc_version.py --version 3.1                # create + texts (nl-NL, en-GB)
    scripts/asc_version.py --version 3.1 --build 7      # also attach build 3.1 (7)
    scripts/asc_version.py --version 3.1 --dry-run

Texts per locale in release-notes/store-<version>/: description-<locale>.md,
whatsnew-<locale>.md, promo-<locale>.txt (optional); keywords and the URLs are
copied from the newest version that has them. Nothing here submits for review.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import asc_api as asc  # noqa: E402

BUNDLE_ID = "com.squashanalyzer.app"
LOCALES = ("nl-NL", "en-GB")
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "WAITING_FOR_REVIEW", "INVALID_BINARY"}


def read(path, required=True):
    if not os.path.exists(path):
        if required:
            sys.exit(f"missing {path}")
        return None
    with open(path) as handle:
        return handle.read().strip()


def app_id():
    apps = asc.get("/v1/apps", {"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"No app with bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def versions(app):
    return asc.get(f"/v1/apps/{app}/appStoreVersions", {"filter[platform]": "IOS", "limit": 20})["data"]


def localizations(version_id):
    return {l["attributes"]["locale"]: l for l in asc.get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--build", help="build number to attach, e.g. 7 (must be processed)")
    ap.add_argument("--submit", action="store_true", help="submit the version for App Review (release after approval)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    folder = os.path.join(os.path.dirname(__file__), "..", "release-notes", f"store-{args.version}")

    app = app_id()
    existing = versions(app)
    target = next((v for v in existing if v["attributes"]["versionString"] == args.version), None)
    # Keywords and URLs come from the newest version that has them (the live one)
    source = next((v for v in existing if v["attributes"]["versionString"] != args.version), None)
    source_locs = localizations(source["id"]) if source else {}

    texts = {}
    for locale in LOCALES:
        src = source_locs.get(locale, {}).get("attributes", {})
        attrs = {
            "description": read(os.path.join(folder, f"description-{locale}.md")),
            "whatsNew": read(os.path.join(folder, f"whatsnew-{locale}.md")),
            "keywords": src.get("keywords"),
            "supportUrl": src.get("supportUrl") or "https://squashanalyzer.com",
            "marketingUrl": src.get("marketingUrl") or "https://squashanalyzer.com",
        }
        promo = read(os.path.join(folder, f"promo-{locale}.txt"), required=False)
        if promo:
            attrs["promotionalText"] = promo
        if len(attrs["description"]) > 4000 or len(attrs["whatsNew"]) > 4000 or len(attrs.get("promotionalText") or "") > 170:
            sys.exit(f"{locale}: text too long (description/whatsNew 4000, promo 170)")
        texts[locale] = {k: v for k, v in attrs.items() if v is not None}

    print(f"Version {args.version}: {'exists (' + target['attributes']['appStoreState'] + ')' if target else 'will be created'}")
    for locale, attrs in texts.items():
        print(f"  {locale}: " + ", ".join(f"{k} {len(v)}" for k, v in attrs.items()))
    if args.dry_run:
        return

    if target is None:
        target = asc.post("/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": args.version},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}},
        }})["data"]
        print(f"  created version {args.version} ({target['attributes']['appStoreState']})")
    elif target["attributes"]["appStoreState"] not in EDITABLE:
        sys.exit(f"Version {args.version} is {target['attributes']['appStoreState']}; not editable")
    version_id = target["id"]

    locs = localizations(version_id)
    for locale, attrs in texts.items():
        if locale in locs:
            asc.patch(f"/v1/appStoreVersionLocalizations/{locs[locale]['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": locs[locale]["id"], "attributes": attrs}})
            print(f"  {locale}: texts updated")
        else:
            asc.post("/v1/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": locale, **attrs},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }})
            print(f"  {locale}: localization created with texts")

    if args.build:
        builds = asc.get("/v1/builds", {"filter[app]": app, "filter[preReleaseVersion.version]": args.version,
                                        "filter[version]": args.build, "limit": 5})["data"]
        build = next((b for b in builds if b["attributes"]["processingState"] == "VALID"), None)
        if build is None:
            states = [b["attributes"]["processingState"] for b in builds]
            sys.exit(f"Build {args.version} ({args.build}) is not processed yet ({states or 'not found'}); run again later")
        asc.patch(f"/v1/appStoreVersions/{version_id}/relationships/build",
                  {"data": {"type": "builds", "id": build["id"]}})
        print(f"  build {args.version} ({args.build}) attached")
    if args.submit:
        submit(app, version_id)
        print("Done. Submitted for review.")
    else:
        print("Done. Nothing was submitted for review.")


def submit(app, version_id):
    """One review submission with this version as its item, then submitted;
    the version releases after approval (AFTER_APPROVAL, as 3.0)"""
    asc.patch(f"/v1/appStoreVersions/{version_id}", {"data": {
        "type": "appStoreVersions", "id": version_id, "attributes": {"releaseType": "AFTER_APPROVAL"}}})
    open_ones = asc.get("/v1/reviewSubmissions", {"filter[app]": app, "filter[platform]": "IOS",
                                                  "filter[state]": "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES"})["data"]
    if open_ones:
        sys.exit(f"There is already an open review submission ({open_ones[0]['attributes']['state']}); finish or cancel it in App Store Connect")
    submission = asc.post("/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app}}},
    }})["data"]
    asc.post("/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
        },
    }})
    done = asc.patch(f"/v1/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})["data"]
    print(f"  review submission {submission['id']}: {done['attributes']['state']}")


if __name__ == "__main__":
    main()
