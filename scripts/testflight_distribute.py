#!/usr/bin/env python3
"""Wait for a build to finish processing, set its TestFlight notes, add it to beta groups
and submit for beta review.

    scripts/testflight_distribute.py --version 2.2 --build 10 --notes release-notes/2.2-10.md \
        [--groups Squashteam] [--no-review] [--timeout-minutes 45]

The notes file is plain text (max 4000 characters) and becomes the "What to Test"
text testers see in TestFlight (locale nl-NL).
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import asc_api as asc  # noqa: E402

APP_ID = "6758676921"


def find_build(marketing_version, build_number):
    """Newest build with this build number inside the given marketing version (build numbers repeat across versions)."""
    builds = asc.get("/v1/builds", {"filter[app]": APP_ID, "filter[preReleaseVersion.version]": marketing_version,
                                    "filter[version]": build_number, "sort": "-uploadedDate", "limit": 5,
                                    "fields[builds]": "version,processingState,expired,uploadedDate"})["data"]
    builds = [b for b in builds if not b["attributes"]["expired"]]
    return max(builds, key=lambda b: b["attributes"]["uploadedDate"]) if builds else None


def set_test_notes(build_id, text, locale="nl-NL"):
    """Fill the build's What to Test text (created by App Store Connect, usually empty)."""
    if len(text) > 4000:
        sys.exit(f"Notes are {len(text)} characters; TestFlight allows 4000")
    existing = asc.get(f"/v1/builds/{build_id}/betaBuildLocalizations",
                       {"fields[betaBuildLocalizations]": "locale,whatsNew"})["data"]
    match = next((l for l in existing if l["attributes"]["locale"] == locale), None)
    if match:
        asc.patch(f"/v1/betaBuildLocalizations/{match['id']}", {"data": {
            "type": "betaBuildLocalizations", "id": match["id"], "attributes": {"whatsNew": text}}})
    else:
        asc.post("/v1/betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": locale, "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
    print(f"  test notes set ({len(text)} chars, {locale})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="marketing version, e.g. 2.2")
    ap.add_argument("--build", required=True, help="build number, e.g. 6")
    ap.add_argument("--notes", help="text file with the What to Test notes for testers")
    ap.add_argument("--groups", nargs="*", default=["Squashteam"])
    ap.add_argument("--no-review", action="store_true")
    ap.add_argument("--timeout-minutes", type=int, default=45)
    args = ap.parse_args()

    deadline = time.time() + args.timeout_minutes * 60
    while True:
        build = find_build(args.version, args.build)
        state = build["attributes"]["processingState"] if build else "NOT_VISIBLE_YET"
        print(time.strftime("%H:%M:%S"), f"{args.version} ({args.build})", state, flush=True)
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID"):
            sys.exit(f"Build {args.build} processing ended in {state}")
        if time.time() > deadline:
            sys.exit("Timed out waiting for processing")
        time.sleep(120)

    build_id = build["id"]

    if args.notes:
        set_test_notes(build_id, open(args.notes, encoding="utf-8").read().strip())

    # Internal groups receive every build automatically and refuse explicit assignment.
    groups = asc.get(f"/v1/apps/{APP_ID}/betaGroups", {"fields[betaGroups]": "name,isInternalGroup"})["data"]
    wanted = [g for g in groups if g["attributes"]["name"] in args.groups and not g["attributes"]["isInternalGroup"]]
    if not wanted:
        sys.exit(f"No external beta groups named {args.groups}")
    asc.post(f"/v1/builds/{build_id}/relationships/betaGroups",
             {"data": [{"type": "betaGroups", "id": g["id"]} for g in wanted]})
    for g in wanted:
        print("  added to external group", g["attributes"]["name"])

    if not args.no_review:
        sub = asc.post("/v1/betaAppReviewSubmissions", {"data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
        }})
        print("  beta review:", sub["data"]["attributes"]["betaReviewState"])
    print("Done.")


if __name__ == "__main__":
    main()
