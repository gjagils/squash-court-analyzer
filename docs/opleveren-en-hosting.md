# Opleveren en hosting (stand 6 oktober 2026)

Dit is het document voor iedereen (mens, Claude Code, Codex) die iets moet
bouwen, testen, uitrollen of opleveren. Het is bijgewerkt na de verhuizing van
de NAS naar Cloudflare (5 oktober 2026) en na het bouwen van live
teamwedstrijden (6 oktober). Wat er in de app gebeurt staat in
`ARCHITECTURE.md`; de lopende wijzigingen per build in
`docs/wijzigingen-builds.md`.

## 1. Wie draait wat

| Onderdeel | Waar het draait | Code | Uitrollen |
| --- | --- | --- | --- |
| Live meekijken (wedstrijd en teamwedstrijd) `live.squashanalyzer.com` (alias `beta.squashanalyzer.com`) | Cloudflare Worker `squash-live-beta` met Durable Objects `LiveSession`, `LiveLimiter` en `TeamSession` (SQLite) | `server/live-worker` | Automatisch bij een push naar `main` die `server/live-worker/**` raakt (`.github/workflows/deploy-live-beta.yml`), of met de hand: `cd server/live-worker && npx wrangler deploy` |
| Website `squashanalyzer.com` en `www` | Cloudflare Worker met statische assets `squashanalyzer-site` | `website/` + `server/website-worker/wrangler.jsonc` | **Met de hand vanaf de Mac**, vanuit de repo-root: `npx wrangler deploy -c server/website-worker/wrangler.jsonc` |
| Apps | TestFlight (iOS), Google Play testtracks (Android) | `SquashAnalyzer/`, `Android/`, `Packages/` | Scripts in `scripts/`, zie 4 |
| NAS (Portainer-stacks 85 = website, 109 = live Node-server) | Draait nog, **alleen als reserve**; van buiten niet meer bereikbaar (tunnel-hostnames en DNS-records zijn weg) | `deploy/website-nginx.conf`, `server/live` | Niet meer bijhouden; de NAS-kopie van de website is verouderd |

Gevolgen van de verhuizing:

- **De website wordt niet meer via Portainer gepubliceerd.** Actuele
  instructies gebruiken de `wrangler deploy` hierboven. Verwijzingen naar
  Portainer in historische plannen beschrijven de vroegere situatie.
- **De map `website/screenshots/` en `website/teams/` staan buiten git** (de
  repo is publiek; teamzips bevatten namen en foto's en mogen nooit gecommit
  worden). Een deploy moet dus vanaf een checkout waar die mappen staan (de
  hoofdcheckout van Gerd-Jan), of kopieer ze eerst naar je worktree. Daarom
  staat de GitHub-workflow voor de website (`deploy-website.yml`) bewust uit
  (alleen met de hand te starten): hij zou een site zonder screenshots en
  teamzips uploaden.
- **De live-server is losgekoppeld van app-builds.** Hij gaat live zodra een
  wijziging op `main` staat, ook als er nog geen nieuwe build is. Houd de API
  daarom **achterwaarts compatibel** met de builds die testers hebben
  (iOS 2.2 (18), Android 0.5 (5)): nieuwe endpoints erbij is veilig,
  bestaande aanpassen niet. De teamendpoints (`/api/team…`, pagina `/t/<id>`)
  zijn nieuw en worden door oudere builds simpelweg niet gebruikt.
- **De app wijst alleen nog naar `https://live.squashanalyzer.com`.** De
  schakelaar Alfa/Beta is uit de app gehaald voordat hij in een build zat;
  `LiveShare.serverKey` bestaat nog maar wordt niet gelezen.
- **De Node-server (`server/live`) heeft geen teamendpoints.** Vallen we terug
  op de NAS, dan werkt live meekijken per partij wel, live teamwedstrijden niet.
- **Terugvallen op de NAS** = custom domain van de Worker af en in Cloudflare
  Zero Trust de public hostname opnieuw toevoegen (tunnel
  `2b05ba07-fadb-4248-a867-6df79718ae59`; website → `http://192.168.68.120:3001`,
  live → `http://192.168.68.120:3002`). Details en geschiedenis:
  `docs/hosting-verhuizing.md`. Of de NAS ooit helemaal weg mag, beslist
  Gerd-Jan.
- **Een Worker terugdraaien**: `npx wrangler rollback` (of de commit
  terugdraaien en laten deployen).

Cloudflare-account: login `gerdjanvangils@gmail.com`; `wrangler` is op de Mac
via OAuth ingelogd (`npx wrangler whoami`). De GitHub-secrets
`CLOUDFLARE_API_TOKEN` en `CLOUDFLARE_ACCOUNT_ID` staan in de repo. Valkuilen
bij Cloudflare:

- Fout 10063 "You need a workers.dev subdomain": één keer Workers & Pages in
  het dashboard openen, daarna opnieuw deployen.
- Fout 100117 bij een custom domain op een naam die al een (tunnel-)record
  heeft: eerst dat DNS-record verwijderen.
- Direct na een deploy kan `/health` een paar seconden een 500 geven (eerste
  aanroep van het limiter-object).
- Logs: dashboard → Worker → Observability (alleen methode, pad en status).
- `wrangler pages project create` maakt geen pages.dev-project meer maar een
  Worker; daarom bestaat `server/website-worker/wrangler.jsonc`.
- **DNS-wijzigingen en deploys doet Gerd-Jan zelf of buiten de automodus van
  Claude Code**: de classifier weigert ze als "Production Deploy".

## 2. Live meekijken in het kort

- Per wedstrijd: `LiveSession` (stand, foto's, schrijfsleutel, twee uur
  idle-alarm), kijkpagina `/l/<id>`.
- Per teamwedstrijd (nieuw): `TeamSession`, API `/api/team…`, kijkpagina
  `/t/<id>`. Eén gedeelde schrijfsleutel per teamwedstrijd; de uitnodiging is
  `id.key` als link (`https://squashanalyzer.com/team#<id>.<key>`), als code of
  als `squashanalyzer://team#…`. De app werkt de gekozen partij bij; de
  gedeelde sleutel geeft technisch schrijfrecht op alle partijen. Lege namen blijven leeg op de server; pagina en app tonen dan de
  teamnaam met de partij erachter ("Delft 7 E1"). Alles wordt twee uur na de
  laatste update gewist. Ontwerp en beslissingen:
  `docs/plan-live-teamwedstrijd.md`; codepad: sectie Competitie in
  `ARCHITECTURE.md`.
- Opslag: live-inhoud staat tijdelijk in persistente Durable Object-opslag
  (SQLite); het alarm verwijdert de sessie-inhoud na twee uur zonder
  stand-update. De limiter bewaart apart technische aanmaakadministratie.
- Privacy: teamnamen, datum, voornamen, stand en (bij losse wedstrijden
  optioneel) kleine spelersfoto's gaan naar de server; de tekst staat in `website/privacy.html`.
  Wijzig je wat er verstuurd wordt, pas die tekst dan ook aan.

## 3. Bouwen en testen

Alles draait lokaal op de Mac. Eisen: Xcode, Skip, Android Studio.

| Wat | Commando |
| --- | --- |
| Core (incl. Skip-transpilatie en de Kotlin-tests) | `cd Packages/SquashAnalyzerCore && swift test` (ook: `skip test --project Packages/SquashAnalyzerCore`, niet `--package-path`) |
| iOS-tests | `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation -only-testing:SquashAnalyzerTests` |
| Android unit-tests en debug-APK | `cd Android && export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ANDROID_HOME=$HOME/Library/Android/sdk && ./gradlew testDebugUnitTest assembleDebug` |
| Worker | `cd server/live-worker && npm test` (21 tests) |
| Node-reserve | `cd server/live && node --test` |
| Lint | `scripts/lint.sh` |

Regels voor tests op toestellen:

- **Nooit `connectedDebugAndroidTest` met de Samsung A13 (serienummer
  `RF8W10L1P6N`) aangesloten**: Gradle verwijdert de app en daarmee de data
  van Gerd-Jan. Zet `ANDROID_SERIAL=emulator-5554` en geef bij `adb` altijd
  `-s <serienummer>` mee. Een nieuwe build op de telefoon: `adb -s RF8W10L1P6N
  install -r Android/app/build/outputs/apk/debug/app-debug.apk`. Raak
  systeemdialogen op zijn telefoon niet aan. Het toestel moet met dezelfde
  debug-sleutel zijn geïnstalleerd; zit er een Play-versie op, dan is
  verwijderen (en dus data kwijt) de enige weg: vraag eerst.
- iPhone 16 Pro (UDID `00008140-0002683C0CE2801C`): bouwen met
  `xcodebuild build -configuration Debug -destination 'id=<udid>' -allowProvisioningUpdates`
  en installeren met `xcrun devicectl device install app`.
- SwiftData-schema V7 is bevroren (staat op de telefoon van Gerd-Jan); een
  modelwijziging betekent V8 met migratie. Competitie bewaart zijn data
  daarom in een JSON-bestand (`JSONFileTeamMatchStore`) en niet in
  SwiftData of Room.
- Skip-valkuilen (geen `CharacterSet`-splitsen, geen `lastIndex(of:)`,
  `Double` wordt als `1.79E12` gecodeerd dus gebruik `Int64`, alleen
  SF Symbols met een Android-mapping in `AppSymbol.swift`, enzovoort): zie
  `docs/android-port.md`.
- Ontwerp: het scheidsrechtersscherm is de visuele referentie (vlak, omlijnd,
  getint; geen glanzende `HardwareButton`s). Zie `docs/style/README.md`.

## 4. Opleveren naar testers

**Er wordt niets geüpload naar TestFlight of Google Play zonder dat
Gerd-Jan dat zegt.** Stand: iOS 2.2 (18) en Android 0.5 (5) zijn het laatst
geüpload; build 19 (Competitie, live teamwedstrijd, nieuwe hosting) is
klaar maar nog niet geüpload (in de projectbestanden staan nog iOS
`CURRENT_PROJECT_VERSION = 18` en Android `versionCode = 5`; ophogen hoort bij
de upload).

Volgorde bij een externe build:

1. Alles op `main` en groen (CI, plus lokaal de suites uit 3). De live-Worker
   wordt bij de push automatisch uitgerold; controleer `/health` op
   `https://live.squashanalyzer.com`.
2. Buildnummer ophogen: iOS `CURRENT_PROJECT_VERSION` in `project.pbxproj`
   (beide app-configuraties); Android `scripts/play_upload.py --bump` en de
   `versionName` in `Android/app/build.gradle.kts`.
3. Releasenotes in het Nederlands: `release-notes/<versie>-<build>.md` (iOS,
   geen emoji, App Store Connect weigert ze) en
   `release-notes/android-<versionName>-<versionCode>.md` (maximaal 500
   tekens). De tekst staat voorbereid in `docs/wijzigingen-builds.md`,
   inclusief het stuk over de nieuwe hosting.
4. iOS: `xcodebuild archive` (Release, `-allowProvisioningUpdates` met de
   App Store Connect API-sleutel), `xcodebuild -exportArchive` met een
   ExportOptions.plist (`method app-store-connect`, `destination upload`,
   `signingStyle automatic`, `manageAppVersionAndBuildNumber false`), daarna
   `scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md`
   (zet de notities, voegt toe aan groep Squashteam, dient in voor
   bèta-review en laat oude builds vervallen; draai
   `scripts/testflight_expire_old.py` nogmaals na goedkeuring).
5. Android: `cd Android && ./gradlew :app:bundleRelease`, dan
   `scripts/play_upload.py --notes <bestand> --name "<versionName> (<code>)"`
   (internal, alpha en de Google Group-track tegelijk; `--check` toont de
   tracks). Testers van gesloten tracks zijn alleen in de console te wijzigen.
6. Schermafbeeldingen vernieuwen: `scripts/screenshots.sh`, bekijk de PNG's,
   dan `scripts/upload_screenshots.py` (probeer `--dry-run`); Play-listing
   met `scripts/play_listing.py` (draai die vanuit de hoofdcheckout: de
   Play-screenshots staan buiten git).
7. Handleiding op de website bijwerken (`website/handleiding/iphone.html` en
   `android.html`, per tegel één sectie) en de website publiceren met de
   `wrangler deploy` uit 1. Daarna in het rapport vermelden wat er veranderd is.
8. `docs/wijzigingen-builds.md`: het blok "Volgende build" krijgt de kop met
   buildnummers en "(geüpload)".

Sleutels en geheimen staan **nooit** in de repo: App Store Connect-sleutel in
`~/.appstoreconnect/private_keys/` (sleutel- en issuer-id staan als
standaardwaarde in `scripts/asc_api.py`, te overschrijven met `ASC_KEY_ID`,
`ASC_ISSUER_ID` en `ASC_KEY_PATH`), Play-serviceaccount en uploadsleutel in
`~/.android-keys/` (wachtwoorden in `~/.gradle/gradle.properties`,
`PLAY_KEY_PATH` overschrijft), Cloudflare via `wrangler login` en de
GitHub-secrets.

## 5. Open punten (voor wie verder wil)

- Build 19 uploaden: alleen als Gerd-Jan het zegt.
- Live teamwedstrijd is getest tussen iOS-simulator, Android-emulator, de
  iPhone en de A13 zijn nog niet door Gerd-Jan geprobeerd.
- Vergelijken met de SBN-uitslag en een badgecategorie Teamspeler (zie
  `docs/competitie-vervolg.md`).
- De NAS-stacks 85 en 109 opruimen zodra Gerd-Jan de reserve niet meer wil.
- Testeraanmeldingen via Testers Community (Cirrux, aanmeldingen onder de
  naam "squashanalyzer") afhandelen: toevoegen aan de Google Group van de
  track "Google Group testers" en een antwoordmail sturen. Planning van de
  testperiode: `docs/buildplanning-testperiode.md`.
- Google's pre-launch report voor Squash Analyzer is nog niet gegenereerd.
