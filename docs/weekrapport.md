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
- **Snapshots**: per week één klein JSON-bestand in `docs/stats/weekly/`, zodat
  de trend blijft kloppen als Cloudflare oudere dagen niet meer geeft.

## Connector (eenmalig, Gerd-Jan)

De geplande taak is op 23 oktober vanuit een sessie aangemaakt en kon daarbij
geen connector meekrijgen. Zonder de Cirrux-connector kan de sessie het
rapport wel maken en het snapshot committen, maar niet mailen. Koppel daarom
in Claude (de lijst geplande taken, taak "Weekrapport website") de connector
Cirrux aan de taak, of maak de taak daar opnieuw aan met dezelfde opdracht en
Cirrux erbij. De eerste run is zaterdag 24 oktober 2026 om 07:40.

## Sleutels (eenmalig, Gerd-Jan)

Beide als geheim in de cloudomgeving van Claude Code (menu van de omgeving in
de titelbalk van een sessie → Edit → Network secrets, anders als
omgevingsvariabele). Zonder een sleutel komt het rapport toch, met een regel
onder "Let op" welk deel ontbreekt.

| Naam | Waarde |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare → My Profile → API Tokens → Create Token: alleen *Zone · Analytics · Read* op de zone squashanalyzer.com (geen schrijfrechten). |
| `CLOUDFLARE_ZONE_ID` | Optioneel; zonder zoekt het script de zone op naam. Staat rechtsonder op de overzichtspagina van de zone. |
| `STATS_KEY` | Dezelfde waarde als `npx wrangler secret put STATS_KEY` in `server/live-worker` (een lange willekeurige tekens­reeks, bijvoorbeeld `openssl rand -hex 24`). |

## Zelf draaien

```bash
python3 scripts/weekly-stats.py --sample              # voorbeeld, om de opmaak te zien
python3 scripts/weekly-stats.py --end 2026-10-17      # een eerdere week
python3 scripts/weekly-stats.py --no-snapshot         # zonder bestand in docs/stats/weekly
```

Het script gebruikt alleen de standaardbibliotheek van Python 3.
