> **Oorspronkelijk plan (Docker op de NAS).** Sinds 5 oktober 2026 draait
> live meekijken als Cloudflare Worker (`server/live-worker`); de Node-server
> `server/live` is alleen reserve. Zie `docs/opleveren-en-hosting.md`.

# Bouwplan: Live meekijken

Status: **gebouwd** (3 oktober 2026, branch `claude/tender-rubin-yw2rzz`), nog lokaal te testen: zie `docs/archief/lokaal-testen-oktober.md`.

Afwijkingen van het plan bij het bouwen: het model en de verzendlogica staan in Core (`LiveShare.swift`, gedeeld met Android), het versturen per platform (`URLSessionLiveTransport` / `HttpLiveTransport`), net als bij AI Coach. "Laatste punt tonen" staat vast uit (nog geen instelling). Het adres is `LiveShare.defaultBaseURL`.

## Idee

De coach of scheidsrechter start een wedstrijd en deelt een link in de WhatsApp-groep. Wie op de link tikt, volgt de stand live in de browser. De app is daarvoor niet nodig.

## Besluiten

| # | Besluit |
|---|---|
| 1 | Eigen server in **Docker** (via Portainer), geen iCloud of externe dienst |
| 2 | Alleen **voornamen** worden gedeeld |
| 3 | Na de wedstrijd wordt de livesessie **direct verwijderd** |
| 4 | Niets wordt op schijf opgeslagen: de server houdt sessies alleen in het geheugen |
| 5 | Live start pas na een bewuste tik op **"Live delen"** |

## Hoe het werkt

```
 iPhone (coach/scheids)                Docker: squash-live                 Browser (WhatsApp-groep)
 ─────────────────────                 ───────────────────                 ────────────────────────
 "Live delen"  ── POST /api/live ────▶ maakt sessie (geheugen)
               ◀── id + schrijfsleutel ─
 deelt link  live.squashanalyzer.com/l/<id>  ───────────────────────────▶  opent pagina
 elk punt      ── PUT  /api/live/<id> ─▶ bewaart laatste stand  ── SSE ──▶ stand ververst direct
 wedstrijd uit ── PUT (status: klaar) ─▶ stuurt eindstand       ── SSE ──▶ toont eindstand
               ── DELETE /api/live/<id>▶ sessie weg                        pagina houdt eindstand vast
```

- De app stuurt steeds de **hele stand** (geen losse punten). Een punt ongedaan maken, een let of een gemiste verbinding corrigeert zich dus vanzelf bij het volgende bericht.
- Kijkers krijgen updates via **Server-Sent Events (SSE)**. Dat is direct (geen vertraging van seconden), werkt in elke browser en gaat goed door een reverse proxy.

## Wat kijkers zien

- Voornamen: **Jan – Piet**
- Gamestand (2-1), huidige stand (8-6), wie serveert (● bij de naam)
- Gespeelde games: 11-8 · 9-11 · 11-6
- Status: *Inspelen…* → *Game 2 bezig* → *Pauze* → *Afgelopen: Jan wint 3-1*
- "Laatst bijgewerkt 12 s geleden". Na een paar minuten zonder update: "Geen verbinding met de baan".
- Optioneel, als instelling in de app (standaard **uit**): laatste punt, zoals "Winner · Volley drop". Niet elke coach wil analyse delen met de tegenpartij.

Wie de link opent nadat de wedstrijd is afgelopen en verwijderd, ziet: *"Deze livewedstrijd is afgelopen."* Wie de pagina al open had, blijft de eindstand zien, want die komt binnen vóór het verwijderen.

**Voorbeeld in WhatsApp:** de server kent de voornamen en kan daarom zelf een nette linkpreview maken (Open Graph): *"🔴 Live: Jan – Piet · Squash Analyzer"* met logo.

---

## Deel 1 — Server (`server/live/`, nieuw in deze repo)

### Techniek
- **Node.js** (LTS), zonder externe pakketten (`node:http`). Klein, snel en weinig onderhoud.
- Eén container die zowel de API als de kijkpagina serveert.
- `Dockerfile` + `docker-compose.yml`, te deployen als **Portainer-stack vanuit Git**.
- HTTPS en het domein via je bestaande reverse proxy (zie open vragen).

### API

| Methode | Pad | Wie | Wat |
|---|---|---|---|
| `POST` | `/api/live` | app | Nieuwe sessie. Geeft `id` (12 tekens, willekeurig) en `writeKey` (geheime sleutel, 32 bytes) |
| `PUT` | `/api/live/:id` | app (met `Authorization: Bearer <writeKey>`) | Hele stand vervangen |
| `DELETE` | `/api/live/:id` | app (met sleutel) | Sessie direct verwijderen |
| `GET` | `/api/live/:id` | kijker | Huidige stand (JSON) |
| `GET` | `/api/live/:id/events` | kijker | SSE-stroom met elke nieuwe stand, en `ended` bij verwijderen |
| `GET` | `/l/:id` | kijker | Kijkpagina (HTML + Open Graph-tags) |
| `GET` | `/health` | Portainer/proxy | Gezondheidscheck |

### Gegevens (alleen in geheugen)
```json
{
  "p1": "Jan", "p2": "Piet",
  "bestOf": 5,
  "games": [[11, 8], [9, 11]],
  "score": [5, 3],
  "server": 1, "side": "R",
  "status": "warmup | playing | break | finished",
  "lastPoint": "Winner · Volley drop",
  "updatedAt": "2026-10-03T19:42:10Z"
}
```

### Veiligheid en opruimen
- **Alleen schrijven met de sleutel** die de app bij het aanmaken kreeg. Kijkers kunnen alleen lezen.
- **Niets op schijf**, geen database. De stand wordt niet gelogd (alleen methode, pad zonder id, statuscode).
- **Automatisch opruimen als vangnet:** een sessie zonder update van 2 uur wordt verwijderd, voor het geval de app de `DELETE` niet meer kan sturen (lege batterij, geen netwerk).
- **Limieten:** maximaal 2 KB per bericht, maximaal 200 actieve sessies, eenvoudige limiet per IP-adres op het aanmaken van sessies.
- **Validatie:** namen maximaal 20 tekens, alleen letters, spaties en koppeltekens. HTML wordt altijd ge-escaped op de kijkpagina.
- **Herstart van de container:** alle sessies zijn weg. De app merkt dat (`404` op `PUT`) en maakt stilletjes een nieuwe sessie aan, maar de oude link werkt dan niet meer. Kijkers zien *"Verbinding verbroken"*. Dat is acceptabel voor een zeldzame herstart.

### Kijkpagina (`server/live/public/`)
- Eén HTML-pagina met CSS en een beetje JavaScript, in de stijl van de website (kleuren en logo uit `website/style.css`).
- Grote cijfers, leesbaar op een telefoon. Licht en donker thema.
- Maakt vanzelf opnieuw verbinding na een onderbreking (standaard SSE-gedrag).

### Tests
- API-tests met `node:test`: aanmaken, schrijven zonder of met verkeerde sleutel (`401`), verwijderen, verlopen na 2 uur (met nep-klok), limieten.

## Deel 2 — App (iOS)

### Kern (`Packages/SquashAnalyzerCore`)
- Nieuw: `LiveSnapshot` (de JSON hierboven) en `LiveSnapshot.firstName(_:)`, die van "Jan de Vries" alleen "Jan" maakt. Het model zit in Core, zodat Android het later ook kan gebruiken.

### Service
- Nieuw: `LiveShareService` (`SquashAnalyzer/Services/`):
  - `start(snapshot)` → `POST`, bewaart `id` + `writeKey` bij de wedstrijd (alleen in het geheugen, niet in SwiftData);
  - `update(snapshot)` → `PUT`. Achter elkaar volgende updates worden samengevoegd, zodat alleen de laatste stand gaat. Bij geen verbinding wordt het later opnieuw geprobeerd, alleen met de nieuwste stand;
  - `stop()` → `DELETE`.
- Het adres van de server staat in één constante, `LiveConfig.baseURL`.

### Koppeling met de wedstrijd
- Werkt in **coachmodus** (`Match`/`Game`) en **scheidsrechtermodus** (`RefereeMatch`). Beide krijgen een `liveSnapshot`.
- Na elk punt, ongedaan maken, let, einde van een game en de startknop (zie hieronder) roept de app `update` aan.
- **Wedstrijd afgelopen:** de app stuurt de eindstand (`status: finished`) en direct daarna `DELETE`.
- **Wedstrijd afgebroken of weggegooid:** direct `DELETE`.

### Bediening
- Knop **"Live delen"** (icoon 📡) in de wedstrijdbalk, in beide modi. Een tik maakt de sessie aan en opent het deelmenu met de link en de tekst *"Volg Jan – Piet live: <link>"*.
- Zolang live aan staat: een rood bolletje "LIVE" bovenin. Een tik daarop geeft **"Link opnieuw delen"** of **"Live stoppen"**.
- Instelling: *"Laatste punt tonen aan kijkers"* (standaard uit).

### Raakvlak met de startknop per game
Uit de testfeedback komt ook een startknop per game, zodat de inspeeltijd niet in de eerste rally telt. Tot de eerste tik op Start staat de livestatus op *Inspelen…*. Tussen games (na het laatste punt, vóór Start) staat hij op *Pauze*.

### Privacy
- Alleen voornamen, alleen in het geheugen van de server, en verwijderd na de wedstrijd (of na 2 uur zonder update).
- `website/privacy.html`: een alinea "Live meekijken" toevoegen.

### Tests
- `LiveSnapshot` vanuit een `Match` en een `RefereeMatch` (scores, games, serveerder, status).
- `firstName`: "Jan de Vries" → "Jan", "Anne-Marie" → "Anne-Marie", lege naam → "Speler 1".
- `LiveShareService` met een nep-`URLSession`: samenvoegen van updates, opnieuw proberen, nieuwe sessie na `404`, `DELETE` bij het einde.

## Deel 3 — Android (later)

- Android kan direct meekijken via de browser.
- Live delen vanaf Android is later eenvoudig, omdat het dezelfde HTTP-API is en `LiveSnapshot` al in Core staat.

## Volgorde

| Stap | Inhoud | Inschatting |
|---|---|---|
| 1 | Server: API, opruimen, limieten + tests | klein–middel |
| 2 | Kijkpagina + linkpreview | klein–middel |
| 3 | Docker + Portainer-stack, domein en HTTPS via de proxy | klein |
| 4 | App: `LiveSnapshot` (Core) + `LiveShareService` + tests | middel |
| 5 | App: knop "Live delen", LIVE-indicator, stoppen | klein–middel |
| 6 | Privacyverklaring, release notes | klein |

Stap 1 tot en met 3 zijn los te testen met `curl` en een browser, nog voordat de app iets verstuurt.

## Open vragen

1. **Domein:** `live.squashanalyzer.com`, of een (sub)domein dat je al op je Docker-server hebt?
2. **Reverse proxy:** wat draait er voor je containers (Traefik, Nginx Proxy Manager, Caddy)? Dan lever ik de juiste labels of configuratie mee in `docker-compose.yml`.
3. **Mag de pagina open blijven na de wedstrijd?** Kijkers die hem al open hadden, houden nu de eindstand in beeld. Wie later op de link tikt, ziet alleen "afgelopen".
