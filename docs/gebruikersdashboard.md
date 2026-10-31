# Gebruikersdashboard (elke ochtend bijgewerkt)

Gevraagd door Gerd-Jan op 27 oktober 2026: één pagina met downloads en gebruik
uit de App Store, Google Play, TestFlight en live meekijken. Op 31 oktober
gevraagd: elke dag om 8:00 bijwerken.

- **Dashboard**: <https://claude.ai/artifact/Adsn3Um4wn29PdzhgANi51> (privé; delen
  via het menu Delen op de pagina).
- **Geplande taak** op de Mac, in de Claude-app (lijst geplande taken,
  "Gebruikersdashboard bijwerken", elke dag 8:00). Hij draait alleen als de app
  open is; anders bij de volgende keer openen.
- **Script**: `scripts/usage-dashboard-data.py` maakt de JSON-bestanden. Tussenstanden
  in `~/.squash-dashboard/state` (niet in git), uitvoer in `~/.squash-dashboard/out`.

## Waar elk cijfer vandaan komt

| Onderdeel | Bron | Hoe |
|---|---|---|
| App Store-downloads per dag en maand | Verkooprapporten, vendor 93986735 | App Store Connect-API (sleutel AN4XF9Y8MM) |
| App Store-sessies en actieve apparaten | App Analytics, alleen opt-in | Chrome (ingelogd op App Store Connect) |
| TestFlight per build | `betaBuildUsages` | App Store Connect-API |
| Google Play per dag en de 28-dagencijfers | Play Console → Statistieken en dashboard | Chrome (ingelogd op de Play Console) |
| Live meekijken | `GET /api/stats` van de live-Worker | `STATS_KEY` uit `~/.squash-keys/stats-key.txt` |

Play en de opt-in-sessies hebben geen bruikbare API; daarom draait de taak op de
Mac en niet in de cloud. Is Chrome niet ingelogd, dan blijven die cijfers op de
vorige stand en zegt de taak dat in zijn melding.

De stores lopen een tot twee dagen achter: het App Store-dagrapport komt rond
5:00 de volgende ochtend, Play verwerkt een dag meestal binnen twee dagen.

## Zelf draaien

```bash
python3 scripts/usage-dashboard-data.py --out ~/.squash-dashboard/out
python3 scripts/usage-dashboard-data.py --out ~/.squash-dashboard/out --play play.json --optin optin.json
```

De vorm van `play.json` en `optin.json` staat bovenaan het script.
