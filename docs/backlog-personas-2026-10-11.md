# Backlog uit de persona-review (11 oktober 2026)

Om door te nemen met Gerd-Jan op 12 oktober. Doel: kiezen wat in de volgende
externe testversie komt (voorstel: **3.0 build 3**) en wat er nog nodig is voor
de launch zodra de Android-testfase klaar is.

Werkwijze: de app is doorgelopen als **coach**, **scheidsrechter** en
**teamgenoot**, aan de hand van de handleiding, de code en de schermen op de
iOS-simulator en Android-emulator (11 oktober). Voor de scheidsrechter is
daarnaast gekeken naar andere squash-scheidsrechterapps en de WSF-regels van
2025 (bronnen onderaan). Niets hiervan is met echte gebruikers getest; de
punten zijn voorstellen.

Grootte: **S** = een paar uur, **M** = een dag, **L** = meerdere dagen.
Voorstel per punt: **B3** (in 3.0 build 3), **Launch** (vóór productie),
**Later**.

## Wat al goed staat

- **Coach**: per punt wie, hoe, waar en met welke slag; soort fout; volley.
  Analyse per game met heatmap, slagen, rallyduur, "waar vallen de punten" en
  lokaal advies (5 regels, met "net als in game 1"); AI Coach met eigen sleutel;
  sinds 9 oktober een profiel per speler over de wedstrijden.
- **Scheidsrechter**: één tik per rally, servicevak met voorkeur per speler,
  LET/STROKE per speler, undo (ook na hervatten), match- en gametimer,
  later instappen, live meekijken, deeltekst en plaatje.
- **Teamgenoot**: Mijn team met stand, programma en spelers van SBN; een
  teamwedstrijd van vier partijen met de SBN-regels; live teampagina waar
  teamgenoten hun eigen partij op zetten; verslag delen in de groepsapp.

## Coach

Vraag: haal je hier genoeg uit om goed te coachen?

Wel: tijdens en na de wedstrijd zie je per game waar punten vallen en wat
werkt. Het grootste gemis zit op het moment dat coaching echt telt (de pauze
tussen games) en in het vervolg na de wedstrijd.

| # | Punt | Waarom | Grootte | Voorstel |
|---|---|---|---|---|
| C1 | **Pauzekaart tussen games**: na "Game klaar" één scherm met 3 korte punten in grote letters (uit het lokale advies), om de speler in de pauze te laten zien | De pauze duurt 2 minuten; het dashboard is te druk om samen met de speler te bekijken | M | B3 |
| C2 | **Snelle invoer** (instelling): alleen wie en hoe (winner/fout), zonder vak en slag | Bij snelle rally's of een eerste keer is 4 tikken per punt veel; liever minder detail dan gemiste punten | M | B3 |
| C3 | **Notitie per game** (tekst, eventueel dicteren) die in de analyse en het verslag terugkomt | Coaches onthouden "backhand-volley te laat" niet tot na de wedstrijd | S | B3 |
| C4 | **Service en return**: punten gewonnen op eigen service versus bij hand-out, per speler | Data is er al (`Point.server`); zegt veel over druk zetten | S | B3 |
| C5 | **Verslag voor de speler** (pdf of plaatje) met analyse, advies en de profiellijn | Nu deel je de score; de analyse zelf blijft op de telefoon van de coach | M | Later |
| C6 | **Scouting**: profiel van een tegenstander (als die opgeslagen is) vóór een wedstrijd, ook vanuit het programma van Mijn team | Het profiel werkt al voor iedere gekozen speler; alleen de ingang ontbreekt | S | Later |
| C7 | **Coachingfocus koppelen aan cijfers** (focus "Backhand" → hoe vaak won/verloor je links achter) | De focus-tags staan nu los van de analyse | M | Later |
| C8 | **Trainingsmodus** (oefenpartij zonder badges en zonder telling in het profiel) | Staat al als vroeg idee op de lijst | M | Later |

## Scheidsrechter

Vraag: werkt dit goed genoeg om als scheidsrechter te nemen?

Wel, voor een clubwedstrijd: de telling, de servicekant en de calls kloppen en
zijn snel. Voor een competitie- of toernooiwedstrijd mist de app wat de regels
van een scheidsrechter vragen en wat andere apps bieden (zie de vergelijking
hieronder). Let op: de WSF-regels zijn in 2025 aangepast (inspelen 4 minuten,
2 minuten tussen games); de bron staat onderaan, te checken of SBN die al volgt.

| # | Punt | Waarom | Grootte | Voorstel |
|---|---|---|---|---|
| R1 | **Scherm blijft aan** tijdens een wedstrijd | In de pauze ging het scherm op slot | S | **Gedaan 11 oktober** (iOS en Android, nog op een telefoon te proberen) |
| R2 | **Officiële timers** met waarschuwing: inspelen 4 min (wissel na 2), 1 min tot start, 2 min tussen games, "15 seconden" en "Time" (trillen of geluid) | Een scheidsrechter moet de tijd bewaken; nu is er alleen een stopwatch | M | B3 |
| R3 | **Conduct**: waarschuwing, conduct stroke, game, match, met de soort overtreding; een conduct stroke verandert het servicevak niet | Regel 14; elke serieuze scheidsrechterapp heeft het | M | B3 |
| R4 | **"No let"** als vastgelegde beslissing, plus **appeals**, met een beslissingenlijst in de wedstrijd | Nu tel je bij "no let" alleen het punt; achteraf is niet terug te zien wat er beslist is | M | B3 |
| R5 | **Best of 3** kiezen (nu altijd best of 5) | Jeugd, toernooien en oefenpartijen; de coachmodus heeft hetzelfde | S | B3 |
| R6 | **Blessuretimer per soort** (3 min eigen, 15 min veroorzaakt, 5 min bloed, 2 min materiaal) en opgave | Op het lastigste moment geen regels opzoeken | M | Later |
| R7 | **Stand omroepen**: tekst in WSF-bewoording op het scherm ("Hand-out, 5-3", "Game ball", "10-all"), optioneel uitgesproken | Helpt clubleden die zelden fluiten | M | Later |
| R8 | **Wedstrijdformulier** als pdf (games, beslissingen, conduct) | SBN werkt met een papieren formulier; de captain voert de uitslag in | M | Later |
| R9 | **Liggend scherm en tablet**, grote stand leesbaar door het glas | Wat Squore en Squash Score Referee gewaardeerd maakt | L | Later |
| R10 | **Invoer zonder te kijken**: Apple Watch, toetsenbord of bluetooth-klikker | Niche, maar gevraagd door scheidsrechters op de galerij | L | Later |

## Teamgenoot

Vraag: kan ik mijn team makkelijk op de hoogte houden en krijg ik betere info
over mijn team?

Wel op de speelavond: de live teampagina en het verslag werken goed. Tussen de
speelavonden is er weinig dat je terug laat komen: geen herinnering, geen
opstelling, geen seizoensoverzicht.

| # | Punt | Waarom | Grootte | Voorstel |
|---|---|---|---|---|
| T1 | **Programma in je agenda** (.ics-export van de wedstrijden van Mijn team) | Klein, en iedereen in het team wil het | S | B3 |
| T2 | **Seizoensoverzicht per teamlid**: partijen, gewonnen/verloren, games, uit de teamwedstrijden in de app en het record van SBN | "Hoe staan we ervoor" gaat nu alleen over het team | M | B3 |
| T3 | **Vergelijken met de SBN-uitslag** na de wedstrijd (staat al op de lijst) | Fouten in de invoer bij SBN vallen dan op | M | Launch |
| T4 | **Opstelling plannen**: wie speelt E1–E4 volgende week, met beschikbaarheid via de teamlink | Captains regelen dit nu in de groepsapp | L | Later |
| T5 | **Tegenstander bekijken**: de vorige uitslag tegen dit team en hun stand, vanuit het programma | De gegevens staan al op de SBN-pagina's die de app leest | S | Later |
| T6 | **Melding als een teamgenoot een partij invult** tijdens een live teamwedstrijd | Nu moet je op Vernieuwen tikken | L (vraagt push) | Later |
| T7 | **Badgecategorie Teamspeler** (staat al op de lijst) | Beloont meedoen aan de competitie | M | Later |

## Naar de volgende externe test (3.0 build 3)

Voorstel: wat op 9–11 oktober gebouwd is (spelersprofiel, lichte modus,
rondleiding, delen en feedback, scherm aan, de fixes uit de core-review) plus
een kleine selectie hierboven: **C1, C3, C4, R2, R3, R4, R5, T1**. Samen
ongeveer vier tot vijf dagen werk. C2 en T2 als er ruimte is.

Vóór de upload:

- Alles op `main` en groen, releasenotes uit `docs/wijzigingen-builds.md`.
- Op de iPhone en de A13 nalopen in licht en donker: analyse, profiel, badges,
  Competitie, live-pagina's.
- Handleiding bijwerken voor wat er nieuw is; de schermafbeeldingen op de
  website en in de stores zijn nog van vóór 3.0.

## Naar de launch

- **Google Play productie**: 12 testers die 14 dagen aaneengesloten in de
  gesloten test zitten (persoonlijk account); de stand staat in de Play
  Console en is niet in deze review gecontroleerd. Daarna de productieaanvraag.
- **App Store 3.0**: de versie 3.0 bestaat nog niet in App Store Connect;
  schermafbeeldingen, "Wat is er nieuw", privacylabel (feedback per mail, live,
  AI Coach) en review-notities (hoe live en Competitie te proberen).
- **Besluit app-icoon**: het iOS-icoon heeft sinds 11 oktober een lichte
  variant voor de lichte weergave van iOS. De App Store toont de standaard
  (lichte) variant; wil je daar het donkere icoon, dan moet het andersom.
- **Play-listing**: beschrijving bijwerken (Competitie, live, badges, profiel,
  lichte modus), nieuwe schermafbeeldingen, data-safety-formulier nalopen.
- **Website**: schermafbeeldingen en de tekst "Nieuwe bètaversie" bijwerken;
  `testen.html` na de launch omzetten naar downloadlinks.
- **Beoordelen-vraag** (uit het testersrapport): pas bij productie, met de
  vraag van Apple en Google na een paar afgeronde wedstrijden.
- **Zicht op crashes**: de app stuurt niets; Xcode Organizer en Play Vitals
  laten crashes zien zonder extra code. Afspreken wie die wekelijks bekijkt.

## Wat nu door Gerd-Jan te testen is (stand 11 oktober, iPhone 3.0 (2.5))

- **Lichte modus**: alle schermen langs, ook analyse na een coachwedstrijd,
  profiel, badges, Competitie en een teamwedstrijd; wisselen tijdens een
  wedstrijd; Systeem met de telefoon op licht en op donker.
- **App-icoon**: iPhone-beginscherm met de telefoon op licht en op donker.
- **Scheidsrechter en coach**: de nadruk op de serveerder in licht.
- **Scherm blijft aan** tijdens een wedstrijd, en gaat weer op slot na afloop.
- **Profiel** van een speler met een paar wedstrijden.
- **Teamwedstrijd**: Vernieuwen bij een gekoppelde partij met games van vóór
  het meetellen; een partij met opgave op twee telefoons.
- **Website en live-pagina's**: de keuze Weergave en de nieuwe tagline.
- **A13**: de nieuwste versie staat er nog niet op (2.3 is van vóór de lichte
  modus).

## Bronnen (scheidsrechter)

- WSF Rules of Singles Squash 2025:
  https://squash.nl/media/ot0ezdzh/250901_world-squash-rules-of-singles-squash-2025.pdf
- SBN algemeen competitiereglement v12:
  https://squash.nl/media/u3rk31tf/algemeen-competitiereglement-versie-12.pdf
- SQUASHREF / RacketRef (PSA Tour): https://racketref.io/
- Swiss Squash Ref App: https://help.my.squash.ch/en/referees/squash-ref-app/
- Squash Score Referee (iOS): https://apps.apple.com/us/app/squash-score-referee/id1093833787
- Squore (Android): https://apkpure.com/squore-squash-ref-tool/com.doubleyellow.scoreboard/amp
- Squash Score Pro (iPhone, Apple Watch): https://apps.apple.com/app/id6758004393
- Rankedin scoreboards: https://rankedin.ladesk.com/276930-9-Scoreboards-

De vergelijking met andere apps komt uit een webonderzoek van 11 oktober en
is niet per app nagelopen.
