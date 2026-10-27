#!/usr/bin/env python3
"""Weekrapport van de website en de live-dienst, als markdown (Gerd-Jan, 23 oktober 2026).

Draait elke zaterdagochtend als geplande taak in de cloud en wordt per mail naar
info@squashanalyzer.com gestuurd (zie docs/weekrapport.md). Bronnen:

- Cloudflare-analytics van de zone squashanalyzer.com (GraphQL): verzoeken,
  paginaweergaven, unieke bezoekers, landen, meest bezochte pagina's. Vraagt
  CLOUDFLARE_API_TOKEN (Analytics: Read) en optioneel CLOUDFLARE_ZONE_ID.
- De gebruikscijfers van de live-dienst (GET /api/stats, server/live-worker/src/stats.js).
  Vraagt STATS_KEY. Alleen tellingen per dag, niets persoonlijks.

Ontbreekt een sleutel, dan staat dat in het rapport en komt de rest gewoon.
Per week wordt een snapshot in docs/stats/weekly/<einddatum>.json bewaard, zodat
de trend niet afhangt van hoe lang Cloudflare gegevens bewaart.

    scripts/weekly-stats.py                 # de week tot en met gisteren
    scripts/weekly-stats.py --end 2026-10-17
    scripts/weekly-stats.py --sample        # voorbeeldgegevens, om de opmaak te zien
    scripts/weekly-stats.py --out rapport.md
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

ZONE_NAME = "squashanalyzer.com"
LIVE_URL = os.environ.get("LIVE_URL", "https://live.squashanalyzer.com").rstrip("/")
GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
REST = "https://api.cloudflare.com/client/v4"
TIMEOUT = 30
WEEKS = 8
ROOT = pathlib.Path(__file__).resolve().parent.parent
SNAPSHOTS = ROOT / "docs" / "stats" / "weekly"
MONTHS = ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus",
          "september", "oktober", "november", "december"]
KIND_LABELS = [("live", "Livewedstrijden"), ("team", "Teamwedstrijden"),
               ("viewer-live", "Kijkers bij een livewedstrijd"), ("viewer-team", "Kijkers bij een teamwedstrijd"),
               ("follower-live", "Volgers vergrendelscherm (live)"), ("follower-team", "Volgers vergrendelscherm (team)")]


# ---------------------------------------------------------------- HTTP

def http_json(url, headers=None, data=None):
    body = json.dumps(data).encode("utf-8") if data is not None else None
    # Cloudflare's bot protection answers 403 to urllib's default user agent
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json",
                                                          "User-Agent": "squashanalyzer-weekrapport/1.0", **(headers or {})})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def day_text(day):
    return f"{day.day} {MONTHS[day.month - 1]}"


def period_text(first, last):
    if first.month == last.month:
        return f"{first.day}–{last.day} {MONTHS[last.month - 1]} {last.year}"
    return f"{day_text(first)} – {day_text(last)} {last.year}"


# ---------------------------------------------------------------- Cloudflare

def cloudflare_zone_id(token):
    zone = os.environ.get("CLOUDFLARE_ZONE_ID", "").strip()
    if zone:
        return zone
    answer = http_json(f"{REST}/zones?name={ZONE_NAME}", headers={"Authorization": f"Bearer {token}"})
    zones = answer.get("result") or []
    if not zones:
        raise RuntimeError(f"zone {ZONE_NAME} niet gevonden met deze token")
    return zones[0]["id"]


def graphql(token, query, variables):
    answer = http_json(GRAPHQL, headers={"Authorization": f"Bearer {token}"}, data={"query": query, "variables": variables})
    if answer.get("errors"):
        raise RuntimeError("; ".join(e.get("message", "?") for e in answer["errors"]))
    return answer["data"]["viewer"]["zones"][0]


DAILY_QUERY = """
query($zone: String!, $since: Date!, $until: Date!) {
  viewer { zones(filter: { zoneTag: $zone }) {
    httpRequests1dGroups(limit: 100, filter: { date_geq: $since, date_leq: $until }, orderBy: [date_ASC]) {
      dimensions { date }
      sum { requests pageViews threats countryMap { clientCountryName requests } }
      uniq { uniques }
    }
  } }
}"""

PATHS_QUERY = """
query($zone: String!, $since: Time!, $until: Time!) {
  viewer { zones(filter: { zoneTag: $zone }) {
    httpRequestsAdaptiveGroups(limit: 12, filter: { datetime_geq: $since, datetime_leq: $until,
      requestSource: "eyeball", edgeResponseStatus: 200, clientRequestHTTPHost: "%s" }, orderBy: [count_DESC]) {
      count
      dimensions { clientRequestPath }
    }
  } }
}""" % ZONE_NAME


def fetch_cloudflare(first_day, last_day, notes):
    """Per dag: verzoeken, paginaweergaven, unieke bezoekers, landen; plus de drukste pagina's van de week."""
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "").strip()
    if not token:
        notes.append("Websitecijfers ontbreken: zet CLOUDFLARE_API_TOKEN (Cloudflare-token met *Analytics: Read* "
                     "op de zone squashanalyzer.com) als geheim in de cloudomgeving.")
        return None
    try:
        zone = cloudflare_zone_id(token)
        since = first_day - dt.timedelta(days=7 * WEEKS)
        daily = graphql(token, DAILY_QUERY, {"zone": zone, "since": since.isoformat(), "until": last_day.isoformat()})
        days = {}
        for group in daily.get("httpRequests1dGroups") or []:
            countries = {}
            for item in group["sum"].get("countryMap") or []:
                countries[item["clientCountryName"]] = countries.get(item["clientCountryName"], 0) + item["requests"]
            days[group["dimensions"]["date"]] = {
                "requests": group["sum"]["requests"], "pageViews": group["sum"]["pageViews"],
                "threats": group["sum"]["threats"], "uniques": group["uniq"]["uniques"], "countries": countries,
            }
    except (urllib.error.URLError, RuntimeError, KeyError, IndexError) as error:
        notes.append(f"Websitecijfers van Cloudflare konden niet worden opgehaald: {error}")
        return None
    paths = []
    try:
        top = graphql(token, PATHS_QUERY, {"zone": zone, "since": f"{first_day.isoformat()}T00:00:00Z",
                                           "until": f"{last_day.isoformat()}T23:59:59Z"})
        for group in top.get("httpRequestsAdaptiveGroups") or []:
            path = group["dimensions"]["clientRequestPath"]
            if path.startswith("/teams/") or path.startswith("/screenshots/"):
                continue  # teamzips en plaatjes zeggen niets over lezers
            paths.append((path, group["count"]))
    except (urllib.error.URLError, RuntimeError, KeyError, IndexError) as error:
        notes.append(f"De meest bezochte pagina's konden niet worden opgehaald: {error}")
    return {"days": days, "paths": paths}


# ---------------------------------------------------------------- live-dienst

def fetch_live(first_day, last_day, notes):
    # Without STATS_KEY in the environment the request still goes out: a network
    # secret of the cloud environment adds the Authorization header on the way
    key = os.environ.get("STATS_KEY", "").strip()
    since = first_day - dt.timedelta(days=7 * WEEKS)
    url = f"{LIVE_URL}/api/stats?from={since.isoformat()}&to={last_day.isoformat()}"
    try:
        answer = http_json(url, headers={"Authorization": f"Bearer {key}"} if key else None)
        return answer.get("rows") or []
    except urllib.error.HTTPError as error:
        if error.code == 404:
            notes.append("Cijfers van de live-dienst ontbreken: de sleutel klopt niet of ontbreekt. Zet STATS_KEY als "
                         "netwerkgeheim (host live.squashanalyzer.com, header Authorization, voorvoegsel Bearer) "
                         "of als omgevingsvariabele in de cloudomgeving; zie docs/weekrapport.md.")
        else:
            notes.append(f"Cijfers van de live-dienst konden niet worden opgehaald: HTTP {error.code}")
    except (urllib.error.URLError, ValueError) as error:
        notes.append(f"Cijfers van de live-dienst konden niet worden opgehaald: {error}")
    return None


# ---------------------------------------------------------------- rekenen

def week_bounds(end):
    """De week die eindigt op `end` (7 dagen), en de week ervoor."""
    first = end - dt.timedelta(days=6)
    return (first, end), (first - dt.timedelta(days=7), end - dt.timedelta(days=7))


def in_week(day_text, bounds):
    return bounds[0].isoformat() <= day_text <= bounds[1].isoformat()


def site_week(site, bounds):
    """Totalen van de website over een week; None zonder cijfers."""
    if not site:
        return None
    days = [d for key, d in site["days"].items() if in_week(key, bounds)]
    if not days:
        return None
    countries = {}
    for d in days:
        for country, n in d["countries"].items():
            countries[country] = countries.get(country, 0) + n
    return {
        "requests": sum(d["requests"] for d in days), "pageViews": sum(d["pageViews"] for d in days),
        "uniques": sum(d["uniques"] for d in days), "threats": sum(d["threats"] for d in days),
        "countries": countries, "days": len(days),
    }


def live_week(rows, bounds):
    """Per soort: echte en testaantallen in een week, plus club, platform en regio van de echte."""
    if rows is None:
        return None
    week = [r for r in rows if in_week(r["day"], bounds)]
    result = {"kinds": {kind: {"real": 0, "test": 0} for kind, _ in KIND_LABELS},
              "clubs": {}, "platforms": {}, "regions": {}, "languages": {}}
    for r in week:
        kind = result["kinds"].setdefault(r["kind"], {"real": 0, "test": 0})
        kind["test" if r["test"] else "real"] += r["n"]
        if r["test"]:
            continue
        if r["kind"] == "team" and r.get("club"):
            result["clubs"][r["club"]] = result["clubs"].get(r["club"], 0) + r["n"]
        if r["kind"] in ("live", "team"):
            result["platforms"][r["platform"]] = result["platforms"].get(r["platform"], 0) + r["n"]
            region = f"{r['region']} ({r['country']})" if r["region"] != "unknown" else r["country"]
            result["regions"][region] = result["regions"].get(region, 0) + r["n"]
            result["languages"][r["lang"]] = result["languages"].get(r["lang"], 0) + r["n"]
    return result


def diff_text(now, before):
    if before is None:
        return "–"
    delta = now - before
    if delta == 0:
        return "gelijk"
    sign = "+" if delta > 0 else "−"
    text = f"{sign}{abs(delta)}"
    if before:
        text += f" ({sign}{abs(round(100 * delta / before))}%)"
    return text


def fmt(n):
    return "–" if n is None else f"{n:,}".replace(",", ".")


def top(items, limit=6, total=None):
    ranked = sorted(items.items(), key=lambda kv: -kv[1])[:limit]
    if not ranked:
        return "–"
    parts = []
    for name, n in ranked:
        share = f" ({round(100 * n / total)}%)" if total else ""
        parts.append(f"{name} {fmt(n)}{share}")
    return ", ".join(parts)


# ---------------------------------------------------------------- snapshots

def save_snapshot(end, site_now, live_now):
    SNAPSHOTS.mkdir(parents=True, exist_ok=True)
    snapshot = {"week_end": end.isoformat()}
    if site_now:
        snapshot["site"] = {k: site_now[k] for k in ("requests", "pageViews", "uniques", "days")}
    if live_now:
        snapshot["live"] = {kind: v["real"] for kind, v in live_now["kinds"].items()}
        snapshot["live_test"] = {kind: v["test"] for kind, v in live_now["kinds"].items()}
    (SNAPSHOTS / f"{end.isoformat()}.json").write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + "\n")


def load_snapshots():
    result = {}
    if not SNAPSHOTS.exists():
        return result
    for path in SNAPSHOTS.glob("*.json"):
        try:
            data = json.loads(path.read_text())
            result[data["week_end"]] = data
        except (ValueError, KeyError):
            continue
    return result


# ---------------------------------------------------------------- rapport

def render(end, site, rows, notes, snapshots):
    now_b, before_b = week_bounds(end)
    site_now, site_before = site_week(site, now_b), site_week(site, before_b)
    live_now, live_before = live_week(rows, now_b), live_week(rows, before_b)
    lines = [f"# SquashAnalyzer weekrapport · {period_text(*now_b)}", ""]

    lines += ["## Website (squashanalyzer.com)", ""]
    if site_now:
        lines += ["| | Deze week | Vorige week | Verschil |", "|---|---:|---:|---:|"]
        for key, label in (("uniques", "Bezoekers (unieke adressen, per dag geteld)"),
                           ("pageViews", "Paginaweergaven"), ("requests", "Verzoeken (alles, ook plaatjes)")):
            before = site_before[key] if site_before else None
            lines.append(f"| {label} | {fmt(site_now[key])} | {fmt(before)} | {diff_text(site_now[key], before)} |")
        lines.append("")
        lines.append(f"**Landen** (verzoeken): {top(site_now['countries'], total=site_now['requests'])}")
        if site and site["paths"]:
            lines.append("")
            lines.append("**Meest bezochte pagina's**: " + ", ".join(f"`{p}` {fmt(n)}" for p, n in site["paths"][:8]))
        if site_now["days"] < 7:
            lines.append("")
            lines.append(f"_Cloudflare had cijfers voor {site_now['days']} van de 7 dagen._")
    else:
        lines.append("_Geen websitecijfers deze week (zie onderaan)._")
    lines.append("")

    lines += ["## Live-dienst (live.squashanalyzer.com)", ""]
    if live_now:
        lines += ["| | Deze week | Vorige week | Verschil |", "|---|---:|---:|---:|"]
        for kind, label in KIND_LABELS:
            now_n = live_now["kinds"][kind]["real"]
            before_n = live_before["kinds"][kind]["real"] if live_before else None
            test = live_now["kinds"][kind]["test"]
            test_text = f" (+{test} test)" if test else ""
            lines.append(f"| {label} | {fmt(now_n)}{test_text} | {fmt(before_n)} | {diff_text(now_n, before_n)} |")
        lines.append("")
        lines.append(f"**Clubs** (teamwedstrijden): {top(live_now['clubs'])}")
        lines.append(f"**Regio's** (gestarte wedstrijden): {top(live_now['regions'])}")
        lines.append(f"**Platform**: {top(live_now['platforms'])} · **Taal**: {top(live_now['languages'])}")
        lines.append("")
        lines.append("_Test = wedstrijden met de voorbeeldspelers of een testteam; die tellen niet mee in de andere getallen._")
    else:
        lines.append("_Geen cijfers van de live-dienst deze week (zie onderaan)._")
    lines.append("")

    # Trend: 8 weken uit de snapshots (website) en de live-rijen
    lines += [f"## Trend ({WEEKS} weken)", ""]
    lines += ["| Week t/m | Bezoekers | Paginaweergaven | Live | Team | Kijkers | Volgers |", "|---|---:|---:|---:|---:|---:|---:|"]
    for i in range(WEEKS - 1, -1, -1):
        week_end = end - dt.timedelta(days=7 * i)
        bounds = week_bounds(week_end)[0]
        s = site_week(site, bounds) or (snapshots.get(week_end.isoformat(), {}).get("site"))
        l = live_week(rows, bounds)
        if l is None:
            stored = snapshots.get(week_end.isoformat(), {}).get("live")
            l = {"kinds": {k: {"real": v} for k, v in stored.items()}} if stored else None
        kinds = l["kinds"] if l else {}
        get = lambda k: kinds.get(k, {}).get("real") if kinds else None  # noqa: E731
        viewers = None if not kinds else (get("viewer-live") or 0) + (get("viewer-team") or 0)
        followers = None if not kinds else (get("follower-live") or 0) + (get("follower-team") or 0)
        mark = " **(deze week)**" if i == 0 else ""
        lines.append(f"| {day_text(week_end)}{mark} | {fmt(s['uniques'] if s else None)} | {fmt(s['pageViews'] if s else None)} "
                     f"| {fmt(get('live'))} | {fmt(get('team'))} | {fmt(viewers)} | {fmt(followers)} |")
    lines.append("")
    lines.append("_Een streepje: geen cijfers voor die week (nog niet geteld, of ouder dan Cloudflare bewaart)._")
    lines.append("")

    if notes:
        lines += ["## Let op", ""]
        lines += [f"- {note}" for note in notes]
        lines.append("")
    lines.append(f"_Gemaakt op {dt.date.today().isoformat()} door scripts/weekly-stats.py._")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- voorbeeld

def sample_data(end):
    import random
    random.seed(7)
    days = {}
    for i in range(7 * WEEKS):
        day = end - dt.timedelta(days=i)
        base = 40 + (7 * WEEKS - i) // 4
        days[day.isoformat()] = {"requests": base * 9 + random.randint(0, 80), "pageViews": base * 3 + random.randint(0, 20),
                                 "uniques": base + random.randint(0, 10), "threats": random.randint(0, 2),
                                 "countries": {"Netherlands": base * 8, "Belgium": random.randint(0, 20), "Germany": random.randint(0, 8)}}
    site = {"days": days, "paths": [("/", 310), ("/handleiding/iphone.html", 88), ("/testen.html", 61), ("/privacy.html", 20)]}
    rows = []
    for i in range(7 * WEEKS):
        day = (end - dt.timedelta(days=i)).isoformat()
        if i % 2 == 0:
            rows.append({"day": day, "kind": "live", "platform": "ios", "lang": "nl", "country": "NL", "region": "South Holland", "club": "", "test": 0, "n": 1 + (i % 3)})
        if i % 7 == 3:
            rows.append({"day": day, "kind": "team", "platform": "android", "lang": "nl", "country": "NL", "region": "South Holland", "club": "All Inn Squash", "test": 0, "n": 1})
            rows.append({"day": day, "kind": "viewer-team", "platform": "unknown", "lang": "nl", "country": "NL", "region": "South Holland", "club": "", "test": 0, "n": 9})
        if i % 5 == 1:
            rows.append({"day": day, "kind": "live", "platform": "unknown", "lang": "nl", "country": "NL", "region": "Utrecht", "club": "", "test": 1, "n": 1})
            rows.append({"day": day, "kind": "viewer-live", "platform": "unknown", "lang": "en", "country": "BE", "region": "Flanders", "club": "", "test": 0, "n": 3})
    return site, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--end", help="laatste dag van de week (YYYY-MM-DD); standaard gisteren")
    parser.add_argument("--out", help="schrijf het rapport naar dit bestand in plaats van naar stdout")
    parser.add_argument("--sample", action="store_true", help="voorbeeldgegevens, geen netwerk en geen snapshot")
    parser.add_argument("--no-snapshot", action="store_true", help="geen snapshot in docs/stats/weekly schrijven")
    args = parser.parse_args()
    end = dt.date.fromisoformat(args.end) if args.end else dt.date.today() - dt.timedelta(days=1)
    now_b = week_bounds(end)[0]
    notes = []
    if args.sample:
        site, rows = sample_data(end)
    else:
        site = fetch_cloudflare(now_b[0], end, notes)
        rows = fetch_live(now_b[0], end, notes)
    snapshots = {} if args.sample else load_snapshots()
    report = render(end, site, rows, notes, snapshots)
    if not args.sample and not args.no_snapshot:
        save_snapshot(end, site_week(site, now_b), live_week(rows, now_b))
    if args.out:
        pathlib.Path(args.out).write_text(report)
        print(f"rapport geschreven naar {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(report)


if __name__ == "__main__":
    main()
