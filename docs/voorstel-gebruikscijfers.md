# Voorstel: gebruikscijfers van live meekijken, zonder herleidbaarheid

Vraag van Gerd-Jan (23 oktober 2026): bijhouden hoeveel livewedstrijden en live
teamwedstrijden er gestart worden, en waar het gebruik zit (alleen het eigen team
bij All Inn, of ook andere verenigingen). Niet als administratie, niet herleidbaar
tot personen, alleen om te zien of en waar de app gebruikt wordt.

**Besluit en stand (23 oktober 2026)**: Gerd-Jan koos voor bouwen, mét de club, en
met wedstrijden van de testspelers (Bob, Wim, Bombardino, Whiskey) apart geteld.
De Worker-kant staat op `main` (`server/live-worker/src/stats.js`, tests in
`test/stats.test.js`, uitleg in de README van de Worker); de app-kant (het veld
`platform` meesturen) staat op de branch `claude/gebruikscijfers-app` en moet op
de Mac getest en gemerged worden. Het geheim
`STATS_KEY` staat sinds 27 oktober 2026 op de Worker (waarde op Gerd-Jans Mac in
`~/.squash-keys/stats-key.txt`); geteld wordt sinds de deploy van 23 oktober. De tekst hieronder is het oorspronkelijke voorstel; waar de bouw
afwijkt staat het in de README van de Worker (soorten `viewer-live`/`viewer-team`
en `follower-live`/`follower-team`, kolom `test`).

## Wat de live-server nu al ziet

De Worker (`server/live-worker`) krijgt bij `POST /api/live` de voornamen, de stand
en `lang`; bij `POST /api/team` de twee teamnamen, de datum en `lang`. Cloudflare
geeft daarbij het IP-adres (alleen voor de limiet per minuut) en, in `request.cf`,
het land, de regio en de stad van dat IP. De limiter telt alleen de *lopende*
sessies (`/health`); na twee uur is alles weg. Er wordt dus niets geteld over de tijd
heen. Workers Logs (`[observability]`) bewaren aanroepen een paar dagen, niet
bruikbaar als telling.

## Wat we tellen en wat niet

Tellen (één rij per dag, per soort, een getal erbij):

| Gebeurtenis | Wanneer | Extra kenmerk |
|---|---|---|
| `live` | `POST /api/live` slaagt | taal (nl/en), land, platform |
| `team` | `POST /api/team` slaagt | taal, land, platform, **club** (zie onder) |
| `viewer` | een kijker opent de events-stream | land |
| `follower` | `POST …/followers` (vergrendelscherm) | platform (ios/android, zit al in de registratie) |

Niet opslaan: IP-adressen, sessie-ids, namen, tijdstippen fijner dan een dag, en
geen koppeling tussen rijen. Een rij is "op 23 oktober zijn er 3 livewedstrijden
gestart uit Nederland, waarvan 2 op iPhone". Dat is geen persoonsgegeven; met één
gebruiker op een dag is het wel "Gerd-Jan heeft gefloten", maar dat weet alleen
Gerd-Jan zelf en de teller zegt niet wie.

**Platform**: de app stuurt nu geen platform mee bij het starten. Toevoegen als
optioneel veld `platform` ("ios"/"android") naast `lang` in `LiveSnapshot` en
`TeamLiveHeader` (achterwaarts compatibel: een oude app laat het weg, de server telt
dan "onbekend"). Niet uit de User-Agent afleiden; die is op Android vaag.

**Land en regio**: `request.cf.country` is grof genoeg ("NL", "BE"). De regio
(`request.cf.region`, provincie) zegt al iets over "andere verenigingen" zonder
naar een club te kijken. De stad niet opslaan: met weinig gebruikers is stad plus
dag bijna een team.

**Club**: de enige clubinformatie die de server ziet is de teamnaam van een live
teamwedstrijd ("All Inn 3", "Victoria 2"). Voorstel: de thuisteamnaam zonder het
teamnummer achteraan opslaan als `club` ("All Inn"), per dag geteld. Een club is
geen persoon; SBN publiceert het programma toch al. Wel: geen tegenstander
opslaan (dan is de rij één specifieke wedstrijd), en losse livewedstrijden hebben
geen club (daar kun je hooguit de regio zien). Wil Gerd-Jan ook dat niet, laat
`club` dan weg: de regio blijft over.

## Hoe te bouwen (kleinste variant)

1. Eén nieuw Durable Object `StatsCounter` (SQLite, zoals de limiter), één object
   voor de hele dienst, met een tabel `counts(day, kind, platform, lang, country,
   region, club, n)` en een `bump(kind, fields)` die `n` ophoogt. Geen
   verwijdertermijn nodig: het zijn getallen. Niet in de EU-jurisdictie gezet
   worden hoeft niet (geen persoonsgegevens), maar het kan.
2. In `index.js` na een geslaagde create/followers/events-aanroep één
   `ctx.waitUntil(stats.bump(...))`: faalt het tellen, dan merkt de gebruiker niets.
3. `GET /api/stats?from=2026-10-01&to=2026-10-31` met een Bearer-sleutel
   (`wrangler secret put STATS_KEY`), antwoord als JSON. Lezen met `curl` en `jq`,
   of later een pagina `website/stats.html` die alleen met de sleutel werkt. Zonder
   sleutel 404, zodat het pad niet opvalt.
4. Tests in `server/live-worker/test/stats.test.js` (vitest, workerd): één start
   geeft één rij, twee op een dag geeft `n = 2`, zonder sleutel geen toegang, en
   geen ids of namen in de opslag (assert op de tabelinhoud).
5. App: `platform` meesturen (Core `LiveSnapshot`/`TeamLiveHeader`, één regel per
   platform; de server negeert een onbekende waarde). Kan ook later: tot die
   tijd telt de server "onbekend".
6. Privacytekst (`website/privacy.html`, "Technische verzoekgegevens"): "De
   live-dienst telt per dag hoe vaak live meekijken en live teamwedstrijden gestart
   worden, met land, provincie, taal en platform, en bij een teamwedstrijd de
   clubnaam uit de teamnaam. Zonder namen, IP-adressen of sessie-ids; deze tellingen
   zijn niet tot een persoon te herleiden en worden niet gedeeld." Zelfde regel in
   de Engelse privacypagina en in het Play data-safety-formulier (geen wijziging
   nodig als het onder "app-activiteit, niet gekoppeld" valt; nakijken).

Grootte: M (een dag), de app-aanpassing S. De NAS-reserve (`server/live`) krijgt dit
niet.

## Alternatieven, en waarom niet

- **Cloudflare Analytics Engine**: schrijven vanuit de Worker, SQL via de API,
  gratis. Minder eigen code, maar een extra product, de bewaartermijn ligt bij
  Cloudflare, en opvragen gaat alleen via API-token of dashboard. Pas interessant
  bij veel meer verkeer.
- **Google Analytics / Firebase Analytics in de app**: uit, en bewust uit (zie de
  privacytekst: "andere Firebase-onderdelen, zoals analyse, staan uit"). Niet aanzetten.
- **App Store Connect en Play Console**: geven installaties en actieve apparaten
  per land, maar niets over live of Competitie, en Apple alleen van gebruikers die
  delen met ontwikkelaars aan hebben. Wel gratis en al beschikbaar: eerst daar
  kijken voor "wordt het gebruikt".
- **Een gebruikers- of apparaat-id meesturen** om unieke gebruikers te tellen: niet
  doen, dat is precies de herleidbaarheid die Gerd-Jan niet wil.
