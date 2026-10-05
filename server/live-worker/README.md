# squash-live-beta: live meekijken op Cloudflare Workers

De Cloudflare-versie van [`server/live`](../live/README.md): dezelfde API,
dezelfde kijkpagina, maar zonder eigen server. Sinds 5 oktober 2026 **de**
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
- Alleen voornamen, de stand en de foto's (max 24 KB per speler), nergens
  anders dan in het sessie-object; weg met de sessie.

Verschil met de Node-versie: geen totaalmaximum op kijkers over alle
sessies (wel per sessie), en een herstart van de Worker breekt geen sessies.

## Testen

```bash
cd server/live-worker
npm install
npm test          # vitest met de Workers-testomgeving (workerd), twee projecten
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
`curl https://beta.squashanalyzer.com/health`; de eerste ~20 s na een deploy
kan dat nog een 500 geven, daarna `{"ok":true,"sessions":0}`. Uitgerold op
5 oktober 2026.

De GitHub-workflow `deploy-live-beta.yml` rolt uit bij elke push naar `main`
die `server/live-worker/` raakt, met de twee secrets hierboven in de repo.

## API

Gelijk aan de Node-versie (zie `server/live/README.md`): `POST /api/live`,
`PUT /api/live/:id`, `PUT /api/live/:id/photos`, `DELETE /api/live/:id`,
`GET /api/live/:id`, `GET /api/live/:id/events`, `GET /api/live/:id/photo/1|2`,
`GET /l/:id`, `GET /health`.

Instellingen in `wrangler.toml` onder `[vars]`: `PUBLIC_URL`, `IDLE_MINUTES`
(120), `MAX_SESSIONS` (200), `CREATES_PER_MINUTE` (10),
`GLOBAL_CREATES_PER_MINUTE` (60), `MAX_VIEWERS_PER_SESSION` (200).
