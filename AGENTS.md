# Werkafspraken voor agents (Codex, Claude Code)

SquashAnalyzer: iOS-app (SwiftUI/SwiftData) en Android-app (dezelfde Swift
via Skip, Room), met live meekijken en een website op Cloudflare. De eigenaar
is Gerd-Jan (Nederlandstalig): app-teksten, documentatie, releasenotes en
commit-uitleg zijn Nederlands, code en commentaar Engels zoals het er al staat.

## Eerst lezen

- `docs/opleveren-en-hosting.md`: **wie draait wat (Cloudflare, de NAS is
  alleen reserve), hoe je test, uitrolt en oplevert, en wat nog openstaat.**
- `ARCHITECTURE.md`: opzet van de app (lokale data, scoringsregels, badges,
  Competitie incl. live teamwedstrijd, Android-port).
- `docs/wijzigingen-builds.md`: wat er sinds de laatste upload veranderd is,
  met de releasenote-teksten. Werk dit bij met elke wijziging.
- `docs/android-port.md`: Skip-valkuilen en Android-status.
- `docs/competitie-vervolg.md`, `docs/plan-live-teamwedstrijd.md`: de laatste
  feature en de gemaakte keuzes.

## Harde regels

- **Niets uploaden naar TestFlight of Google Play** (en geen buildnummers
  ophogen voor een upload) zonder dat Gerd-Jan dat zegt. Mergen naar `main`
  mag als de suites groen zijn; een push naar `main` rolt de live-Worker
  automatisch uit.
- **De website publiceren** gaat met `npx wrangler deploy -c
  server/website-worker/wrangler.jsonc` vanaf de Mac (niet via Portainer; de
  NAS is verouderd). `website/screenshots/` en `website/teams/` staan buiten
  git en mogen nooit gecommit worden (publieke repo, teamzips bevatten namen
  en foto's).
- DNS- en Cloudflare-dashboardwijzigingen doet Gerd-Jan zelf.
- **Nooit `connectedDebugAndroidTest` met zijn Samsung A13 aangesloten** (het
  wist de app-data); gebruik `ANDROID_SERIAL=emulator-5554` en `adb -s`.
- SwiftData-schema V7 is bevroren; een modelwijziging is V8 met migratie.
  Competitie gebruikt bewust een JSON-bestand.
- **Versienummers**: versie (3.1) gelijk op iOS en Android, `build 4` per
  upload naar testers, `build 4.1` per interne uitlevering; alleen aanpassen
  met `scripts/version.py` (uitleg in `docs/opleveren-en-hosting.md`). In
  productie staat iOS 2.0; de testperiode loopt tot 3.0.
- Houd de live-server-API achterwaarts compatibel met de builds van testers.
- Geheimen (App Store Connect-, Play- en Cloudflare-sleutels) staan buiten de
  repo; zie `docs/opleveren-en-hosting.md`.
- Nieuwe UI in de stijl van het scheidsrechtersscherm (`docs/style/README.md`).

## Testen

Zie de tabel in `docs/opleveren-en-hosting.md` (Core met Skip, iOS, Android,
Worker). Draai ze allemaal voordat je naar `main` pusht.
