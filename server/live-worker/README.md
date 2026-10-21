# squash-live-beta: live meekijken op Cloudflare Workers

De Cloudflare-versie van [`server/live`](../live/README.md): dezelfde API voor losse wedstrijden,
met daarnaast live teamwedstrijden en een teamkijkpagina, maar zonder eigen server. Sinds 5 oktober 2026 **de**
live-server: `live.squashanalyzer.com` (de app) en `beta.squashanalyzer.com`
(alias uit de testfase) zijn allebei custom domains van deze Worker;
`PUBLIC_URL` is `https://live.squashanalyzer.com`. De Node-versie op de NAS
is reserve.

## Hoe het werkt

- **Eén Durable Object per livewedstrijd** (`src/session.js`), genoemd naar
  het sessie-id. Het bewaart de schrijfsleutel, de stand, de twee foto's en
  de open kijkers. De stand staat in de opslag van het object, dus een
  object dat even uit het geheugen gaat (niemand kijkt) komt terug zoals het
  was. Een alarm verwijdert de sessie `IDLE_MINUTES` na de laatste update;
  **Live stoppen** verwijdert meteen.
- **Eén limiter-object** (`src/limiter.js`) telt sessies per IP en in totaal
  per minuut, en houdt bij welke sessies er zijn (voor het maximum en
  `/health`).
- **Kijkers** krijgen Server-Sent Events uit het sessie-object. De
  kijkpagina (`public/live.html`) en het logo zijn statische assets; de
  Worker vult de linkpreview in.
- Het bezoekers-IP komt uit `CF-Connecting-IP`, dat Cloudflare zelf zet.
- Losse sessies bevatten voornamen, stand en optioneel foto's (max 24 KB per speler).
  Stoppen of het alarm na twee uur sinds de laatste stand-update wist de sessieopslag.
  Reeds ontvangen browserinhoud en kopieën verdwijnen daardoor niet automatisch.
- `TeamSession` (`src/team.js`) bewaart de teamnamen, vier partijen, de gedeelde
  schrijfsleutel en (sinds feature/live-activity) per partij optioneel een foto van de
  thuis- en de uitspeler (max 24 KB elk) in persistente Durable Object-opslag. Een team-
  of partijupdate vernieuwt het alarm. De team-API ontbreekt in de NAS-reserve.
  Twee sleutels: de **uitnodigingssleutel** (in de link of code) schrijft partijen, en
  geeft schrijfrecht op alle partijen, niet alleen de eigen; de **eigenaarssleutel** blijft
  op de telefoon die de pagina startte en is nodig om de pagina te stoppen (`DELETE`) of de
  teamnamen te wijzigen (`PUT`). `GET /api/team/:id/verify` (Bearer) zegt of een sleutel werkt
  en wat hij mag (`owner` of `writer`), zodat een verkeerd getypte code bij Deelnemen opvalt.
  De Worker weigert een partij met meer games dan nodig om te winnen.
- De limiter bewaart apart IP-adressen en tijdstippen. De sessietermijn van
  twee uur geldt niet voor die administratie; oude verzoeken worden bij
  volgende aanmaakverzoeken gefilterd, zonder afzonderlijk verwijderalarm.

Verschil met de Node-versie: geen totaalmaximum op kijkers over alle
sessies (wel per sessie), en een herstart van de Worker breekt geen sessies.

## Testen

```bash
cd server/live-worker
npm install
npm test          # vitest met de Workers-testomgeving (workerd)
```

`test/api.test.js` draait tegen de echte limieten; `test/limits.test.js`
met kleine (vitest.config.js), omdat de limiter over tests heen telt.

## Uitrollen

Eén keer:

1. In het Cloudflare-dashboard: **Workers & Pages** één keer openen; dat
   maakt het `workers.dev`-subdomein aan (gratis plan volstaat; Durable
   Objects met SQLite zitten erin). Zonder dat subdomein faalt de deploy met
   fout 10063, ook al gebruikt de Worker alleen het eigen domein.
2. `npx wrangler login` (opent de browser) of een API-token met
   "Edit Cloudflare Workers" als `CLOUDFLARE_API_TOKEN` en het account-id als
   `CLOUDFLARE_ACCOUNT_ID` in de omgeving.

Daarna:

```bash
cd server/live-worker
npx wrangler deploy
```

`wrangler.toml` koppelt de Worker aan `live.squashanalyzer.com` en
`beta.squashanalyzer.com` als custom domains: Cloudflare maakt de DNS-records
en certificaten zelf aan (de zone staat in hetzelfde account). Bestaat er al
een ander record voor die naam (zoals het tunnel-record van de NAS), dan
weigert de deploy met fout 100117: eerst dat record verwijderen. Controleer met
`curl https://live.squashanalyzer.com/health`; de eerste ~20 s na een deploy
kan dat nog een 500 geven, daarna `{"ok":true,"sessions":0}`. Uitgerold op
5 oktober 2026.

De GitHub-workflow `deploy-live-beta.yml` rolt uit bij elke push naar `main`
die `server/live-worker/` raakt, met de twee secrets hierboven in de repo.

## API

Gelijk aan de Node-versie (zie `server/live/README.md`): `POST /api/live`,
`PUT /api/live/:id`, `PUT /api/live/:id/photos`, `DELETE /api/live/:id`,
`GET /api/live/:id`, `GET /api/live/:id/events`, `GET /api/live/:id/photo/1|2`,
`GET /l/:id`, `GET /health`.

Live score op het vergrendelscherm (feature/live-activity, nog niet in
productie): `POST /api/live/:id/followers` en `DELETE /api/live/:id/followers`
met `{ "platform": "ios"|"android", "token": "...", "sandbox"?: true }` (geen
sleutel nodig; 201, 204, 400, 404, 429 boven `MAX_FOLLOWERS_PER_SESSION`, 503
als pushen voor dat platform uit staat) en `GET /api/push` (`{ ios, android }`).
Na elke stand pusht de sessie (`src/push.js`, op de achtergrond) naar APNs
(Live Activity) en FCM (databericht); een afgelopen wedstrijd, Live stoppen of
het alarm geeft één keer een eindbericht. Tokens die APNs of FCM als dood
melden worden vergeten; de volgers verdwijnen met de sessie. Per verzending
logt de Worker alleen tellingen (`push live update {"apns 200":3}`), geen tokens.
Een melding (APNs `alert`, FCM `alertTitle`/`alertBody`) gaat alleen mee bij een
gewonnen game en bij de uitslag, en niet naar volgers met `"alerts": false`.

Taal (versie 3.0, optioneel en achterwaarts compatibel): de app mag `"lang":
"nl"|"en"` meesturen bij `POST /api/live` (naast de stand), `POST /api/team`
(naast de teamkop) en `POST .../followers` (naast het token); ook `?lang=en` in
de URL van de twee POST's werkt. Alles behalve `en` (ook ontbreken, oudere
builds) is Nederlands. Een volger krijgt de meldingen in zijn eigen `lang`
("Game 2 to Piet", "Result: Jan wins 3–1", "E2: Paul wins 3–1", "· matches
3–1"); de stand zelf (content-state, FCM `snapshot`/`team`) is voor iedereen
gelijk en wordt nooit vertaald. De `lang` van de starter wordt bij de sessie
bewaard en bepaalt alleen de teksten van het linkvoorbeeld (`og:description`,
"· matches 1-0" in de titel van een teamwedstrijd): een crawler als die van
WhatsApp stuurt geen bruikbare `Accept-Language`, en de ontvanger spreekt
meestal de taal van wie deelt. De pagina's `/l/:id` en `/t/:id` kiezen zelf
Engels in de browser als `navigator.language` niet met `nl` begint. Foutteksten
van de API blijven Nederlands.

Teamwedstrijd op het vergrendelscherm (zelfde branch, nog niet in productie):

- `POST` / `DELETE /api/team/:id/followers`: dezelfde body en antwoorden als bij
  een losse wedstrijd (201, 204, 400, 404, 429, 503).
- `PUT /api/team/:id/partij/:slot/photos` met `{ "p1": thuis, "p2": uit }`
  (base64-JPEG van max 24 KB, of `null`; een ongeldige foto telt als geen foto),
  Bearer uitnodigings- of eigenaarssleutel: 204, 400, 401, 404 (ook bij slot
  buiten 1–4). Een geleegde partij (`{ "empty": true }`) verliest haar foto's.
  `GET /api/team/:id/photo/:slot/1|2` geeft de JPEG (zonder cache) of 404.
  `GET /api/team/:id` (en elke SSE-`state`) heeft nu `photos` met **altijd alle vier**
  slots (`{ "1": [thuis, uit], ... "4": [false, false] }`) en `photoVersion` (gaat
  omhoog bij elke fotowijziging, ook bij het legen van een slot met foto's).
- Na elke `PUT` van een partij of van de teamnamen krijgen de volgers een
  `update` met de compacte teamstand (APNs `content-state`, FCM-veld `team` als
  JSON-tekst, `kind: "team"`): `{ home, away, partijen: [{ slot, p1, p2, bestOf,
  gamesWon, score, status, winner?, end? }] }`, alleen bestaande partijen, op slot;
  geen games, laatste punt of volgorde.
- Klaar is een partij met een winnaar, status `finished` of `end` (`retired` of
  `walkover`); de teampagina telt sindsdien ook zo. Zijn alle vier klaar, dan één
  keer `end` (blijft 4 uur staan) met de uitslag als melding; wordt een partij
  daarna teruggezet naar niet klaar, dan komen er weer updates. Live stoppen of het
  alarm geeft één keer `end` (weg na een minuut) als dat nog niet verstuurd was.
- Meldingen: een partij die klaar wordt (`E2: Paul wint 3–1`, of `(opgave)` /
  `(walkover)`, zonder naam `Delft 8 E2`; tekst `All Inn 8 5 – 3 Delft 8` in
  games), en de uitslag (`Uitslag: All Inn 8 wint 9–4` of `Uitslag: gelijkspel 6–6`,
  op games zoals de teampagina; tekst `All Inn 8 – Delft 8 · partijen 3–1`). Geen
  melding per rally of per game.
- De teampagina heeft de knop "Volg op je vergrendelscherm" naar
  `squashanalyzer://volg#team/<id>` (met `@<host>` buiten live.squashanalyzer.com),
  verborgen als alle partijen klaar zijn of de wedstrijd voorbij is.

Instellingen in `wrangler.toml` onder `[vars]`: `PUBLIC_URL`, `IDLE_MINUTES`
(120), `MAX_SESSIONS` (200), `CREATES_PER_MINUTE` (10),
`GLOBAL_CREATES_PER_MINUTE` (60), `MAX_VIEWERS_PER_SESSION` (200),
`LIVE_JURISDICTION` (`eu` = de objecten staan alleen in de EU; leeg = geen
beperking, ook in de lokale tests omdat workerd geen jurisdicties kent). Een
wijziging maakt lopende sessies onvindbaar (ze duren hooguit twee uur): zet
hem om als `/health` `"sessions": 0` zegt. Staat sinds 6 oktober 2026 op `eu`.

Pushen (vergrendelscherm): `MAX_FOLLOWERS_PER_SESSION` (500) en
`APNS_BUNDLE_ID` (`com.squashanalyzer.app`) als vars, en als geheimen
(`npx wrangler secret put NAAM`) `APNS_KEY` (de .p8-tekst), `APNS_KEY_ID`,
`APNS_TEAM_ID` en `FCM_SERVICE_ACCOUNT` (de JSON van het Firebase-
serviceaccount). Ontbreken ze, dan staat dat platform uit en werkt de rest
zoals altijd. De productie-Worker heeft ze nog niet (15 oktober 2026).

## Test-Worker squash-live-dev

Voor feature/live-activity draait een aparte Worker, los van productie:
`https://squash-live-dev.gerdjanvangils.workers.dev` (`wrangler.dev.toml`:
eigen naam, `workers_dev`, geen routes, `PUBLIC_URL` leeg zodat links het
workers.dev-adres krijgen). De app accepteert dit adres via
`squashanalyzer://volg#<id>@<host>`; de kijkpagina maakt die link zelf.

```bash
cd server/live-worker
npx wrangler deploy -c wrangler.dev.toml
npx wrangler secret put APNS_KEY -c wrangler.dev.toml < ~/.apple-keys/AuthKey_<KEYID>.p8
npx wrangler tail -c wrangler.dev.toml     # de push-tellingen per stand
```

Geheimen op deze Worker (alleen de namen): `APNS_KEY`, `APNS_KEY_ID`,
`APNS_TEAM_ID`, `FCM_SERVICE_ACCOUNT` (Firebase-project `squash-analyzer-18fb3`).
Op 15 oktober 2026 getest met nep-tokens: APNs (productie en sandbox)
antwoordde `400 BadDeviceToken` en FCM `404 UNREGISTERED`, dus verbinding en
aanmelding werken vanuit de Worker en dode tokens worden vergeten.
Op 16 oktober 2026 ook de teamwedstrijd (commit "teamwedstrijd volgen op het
vergrendelscherm"): volgers 201, foto per partij 204 en terug te lezen, `push team
update` en bij vier beslisde partijen `push team end` in `wrangler tail`; de
nep-tokens (APNs `400 BadDeviceToken`, FCM `400 INVALID_ARGUMENT`) werden vergeten.
