"""De poort voor uploads: geen externe build zonder geslaagde toestellentest.

`scripts/android_devices.py release` schrijft na een run zonder mislukte stappen
het teken hieronder. `testflight_distribute.py` en `play_upload.py` controleren
het. Het teken staat in de gedeelde git-map, zodat het voor elke worktree geldt.
Daarna mag de versie nog omhoog en mogen documenten wijzigen; wijzigt de app zelf,
dan moet de test opnieuw (afspraak Gerd-Jan, 7 november 2026; docs/toestellentest.md).
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_PATHS = ("SquashAnalyzer/", "SquashAnalyzerTests/", "SquashLiveActivity/", "Shared/", "Android/app/src/main/")


def git(*args):
    return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True, check=True).stdout.strip()


def stamp_path():
    common = git("rev-parse", "--git-common-dir")
    return os.path.join(common if os.path.isabs(common) else os.path.join(ROOT, common), "squash-toestellentest.json")


def is_app_file(path):
    if path.startswith(APP_PATHS):
        return True
    return path.startswith("Packages/") and "/Sources/" in path


def changed_app_files(since):
    return [p for p in git("diff", "--name-only", since, "HEAD").splitlines() if is_app_file(p)]


def dirty_app_files():
    return [line[3:] for line in git("status", "--porcelain").splitlines() if is_app_file(line[3:])]


def head():
    return git("rev-parse", "HEAD")


def write_stamp(commit, report_folder):
    """`commit`: the one tested, taken before the build; HEAD may have moved during the run"""
    with open(stamp_path(), "w") as f:
        json.dump({"commit": commit, "folder": report_folder}, f)


def problem():
    """Why this checkout may not be uploaded yet; None when it may"""
    try:
        with open(stamp_path()) as f:
            stamp = json.load(f)
    except (OSError, ValueError):
        return "er is nog geen geslaagde toestellentest"
    dirty = dirty_app_files()
    if dirty:
        return f"niet-gecommitte wijzigingen in de app ({dirty[0]})"
    try:
        changed = changed_app_files(stamp["commit"])
    except subprocess.CalledProcessError:
        return "de geteste commit is onbekend in deze checkout"
    if changed:
        return f"de app is gewijzigd sinds de toestellentest ({len(changed)} bestanden, o.a. {changed[0]})"
    return None


def require(skip=False):
    reason = problem()
    if reason is None:
        return
    if skip:
        print(f"LET OP: toestellentest overgeslagen ({reason}).", flush=True)
        return
    sys.exit(f"Upload gestopt: {reason}.\nDraai eerst: scripts/android_devices.py release\n"
             "Overslaan kan alleen op verzoek van Gerd-Jan: --skip-device-test")
