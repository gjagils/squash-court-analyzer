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
- `docs/skip-valkuilen.md`: de Skip-valkuilen (Swift → Kotlin) in een lijst; `docs/android-port.md` is het uitgebreide logboek.
- `docs/competitie-vervolg.md`, `docs/plan-live-teamwedstrijd.md`: de laatste
  feature en de gemaakte keuzes.

## Werken zonder elkaar in de weg te zitten

Meerdere agents (Codex, Claude Code) en Gerd-Jan werken in dezelfde repo. Op 6
oktober bleef een grote documentatiereview van Codex ongecommit in de
hoofdcheckout staan terwijl `main` doorliep, waardoor het later handmatig
samengevoegd moest worden. Daarom:

1. **Begin elke sessie met `scripts/sync-check.sh`.** Loop je achter op
   `origin/main`, doe dan eerst `git pull --rebase origin main` en pas daarna
   bewerken. Staan er niet-gecommitte wijzigingen die niet van jou zijn: niet
   aanraken, niet overschrijven; stop en vraag Gerd-Jan.
2. **Werk in een eigen worktree, niet in de hoofdcheckout** (`git worktree add
   ../squash-<onderwerp> -b <agent>/<onderwerp> origin/main`). De hoofdcheckout
   is Gerd-Jans werkplek: daar alleen `git pull --ff-only`.
3. **Commit klein en vaak, en push direct naar `main`**:
   `git pull --rebase origin main && git push origin HEAD:main`. Een wijziging
   die alleen in een werkmap staat, bestaat voor de anderen niet. Een
   documentatiereview of ander groot werk gaat in stappen (een commit per
   onderwerp), niet als één grote ongecommitte hoop.
4. **Sluit elke sessie af met `scripts/sync-check.sh` en een melding**: wat is
   er veranderd, wat staat er nog open. Er mag niets ongecommit achterblijven
   en geen lege branch (zie "Branches opruimen").
5. **Gedeelde documenten** (`docs/wijzigingen-builds.md`,
   `docs/opleveren-en-hosting.md`, `AGENTS.md`, `README.md`): pull vlak voor
   het bewerken, houd je wijziging klein en push meteen. Bij een merge-conflict
   in zulke bestanden: beide kanten behouden en daarna samenvoegen, niets van
   de ander weggooien.
6. **Niet committen**: bouwuitvoer en schermafbeeldingen in de root (`output/`,
   `Squashanalyzerscreens/`), `__pycache__`, sleutels, `website/screenshots/`
   en `website/teams/` (die staan in `.gitignore`).
7. **Feiten die je in documentatie zet moet je kunnen controleren.** Schrijf
   geen "iedere telefoon schrijft alleen zijn eigen partij" als de server dat
   niet afdwingt; zet erbij wat de code echt doet. Een status ("nog niet
   geüpload", "staat live") moet kloppen op het moment dat je hem schrijft en
   een datum dragen.

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
- **Branches opruimen**: push gemergd werk direct naar `main` (`git push origin
  HEAD:main`) en laat geen remote werkbranch staan; is een branch na een
  commit leeg (alles in `main`), verwijder hem dan (`git push origin --delete
  <branch>`, lokaal `git branch -d`; een branch die in een worktree is
  uitgecheckt kan pas weg als die sessie klaar is). Verwijder nooit een branch
  met commits die niet in `main` staan, en raak worktrees van andere sessies
  en de uncommitted wijzigingen in de hoofdcheckout niet aan.
- Houd de live-server-API achterwaarts compatibel met de builds van testers.
- Geheimen (App Store Connect-, Play- en Cloudflare-sleutels) staan buiten de
  repo; zie `docs/opleveren-en-hosting.md`.
- Nieuwe UI in de stijl van het scheidsrechtersscherm (`docs/style/README.md`).

## Testen

Zie de tabel in `docs/opleveren-en-hosting.md` (Core met Skip, iOS, Android,
Worker). Draai ze allemaal voordat je naar `main` pusht.
