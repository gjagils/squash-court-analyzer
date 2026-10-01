#!/usr/bin/env python3
"""Update the Google Play store listing (nl-NL) from the repo: texts and contact
details from Android/play/listing-nl-NL.json, the icon, feature graphic and
phone screenshots from Android/play/. Same service-account key as
play_upload.py.

    scripts/play_listing.py --dry-run     # show what would be sent
    scripts/play_listing.py               # replace texts and images, commit
"""
import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import urllib.parse  # noqa: E402,F401  (play_upload needs it loaded)
from play_upload import API, UPLOAD_API, access_token, call  # noqa: E402

PLAY = os.path.join(os.path.dirname(__file__), "..", "Android", "play")
LANGUAGE = "nl-NL"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    with open(os.path.join(PLAY, f"listing-{LANGUAGE}.json")) as handle:
        listing = json.load(handle)
    screenshots = sorted(glob.glob(os.path.join(PLAY, "screenshots", "*.png")))
    images = {
        "icon": [os.path.join(PLAY, "icon-512.png")],
        "featureGraphic": [os.path.join(PLAY, "feature-graphic-1024x500.png")],
        "phoneScreenshots": screenshots,
    }
    print(f"Titel: {listing['title']} | kort: {len(listing['shortDescription'])} tekens | lang: {len(listing['fullDescription'])} tekens")
    for kind, files in images.items():
        print(kind, [os.path.basename(f) for f in files])
    if len(listing["shortDescription"]) > 80 or len(listing["fullDescription"]) > 4000:
        sys.exit("Tekst te lang voor Play (80 / 4000 tekens).")
    if args.dry_run:
        return

    token = access_token()
    edit = call(token, "POST", f"{API}/edits", body={})["id"]
    call(token, "PUT", f"{API}/edits/{edit}/details", body={
        "defaultLanguage": LANGUAGE,
        "contactEmail": listing["contactEmail"],
        "contactWebsite": listing["contactWebsite"],
    })
    call(token, "PUT", f"{API}/edits/{edit}/listings/{LANGUAGE}", body={
        "language": LANGUAGE,
        "title": listing["title"],
        "shortDescription": listing["shortDescription"],
        "fullDescription": listing["fullDescription"],
    })
    for kind, files in images.items():
        call(token, "DELETE", f"{API}/edits/{edit}/listings/{LANGUAGE}/{kind}")
        for path in files:
            with open(path, "rb") as handle:
                call(token, "POST", f"{UPLOAD_API}/edits/{edit}/listings/{LANGUAGE}/{kind}?uploadType=media",
                     data=handle.read(), content_type="image/png")
            print("  ↑", kind, os.path.basename(path))
    call(token, "POST", f"{API}/edits/{edit}:commit")
    print("Store-vermelding bijgewerkt.")


if __name__ == "__main__":
    main()
