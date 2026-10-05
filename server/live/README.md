# squash-live: live meekijken (Node-versie, reserve)

**Sinds 5 oktober 2026 draait live meekijken op Cloudflare Workers**
([`server/live-worker`](../live-worker/README.md), zelfde API en kijkpagina);
`live.squashanalyzer.com` wijst daarheen. Deze Node-versie draait nog op de
NAS (Portainer-stack 109) als reserve, maar is van buiten niet meer
bereikbaar zolang het tunnel-record `live` ontbreekt.

Kleine server voor **live meekijken** (zie `docs/plan-live-meekijken.md`). De
coach of scheidsrechter tikt in de app op **Live delen** en deelt de link in de
WhatsApp-groep. Wie op de link tikt, ziet de stand live in de browser, zonder
app.

- **Alleen voornamen en de stand**, alleen in het geheugen. Er is geen
  database en er wordt niets naar schijf geschreven.
- **2 uur na de wedstrijd weg**: de app stuurt de eindstand en laat de sessie
  dan los. Kijkers zien de eindstand nog tot de server de sessie 2 uur na de
  laatste update verwijdert (`IDLE_MINUTES`). Daarna toont de link
  "afgelopen". Tikt de coach op **Live stoppen**, dan is de sessie meteen weg.
- **Vangnet**: een sessie zonder update van 2 uur wordt automatisch verwijderd
  (bijvoorbeeld een lege telefoon). In te stellen met `IDLE_MINUTES`.
- Herstart van de container = alle sessies weg. De app maakt dan bij het
  volgende punt vanzelf een nieuwe sessie. De oude link toont "afgelopen",
  dus deel de nieuwe link opnieuw.

## Draaien in Portainer

**Zo staat het nu (3 oktober 2026):** stack `squash-live` (id 109) op de NAS,
branch `main`, `LIVE_PORT=3002`, `PUBLIC_URL=https://live.squashanalyzer.com`, met de
Cloudflare Tunnel als voorkant (public hostname `live` →
`http://192.168.68.120:3002`). Een aparte reverse proxy is dan niet nodig: de
tunnel doet HTTPS en geeft `X-Forwarded-For` door. De compose gebruikt
`network_mode: bridge`, omdat Docker op de NAS geen adresruimte meer heeft voor
een eigen netwerk per stack.

Algemeen:

1. **Stacks → Add stack → Repository**
   - Repository URL: `https://github.com/gjagils/squash-court-analyzer`
   - Reference: de branch met deze map (later `main`)
   - Compose path: `server/live/docker-compose.yml`
2. Environment variables:
   - `PUBLIC_URL`: het adres dat in WhatsApp komt, bijvoorbeeld
     `https://live.squashanalyzer.com` (zonder `/` aan het eind)
   - optioneel `LIVE_PORT` (standaard 8080), `IDLE_MINUTES` (120), `MAX_SESSIONS` (200),
     `CREATES_PER_MINUTE` per IP (10), `GLOBAL_CREATES_PER_MINUTE` (60),
     `MAX_VIEWERS_PER_SESSION` (200), `MAX_VIEWERS` (2000)
   - `TRUST_PROXY=1` (standaard in de compose): het IP van de bezoeker komt uit
     `CF-Connecting-IP`/`X-Forwarded-For`. Alleen aan achter een proxy die je
     zelf beheert; zonder die vlag telt het socket-adres, zodat niemand de
     limiet omzeilt met een verzonnen header.
3. **Reverse proxy**: laat het domein van `PUBLIC_URL` met HTTPS doorverwijzen
   naar poort `LIVE_PORT` van deze host.
   - Zet buffering uit voor `/api/live/*/events` (Server-Sent Events). Bij
     Nginx (Proxy Manager) doet de server dat zelf met `X-Accel-Buffering: no`.
     Een time-out van een paar minuten is genoeg: de server stuurt elke 25 s
     een ping en de browser maakt vanzelf opnieuw verbinding.
   - Geef `X-Forwarded-For` en `X-Forwarded-Proto` door (standaard bij de
     meeste proxies).
4. Controleer: `https://<domein>/health` geeft `{"ok":true,...}`.

Het adres staat in de app in `LiveShare.defaultBaseURL`
(`Packages/SquashAnalyzerCore/Sources/SquashAnalyzerCore/LiveShare.swift`).
Pas het daar aan als je een ander domein kiest.

## API

| Methode | Pad | Wie | Wat |
|---|---|---|---|
| `POST` | `/api/live` | app | nieuwe sessie: `{id, writeKey, url}` |
| `PUT` | `/api/live/:id` | app, `Authorization: Bearer <writeKey>` | hele stand vervangen |
| `PUT` | `/api/live/:id/photos` | app, met sleutel | spelersfoto's, één keer na het aanmaken: `{p1, p2}` als base64-JPEG (max 24 KB elk) of `null` |
| `DELETE` | `/api/live/:id` | app, met sleutel | sessie meteen weg (Live stoppen) |
| `GET` | `/api/live/:id` | kijker | huidige stand |
| `GET` | `/api/live/:id/events` | kijker | Server-Sent Events: `state` (met `photos: [bool, bool]` en `photoVersion`), `ended` |
| `GET` | `/api/live/:id/photo/1` of `/2` | kijker | foto van speler 1 of 2 (`image/jpeg`, `Cache-Control: no-store`) |
| `GET` | `/l/:id` | kijker | kijkpagina, met linkpreview "🔴 Live: Jan – Piet" |
| `GET` | `/health` | proxy/Portainer | gezondheidscheck |

De stand (`LiveSnapshot` in de app):

```json
{ "p1": "Jan", "p2": "Piet", "bestOf": 5, "games": [[11, 8]], "score": [3, 2],
  "gamesWon": [1, 0], "server": 1, "side": "R", "status": "playing",
  "lastPoint": "Jan: Winner · Volley drop", "winner": null }
```

`status` is `warmup`, `playing`, `between` of `finished`. Alleen deze velden
worden bewaard. Namen worden ook op de server nog tot een voornaam ingekort.
Foto's (alleen als "Foto's van de spelers meesturen" aan staat) moeten echte
JPEG's zijn (begin `FF D8 FF`) van hoogstens 24 KB; iets anders telt als geen
foto. Ze staan alleen in het geheugen en gaan weg met de sessie.

## Lokaal testen

```bash
cd server/live
npm test                      # node --test, geen pakketten nodig
PORT=8080 node server.js      # dan http://localhost:8080/health
```

Ook zonder eigen domein te proberen op het lokale netwerk: zet in de app
tijdelijk `LiveShare.defaultBaseURL` op `http://<ip-van-de-mac>:8080`.
- iOS staat gewone `http` naar het lokale netwerk toe (`NSAllowsLocalNetworking`
  in `Info.plist`).
- Android staat `http` alleen in de **debug-build** toe
  (`Android/app/src/debug/res/xml/network_security_config.xml`). De
  release-build blijft alleen HTTPS.
