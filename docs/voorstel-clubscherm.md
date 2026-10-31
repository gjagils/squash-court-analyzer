# Voorstel: clubscherm met alle live wedstrijden (31 oktober 2026)

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
