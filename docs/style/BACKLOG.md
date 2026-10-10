# Stijlbacklog voor Claude Code

## Scope en afspraken

De homepage wordt in deze wijziging doorgevoerd voor iOS en Android. De overige schermen krijgen **geen redesign**. De HTML-previews in `docs/archief/homepage-options/pages.html` zijn door de gebruiker afgewezen en mogen niet als implementatiereferentie dienen.

## Stand (3 oktober, Claude Code)

- [x] Inventariseer afwijkende kleuren op vervolgschermen in iOS en het gedeelde Skip/Android-package.
- [x] Trek alleen achtergrond (echt zwart), primaire/secundaire tekst en algemene oranje accenten gelijk met `docs/style/tokens.json`.
- [x] Behoud layout, afstanden, knoppen, kaartvormen en bestaande tekstgroottes; uitzondering: paginatitels hieronder.
- [x] Maak paginatitels consistent 20 pt op iOS / 20 sp op Android, met gewone schrijfwijze: Coach, Scheidsrechter, Coach dashboard, Wedstrijden, Spelers, Alle badges, Mijn team, Instellingen. Laat dynamische speler- en badgenamen intact.
- [x] Behoud functionele kleuren: oranje/blauw voor de spelers, koel blauw/indigo voor rechter scheidsrechteracties, rood voor STROKE/fouten, baan- en badgekleuren. Gebruik namen/labels naast kleur.
- [x] Controleer beide platformen met standaard en vergrote tekst (4 okt, simulator en emulator 1,3× en 2×). Afbrekende titels en knoppen opgelost; scoreschermen op Android begrensd tot 1,3×. iOS gebruikt grotendeels vaste lettergroottes en groeit dus nauwelijks mee; meegroeien op lijst- en menuschermen is een mogelijke latere stap.

Uitgevoerd:
- Schermachtergronden echt zwart: `AppBackground` (iOS) en `GlowBackground` (gedeeld) zonder oranje gloed; de achtergrondtokens in alle lokale paletten op `Color.black`.
- Secundaire tekst overal `#B3ADA6` (was op badges, teamkaart, dashboard en badgestrook iets lichter); het afwijkende oranje van Mijn team gelijk aan `#F28C26`.
- Kaartkleuren, knoppen, spelerskleuren, LET/STROKE en baankleuren zijn niet veranderd.
- Paginatitels: `pageTitle(_:)` en `PageTitleStyle` (20 pt semibold) in `PageTitle.swift`; op Android zet `MainActivity` elke titelbalk op 20 sp semibold en staan de titels compact naast de terugpijl. Eigen koppen (Coach, Scheidsrechter, Coach dashboard, Wedstrijden, Spelers, Kies speler, Instellingen) in gewone schrijfwijze op 20 pt. Op Android stond "Spelers" dubbel (titelbalk en kop); de kop is weg.
- Gecontroleerd met standaardtekst op de iPhone 17 Pro Max-simulator en de Android-emulator. Nog te doen bij het testen op de toestellen: vergrote tekst.

## Relevante bronnen

- `docs/style/README.md` en `tokens.json`: ontwerpwaarden en functionele kleuren.
- `SquashAnalyzer/DesignSystem.swift`: iOS-palet.
- `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI`: gedeelde presentatie en lokale paletten.
- `SquashAnalyzer/Views`: iOS-schermen.

Pas niet globaal alle kaartvormen, margins of fonts aan op basis van de oorspronkelijke stijlgids. De latere gebruikersafspraak hierboven gaat voor. Stem af op de laatste code van de foutanalyse; draai geen fixes van andere wijzigingen terug.

## Lichte modus in apps en web (10 oktober 2026)

- [ ] **Implementeer warm licht naast donker op iOS, Android en web.**
  Ontwerp: `README.md`, `tokens.json` → `themes.light` en de lichte sectie in
  `../archief/homepage-options/style-guide.html`. Alleen het ontwerp is nu klaar.

Acceptatiecriteria en werkvolgorde:

1. Maak thematische kleuren in `SharedColors` en de iOS-adapter `AppColors`;
   vervang geforceerde donkere weergave en losse vaste kleuren waar nodig.
   Behoud de bestaande layouts, bediening en donkere stijl.
2. Werk alle appschermen bij, inclusief instellingen, sheets, systeemnavigatie,
   wedstrijdstart, coach, scheidsrechter, analyse, profiel, badges en teamwedstrijden.
3. Pas hetzelfde palet toe op de website (`website/`, inclusief handleiding,
   spelerskaart en teamuitnodiging) en de live kijkpagina’s voor losse partijen
   en teamwedstrijden (`server/live-worker/public/`). De NAS blijft reserve.
4. Werk de themakeuze uit met Gerd-Jan: voorstel Systeem / Licht / Donker,
   met lokaal bewaarde voorkeur. Bepaal de standaard voor bestaande en nieuwe
   gebruikers vóór invoering; die keuze is nog niet gemaakt. Neem op web
   systeemvoorkeur, handmatige keuze en eerste paginarender zonder kleurflits mee.
5. Controleer functionele kleuren per achtergrond: spelers, LET/STROKE,
   fouten/succes, heatmap, badges en servermarkering. Behoud namen en labels;
   bepaal leesbare lichte varianten waar de huidige kleuren niet voldoen.
   Controleer het bestaande logo op licht en stem een eventuele transparante
   variant af. Bepaal ook bewust hoe geëxporteerde scorekaarten/afbeeldingen kleuren.
6. Verifieer tekstcontrast (normale tekst minimaal 4,5:1, grote tekst 3:1),
   noodzakelijke bediening/focusmarkeringen (3:1), hover, pressed, selectie,
   disabled, fouten, lege toestanden, grote tekst en kleine schermen in beide modi.
   Vergelijk iOS-simulator, Android-emulator en mobiele/desktopbrowser visueel.
7. Draai vóór push alle suites uit `docs/opleveren-en-hosting.md`. Werk
   handleiding en releasenotes bij wanneer de modus daadwerkelijk werkt.
   Website publiceren volgens de hostinginstructies; uploads naar TestFlight
   of Play uitsluitend op verzoek. Houd de live-API achterwaarts compatibel.
