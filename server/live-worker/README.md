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
- `TeamSession` (`src/team.js`) bewaart de teamnamen, vier partijen en de gedeelde
  schrijfsleutel in persistente Durable Object-opslag, zonder foto's. Een team-
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
logt de Worker alleen tellingen (`push update {"apns 200":3}`), geen tokens.

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
