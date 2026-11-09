#!/usr/bin/env python3
"""Gegevens voor het gebruikersdashboard (Gerd-Jan, 31 oktober 2026).

Maakt de JSON-bestanden van het dashboard "Squash Analyzer gebruikers"
(claude.ai/artifact/Adsn3Um4wn29PdzhgANi51). Draait elke ochtend als geplande
taak op de Mac (zie docs/gebruikersdashboard.md); de taak haalt eerst de
Play Console- en App Analytics-cijfers uit Chrome en geeft die hier mee.

Bronnen:
- App Store: verkooprapporten via de App Store Connect-API (vendor 93986735),
  per dag en per maand. Producttype 1 = nieuwe download, 3 = herdownload, 7 = update.
- TestFlight: betaBuildUsages per build via dezelfde API.
- Live-dienst: GET /api/stats met STATS_KEY (uit de omgeving of ~/.squash-keys/stats-key.txt).
- De app zelf (3.1 en later): één melding per toestel per dag, ook via /api/stats
  (app-per-dag.json), Nederland apart van keurders en testtoestellen elders.
- Accounts (4.0): aantal per dag uit de D1-database van de account-Worker, met een
  alleen-lezen query via wrangler (ingelogd op deze Mac) (accounts-per-dag.json).
- Per week (zaterdag t/m vrijdag): de bronnen hierboven naast elkaar, voor de
  weekvergelijking op het dashboard (per-week.json).
- Google Play en de opt-in-sessies van App Analytics: alleen in de browser te lezen,
  dus als JSON-bestanden meegegeven (--play, --optin). Ontbreekt er een, dan blijven
  de vorige cijfers staan.

Tussenstanden staan in ~/.squash-dashboard/state (niet in git): wat Apple al gaf,
hoeft niet opnieuw opgehaald, en de Play-cijfers groeien per run aan.

    scripts/usage-dashboard-data.py --out ~/.squash-dashboard/out
    scripts/usage-dashboard-data.py --out DIR --play play.json --optin optin.json

play.json:  {"installaties": {"2026-10-28": 0, ...}, "nieuwe_apparaten": {...},
             "actieve_gebruikers": {...}, "geinstalleerd": {...},
             "samenvatting": {"installaties": 18, "eerst_geopend": 16, "maandelijks_actief": 6}}
optin.json: {"sessies": {"2026-10-27": 1, ...}, "apparaten": {"2026-10-27": 1, ...}}
Dagen zonder rij in Play zijn 0 zolang Play voor die dag al een installatiebasis geeft.
"""
import argparse
import csv
import datetime as dt
import gzip
import io
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import asc_api  # noqa: E402

APP_ID = "6758676921"
VENDOR = "93986735"
LIVE_URL = "https://live.squashanalyzer.com"
STATE = pathlib.Path.home() / ".squash-dashboard" / "state"
FIRST_MONTH = "2026-03"           # eerste maand met App Store-downloads
PLAY_START = dt.date(2026, 10, 2)  # eerste dag op Google Play
LIVE_START = dt.date(2026, 10, 23)  # sinds de deploy van de teller
APP_START = dt.date(2026, 10, 31)   # eerste dagmelding van de app (3.1)
ACCOUNTS_START = dt.date(2026, 11, 1)  # accountdatabase aangemaakt (4.0)
ACCOUNTS_DB = "squash-account"        # D1-database van de account-Worker, alleen gelezen
REPO = pathlib.Path(os.environ.get("SQUASH_REPO", pathlib.Path.home() / "Github" / "squash-court-analyzer"))
APP_PARTS = {"referee": "scheidsrechter", "coach": "coach", "analysis": "analyse", "competition": "competitie"}
APPSTORE_DAYS = 35                 # dagen in de grafiek App Store per dag
PLAY_DAYS = 60                     # dagen in de grafieken Google Play per dag
USER_AGENT = "squashanalyzer-dashboard/1.0"  # Cloudflare weigert urllib's standaard user-agent
LIVE_KINDS = {"live": "livewedstrijden", "team": "teamwedstrijden", "viewer-live": "geopend_live",
              "viewer-team": "geopend_team", "follower-live": "volgers_live", "follower-team": "volgers_team"}
LIVE_LABELS = [("live", "Livewedstrijden gestart"), ("team", "Teamwedstrijden gestart"),
               ("viewer-live", "Kijkpagina geopend (live)"), ("viewer-team", "Kijkpagina geopend (team)"),
               ("follower-live", "Volgers vergrendelscherm (live)"), ("follower-team", "Volgers vergrendelscherm (team)")]


def load(name, default):
    path = STATE / name
    return json.loads(path.read_text()) if path.exists() else default


def save(name, value):
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / name).write_text(json.dumps(value, indent=1, sort_keys=True))


def write(out, name, rows):
    (out / name).write_text(json.dumps(rows, indent=1, ensure_ascii=False))


def days_between(first, last):
    day = first
    while day <= last:
        yield day
        day += dt.timedelta(days=1)


# ---------------------------------------------------------------- App Store

def sales_report(frequency, date):
    """Units per product type for one report, {} when Apple had no sales, None when not ready yet."""
    url = (f"{asc_api.BASE_URL}/v1/salesReports?filter[frequency]={frequency}&filter[reportType]=SALES"
           f"&filter[reportSubType]=SUMMARY&filter[vendorNumber]={VENDOR}&filter[reportDate]={date}"
           f"&filter[version]={'1_1' if frequency == 'DAILY' else '1_0'}")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {asc_api.token()}", "Accept": "application/a-gzip"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            text = gzip.decompress(resp.read()).decode()
    except urllib.error.HTTPError as error:
        body = error.read().decode(errors="replace")
        if error.code == 404 and "no sales" in body:
            return {}
        if error.code == 404:
            return None
        raise
    units = {}
    for row in csv.DictReader(io.StringIO(text), delimiter="\t"):
        kind = row["Product Type Identifier"].rstrip("F")
        units[kind] = units.get(kind, 0) + int(row["Units"])
    return units


def appstore(out, today, optin):
    daily = load("sales-daily.json", {})
    first = today - dt.timedelta(days=APPSTORE_DAYS + 5)
    for day in days_between(first, today - dt.timedelta(days=1)):
        key = day.isoformat()
        if key not in daily:
            units = sales_report("DAILY", key)
            if units is None:
                break  # later days are not ready either
            daily[key] = units
    save("sales-daily.json", daily)

    monthly = load("sales-monthly.json", {})
    month = dt.date.fromisoformat(FIRST_MONTH + "-01")
    this_month = today.replace(day=1)

    def days_of(key):
        return [units for day, units in daily.items() if day.startswith(key)]

    while month < this_month:
        key = month.strftime("%Y-%m")
        if key not in monthly:
            units = sales_report("MONTHLY", key)
            # Apple says "no sales" until the month report exists; the days show whether that is true
            if units is None or (not units and any(days_of(key))):
                break
            monthly[key] = units
        month = (month + dt.timedelta(days=32)).replace(day=1)
    save("sales-monthly.json", monthly)

    months = []
    for key in sorted(monthly):
        months.append({"maand": key, "nieuwe_downloads": monthly[key].get("1", 0), "herdownloads": monthly[key].get("3", 0)})
    while month <= this_month:  # months without a report yet, from the days
        key = month.strftime("%Y-%m")
        days = days_of(key)
        months.append({"maand": key, "nieuwe_downloads": sum(u.get("1", 0) for u in days),
                       "herdownloads": sum(u.get("3", 0) for u in days)})
        month = (month + dt.timedelta(days=32)).replace(day=1)
    write(out, "appstore-per-maand.json", months)

    last = max(daily) if daily else None
    rows = []
    if last:
        for day in days_between(dt.date.fromisoformat(last) - dt.timedelta(days=APPSTORE_DAYS - 1), dt.date.fromisoformat(last)):
            key = day.isoformat()
            units = daily.get(key, {})
            rows.append({"dag": key, "nieuwe_downloads": units.get("1", 0), "herdownloads": units.get("3", 0),
                         "updates": units.get("7", 0), "sessies_optin": optin["sessies"].get(key),
                         "actieve_apparaten_optin": optin["apparaten"].get(key)})
    write(out, "appstore-per-dag.json", rows)
    return last


def testflight(out):
    builds = asc_api.get("/v1/builds", {"filter[app]": APP_ID, "limit": "30", "sort": "-uploadedDate", "include": "preReleaseVersion"})
    versions = {item["id"]: item["attributes"]["version"] for item in builds.get("included", [])}
    rows = []
    for build in builds["data"]:
        attrs = build["attributes"]
        pre = build["relationships"]["preReleaseVersion"]["data"]
        usage = asc_api.get(f"/v1/builds/{build['id']}/metrics/betaBuildUsages")["data"][0]["dataPoints"][0]["values"]
        version = versions.get(pre["id"]) if pre else None
        rows.append({"build": f"{version} ({attrs['version']})", "versie": version, "buildnummer": int(attrs["version"]),
                     "geupload": attrs["uploadedDate"][:10], "actief": not attrs["expired"],
                     "installaties": usage["installCount"], "sessies": usage["sessionCount"],
                     "uitgenodigd": usage["inviteCount"], "crashes": usage["crashCount"], "feedback": usage["feedbackCount"]})
    write(out, "testflight-builds.json", rows)


# ---------------------------------------------------------------- live

def stats_key():
    key = os.environ.get("STATS_KEY", "").strip()
    if not key:
        path = pathlib.Path.home() / ".squash-keys" / "stats-key.txt"
        key = path.read_text().strip() if path.exists() else ""
    return key


def live(out, today):
    url = f"{LIVE_URL}/api/stats?from={LIVE_START.isoformat()}&to={today.isoformat()}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {stats_key()}", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        answer = json.loads(resp.read().decode())
    totals = answer["totals"]
    write(out, "live-totalen.json", [{"soort": label, "echt": totals[kind]["real"], "test": totals[kind]["test"]}
                                     for kind, label in LIVE_LABELS])
    # Weeks run Saturday to Friday, as in the weekly report; the last one may still be running
    weeks = {}
    for day in days_between(LIVE_START, today):
        end = day + dt.timedelta(days=(4 - day.weekday()) % 7)
        weeks.setdefault(end.isoformat(), {"week_tm": end.isoformat(), **{col: 0 for col in LIVE_KINDS.values()},
                                           "wedstrijden_nl": 0})
    for row in answer["rows"]:
        if row["test"] or row["kind"] not in LIVE_KINDS:
            continue
        day = dt.date.fromisoformat(row["day"])
        end = (day + dt.timedelta(days=(4 - day.weekday()) % 7)).isoformat()
        if end in weeks:
            weeks[end][LIVE_KINDS[row["kind"]]] += row["n"]
            # store reviewers and test devices start matches from abroad; Dutch starts are the real use
            if row["kind"] in ("live", "team") and row.get("country") == "NL":
                weeks[end]["wedstrijden_nl"] += row["n"]
    rows = [weeks[key] for key in sorted(weeks)]
    for row in rows:
        row["volgers"] = row["volgers_live"] + row["volgers_team"]
    write(out, "live-per-week.json", rows)
    app_days(out, today, answer.get("appRows", []))


def app_days(out, today, app_rows):
    """The app's own daily report (3.1 and later): devices that opened it, per day, Dutch apart from the rest."""
    days = {day.isoformat(): {"dag": day.isoformat(), "geopend_nl": 0, "nieuw_nl": 0, "ios_nl": 0, "android_nl": 0,
                              **{f"{name}_nl": 0 for name in APP_PARTS.values()}, "geopend_elders": 0, "nieuw_elders": 0}
            for day in days_between(APP_START, today)}
    for row in app_rows:
        day = days.get(row["day"])
        if not day:
            continue
        where = "nl" if row.get("country") == "NL" else "elders"
        kind = row["kind"]
        if kind == "app":
            day[f"geopend_{where}"] += row["n"]
            if where == "nl" and row.get("platform") in ("ios", "android"):
                day[f"{row['platform']}_nl"] += row["n"]
        elif kind == "app-first":
            day[f"nieuw_{where}"] += row["n"]
        elif where == "nl" and kind[4:] in APP_PARTS:
            day[f"{APP_PARTS[kind[4:]]}_nl"] += row["n"]
    write(out, "app-per-dag.json", [days[key] for key in sorted(days)])


# ---------------------------------------------------------------- Google Play

def play(out, fresh):
    stored = load("play.json", {"installaties": {}, "nieuwe_apparaten": {}, "actieve_gebruikers": {}, "geinstalleerd": {}, "samenvatting": {}})
    if fresh:
        for metric, values in fresh.items():
            if metric == "samenvatting":
                stored["samenvatting"] = values
            else:
                stored.setdefault(metric, {}).update({day: int(n) for day, n in values.items()})
        save("play.json", stored)
    base = stored["geinstalleerd"]
    last = max(base) if base else None
    rows = []
    if last:
        first = max(PLAY_START, dt.date.fromisoformat(last) - dt.timedelta(days=PLAY_DAYS - 1))
        for day in days_between(first, dt.date.fromisoformat(last)):
            key = day.isoformat()
            rows.append({"dag": key, "installaties": stored["installaties"].get(key, 0),
                         "nieuwe_apparaten": stored["nieuwe_apparaten"].get(key, 0),
                         "actieve_gebruikers": stored["actieve_gebruikers"].get(key, 0),
                         "geinstalleerd": base.get(key, 0)})
    write(out, "play-per-dag.json", rows)
    summary = stored["samenvatting"]
    write(out, "play-28-dagen.json", [
        {"cijfer": "Installaties (alle apparaten)", "waarde": summary.get("installaties")},
        {"cijfer": "Voor het eerst geopend", "waarde": summary.get("eerst_geopend")},
        {"cijfer": "Maandelijks actieve apparaten", "waarde": summary.get("maandelijks_actief")}])
    return last


# ---------------------------------------------------------------- Accounts (4.0)

def wrangler():
    """The wrangler of the account Worker's checkout (logged in on this Mac), else via npx."""
    local = REPO / "server" / "account-worker" / "node_modules" / ".bin" / "wrangler"
    return [os.environ["WRANGLER"]] if os.environ.get("WRANGLER") else [str(local)] if local.exists() \
        else ["npx", "--yes", "wrangler@4.156.0"]


def accounts(out, today):
    """Accounts made per day, read from the account database with a read-only query."""
    sql = "SELECT date(created_at / 1000, 'unixepoch') AS dag, COUNT(*) AS n FROM accounts GROUP BY dag"
    result = subprocess.run([*wrangler(), "d1", "execute", ACCOUNTS_DB, "--remote", "--json", "--command", sql],
                            cwd=STATE.parent, capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip()[-300:])
    text = result.stdout
    made = {row["dag"]: row["n"] for row in json.loads(text[text.index("["):])[0]["results"]}
    rows, total = [], sum(n for day, n in made.items() if day < ACCOUNTS_START.isoformat())
    for day in days_between(ACCOUNTS_START, today):
        total += made.get(day.isoformat(), 0)
        rows.append({"dag": day.isoformat(), "nieuw": made.get(day.isoformat(), 0), "totaal": total})
    write(out, "accounts-per-dag.json", rows)
    return today.isoformat()


# ---------------------------------------------------------------- Per week

def friday_of(day):
    return day + dt.timedelta(days=(4 - day.weekday()) % 7)


def weeks(out, today):
    """Weeks from Saturday to Friday side by side; a source counts only for weeks it fully covers."""
    daily = load("sales-daily.json", {})
    stored = load("play.json", {})
    play_days = sorted(stored.get("geinstalleerd", {}))
    live_weeks = {row["week_tm"]: row for row in json.loads((out / "live-per-week.json").read_text())} \
        if (out / "live-per-week.json").exists() else {}
    app = {row["dag"]: row for row in json.loads((out / "app-per-dag.json").read_text())} \
        if (out / "app-per-dag.json").exists() else {}
    made = {row["dag"]: row for row in json.loads((out / "accounts-per-dag.json").read_text())} \
        if (out / "accounts-per-dag.json").exists() else {}
    sources = {"appstore": (min(daily), max(daily)) if daily else None,
               "play": (play_days[0], play_days[-1]) if play_days else None}

    def covered(source, first, last):
        span = sources[source]
        return bool(span) and span[0] <= first.isoformat() and last.isoformat() <= span[1]

    rows = []
    end = friday_of(PLAY_START) + dt.timedelta(days=7)  # the first full week on Google Play
    while end <= friday_of(today):
        first = end - dt.timedelta(days=6)
        keys = [day.isoformat() for day in days_between(first, end)]
        row = {"week_tm": end.isoformat(), "lopend": end >= today}
        if covered("appstore", first, end):
            row.update({col: sum(daily[key].get(kind, 0) for key in keys)
                        for col, kind in (("as_nieuw", "1"), ("as_her", "3"), ("as_updates", "7"))})
        else:
            row.update(as_nieuw=None, as_her=None, as_updates=None)
        if covered("play", first, end):
            row["play_installaties"] = sum(stored["installaties"].get(key, 0) for key in keys)
            row["play_geinstalleerd"] = stored["geinstalleerd"].get(end.isoformat())
        else:
            row.update(play_installaties=None, play_geinstalleerd=None)
        week = live_weeks.get(end.isoformat()) if first >= LIVE_START else None
        row["wedstrijden"] = week["livewedstrijden"] + week["teamwedstrijden"] if week else None
        row["wedstrijden_nl"] = week["wedstrijden_nl"] if week else None
        row["geopend"] = week["geopend_live"] + week["geopend_team"] if week else None
        # device-days: a device that opens the app on three days counts three times
        full = first >= APP_START and all(key in app for key in keys)
        for col in ("geopend_nl", "nieuw_nl", "geopend_elders"):
            row[f"app_{col}"] = sum(app[key][col] for key in keys) if full else None
        known = [key for key in keys if key in made]
        row["accounts_nieuw"] = sum(made[key]["nieuw"] for key in known) if known and end < today else None
        row["accounts_totaal"] = made[known[-1]]["totaal"] if known and end < today else None
        rows.append(row)
        end += dt.timedelta(days=7)
    write(out, "per-week.json", rows)
    done = [row["week_tm"] for row in rows if not row["lopend"]]
    return done[-1] if done else None


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", required=True, help="map voor de JSON-bestanden")
    parser.add_argument("--play", help="Play Console-cijfers uit de browser (JSON)")
    parser.add_argument("--optin", help="App Analytics opt-in-sessies uit de browser (JSON)")
    args = parser.parse_args()
    out = pathlib.Path(os.path.expanduser(args.out))
    out.mkdir(parents=True, exist_ok=True)
    today = dt.date.today()

    optin = load("optin.json", {"sessies": {}, "apparaten": {}})
    if args.optin:
        fresh = json.loads(pathlib.Path(args.optin).read_text())
        for metric in ("sessies", "apparaten"):
            optin[metric].update({day: int(n) for day, n in fresh.get(metric, {}).items()})
        save("optin.json", optin)

    report = {}
    for name, step in [("appstore", lambda: appstore(out, today, optin)), ("testflight", lambda: testflight(out)),
                       ("live", lambda: live(out, today)),
                       ("play", lambda: play(out, json.loads(pathlib.Path(args.play).read_text()) if args.play else None)),
                       ("accounts", lambda: accounts(out, today)),
                       ("weken", lambda: weeks(out, today))]:
        try:
            report[name] = {"ok": True, "laatste_dag": step()}
        except Exception as error:  # one source failing must not stop the others
            report[name] = {"ok": False, "fout": f"{type(error).__name__}: {error}"}
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
