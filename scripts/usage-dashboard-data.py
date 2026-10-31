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
    while month < this_month:
        key = month.strftime("%Y-%m")
        if key not in monthly:
            units = sales_report("MONTHLY", key)
            if units is None:
                break
            monthly[key] = units
        month = (month + dt.timedelta(days=32)).replace(day=1)
    save("sales-monthly.json", monthly)

    months = []
    for key in sorted(monthly):
        months.append({"maand": key, "nieuwe_downloads": monthly[key].get("1", 0), "herdownloads": monthly[key].get("3", 0)})
    current = this_month.strftime("%Y-%m")
    if current not in monthly:
        days = [units for key, units in daily.items() if key.startswith(current)]
        months.append({"maand": current, "nieuwe_downloads": sum(u.get("1", 0) for u in days),
                       "herdownloads": sum(u.get("3", 0) for u in days)})
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
        weeks.setdefault(end.isoformat(), {"week_tm": end.isoformat(), **{col: 0 for col in LIVE_KINDS.values()}})
    for row in answer["rows"]:
        if row["test"] or row["kind"] not in LIVE_KINDS:
            continue
        day = dt.date.fromisoformat(row["day"])
        end = (day + dt.timedelta(days=(4 - day.weekday()) % 7)).isoformat()
        if end in weeks:
            weeks[end][LIVE_KINDS[row["kind"]]] += row["n"]
    rows = [weeks[key] for key in sorted(weeks)]
    for row in rows:
        row["volgers"] = row["volgers_live"] + row["volgers_team"]
    write(out, "live-per-week.json", rows)


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
                       ("play", lambda: play(out, json.loads(pathlib.Path(args.play).read_text()) if args.play else None))]:
        try:
            report[name] = {"ok": True, "laatste_dag": step()}
        except Exception as error:  # one source failing must not stop the others
            report[name] = {"ok": False, "fout": f"{type(error).__name__}: {error}"}
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
