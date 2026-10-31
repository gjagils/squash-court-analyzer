# Voorstel: spelersaccount met centrale badges (4.0)

Stand: 31 oktober 2026. Tweede versie, met de feedback verwerkt. De keuzes
zijn gemaakt (zie Besluiten). Er is nog niets gebouwd. Gerd-Jan wil eerst zien wat dit betekent
voor:

- de opslag;
- de hoeveelheid data;
- de plek waar de data staat;
- de beveiliging;
- de kosten.

Daarna beslist hij. De planning (3.1 en 3.2 klein, dit als 4.0) staat in het
[releaseplan 3.x en 4.0](releaseplan-3x-4.0.md).

## Het idee (besluiten van Gerd-Jan, 31 oktober)

- **Jij als speler staat centraal.** Je hebt één account. Wedstrijden die over
  jou gaan komen daar terecht, wie ze ook invoert: je coach, de
  scheidsrechter of jijzelf.
- **Je eigen kaart wordt uitgebreid.** Je profielkaart, vorm, trend en badges
  worden berekend uit al jouw geaccepteerde wedstrijden. De kaarten van andere
  spelers blijven zoals nu: lokaal, alleen uit de wedstrijden op die
  telefoon.
- **Iedereen mag een wedstrijd voor je insturen.** Na de wedstrijd beoordeel
  jij of je hem wilt gebruiken.
- **Inloggen kan op drie manieren:** met e-mail en wachtwoord, met Apple of met
  Google.
- **Het account is vrijwillig.** De app blijft zonder account werken zoals nu.

## Keuzes in het ontwerp

### 1. Heeft de invoerder een account nodig? Advies: nee

Als de coach en de scheidsrechter ook moeten inloggen, is dat een forse
drempel. Dan komen er veel minder wedstrijden binnen. Daarom:

- **Insturen mag zonder account.** De app krijgt een eigen
  **apparaatsleutel**, net zoals een live-sessie nu een schrijfsleutel heeft.
  Een wedstrijd insturen gaat met die sleutel.
- **Limieten** gelden per apparaatsleutel en per IP-adres, met de bestaande
  `LiveLimiter`. Bijvoorbeeld 20 wedstrijden per apparaat per dag.
- **Afzender blokkeren** gaat per apparaatsleutel. In een verzoek staat de naam
  die de invoerder in de app gebruikt, bijvoorbeeld de coachnaam uit
  Instellingen.
- **Heeft de invoerder wel een account**, dan staat dat bij het verzoek
  ("van Peter, geverifieerd"). Dat geeft extra vertrouwen, maar is niet nodig.

Alleen **je eigen data lezen en beheren** vraagt om inloggen.

### 2. Wie rekent de badges uit? Advies: de app

De badgeregels zitten in `BadgeEngine` (Core, Swift). Die regels naar
JavaScript overzetten voor de server betekent twee regelsets die gelijk
moeten blijven. Dat gaat op den duur mis. Daarom:

- **De server bewaart alleen** de ruwe wedstrijden (het compacte formaat
  hieronder) en de awards.
- **De app rekent.** Na inloggen of synchroniseren haalt de app je
  geaccepteerde wedstrijden op en draait de bestaande `BadgeEngine`
  eroverheen. Nieuwe awards stuurt hij terug naar de server.
- **Verwijderde awards** worden bewaard als markering met datum (een
  "tombstone", het veld `deletedAt`). Zo worden ze bij het samenvoegen niet
  opnieuw toegevoegd. Dat werkt hetzelfde als hoe `CardStore` nu kaartlinks
  samenvoegt.
- **Twee telefoons tegelijk:** awards hebben al een vast id per badge,
  wedstrijd en kaart (`AwardValue.awardId`). Twee telefoons die hetzelfde
  uitrekenen, leveren dus geen dubbele awards op.

Het nadeel: een gebruiker zou met een aangepaste app zichzelf badges kunnen
geven. Dat raakt alleen zijn eigen kaart, dus dat accepteren we.

### 3. Eerdere wedstrijden: niet op nul beginnen

Zonder regeling begint iedereen in 4.0 op nul, en is de centrale kaart lang
leger dan de lokale. Daarom komen er twee knoppen:

- **"Eerdere wedstrijden meenemen"**: één keer, op je eigen telefoon, bij het
  maken van het account. Je kiest welke opgeslagen speler jij bent. De app
  stuurt **alle** wedstrijden met die speler als je eigen wedstrijden, ook
  die van vóór het badgeseizoen. Ze tellen meteen mee.
- **"Eerdere wedstrijden sturen"** bij de coach, in Spelers, bij een speler
  die aan een account gekoppeld is. Die wedstrijden komen als gewone
  verzoeken binnen. De speler beoordeelt ze, zo nodig in één keer ("Alle 12
  gebruiken").

Wedstrijden van vóór het badgeseizoen (`BadgeSeason.start`, 23 oktober 2026)
tellen voor trend en vorm, niet voor badges. Dat regelt `BadgeEngine` al bij
het rekenen in de app, dus zo gaat het nu lokaal ook. Daarom moeten ze wel
mee naar de server: anders mist de centrale trend de eerste maanden.

### 4. De kaart van de coach blijft anders. Dat is bewust

De coach ziet bij Peter lokaal een kaart uit zijn eigen wedstrijden. Peter
ziet centraal een kaart uit alles wat hij heeft goedgekeurd. Die twee
verschillen, en dat is de bedoeling: de data blijft van Peter.

Wil de coach de centrale kaart zien, dan deelt Peter zijn **kaartlink**, zoals
nu al kan. Dat zetten we in de handleiding en bij het koppelen in de app.

## Hoe het werkt voor de gebruiker

1. **Account maken.** Instellingen → Mijn account.
   - Je logt in met e-mail en wachtwoord, met Apple of met Google.
   - De app vraagt je **geboortejaar**, zie Jeugd hieronder.
   - Je kiest "Dit ben ik": je SBN-speler uit Mijn team, of alleen je naam als
     je niet bij SBN speelt.
   - Je geeft toestemming met één duidelijke vraag. Daar staat bij wat er
     bewaard wordt en waarom.
   - Daarna komt de vraag "Eerdere wedstrijden meenemen?".
2. **Herkend worden.** Een invoerder moet jou kunnen kiezen. Dat kan op drie
   manieren:
   - **automatisch via het SBN-spelerpad** in een teamwedstrijd;
   - **met je spelerscode of QR-code**, die de coach koppelt aan een speler in
     Spelers;
   - **via een link** die je deelt.
3. **Wedstrijd invoeren.** Dat gaat zoals nu. Is een speler gekoppeld, dan
   zet de app na afloop een compacte versie in een **uitgaande wachtrij**:
   - elke wedstrijd heeft een vast id, dus opnieuw proberen geeft geen
     tweede verzoek, want de server negeert een id die hij al heeft;
   - zonder dekking in de sporthal blijft de wedstrijd in de wachtrij tot er
     weer verbinding is, ook na het herstarten van de app;
   - de invoerder ziet alleen een klein "wordt verstuurd" bij de wedstrijd.
4. **Beoordelen.** Je krijgt een melding: "Nieuwe wedstrijd van Peter, 30 okt,
   3-1 tegen Mark. Gebruiken?" Je kunt kiezen:
   - **Gebruiken**: de wedstrijd telt mee voor badges, kaart, vorm en trend.
   - **Niet gebruiken**: de wedstrijd wordt van de server gewist.
   - **Geen antwoord**: na 7 dagen komt er een herinnering. Na **90 dagen**
     wordt de wedstrijd gewist.

   Wat je zelf invoert, telt meteen mee.
5. **Dubbele wedstrijden.** Voeren de coach en de scheidsrechter dezelfde
   partij in, dan zie je één verzoek met de keuze welke versie je gebruikt.
   Herkennen gaat in deze volgorde:
   1. **Teamwedstrijd**: team-id plus partij E1–E4. Die zijn eenduidig.
   2. **SBN-spelerpad** van beide spelers plus de datum.
   3. **Terugval**: datum, tegenstandernaam en uitslag. Dat is minder
      betrouwbaar ("Mark" tegen "Mark de Vries", een telfout in de uitslag).
      Daarom voegt de server niets samen, maar vraagt hij het de speler:
      "Is dit dezelfde wedstrijd als …?"
6. **Op elke telefoon.** Log je in op een tweede telefoon, dan haalt die je
   wedstrijden op en rekent dezelfde kaart en badges uit.

## Welke data, en hoeveel

Het uitgangspunt is: zo weinig mogelijk centraal. De volledige analyse blijft
op de telefoon van wie hem invoerde. Dat zijn onder meer de notities, het
advies, de AI Coach en foto's van tegenstanders.

| Gegeven | Inhoud | Grootte |
|---|---|---|
| Account | e-mail en inlogmethode (bij Firebase), geboortejaar, toestemmingsdatum | < 1 KB |
| Spelersprofiel | naam, eventueel SBN-spelerpad, club, eigen foto (optioneel) | 1 KB + foto 30–60 KB |
| Wedstrijd | vast id, datum, eventueel team-id en partij, tegenstander (naam en eventueel SBN-pad), uitslag per game. Per rally: winnaar, soort punt, vak, slag, duur, volley, serveerder. Dit is wat `BadgeMatchInput` nu ook gebruikt | ca. 2–3 KB (4 games, ~95 rally's, gemeten) |
| Awards | badge, wedstrijd, datum, eventueel `deletedAt` | < 0,1 KB per stuk |
| Openstaande verzoeken | dezelfde wedstrijd plus apparaatsleutel en naam van de afzender, maximaal 90 dagen | ca. 3 KB, tijdelijk |

Trend en vorm rekent de app uit de wedstrijden. Daarvoor is geen aparte opslag
nodig. Ter vergelijking: een volledige coachwedstrijd zoals de app hem nu
bewaart is ongeveer 26 KB.

**Per speler:** zo'n 40 tot 80 gemeten wedstrijden per seizoen. Dat is
**ongeveer 150–250 KB per seizoen**, plus een foto.

| Spelers met account | Data per jaar (zonder foto's) | Foto's |
|---|---|---|
| 500 | ca. 0,1 GB | 25 MB |
| 5.000 | ca. 1 GB | 250 MB |
| 50.000 | ca. 10–12 GB | 2,5 GB |

SBN heeft enkele duizenden competitiespelers. 5.000 accounts is al een groot
succes. 50.000 accounts is het scenario "heel Nederland en België plus het
buitenland".

## Waar zetten we het neer

Ja, dit wordt **een echte database**. De live-server bewaart nu alleen
tijdelijke dingen. Accounts en wedstrijden moeten jaren blijven staan en je
wilt erin kunnen zoeken. Advies: blijf bij Cloudflare, waar alles al draait.

| Onderdeel | Waar | Waarom |
|---|---|---|
| Database | **Cloudflare D1** (SQLite), aangemaakt met jurisdictie `eu` | Een gewone SQL-database. De data staat gegarandeerd in de EU, net als de live-sessies nu (`LIVE_JURISDICTION = "eu"`). De jurisdictie kan alleen bij het aanmaken worden gekozen. **Time Travel** zet de database tot 30 dagen terug |
| Foto's | **Cloudflare R2**, jurisdictie `eu`, of in eerste instantie geen foto's | Bestanden horen niet in de database |
| API | Een **aparte Worker** `squash-account` | Een fout in de accountcode raakt het live meekijken op de competitieavond dan niet |
| Live, team, clubscherm | Blijft in Durable Objects | Tijdelijk en realtime, zoals nu |

**Grens van D1:** een D1-database mag op Workers Paid maximaal **10 GB**
zijn. Bij 5.000 spelers is dat jarenlang geen punt. Bij het scenario met
50.000 spelers (10–12 GB per jaar) past het niet meer in één database. Er
zijn twee uitwegen, en die hoeven we nu niet te bouwen:

- **Wedstrijdgegevens naar R2.** De rally's van een wedstrijd gaan als één
  bestand naar R2. In D1 blijven alleen de index, de uitslag en de awards
  staan. Dan is D1 maar een fractie zo groot.
- **Eén database per seizoen.**

Het datamodel houdt hier vanaf het begin rekening mee: de rally's staan in
een eigen kolom of tabel, zodat ze later makkelijk te verhuizen zijn.

### Inloggen

E-mail met wachtwoord is het lastigste deel. Het vraagt het volgende:

- wachtwoorden veilig bewaren;
- het e-mailadres bevestigen;
- wachtwoord vergeten;
- bescherming tegen raden van wachtwoorden.

Advies: **Firebase Authentication, via de REST-API**.

- **Firebase doet de wachtwoorden en de mails.** Firebase bewaart de
  wachtwoorden, verstuurt de bevestigings- en resetmails en beschermt tegen
  raden. Er is al een Firebase-project voor de pushmeldingen op Android.
- **REST-API in plaats van de SDK.** Het inloggen zit dan in gedeelde
  Swift-code (Core), met gewone HTTP-aanroepen. Er hoeft geen Firebase-SDK op
  iOS en geen `skip-firebase` op Android. Dat houdt de 3.x-builds ook vrij van
  een extra afhankelijkheid (zie het releaseplan).
- **Apple op iOS** gaat native (`AuthenticationServices`). Het resultaat gaat
  via de REST-API naar Firebase.
- **Apple op Android** gaat via een webflow. Daarvoor zijn bij Apple een
  **Services ID** en een sleutel nodig. Dat is eenmalig werk, maar geen
  klein werk: reken op een halve dag inrichten en testen.
- **Google** gaat op Android native of via een webflow, en op iOS via een
  webflow.
- **De Worker controleert** bij elk verzoek het korte geldige token van
  Firebase met de openbare sleutels van Google. Firebase weet dus wie je
  bent. Wat je speelt, ziet Firebase niet.

Het alternatief is alles zelf in de Worker bouwen. Dan staat alles in de EU,
maar ligt de beveiliging van de wachtwoorden bij ons, en is er ook een
maildienst nodig. Dat raad ik af.

**Apple-eisen:**
- Wie inloggen met Google aanbiedt, moet ook inloggen met Apple aanbieden.
- Bij het verwijderen van een account moet het **Apple-token worden
  ingetrokken**. Dat is verplicht sinds 2022. Firebase heeft daarvoor een
  aanroep. De app vraagt bij het verwijderen even opnieuw om in te loggen met
  Apple, zodat er een vers token is om in te trekken.

## Hoe houden we het veilig

**Toegang**
- **Lezen en beheren** van je eigen data kan alleen met je inlogtoken. Een
  ander kan je kaart niet ophalen, behalve via een kaartlink die je zelf
  deelt.
- **Insturen** gaat met een apparaatsleutel. Daarmee kun je alleen een
  wedstrijd in iemands postvak leggen. Bekijken of wijzigen kan niet.
- **Spam** wordt tegengegaan op vier manieren:
  - een limiet per apparaatsleutel en per IP;
  - je kunt een afzender blokkeren;
  - verzoeken worden na 90 dagen gewist;
  - een spelerscode is lang genoeg om niet te raden.

**Opslag**
- De database staat in de EU en is versleuteld opgeslagen door Cloudflare.
- Wachtwoorden worden nooit door ons bewaard; dat doet Firebase.
- Geheimen staan alleen als Worker-secrets, nooit in git.
- Back-up: D1 Time Travel (30 dagen terug), plus een wekelijkse export naar
  R2 in de EU.
- In de logs komen geen namen of e-mailadressen.

**Rechten van de gebruiker (AVG)**
- Toestemming wordt vooraf en apart gevraagd. Een account is nooit
  verplicht.
- **Account verwijderen** kan in de app; Apple en Google verplichten dat
  allebei.
  - Alles gaat direct weg: wedstrijden, verzoeken, awards en de
    verwijdermarkeringen (`deletedAt`) daarvan.
  - Het Apple-token wordt ingetrokken.
  - In de back-up blijft het nog hoogstens 30 dagen staan. Dat zetten we in
    de privacytekst.
- **Verwijderen buiten de app:** Google wil ook een weg buiten de app.
  Advies: een **aanvraagformulier** op de website. Je vult je e-mailadres in
  en bevestigt via een link in je mail; daarna wordt het account
  verwijderd. Dat is veel kleiner dan een echte weblogin en voldoet aan de
  eis van Google.
- Je kunt je data downloaden als één bestand. Dat lijkt op de back-up die er
  nu is.
- **Jeugd:** de app kent geen leeftijd, en een SBN-speler heeft in de app geen
  geboortedatum. Daarom vraagt de app bij het maken van een account **altijd
  het geboortejaar**. Onder de 16 is in Nederland toestemming van een ouder
  nodig. Er zijn twee mogelijkheden:
  - **A.** Een account kan pas vanaf 16. Daaronder speel je zoals nu, zonder
    account.
  - **B.** Onder de 16 vul je het e-mailadres van een ouder in. Die bevestigt
    via een link.
- De tegenstander krijgt niets en wordt alleen met een naam en eventueel een
  SBN-pad bewaard.

**Papierwerk**
- Het privacybeleid moet herschreven worden, in het Nederlands en het Engels.
  Het moet vermelden:
  - het account;
  - waar de data staat;
  - hoe lang de data bewaard wordt;
  - Firebase als verwerker;
  - de apparaatsleutel.
- Verwerkersovereenkomsten met Cloudflare en Google (standaard).
- De privacylabels in de stores moeten worden aangepast. Er komen
  contactgegevens (e-mail), gebruikersinhoud en een gebruikers-ID bij,
  allemaal gekoppeld aan identiteit. Alles blijft zonder tracking.

## Kostenschatting

De bedragen komen van de prijspagina's zoals ik ze op 31 oktober 2026 vond.
**Controleer ze vlak voor het bouwen.**

**Wat er al betaald wordt:** Workers Paid kost $5 per maand. Daarin zit:

| Wat | Inbegrepen per maand | Daarboven |
|---|---|---|
| Worker-verzoeken | 10 miljoen | |
| D1: opslag | 5 GB | ca. $0,75 per GB per maand, maximaal 10 GB per database |
| D1: rijen schrijven | 50 miljoen | $1 per miljoen |
| D1: rijen lezen | 25 miljard | |
| R2 | 10 GB | ca. $0,015 per GB per maand |

**Firebase Authentication:** e-mail, Apple en Google zijn zonder limiet gratis
in de gewone Firebase Authentication. De grens van ongeveer 50.000 actieve
gebruikers per maand geldt alleen als je overstapt naar **Identity
Platform**, en dat hebben we niet nodig. Alleen inloggen met sms kost geld,
en dat gebruiken we niet. Dit klopt volgens wat ik vond, maar controleer het
op de officiële prijspagina.

**Uitgangspunten:**
- Een speler opent de app zo'n 30 keer per maand en synchroniseert dan
  2–3 keer.
- Hij speelt 8 wedstrijden per maand.
- Per wedstrijd zijn er zo'n 10 schrijfacties.

| Scenario | Verzoeken per maand | Rijen geschreven per maand | Opslag na 1 jaar | Extra kosten per maand |
|---|---|---|---|---|
| 500 spelers | ca. 45.000 | ca. 40.000 | 0,1 GB | **$0** |
| 5.000 spelers | ca. 450.000 | ca. 400.000 | 1,2 GB | **$0** |
| 50.000 spelers | ca. 4,5 miljoen | ca. 4 miljoen | 12 GB + 2,5 GB foto's | **ca. $5–10**. Wel eerst de rally's naar R2 verhuizen vanwege de grens van 10 GB |

**Conclusie:** tot enkele duizenden spelers kost dit niets extra bovenop de
$5 die je al betaalt. De echte kosten zijn tijd: bouwen, testen, het
inrichten van Apple en Google, en het privacypapierwerk.

**Niet meegerekend, voor later:** een abonnement voor clubs.
- Koopt een club in de app, dan houdt Apple of Google 15–30% in.
- Betaalt een club via de website, dan zijn de kosten een paar procent. Of dat
  mag, moet nog worden uitgezocht.

## Besluiten van Gerd-Jan (31 oktober)

Alle keuzes volgen het advies:

1. **Inloggen:** Firebase Authentication via de REST-API, met e-mail en
   wachtwoord, Apple en Google.
2. **Insturen:** zonder account, met een apparaatsleutel, limieten per
   apparaat en IP, en een blokkeerknop.
3. **Jeugd:** een account pas vanaf 16. Jongere spelers spelen zoals nu,
   zonder account. Het geboortejaar wordt gevraagd bij het maken van een
   account.
4. **Opslag in de app:** de accountdata komt in eigen bestanden, buiten
   SwiftData en Room. Er komt geen schemamigratie voor 4.0.
5. **Foto's:** niet in 4.0. Je foto blijft lokaal zoals nu. Later kan het
   via R2.
6. **Niet-SBN-spelers:** mogen een account maken met alleen een naam. Zij
   worden gekoppeld via een spelerscode of QR-code.
7. **Clubabonnement:** niet in 4.0. Het clubscherm kan al eerder als gratis
   proef met een geheime link draaien.

## Grootte (ruw)

| Onderdeel | Grootte |
|---|---|
| Inloggen in gedeelde code (REST), schermen, geboortejaar, toestemming, verwijderen met intrekken van het Apple-token | L |
| Apple en Google inrichten (Services ID, sleutels, webflow op Android) | M |
| Account-Worker met D1, API, postvak, apparaatsleutels, limieten, tests | L |
| Koppelen van spelers (SBN-pad, code of QR), uitgaande wachtrij | M |
| Beoordelen: postvak, melding, herinnering, dubbele wedstrijden | M |
| Synchroniseren en badges rekenen in de app met `BadgeEngine`, awards met tombstones samenvoegen | M (de regels bestaan al) |
| Eerdere wedstrijden meenemen en sturen | M |
| Privacybeleid, labels, verwijderformulier op de website, handleiding | M |

Samen is dit enkele weken werk. Het is dus terecht een 4.0.
