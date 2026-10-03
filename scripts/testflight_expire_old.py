#!/usr/bin/env python3
"""Expire old TestFlight builds, so testers always land on the newest one.

    scripts/testflight_expire_old.py [--dry-run]

Keeps the newest build that external testers can install (externalBuildState
IN_BETA_TESTING) and everything uploaded after it (a build still waiting for
beta review). Every older build that is not yet expired is expired. Expiring
cannot be undone: testers on an expired build have to update in TestFlight.
testflight_distribute.py runs this at the end; while a new build waits for
review the previous approved build stays, so run it again after approval.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import asc_api as asc  # noqa: E402

APP_ID = "6758676921"


def expire_old(dry_run=False):
    r = asc.get("/v1/builds", {"filter[app]": APP_ID, "filter[expired]": "false", "sort": "-uploadedDate",
                               "limit": 200, "include": "preReleaseVersion,buildBetaDetail"})
    included = {(i["type"], i["id"]): i["attributes"] for i in r.get("included", [])}
    builds = []
    for b in r["data"]:
        rel = b["relationships"]
        version = included[("preReleaseVersions", rel["preReleaseVersion"]["data"]["id"])]["version"]
        detail = included[("buildBetaDetails", rel["buildBetaDetail"]["data"]["id"])]
        builds.append((b["id"], f"{version} ({b['attributes']['version']})", detail.get("externalBuildState")))
    # Newest first: everything after the newest installable build is old
    newest = next((i for i, b in enumerate(builds) if b[2] == "IN_BETA_TESTING"), None)
    if newest is None:
        print("No build in external beta testing; nothing expired")
        return
    print("Keeping", ", ".join(b[1] for b in builds[:newest + 1]))
    for build_id, name, _ in builds[newest + 1:]:
        if dry_run:
            print("  would expire", name)
            continue
        asc.patch(f"/v1/builds/{build_id}", {"data": {"type": "builds", "id": build_id,
                                                        "attributes": {"expired": True}}})
        print("  expired", name)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    expire_old(ap.parse_args().dry_run)
