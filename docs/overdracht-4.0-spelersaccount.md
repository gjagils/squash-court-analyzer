# Overdracht 4.0 spelersaccount (4 november 2026)

Waar we staan, zodat een nieuwe sessie zonder voorkennis verder kan. Achtergrond:
[voorstel](voorstel-spelersaccount-4.0.md), [releaseplan](releaseplan-3x-4.0.md),
[testdraaiboek](testplan-4.0-koppelen.md), [backlog](backlog-2026-10-21.md) (S1–S6).

## De stand

Alles staat op `main`, achter `Features.shared.playerAccount` (standaard uit).

| Onderdeel | Stand |
|---|---|
| Account maken, inloggen met e-mail, Apple op iOS | Gebouwd |
| Koppelen zonder code: SBN-speler, "Ben jij X?" in je team, deellink | Gebouwd en getest (scenario's A t/m D) |
| Synchroniseren: wedstrijden uit je account komen in Afgeronde wedstrijden en tellen mee voor je badges (`AccountSync.swift`) | Gebouwd, unit-tests groen, **nog niet op een telefoon gezien** |
| Tokenvernieuwing op Android (ID-token verloopt na een uur) | **Nog niet aantoonbaar gezien** |

Afgesloten: het uitloggen op de A13 op 1 november was geen fout. Gerd-Jan maakte op
die telefoon de testaccounts van Paul en Niels en logde daarna uit (opslag geschreven
om 11:53, alleen de apparaatsleutel over). Niet opnieuw onderzoeken.

## Eerst doen

1. **Testapp op de A13 opnieuw bouwen en installeren.** Daar staat nog de build van
   1 november (3.1 build 4), van voor de wijzigingen die sindsdien op `main` kwamen.
   Is de oude build nog geïnstalleerd, dan hoeft dit niet voor stap 3, maar de nieuwe
   is het eerlijker om op te testen.
2. **Test-Worker bijwerken (doet Gerd-Jan).** Niet zeker of de wijziging met `decidedAt`
   al op de testserver staat. Zonder die wijziging haalt de app steeds alles opnieuw op;
   dubbel wordt het niet.
   ```bash
   cd ~/Github/squash-court-analyzer && git pull && cd server/account-worker && npm run deploy-test
   ```
3. **Synchroniseren testen.** Gerd-Jan logt op de A13 in **SA 4.0 test** in met
   `telecom@gerdjan.nl`. In Afgeronde wedstrijden horen dan te staan: de wedstrijd van
   "Coach Peter" (deellink) en de wedstrijd die hij als Gerd Lasso claimde. Controleer ook
   dat de badges meetellen bij zijn eigen speler. Laat de serverlog meelopen:
   ```bash
   cd server/account-worker && npx wrangler tail squash-account-test --format json
   ```
4. **Tokenvernieuwing testen.** Ruim een uur na het inloggen de app herstarten. Goed: nog
   steeds ingelogd, en `/me` geeft 200. De opslag op de telefoon is dan ruim 1 kB:
   ```bash
   adb -s RF8W10L1P6N shell run-as com.squashanalyzer.android.test4 ls -la shared_prefs/squash-analyzer-secure.xml
   ```
   311 bytes betekent: geen sessie meer (alleen de apparaatsleutel).
5. **Testplan afmaken:** scenario E (account verwijderen op de testserver) en F (zonder
   netwerk). Daarna de tabel in het testdraaiboek bijwerken.

## Daarna: de backlog van 4.0

- S4: naam van de afzender als de coach geen account heeft.
- S6: volledige badges van een teamgenoot, met toestemming ("Zichtbaar voor mijn team", standaard uit).
- Onderscheidingen naar de server synchroniseren.
- Inloggen met Google, en Apple op Android.
- S1: accountmails in eigen stijl en in de gekozen taal.

## Vóór een 4.0-release

- Echte Worker (`account.squashanalyzer.com`) draait nog migratie 0001 en oude code:
  migratie 0002 en deploy nodig. Dat doet Gerd-Jan.
- Branch `claude/wedstrijd-link-site` (pagina `/wedstrijd` en app-link voor de deellink)
  is niet gepubliceerd en wacht op het akkoord van Gerd-Jan. Hij loopt achter op `main`.
- Testdata opruimen: `npm run reset-test` en de testlogins in Firebase.

## Testomgeving

- Test-Worker: `squash-account-test` op `test-account.squashanalyzer.com`, eigen database.
- Testlogins: `satest+…@gerdjan.nl`. **Gerd-Jan maakt ze zelf aan**; Claude maakt geen
  Firebase-accounts en vult geen wachtwoorden in. Paul van Rijn (speler 2) en Niels de
  Groot (speler 3) bestaan al, Gerd-Jan zelf is `telecom@gerdjan.nl`.
- In de testdatabase op 1 november: Gerd-Jan (SBN 940) 2 geaccepteerd, Paul (942) 1 in
  het Postvak, Niels (937), en een open teamwedstrijd voor "Kees".
- Nep-coach: `node dev/send-match.mjs --test …` in `server/account-worker` (zie testdraaiboek).

## Bouwen

Android-testapp (staat naast de gewone app; serienummer A13 `RF8W10L1P6N`):

```bash
cd Android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ANDROID_HOME=~/Library/Android/sdk ./gradlew assembleDebug -PsquashPlayerAccount=true -PsquashAccountServer=test -PsquashTestApp=true
```

```bash
~/Library/Android/sdk/platform-tools/adb -s RF8W10L1P6N install -r Android/app/build/outputs/apk/debug/app-debug.apk
```

iOS-testbuild: `SQUASH_PLAYER_ACCOUNT=YES SQUASH_ACCOUNT_SERVER=test
SQUASH_FIREBASE_API_KEY=<uit ~/.android-keys/google-services.json>`, simulator iPhone 17 Pro.
Draai iOS-tests op "iPhone 17", anders overschrijven ze de testinstallatie op de 17 Pro.

## Valkuilen

- **Nooit** Gradle connected tests met de A13 aangesloten: dat wist appdata. Gebruik
  `ANDROID_SERIAL=emulator-5554`. `adb -s … install -r` mag wel.
- Oude Skip-uitvoer geeft rare Kotlin-fouten ("Enum types cannot be instantiated"):
  verwijder `Packages/SquashAnalyzerUI/.build/plugins/outputs/squashanalyzerui` en
  `.build/gradle-skip-stamp`, en draai `swift build`.
- Skip kent `layoutPriority` en `removePersistentDomain` niet.
- Toggles op de iOS 26-simulator reageren niet op een tik: gebruik een veeg.
- De serverlog toont alleen de Worker: aanroepen naar Firebase (inloggen, tokenvernieuwing)
  staan er niet in.
- Worker-tail: `npx wrangler tail squash-account-test`, zonder `--env`.
- Cloudflare-resources maken en deployen naar de Workers doet Gerd-Jan, en geheimen gaan
  nooit in git.
