# Wijzigingen per build

Doorlopend overzicht van wat er sinds de laatste upload is veranderd. Bij elke
nieuwe build schuift het blok "Volgende build" naar beneden onder het
buildnummer, en de releasenotes (`release-notes/`) worden eruit geschreven.

## Volgende build (nog niet geüpload; nummers bepalen bij de upload)

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
- [ ] Testen op Gerd-Jans iPhone en de Android-telefoon (ook met vergrote tekst).
- [ ] Screenshots App Store en Play, en de handleiding op de website.
- [ ] Releasenotes schrijven uit dit overzicht (`release-notes/`); `concept-volgende-build.md` is verouderd.
- [x] Privacytekst (live meekijken: 2 uur bewaren, foto's) gepubliceerd (3 okt).
- [ ] Website bijwerken (homepage, nieuws).
- [x] Google Play Gegevensveiligheid: Naam en Foto's toegevoegd (3 okt, via de API).

## iOS 2.2 build 16 en Android 0.3 (3), 1 oktober 2026

Zie `release-notes/2.2-16.md` en `release-notes/android-0.3-3.md`.
