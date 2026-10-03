# Wijzigingen per build

Doorlopend overzicht van wat er sinds de laatste upload is veranderd. Bij elke
nieuwe build schuift het blok "Volgende build" naar beneden onder het
buildnummer, en de releasenotes (`release-notes/`) worden eruit geschreven.

## Volgende build (nog niet geüpload; nummers bepalen bij de upload)

Vergeleken met iOS 2.2 (16) en Android 0.3 (3), beide 1 oktober 2026. Stand: `main`, 3 oktober.

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

### Opgelost
- Scheidsrechter: de STROKE-banner verschijnt weer; Sluiten wacht tot er is
  opgeslagen; na Undo komt het eindvenster weer terug als de game opnieuw wordt
  uitgespeeld.
- Na het hervatten klopt de serveerkant (box) weer.
- Live meekijken werkte niet op Android.
- Het deelplaatje had een doorzichtige rand.

### Onder de motorkap
- SwiftData V7 (`SavedPoint.errorKind`), Room 9. Back-upformaat 3 alleen als er
  scheidsrechterwedstrijden in zitten, anders 2 zoals voorheen.
- Serviceregel en wedstrijdstand op één plek in Core (`ScoringEngine`).
- Live-server (`live.squashanalyzer.com`) met limieten per IP en op kijkers.
- Kaartlinks begrensd op lengte en uitpaklimiet (bescherming tegen zip-bombs).
- Opruiming: dode code, lege bestanden en publieke tuples weg (T15, T16).

### Nog doen vóór de upload
- [ ] Testen op Gerd-Jans iPhone en de Android-telefoon (ook met vergrote tekst).
- [ ] Screenshots App Store en Play, en de handleiding op de website.
- [ ] Releasenotes schrijven uit dit overzicht (`release-notes/`); `concept-volgende-build.md` is verouderd.
- [ ] Privacytekst: live meekijken (2 uur bewaren) staat klaar in
      `website/privacy.html`, nog niet gepubliceerd.
- [ ] Website bijwerken (homepage, nieuws).

## iOS 2.2 build 16 en Android 0.3 (3), 1 oktober 2026

Zie `release-notes/2.2-16.md` en `release-notes/android-0.3-3.md`.
