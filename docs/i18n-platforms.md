# Engels: platformdelen en live-server (sprint 3, `i18n-platforms`)

Stand 21 oktober 2026, nog niet gebouwd op de Mac. Het algemene mechanisme
staat in `docs/i18n.md` (sprint 1); dit zijn de keuzes voor de iOS-target, de
widget, Android en de live-server. Nederlands blijft overal de brontaal en
leest precies als voorheen.

## iOS, widget en `Shared/`

- String Catalogs: `SquashAnalyzer/Localizable.xcstrings` (app, ook de teksten
  uit `Shared/`) en `SquashLiveActivity/Localizable.xcstrings` (widget), bron
  `nl`, sleutel = de huidige Nederlandse tekst. `nl` staat in `knownRegions`;
  `CFBundleLocalizations` (nl, en) in beide Info.plists.
- `developmentRegion` stond al op `en` en is zo gelaten: een telefoon in een
  andere taal dan Nederlands of Engels krijgt Engels.
- Teksten in een `String` (koppen als "E3 · bezig", "Uitslag: … wint …") gaan
  via `String(localized:)`, pas bij het tonen; de content-state, statuscodes
  en teamnamen blijven onvertaald.
- Geen `InfoPlist.xcstrings`: de app heeft geen `NS*UsageDescription`-teksten.
- Instellingen: rij Taal/Language na Weergave, opent
  `UIApplication.openSettingsURLString` (iOS toont daar de taal per app).
- De testactie in het schema draait in nl/NL, omdat tests Nederlandse teksten
  controleren.

## Android (`Android/app/src/main`)

- `res/values/strings.xml` is Nederlands (standaard), `res/values-en/` Engels.
- Terugval: met alleen resources krijgt een Duitse telefoon Nederlands. Daarom
  kiest `HostLocale.kt`: eerste taal van de telefoon (of de gekozen app-taal)
  Nederlands → Nederlands, anders Engels.
- Taal per app: `res/xml/locales_config.xml` (nl, en) en `android:localeConfig`.
  `MainActivity.openAppLanguageSettings()` opent
  `Settings.ACTION_APP_LOCALE_SETTINGS` (Android 13+), anders de app-info.
  Na het mergen van sprint 2 nog koppelen in de `AndroidHomeView(...)`-aanroep
  (naam van de closure volgens sprint 2), bijvoorbeeld
  `onLanguage = { openAppLanguageSettings() },`.
- Meldingskanalen krijgen de nieuwe naam als de taal verandert.

## Live-server (`server/live-worker`)

- Optioneel `lang` (`"nl"`/`"en"`, anders Nederlands) bij `POST /api/live`,
  `POST /api/team` en `POST .../followers`; zie `server/live-worker/README.md`.
  Oudere builds sturen niets en merken niets.
- Meldingen (game, partij, uitslag) gaan per volger in diens taal; de stand
  zelf is voor iedereen gelijk.
- Linkvoorbeeld: volgt de `lang` van wie de link deelde (een crawler stuurt
  geen bruikbare `Accept-Language`). De pagina's `/l/:id` en `/t/:id` kiezen
  Engels in de browser als `navigator.language` niet met `nl` begint.
- API-foutteksten blijven Nederlands.

## Nog te controleren op de Mac

- iOS- en widgetbuild; catalogs komen in `nl.lproj` en `en.lproj`; unit tests.
- Live Activity en Dynamic Island op een Engelse iPhone (los en teamwedstrijd).
- Taal-optie in iOS-Instellingen bij de app.
- `./gradlew :app:testDebugUnitTest assembleDebug`; meldingen op de emulator in
  nl, en en de (Android 9–16, Live Update); taalscherm per app op Android 13+.
- Past "matches" (9 sp) op de plek van "partijen" in de teammelding.
