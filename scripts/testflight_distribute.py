#!/usr/bin/env python3
"""Wait for a build to finish processing, set its TestFlight notes, add it to beta groups
and submit for beta review. Older builds are expired (testflight_expire_old.py).

    scripts/testflight_distribute.py --version 2.2 --build 10 --notes release-notes/2.2-10.md \
        [--groups Squashteam] [--no-review] [--timeout-minutes 45]

The notes file is plain text (max 4000 characters) and becomes the "What to Test"
text testers see in TestFlight (locale nl-NL).
"""
import argparse
import os
import re
import sys
import time
import urllib.error

sys.path.insert(0, os.path.dirname(__file__))
import asc_api as asc  # noqa: E402
import version as versions  # noqa: E402
from testflight_expire_old import expire_old  # noqa: E402

APP_ID = "6758676921"


def find_build(marketing_version, build_number):
    """Newest build with this build number inside the given marketing version (build numbers repeat across versions)."""
    builds = asc.get("/v1/builds", {"filter[app]": APP_ID, "filter[preReleaseVersion.version]": marketing_version,
                                    "filter[version]": build_number, "sort": "-uploadedDate", "limit": 5,
                                    "fields[builds]": "version,processingState,expired,uploadedDate"})["data"]
    builds = [b for b in builds if not b["attributes"]["expired"]]
    return max(builds, key=lambda b: b["attributes"]["uploadedDate"]) if builds else None


# TestFlight rejects emoji and pictographs in What to Test ("invalid characters")
_EMOJI = re.compile("[\U00010000-\U0010FFFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F]")


def set_test_notes(build_id, text, locale="nl-NL"):
    """Fill the build's What to Test text (created by App Store Connect, usually empty)."""
    text = _EMOJI.sub("", text).replace("  ", " ")
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
    ap.add_argument("--version", help="marketing version, e.g. 3.1 (default: from the project, scripts/version.py)")
    ap.add_argument("--build", help="build number, e.g. 4 (default: from the project)")
    ap.add_argument("--notes", help="text file with the What to Test notes for testers")
    ap.add_argument("--groups", nargs="*", default=["Squashteam"])
    ap.add_argument("--no-review", action="store_true")
    ap.add_argument("--keep-old", action="store_true", help="do not expire older builds")
    ap.add_argument("--timeout-minutes", type=int, default=45)
    args = ap.parse_args()
    if not (args.version and args.build):
        project_version, project_build = versions.read_ios()
        args.version = args.version or project_version
        args.build = args.build or str(project_build)
    if args.build in ("0",) or "." in args.build:
        sys.exit(f"Build {args.build} is geen upload: gebruik scripts/version.py upload (build + 1), internal bouwen telt niet mee")

    deadline = time.time() + args.timeout_minutes * 60
    while True:
        try:
            build = find_build(args.version, args.build)
        except Exception as error:  # a network hiccup must not end the wait
            print(time.strftime("%H:%M:%S"), f"kon de build niet opvragen ({error}); ik blijf proberen", flush=True)
            if time.time() > deadline:
                sys.exit("Timed out waiting for processing")
            time.sleep(60)
            continue
        state = build["attributes"]["processingState"] if build else "NOT_VISIBLE_YET"
        print(time.strftime("%H:%M:%S"), f"{args.version} ({args.build})", state, flush=True)
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID"):
            sys.exit(f"Build {args.build} processing ended in {state}")
        if time.time() > deadline:
            sys.exit("Timed out waiting for processing")
        time.sleep(120)

    # The build is in App Store Connect now. What follows (notes, group, review,
    # expiring old builds) can be repeated: when it breaks halfway, run the same
    # command again and what is done is not done twice.
    restart = "scripts/testflight_distribute.py" + (f" --notes {args.notes}" if args.notes else "")
    try:
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
        # Older builds go; the previous approved one stays until this one passes review
        if not args.keep_old:
            expire_old()
    except urllib.error.HTTPError as error:
        if error.code == 409 and "betaAppReviewSubmissions" in str(error.url):
            print("  beta review was already submitted")
        else:
            sys.exit(f"Gestopt na het uploaden ({error}). De build staat in TestFlight; draai opnieuw: {restart}")
    except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
        sys.exit(f"Gestopt na het uploaden ({error}). De build staat in TestFlight; draai opnieuw: {restart}")
    print("Done.")


if __name__ == "__main__":
    main()
