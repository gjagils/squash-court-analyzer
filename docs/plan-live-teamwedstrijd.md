# Plan: live meekijken per teamwedstrijd

**Actuele status 6 oktober:** gebouwd op main, nog niet als app-update geüpload. `TeamSession` bewaart team/partijen in persistente Durable Object-opslag; stoppen of het alarm na twee uur inactiviteit wist de sessiedata. Alle deelnemers gebruiken dezelfde schrijfsleutel: de app kiest de partij, de server beperkt de sleutel niet tot één partij. IP/tijdstippen voor de limiter hebben een afzonderlijke opslag. Zie [opleveren en hosting](opleveren-en-hosting.md).

Stand 5 oktober 2026, op Gerd-Jans vraag "wat heb je nodig voor live
teamwedstrijden?". **Gebouwd op 6 oktober 2026** (beslissingen: per partij ook
punt voor punt, voornamen van de tegenstander naar de server, standaardnaam
teamnaam plus positie, wissen 2 uur na de laatste update, meteen elke
telefoon via een gedeelde teamsleutel). Getest met iOS-simulator en
Android-emulator tegen live.squashanalyzer.com. De tekst hieronder is het
oorspronkelijke plan. Het sluit aan op
Competitie (`TeamMatch`, vier partijen E1 tot en met E4) en op live meekijken
(`LiveShare`, de Cloudflare-Worker `server/live-worker`).

## Uitgangssituatie vóór de bouw (5 oktober)

- Live meekijken is **per partij**: één Durable Object per livewedstrijd
  (`LiveSession`) met een stand (`LiveSnapshot`), een schrijfsleutel, twee
  kleine foto's en een alarm dat de sessie twee uur na de laatste update wist.
  Kijkpagina `/l/<id>` met serverside-events.
- Een teamwedstrijd bestaat in de app alleen lokaal (`TeamMatch`, een JSON-
  bestand). De server kent hem niet.

## Oorspronkelijk doel

Eén link in de groepsapp voor de hele teamavond: de stand in games, wie er
tegen wie speelt, per partij de games en bij een lopende partij de stand
punt voor punt, en aan het eind de uitslag met competitiepunten.

## Benodigd, per onderdeel

### 1. Server (`server/live-worker`, de NAS-versie blijft reserve)

- Een tweede Durable Object, `TeamSession`, per teamwedstrijd. Het bewaart
  de teamnamen, de datum, de vier slots (voornamen, de laatste stand van de
  partij in de vorm van `LiveSnapshot`, status open, bezig of klaar) en een
  teamsleutel. Zelfde regels als nu: alleen voornamen, alleen in het
  persistente opslag van het object, alarm twee uur na de laatste team- of partijupdate, limieten in
  `LiveLimiter`.
- Endpoints naast de bestaande: `POST /api/team` (geeft id, teamsleutel en
  url), `PUT /api/team/:id/partij/:slot` (stand van één partij, met de
  teamsleutel), `DELETE /api/team/:id`, `GET /api/team/:id` en
  `GET /api/team/:id/events` (serverside-events voor de kijkers).
- Kijkpagina `/t/<id>` in de huisstijl (zoals `public/live.html`): bovenaan
  de teamstand, daaronder vier kaarten. Linkpreview "🔴 Live: Delft 8 – All
  Inn 8 · 5-3".
- Tests in de Workers-testomgeving (zoals `test/api.test.js`): aanmaken,
  partij bijwerken, kijkers krijgen alles, verlopen, limieten, ongeldige
  sleutel.

### 2. App (Core en UI, beide platforms)

- Core: `TeamLive` naast `LiveShare`. Een teamwedstrijd live zetten maakt de
  teamsessie en geeft link en teamsleutel. `LiveShare` kan een tweede doel
  krijgen: hetzelfde `LiveSnapshot` gaat ook naar `PUT .../partij/<slot>`
  als de wedstrijd is gestart voor een partij (`TeamTarget` bestaat al).
- UI: een knop "Live delen" op het teamwedstrijdscherm (deelt de kijkerslink)
  en een manier om de teamsleutel met teamgenoten te delen, zodat ook een
  andere coach of scheidsrechter zijn partij in dezelfde teampagina krijgt
  (een link zoals de spelerskaartlinks, met een eigen scherm voor het
  ontvangen). Handmatig ingevulde partijen sturen hun uitslag bij het
  bewaren.
- Tests: Core met een nep-transport (zoals `LiveShareTests`), en een
  doorloop op simulator en emulator naast elkaar.

### 3. Website en privacy

- `privacy.html` en de handleiding krijgen een alinea over de teampagina.
- Niets nieuws bewaard: voornamen, standen en teamnamen, twee uur na de
  laatste update gewist.

## Oorspronkelijke beslisvragen — beantwoord bij de bouw

1. **Wie voert in?** Alleen de captain op één telefoon (eenvoudig), of elke
   coach en scheidsrechter vanaf de eigen telefoon in dezelfde teampagina
   (past bij vier banen tegelijk; je koos "elke telefoon"). Dat bepaalt de
   teamsleutel en het ontvangen van de uitnodiging.
2. **Hoe live per partij?** Alleen de uitslag per partij zodra die klaar is
   (klein), of ook de stand punt voor punt van lopende partijen (meer verkeer
   en een drukkere kijkpagina, maar dat is wat "live" is).
3. **Tegenstanders:** voornamen van de tegenstanders gaan dan ook naar de
   server (nu al zo bij een gewone livewedstrijd). Akkoord?
4. **Verlopen:** twee uur na de laatste update, of de hele avond (bijvoorbeeld
   vier uur) omdat een teamavond langer duurt?

## Inschatting

- **Eerste deel** (teampagina met per partij de uitslag en de lopende games,
  captain-telefoon): server en kijkpagina plus app, ongeveer een dag werk.
- **Compleet** (elke telefoon, uitnodiging per link, punt voor punt, Android
  en iPhone gelijk, tests, handleiding en privacytekst): twee tot drie dagen.
- Geen nieuwe accounts of tokens nodig: wrangler is ingelogd en de deploy
  loopt vanzelf via GitHub Actions zodra `server/live-worker` verandert.
