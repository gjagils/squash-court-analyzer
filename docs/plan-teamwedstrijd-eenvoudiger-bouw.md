# Bouwplan: teamwedstrijd eenvoudiger (per scherm)

Stand 8 oktober 2026. Uitwerking van `docs/voorstel-teamwedstrijd-eenvoudiger.md`
en het klikbare voorbeeld, gebaseerd op de code van 8 oktober. **Nog niets
gebouwd.** Het voorbeeld is een mock-up: bij het bouwen gebruiken we de
bestaande onderdelen (`ActionButton`, `SectionHeader`, `SharedColors`, de
LIVE-capsule uit `TeamLiveCard`, stijl uit `docs/style/README.md`) en op
iPhone en Android dezelfde plekken, namen en iconen. Alle schermen staan in
`Packages/SquashAnalyzerUI` en draaien via Skip op beide platforms; alleen de
ingang op de iPhone zit in `SquashAnalyzer/Views/HomeView.swift`.

## Uitgangspunten

1. **Gedeeld betekent live.** Een teamwedstrijd is nu lokaal (`TeamMatch`, JSON-
   bestand) tot iemand *Live delen* doet; dan krijgt hij `liveId`, `liveKey`
   en (alleen op die telefoon) `liveOwnerKey`. Het label **GEDEELD** is dus
   `match.isLive`, **EIGEN** is `!match.isLive`. Geen nieuw veld, geen
   schemawijziging (V7 blijft bevroren), geen migratie.
2. **De server hoeft niet te veranderen** voor het eerste deel. Dat houdt de
   API achterwaarts compatibel met de builds van testers.
3. **De rol "captain" bestaat niet.** De eigenaar is de telefoon die live zette
   (`isLiveOwner`); alle andere deelnemers hebben dezelfde schrijfsleutel.
4. **Kijkerslink en meedoenlink blijven gescheiden** (besluit 8 oktober): de
   meedoenlink bevat de schrijfsleutel en gaat niet naar supporters.
5. **Eén gedeeld onderdeel voor het label**, `TeamShareBadge` in
   `SquashAnalyzerUI`, gebruikt op elk scherm hieronder. Niet per scherm een
   eigen tekstje of kleur.
6. **Skip-regels** (`docs/skip-valkuilen.md`): geen `CharacterSet`, geen
   splitsen met Foundation-extra's, nieuwe views klein houden. Lees dat bestand
   voor het bouwen.

### Afwijkingen van het voorbeeld

| Voorbeeld | Bouwplan | Waarom |
| --- | --- | --- |
| "2 telefoons schrijven mee" | "2 van 4 partijen komen van teamgenoten" | De server weet niet hoeveel telefoons meeschrijven. `TeamPartij.fromLive` laat wel zien welke partijen van een ander komen. Een echt telefoonaantal kan later (fase 3). |
| "door Mark" bij elke partij | alleen de speler die de partij speelde (al aanwezig) | Een partij op de server heeft geen schrijver, alleen spelersnamen. |
| Deelschakelaar standaard aan | open vraag (hieronder) | Delen stuurt voornamen en de stand naar de server. |

## Scherm 1: Competitie, de lijst

**Nu:** `SharedTeamMatchesView` (twee knoppen, daaronder `TeamMatchCard`
per wedstrijd, nieuwste eerst).

**Wijzigen:**
- `TeamMatchCard` krijgt rechtsboven `TeamShareBadge(match)` naast de dagtekst
  (nu staat daar al de winnaar of "BEZIG"; de badge komt vóór de winnaar).
- Lijst opdelen onder `SectionHeader("GEDEELD MET MIJN TEAM")` en
  `SectionHeader("ALLEEN OP MIJN TELEFOON")` (alleen tonen als beide groepen
  bestaan; bij één groep geen kopje).
- Knoppen en teksten blijven: *Nieuwe teamwedstrijd*, *Deelnemen met link of
  code*.

**Test:** `CompetitionScreenTest.kt` (Android) uitbreiden met een gedeelde en
een eigen wedstrijd; de bestaande Core-tests blijven gelijk.

## Scherm 2: Nieuwe teamwedstrijd

**Nu:** `NewTeamMatchSheet` kiest uit het programma van Mijn team of laat zelf
invullen; `onCreate(TeamMatch)` bewaart en opent.

**Wijzigen:**
- Onder de keuze een rij **Deel met mijn team** (schakelaar). Bij aan: na
  `store.save` meteen dezelfde stappen als `goLive()` in `SharedTeamMatchView`
  (create, bewaren, `pushAll`). Die stappen verhuizen naar één functie in Core
  (`TeamLive`/`TeamMatchSupport`) zodat het nieuwe scherm en het
  teamwedstrijdscherm dezelfde code gebruiken.
- Lukt live zetten niet (geen internet): de wedstrijd blijft **EIGEN**, met
  melding "Delen lukte niet, probeer het straks op het teamwedstrijdscherm".
  Niet blokkeren.
- Na aanmaken opent het deelscherm (scherm 4) als delen aan stond.

## Scherm 3: Teamwedstrijd

**Nu:** `SharedTeamMatchView`: kop, `partijenList`, `TeamLiveCard`, *Deel
verslag*, *Verwijder teamwedstrijd*.

**Wijzigen:**
- Bovenaan een banner (`TeamShareBanner`, bij `TeamShareBadge`):
  - gedeeld: "GEDEELD MET TEAM · eigenaar jij" of "· eigenaar een teamgenoot"
    (`isLiveOwner`), plus "N van 4 partijen komen van teamgenoten"
    (`partijen.filter { $0.fromLive == true }.count`);
  - eigen: "EIGEN · alleen op deze telefoon".
- `TeamLiveCard` wordt `TeamShareCard`: de drie knoppen (*Live delen*, *Deel
  kijkerslink*, *Nodig teamgenoten uit*) worden één knop **Deel met team en
  supporters** (opent scherm 4) en bij EIGEN **Deel met mijn team**. *Vernieuwen*
  en *Live stoppen* / *Live verlaten* blijven, nu onder de kop.
- De code-regel ("Code om mee te doen: …") verhuist naar scherm 4.

## Scherm 4: Deelscherm (nieuw)

**Nieuw bestand** `TeamShareSheet.swift`, twee groepen:

- `SectionHeader("VOOR SUPPORTERS")`: tekst met alleen `/t/<id>`
  (`TeamLiveTexts.viewers`), knop **Deel kijkerslink**, onder de tekst "Kijken
  kan zonder app".
- `SectionHeader("VOOR TEAMLEDEN")`: `TeamLiveTexts.invite` met link en code,
  knop **Nodig teamleden uit**.
- Bij alleen-eigen (nog niet live): één knop **Deel met mijn team** die live
  zet en daarna dezelfde twee groepen toont.
- Wie niet de eigenaar is, ziet beide groepen ook (een teamgenoot kan
  doorsturen). Alleen *Live stoppen* blijft bij de eigenaar.

`TeamLiveTexts` blijft de plek voor de berichtteksten; de tekst
"Gebeurt er niets? …" (`CardInbox.newerAppText`) blijft in de uitnodiging.

## Scherm 5: Deelnemen

**Nu:** `SharedTeamJoinView`: link of code plakken, team kiezen, `join`,
daarna `onJoined(match)` opent het overzicht.

**Wijzigen:**
- Na `Deelnemen` opent het teamwedstrijdscherm met een korte regel bovenaan:
  "Tik op jouw partij en zet er een wedstrijd op." (alleen de eerste keer, niet
  bewaard als instelling; verdwijnt zodra een partij van jou is ingevuld).
- Team vooraf gekozen via Mijn team werkt al (`TeamMatch.sameTeam`); de
  uitleg daaronder in de UI mag korter.
- Foutteksten blijven.

Open voor later: automatisch de partijkeuze openen (voorstel punt 2). Eerst
kijken of de regel hierboven genoeg is.

## Scherm 6: Partij (E1 tot en met E4)

**Nu:** `TeamPartijEditor` toont spelers, "Hield je deze partij bij…"
(`Kies wedstrijd` opent `TrackedMatchPicker` met *Coach*, *Scheidsrechter* en
bijgehouden wedstrijden) en daaronder de handmatige games.

**Wijzigen:** alleen het bovenste deel, de volgorde en de woorden. De drie
manieren staan bovenaan als drie duidelijke keuzes:
1. **Nieuwe wedstrijd starten** (Coach of Scheidsrechter) → bestaand
   `onTrack(partij, kind)`.
2. **Eerder getelde wedstrijd koppelen** → bestaande lijst uit
   `TrackedMatchPicker` (dezelfde `entries`, dezelfde dagsortering).
3. **Alleen de games invullen** → bestaande game-invoer.

Bovenaan de partij `TeamShareBadge` en de regel "Je werkt in de gedeelde
teamwedstrijd" of "in je eigen teamwedstrijd". `TrackedMatchPicker` zelf
verandert alleen van kop (*NIEUWE WEDSTRIJD BIJHOUDEN* blijft). De koppel- en
trackinglogica (`TeamMatchSupport.link`, `track`, `target(forMatchId:)`) blijft
ongewijzigd.

## Scherm 7: Wedstrijd starten (Coach of Scheidsrechter)

**Nu:** `MatchSetupView` heeft *Onderdeel van een teamwedstrijd*. Komt de
gebruiker uit scherm 6, dan is `teamTarget` al bekend en slaat de setup de
vragen over.

**Wijzigen:** niets in de keuzelogica. Een regel in de setup toont de gekozen
teamwedstrijd met `TeamShareBadge`, zodat zichtbaar is of dit een gedeelde is.

## Scherm 8: Tijdens het tellen

**Nu:** `CoachSessionView` en `RefereeSessionView` kennen `activeTarget`.
Hebben ze een doel, dan gaat de stand bij elke punt naar de teampagina als de
teamwedstrijd live is.

**Wijzigen:** een kleine regel boven in het scherm, alleen met een doel:
`TeamShareBadge` + "Telt mee voor Delft 7 – All Inn 3 · E2". Niet als
nieuwe knop, geen extra navigatie. De regel gebruikt `activeTarget`; of de sessie de
teamwedstrijd al bij de hand heeft om `isLive` te lezen, moet bij het bouwen
nog worden nagegaan.

## Scherm 9: Kijkerspagina

`server/live-worker/public/team.html` blijft zoals hij is: alleen kijken, geen
knoppen om iets in te vullen. Een regel "Je kijkt mee" is niet nodig.

## Server

Geen wijziging in fase 1 en 2. De API (`POST /api/team`, `PUT …/partij/:slot`,
`GET …/verify`, `DELETE`) dekt alles. Worden de gedeelde schrijfsleutel en de
schrijfrechten per partij later beperkt of een telefoonaantal toegevoegd
(fase 3), dan komt dat als nieuw, optioneel veld erbij (oudere builds negeren
het).

## Fases en volgorde

**Fase 1: label, deelscherm en teksten** (klein; geen logica):
`TeamShareBadge` en `TeamShareBanner`, scherm 1, 3, 4 en 8, de woorden in 5 en
6. Alles op beide platforms in één keer.

**Fase 2: delen bij aanmaken en partijkeuze** (middel): schakelaar in scherm 2,
`goLive`-logica naar Core, bovenaan scherm 6 de drie keuzes.

**Fase 3 (alleen als nodig na een speeldag):** telefoonaantal, schrijver per
partij, schrijfrechten per partij, eigenaarschap overdraagbaar maken.

## Tests

| Wat | Waar |
| --- | --- |
| `isLive` naar label, "N van 4 komen van teamgenoten", de gedeelde `goLive`-functie (nep-transport) | Core: `TeamLiveTests`, `TeamMatchTests` |
| Lijst met gedeelde en eigen wedstrijd, deelscherm met twee groepen, partij met drie keuzes | Android: `CompetitionScreenTest` en een nieuwe test voor het deelscherm |
| Doorloop op simulator en emulator naast elkaar, één telefoon als eigenaar, één als deelnemer, tegen `live.squashanalyzer.com` | handmatig, zoals bij 6 oktober |
| Worker: geen wijziging, `server/live-worker/test/team.test.js` blijft groen | Worker |

Alle suites uit `docs/opleveren-en-hosting.md` draaien vóór een push naar
`main`. Nooit `connectedDebugAndroidTest` met de Samsung A13 aangesloten.

## Documentatie bij elke fase

`docs/wijzigingen-builds.md` (releasenotetekst), `ARCHITECTURE.md` (Competitie),
de handleiding op de website (`website/handleiding/iphone.html` en
`android.html`, publiceren vanaf de Mac) en `docs/bewuste-keuzes.md` voor het
besluit over kijkerslink en meedoenlink.

## Open vragen voor Gerd-Jan

1. **Staat delen bij een nieuwe teamwedstrijd standaard aan?** Dan gaan
   voornamen en de stand naar de server zodra je aanmaakt; bij uit gebeurt dat
   pas als je zelf deelt. Voorstel: aan, met de privacyzin onder de
   schakelaar.
2. **Volstaat "N van 4 partijen komen van teamgenoten"** in plaats van een
   telefoonaantal?
3. **Eigenaarschap overdraagbaar** (nu valt *Live stoppen* weg als de
   eigenaarstelefoon wegvalt; het alarm wist na 2 uur toch alles)? Voorstel:
   niet bouwen, het is een teamavond.
4. **Beginnen met fase 1?** Dan zit er niets in dat de bestaande
   gebruiker verrast; fase 2 pas na een speeldag met deze versie.
