# Voorstel: clubscherm met alle live wedstrijden (31 oktober 2026)

> **Gebouwd op 3 november 2026**, zie "Wat er gebouwd is" onderaan. Keuzes van Gerd-Jan:
> een geheime link per club, en de club uit de SBN-clubzoeker.

Idee van Gerd-Jan: een pagina per club die alle live wedstrijden van die
club op één scherm laat zien. All Inn Squash zet die pagina tijdens de
competitieavond op de tv in de kantine, en iedereen ziet de stand van elke
partij die op dat moment geteld wordt.

Later wordt dit een betaald onderdeel: de club heeft een account en een
abonnement nodig. **Eerst moet het werken.** Daarna volgen het teasen (bijv.
een demo op Instagram en de website) en het abonnement. Het hoort bij B1
"Weergeven per squashvereniging" in de [backlog van 21 oktober](backlog-2026-10-21.md#businessmodel).

## Wat er al is

- **Live teamwedstrijd** (`TeamSession` in `server/live-worker/src/team.js`,
  kijkpagina `/t/<id>`): per teamwedstrijd de vier partijen, de stand punt
  voor punt, serverside-events, gewist twee uur na de laatste update. Zie
  [plan live teamwedstrijd](plan-live-teamwedstrijd.md).
- **Live per partij** (`LiveSession`, `/l/<id>`): een losse wedstrijd, zonder
  team of club.
- **Clubnaam uit de teamnaam**: `clubName()` in `stats.js` maakt van
  "All Inn Squash 8" de club "All Inn Squash". Die wordt al gebruikt voor de
  gebruikscijfers.

Wat ontbreekt: de server weet niet welke sessies er op dit moment lopen.
Elke sessie is een los Durable Object, en het enige ingangspunt is de link.

## Opzet (eerste werkende versie)

1. **`ClubWall` Durable Object per club** (sleutel: genormaliseerde
   clubnaam). Het houdt een lijst bij van de actieve teamsessies van die
   club, met het team-id, de teamnamen en de laatste stand.
2. **Teamsessies melden zich aan.** Een `TeamSession` waarvan de thuis- of
   uitploeg bij een club hoort, stuurt bij elke update een korte stand naar
   die `ClubWall`, en een afmelding bij stoppen of verlopen. Een uitwedstrijd
   van All Inn telt dus ook mee, en de tegenstander ziet hem op het eigen
   clubscherm.
3. **Kijkpagina `/c/<club>`** in de stijl van `team.html`, gemaakt voor een
   tv: liggend, grote cijfers, geen knoppen. Bovenaan staan de clubnaam en de
   klok. Daaronder staat per teamwedstrijd één blok met de teamstand en de
   vier partijen; een lopende partij laat de stand punt voor punt zien. Bij
   veel wedstrijden (meer dan het scherm toont) wisselt de pagina vanzelf
   tussen pagina's. Als er niets live is, staat er "Nog geen live
   wedstrijden" met een QR-code naar de app.
4. **Updates via serverside-events**, zoals bij `/t/<id>`. De tv ververst
   vanzelf en komt na een wegvallende verbinding vanzelf terug.

Losse wedstrijden (`/l/<id>`) hebben geen club en doen in de eerste versie
niet mee. Later kunnen ze meedoen, via een clubkeuze bij Live delen of de club
uit Mijn team.

## Open vragen voor Gerd-Jan

- **Openbaar of afgeschermd?** Nu ziet alleen wie de link heeft een live
  wedstrijd. Een clubscherm toont de voornamen van iedereen die die avond live
  speelt, ook van de tegenstander. Er zijn twee mogelijkheden:
  - een geheime link per club (bijv. `/c/<club>?k=…`), die in de eerste versie
    met de hand wordt uitgedeeld;
  - een schakelaar in de app, "Toon op het clubscherm", die standaard aan
    staat en per teamwedstrijd uit kan.

  Met het abonnement wordt de geheime link vanzelf het account van de club.
  Verder moet het privacybeleid één alinea erbij krijgen.
- **Welke clubnaam?** De naam uit SBN-teamnamen is niet altijd gelijk
  geschreven. De clubzoeker kent de officiële SBN-clubs. Koppelen aan dat
  club-id is netter dan de tekst van de teamnaam gebruiken.
- **Proefclub**: All Inn Squash als eerste, op een competitieavond met een
  paar teams die live delen.

## Grootte

- Server (`ClubWall`, aanmelden vanuit `TeamSession`, `/c/<club>`, tests): **M**
- Tv-pagina zelf: **M**
- App: niets nodig voor de eerste versie, zolang teams hun teamwedstrijd live
  delen. Wel nodig: een knop "Clubscherm openen" of het delen van de link, plus
  eventueel de schakelaar. Grootte: **S**
- Account en abonnement: **L**, pas na de proef.

De eerste versie kan dus zonder app-update live, omdat de Worker vanuit
`main` automatisch wordt uitgerold.

## Wat er gebouwd is (3 november 2026)

- **Pagina**: `/c/<SBN-club-id>?k=<sleutel>` (`public/club.html`), voor een tv: per teamwedstrijd de
  teamnamen, de stand in partijen en E1-E4 met games en de lopende game. Maximaal vier teamwedstrijden
  per pagina; zijn het er meer, dan wisselen de pagina's elke 12 seconden. Zonder live wedstrijden staat er
  "Nog geen live wedstrijden". Geen knoppen, altijd donker. De QR-code naar de app uit het voorstel zit er nog niet in.
- **Toegang**: zonder de juiste sleutel is het antwoord 404, net als bij een club zonder scherm. De linkpreview
  noemt de club niet.
- **Clubregister**: de Worker-secret `CLUB_WALLS` (niet in de publieke repo), JSON:
  `[{"id":"2","name":"All Inn Squash","key":"…"}]`, met id en officiële naam uit de clubzoeker en een sleutel
  van minstens 24 tekens. Zonder die secret bestaat er geen enkel scherm. All Inn Squash is id 2 (opgezocht op
  3 november 2026 in de zoeker van SBN Competitie 2026-2027); het id hoort bij dit seizoen en is bij een nieuw
  seizoen opnieuw na te kijken.
- **Koppeling**: een live teamwedstrijd kent alleen teamnamen, geen club-id. Hij hoort bij een club als een
  teamnaam met de officiële naam begint, als hele woorden ("All Inn Squash 8", "All Inn Squash Dames 1"). Daardoor
  is er geen app-update nodig en werkt het ook met 3.1. Teamnamen uit het programma van Mijn team zijn de namen van
  SBN; een met de hand anders getypte naam komt niet op het scherm.
- **Opslag**: `ClubWall` (Durable Object per club, `src/club.js`, migratie v4) houdt een kopie van de teamnamen, de
  dag en de partijen (voornamen en stand, geen foto's). Weg bij Live stoppen, en anders 2 uur na de laatste update
  (`IDLE_MINUTES`), in dezelfde jurisdictie als de teamwedstrijden.
- **Niet gedaan**: losse wedstrijden, een schakelaar in de app, de QR-code, en een account of abonnement.

Een club toevoegen: sleutel maken met `openssl rand -base64 24 | tr '+/' '-_'`, de lijst aanvullen en vanuit
`server/live-worker` `npx wrangler secret put CLUB_WALLS`. Let op: dat zet de hele lijst opnieuw.

**Stand 3 november 2026:** aan voor All Inn Squash (id 2), als gratis proef. De secret staat op `squash-live-beta`, de lijst
met de sleutel lokaal op de Mac van Gerd-Jan in `~/.squash-keys/club-walls.json` (nooit in de repo). In productie
getest met een testteamwedstrijd: op het scherm na aanmaken, stand komt door, weg na stoppen. Nog niet op een echte tv
of op een competitieavond gezien. Privacybeleid (nl/en) is bijgewerkt en gepubliceerd.
