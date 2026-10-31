# Voorstel: spelersaccount met centrale badges (4.0)

Stand: 31 oktober 2026. Dit is een uitwerking. Er is nog niets gebouwd.
Gerd-Jan wil eerst zien wat het betekent voor:

- de opslag;
- de hoeveelheid data;
- de plek waar de data staat;
- de beveiliging;
- de kosten.

Daarna beslist hij. De bijbehorende planning (3.1 en 3.2 klein, dit als 4.0)
staat in [releaseplan 3.x en 4.0](releaseplan-3x-4.0.md).

## Het idee (besluiten van Gerd-Jan, 31 oktober)

- **Jij als speler staat centraal.** Je hebt één account. Wedstrijden die over
  jou gaan komen daar terecht, wie ze ook invoert: je coach, de
  scheidsrechter of jijzelf.
- **Je eigen kaart wordt uitgebreid.** Je profielkaart, vorm, trend en badges
  worden berekend uit al jouw geaccepteerde wedstrijden. De kaarten van andere
  spelers blijven zoals nu: lokaal, alleen uit de wedstrijden op die
  telefoon.
- **Iedereen mag een wedstrijd voor je laten tellen.** Na de wedstrijd
  beoordeel jij of je hem wilt gebruiken. Er is dus geen lijst van vaste
  invoerders. Jij beslist per wedstrijd.
- **Inloggen kan op drie manieren:** met e-mail en wachtwoord, met Apple of met
  Google.
- **Het account is vrijwillig.** De app blijft zonder account werken zoals nu.

## Hoe het werkt voor de gebruiker

1. **Account maken.** Instellingen → Mijn account. Je logt in met e-mail en
   wachtwoord, met Apple of met Google. Daarna kies je "Dit ben ik": je
   SBN-speler uit Mijn team, of alleen je naam als je niet bij SBN speelt. Je
   geeft toestemming met één duidelijke vraag. Daar staat bij wat er
   bewaard wordt en waarom.
2. **Herkend worden.** Een ander moet jou kunnen kiezen als speler in een
   wedstrijd. Dat kan op drie manieren:
   - **automatisch via het SBN-spelerpad**: speel je in een teamwedstrijd, dan
     weet de app al wie je bent;
   - **met je spelerscode of QR-code**: die laat je zien aan de coach, en die
     koppelt hem aan een speler in Spelers;
   - **via een link die je deelt**, zoals de kaartlinks nu.
3. **Wedstrijd invoeren.** Je coach of de scheidsrechter speelt de wedstrijd
   zoals nu. Is een van de spelers gekoppeld aan een account, dan stuurt de
   app na afloop een compacte versie naar de server, geadresseerd aan die
   speler. Voor de invoerder verandert er verder niets.
4. **Beoordelen.** Je krijgt een melding: "Nieuwe wedstrijd van Peter, 30 okt,
   3-1 tegen Mark. Gebruiken?" Je kunt kiezen:
   - **Gebruiken**: de wedstrijd telt mee voor je badges, kaart, vorm en
     trend.
   - **Niet gebruiken**: de wedstrijd wordt van de server gewist.
   - **Geen antwoord binnen 30 dagen**: de wedstrijd wordt ook gewist.

   Wedstrijden die je zelf invoert, tellen meteen mee.
5. **Dubbele wedstrijden.** Voeren de coach en de scheidsrechter dezelfde
   partij in, dan herkent de server dat aan de datum, de tegenstander en de
   uitslag. Je ziet dan één verzoek met de keuze welke versie je gebruikt. De
   versie van de coach heeft meer details.
6. **Op elke telefoon.** Log je in op een tweede telefoon, dan staan je
   kaart en badges daar ook.

## Welke data, en hoeveel

Het uitgangspunt is: zo weinig mogelijk centraal. De volledige analyse blijft
op de telefoon van wie hem invoerde. Dat zijn onder meer de notities per
game, het advies, de AI Coach en foto's van tegenstanders.

| Gegeven | Inhoud | Grootte |
|---|---|---|
| Account | e-mail, inlogmethode, aanmaakdatum, toestemmingsdatum | < 1 KB |
| Spelersprofiel | naam, eventueel SBN-spelerpad, club, eigen foto (optioneel) | 1 KB + foto 30–60 KB |
| Wedstrijd voor de badges | datum, tegenstander (alleen naam), uitslag per game, per rally: winnaar, soort punt, vak, slag, duur, volley, serveerder. Dit is wat `BadgeMatchInput` nu ook gebruikt | ca. 2–3 KB (een wedstrijd van 4 games en ~95 rally's, gemeten in het huidige formaat) |
| Samenvatting voor trend en vorm | winners, fouten, slagen, vakken, rallyduur. Dit is wat `PlayerTrend` nu per wedstrijd uitrekent | ca. 0,3 KB |
| Behaalde badges | badge, wedstrijd, datum | < 0,1 KB per stuk |
| Openstaande verzoeken | dezelfde wedstrijd plus van wie hij komt, maximaal 30 dagen | ca. 3 KB, tijdelijk |

Ter vergelijking: een volledige coachwedstrijd zoals de app hem nu bewaart is
ongeveer 26 KB.

**Per speler:** een actieve competitiespeler speelt zo'n 40 tot 80 gemeten
wedstrijden per seizoen. Dat is **ongeveer 150–250 KB per seizoen**, plus
een foto.

| Spelers met account | Data per jaar (zonder foto's) | Foto's |
|---|---|---|
| 500 | ca. 0,1 GB | 25 MB |
| 5.000 | ca. 1 GB | 250 MB |
| 50.000 | ca. 10 GB | 2,5 GB |

Ter vergelijking: SBN heeft enkele duizenden competitiespelers. 5.000
accounts is al een groot succes. 50.000 accounts is het scenario "heel
Nederland en België plus het buitenland".

## Waar zetten we het neer

Ja, dit wordt **een echte database**. De live-server bewaart nu alleen
tijdelijke dingen in Durable Objects: een live wedstrijd wordt na twee uur
gewist. Accounts en wedstrijden moeten jaren blijven staan, en je wilt
erin kunnen zoeken. Bijvoorbeeld "welke verzoeken staan er voor speler X"
of "alle spelers van All Inn" voor het clubscherm.

Advies: blijf bij Cloudflare. Daar draait alles al, en je hebt Workers Paid.

| Onderdeel | Waar | Waarom |
|---|---|---|
| Database | **Cloudflare D1** (SQLite), aangemaakt met jurisdictie `eu` | Een gewone SQL-database naast de Worker die er al is. De data staat gegarandeerd in de EU, net als de live-sessies nu (`LIVE_JURISDICTION = "eu"`). De jurisdictie kan alleen bij het aanmaken worden gekozen. D1 heeft **Time Travel**: je kunt de database tot 30 dagen terugzetten |
| Foto's | **Cloudflare R2** met jurisdictie `eu`, of in eerste instantie geen foto's | Bestanden horen niet in de database |
| Inloggen | Zie hieronder | |
| Live, team, clubscherm | Blijft in Durable Objects | Tijdelijk en realtime, zoals nu |

De API komt in de bestaande Worker (`server/live-worker`) onder `/api/v4/...`,
of in een aparte Worker `squash-account`. Mijn advies is een **aparte
Worker**. Dan raakt een fout in de accountcode het live meekijken op de
competitieavond niet, en kun je ze los uitrollen.

### Inloggen: zelf bouwen of een dienst

E-mail met wachtwoord is het lastigste deel. Het vraagt het volgende:

- wachtwoorden veilig bewaren;
- het e-mailadres bevestigen;
- wachtwoord vergeten, met een resetmail;
- bescherming tegen raden van wachtwoorden;
- inloggen met Apple en Google controleren.

| | **A. Firebase Authentication** (advies) | **B. Zelf in de Worker** |
|---|---|---|
| E-mail + wachtwoord, Apple, Google | Alles kant-en-klaar, ook bevestigingsmail en wachtwoord vergeten | Alles zelf bouwen, plus een maildienst voor de mails |
| Beveiliging | Wachtwoorden en beveiliging tegen inbraakpogingen bij Google | Ons eigen werk en onze eigen verantwoordelijkheid |
| Waar staat het | Alleen de inloggegevens (e-mail, uid) bij Google, mogelijk buiten de EU. **Alle squashdata blijft in D1 in de EU** | Alles in de EU |
| Al aanwezig | Er is al een Firebase-project voor de pushmeldingen op Android | Nee |
| Kosten | Gratis tot ongeveer 50.000 actieve gebruikers per maand | Gratis, plus de maildienst |
| Op iOS en Android | Firebase-SDK; voor de gedeelde code is er `skip-firebase` (nog na te gaan of de Auth-module alles dekt) | Eigen schermen, eigen code |

Bij A stuurt de app bij elk verzoek een kort geldig token van Firebase mee. De
Worker controleert dat token met de openbare sleutels van Google. Pas dan
geeft hij data vrij. Firebase weet dus alleen wie je bent. Wat je speelt,
ziet Firebase niet.

**Let op bij Apple:** wie inloggen met Google aanbiedt, moet ook inloggen met
Apple aanbieden. Dat zit in beide varianten.

## Hoe houden we het veilig

**Toegang**
- Elk verzoek naar de account-API heeft een geldig inlogtoken nodig.
- De server geeft **alleen je eigen data** terug. Een andere speler kan je
  kaart niet ophalen, behalve via een kaartlink die je zelf deelt, zoals nu.
- Een invoerder kan een wedstrijd alleen **afleveren** in iemands
  postvak. Bekijken, wijzigen of iets anders van die speler zien kan hij
  niet.
- Het postvak is beschermd tegen spam:
  - een limiet per invoerder per dag, met de bestaande `LiveLimiter`;
  - je kunt een afzender blokkeren;
  - verzoeken worden na 30 dagen automatisch gewist.

**Opslag**
- De database staat in de EU (jurisdictie `eu`) en is versleuteld opgeslagen
  door Cloudflare.
- Wachtwoorden worden nooit door ons bewaard: bij A doet Firebase dat, bij B
  bewaren we ze alleen als sterke hash.
- Geheimen staan alleen als Worker-secrets, nooit in git. Dat is nu ook al
  zo voor de push-sleutels.
- Een back-up kan via D1 Time Travel (30 dagen terug). Daarnaast komt er een
  wekelijkse export naar R2 in de EU.
- In de logs komen geen namen of e-mailadressen. De observability staat nu
  aan; die moet dit respecteren.

**Rechten van de gebruiker (AVG)**
- Toestemming wordt vooraf en apart gevraagd. Een account is nooit
  verplicht.
- Je kunt je account verwijderen, in de app en via een webpagina. Apple en
  Google verplichten allebei het verwijderen in de app; Google wil ook een
  weblink. Daarbij gaan alle wedstrijden, verzoeken en badges direct weg, ook
  uit de verwijderde-lijst. In de Time Travel-back-up blijven ze nog
  hoogstens 30 dagen staan, en dat zetten we in de privacytekst.
- Je kunt je data downloaden als één bestand. Dat lijkt op de back-up die er
  nu is.
- **Jeugdspelers:** in Nederland moet een ouder toestemming geven onder de 16
  jaar. Er zijn twee mogelijkheden:
  - een account pas vanaf 16;
  - bij jongere spelers toestemming van een ouder vragen, bijvoorbeeld via het
    e-mailadres van de ouder.

  Dit moet een bewuste keuze zijn.
- De tegenstander krijgt niets en wordt alleen met een naam bewaard, net als
  nu in de geschiedenis.

**Papierwerk**
- Het privacybeleid moet herschreven worden, in het Nederlands en het Engels.
  Het moet vermelden:
  - een account;
  - waar de data staat;
  - hoe lang de data bewaard wordt;
  - Firebase als verwerker.
- Verwerkersovereenkomsten: Cloudflare en Google bieden die standaard aan.
- De privacylabels in App Store Connect en Play moeten worden aangepast. Er
  komen contactgegevens bij (e-mail), gebruikersinhoud en een gebruikers-ID,
  allemaal **gekoppeld aan identiteit**. Alles blijft zonder tracking.

## Kostenschatting

De bedragen komen van de prijspagina's van Cloudflare en Google zoals ik ze
op 31 oktober 2026 vond. **Controleer ze vlak voor het bouwen.**

**Wat er al betaald wordt:** Workers Paid kost $5 per maand. Daarin zit onder
meer:

| Wat | Inbegrepen per maand | Daarboven |
|---|---|---|
| Worker-verzoeken | 10 miljoen | |
| D1 en Durable Objects (SQLite): opslag | 5 GB | D1 ca. $0,75 per GB per maand, Durable Objects $0,20 |
| D1 en Durable Objects (SQLite): rijen schrijven | 50 miljoen | $1 per miljoen |
| D1 en Durable Objects (SQLite): rijen lezen | 25 miljard | |
| R2 | 10 GB | ca. $0,015 per GB per maand |
| Firebase Authentication | gratis tot ongeveer 50.000 actieve gebruikers per maand | |

**Uitgangspunten:**
- Een speler opent de app zo'n 30 keer per maand en synchroniseert dan
  2–3 keer.
- Hij speelt 8 wedstrijden per maand.
- Per wedstrijd zijn er zo'n 10 schrijfacties: wedstrijd, verzoek,
  beoordeling, badges, samenvatting en indexen.

| Scenario | Verzoeken per maand | Rijen geschreven per maand | Opslag na 1 jaar | Extra kosten per maand |
|---|---|---|---|---|
| 500 spelers | ca. 45.000 | ca. 40.000 | 0,1 GB | **$0**, valt binnen de $5 |
| 5.000 spelers | ca. 450.000 | ca. 400.000 | 1,2 GB | **$0**, valt binnen de $5 |
| 50.000 spelers | ca. 4,5 miljoen | ca. 4 miljoen | 12 GB + 2,5 GB foto's | **ca. $5–10** (opslag boven 5 GB). Firebase zit rond de grens van het gratis deel |

Voor het clubscherm en de live-sessies verandert er niets. Die vallen al
binnen het huidige abonnement.

**Conclusie:** tot enkele duizenden spelers kost dit niets extra bovenop de
$5 die je al betaalt. Pas bij tienduizenden spelers wordt het een paar tientjes per
maand. De echte kosten zitten in de tijd voor bouwen, testen en onderhoud,
en in het privacypapierwerk.

**Niet meegerekend, voor later:**
- **Een abonnement voor clubs.**
  - Koopt een club in de app, dan houdt Apple of Google 15–30% in.
  - Betaalt een club via de website, bijvoorbeeld met iDEAL, dan zijn de
    kosten een paar procent. Of dat mag zolang de app er niet naar verwijst,
    moet nog worden uitgezocht.
- **Een eigen maildienst**, alleen bij variant B. Kleine aantallen zijn vaak
  gratis.

## Open keuzes voor Gerd-Jan

1. Firebase Authentication (A) of zelf bouwen (B)?
2. Foto's in het account meteen, of later?
3. Jeugd: een account vanaf 16, of toestemming van een ouder?
4. Moet een niet-SBN-speler (recreant, buitenland) ook een account kunnen
   maken? Mijn advies is ja: dan is alleen de naam nodig.
5. Komt het clubabonnement ook in 4.0, of eerst alleen spelersaccounts?

## Grootte (ruw)

| Onderdeel | Grootte |
|---|---|
| Accountschermen en inloggen op iOS en Android, met toestemming en verwijderen | L |
| Account-Worker met D1, API, postvak, tests | L |
| Koppelen van spelers (SBN-pad, code of QR) en versturen na een wedstrijd | M |
| Beoordelen (postvak in de app, melding, dubbele wedstrijden) | M |
| Badges en kaart uit de centrale wedstrijden, synchroniseren tussen telefoons | L |
| Privacybeleid, labels, verwijderpagina, handleiding | M |

Samen is dit enkele weken werk. Het is dus terecht een 4.0.
