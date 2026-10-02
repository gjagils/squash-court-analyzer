# squash-live: live meekijken

Kleine server voor **live meekijken** (zie `docs/plan-live-meekijken.md`). De
coach of scheidsrechter tikt in de app op **Live delen** en deelt de link in de
WhatsApp-groep. Wie op de link tikt, ziet de stand live in de browser, zonder
app.

- **Alleen voornamen en de stand**, alleen in het geheugen. Er is geen
  database en er wordt niets naar schijf geschreven.
- **Na de wedstrijd direct weg**: de app stuurt de eindstand en verwijdert
  daarna meteen de sessie. Wie de pagina open had, houdt de eindstand in beeld.
  Wie later op de link tikt, ziet "afgelopen".
- **Vangnet**: een sessie zonder update van 2 uur wordt automatisch verwijderd
  (bijvoorbeeld een lege telefoon). In te stellen met `IDLE_MINUTES`.
- Herstart van de container = alle sessies weg. De app maakt dan bij het
  volgende punt vanzelf een nieuwe sessie. De oude link toont "afgelopen",
  dus deel de nieuwe link opnieuw.

## Draaien in Portainer

1. **Stacks → Add stack → Repository**
   - Repository URL: `https://github.com/gjagils/squash-court-analyzer`
   - Reference: de branch met deze map (later `main`)
   - Compose path: `server/live/docker-compose.yml`
2. Environment variables:
   - `PUBLIC_URL`: het adres dat in WhatsApp komt, bijvoorbeeld
     `https://live.squashanalyzer.com` (zonder `/` aan het eind)
   - optioneel `LIVE_PORT` (standaard 8080), `IDLE_MINUTES` (120), `MAX_SESSIONS` (200)
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
| `DELETE` | `/api/live/:id` | app, met sleutel | sessie meteen weg |
| `GET` | `/api/live/:id` | kijker | huidige stand |
| `GET` | `/api/live/:id/events` | kijker | Server-Sent Events: `state`, `ended` |
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
