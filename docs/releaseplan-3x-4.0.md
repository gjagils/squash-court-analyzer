# Releaseplan: kleine 3.x-releases naast 4.0

Stand: 31 oktober 2026. Tweede versie: de feedback op de eerste versie is
verwerkt. Gerd-Jan wil:

- 3.1 en 3.2 als kleine releases, met bugfixes en kleine wijzigingen;
- de grote features (spelersaccount, centrale badges, zie het
  [voorstel](voorstel-spelersaccount-4.0.md)) als 4.0.

## Advies: alles op `main`, 4.0 achter een vlag

| | **Lange 4.0-branch** | **Op `main` achter een vlag** (advies) |
|---|---|---|
| Hoe | 4.0 op een eigen branch, `main` blijft 3.x | Alles in kleine stukjes naar `main`; 4.0-onderdelen staan uit in 3.x-builds |
| Samenvoegen | Wordt steeds pijnlijker: 4.0 raakt dezelfde bestanden als bijna elke 3.x-fix (Instellingen, beginscherm, Spelers, badges), via Skip ook op Android | Er valt niets samen te voegen |
| Bugfixes | Op twee plekken | Eén keer |
| Past bij de werkafspraken | Nee | Ja: klein committen, direct naar `main` |

## Het grootste risico: het databaseschema

De iPhone-app gebruikt SwiftData. Het schema staat nu op `SchemaV7`. Android
gebruikt Room, nu versie 9.

Stel dat 4.0 een nieuw schema nodig heeft (`SchemaV8`, Room 10) en een tester
installeert een 4.0-build. Dan migreert de database. Gaat hij daarna terug
naar 3.x, dan kan die oudere app de database niet meer openen.

**Afspraak:**
1. **De accountdata blijft buiten het schema.** Het account, de wachtrij, het
   postvak en de gesynchroniseerde wedstrijden komen in een eigen bestand of
   eigen bestanden, zoals Competitie dat nu doet met `TeamMatchStore`. Dan
   verandert er aan SwiftData en Room niets.
2. **Is een schemawijziging toch nodig**, bijvoorbeeld een account-id bij een
   speler, dan gaat die migratie **eerst in een 3.x-build**, met lege kolommen.
   Pas daarna gaat 4.0 de kolommen gebruiken. Zo delen beide lijnen altijd
   hetzelfde schema.
3. Een test controleert dat een 3.x-build een database van de nieuwste
   4.0-build kan openen.

## De vlag: wat zit er in een 3.x-build

- **In Core** komt een vlag `Features.playerAccount`. Die bepaalt of
  menu-items, schermen en netwerkverkeer naar de account-API bestaan.
- **De waarde komt uit de buildconfiguratie:** een Xcode-configuratie en een
  Gradle-`buildConfigField`, zoals de Firebase-waarden nu op Android. Een
  3.x-store-build heeft de vlag vast uit.
- **Geen zware afhankelijkheden.** Inloggen gaat via de REST-API van Firebase
  (zie het voorstel). Daarom komt er geen Firebase-SDK en geen
  `skip-firebase` in de app. De extra code in een 3.x-build is dus klein.
  Apple-inlog gebruikt `AuthenticationServices`, en dat zit al in iOS.
- **Een verborgen ontwikkelaarsschakelaar alleen in debug-builds.** Zo kun je
  4.0 op je eigen telefoon aanzetten zonder aparte build. In een
  store-build zit hij niet. App Review keurt verborgen functies in een
  store-build soms af.

## De live-Worker

Het spelersaccount komt in een eigen Worker. Toch verandert er ook iets aan
de bestaande live-Worker (`squash-live-beta`):

- **koppelen via het SBN-spelerpad** in teamsessies;
- **het clubscherm**, dat zich aanmeldt bij de bestaande teamsessies.

Regels daarvoor:

- **Alleen toevoegen.** Nieuwe velden zijn optioneel. Een 3.x-app die ze
  niet stuurt, werkt precies zoals nu.
- **Nieuwe endpoints** komen naast de bestaande, er verandert niets aan de
  oude.
- De bestaande tests van de Worker blijven ongewijzigd groen. Dat is het
  bewijs dat 3.x niets merkt.

## Versies en builds

- **3.1** = wat nu in de test zit (build 2). Daar alleen nog bugfixes bij,
  dan naar productie.
- **3.2** = de volgende kleine release. Kandidaten (allemaal S of M, geen
  account nodig), uit de [persona-backlog](backlog-personas-2026-10-11.md)
  en de [buildbacklog](wijzigingen-builds.md#backlog):
  - programma in je agenda (T1);
  - vorige uitslag tegen de tegenstander (T5);
  - officiële timers voor de scheidsrechter (R2);
  - SquashLevels-link bij een speler ([plan](plan-squashlevels-profiel.md));
  - voortgang naar de volgende badgetrede;
  - onderlinge stand bij Kies speler.

  Ook de vlag zelf (uit) en eventueel een schemamigratie voor 4.0 (zie
  hierboven) gaan in 3.2.
- **3.3 enzovoort** zolang 4.0 nog niet klaar is.
- **4.0** = spelersaccount en centrale badges, eventueel met het
  clubabonnement.

### Testen in twee lijnen: let op

- **TestFlight:** er kan per toestel maar één versie van de app staan. Een
  tester heeft dus 3.2 **of** 4.0, nooit beide. Hij kan wel terugwisselen,
  maar dat werkt alleen als het schema gedeeld blijft (zie hierboven).
- **Google Play** kijkt alleen naar de versionCode. Een 4.0-build
  (versionCode 4.000.100 en hoger) is altijd hoger dan elke 3.x. Wie een
  4.0-build heeft, **kan niet terug** naar 3.x en krijgt ook de 3.2 uit
  productie niet meer. De proefgroep blijft dus op de 4.0-testtrack tot 4.0
  in productie gaat.
- **Daarom:** maak de 4.0-proefgroep **klein en bewust**, met een paar mensen
  die dat weten en ermee kunnen leven. Bijvoorbeeld jij, één coach en twee of
  drie spelers van je eigen team. Op Play krijgen zij een eigen gesloten
  track. In TestFlight komen ze in een eigen groep "4.0-proef".

`scripts/version.py` rekent al met major en minor. Nodig: een vlag voor de
4.0-buildconfiguratie, en distributie- en uploadscripts die de juiste groep
of track kiezen.

### Testen in beide standen

- De suites draaien **met de vlag uit**. Zo bewijs je dat 3.x niets van 4.0
  laat zien.
- De suites draaien **ook met de vlag aan**. Anders veroudert de 4.0-code op
  `main` ongemerkt.
- Hoe: Core-tests met beide waarden, de iOS-tests met beide
  buildconfiguraties, Android unit tests met beide `buildConfigField`s. De
  connected-tests op de emulator draaien alleen in de stand van de volgende
  upload.

## Werkwijze

1. **Bugfixes en kleine wensen** gaan direct naar `main`, en in de volgende
   3.x-build.
2. **4.0-werk** gaat in kleine stukken achter de vlag naar `main`, met
   tests. Eerst de server, dan de app.
3. **Een 3.x-release** komt van `main` met de vlag uit, nadat beide standen
   groen zijn.
4. **Een 4.0-proefbuild** komt van dezelfde `main` met de vlag aan, voor de
   proefgroep.
5. `docs/wijzigingen-builds.md` krijgt per build twee kopjes: "3.x" en
   "4.0 (achter de vlag)".

## Eerste stappen

1. **3.1 afronden** en naar productie. Het privacylabel moet daarvoor nog
   worden aangepast.
2. ~~Besluiten over de open keuzes~~: genomen op 31 oktober, zie het
   [voorstel](voorstel-spelersaccount-4.0.md#besluiten-van-gerd-jan-31-oktober).
3. ~~Besluit over het schema~~: genomen op 31 oktober. De accountdata komt in
   eigen bestanden en er komt geen migratie.
4. **De vlag en de tests in beide standen** bouwen, in 3.2, met de vlag uit.
5. **De proefgroep samenstellen** en de testers vertellen dat ze tot de
   release op 4.0 blijven.
6. **De 3.2-lijst kiezen** uit de kandidaten hierboven.

## Wanneer is 4.0 klaar

4.0 gaat naar productie als:

- iedereen in de proefgroep minstens één competitieavond heeft gespeeld met
  wedstrijden die door een ander zijn ingestuurd en door de speler zijn
  goedgekeurd;
- eerdere wedstrijden meenemen werkt, en de centrale kaart dan klopt met de
  lokale;
- inloggen werkt op iOS en Android, met e-mail, Apple en Google;
- account verwijderen werkt, met het Apple-token ingetrokken en de data
  weg, en ook het verwijderformulier op de website werkt;
- versturen zonder dekking en daarna opnieuw proberen geeft geen dubbele
  verzoeken;
- de suites zijn groen in beide standen;
- de live-Worker-tests zijn ongewijzigd groen;
- het privacybeleid, de privacylabels in beide stores en de
  verwerkersovereenkomsten zijn geregeld;
- de handleiding, de website en de releasenotes hebben een 4.0-sectie.

Daarna gaat de vlag standaard aan, en wordt de code voor zonder vlag
opgeruimd in 4.1.
