# Overdracht sprint 3 (`i18n-platforms`) voor de samenvoeging

21 oktober 2026. Voor wie de vier sprints van de Engelse variant (3.0, vrijdag
23 oktober) op de Mac samenvoegt. Achtergrond en keuzes: `docs/i18n-platforms.md`.

## Wat er in de branch zit

- **iOS, widget, `Shared/`**: String Catalogs voor app en widget (bron nl),
  Live Activity en Dynamic Island in het Engels, Instellingen met de rij
  Taal/Language (opent de iOS-instellingen van de app), `nl` in `knownRegions`.
- **Android**: `values/` (nl, standaard) en `values-en/`, `HostLocale.kt`
  (niet-Nederlandse telefoon → Engels), `locales_config.xml` en
  `MainActivity.openAppLanguageSettings()`.
- **Live-server**: optioneel `lang` bij starten en volgen, pushmeldingen per
  volger in diens taal, linkvoorbeeld in de taal van wie deelt; `live.html` en
  `team.html` Engels als de browser niet op Nederlands staat. 57 vitest-tests groen.
- Niets aangeraakt in `Packages/` en `website/`. Niet uitgerold.

## Afspraak met sprint 1 (`i18n-core`): het `lang`-veld

Sprint 1 laat de app `lang` meesturen; de server verwacht het zo:

| Verzoek | Waar `lang` staat |
|---|---|
| `POST /api/live` (live meekijken starten) | bovenaan in de JSON, naast de standvelden (`p1`, `score`, …) |
| `POST /api/team` (teamwedstrijd starten) | bovenaan in de JSON, naast `home`, `away`, `date` |
| `POST /api/live/:id/followers` en `/api/team/:id/followers` (volgen) | naast `platform`, `token`, `sandbox`, `alerts` |

- Waarde `"nl"` of `"en"`; al het andere en ontbreken telt als `"nl"`.
- `?lang=en` in de URL van de twee start-POST's werkt ook, maar de body heeft voorrang.
- Bij `DELETE .../followers` en bij `PUT` van de stand is `lang` niet nodig.
- Na de merge controleren: de request-structs in Core sturen precies deze
  sleutel `lang` op deze plekken (anders blijft alles stil Nederlands).

## Volgorde en aandachtspunten bij het samenvoegen

1. Eerst sprint 1 en 2 (Core en UI), dan deze branch, dan sprint 4 (website).
2. **Android, sprint 2**: na het mergen van `i18n-ui` één regel toevoegen aan de
   `AndroidHomeView(...)`-aanroep in `MainActivity.kt`, met de closure-naam
   van sprint 2:
   `onLanguage = { openAppLanguageSettings() },`
3. **Mogelijke conflicten**: `SquashAnalyzer.xcodeproj/project.pbxproj` (nieuwe
   ID's `D1000001/2`, `D2000001/2`; als sprint 1 of 2 ook catalogs toevoegt,
   beide behouden) en `Android/.../MainActivity.kt`.
4. Controleer of sprint 2 het `String`-type van `SettingsRow`, `ActionButton`,
   `CloseButton` of `pageTitle` verandert: de iOS-`SettingsView` geeft er
   gelokaliseerde teksten aan door.
5. Taalterugval gelijk houden: app-target en Android tonen Engels op een
   telefoon die niet op Nederlands staat (bijv. Duits); controleer dat de
   UI-package van sprint 2 dat ook doet.

## Besloten

- "matches" past op de plek van "partijen" in de teammelding op Android
  (Gerd-Jan, 21 oktober).
- Linkvoorbeeld volgt de taal van wie deelt, niet `Accept-Language`.

## Nog open

- Nederlands gebleven: API-foutteksten van de server, teksten uit Core
  (`LeagueTeamError`, `CardInbox.newerAppText`), twee controleteksten in
  `RoomPlayerStore` (Android) en de standaardnamen `Speler 1`/`Speler 2` die
  de server opslaat.

## Te testen op de Mac (niets hiervan kon in de cloud)

- iOS: app en widget bouwen; catalogs in `nl.lproj` en `en.lproj`; unit tests
  (draaien in nl/NL via het schema).
- Live Activity en Dynamic Island op een Engelse iPhone, los en teamwedstrijd;
  de Taal-optie in iOS-Instellingen bij de app.
- Android: `./gradlew :app:testDebugUnitTest assembleDebug`; meldingen op de
  emulator in nl, en en de (Android 9–16, Live Update); taalscherm per app op
  Android 13+ en de terugval naar app-info.
- Worker: `npx vitest run` in `server/live-worker` na de merge.
