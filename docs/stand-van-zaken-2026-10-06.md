# SquashAnalyzer: stand van zaken op 6 oktober 2026

Overzicht van de wijzigingen van 1 tot en met 6 oktober, op basis van de
projectdocumentatie, releasenotes en Git-geschiedenis. Referentie:
`main` en `origin/main` op `19fabb8`, na ophalen van de remote refs op
6 oktober. De lokale checkout liep vier commits achter en is met een
fast-forward bijgewerkt. Dit is een documentatiereview, geen nieuwe
functionele testronde of controle van de stores en productieomgeving.

## Al bij testers volgens de opleverdocumentatie

Laatste uploads: **iOS 2.2 (18)** en **Android 0.5 (5)**, op 5 oktober.
De projectbestanden bevatten nog deze versienummers.

| Periode | Verandering |
| --- | --- |
| 1 oktober, builds 15/16 | Baan met keuze uit 6 of 9 vakken, slagen per rij, Kill en de volleyschakelaar. Lokaal coachadvies gebruikt rijen en kanten en herkent patronen tussen games. |
| 1 oktober | Android en iPhone grotendeels gelijkgetrokken: spelersfoto's, geschiedenis, delen, stoppen/hervatten, Undo en analyse. Teamimport via zip of link en back-ups tussen beide platforms; automatische back-ups wekelijks. |
| 3 oktober, build 17 / Android 0.4 | Live meekijken per wedstrijd met foto's, soort unforced error, START GAME en delen als Scorekaart, Verslag of Plaatje. Clubhuis-startscherm en consistente zwarte stijl. |
| 3 oktober | Grote technische opruiming: gedeelde iOS/Android-schermen en opslaglogica, reparaties aan back-ups en hervatten, robuustere live- en kaartlinks, toegankelijkheid en CI. De code-analysebacklog T1–T25 staat als afgerond gemarkeerd. |
| 5 oktober, build 18 / Android 0.5 | Zeventien badges in brons, zilver en goud en zeven nieuwe badges: 37 badgefamilies, 71 varianten. Hoogste trede in beeld; eerdere awards blijven bruikbaar. |
| 4–5 oktober | Grote systeemtekst beter ondersteund; wedstrijdklok telt gesloten tijd niet meer mee. Mijn team markeert het eigen team, heeft Vernieuwen en haalt SBN-gegevens minder vaak op. |

Bronnen: [buildoverzicht](wijzigingen-builds.md),
[releasenotes](../release-notes/), [Android-port](android-port.md),
[afgeronde code-analysebacklog](backlog-code-analyse-2026-10-03.md).

## Gebouwd op main, voor de volgende app-upload

**Competitie en live teamwedstrijden zijn gebouwd voor build 19, maar die
app-build is volgens de actuele opleverdocumentatie nog niet geüpload.**

- Eén teamwedstrijd met vier partijen E1–E4, uit Mijn team of handmatig.
- Partijen handmatig invullen, koppelen aan gespeelde wedstrijden of
  rechtstreeks als coach/scheidsrechter starten. Op de speeldag vraagt de
  app na afloop of een wedstrijd bij de teamwedstrijd hoort.
- Teamstand, competitiepunten en gezamenlijk verslag als Scorekaart,
  Verslag of Plaatje.
- Spelers markeren als **In mijn team**; teamwedstrijden en teamvlag in
  back-upformaat 4 wanneer er teamdata is.
- Eén live kijkerslink voor de hele teamavond, deelnemen via link of code,
  meerdere telefoons die hun eigen partij bijwerken, ook punt voor punt.
- De koppeling van een lopende partij blijft bestaan na verlaten en
  hervatten (fix van 6 oktober, `4eda69f`).

De docs melden geslaagde tests op simulator/emulator. Praktijktesten van
live teamwedstrijden door Gerd-Jan op iPhone en A13 staan nog open.
Upload naar TestFlight/Play wacht op zijn opdracht.

Bronnen: [Competitie-vervolg](competitie-vervolg.md),
[live teamwedstrijd](plan-live-teamwedstrijd.md),
[opleveren en hosting](opleveren-en-hosting.md).

## Hosting is los van de app-release veranderd

Volgens de opleverdocumentatie draaien website en live meekijken sinds
5 oktober op Cloudflare Workers. De NAS is reserve. De bestaande domeinen
blijven hetzelfde. De Alfa/Beta-keuze is alweer uit de app verwijderd.

De live-Worker wordt automatisch uitgerold bij wijzigingen aan zijn map
op main; de website wordt vanaf de Mac gepubliceerd, omdat screenshots en
teamzips buiten Git staan. De NAS-versie ondersteunt geen live
teamwedstrijden. Deze review heeft de actuele deployment niet opnieuw getest.

## Nog op de backlog

- **SquashLevels-profiel per opgeslagen speler**, nieuw uitgewerkt op
  6 oktober: link of speler-ID invoeren, browserknop en optionele profiellink
  in team-zips. Nog niet gebouwd en nog geen build toegewezen.
  Zie [de feature-uitwerking](plan-squashlevels-profiel.md).
- Voortgang naar de volgende badgetrede.
- Onderlinge stand bij Kies speler.
- Spelersprofiel met trends over meerdere wedstrijden.
- Vergelijken met de officiële SBN-uitslag en badgecategorie Teamspeler.
- Grotere onderwerpen zoals trainingsmodus en clubranglijst.

De datums en buildtoewijzingen uit de oude planning zijn niet allemaal
actueel; zie de documentatiebevindingen hieronder.

## Branches: er bestaat meer dan alleen main

De remote heeft drie branches, rechtstreeks gecontroleerd met
`git ls-remote --heads origin`:

| Branch op origin | Commit | Verhouding tot main |
| --- | --- | --- |
| `main` | `19fabb8` | Centrale, actuele app-ontwikkeling |
| `claude/live-beta-afronden-faf03f` | `19fabb8` | Exact dezelfde commit als main |
| `claude/great-pasteur-eyskxy` | `9b55182` | Twee eigen commits buiten main; mist tegelijk tien commits van main |

De twee nog niet samengevoegde commits zijn:

- `46a8607`: documentatie en conceptworkflow voor testbuilds vanuit de
  cloud via GitHub Actions, plus aanpassing van het TestFlight-script.
- `9b55182`: Python-cache van scripts negeren in Git.

De workflow staat dus **niet op main**; een werkende releasebouwstraat in
de cloud is daarmee ook niet aangetoond. De branch bevat
`docs/cloud-builds.md` naast de workflow en scriptwijzigingen.

Lokaal bestaan zes branches: main en vijf Claude-branches. Alle lokale
Claude-branchtips zitten al in main; de lokale `claude/great-pasteur-eyskxy`
loopt achter op zijn remote tegenhanger. Enkele lokale branches zijn aan
worktrees gekoppeld. Niets verwijderd of samengevoegd tijdens deze review,
behalve de fast-forward van main naar de bestaande origin/main.

## Documentatiebevindingen en afhandeling

De documentatie bevat veel historische plannen met latere aanvullingen.
Lees voor de huidige toestand eerst `opleveren-en-hosting.md` en
`wijzigingen-builds.md`; onderstaande tegenstrijdigheden zijn op 6 oktober in de repo gecorrigeerd.
De opsomming beschrijft wat vóór die correctie werd aangetroffen.

1. **Buildplanning:** de inleiding kiest Competitie voor build 19, maar de
   build-19-sectie kiest nog badgevoortgang. Verder staat Competitie bij
   "Wat niet in deze builds komt" en zijn achteraf invullen en live nog
   toekomstplannen. Dat klopt niet meer met de opgeleverde code.
2. **Architectuur:** noemt nog 31 badges, Android-placeholders en beperkte
   historie, terwijl de nieuwere docs 37 badgefamilies en gedeelde schermen
   beschrijven. De Competitie-sectie zegt eerst dat teamdata nog niet in de
   back-up zit, en even later terecht dat dit wel zo is.
3. **Android-port:** de kopstatus en "Volgende" komen nog uit september;
   latere secties beschrijven de voltooiing. Bruikbaar als technisch logboek,
   maar de kop is geen actueel statusoverzicht.
4. **Handleidingen:** noemen Competitie en live teamwedstrijden als onderdeel
   van de geteste bèta, terwijl de uploadnotities en testpagina nog build 18
   noemen. Label de functies voor build 19 duidelijk totdat die uit is.
5. **Testpagina:** noemt Android-back-ups nog dagelijks; de actuele
   implementatiedocumentatie en handleiding zeggen wekelijks.
6. **Privacytekst en hosting:** `website/privacy.html` zegt dat livegegevens
   alleen in werkgeheugen staan en niet op schijf. De Worker gebruikt
   echter Durable Object-opslag (`ctx.storage.put` in `session.js` en
   `team.js`), met verwijderen via een alarm. Ook het nieuwe teamplan en
   sommige hostingteksten bevatten nog de oude geheugenomschrijving.
   Beschrijf de tijdelijke opslag en verwijdertermijn overeenkomstig de
   huidige implementatie. Dit is een geconstateerde tekst/code-afwijking,
   geen controle of uitspraak over juridische naleving.
7. **App Store-metadata:** noemt nog volley als losse slag, GPT-4o als vast
   model en Kort als deeloptie. Dat loopt achter op de app.
8. **Oude badge- en testinstructies:** bevatten nog toekomstige stappen die
   later al zijn afgevinkt of uitgeleverd. Markeer zulke documenten als
   historisch en verwijs naar de actuele opleverinstructie.

De actuele architectuur, buildplanning, Android-kopstatus, handleidingen,
testpagina, privacy-/hostingteksten en App Store-tekst zijn bijgewerkt. Oude
inrichtings- en testplannen zijn herkenbaar als historie gemarkeerd. Er is
geen app-code aangepast en geen TestFlight- of Play-release gestart.
