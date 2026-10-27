# Weekrapport website en live-dienst (zaterdagochtend per mail)

Gevraagd door Gerd-Jan op 23 oktober 2026: elke zaterdagochtend de statistieken
van de afgelopen week plus een trend, per mail naar info@squashanalyzer.com.

## Hoe het loopt

- **Geplande taak** in de cloudomgeving van Claude Code ("Weekrapport website",
  elke zaterdag 07:40 Nederlandse tijd, een verse sessie per keer). De taak
  haalt `main` op, draait `scripts/weekly-stats.py`, commit het weeksnapshot
  in `docs/stats/weekly/<einddatum>.json` naar `main` en mailt het rapport via
  Cirrux vanaf info@squashanalyzer.com (alias van mail@gerdjan.nl) naar
  info@squashanalyzer.com. Beheer: de lijst geplande taken in Claude Code.
- **De week** is zaterdag tot en met vrijdag (de 7 dagen tot en met gisteren),
  vergeleken met de week ervoor; de trend beslaat 8 weken.
- **Bronnen**: Cloudflare-analytics van de zone squashanalyzer.com (verzoeken,
  paginaweergaven, unieke bezoekers, landen, drukste pagina's; het zijn
  randcijfers van Cloudflare, dus ook bots en plaatjes tellen in "verzoeken")
  en de gebruikscijfers van de live-dienst (`GET /api/stats`, zie
  `docs/voorstel-gebruikscijfers.md`). Niets persoonlijks: Cloudflare levert
  totalen, de live-dienst alleen tellingen per dag.
- **App-gebruik** (vanaf 3.1, `appRows` uit dezelfde `GET /api/stats`, zie
  `docs/voorstel-gebruikstelling-app.md`): apparaten per dag (gemiddeld),
  apparaat-dagen, nieuwe installaties en per deel (coach, scheidsrechter,
  analyse, competitie), plus platform, versie en taal. Het zijn
  apparaat-dagen, geen unieke gebruikers. Zolang de Worker of de app de
  telling nog niet heeft, staat er "Nog geen meldingen van de app".
- **Snapshots**: per week één klein JSON-bestand in `docs/stats/weekly/`, zodat
  de trend blijft kloppen als Cloudflare oudere dagen niet meer geeft.

## Connector en repo

Sinds 27 oktober 2026 heeft de taak de connector Cirrux en de repo
gjagils/squash-court-analyzer als bron. Bij de eerste run (24 oktober)
ontbraken die: het rapport werd gemaakt, maar niet gemaild, en het
snapshot kon niet gepusht worden (403 van de git-proxy).

## Sleutels (eenmalig, Gerd-Jan)

Beide als geheim in de cloudomgeving van Claude Code (menu van de omgeving in
de titelbalk van een sessie → Edit → Network secrets, anders als
omgevingsvariabele). Zonder een sleutel komt het rapport toch, met een regel
onder "Let op" welk deel ontbreekt.

| Naam | Waarde |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare → My Profile → API Tokens → Create Token: alleen *Zone · Analytics · Read* op de zone squashanalyzer.com (geen schrijfrechten). Als netwerkgeheim: type Bearer, toegestane website `api.cloudflare.com`, padprefix leeg, header `Authorization` met voorvoegsel `Bearer`. |
| `CLOUDFLARE_ZONE_ID` | Optioneel; zonder zoekt het script de zone op naam. Staat rechtsonder op de overzichtspagina van de zone. |
| `STATS_KEY` | Dezelfde waarde als het geheim `STATS_KEY` van de Worker squash-live-beta. Op 27 oktober 2026 aangemaakt en gezet; de waarde staat op Gerd-Jans Mac in `~/.squash-keys/stats-key.txt` (alleen voor hem leesbaar, niet in git). Als netwerkgeheim: type Bearer, toegestane website `live.squashanalyzer.com`, padprefix `/api/stats`, header `Authorization` met voorvoegsel `Bearer`; het script stuurt het verzoek dan zonder sleutel en de proxy zet de header erbij. |

## Zelf draaien

```bash
python3 scripts/weekly-stats.py --sample              # voorbeeld, om de opmaak te zien
python3 scripts/weekly-stats.py --end 2026-10-17      # een eerdere week
python3 scripts/weekly-stats.py --no-snapshot         # zonder bestand in docs/stats/weekly
```

Het script gebruikt alleen de standaardbibliotheek van Python 3.
