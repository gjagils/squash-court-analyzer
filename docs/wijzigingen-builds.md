# Wijzigingen per build

Doorlopend overzicht van wat er sinds de laatste upload is veranderd. Bij elke
nieuwe build schuift het blok "Volgende build" naar beneden onder het
buildnummer, en de releasenotes (`release-notes/`) worden eruit geschreven.

## Volgende build (nog niet geüpload; iOS 18 / Android 5, pas na Gerd-Jans go)

Vergeleken met iOS 2.2 (17) en Android 0.4 (4), 3 oktober 2026.

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

### Probeer vooral
- Zet de tekst groot (Samsung: Lettergrootte max; iPhone: Tekstgrootte) en loop
  beginscherm, Coach, Scheidsrechter en Afgeronde wedstrijden door.
- Stop een scheidsrechterwedstrijd, wacht even en hervat: loopt de klok verder
  waar hij was?

## Backlog

- [ ] **Wedstrijd koppelen aan een competitiewedstrijd** (verkennen in de testperiode).
      Een SBN-teamwedstrijd = 4 partijen (E1–E4, singles, best of 5 tot 11).
      Uitslag = gewonnen games over de 4 partijen; competitiepunten = games + 3
      bonuspunten voor de winnaar. Winnaar: eerst meeste games; gelijk → meeste
      gewonnen partijen; nog gelijk → meeste rallypunten. Idee: als een coach- of
      scheidsrechterwedstrijd op de dag van een wedstrijd van Mijn team valt,
      vragen of hij erbij hoort en welke partij (E1–E4). Dan: de teamwedstrijd als
      geheel (4 partijen, stand in games), één verslag van de avond, live
      meekijken per teamwedstrijd, en vergelijken met de SBN-uitslag.

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
