#!/usr/bin/env python3
"""One place for the version and build numbers of both apps (docs/opleveren-en-hosting.md).

The scheme:

    3.1 build 4      the 4th upload to testers (TestFlight / Google Play) of version 3.1
    3.1 build 4.1    the 1st internal delivery after that upload (own iPhone / Android phone)

The version (3.1) is the same on iOS and Android and goes up with a new test
round; the production release is a whole version (3.0, 4.0, ...). The build
starts at 1 again with every version. What is committed is the last upload:
`upload` raises the build before the next one, `internal` only prints the
numbers for a local delivery and keeps its own counter in the git-ignored file
.internal-build.

    iOS      MARKETING_VERSION = 3.1         CURRENT_PROJECT_VERSION = 4  (4.1 internal)
    Android  versionName "3.1 (4)"           versionCode = 3·1.000.000 + 1·10.000 + 4·100 (+ internal)

The Android versionCode must always go up and can never start over, hence the
formula: version and build are small digits, internal deliveries add 1..99.

    scripts/version.py show                  # current numbers on both platforms
    scripts/version.py check                 # iOS and Android agree (used in lint.sh)
    scripts/version.py set 3.1               # new version, build 0 (nothing uploaded yet)
    scripts/version.py upload                # build + 1: do this right before an upload
    scripts/version.py internal --new        # count an internal delivery: 3.1 build 4.1
    scripts/version.py internal --xcode      # for it: CURRENT_PROJECT_VERSION=4.1  (xcodebuild ... $(...))
    scripts/version.py internal --gradle     # for it: -PsquashInternal=1           (./gradlew ... $(...))
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PBXPROJ = os.path.join(ROOT, "SquashAnalyzer.xcodeproj", "project.pbxproj")
GRADLE = os.path.join(ROOT, "Android", "app", "build.gradle.kts")
COUNTER = os.path.join(ROOT, ".internal-build")


def android_code(version: str, build: int, internal: int = 0) -> int:
    major, minor = (int(part) for part in version.split("."))
    if not (0 <= minor < 100 and 0 <= build < 100 and 0 <= internal < 100):
        raise ValueError("minor, build and internal must be below 100")
    return major * 1_000_000 + minor * 10_000 + build * 100 + internal


def build_text(build: int, internal: int = 0) -> str:
    return f"{build}.{internal}" if internal else str(build)


def android_name(version: str, build: int, internal: int = 0) -> str:
    return f"{version} ({build_text(build, internal)})"


def valid_version(version: str) -> str:
    if not re.fullmatch(r"\d+\.\d+", version):
        sys.exit(f"Versie '{version}' moet de vorm 3.1 hebben")
    return version


# MARK: reading and writing the project files

def read_ios() -> tuple:
    with open(PBXPROJ) as handle:
        text = handle.read()
    versions = set(re.findall(r"MARKETING_VERSION = ([\d.]+);", text))
    builds = set(re.findall(r"CURRENT_PROJECT_VERSION = ([\d.]+);", text))
    if len(versions) != 1 or len(builds) != 1:
        sys.exit(f"project.pbxproj heeft verschillende waarden: versie {versions}, build {builds}")
    return versions.pop(), int(builds.pop())


def read_android() -> tuple:
    with open(GRADLE) as handle:
        text = handle.read()
    version = re.search(r'val squashVersion = "([\d.]+)"', text)
    build = re.search(r"val squashBuild = (\d+)", text)
    code = re.search(r"val squashCode = (\d+)", text)
    if not (version and build and code):
        sys.exit("build.gradle.kts mist squashVersion, squashBuild of squashCode")
    return version.group(1), int(build.group(1)), int(code.group(1))


def write(version: str, build: int) -> None:
    with open(PBXPROJ) as handle:
        text = handle.read()
    text = re.sub(r"MARKETING_VERSION = [\d.]+;", f"MARKETING_VERSION = {version};", text)
    text = re.sub(r"CURRENT_PROJECT_VERSION = [\d.]+;", f"CURRENT_PROJECT_VERSION = {build};", text)
    with open(PBXPROJ, "w") as handle:
        handle.write(text)
    with open(GRADLE) as handle:
        text = handle.read()
    text = re.sub(r'val squashVersion = "[\d.]+"', f'val squashVersion = "{version}"', text)
    text = re.sub(r"val squashBuild = \d+", f"val squashBuild = {build}", text)
    text = re.sub(r"val squashCode = \d+", f"val squashCode = {android_code(version, build)}", text)
    with open(GRADLE, "w") as handle:
        handle.write(text)
    if os.path.exists(COUNTER):
        os.remove(COUNTER)


def problems() -> list:
    version, build = read_ios()
    android_version, android_build, code = read_android()
    found = []
    if version != android_version:
        found.append(f"versie: iOS {version}, Android {android_version}")
    if build != android_build:
        found.append(f"build: iOS {build}, Android {android_build}")
    if code != android_code(android_version, android_build):
        found.append(f"versionCode {code} hoort {android_code(android_version, android_build)} te zijn")
    return found


# MARK: the internal counter (local only)

def current_internal(version: str, build: int) -> int:
    """The internal delivery number after upload `build` of `version` (0 = none yet)."""
    if os.path.exists(COUNTER):
        with open(COUNTER) as handle:
            saved = json.load(handle)
        if saved.get("version") == version and saved.get("build") == build:
            return saved.get("n", 0)
    return 0


def new_internal(version: str, build: int) -> int:
    n = current_internal(version, build) + 1
    with open(COUNTER, "w") as handle:
        json.dump({"version": version, "build": build, "n": n}, handle)
    return n


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("show")
    sub.add_parser("check")
    set_cmd = sub.add_parser("set")
    set_cmd.add_argument("version")
    set_cmd.add_argument("--build", type=int, default=0)
    sub.add_parser("upload")
    internal = sub.add_parser("internal")
    internal.add_argument("--new", action="store_true", help="count a new internal delivery (build 4 -> 4.1 -> 4.2)")
    internal.add_argument("--xcode", action="store_true", help="print the xcodebuild setting for the current internal number")
    internal.add_argument("--gradle", action="store_true", help="print the Gradle property for the current internal number")
    args = parser.parse_args()

    if args.command == "show":
        version, build = read_ios()
        print(f"{version} build {build}")
        print(f"  iOS      {version} ({build})")
        print(f"  Android  {android_name(version, build)}, versionCode {android_code(version, build)}")
        for line in problems():
            print("  LET OP:", line)
    elif args.command == "check":
        found = problems()
        for line in found:
            print("Versie-afwijking:", line)
        sys.exit(1 if found else 0)
    elif args.command == "set":
        write(valid_version(args.version), args.build)
        print(f"{args.version} build {args.build}")
    elif args.command == "upload":
        version, build = read_ios()
        write(version, build + 1)
        print(f"{version} build {build + 1}: klaar voor een upload")
    elif args.command == "internal":
        version, build = read_ios()
        n = new_internal(version, build) if args.new else current_internal(version, build)
        if args.xcode:
            print(f"CURRENT_PROJECT_VERSION={build_text(build, n)}")
        elif args.gradle:
            print(f"-PsquashInternal={n}")
        else:
            print(f"{version} build {build_text(build, n)}")

if __name__ == "__main__":
    main()
