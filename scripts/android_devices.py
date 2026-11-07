#!/usr/bin/env python3
"""Toestellentest voor Android: dezelfde route over de schermmaten die testers hebben.

Eén emulator krijgt per profiel de schermmaat, dichtheid, tekstgrootte en navigatie
van een echt toestel; de lay-out van de app hangt daar in dp van af. Per profiel
loopt het script dezelfde schermen af, maakt schermafbeeldingen en zoekt naar wat
een mens op het eerste gezicht ook ziet: tekst of knoppen die buiten het scherm
vallen, of onder de systeembalken. Uitkomst: output/toestellen/<datum>/index.html.

    scripts/android_devices.py release                # vaste test vóór een upload: bouwt, beide Android-versies
    scripts/android_devices.py run                    # alle profielen, met de debug-APK
    scripts/android_devices.py run --only oneplus-nord3,small
    scripts/android_devices.py run --apk pad/naar.apk
    scripts/android_devices.py profiles

Draait alleen op een emulator: een echt toestel wordt geweigerd (AGENTS.md: nooit de
A13). Na afloop staat de emulator terug op zijn eigen schermmaat. Zie docs/toestellentest.md.
"""
import argparse
import datetime
import html
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

import toestellen_gate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADB = os.path.join(os.environ.get("ANDROID_HOME", os.path.expanduser("~/Library/Android/sdk")), "platform-tools", "adb")
PACKAGE = "com.squashanalyzer.android"
TEAM_LINK = "https://sbn.toernooi.nl/league/E035D752-EA4C-446D-82CF-0016EFF20E6C/team/113"

# name, label, width px, height px, density, font scale, three-button navigation.
# Waarden van de fabrikant; waar een tester een afwijkende weergave heeft staat dat erbij.
PROFILES = [
    {"id": "oneplus-nord3", "label": "OnePlus Nord 3 (teamgenoot, grote weergave)", "w": 1240, "h": 2772, "dpi": 560, "font": 1.0, "buttons": True},
    {"id": "galaxy-a13", "label": "Samsung Galaxy A13 (dichtheid geschat)", "w": 1080, "h": 2408, "dpi": 450, "font": 1.0, "buttons": True},
    {"id": "galaxy-a57-zoom", "label": "Samsung Galaxy A57, schermzoom groot", "w": 1080, "h": 2340, "dpi": 500, "font": 1.0, "buttons": False},
    {"id": "small", "label": "Klein en oud (360 x 740 dp)", "w": 720, "h": 1480, "dpi": 320, "font": 1.0, "buttons": True},
    {"id": "narrow-fold", "label": "Smal (vouwtelefoon dicht, 344 dp)", "w": 904, "h": 2316, "dpi": 420, "font": 1.0, "buttons": False},
    {"id": "big-text", "label": "Middelgroot met grote tekst (1,3)", "w": 1080, "h": 2400, "dpi": 420, "font": 1.3, "buttons": False},
    {"id": "large", "label": "Groot (Pixel Pro XL)", "w": 1344, "h": 2992, "dpi": 480, "font": 1.0, "buttons": False},
]

# De twee Android-versies van de vaste test vóór een upload (Gerd-Jan, 7 november 2026): de meest
# geïnstalleerde over alle profielen, de nieuwste over de uitersten. Bij een nieuwe Android-versie
# hier bijwerken; zie docs/toestellentest.md.
ANDROIDS = [
    {"name": "Android 16 (meest geïnstalleerd)", "folder": "android-16", "avd": "SA_Toestellen", "only": None},
    {"name": "Android 17 (nieuwste)", "folder": "android-17", "avd": "SA_Toestellen_17",
     "only": ["oneplus-nord3", "small", "large"]},
]


class Device:
    def __init__(self, serial):
        if not serial.startswith("emulator-"):
            sys.exit(f"{serial} is geen emulator: deze test draait alleen op een emulator.")
        self.serial = serial

    def adb(self, *args, check=False, binary=False, timeout=120):
        result = subprocess.run([ADB, "-s", self.serial, *args], capture_output=True, timeout=timeout)
        if check and result.returncode != 0:
            raise RuntimeError(f"adb {' '.join(args)}: {result.stderr.decode(errors='replace')}")
        return result.stdout if binary else result.stdout.decode(errors="replace")

    def shell(self, *args):
        return self.adb("shell", *args)

    def nodes(self):
        """Everything on screen with a text or description, with its bounds"""
        for _ in range(4):
            self.shell("uiautomator", "dump", "/sdcard/u.xml")
            raw = self.shell("cat", "/sdcard/u.xml")
            start = raw.find("<?xml")
            if start >= 0:
                try:
                    tree = ET.fromstring(raw[start:raw.rfind(">") + 1])
                except ET.ParseError:
                    time.sleep(1)
                    continue
                result = []
                for node in tree.iter("node"):
                    if node.get("package") != PACKAGE:
                        continue
                    match = re.match(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", node.get("bounds", ""))
                    if not match:
                        continue
                    box = [int(v) for v in match.groups()]
                    result.append({"text": node.get("text") or "", "desc": node.get("content-desc") or "", "box": box,
                                   "scrollable": node.get("scrollable") == "true"})
                return result
            time.sleep(1)
        return []

    def find(self, wanted, exact=True):
        wanted_low = wanted.lower()
        for node in self.nodes():
            for value in (node["text"], node["desc"]):
                low = value.lower()
                if (low == wanted_low) if exact else (wanted_low in low):
                    return node
        return None

    def wait(self, wanted, seconds=12, exact=True):
        end = time.time() + seconds
        while time.time() < end:
            node = self.find(wanted, exact)
            if node:
                return node
            time.sleep(1)
        return None

    def tap_box(self, box):
        self.shell("input", "tap", str((box[0] + box[2]) // 2), str((box[1] + box[3]) // 2))
        time.sleep(1.2)

    def tap(self, wanted, seconds=12, exact=True, required=True):
        node = self.wait(wanted, seconds, exact)
        if not node:
            if required:
                raise LookupError(f'"{wanted}" staat niet op het scherm')
            return False
        self.tap_box(node["box"])
        return True

    def scroll_to(self, wanted, tries=8, exact=True):
        for _ in range(tries):
            node = self.find(wanted, exact)
            if node:
                return node
            self.swipe_up()
        return None

    def size(self):
        match = re.search(r"Override size: (\d+)x(\d+)", self.shell("wm", "size")) or re.search(r"Physical size: (\d+)x(\d+)", self.shell("wm", "size"))
        return int(match.group(1)), int(match.group(2))

    def swipe_up(self):
        width, height = self.size()
        self.shell("input", "swipe", str(width // 2), str(height * 7 // 10), str(width // 2), str(height * 3 // 10), "350")
        time.sleep(1)

    def back(self):
        self.shell("input", "keyevent", "KEYCODE_BACK")
        time.sleep(1.2)

    def type_text(self, text):
        self.shell("input", "text", text.replace(" ", "%s").replace("&", "\\&"))
        time.sleep(0.8)

    def shot(self, path):
        with open(path, "wb") as f:
            f.write(self.adb("exec-out", "screencap", "-p", binary=True))

    def launch(self):
        self.shell("am", "force-stop", PACKAGE)
        self.shell("monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
        time.sleep(5)

    def system_bars(self):
        """Top and bottom of the area the app may draw text in"""
        dump = self.shell("dumpsys", "window", "displays")
        top = bottom = None
        match = re.search(r"mStableInsets?=\S*|mCurrentInsets", dump)
        window = self.shell("dumpsys", "window")
        status = re.search(r"type=statusBars frame=\[\d+,\d+\]\[\d+,(\d+)\]", window) or re.search(r"statusBars[^\n]*?frame=\[\d+,\d+\]\[\d+,(\d+)\]", window)
        nav = re.search(r"type=navigationBars frame=\[\d+,(\d+)\]\[\d+,\d+\]", window) or re.search(r"navigationBars[^\n]*?frame=\[\d+,(\d+)\]\[\d+,\d+\]", window)
        top = int(status.group(1)) if status else 0
        bottom = int(nav.group(1)) if nav else self.size()[1]
        return top, bottom

    def apply(self, profile):
        self.shell("wm", "size", f"{profile['w']}x{profile['h']}")
        self.shell("wm", "density", str(profile["dpi"]))
        self.shell("settings", "put", "system", "font_scale", str(profile["font"]))
        overlay = "enable" if profile["buttons"] else "disable"
        self.shell("cmd", "overlay", overlay, "com.android.internal.systemui.navbar.threebutton")
        if not profile["buttons"]:
            self.shell("cmd", "overlay", "enable", "com.android.internal.systemui.navbar.gestural")
        time.sleep(3)

    def reset(self):
        self.shell("wm", "size", "reset")
        self.shell("wm", "density", "reset")
        self.shell("settings", "put", "system", "font_scale", "1.0")


def first_serial():
    out = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith("emulator-") and "\tdevice" in line:
            return line.split("\t")[0]
    sys.exit("Geen emulator gevonden. Start er een: emulator -avd SA_Toestellen -no-window -no-audio")


def problems_on_screen(device):
    """What falls off the screen or under a system bar"""
    width, height = device.size()
    top, bottom = device.system_bars()
    found = []
    for node in device.nodes():
        label = node["text"] or node["desc"]
        if not label:
            continue
        left, upper, right, lower = node["box"]
        if right <= left or lower <= upper:
            continue
        short = label[:60]
        if left < 0 or right > width:
            found.append(f'buiten beeld (breedte): "{short}"')
        if upper < top and lower > 0 and not node["scrollable"]:
            found.append(f'onder de statusbalk: "{short}"')
    return found


def prepare(device, apk):
    """A clean app: Nederlands, the tour away, Mijn team set, one team match of today"""
    device.reset()
    device.shell("pm", "clear", PACKAGE)
    print("Installeren…", flush=True)
    device.adb("install", "-r", apk, check=True, timeout=300)
    device.launch()
    device.tap("Get started", required=False, seconds=10) or device.tap("Aan de slag", required=False, seconds=3)
    device.tap("Skip", required=False, seconds=4) or device.tap("Overslaan", required=False, seconds=2)
    device.tap("Settings", seconds=8, required=False) or device.tap("Instellingen", seconds=3)
    # Taal: Nederlands, whatever the emulator speaks
    if device.tap("Language", seconds=4, required=False):
        device.tap("Nederlands", seconds=6)
        time.sleep(5)
    device.launch()
    device.tap("Instellingen", seconds=8)
    device.tap("Mijn team", seconds=6)
    device.scroll_to("Teamlink")
    device.tap("Teamlink", seconds=5)
    device.type_text(TEAM_LINK)
    device.back()
    device.tap("BEWAAR TEAMLINK", seconds=5)
    time.sleep(6)
    device.launch()
    # Team match of today, typed in and not shared: nothing goes to the live server
    device.tap("Competitie", seconds=10)
    device.tap("Nieuwe teamwedstrijd", seconds=6)
    # Off, and checked: a shared match would land on the live server and a club screen
    label = device.wait("Deel met mijn team", seconds=6)
    width, _ = device.size()
    device.shell("input", "tap", str(width - width // 8), str((label["box"][1] + label["box"][3]) // 2))
    time.sleep(1.5)
    if not device.wait("De teamwedstrijd blijft alleen op deze telefoon", seconds=4, exact=False):
        raise SystemExit("Delen staat niet uit: gestopt, er is niets gemaakt.")
    # Ons team is filled in from Mijn team
    device.scroll_to("Tegenstander")
    device.tap("Tegenstander", seconds=4)
    device.type_text("Squash Delft 8")
    device.back()
    device.scroll_to("Maak teamwedstrijd")
    device.tap("Maak teamwedstrijd", seconds=4)
    time.sleep(3)
    if not device.scroll_to("Alleen op deze telefoon", tries=2):
        raise SystemExit("De testwedstrijd is gedeeld: stop hem in de app (Live stoppen).")


# The route: each step leaves a screenshot under this name. A step that fails is
# reported and the route goes on from the home screen.

def step_home(device, shot):
    device.wait("Coach", seconds=10)
    shot("home", "Beginscherm met teamwedstrijd van vandaag")
    node = device.find("Badges")
    width, height = device.size()
    _, bottom = device.system_bars()
    other = device.find("Spelers")
    # The list clips a row at its edge, so a clipped row is lower than a whole one
    clipped = node and other and node["box"][3] - node["box"][1] < other["box"][3] - other["box"][1]
    if not node or clipped or node["box"][3] > bottom:
        shot.note("home", "Badges past niet op het eerste scherm (scrollen nodig)")


def step_team_match(device, shot):
    device.tap("Squash Delft 8", exact=False, seconds=8)
    time.sleep(2)
    shot("team-match", "Teamwedstrijd, geopend vanaf de balk")
    device.back()


def step_competition(device, shot):
    device.tap("Competitie", seconds=8)
    time.sleep(2)
    shot("competition", "Competitie: vandaag en komend")
    device.swipe_up()
    device.swipe_up()
    device.swipe_up()
    shot("competition-past", "Competitie: verder naar beneden")
    device.back()


def step_team(device, shot):
    device.tap("MIJN TEAM", seconds=8)
    time.sleep(2)
    shot("team", "Mijn team")
    device.back()


def step_settings(device, shot):
    device.tap("Instellingen", seconds=8)
    time.sleep(1)
    shot("settings", "Instellingen")
    device.scroll_to("Wedstrijd volgen")
    device.tap("Wedstrijd volgen", seconds=4)
    time.sleep(2)
    shot("live-follow", "Wedstrijd volgen")
    device.back()
    device.back()


def open_coach_match(device):
    device.tap("Coach", seconds=8)
    time.sleep(2)
    if device.find("Uitgebreid"):
        device.tap("Uitgebreid", seconds=2)
    if device.tap("Hervatten", seconds=3, required=False):
        time.sleep(2)
        return
    device.tap("START WEDSTRIJD", seconds=5, exact=False)
    time.sleep(2)
    device.tap("START GAME", seconds=5, exact=False, required=False)
    time.sleep(1)


def step_coach(device, shot):
    open_coach_match(device)
    shot("coach", "Coach tussen de punten, met de keuze Invoer")
    device.tap("Uitgebreid", seconds=4)
    device.tap("Speler 1", seconds=4)
    time.sleep(1)
    shot("coach-how", "Coach: hoe werd het punt gewonnen?")
    device.tap("Winner", seconds=4, exact=False)
    time.sleep(1)
    shot("coach-court", "Coach: de baan")
    cancel = device.wait("Annuleren", seconds=4)
    width, _ = device.size()
    device.shell("input", "tap", str(width // 3), str(cancel["box"][1] * 3 // 5))
    time.sleep(1.5)
    shot("coach-shot", "Coach: welke slag?")
    device.tap("Annuleren", seconds=4, required=False)
    time.sleep(1)
    device.tap("Eenvoudig", seconds=4)
    device.tap("Speler 2", seconds=4)
    time.sleep(1)
    shot("coach-simple", "Coach Eenvoudig: meteen de baan")
    device.tap("Annuleren", seconds=4, required=False)
    time.sleep(1)
    device.tap("Uitgebreid", seconds=4, required=False)


def step_referee(device, shot):
    device.tap("Scheidsrechter", seconds=8)
    time.sleep(2)
    if device.tap("Hervatten", seconds=3, required=False):
        time.sleep(2)
    else:
        shot("referee-setup", "Scheidsrechter: opzet")
        device.tap("START SCHEIDSRECHTER", seconds=5)
        time.sleep(2)
    shot("referee", "Scheidsrechter")


ROUTE = [step_home, step_team_match, step_competition, step_team, step_settings, step_coach, step_referee]


class Shots:
    """Takes the screenshots of one profile and collects what is wrong"""

    def __init__(self, device, folder, profile_id):
        self.device = device
        self.folder = folder
        self.profile_id = profile_id
        self.items = {}

    def __call__(self, name, title):
        file = f"{self.profile_id}-{name}.png"
        self.device.shot(os.path.join(self.folder, file))
        self.items[name] = {"file": file, "title": title, "problems": problems_on_screen(self.device)}

    def note(self, name, text):
        self.items[name]["problems"].append(text)


def run_profile(device, profile, folder):
    device.apply(profile)
    shots = Shots(device, folder, profile["id"])
    failures = []
    for step in ROUTE:
        name = step.__name__.replace("step_", "")
        print(f"  {name}", flush=True)
        device.launch()
        try:
            step(device, shots)
        except Exception as error:  # the route goes on; the report says what failed
            failed = f"{name}-mislukt"
            shots(failed, f"Stap {name} mislukt")
            failures.append(f"{name}: {error}")
    return {"id": profile["id"], "label": profile["label"], "dp": f"{profile['w'] * 160 // profile['dpi']} x {profile['h'] * 160 // profile['dpi']} dp",
            "font": profile["font"], "shots": shots.items, "failures": failures}


def report(results, folder, version):
    names = []
    titles = {}
    for result in results:
        for name, item in result["shots"].items():
            if name not in names:
                names.append(name)
            titles.setdefault(name, item["title"])
    problems = sum(len(item["problems"]) for result in results for item in result["shots"].values())
    failures = sum(len(result["failures"]) for result in results)
    rows = []
    rows.append("<tr><th></th>" + "".join(
        f"<th>{html.escape(r['label'])}<br><small>{r['dp']}{' · tekst ' + str(r['font']) if r['font'] != 1.0 else ''}</small></th>" for r in results) + "</tr>")
    for name in names:
        cells = [f"<th class=side>{html.escape(titles[name])}</th>"]
        for result in results:
            item = result["shots"].get(name)
            if not item:
                cells.append("<td class=empty>–</td>")
                continue
            notes = "".join(f"<div class=problem>{html.escape(p)}</div>" for p in item["problems"])
            cells.append(f"<td><a href='{item['file']}'><img loading=lazy src='{item['file']}' alt=''></a>{notes}</td>")
        rows.append("<tr>" + "".join(cells) + "</tr>")
    failed = "".join(f"<li>{html.escape(r['label'])}: {html.escape(f)}</li>" for r in results for f in r["failures"])
    page = f"""<!doctype html><html lang=nl><meta charset=utf-8><title>Toestellentest {html.escape(version)}</title>
<style>body{{font:14px -apple-system,sans-serif;background:#111;color:#eee;margin:16px}}table{{border-collapse:collapse}}
th,td{{padding:6px;vertical-align:top;text-align:left;font-weight:500}}th small{{color:#aaa;font-weight:400}}
th.side{{position:sticky;left:0;background:#111;width:120px}}img{{width:190px;border:1px solid #444;border-radius:8px}}
.problem{{color:#ff9d7a;font-size:12px;max-width:190px}}.failed{{color:#ff9d7a}}</style>
<h1>Toestellentest {html.escape(version)}</h1>
<p>{len(results)} schermmaten, {datetime.datetime.now():%-d-%-m-%Y %H:%M}. Gemeld: {problems} lay-outpunt(en), {failures} mislukte stap(pen).
Een emulator met de maten van het toestel; fabrikantaanpassingen (One UI, OxygenOS) zitten er niet in.</p>
{f"<h2>Mislukte stappen</h2><ul class=failed>{failed}</ul>" if failed else ""}
<table>{"".join(rows)}</table></html>"""
    path = os.path.join(folder, "index.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(page)
    return path, problems, failures


def run_all(device, chosen, apk, folder, title):
    """All chosen profiles on one running emulator; returns (report, layout points, failed steps)"""
    os.makedirs(folder, exist_ok=True)
    results = []
    try:
        prepare(device, apk)
        for profile in chosen:
            print(profile["label"], flush=True)
            results.append(run_profile(device, profile, folder))
            report(results, folder, title)  # also after a crash there is a report
    finally:
        device.reset()
    return report(results, folder, title)


def online_emulators():
    lines = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines()
    return [line.split()[0] for line in lines[1:] if line.startswith("emulator-") and "device" in line]


def boot(avd):
    """Starts `avd` without a window and returns its Device once it has booted"""
    emulator = os.path.join(os.path.dirname(os.path.dirname(ADB)), "emulator", "emulator")
    subprocess.Popen([emulator, "-avd", avd, "-no-window", "-no-audio", "-no-snapshot"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    end = time.time() + 300
    while time.time() < end:
        for serial in online_emulators():
            device = Device(serial)
            if device.shell("getprop", "sys.boot_completed").strip() == "1":
                # A fresh emulator's own "System UI isn't responding" covered the app (Android 17,
                # 7 November 2026): no system error dialogs on the test emulators. A crash of the app
                # still shows as a failed step.
                device.shell("settings", "put", "global", "hide_error_dialogs", "1")
                time.sleep(20)
                device.shell("am", "broadcast", "-a", "android.intent.action.CLOSE_SYSTEM_DIALOGS")
                return device
        time.sleep(5)
    sys.exit(f"Emulator {avd} start niet.")


def stop(device):
    device.adb("emu", "kill")
    end = time.time() + 60
    while time.time() < end and online_emulators():
        time.sleep(2)


def release(skip_build=False):
    """The fixed test before an upload: builds, runs both Android versions and leaves the stamp"""
    if toestellen_gate.dirty_app_files():
        sys.exit("Eerst committen: de test geldt voor een commit.")
    if online_emulators():
        sys.exit("Er draait al een emulator; stop die eerst.")
    tested = toestellen_gate.head()
    apk = os.path.join(ROOT, "Android/app/build/outputs/apk/debug/app-debug.apk")
    if not skip_build:
        studio_java = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        env = dict(os.environ, JAVA_HOME=os.environ.get("JAVA_HOME", studio_java),
                   ANDROID_HOME=os.path.dirname(os.path.dirname(ADB)))
        subprocess.run(["./gradlew", "assembleDebug"], cwd=os.path.join(ROOT, "Android"), env=env, check=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    base = os.path.join(ROOT, "output", "toestellen", stamp)
    started = time.time()
    failed = 0
    for android in ANDROIDS:
        print(f"\n== {android['name']}", flush=True)
        chosen = [p for p in PROFILES if android["only"] is None or p["id"] in android["only"]]
        device = boot(android["avd"])
        try:
            path, problems, failures = run_all(device, chosen, apk, os.path.join(base, android["folder"]),
                                               f"{stamp} {android['name']}")
        finally:
            stop(device)
        print(f"{android['name']}: {problems} lay-outpunt(en), {failures} mislukte stap(pen): {path}", flush=True)
        failed += failures
    print(f"\nKlaar in {int(time.time() - started) // 60} min: {base}")
    if failed:
        sys.exit(f"{failed} mislukte stap(pen): upload blijft dicht.")
    toestellen_gate.write_stamp(tested, base)
    print("Upload mag door de poort. Bekijk ook zelf de beelden: de test ziet niet alles.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("profiles")
    run = sub.add_parser("run")
    run.add_argument("--apk", default=os.path.join(ROOT, "Android/app/build/outputs/apk/debug/app-debug.apk"))
    run.add_argument("--only", default="")
    run.add_argument("--serial", default="")
    rel = sub.add_parser("release", help="vaste test vóór een upload: beide Android-versies, opent de poort")
    rel.add_argument("--skip-build", action="store_true", help="de debug-APK is al van deze commit")
    args = parser.parse_args()
    if args.command == "release":
        release(args.skip_build)
        return
    if args.command == "profiles":
        for profile in PROFILES:
            print(f"{profile['id']:18} {profile['w']}x{profile['h']} @{profile['dpi']} = {profile['w'] * 160 // profile['dpi']} x {profile['h'] * 160 // profile['dpi']} dp  {profile['label']}")
        return
    device = Device(args.serial or first_serial())
    chosen = [p for p in PROFILES if not args.only or p["id"] in args.only.split(",")]
    if not chosen:
        sys.exit("Geen profiel met die naam; zie: scripts/android_devices.py profiles")
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    folder = os.path.join(ROOT, "output", "toestellen", stamp)
    os.makedirs(folder, exist_ok=True)
    started = time.time()
    path, problems, failures = run_all(device, chosen, args.apk, folder, stamp)
    print(f"\nKlaar in {int(time.time() - started) // 60} min: {path}")
    print(f"{problems} lay-outpunt(en), {failures} mislukte stap(pen)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
