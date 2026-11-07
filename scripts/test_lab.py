#!/usr/bin/env python3
"""Firebase Test Lab: een automatische rondgang (Robo) op echte Android-toestellen.

Vult de emulatortest aan met wat die niet ziet: One UI en OxygenOS op echte hardware.
Blijft binnen de gratis runs: het project heeft geen betaalkoppeling, en elk toestel
is hier maximaal 5 minuten aan het werk. De app praat in Test Lab niet met de live-server
(`isFirebaseTestLab` in MainActivity.kt). Zie docs/toestellentest.md.

    scripts/test_lab.py              # de vaste toestellen, met de debug-APK
    scripts/test_lab.py --list oneplus
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "squash-analyzer-18fb3"
# Eén Samsung en één OnePlus: Gerd-Jans toestel en het dichtst bij de OnePlus van de teamgenoot
DEVICES = [("a13", "34"), ("OP5958L1", "34")]
TIMEOUT = "5m"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apk", default=os.path.join(ROOT, "Android/app/build/outputs/apk/debug/app-debug.apk"))
    parser.add_argument("--list", metavar="MERK", help="toon de toestellen van een merk")
    args = parser.parse_args()
    if args.list:
        command = ["gcloud", "firebase", "test", "android", "models", "list", "--project", PROJECT,
                   "--filter", f"form=PHYSICAL AND brand~{args.list}",
                   "--format", "table(codename,name,supportedVersionIds.list())"]
    else:
        if not os.path.exists(args.apk):
            sys.exit(f"Geen APK op {args.apk}: bouw eerst met ./gradlew assembleDebug")
        command = ["gcloud", "firebase", "test", "android", "run", "--project", PROJECT, "--type", "robo",
                   "--app", args.apk, "--timeout", TIMEOUT, "--record-video"]
        for model, version in DEVICES:
            command += ["--device", f"model={model},version={version},locale=nl,orientation=portrait"]
    sys.exit(subprocess.run(command).returncode)


if __name__ == "__main__":
    main()
