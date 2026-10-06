# Website en live-server naar een externe host

> **Samenvatting (6 oktober 2026):** klaar. Website en live-server draaien op
> Cloudflare (Workers); de NAS-stacks 85 en 109 staan alleen nog als reserve.
> Wat dat betekent voor uitrollen en opleveren staat in
> `docs/opleveren-en-hosting.md`. De rest van dit bestand is de
> geschiedenis van de verkenning en de omzetting.

Verkenning van 5 oktober 2026. Vraag: kunnen de website en de live-server van
de NAS (Portainer, Cloudflare Tunnel) naar een externe host, en welke?

## Wat er nu draait

| Onderdeel | Nu | Wat het nodig heeft |
| --- | --- | --- |
| Website `squashanalyzer.com` en `www` | nginx in Portainer-stack 85 op de NAS, via Cloudflare Tunnel | Statisch: 130 bestanden, 6,6 MB. `/.well-known/apple-app-site-association` en `assetlinks.json` als `application/json` op beide hosts. `/teams/<code>/team.zip` staat buiten git (`.gitignore`), wordt met de hand geüpload. |
| Live meekijken `live.squashanalyzer.com` | Node 22-container (`server/live`), Portainer-stack 109, Cloudflare Tunnel ervoor | Eén proces dat altijd aanstaat: sessies, foto's en kijkers zitten in het geheugen, niets op schijf. Server-Sent Events, dus lange verbindingen (ping elke 25 s). `TRUST_PROXY=1` leest het bezoekers-IP uit `CF-Connecting-IP`. Geen database, geen volumes. |
| Domein en DNS | Cloudflare | Blijft. |

De app praat verder nergens mee: AI Coach gaat rechtstreeks naar OpenAI met
de sleutel van de gebruiker, Mijn team rechtstreeks naar sbn.toernooi.nl.
Kaartlinks en teamlinks zijn gewone bestanden of URL-fragmenten op de website.

## Advies

**Website naar Cloudflare Pages, live-server naar Cloudflare Workers.**
Alles bij Cloudflare, gratis, geen NAS en geen tunnel meer nodig.

**Besluit Gerd-Jan, 5 oktober (avond): alles standaard naar Cloudflare; de
NAS blijft voorlopig als reserve draaien.** Stand na die avond:

- **Live meekijken is omgezet.** `live.squashanalyzer.com` is een custom
  domain van de Worker `squash-live-beta` (naast `beta.squashanalyzer.com`,
  dat als alias blijft); `PUBLIC_URL` is `https://live.squashanalyzer.com`.
  Het tunnel-record `live` → `2b05ba07-fadb-4248-a867-6df79718ae59.cfargotunnel.com`
  is uit DNS gehaald en de tunnel-hostname is weg; alleen Portainer-stack 109
  draait nog (terugzetten: zie bij de website hieronder). De schakelaar Alfa/Beta is uit de app gehaald voordat hij
  in een build zat; `LiveShare.serverKey` blijft bestaan maar wordt niet
  gelezen. `server/live` (Node) is de reserve.
- **Website is omgezet (5 oktober, 18:35).** Gerd-Jan haalde de
  tunnel-records voor `squashanalyzer.com` en `www` uit DNS; daarna
  `npx wrangler deploy -c server/website-worker/wrangler.jsonc` vanaf de Mac
  (de map `website/screenshots/` en `website/teams/` gaan dan mee; de repo is
  publiek, dus de teamzips blijven buiten git en de website-workflow in
  GitHub blijft uit). Gecontroleerd op het eigen domein: homepage, `www`,
  `/badges/`, `/handleiding/`, `/kaart/`, de screenshots, de teamzip
  (`application/zip`, `noindex`), beide deep-link-bestanden als
  `application/json`. Nog te doen op een telefoon:
  `adb shell pm get-app-links com.squashanalyzer.android` moet `verified`
  blijven en een kaartlink vanaf de iPhone moet de app openen. Gerd-Jan
  haalde dezelfde avond ook de drie tunnel-hostnames (`live`, apex, `www`)
  uit de tunnel; alleen Portainer-stacks 85 (website) en 109 (live) draaien
  nog als reserve. Terugvallen = custom domain van de Worker af, in Zero
  Trust de public hostname opnieuw toevoegen (tunnel
  `2b05ba07-fadb-4248-a867-6df79718ae59`, website → `http://192.168.68.120:3001`,
  live → `http://192.168.68.120:3002`), wat ook het DNS-record aanmaakt.

**Stand 5 oktober (avond):** de Workers-versie van de live-server is gebouwd
in `server/live-worker` (Durable Objects, zelfde API en kijkpagina, 12 tests
groen in de Workers-testomgeving) en gaat naar `beta.squashanalyzer.com`. De
app krijgt in Instellingen een schakelaar **Alfa** (NAS, `live.squashanalyzer.com`)
of **Beta** (Cloudflare); een lopende wedstrijd blijft op de server waar hij
begon. Zie `server/live-worker/README.md` voor het uitrollen. Fly.io is
daarmee het reserveplan als de Workers-versie tegenvalt; de uitwerking
hieronder blijft staan.

**Uitgerold 5 oktober (17:40):** `npx wrangler deploy` vanaf de Mac na
`wrangler login`; Cloudflare maakte DNS en certificaat voor
`beta.squashanalyzer.com` zelf aan. Eerste poging gaf fout 10063 ("You need a
workers.dev subdomain"): één keer Workers & Pages openen in het dashboard, dan
opnieuw deployen. `/health` gaf de eerste ~20 s een 500 (eerste aanroep van
het limiter-object), daarna `{"ok":true,"sessions":0}`. Praktijktest met de
app: coachwedstrijd op de iPhone met Beta gekozen, link en spelersfoto's op de
kijkpagina, tientallen stand-updates zonder één fout in de Worker-logs
(alleen methode, pad en status te zien). Gerd-Jans oordeel: "werkt super
soepel". Android-telefoon nog niet getest op Beta (later). Automatisch
uitrollen staat aan sinds de merge van 5 oktober 18:13: de secrets
`CLOUDFLARE_API_TOKEN` en `CLOUDFLARE_ACCOUNT_ID` staan in de repo en de
eerste run van `deploy-live-beta.yml` op `main` was groen (tests 26 s,
deploy 25 s).

### Website: Cloudflare Pages (gratis)

**Stand 5 oktober (avond):** `website/_headers` en de workflow
`deploy-website.yml` staan klaar; de proef op een `pages.dev`-adres en de
omzetting van de domeinen staan in `docs/live-beta-afronden-instructie.md`,
stap 9. Tot die omzetting serveert de NAS de site.

**Proef gedaan 5 oktober (18:00):** `wrangler pages project create` maakt
tegenwoordig geen `pages.dev`-project meer maar een Worker met statische
assets ("Pages is nu onderdeel van Workers"); een klassiek Pages-project is
niet meer aan te maken. Daarom staat de site als Worker `squashanalyzer-site`
met config `server/website-worker/wrangler.jsonc`, uitgerold met
`npx wrangler deploy -c server/website-worker/wrangler.jsonc`, op
`https://squashanalyzer-site.gerdjanvangils.workers.dev`. Gecontroleerd:
homepage, `/badges/`, `/handleiding/`, `/testen.html`, `/privacy.html`, een
kaartlink en de teamzip; alle 172 interne links en assets geven 200; de
homepage en de badgepagina zijn byte-gelijk aan de NAS (op de e-mail-
obfuscatie van Cloudflare op het eigen domein na). Headers: beide
deep-link-bestanden `application/json`, `/teams/*` `noindex`. Twee
verschillen met nginx: `/privacy.html` en `/testen.html` krijgen een 307 naar
`/privacy` en `/testen` (de pagina laadt daarna gewoon), en **`website/screenshots/`
staat net als `website/teams/` buiten git**, dus beide ontbreken bij een
upload vanuit GitHub Actions; vanaf de Mac gaan ze wel mee. Omzetten van het
domein is Gerd-Jans besluit (custom domain op de Worker in plaats van op
een Pages-project).

Waarom: het domein staat al bij Cloudflare, de site is statisch, en Pages
publiceert automatisch bij elke push naar `main`. Het gratis plan is ruim
genoeg (500 builds per maand, 100 custom domains per project, `_headers` tot
100 regels).

Wat er nodig is:

1. Pages-project koppelen aan de GitHub-repo, productiebranch `main`, geen
   buildcommando, uitvoermap `website`.
2. `website/_headers` toevoegen:
   ```
   /.well-known/apple-app-site-association
     Content-Type: application/json
   /.well-known/assetlinks.json
     Content-Type: application/json
   /teams/*
     X-Robots-Tag: noindex
   ```
3. Custom domains `squashanalyzer.com` en `www.squashanalyzer.com` aan het
   project hangen (beide, want de deep-link-bestanden moeten op beide hosts
   staan). Pages zet de DNS-records zelf; de tunnel-hostnames voor de website
   daarna verwijderen.
4. Controle: `curl -sI https://squashanalyzer.com/.well-known/apple-app-site-association`
   toont `application/json`; `adb shell pm get-app-links com.squashanalyzer.android`
   blijft `verified`.
5. **Teamzips:** `website/teams/<code>/team.zip` staat niet in git en komt dus
   niet mee in een git-deploy. Kies één van twee:
   - de map uit `.gitignore` halen en de zips gewoon committen (de codes zijn
     al lange willekeurige namen en `robots.txt` houdt ze uit zoekmachines), of
   - de zips in een Cloudflare R2-bucket zetten achter `squashanalyzer.com/teams/`
     (gratis tot 10 GB). Eerste optie is het eenvoudigst.

Overstappen kan zonder onderbreking: eerst het Pages-project op
`<naam>.pages.dev` controleren, dan de domeinen omzetten.

### Live-server: Fly.io (ongeveer €2 tot €4 per maand)

Waarom: de container draait er zonder aanpassing (de `Dockerfile` wordt
gebruikt zoals hij is), een machine blijft permanent aan (nodig: de sessies
staan in het geheugen en kijkers houden een open verbinding), er is een
regio Amsterdam, en de prijs is de laagste van de kandidaten: een
`shared-cpu-1x` met 256 MB kost $1,94 per maand, met 512 MB $3,88.

Wat er nodig is:

1. `flyctl` installeren, `fly launch --no-deploy` in `server/live`, en in
   `fly.toml`:
   ```toml
   app = "squash-live"
   primary_region = "ams"
   [env]
     PUBLIC_URL = "https://live.squashanalyzer.com"
     TRUST_PROXY = "1"
   [http_service]
     internal_port = 8080
     force_https = true
     auto_stop_machines = "off"     # sessies in het geheugen: nooit stoppen
     auto_start_machines = true
     min_machines_running = 1
     [http_service.checks.health]
       path = "/health"
       interval = "30s"
   [[vm]]
     size = "shared-cpu-1x"
     memory = "512mb"
   ```
   Eén machine, geen tweede: twee machines zouden elk hun eigen sessies
   hebben.
2. `fly deploy`, daarna `fly certs add live.squashanalyzer.com` en in
   Cloudflare een CNAME `live` → `squash-live.fly.dev`. Zet dat record eerst
   op "DNS only" tot het certificaat van Fly er is; daarna mag de oranje wolk
   aan (Cloudflare laat SSE door en de ping van 25 s houdt de verbinding
   open). Met de wolk aan komt het bezoekers-IP uit `CF-Connecting-IP`, zonder
   wolk uit de `X-Forwarded-For` van Fly; de server kent beide.
3. Deploy bij elke push: een job in `.github/workflows/ci.yml` die na de
   servertests `flyctl deploy --remote-only` draait met een `FLY_API_TOKEN`
   als GitHub-secret, alleen als `server/live/**` is veranderd.
4. Overstappen buiten een speelavond: bij de wissel verdwijnen lopende
   sessies (de app maakt bij het volgende punt vanzelf een nieuwe link).
   Daarna stack 109 en de tunnel-hostname `live` op de NAS verwijderen.
5. In de app verandert niets (`LiveShare.defaultBaseURL` blijft
   `https://live.squashanalyzer.com`).

## Alternatieven en waarom niet

| Partij | Prijs | Oordeel |
| --- | --- | --- |
| Hetzner Cloud VPS (CX23) | €3,99 + €0,50 IPv4 per maand | Zelfde opzet als nu (Docker, Portainer, cloudflared), maar dan zelf een Linux-server bijhouden (updates, SSH, back-ups). Goede keus als je liever een eigen machine hebt. |
| Railway | vanaf $5 per maand | Werkt, maar duurder dan Fly voor dit kleine proces en geen Nederlandse regio. |
| Render | Starter $7 per maand | Het gratis plan slaapt na 15 minuten, dat kan niet voor live. Starter is het duurst van de lijst. |
| Cloudflare Workers + Durable Objects | gratis plan (100.000 verzoeken per dag) | Gebouwd op 5 oktober als `server/live-worker` (zie boven): één Durable Object per sessie, SSE via een stream, alarm voor het opruimen. |
| Cloudflare Pages voor de live-server | — | Kan niet: Pages Functions zijn stateless en houden geen sessies in het geheugen. |

## Volgorde en moment

Afgerond op 5 oktober 2026 (zie het besluit hierboven); de NAS-stacks mogen
weg zodra Gerd-Jan de reserve niet meer nodig vindt.

1. Website naar Pages (een uur werk, geen risico, op elk moment).
2. Live-server naar Fly op een dag zonder competitiewedstrijden; test eerst
   met een eigen wedstrijd op een telefoon via de nieuwe host.
3. NAS opruimen: stacks 85 en 109 en de tunnel-hostnames weg; de tunnel zelf
   kan blijven voor andere dingen.

Niet tijdens de laatste dagen van de Play-testperiode doen: als de
live-server even weg is terwijl een tester iets probeert, kost dat
vertrouwen vlak voor de productieaanvraag.
