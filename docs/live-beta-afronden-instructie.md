> **Afgerond en achterhaald (6 oktober 2026).** Alles hieronder is uitgevoerd.
> Het besluit is anders uitgepakt dan deze instructie: de schakelaar Alfa/Beta
> is uit de app gehaald, `live.squashanalyzer.com` en de website draaien op
> Cloudflare en de NAS is alleen reserve. Lees `docs/opleveren-en-hosting.md`
> voor de huidige stand; dit bestand blijft als geschiedenis.

# Instructie voor Claude Code op de Mac: live meekijken op Cloudflare afronden

Kopieer alles onder de lijn in Claude Code in de lokale checkout
(`/Users/gerd-janvangils/Github/squash-court-analyzer`). De cloudsessie van 5
oktober heeft de Cloudflare-versie van de live-server gebouwd
(`server/live-worker`) en de schakelaar Alfa/Beta in de app, op branch
`claude/great-pasteur-eyskxy` (commit `ebf2ac1`). Deze instructie laat dat
lokaal verifiëren, uitrollen op `beta.squashanalyzer.com` en met een echte
wedstrijd testen. Twee stappen moet Gerd-Jan zelf doen in de browser; die
staan gemarkeerd met **[Gerd-Jan]**.

---

Rond de Cloudflare-versie van live meekijken af: verifiëren, uitrollen op
beta.squashanalyzer.com, de app met de schakelaar bouwen en een echte
wedstrijd testen. Werk stap voor stap, meld na elke stap kort wat je zag, en
stop bij elke stap met **[Gerd-Jan]** tot hij zegt dat het gedaan is. Zet
niets om op `live.squashanalyzer.com`: Alfa (de NAS) blijft de server voor
de testers tot Gerd-Jan anders beslist.

## 0. Lees eerst

- `server/live-worker/README.md`: hoe de Worker werkt en hoe je uitrolt.
- `server/live/README.md`: de Node-versie, dezelfde API.
- `docs/hosting-verhuizing.md`: het advies en de stand van zaken.
- `docs/android-port.md`, "Nieuwe Skip-eigenaardigheden": valkuilen voor
  het nieuwe type `LiveServer` in Core.

## 1. Branch ophalen

```bash
git fetch origin
git checkout claude/great-pasteur-eyskxy
git merge --ff-only origin/claude/great-pasteur-eyskxy
```

De branch staat op `main` plus de commits van 5 oktober (backlog,
buildplanning, hostingadvies, live-worker). Werk op deze branch; merge naar
`main` in stap 8.

## 2. Worker lokaal testen

```bash
cd server/live-worker
npm install
npm test
npx wrangler deploy --dry-run --outdir /tmp/squash-live-beta
cd ../..
```

Verwacht: 12 tests groen in twee projecten (`api` en `limits`), en de dry
run noemt de bindings `SESSION`, `LIMITER`, `ASSETS` en de zes variabelen.
Draai ook de Node-tests van de oude server (`cd server/live && npm test`) om
zeker te zijn dat die onaangeraakt zijn.

## 3. App-kant: tests en transpilatie

```bash
scripts/lint.sh
swift test --package-path Packages/SquashAnalyzerCore
skip test --package-path Packages/SquashAnalyzerCore
swift test --package-path Packages/SquashAnalyzerUI
cd Android && ./gradlew :app:testDebugUnitTest && cd ..
xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation
```

Nieuw in Core: `LiveServer` (enum met `storageKey`, `baseURL`, `host`,
`stored`) in `LiveShare.swift`, en `LiveShare.baseURL` is nu een berekende
property met een override voor tests; `sessionBaseURL` houdt de server van
een lopende sessie vast. In `LiveShareTests` staan twee nieuwe tests
(`testTheServerSettingPicksTheAddress`, `testARunningMatchKeepsItsServer`);
op Linux waren alle 20 groen. Let bij Skip op: `UserDefaults.standard.string(forKey:)`
in een statische computed property, en de `Picker` met `.segmented` in
`SharedSettingsView` (`SharedLeagueTeamViews.swift`). Schrijf het type
voluit of splits de expressie als Kotlin klaagt; verander de
`rawValue`s `alfa`/`beta` niet, die staan in de instellingen van testers
zodra build 19 uit is.

Controleer op de simulator en de emulator: Instellingen → Live meekijken
toont onder de twee schakelaars een segment Alfa | Beta met daaronder
"Live-server: live.squashanalyzer.com"; bij Beta verandert de regel in
`beta.squashanalyzer.com`; met "Knop LIVE" uit is het segment grijs.

## 4. [Gerd-Jan] Workers aanzetten en inloggen

In het Cloudflare-dashboard: **Workers & Pages** openen en, als dat de eerste
keer is, een `workers.dev`-subdomein kiezen (bijvoorbeeld `squashanalyzer`).
Gratis plan volstaat. Daarna in de terminal:

```bash
cd server/live-worker && npx wrangler login && cd ../..
```

Dat opent de browser; keur de toegang goed. Zeg daarna "ingelogd".

## 5. Uitrollen en controleren

```bash
cd server/live-worker
npx wrangler deploy
cd ../..
curl -s https://beta.squashanalyzer.com/health
```

Verwacht `{"ok":true,"sessions":0}`. Wrangler maakt het DNS-record en het
certificaat voor `beta.squashanalyzer.com` zelf aan (custom domain in
`wrangler.toml`); dat kan een paar minuten duren. Controleer in het
dashboard dat de Worker `squash-live-beta` bestaat met de twee Durable
Object-klassen. Test de API zonder app:

```bash
curl -s -X POST https://beta.squashanalyzer.com/api/live -H 'Content-Type: application/json' \
  -d '{"p1":"Jan","p2":"Piet","bestOf":5,"games":[],"score":[0,0],"gamesWon":[0,0],"server":1,"side":"R","status":"warmup"}'
```

Open de `url` uit het antwoord in de browser: de kijkpagina met "Jan – Piet"
en de linkpreview-titel. Stuur met de `writeKey` een `PUT` met een andere
stand en zie de pagina meebewegen; `DELETE` toont "afgelopen". Verwijder
daarna de testsessie.

## 6. Echte test met de app

1. Zet op Gerd-Jans iPhone en Android-telefoon een debug-build met deze
   branch en kies in Instellingen **Beta**.
2. Speel een korte coachwedstrijd met LIVE aan; open de link op een andere
   telefoon (en in WhatsApp voor de linkpreview). Zet de foto's aan en
   controleer dat ze op de kijkpagina staan.
3. Zet de telefoon even in vliegtuigstand en weer aan: de stand komt bij
   de volgende rally weer door (`offline`-pad van `LiveShare`).
4. Schakel tijdens de wedstrijd naar Alfa: de lopende wedstrijd blijft op
   Beta; de volgende wedstrijd gaat naar Alfa.
5. Scheidsrechterwedstrijd idem, kort.
6. Kijk in het dashboard onder de Worker naar de logs (observability staat
   aan): alleen methode, pad en status, geen namen of standen.
7. Laat een sessie staan en controleer na ruim twee uur dat de link
   "afgelopen" toont en `/health` weer 0 sessies meldt.

Werkt iets niet, los het op in `server/live-worker` (tests erbij), deploy
opnieuw en herhaal het betreffende punt.

## 7. [Gerd-Jan] Automatisch uitrollen (optioneel, aanbevolen)

In Cloudflare een API-token maken met het sjabloon "Edit Cloudflare
Workers", en in de GitHub-repo twee secrets zetten: `CLOUDFLARE_API_TOKEN`
en `CLOUDFLARE_ACCOUNT_ID` (het account-id staat rechts op de overzichtspagina
van Workers & Pages). De workflow `.github/workflows/deploy-live-beta.yml`
test en rolt dan uit bij elke push naar `main` die `server/live-worker`
raakt. Zeg "secrets staan" als het klaar is; controleer daarna met een
lege push of een handmatige run (workflow_dispatch) dat de deploy slaagt.

## 8. Afsluiten

- `docs/hosting-verhuizing.md`: onder "Stand 5 oktober" een regel met de
  datum van de deploy en wat de praktijktest liet zien.
- `docs/wijzigingen-builds.md`, blok "Volgende build", kopje Live meekijken:
  aanvullen met het testresultaat; de schakelaar gaat mee in build 19.
- `docs/android-port.md`: korte paragraaf "Live-server Alfa/Beta" met de
  testaantallen en eventuele nieuwe Skip-eigenaardigheden.
- `server/live-worker/README.md`: de sectie "Uitrollen" bijwerken als iets
  anders bleek te werken dan beschreven.
- Commit per stap, push, en merge in `main`:

```bash
git checkout main && git merge --no-ff claude/great-pasteur-eyskxy && git push origin main
```

Meld aan het eind: testaantallen per suite, het resultaat van de echte
wedstrijd op Beta, en wat open blijft.

## 9. Website op Cloudflare Pages testen (los van de live-server)

De website staat nog op de NAS. Zet hem als proef op Pages, op een
`pages.dev`-adres; het domein blijft bij de NAS tot Gerd-Jan omzet.

1. Eenmalig een Pages-project maken en de map uploaden (de ingelogde
   wrangler van stap 4 volstaat; `website/_headers` zet de JSON-types voor
   de deep-link-bestanden en houdt `/teams/` uit zoekmachines):
   ```bash
   npx --yes wrangler@4 pages project create squashanalyzer-site --production-branch main
   npx --yes wrangler@4 pages deploy website --project-name squashanalyzer-site --branch main
   ```
   De uitvoer noemt het adres, zoals `https://squashanalyzer-site.pages.dev`.
   De lokale map `website/teams/` (buiten git) gaat zo gewoon mee.
2. Controleer op dat adres: de homepage, `/badges/` (37 kaarten, 17 met drie
   plaatjes), `/handleiding/` voor iPhone en Android, `/testen.html`,
   `/privacy.html`, een echte kaartlink (`/kaart/#…` uit de app, met het
   `pages.dev`-adres in plaats van squashanalyzer.com) en een teamzip
   (`/teams/<code>/team.zip`, moet downloaden en niet in Google staan).
3. Headers:
   ```bash
   curl -sI https://squashanalyzer-site.pages.dev/.well-known/apple-app-site-association | grep -i content-type
   curl -sI https://squashanalyzer-site.pages.dev/.well-known/assetlinks.json | grep -i content-type
   curl -sI https://squashanalyzer-site.pages.dev/teams/ | grep -i x-robots
   ```
   Alle drie `application/json` respectievelijk `noindex`.
4. Vergelijk met de NAS: dezelfde pagina's op `https://squashanalyzer.com`
   moeten er hetzelfde uitzien (zelfde commit).

**[Gerd-Jan] beslist** of de website over gaat. Zo ja, dan in een
vervolgstap: in het dashboard bij het Pages-project onder **Custom domains**
`squashanalyzer.com` en `www.squashanalyzer.com` toevoegen (Pages zet de
DNS-records; de tunnel-hostnames voor de website daarna weghalen), de
repository-variabele `WEBSITE_ON_PAGES` op `true` zetten zodat
`.github/workflows/deploy-website.yml` bij elke push naar `main` uploadt (de
token uit stap 7 heeft dan ook "Cloudflare Pages: Edit" nodig), en
`website/teams/` uit `.gitignore` halen en de zips committen, anders missen
ze in de automatische upload. Daarna `adb shell pm get-app-links
com.squashanalyzer.android` en een kaartlink vanaf een iPhone controleren.

## Later, als Beta bevalt (niet in deze sessie)

- `LiveServer.alfa.baseURL` naar Cloudflare laten wijzen (of `live` als
  tweede custom domain op de Worker zetten), de schakelaar uit Instellingen
  halen en `serverKey` laten staan zodat oude instellingen niet storen.
- Portainer-stack 109 en de tunnel-hostname `live` op de NAS weg; stack 85
  (website) zodra de domeinen op Pages staan.
