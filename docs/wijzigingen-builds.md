# Wijzigingen per build

Doorlopend overzicht van wat er sinds de laatste upload is veranderd. Bij elke
nieuwe build schuift het blok "Volgende build" naar beneden onder het
buildnummer, en de releasenotes (`release-notes/`) worden eruit geschreven.

## Volgende build: 3.0 build 1 (nog niet geüpload)

Nieuwe nummering sinds 6 oktober 2026 (`docs/opleveren-en-hosting.md`,
"Versienummers"): 3.0 build 1 is de eerstvolgende upload op iOS en Android; in
de projectbestanden staat nu 3.0 build 0. De release-notes heten
`release-notes/3.0-1.md` en `release-notes/android-3.0-1.md`.

Vergeleken met iOS 2.2 (18) en Android 0.5 (5), 5 oktober 2026. Planning van
de builds in de testperiode (drie tot vier, elk hooguit één feature):
`docs/buildplanning-testperiode.md`: testperiode twaalf dagen, twee builds
(rond 10 en 15 oktober), daarna productie aanvragen voor Android. Build 19
krijgt de competitiekoppeling (besluit Gerd-Jan, 5 oktober); de
badgevoortgang schuift door. Hosting:
`docs/hosting-verhuizing.md`.

### Competitie: teamwedstrijden (de feature van build 19)

Tekst voor de releasenotes (gebruikerstaal):

> **Nieuw: Competitie.** Op het beginscherm staat een rij Competitie. Daar
> maak je een teamwedstrijd van de SBN-competitie aan (uit het programma van
> Mijn team, of zelf ingevuld) met de vier partijen E1 tot en met E4. Hield
> je een partij bij als coach of scheidsrechter? Koppel die, dan komen de
> games vanzelf mee. De rest vul je in met de game-standen, of alleen wie
> won. De app telt de games, de bonuspunten en de winnaar volgens de
> SBN-regels (meeste games; gelijk: meeste partijen; nog gelijk: meeste
> rallypunten; winnaar krijgt 3 bonuspunten) en maakt één verslag van de
> avond om in de groepsapp te delen, als Scorekaart, Verslag of Plaatje,
> net als bij een wedstrijd. Speel je op een dag dat je team een wedstrijd
> heeft, dan vraagt de app na een coach- of scheidsrechterwedstrijd of hij
> erbij hoort en bij welke partij. Een partij kun je ook meteen bijhouden:
> kies bij de partij een nieuwe coach- of scheidsrechterwedstrijd; de
> thuisspeler is Speler 1, en de uitslag komt vanzelf in de partij.
> Bij Spelers zet je met **In mijn team** aan wie bij je team hoort; die
> spelers staan bovenaan als je een partij invult. Teamwedstrijden en die
> teamvlag zitten ook in de back-up.

**Live teamwedstrijd** (ook build 19), tekst voor de releasenotes:

> **Teamwedstrijd live meekijken.** In een teamwedstrijd staat nu een kaart
> Live. Tik op Live delen en deel de kijkerslink in de groepsapp: iedereen
> ziet de stand van de hele avond en per partij de games, ook punt voor
> punt. Teamgenoten kunnen meedoen: stuur ze de uitnodiging (link of code),
> ze kiezen hun team en zetten hun eigen partij erop. Start je een coach- of
> scheidsrechterwedstrijd, kies dan in het beginscherm Onderdeel van een
> teamwedstrijd, dan gaat de stand van die partij vanzelf mee. Alleen
> teamnamen, voornamen en de stand gaan mee; zonder namen staat er de
> teamnaam met de partij erachter, bijvoorbeeld Delft 7 E1. Twee uur na de
> laatste update wordt alles gewist.

Techniek: Worker `TeamSession` (Durable Object), pagina `/t/<id>`, `TeamLive`
en `TeamInvite` in Core, schermen `TeamLiveCard` en `SharedTeamJoinView`.
Getest tussen iOS-simulator en Android-emulator (aanmaken, deelnemen met
de uitnodiging, partij invullen en terugzien op de andere telefoon en op de
pagina, punt voor punt vanuit een gekoppelde coachwedstrijd). Worker 21,
Core 201 (Skip), Android 66 en iOS-tests groen. De NAS-server heeft geen
teamendpoints (alleen reserve).

Bugfix binnen dezelfde feature (6 oktober): een bijgehouden wedstrijd voor
een partij raakte de koppeling kwijt als je hem verliet en later hervatte;
die staat nu in de teamwedstrijd (`trackingMatchId`) en komt terug bij
Hervatten. Geen aparte releasenote nodig (de feature is nieuw).

Back-up: formaat 4 alleen als er teamdata is (testers met build 17 of 18 kunnen
zo'n bestand niet terugzetten, zoals bij formaat 3). De teamvlag is een lijst
ids in de instellingen (`TeamRoster`), geen SwiftData- of Room-kolom.

Techniek (niet voor de releasenotes): `TeamMatch` in Core met tests (12),
opslag in één JSON-bestand per telefoon (`JSONFileTeamMatchStore`, geen
SwiftData- of Room-migratie), gedeelde schermen `SharedTeamMatchesView`,
`SharedTeamMatchView`, `TeamPartijEditor` en `TeamMatchLinkPrompt` in
SquashAnalyzerUI. Live per teamwedstrijd staat hierboven. Nog niet: vergelijken met de SBN-uitslag,
badgecategorie Teamspeler. Getest op simulator en emulator (aanmaken uit het programma,
partij invullen, koppelen vanuit Afgeronde wedstrijden, vraag na een
scheidsrechterwedstrijd, verslag delen, opslag na herinstallatie).

### Live meekijken en website: nieuwe hosting

Tekst voor de releasenotes (gebruikerstaal):

> **Live meekijken en de website draaien nu bij Cloudflare.** Tot nu toe
> stonden de livepagina en squashanalyzer.com op een eigen server thuis.
> Vanaf nu draaien ze op het wereldwijde netwerk van Cloudflare: sneller,
> altijd bereikbaar (ook als een thuisverbinding hapert) en elke
> livewedstrijd krijgt zijn eigen stukje server, dus drukte bij de ene
> wedstrijd raakt de andere niet. Voor jou verandert er niets: dezelfde
> links, dezelfde app. Er wordt nog steeds niets bewaard: alleen voornamen,
> de stand en een kleine spelersfoto, en twee uur na de wedstrijd wordt
> alles gewist.
>
> **Op de livepagina** krijgt elke gewonnen game de kleur van de winnaar en
> staan de scores netjes onder elkaar.

Techniek (niet voor de releasenotes): `live.squashanalyzer.com` en
`squashanalyzer.com` zijn sinds 5 oktober Cloudflare Workers
(`server/live-worker`, `server/website-worker`); de NAS is reserve, zie
`docs/hosting-verhuizing.md`. Getest op de iPhone met een scheidsrechter- en
een coachwedstrijd, foto's, WhatsApp-link en vliegtuigstand: "werkt super
soepel". De schakelaar Alfa/Beta uit de testbranch is weer verwijderd
(nooit in een build geweest).

### Gemeld door testers
(wat · wie · platform · nu / volgende / later)

## iOS 2.2 build 18 en Android 0.5 (5), 5 oktober 2026 (geüpload)

Android 0.5 (5) staat op internal, alpha en Google Group testers
(`scripts/play_upload.py`), de Play-listing is bijgewerkt. iOS 2.2 (18) is
vanaf de Mac geüpload (`xcodebuild -exportArchive`, archief in
`output/build-18/`) en via `scripts/testflight_distribute.py` van notes
voorzien en ingediend voor beta review. Website gepubliceerd (stack 85).
Zie `release-notes/2.2-18.md` en `release-notes/android-0.5-5.md`. Getest op
de iPhone 17 Pro Max-simulator en de Android-emulator (API 36.1); alle suites
groen (zie `docs/android-port.md`, "Badges met treden"). Vergeleken met iOS
2.2 (17) en Android 0.4 (4), 3 oktober 2026.

### Opgelost tijdens het testen (5 oktober)
- **iOS Instellingen, TERUGZETTEN** opende geen bestandskiezer (twee
  `.fileImporter`s op één view); nu elk op zijn eigen rij.
- **iOS Spelers:** het getal bij de medaille telt een badge met treden één
  keer, zoals Android en "x van 37".
- **Strip "Badges verdiend":** de tekst krimpt bij vijf medaillons; op Android
  stond er "Bombardino · 5" in plaats van "· 5 badges".
- De oude imagesets zonder trede zijn verwijderd (71 imagesets over).

### Opgelost
- **Grote systeemtekst:** de tegel "SCHEIDSRECHTER" brak op Android al bij
  Samsung "groot" (1,3×) midden in het woord; tegeltitels, de naam
  SquashAnalyzer, "Sluiten", "Stop", Links/Rechts, "TIK = PUNT" en de filtertabs
  blijven nu op één regel en worden zo nodig iets kleiner.
- **Scoreschermen op Android:** Coach en Scheidsrechter scoren volgen de
  systeemtekst tot 1,3× (`FontScaleCap`), zodat ze bij 2× niet meer uitlopen.
- **Wedstrijdklok na hervatten:** een gestopte scheidsrechterwedstrijd telde de
  uren met de app dicht mee (bijv. 970:54 de volgende dag). Bij hervatten
  lopen match- en gameklok nu verder vanaf het laatste opslaan.

### Mijn team
- **Je eigen team valt op** in de stand: een oranje band met naam, positie en
  punten in oranje. Op de iPhone nu hetzelfde teamscherm als op Android.
- **Minder verkeer naar sbn.toernooi.nl:** de app toont de bewaarde stand en haalt
  alleen opnieuw op als er iets kan zijn veranderd (`LeagueTeamRefresh`): elk uur
  zolang een gespeelde wedstrijd van je team (laatste 2 weken) nog geen uitslag
  heeft, elke 6 uur als niet elk team in de poule even vaak heeft gespeeld, en
  anders eens per week. Eerst haalde de app het team op bij elk beginscherm.
- **Vernieuwen**-knop onderaan het teamscherm om meteen op te halen.

### Badges
- **Treden brons, zilver en goud** voor zeventien badges; de rand van de badge
  laat de trede zien en het getal in de badge is de drempel. 5 points in a row
  5/7/10 (goud is de oude Perfect ten), slagbadges 4/6/8 per game, Front row
  king en Back from the dead 5/7/9, Endurance 60/90/120 s, Iron man 60/75/90
  min, Hat trick 3/5/7, Nemesis 5/10/20, Ten out of ten 10/25/50, Centurion
  100/500/1000, Veteran 25/50/100. Wie de drempel van goud haalt, krijgt in die
  wedstrijd alle drie de treden; al verdiende badges blijven brons.
- **Zeven nieuwe badges:** Rock solid (wedstrijd zonder unforced error, coach),
  Back wall boss (5 winners achterin, coach), Sneltrein (game in minder dan 6
  minuten, coach), Vette winst (tegenstander in geen game boven de 5),
  Clubicoon (10 verschillende tegenstanders, één keer), Rivalen (10 wedstrijden
  tegen dezelfde tegenstander) en Hand-out held (5 rally's op rij gewonnen op
  de service van de ander). Daarmee zijn er 37 badges (71 met treden).
- **Schermen:** de catalogus toont per badge de drie treden naast elkaar met de
  drempels; het spelersscherm, de badgekaart (app en website) en de strip na de
  wedstrijd tonen per badge de hoogste trede. Bij de momenten staat de trede
  erbij ("Goud · Tegen …").
- Artwork van Codex (`docs/style/badge-artwork-overdracht-claude-code.md`); de
  oude imagesets van de zeventien omgezette badges en `perfect-ten` zijn op
  5 oktober verwijderd.

### Probeer vooral
- Zet de tekst groot (Samsung: Lettergrootte max; iPhone: Tekstgrootte) en loop
  beginscherm, Coach, Scheidsrechter en Afgeronde wedstrijden door.
- Stop een scheidsrechterwedstrijd, wacht even en hervat: loopt de klok verder
  waar hij was?
- Speel in coachmodus een game met 6 of 8 drops en kijk of zilver/goud op de
  strip, het spelersscherm en de gedeelde kaart verschijnen; open "Alle badges"
  voor de treden en de zeven nieuwe badges.

## Backlog

- [x] **Wedstrijd koppelen aan een competitiewedstrijd** (gebouwd 5 oktober voor build 19, zie hierboven; live per teamwedstrijd en SBN-vergelijking nog niet).
      Een SBN-teamwedstrijd = 4 partijen (E1–E4, singles, best of 5 tot 11).
      Uitslag = gewonnen games over de 4 partijen; competitiepunten = games + 3
      bonuspunten voor de winnaar. Winnaar: eerst meeste games; gelijk → meeste
      gewonnen partijen; nog gelijk → meeste rallypunten. Idee: als een coach- of
      scheidsrechterwedstrijd op de dag van een wedstrijd van Mijn team valt,
      vragen of hij erbij hoort en welke partij (E1–E4). Dan: de teamwedstrijd als
      geheel (4 partijen, stand in games), één verslag van de avond, live
      meekijken per teamwedstrijd, en vergelijken met de SBN-uitslag.
      Ook partijen die je niet hebt bijgehouden met de hand invullen (de
      game-standen, zoals bij Later instappen / Uitslag aanvullen) of later
      importeren. Voorbeeld: speelvolgorde 4-2-1-3; je speelt zelf E4 (niet
      bijgehouden, achteraf invullen), coacht daarna E2 en E1 en fluit E3: samen
      één complete teamwedstrijd.

- [x] **Badges met treden (brons, zilver, goud)** (gekozen: idee B). De huidige
      badge wordt brons; zwaardere treden erboven, bijv. 5 op een rij 5/7/10
      (goud = Perfect ten), slagbadges 4/6/8 per game, Ten out of ten 10/25/50,
      Centurion 100/500/1000, Veteran 25/50/100. Al verdiende badges blijven brons.
      Rand bepaalt de trede. Artwork: Codex, prompt in `docs/style/badge-prompt-codex.md`.
      Gebouwd voor de volgende build (zie hierboven).
- [x] **Nieuwe badges:** Rock solid (wedstrijd zonder unforced errors), Back wall
      boss (5 winners achterin), Sneltrein (game < 6 min), Vette winst
      (tegenstander in geen game boven 5), Clubicoon (10 verschillende
      tegenstanders), Rivalen (10× dezelfde tegenstander), Hand-out held (5 rally's
      op rij bij serve van de ander). Gebouwd voor de volgende build.
- [ ] Later, met de competitiekoppeling: een eigen badgecategorie voor
      competitiewedstrijden (o.a. Teamspeler).
- [ ] **Spelersprofiel met trend over wedstrijden** (voorgesteld 5 oktober,
      kandidaat voor de build na de badges).
      *Waarom:* de analyse kijkt nu per wedstrijd (dashboard, heatmap, slagen,
      soorten fouten); een coach ziet niet of een speler vooruitgaat. Het
      profiel laat dat zien over de laatste wedstrijden, zonder nieuwe invoer.
      *Wat de gebruiker ziet:* vanuit Spelers (naast Badges) een scherm
      "Profiel" met bovenaan foto, naam, aantal wedstrijden en winstpercentage,
      en daaronder kaarten in de huisstijl:
      - **Vorm:** de laatste 10 beslissingen als rij bolletjes (W/V, oranje en
        gedempt) met de uitslag in games eronder; coach- én
        scheidsrechterwedstrijden tellen mee.
      - **Winners tegenover unforced errors** per game, als twee lijnen over
        de laatste 10 coachwedstrijden, met het gemiddelde van de eerste en
        de laatste 5 ("van 3,1 naar 2,4 fouten per game"). Alleen coachmodus
        heeft punttypes; staat er niets, dan toont de kaart dat.
      - **Slagen:** winnende slag met het hoogste aandeel over de periode
        (`Game.pointsWon(by:with:)`), top 3 met percentage, en de slag die het
        vaakst een unforced error opleverde.
      - **Baan:** winners en eigen fouten per rij en kant (`AreaTally`,
        `dominantRow`/`dominantSide`), als dezelfde baanweergave als in de
        analyse; sterkste en zwakste vak in één zin.
      - **Tempo:** gemiddelde rallyduur gewonnen tegenover verloren
        (`averageDurationWon/Lost`), met de trend over de wedstrijden.
      - **Tegenstanders:** top 3 met stand onderling, uit dezelfde
        geschiedenis als de carrièrebadges (`BadgeAwarder.history`,
        `BadgeAwardStore.careerHistory`).
      Elke kaart heeft een periode-keuze: laatste 10, laatste 25, alles.
      *Hoe te bouwen:* een pure `PlayerTrend` in SquashAnalyzerCore die uit een
      lijst opgeslagen coachwedstrijden (`Match`) en scheidsrechterwedstrijden
      (`RefereeMatch`) per speler-id een `PlayerTrendSummary` maakt (per
      wedstrijd: datum, gewonnen, games, winners, unforced errors, slagen per
      type, `AreaTally` winners en fouten, rallyduur), met tests zoals
      `BadgeEngineTests`. Daarbovenop één gedeeld scherm `SharedPlayerTrendView`
      in SquashAnalyzerUI (rijen van kaarten, geen LazyVGrid, getallen met
      `.0` voor Skip) dat beide platformen gebruiken; de stores leveren de
      wedstrijden al (`CoachMatchStore.history`, `RefereeMatchStore.history`,
      iOS `SavedMatch`/`SavedRefereeMatch`). Lijnen tekenen met `Path` zoals de
      heatmap, geen Charts-framework (Skip kent het niet). Een speler zonder
      coachwedstrijden krijgt alleen Vorm en Tegenstanders.
      *Buiten scope (later):* vergelijken van twee spelers, export als plaatje,
      AI Coach-advies over de trend (die kan de `PlayerTrendSummary` dan als
      invoer krijgen).
      *Klaar wanneer:* Core-tests voor de berekeningen (ook met wedstrijden
      zonder punttypes en met "later instappen"), het scherm op iPhone en
      Android gelijk, standaard en 1,3× tekst gecontroleerd, en een regel in de
      handleiding op de website.

## iOS 2.2 build 17 en Android 0.4 (4), 3 oktober 2026 (geüpload)

Vergeleken met iOS 2.2 (16) en Android 0.3 (3), beide 1 oktober 2026. Stand: `main` (`b694cf5`), 3 oktober.
De live-server met foto's draait al in productie; de privacytekst staat online.

### Nieuw voor de gebruiker
- **Homepagina vernieuwd** (Clubhuis-stijl, Codex): logo, naam SquashAnalyzer en
  tagline bovenaan, Mijn team-kaart, twee gelijke tegels Coach en
  Scheidsrechter, daaronder Afgeronde wedstrijden, Spelers en Badges.
- **Stijl gelijkgetrokken:** echt zwarte schermen, dezelfde tekst- en oranjetinten
  overal, paginatitels 20 pt in gewone schrijfwijze (Coach, Scheidsrechter,
  Wedstrijden, Spelers, Instellingen...). Op Android staat de titel compact naast
  de terugpijl en staat "Spelers" niet meer dubbel.
- **Soort fout bij een unforced error:** eerst Unforced error, dan DOWN, OUT,
  SERVICE of GROND (of "Weet niet"), in tegels met uitleg. Service kan alleen bij
  de serveerder. In de analyse en het advies zie je de soorten terug.
  "Servicefout tegenstander" heet nu zo.
- **START GAME bij de eerste service:** inspelen en pauze tellen niet meer mee in
  de lengte van de eerste rally.
- **Live meekijken:** LIVE-knop bij Coach en Scheidsrechter. Grijs tot er een
  link is, rood als de wedstrijd live is. Link delen in de WhatsApp-groep;
  kijkers volgen de stand in de browser. Uit te zetten in Instellingen
  (standaard aan). De eindstand blijft 2 uur zichtbaar en wordt dan gewist;
  zonder netwerk gaat de eindstand alsnog mee zodra er weer verbinding is.
- **Foto's op de livepagina:** staat er een foto bij een speler, dan ziet wie
  meekijkt die naast de naam (een kleine versie, alleen zolang de wedstrijd live
  is). Uit te zetten in Instellingen: "Foto's van de spelers meesturen".
- **Deel score:** drie keuzes, Scorekaart, Verslag of Plaatje, met één knop
  Delen. Het plaatje heeft de spelersfoto's in de cirkels. De optie "Kort" is
  weg.
- **Badges:** ook bij "Nieuw in deze wedstrijd" tik je op een badge voor de uitleg.
  Tien op tien en Veteraan worden ook toegekend als de teller er al voorbij was.
- **Sluitknoppen:** overal dezelfde "✕ Sluiten" (zoals bij Spelers).
- **Back-up:** scheidsrechterwedstrijden gaan nu mee (iOS en Android).
  "Voeg toe" maakt geen dubbele spelers of wedstrijden meer.
- **Kaartlinks:** openen ook als de app nog niet draaide (iOS); op Android openen
  links van squashanalyzer.com direct in de app (assetlinks).

### Anders op de iPhone (door T20, gelijk aan Android)
- Coach en Scheidsrechter vragen zelf "Wedstrijd hervatten?" en hebben de
  gedeelde wedstrijdstart; een lopende wedstrijd staat niet meer in Afgeronde
  wedstrijden (de tegel biedt hem aan).
- Badges per speler en de badgecatalogus zijn de gedeelde schermen.
- Afgeronde wedstrijden: de gedeelde lijst; losse games van vroeger staan nog in
  de back-up maar niet in de lijst. Back-up maken, terugzetten, delen en een
  wedstrijd importeren staan nu in Instellingen.
- Bij "Kies speler" in de wedstrijdstart kan op de iPhone nog geen foto worden
  gekozen (dat kan in Spelers).

### Opgelost
- Scheidsrechter: de STROKE-banner verschijnt weer; Sluiten wacht tot er is
  opgeslagen; na Undo komt het eindvenster weer terug als de game opnieuw wordt
  uitgespeeld.
- Na het hervatten klopt de serveerkant (box) weer.
- Live meekijken werkte niet op Android.
- Android: een afgesloten of weggegooide wedstrijd kon terugkomen als er net nog
  een punt werd opgeslagen; afsluiten wacht nu op die opslag.
- Het deelplaatje had een doorzichtige rand.
- iPhone: de wekelijkse iCloud-back-up schrijft op de achtergrond (met extra tijd
  van iOS) in plaats van de app even te laten haperen bij wegschakelen.
- iPhone: lukt het bewaren van de API key niet, dan zegt de app dat (in plaats van
  "Opgeslagen!"); "Nieuwe wedstrijd" meldt het als de oude niet kon worden
  opgeslagen; een beschadigd bestand van een lopende scheidsrechterwedstrijd wordt
  opgeruimd; exportbestanden krijgen een veilige naam (ook met / of : in een naam).
- Android: het deelplaatje en de badgekaart worden buiten de hoofdthread
  gemaakt (geen hapering bij Delen); een weigerende Keystore laat de app niet
  meer crashen bij het bewaren van de API key; een wedstrijd en zijn badges
  worden samen in één keer opgeslagen.
- Android-back-up via Google laat de versleutelde API key en tijdelijke
  plaatjes buiten de back-up (die werkt op een ander toestel toch niet).
- VoiceOver/TalkBack: iconen worden niet meer als "chevron.right" voorgelezen;
  STROKE-knoppen noemen de speler, de uitslag wordt als één
  zin voorgelezen, de verborgen L/R-keuze van de ontvanger wordt overgeslagen.

### Onder de motorkap
- Automatische tests op GitHub bij elke push (projectregels, live-server, Core
  in Swift en Kotlin, iOS, Android) en `scripts/lint.sh` (T23).
- Extra tests voor deelteksten, Stop, AI-modelkeuze, live, herstel en import (T25).
- Taal: alleen Nederlands, squashtermen blijven Engels (T24).
- SwiftData V7 (`SavedPoint.errorKind`), Room 9. Back-upformaat 3 alleen als er
  scheidsrechterwedstrijden in zitten, anders 2 zoals voorheen.
- Serviceregel en wedstrijdstand op één plek in Core (`ScoringEngine`).
- Live-server (`live.squashanalyzer.com`) met limieten per IP en op kijkers.
- Kaartlinks begrensd op lengte en uitpaklimiet (bescherming tegen zip-bombs).
- Opruiming: dode code, lege bestanden en publieke tuples weg (T15, T16).
- Scoreschermen tekenen niet meer elke seconde helemaal opnieuw (alleen de klok
  tikt); badges één keer berekend; spelerslijst telt badges in één keer (T18).
- Eén geteste opslaglogica voor coach en scheidsrechter (`SessionSaver`, T19).
- iPhone draait coach, scheidsrechter, analyse en Afgeronde wedstrijden nu op
  dezelfde gedeelde schermen als Android (T20); ruim 4.000 regels iPhone-code weg.
  De back-upknoppen (iCloud, terugzetten, delen, importeren) staan in Instellingen.
- Knoppen overal gelijk (één `ActionButton`: gevuld, met rand of alleen tekst) (T17).
- Alle kleuren uit één bron (`SharedColors`, volgens de stijlgids); oude
  LED-/hardware-onderdelen weg (T17). Zichtbaar: het blauw in de analyse is iets
  lichter, gedempte tekst op badges/dashboard een fractie donkerder.

### Nog doen vóór de upload
- [x] Testen op Gerd-Jans iPhone en de Android-telefoon (ook met vergrote tekst).
- [x] Screenshots App Store en Play, en de handleiding op de website.
- [x] Releasenotes schrijven uit dit overzicht (`release-notes/`); `concept-volgende-build.md` is verouderd.
- [x] Privacytekst (live meekijken: 2 uur bewaren, foto's) gepubliceerd (3 okt).
- [x] Website bijwerken (homepage, nieuws).
- [x] Google Play Gegevensveiligheid: Naam en Foto's toegevoegd (3 okt, via de API).

## Backlog (gemeld door Gerd-Jan, 3 oktober)

- [x] Livepagina: bij een lange naam (Bombardino) is "rechts" niet meer te lezen.
      Een lange naam mag over 2 regels; daaronder in klein lettertype een
      bolletje voor wie serveert en aan welke kant. Klaar 3 okt (server, geen
      nieuwe build nodig), samen met de huisstijl op de livepagina.

Verder na build 17 (alleen website en server, geen app-build):
- Website en livepagina in de huisstijl Clubhuis; Material-iconen zoals in de app.
- Oude TestFlight-builds verlopen automatisch (`scripts/testflight_expire_old.py`).

## iOS 2.2 build 16 en Android 0.3 (3), 1 oktober 2026

Zie `release-notes/2.2-16.md` en `release-notes/android-0.3-3.md`.
