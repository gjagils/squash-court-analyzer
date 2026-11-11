#!/usr/bin/env python3
"""Hoe vaak "Stel een vraag" gebruikt wordt en welke vragen er gesteld worden.

Leest het overzicht van https://www.squashanalyzer.com/api/vraag/stats met de
STATS_KEY uit ~/.squash-keys/stats-key.txt (dezelfde sleutel als de
gebruikerscijfers). Vragen staan 180 dagen in de accountdatabase, zonder IP-adres.

    scripts/vraag-stats.py              # laatste 30 dagen
    scripts/vraag-stats.py --days 90
    scripts/vraag-stats.py --json       # ruwe gegevens
"""
import argparse
import json
import os
import urllib.request

URL = "https://www.squashanalyzer.com/api/vraag/stats"
KEY = os.path.expanduser("~/.squash-keys/stats-key.txt")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    with open(KEY) as f:
        key = f.read().strip()
    req = urllib.request.Request(f"{URL}?days={args.days}", headers={"Authorization": f"Bearer {key}", "User-Agent": "squash-stats"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.load(r)
    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return
    print(f"Vragen in de laatste {args.days} dagen: {data['total']} (zonder antwoord: {data['unanswered']})")
    busy = [d for d in data["perDay"] if d["count"]]
    for d in busy:
        print(f"  {d['day']}  {'#' * min(d['count'], 60)} {d['count']}")
    print("\nNieuwste vragen:")
    for q in data["questions"][:50]:
        mark = "" if q["answered"] else "  (geen antwoord)"
        print(f"  {q['askedAt'][:16].replace('T', ' ')}  {q['source']:3} {q['platform']:7} {q['lang']}  {q['question']}{mark}")


if __name__ == "__main__":
    main()
