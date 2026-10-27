# Voorstel: anonieme gebruikstelling in de app (3.1)

Vraag van Gerd-Jan (27 oktober 2026): kan ik echt app-gebruik zien, naast de
cijfers van de stores? Play meet dagelijks actieve gebruikers, Apple alleen van
wie delen met ontwikkelaars aan heeft (heel weinig), en de live-dienst telt
alleen live meekijken en teamwedstrijden (`docs/voorstel-gebruikscijfers.md`).
Wie de app gebruikt zonder live te gaan, is nu onzichtbaar.

Idee: de app meldt hooguit één keer per dag "app geopend" aan dezelfde teller
in de live-Worker. **Status (27 oktober 2026, avond): gebouwd op de branch
`claude/gebruikstelling-3.1` als 3.1 build 1, nog niet op `main`, niet live en
niet geüpload.** Wat gebouwd is staat in `docs/wijzigingen-builds.md`. Afwijkend
van de tekst hieronder: "gebruikt" is het openen van het scherm van dat deel
(coach- of scheidsrechtersscherm, wedstrijdlijst, coachanalyse of
spelersprofiel, Competitie), en de schakelaar staat in Instellingen onder Live.

**Besluit (Gerd-Jan, 27 oktober 2026)** over de open keuzes onderaan:

1. Standaard **aan**, uit te zetten in Instellingen (opt-out).
2. **Wel** meten welk deel gebruikt wordt (coach, scheidsrechter, analyse, competitie).
3. **Wel** nieuwe installaties tellen (`app-first`).
4. Testers **niet** apart tellen: geen `test`-vlag vanuit de app, ook niet op iOS.
5. De versie in een **eigen tabel** `app_days` (niet in de kolom `club`).
6. Land **en** regio bewaren, zoals bij live.
7. In de **eerste 3.1-testbuild**; de Worker mag eerder live, privacypagina en
   console-formulieren gelijk met de 3.1-productierelease.

Waar de tekst hieronder nog meerdere wegen beschrijft, geldt dit besluit.

## Wat de app stuurt

Eén verzoek per dag, `POST /api/app/day` naar de live-dienst, met als body:

```json
{ "platform": "ios", "version": "3.1", "lang": "nl", "parts": ["referee"] }
```

| Veld | Waarde | Waarom |
|---|---|---|
| `platform` | `ios` of `android` | iPhone en Android naast elkaar; zelfde waarden als bij live (`cleanPlatform`) |
| `version` | de marketingversie (`3.1`), niet het buildnummer | zien of mensen bijwerken; het buildnummer maakt rijen fijner zonder nut |
| `lang` | `nl` of `en` (de app-taal) | net als bij live |
| `parts` | optioneel, zie onder | welk deel van de app gebruikt wordt |

Niet meesturen: geen apparaat-ID, geen installatie-ID, geen
advertentie-ID, geen namen, geen tijdstip (de server rekent zelf de dag uit,
`dayOf()` in Nederlandse tijd), geen model of OS-versie. De server slaat net
als nu land en regio op die Cloudflare uit het verzoek afleidt, nooit het
IP-adres zelf.

**Welk deel** (`parts`, keuze 2): een lijst uit `coach`, `referee`, `analysis`,
`competition`, met de delen die vandaag gebruikt zijn. "Gebruikt" is één vaste
gebeurtenis per deel, zodat het meetbaar en testbaar blijft:

- `coach`: een coachsessie gestart
- `referee`: een scheidsrechterswedstrijd gestart
- `analysis`: een afgelopen wedstrijd of spelersprofiel geopend (statistiek, trend)
- `competition`: het Competitie-scherm geopend

### Dubbeltelling beperken zonder ID

De app onthoudt lokaal (UserDefaults, op Android via Skip ook) twee dingen:

- `usageDay`: de dag (`yyyy-MM-dd`, lokale kalender) waarop "geopend" al gemeld is;
- `usageParts`: de delen die vandaag al gemeld zijn, als kommatekst.

Bij het openen (naar de voorgrond komen): is `usageDay` niet vandaag, stuur dan
de melding en zet `usageDay` pas op vandaag na een antwoord 2xx (of 404: een
server zonder dit pad, zoals de NAS-reserve, hoeft het niet elke keer opnieuw
te krijgen). Mislukt het (geen netwerk), dan probeert de app het bij de volgende
keer openen opnieuw. Gebruikt iemand later die dag een nieuw deel, dan gaat er
een tweede verzoek met alleen dat deel (`{"parts":["coach"], "open": false}`):
de server telt dan alleen dat deel, niet nog een "geopend".

Wat dit wel en niet geeft:

- **Per dag**: het aantal apparaten dat de app die dag opende (een telefoon
  telt één keer per dag). Twee telefoons van één persoon tellen twee keer; na
  opnieuw installeren of "gegevens wissen" kan een apparaat op die dag nog één
  keer extra tellen. Dat is zeldzaam en blijft een kleine overtelling.
- **Per week**: de som van de dagen is "apparaat-dagen", **niet** het aantal
  unieke gebruikers. Zonder ID kan de server niet weten of de tien meldingen van
  deze week tien mensen zijn of één persoon die elke dag speelt. Dat is de prijs
  van geen ID, en bewust zo (zie "Alternatieven"). Wel bruikbaar: gemiddeld per
  dag, en de trend daarvan over de weken.
- **Optioneel, keuze 3**: een tweede lokale vlag `usageFirstSent`. De allereerste
  melding van een installatie krijgt `"first": true` en telt daarnaast als soort
  `app-first`. Dat geeft nieuwe installaties per dag zonder ID (ook installaties
  die nooit iets anders doen dan openen), naast de downloadcijfers van de stores.
  Een update van 3.0 naar 3.1 telt dan één keer als "eerste", omdat 3.0 de vlag
  niet kende; dat is één piek bij het uitrollen.

Wanneer de app niets stuurt: als de gebruikstelling uit staat (Instellingen, zie
onder), in debug-builds, in de screenshot-scenario's (`applyScreenshotScenario`)
en in tests (er is dan geen transport gezet, of een nep-transport).

**Testers apart (keuze 4; besloten: niet doen)**: TestFlight- en interne Play-builds sturen
`"test": true` mee; de server zet die in de bestaande kolom `test`, zoals de
voorbeeldspelers nu. Op iOS is TestFlight te herkennen aan de
`sandboxReceipt` van `Bundle.main.appStoreReceiptURL`; op Android is het spoor
(intern/productie) niet betrouwbaar uit de app te halen. Eenvoudiger
alternatief: geen onderscheid, en de testers zijn in de cijfers van de week van
een testronde gewoon zichtbaar als bobbel.

## Server: aansluiten op `StatsCounter`

Alles in de bestaande `StatsCounter` (`server/live-worker/src/stats.js`), zelfde
tabel `counts`, zelfde `GET /api/stats`:

1. **Nieuwe soorten** in `KINDS`: `app` (geopend), `app-coach`, `app-referee`,
   `app-analysis`, `app-competition` en (keuze 3) `app-first`. `totalsOf()`
   telt ze dan vanzelf mee en `GET /api/stats` geeft ze in `rows` en `totals`
   zonder wijziging van het antwoordformaat.
2. **De versie**: de tabel heeft geen kolom `version`, en de primaire sleutel van
   een SQLite-tabel kan niet met `ALTER TABLE` uitgebreid worden. Voorstel: voor
   de `app`-soorten de versie in de kolom `club` zetten (die is bij alles behalve
   `team` leeg) en dat in een commentaar en de README vastleggen ("`club`: de
   club bij `team`, de appversie bij `app`"). Netter maar meer werk: een tweede
   tabel `app_days(day, kind, platform, version, lang, country, region, test, n)`
   in hetzelfde Durable Object, en `rows()` geeft beide (keuze 5).
   **Besloten: de eigen tabel.** `GET /api/stats` krijgt daarvoor een extra
   veld `appRows` naast `rows` (achterwaarts compatibel: het weekrapport van nu
   negeert het), en `totals` telt de `app`-soorten uit die tabel.
3. **Nieuw pad** in `index.js`: `POST /api/app/day`. Het leest de body, valideert
   streng (alleen bekende `parts`, versie alleen cijfers en punten, maximaal 10
   tekens, anders `unknown`) en roept de bestaande `count(...)` aan, één keer
   `app` (tenzij `open: false`) en één keer per deel. Antwoord altijd `204`, ook
   als tellen mislukt: de app hoeft niets te weten.
4. **Misbruik**: het pad heeft geen sleutel (die zou in de app staan en is dan
   niet geheim), dus iedereen kan de teller ophogen. Beperken met de bestaande
   `LiveLimiter`: per IP een paar verzoeken per minuut, zoals `allowCreate`, het
   IP alleen in het geheugen van de limiter. De cijfers blijven een indicatie;
   een vreemde piek is in het weekrapport te zien.
5. **Tests** in `server/live-worker/test/stats.test.js`: één melding geeft één
   rij `app` met platform, taal en versie; `parts` geeft de deelrijen; een
   onbekend deel of een rare versie wordt `unknown`/genegeerd; `open: false`
   telt geen `app`; geen IP of andere identifier in de tabel (assert op de
   inhoud); de limiet geeft na te veel verzoeken nog steeds 204 maar telt niet.
6. **README van de Worker**: het nieuwe pad en de soorten. Achterwaarts
   compatibel: oude apps sturen niets, oude rijen blijven zoals ze zijn.

Een push naar `main` rolt de Worker automatisch uit; de Worker kan dus vóór de
app-build live, dan staat het pad klaar als de 3.1-testers beginnen.

## Weekrapport (`scripts/weekly-stats.py`, `docs/weekrapport.md`)

- `KIND_LABELS` uitbreiden, of beter een eigen blok **"App-gebruik"** boven
  "Live-dienst", omdat de betekenis anders is:
  - gemiddeld aantal apparaten per dag deze week en vorige week;
  - de drukste dag;
  - per platform (iOS/Android) en per versie (aandeel dat al op 3.1 zit);
  - per deel: op hoeveel apparaat-dagen coach, scheidsrechter, analyse,
    competitie gebruikt is;
  - (keuze 3) nieuwe installaties deze week;
- Een zin in het rapport die uitlegt dat de weektotalen apparaat-dagen zijn,
  geen unieke gebruikers.
- Het weeksnapshot in `docs/stats/weekly/` krijgt een veld `app` (gemiddelde per
  dag en de delen), en de trendtabel van 8 weken een kolom "app per dag".
- `--sample` krijgt voorbeeldrijen voor de nieuwe soorten.
- `docs/weekrapport.md`: bij "Bronnen" de app-telling noemen.

De bestaande taak, sleutels en het netwerkgeheim veranderen niet: het blijft
`GET /api/stats` met `STATS_KEY`.

## Opt-out in Instellingen

In het blok "Over de app" (of een eigen blok "Privacy") één schakelaar,
standaard **aan** (keuze 1):

> **Anoniem gebruik tellen**
> Eén keer per dag meldt de app dat hij gebruikt is: platform, versie, taal en
> welk deel. Zonder naam of apparaat-ID.

- Sleutel `usageCountingEnabled` (een `static let` in Core, net als
  `LiveShare.enabledKey`).
- Uitzetten werkt meteen: er gaat niets meer, ook geen al geplande melding.
- Staat in beide instellingenschermen: iOS `SquashAnalyzer/Views/SettingsView.swift`
  en de gedeelde (Android) `SharedSettingsView.swift`.
- Teksten in nl en en (`docs/i18n.md`), en een regel in de handleiding
  (`UserManual`) en de handleiding op de website.

## Privacy: website, App Store Connect, Play Console

**Website** (`website/privacy.html` en `website/en/privacy.html`, blok
"Technische verzoekgegevens"), toe te voegen na de zin over de tellingen van
de live-dienst:

> Daarnaast meldt de app (vanaf versie 3.1) hooguit één keer per dag aan de
> live-dienst dat hij gebruikt is, met het platform (iPhone of Android), de
> appversie, de taal en welke delen van de app die dag gebruikt zijn (coach,
> scheidsrechter, analyse, competitie). Er gaat geen apparaat-ID, naam of
> tijdstip mee; de live-dienst telt dit per dag, samen met het land en de regio
> die Cloudflare uit het verzoek afleidt, net als de tellingen hierboven. Om
> niet dubbel te melden onthoudt de app op je telefoon alleen op welke dag hij
> het laatst gemeld heeft. Je kunt dit in Instellingen uitzetten met "Anoniem
> gebruik tellen".

En in de samenvatting onderaan ("Online verwerking vindt plaats bij …") de
gebruikstelling noemen. Publiceren met `npx wrangler deploy -c
server/website-worker/wrangler.jsonc` vanaf de Mac, gelijk met de 3.1-release
naar de store (niet eerder: 3.0 stuurt niets).

**App Store Connect, App-privacy** (Gerd-Jan, in de console, bij het indienen
van 3.1):

- Gegevenstype **Gebruiksgegevens → Productinteractie** toevoegen.
- Doel: **Analyse**.
- Gekoppeld aan de identiteit: **nee**. Tracking: **nee**.
- Ook in `SquashAnalyzer/PrivacyInfo.xcprivacy`:
  `NSPrivacyCollectedDataTypeProductInteraction`, niet gekoppeld, geen
  tracking, doel `NSPrivacyCollectedDataTypePurposeAnalytics` (dat doet de
  bouwer, in de code).
- Apple staat toe dat gegevens die echt niet gekoppeld zijn als "niet gekoppeld
  aan jou" staan; met deze opzet is dat zo. Het label wordt dan "Gegevens die
  niet aan jou zijn gekoppeld: Gebruiksgegevens". Niet gecontroleerd in de
  actuele Apple-documentatie: Apple kent ook een uitzondering voor gegevens die
  "optioneel en zelden" verzameld worden, maar dat geldt hier niet (standaard
  aan, elke dag).

**Google Play Console, Gegevensveiligheid (Data safety)** (Gerd-Jan, in de
console, vóór de 3.1-productierelease):

- Gegevenstype **App-activiteit → App-interacties**: verzameld, niet gedeeld.
- Doel: **Analyse**.
- Verwerkt tijdelijk: nee (het wordt als telling bewaard).
- Verplicht of optioneel: **optioneel** (uit te zetten in de app).
- Versleuteld verzonden: ja (HTTPS).
- Verwijderverzoek: niet van toepassing; er is niets aan een persoon te
  koppelen. Kies het antwoord dat daar het best bij past op het moment van
  invullen.
- Zelfde lijst bijwerken in `docs/opleveren-en-hosting.md` (de afvinklijst
  voor de consoles) en `docs/google-play.md`.

**Toestemming vooraf?** Geen persoonsgegevens, dus de AVG vraagt geen
toestemming. De regel voor het lezen en schrijven op een apparaat (cookieregel,
Telecommunicatiewet) kent in Nederland een uitzondering voor analytische
gegevens met geen of geringe gevolgen voor de privacy; een datum in UserDefaults
zonder ID valt daar naar verwachting onder. Dit is geen juridisch advies; wie
het zeker wil, kiest bij keuze 1 voor "standaard uit" of een vraag bij de eerste
start.

## Waar het in de code komt

**Core (`Packages/SquashAnalyzerCore`, gedeeld via Skip)**, nieuw bestand
`AppUsage.swift`:

- `AppUsagePart` (enum: `coach`, `referee`, `analysis`, `competition`; geen
  Kotlin-sleutelwoorden als case-naam).
- Pure logica, los te testen: `AppUsage.request(today:lastDay:sentParts:part:enabled:)`
  geeft het verzoek dat nu moet gaan, of niets. Datum als tekst met een
  `DateFormatter` met vast patroon `yyyy-MM-dd` en locale `en_US_POSIX` (geen
  `Date.FormatStyle`, valkuil).
- Een `@MainActor final class AppUsage` met `static let shared` (onder de
  statics die de init gebruikt, valkuil), `func appOpened()` en
  `func used(_ part: AppUsagePart)`. Het verzoek gaat via het bestaande
  `LiveTransport` (iOS URLSession, Android `HttpLiveTransport.kt`) en
  `LiveShare.shared.baseURL`; geen nieuwe netwerkcode per platform.
- `AppPlatform.current` ("ios"/"android") bestaat al op de branch
  `claude/gebruikscijfers-app` (commit 46751e8, niet op `main`, stand 27
  oktober 2026): die eerst mergen of overnemen, dan delen live en de
  gebruikstelling hetzelfde platformveld.
- De versie uit `CFBundleShortVersionString` (iOS) en de `versionName`
  (Android); Skip geeft beide via `Bundle.main.infoDictionary`, nakijken op
  Android, anders de versie bij het starten meegeven zoals `appVersion` in de
  instellingen nu.
- Skip-valkuilen om op te letten (`docs/skip-valkuilen.md`): de delen als
  kommatekst of `[String]` bewaren, geen `[String: String]` in een `Codable`;
  geen functie met alleen een optionele aanroep (`guard let … else { return }`);
  lege literals met type; `@Observable` alleen als het nodig is (hier niet).

**Aanroepen**:

- iOS: `ContentView.swift`, in `.onChange(of: scenePhase)` bij `.active`, naast
  `LiveShare.shared.retryPending()`: `Task { await AppUsage.shared.appOpened() }`.
- Android: `MainActivity.onResume()`, naast de `retryPending`-aanroepen:
  `lifecycleScope.launch { AppUsage.shared.appOpened() }`.
- Delen: op het startpunt van elk deel één regel `AppUsage.shared.used(.referee)`
  enz. (coachsessie starten, scheidsrechterswedstrijd starten, wedstrijd- of
  spelersdetail openen, Competitie openen), in de gedeelde UI waar het kan,
  zodat iOS en Android hetzelfde meten.
- Instellingen: de schakelaar in beide instellingenschermen (zie boven).

**Tests**:

- Core (`swift test` én de Skip-test op Android, zie de testtabel in
  `docs/opleveren-en-hosting.md`), nieuw `AppUsageTests.swift` met een
  nep-`LiveTransport` en een vaste datum:
  - eerste keer vandaag stuurt één verzoek met platform, versie, taal;
  - tweede keer dezelfde dag stuurt niets;
  - de volgende dag weer wel;
  - mislukt verzoek: `usageDay` blijft staan, volgende keer opnieuw;
  - 404 telt als gemeld;
  - een nieuw deel stuurt alleen dat deel met `open: false`; hetzelfde deel
    twee keer stuurt één keer;
  - uitgeschakeld stuurt niets;
  - de body bevat geen andere velden dan de afgesproken (assert op de JSON).
- Worker: de tests uit "Server" punt 5.
- `scripts/weekly-stats.py --sample` laat het nieuwe blok zien.
- Handmatig: op de simulator en de emulator één keer openen en met
  `GET /api/stats` (of de test-Worker `squash-live-dev`) zien dat er precies één
  rij bijkomt.

Grootte: Worker S (een middag), app M (een dag inclusief instellingen, teksten
en tests op beide platforms), weekrapport S. Store-formulieren en de
privacypagina: een half uur, gelijk met de 3.1-release.

## Alternatieven, en waarom niet

- **Firebase Analytics / Google Analytics**: staat bewust uit (privacytekst),
  stuurt een installatie-ID mee en deelt met Google. Niet doen.
- **Een willekeurige installatie-ID** (geen persoon, wel per installatie): geeft
  unieke gebruikers per week en retentie, maar is precies de herleidbaarheid die
  Gerd-Jan niet wil, en maakt het label "gekoppeld" twijfelachtig.
- **Cloudflare Analytics Engine** in plaats van `StatsCounter`: pas zinvol bij
  veel meer verkeer (zie het eerdere voorstel).
- **Alleen de stores**: blijft nuttig voor installaties en Play-DAU, maar zegt
  niets over iOS-gebruik en niets over welk deel gebruikt wordt.

## Open keuzes voor Gerd-Jan

1. **Standaard aan of uit?** Voorstel: aan, met de schakelaar in Instellingen
   (opt-out). Uit (opt-in) geeft veel minder cijfers, vergelijkbaar met Apple nu.
2. **Welk deel meten (`parts`)?** Voorstel: ja, de vier delen met de
   gebeurtenissen hierboven. Zonder delen is het alleen "geopend".
3. **Nieuwe installaties tellen (`app-first`)?** Voorstel: ja; kost één lokale
   vlag en geeft een eigen telling van installaties per dag.
4. **Testers apart tellen?** Alleen op iOS betrouwbaar (TestFlight). Voorstel:
   iOS TestFlight als `test`, Android niet onderscheiden.
5. **Versie in de kolom `club` of een tweede tabel?** Voorstel: kolom `club`
   hergebruiken (geen migratie, `GET /api/stats` blijft gelijk), met uitleg in
   de code en de README.
6. **Regio bewaren voor de app-telling?** Het gebeurt nu automatisch voor alles
   (`count()` voegt land en regio toe). Met weinig gebruikers per regio per dag
   is dat grof genoeg, maar het kan ook alleen land worden voor `app`-soorten.
7. **Wanneer**: in de eerste 3.1-testbuild (de Worker kan eerder live), en de
   privacypagina en de console-formulieren bijwerken gelijk met de
   3.1-productierelease.
