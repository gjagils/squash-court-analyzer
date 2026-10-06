# Google Play: Android-app publiceren

**Actuele status — 6 oktober 2026:** de laatste gedocumenteerde upload is Android **0.5 (5)**, in gesloten test. Ondertekening, upload en App Links zijn ingericht. Android 0.6 (6) is voorbereid maar nog niet geüpload. Volg voor nieuw werk [opleveren en hosting](opleveren-en-hosting.md) en [de buildplanning](buildplanning-testperiode.md).

**Historisch inrichtingslogboek:** de onderstaande stappen en vroege versienummers zijn van de oorspronkelijke inrichting, geen nog af te werken checklist. Oude privacy-antwoorden van vóór AI/live/teamimport zijn niet bruikbaar voor de huidige Data safety-vragen. Gebruik de huidige [privacytekst](../website/privacy.html) en controleer de feitelijke gegevensstromen; dit document bevestigt geen actuele Console- of juridische status.

Stappenplan om de Android-app via Google Play te testen (interne test, de
Android-tegenhanger van TestFlight) en later te publiceren. Deel A (code) is
gedaan; deel B doet Gerd-Jan in de terminal en de Play Console; deel C
(App Links, stap 5 van het kaartdelen) doen we samen.

## Deel A — in de repo (klaar, 2026-09-30)

- **App-icoon**: adaptief icoon uit het iOS-icoon
  (`Android/app/src/main/res/mipmap-*`): zwarte achtergrondlaag, het
  vergrootglas op 54% zodat het handvat binnen de veilige zone van elke
  maskervorm valt. Bijgewerkt icoon = het iOS-icoon opnieuw door dezelfde
  `sips`-stappen halen (zie git-historie van deze commit).
- **Store-afbeeldingen** in `Android/play/`: `icon-512.png` (32-bit PNG met
  alfakanaal, zoals Play eist), `feature-graphic-1024x500.png` (eenvoudig:
  icoon op zwart; vervang gerust door een eigen ontwerp) en
  `screenshots/` (1080×2160; Play staat maximaal 2:1 toe, de emulator maakt
  2400 hoog, dus bijgesneden).
- **Ondertekening**: `app/build.gradle.kts` leest de upload-sleutel uit
  `~/.android-keys/squashanalyzer-upload.jks` en de wachtwoorden uit
  `~/.gradle/gradle.properties` (nooit in de repo). Zonder die sleutel is een
  release-build debug-ondertekend: lokaal te proberen, maar Google Play
  weigert zo'n upload, dus er kan niets per ongeluk verkeerd ondertekend
  live gaan.
- **Versies**: `versionCode` (moet bij elke upload omhoog) en `versionName`
  in `app/build.gradle.kts`; nu `1` / `0.1`.
- **Release-build**: `./gradlew :app:bundleRelease` →
  `app/build/outputs/bundle/release/app-release.aab` (±19 MB). Geen R8
  (verkleinen) nog: Skip gebruikt reflectie, dat vraagt eerst eigen
  keep-regels en een testronde. Release-build gestart op de emulator: werkt.

## Deel B — Gerd-Jan

### B1. Upload-sleutel maken (terminal, ±2 minuten)

Claude maakt deze niet, omdat dan het wachtwoord door de chat zou gaan.

```bash
mkdir -p ~/.android-keys
```

```bash
keytool -genkeypair -v -keystore ~/.android-keys/squashanalyzer-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

- Het vraagt twee keer om een wachtwoord (kies één sterk wachtwoord) en om
  naam/organisatie/plaats; die mag je invullen of met Enter overslaan en aan
  het eind met `ja`/`yes` bevestigen.
- Zet het wachtwoord én het bestand `squashanalyzer-upload.jks` in
  1Password (als bijlage). Kwijt = via Google een nieuwe upload-sleutel
  aanvragen (kan, omdat Play App Signing de echte sleutel beheert, maar het
  kost dagen).
- Open `~/.gradle/gradle.properties` (maak het bestand aan als het niet
  bestaat) en voeg toe, met je eigen wachtwoord:

  ```properties
  SQUASH_UPLOAD_STORE_PASSWORD=jouw-wachtwoord
  SQUASH_UPLOAD_KEY_PASSWORD=jouw-wachtwoord
  ```

Zeg daarna tegen Claude "sleutel staat klaar": die bouwt dan de ondertekende
`.aab` en controleert met `keytool` dat hij met de upload-sleutel is
ondertekend (zonder het wachtwoord te zien).

### B2. App aanmaken in de Play Console

1. Ga naar https://play.google.com/console en kies **Create app** (App
   maken).
2. Invullen:
   - App name: **Squash Analyzer**
   - Default language: **Nederlands – nl-NL**
   - App or game: **App**
   - Free or paid: **Free** (gratis; later betaald maken kan niet)
   - Vink de twee verklaringen aan (Developer Program Policies, US export laws).
3. **Create app**.

Let op, afhankelijk van je account:

- **Accountverificatie**: Google kan vragen om je identiteit te bevestigen
  en, bij nieuwe accounts, om toegang tot een echt Android-toestel te
  bevestigen via de Play Console-app. Zie "Zonder Android-telefoon" onderaan.
- **Persoonlijk account (na november 2023 aangemaakt)**: voordat de app
  openbaar mag, eist Google een **gesloten test met minstens 12 testers die
  14 dagen meedoen**. De interne test (B5) valt daar niet onder. Controleer
  de actuele eis in de Play Console onder Dashboard; die cijfers kunnen
  veranderen.

### B3. App content (App-inhoud): de verplichte vragen

In het menu **Policy and programs → App content** (of via de takenlijst op
het Dashboard). Antwoorden voor de Android-app zoals die nu is (geen AI
Coach, geen iCloud; alleen Mijn team gebruikt internet):

| Onderdeel | Antwoord |
|---|---|
| Privacy policy | `https://squashanalyzer.com/privacy.html` — de versie in de repo noemt Android al (2026-09-30), maar staat nog niet live; publiceren na jouw akkoord. Voor de interne test is de huidige URL bruikbaar. |
| App access | **All functionality is available without special access** (geen login) |
| Ads | **No, my app does not contain ads** |
| Content rating | Vragenlijst starten, e-mail invullen, categorie **All Other App Types** (of "Reference, News, or Educational" als dat er niet staat); alle vragen over geweld, seks, taal, drugs, gokken, gebruikersinteractie: **No**. Delen van gebruikersinhoud: **No** (een kaartlink delen gaat via de deelknop van het toestel, niet via een eigen dienst). Resultaat wordt vrijwel zeker "PEGI 3 / Everyone". |
| Target audience | **18 and over** (de app is voor coaches en scheidsrechters). Kies je leeftijden onder 13, dan gelden de strengere Families-regels. |
| News app | **No** |
| Data safety | Zie hieronder |
| Government app | **No** |
| Financial features | **My app doesn't provide any financial features** |
| Health | Geen gezondheidsfuncties aanvinken |

**Data safety** (Gegevensveiligheid):

1. *Does your app collect or share any of the required user data types?*
   Zonder AI Coach **No**; met AI Coach zie punt 3. Verder blijft alles op
   het toestel (Room-database). Er is geen server,
   geen analytics, geen crashrapportage van derden. Een kaartlink delen doe
   je zelf via de deelknop; de gegevens staan in de link na het `#` en
   worden niet naar een server gestuurd.
2. Bij "No" vervallen de vervolgvragen (encryptie, verwijderverzoek).
3. **Mijn team** (sinds 2026-09-30 op Android) haalt de openbare teampagina
   op van sbn.toernooi.nl. Daarbij gaat alleen het verzoek om die pagina
   het toestel af (de teamlink die je zelf invult), geen gegevens over
   spelers of wedstrijden; dat telt niet als "verzamelen" door de app.
   **AI Coach** (sinds 2026-09-30 op Android): alleen als de gebruiker zelf
   een OpenAI-key invult en op "Vraag AI Coach om advies" tikt, gaan
   gamestatistieken zonder namen naar OpenAI (een derde partij). Daardoor
   is vraag 1 waarschijnlijk niet meer simpelweg "No". Kenmerken om bij het
   invullen te gebruiken: optioneel en door de gebruiker gestart, niet aan
   een persoon of account gekoppeld, versleuteld verzonden (HTTPS), niet
   bewaard door de app. Kies de categorie die het best past op het moment
   van invullen (de lijst verandert weleens); twijfel je, vraag het Claude
   dan samen met het scherm erbij.

### B4. Store-vermelding (Main store listing)

Menu **Grow users → Store presence → Main store listing**.

- **App name**: Squash Analyzer
- **Short description** (max. 80 tekens):
  `Houd squashwedstrijden bij als coach of scheidsrechter en verdien badges.`
- **Full description** (max. 4000 tekens), voorstel:

  ```text
  Squash Analyzer helpt coaches en scheidsrechters om squashwedstrijden bij te houden, punt voor punt.

  SCHEIDSRECHTER
  • Tik op de score om een rally toe te kennen
  • LET, STROKE en undo
  • Servicekant links/rechts, automatische game-wissel
  • Wedstrijden worden automatisch bewaard en zijn te hervatten

  COACH
  • Leg per punt vast wie scoorde, hoe (winner of fout), met welke slag en vanuit welke zone
  • Bekijk afgeronde wedstrijden later terug

  SPELERS EN BADGES
  • Bewaar je spelers en kies ze bij de start van een wedstrijd
  • Spelers verdienen badges, zoals 5 punten op rij of een game met 11-0
  • Deel de badgekaart van een speler met een link; die opent in de app (Android en iPhone) of in de browser

  PRIVACY
  • Geen account nodig
  • Alles blijft op je toestel; geen advertenties, geen tracking
  ```

- **App icon**: `Android/play/icon-512.png`
- **Feature graphic**: `Android/play/feature-graphic-1024x500.png`
- **Phone screenshots** (minimaal 2): `Android/play/screenshots/*.png`.
  Betere screenshots met spelers en een lopende wedstrijd kan Claude later
  van de emulator maken.
- **Category**: App → **Sports**
- **Contact details**: e-mail `info@squashanalyzer.com`, website
  `https://squashanalyzer.com`

### B5. Interne test (de "TestFlight" van Android)

1. **Testing → Internal testing → Testers**: maak een e-maillijst (bijv.
   "Squashteam") met de Google-accounts (Gmail-adressen) van de testers,
   inclusief je eigen. Maximaal 100.
2. **Releases → Create new release**.
   - Play App Signing: als hierom gevraagd wordt, kies **Use Google-generated
     key** (standaard; aanbevolen).
   - Upload `app-release.aab` (Claude bouwt die na B1; pad
     `Android/app/build/outputs/bundle/release/app-release.aab`).
   - Release name: bijv. `0.1 (1)`. Release notes (nl-NL): bijv.
     `Eerste testversie voor Android: scheidsrechter, coach, spelers, badges en kaarten delen.`
3. **Save → Review release → Start rollout to Internal testing**.
4. Onder **Testers** staat de **opt-in link** ("Copy link"). Testers openen
   die op hun Android-toestel, tikken op "Word tester" en installeren de app
   via de Play Store. Nieuwe versies komen daarna automatisch binnen.

Elke volgende upload: `versionCode` omhoog (Claude doet dat), nieuwe `.aab`,
nieuwe release in dezelfde track. Later maakt Claude een uploadscript via de
Google Play Developer API (net als het TestFlight-script); daarvoor is een
service-account in Google Cloud nodig met toegang in de Play Console.

### B6. Vingerafdrukken voor stap 5

Na de eerste upload: **Test and release → Setup → App integrity → App
signing**. Kopieer de **SHA-256 certificate fingerprint** van

- de **App signing key certificate** (de sleutel van Google), en
- de **Upload key certificate** (jouw sleutel).

Geef die twee aan Claude. Die zet ze in `website/.well-known/assetlinks.json`
(deel C / kaartdelen stap 5) en publiceert dat na jouw akkoord.

## Zonder Android-telefoon

- **Testen kan op de emulator**: het emulator-image op deze Mac heeft de
  Play Store. Log daarin zelf in met een Google-account dat op de testerslijst
  staat en open de opt-in link in Chrome op de emulator; dan installeert de
  Play Store de interne-testversie, precies zoals op een telefoon. (Het
  inloggen doe jij, Claude typt geen wachtwoorden.)
- **Accountverificatie**: vraagt de Play Console om een Android-toestel te
  bevestigen, dan moet dat een echt toestel zijn waarop de Play Console-app
  draait; een emulator telt daar waarschijnlijk niet voor. Leen er dan
  eenmalig één (van een tester of familielid).
- **Gesloten test met 12 testers** (alleen bij een persoonlijk account):
  de testers hebben zelf een Android-telefoon nodig; jouw eigen toestel is
  daar niet voor nodig.

## Deel C — App Links (kaartdelen stap 5)

Zie `docs/android-port.md`, plan kaartdelen, stap 5. Nodig: de twee
vingerafdrukken uit B6 en akkoord om de website bij te werken.

## Uploaden met het script (sinds 2026-10-01)

Net als TestFlight gaat een Android-testbuild nu vanaf de Mac, zonder de Play Console:

```bash
scripts/play_upload.py --bump
```
```bash
cd Android && ./gradlew :app:bundleRelease
```
```bash
scripts/play_upload.py --notes release-notes/android-X-N.md --name "X (N)"
```

- `--bump` verhoogt `versionCode` in `app/build.gradle.kts`; `versionName` pas je zelf aan.
- De release-notes (Nederlands, max. 500 tekens) staan in `release-notes/android-<versie>-<code>.md`.
- `--check` laat de tracks en de laatste release zien: zo zie je of de toegang werkt.
- De sleutel van het serviceaccount staat in `~/.android-keys` (nooit in de repo, ook in 1Password).
  Het script ondertekent het verzoek met openssl en stuurt alleen een tijdelijk toegangsbewijs mee.
- Upload-sleutel (`squashanalyzer-upload.jks`) en wachtwoorden: zie B1.

Gedaan: 0.1 (1) met de hand, 0.2 (2) met het script.

Sinds 4 oktober zet het script elke release op **internal**, **alpha** en
**Google Group testers** tegelijk (`--tracks` om af te wijken).

## Twee gesloten tests (sinds 2026-10-04)

Play Console kiest per gesloten test óf mailinglijsten óf Google Groups. Daarom:

- **Gesloten test - Alpha**: mailinglijsten AllInnSquash, Bombardino en overig.
  Bestaande testers; nieuwe mensen kun je hier met de hand bijzetten.
- **Gesloten test - Google Group testers**: leden van
  [squashanalyzer@googlegroups.com](https://groups.google.com/g/squashanalyzer)
  (zichtbaar voor iedereen, lid worden op aanvraag; Gerd-Jan keurt goed, de ledenlijst
  is alleen voor beheerders zichtbaar), plus **testers-community@googlegroups.com**
  (Testers Community, betaalde dienst voor de 12 testers × 14 dagen). Alle landen
  (wereldwijd, voor de testers van die dienst), feedback info@squashanalyzer.com.
  Welkomsttekst van de groep = de testersmail.
- Beide gebruiken dezelfde opt-in-link
  (https://play.google.com/apps/testing/com.squashanalyzer.android).
- Testers van een gesloten test kun je niet via de API beheren ("upgraded to use
  open or closed testing"); releases en landen wel.

## Store-vermelding met het script (sinds 2026-10-01)

`scripts/play_listing.py` zet de Nederlandse store-vermelding vanuit de repo: teksten en
contactgegevens uit `Android/play/listing-nl-NL.json`, icoon en feature graphic uit
`Android/play/`, en de telefoon-schermafdrukken uit `Android/play/screenshots/`
(1080×2160, bijgesneden emulatorbeelden; die map staat in .gitignore). Eerst `--dry-run`.

## Veiligheid van gegevens via de API (sinds 2026-10-01)

`Android/play/data-safety.csv` is de export uit de Play Console, ingevuld: wel gegevens
(alleen **App-activiteit → Andere door gebruikers gegenereerde content**: de gamestatistieken
die de optionele AI Coach naar OpenAI stuurt), verzameld en niet gedeeld, niet kortstondig,
optioneel, voor app-functionaliteit; versleuteld verzonden; geen accounts; verwijdering
"Nee, binnen 90 dagen automatisch verwijderd" (OpenAI bewaart API-gegevens hooguit 30 dagen).
Opnieuw insturen: `POST …/applications/com.squashanalyzer.android/dataSafety` met
`{"safetyLabels": <inhoud van het CSV-bestand>}` (zie play_upload.py voor het token).
Verandert de app wat hij verstuurt, pas dan dit bestand aan.

3 oktober 2026: **Naam** (voornamen naar de live-server) en **Foto's** (kleine
spelersfoto op de livepagina) toegevoegd: verzameld, niet gedeeld, niet kortstondig
(tot 2 uur), optioneel (LIVE en "Foto's meesturen" zijn uit te zetten), voor
app-functionaliteit. Ingestuurd via de API en in de console gecontroleerd.

## Stand 1 oktober 2026 (avond)

- App-inhoud volledig: privacybeleid, inloggegevens, advertenties (geen), contentclassificatie,
  doelgroep, gegevensveiligheid (API), overheid (nee), financiële functies (geen),
  gezondheid (geen), advertentie-ID (nee; de app heeft geen AD_ID-machtiging), categorie Sport.
- Gesloten test "Alpha": 0.3 (3), landen Nederland en België, testers via de e-maillijst
  "Bombardino" (dezelfde als de interne test), feedback info@squashanalyzer.com.
  Op een nog niet gepubliceerde app mag de API alleen een **concept**-release in een
  gesloten track zetten; uitrollen gaat dan in de Play Console.
- Alles (14 wijzigingen) ingestuurd ter beoordeling. Na goedkeuring staat onder
  Gesloten test → Testers de opt-in-link. Productie pas na 12 testers × 14 dagen.
