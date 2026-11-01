# SquashAnalyzer — visuele stijl

De gekozen stijl is de aangepaste Clubhuis-startpagina: echt zwart, warme oranje accenten en rustige, gelijkwaardige kaarten. Deze gids is de ontwerpbron voor nieuwe en vernieuwde schermen op iOS en Android. Vastgelegd op 3 oktober 2026.

- [Visuele stijlkaart](../archief/homepage-options/style-guide.html)
- [Previews van vervolgschermen](../archief/homepage-options/pages.html)
- [Gekozen startpagina](../archief/homepage-options/index.html#clubhuis)
- [Platformonafhankelijke ontwerptokens](tokens.json)

De homepage is nu in native implementatie. Vervolgschermen volgen afzonderlijk via [de backlog](BACKLOG.md).

**Latere scopeafspraak:** op vervolgschermen uitsluitend afwijkende kleuren corrigeren en paginatitels op 20 pt/sp met gewone schrijfwijze zetten. Layout, kaartvormen, afstanden en overige tekstgroottes blijven zoals ze zijn. De vervolgschermpreviews zijn afgewezen en gelden niet als referentie. De andere drie homepageconcepten zijn geen stijlreferentie.

## Identiteit

Schrijf de naam als **SquashAnalyzer**. Gebruik het bestaande logo uit `SquashAnalyzer/Assets.xcassets/AppIcon.appiconset/Squashanalayzerlogo.png` (webversie: `website/logo.png`). Zet het logo naast de naam, rechtstreeks op zwart, zonder extra omlijsting of schaduw. De tagline staat onder de naam en mag over twee regels lopen:

**Jouw spel scherp in beeld. Voor jou en je team.**

De volledige merkheader hoort op de startpagina. Vervolgschermen krijgen een compacte paginatitel met terugnavigatie; herhaal daar niet overal het logo en de tagline.

## Kleuren

| Token | Waarde | Gebruik |
| --- | --- | --- |
| background | #000000 | Echte zwarte schermachtergrond |
| accent | #F28C26 | Iconen, teamstatistieken en accenten |
| textPrimary | #F2EDE6 | Titels en knopnamen |
| textSecondary | #B3ADA6 | Omschrijvingen, metadata en tagline |
| surface | accent met 7% dekking (teamkaart) en 15% (tegels) | Interactieve kaarten; sinds 1 november 2026 twee niveaus |
| border | accent met 25% dekking (teamkaart, 1 pt) en 70% (tegels, 1,5 pt) | Kaartomlijning |
| hover | accent met 18% dekking | Pointerfeedback |
| pressed | accent met 25% dekking | Aanraakfeedback |
| divider | wit met 13% dekking | Subtiele scheidingslijnen |

De transparante kaartvulling wordt op zwart getekend. Gebruik dezelfde compositie op beide platformen. Geen groen, grijze teamkaart, oranje verloop of gevulde oranje hoofdtegel in deze homepage. Kleur alleen is nooit de enige statusindicator.

## Steunkleur en kleurrollen (1 november 2026)

Na een review van alle schermen (canvas "SquashAnalyzer ontwerpreview") is er één steunkleur bij en heeft elke kleur één taak. Besluit Gerd-Jan, 1 november 2026.

| Token | Donker | Licht | Taak |
| --- | --- | --- | --- |
| accent | #F28C26 | #A94F08 | Merk, speler 1, de ene gevulde hoofdactie (START WEDSTRIJD, COACHKAART), selectie (de gekozen game, de tab Alles) |
| steelBlue | #59738C | #405A73 | Speler 2 en de tegenstander. Nooit voor een neutrale actie zoals Delen |
| **support** (zeegroen) | **#3DBDA9** | **#1A6F63** | Goed nieuws (gewonnen, winners, heatmap, "opgeslagen", sleutel ingesteld) en alles wat live is: de LIVE-pil bij coach en scheidsrechter, de live-markering op het beginscherm, Delen in Wedstrijden en Analyse |
| gold | #E6B859 | #8A6412 | Badges, medailles, de kroon van de winnaar en de markering "afgerond". Niet voor statistiek, selectie, knoppen of avatars |
| warmRed | #D94D4D | #B23B3B | Fouten, STROKE links, foutmeldingen. Niet voor live |

Het groen (#66C773) en de rode LIVE-pil zijn vervallen. Avatars zonder foto krijgen de tekstkleur op een lichte tint, niet goud. Scores en gamestanden staan in het ronde systeemfont; monospace is weg, klokken gebruiken tabulaire cijfers. De baan is in warm licht getekend met de zandkleur als vloer (50%) en `courtLine` als lijn, zodat de zones zichtbaar blijven.

## Beginscherm A3 (1 november 2026)

- Merkheader zonder kader: logo, naam en tagline direct op de achtergrond.
- Geen kop boven de tegels ("Klaar om te spelen?" is vervallen); de tegels zeggen zelf "Start met fluiten" en "Start met coachen". Geen lijn in de plaats, alleen ruimte.
- Tegels Scheidsrechter en Coach: vulling accent 15% (`tileCard`), rand 1,5 pt op 70% (`tileStroke`), icoon 32. Dit zijn de zwaarste kaarten op het scherm.
- Mijn team-kaart: altijd met de getinte balk voor de volgende wedstrijd; vulling 7% (`brandCard`), rand 1 pt op 25%, balk 7%. Datumblok in de kaartkleur met oranje tekst. De schakelaar "Mijn team-kaart met balk" is weg.
- Lijntjes tussen de menurijen: 1 pt wit op 13%.
- Live-markering (zeegroene pil) bij Competitie als er een live teamwedstrijd van je team loopt, en bij Wedstrijd volgen met het aantal wedstrijden dat je volgt.

## Lichte modus — warm licht (10 oktober 2026)

Ontwerp vastgesteld op verzoek van Gerd-Jan; **nog niet geïmplementeerd** in
apps of web. De bestaande donkere modus blijft bestaan. De stijlkaart toont
beide varianten; `tokens.json` bevat de lichte waarden onder `themes.light`.
De bestaande hoofdvelden in dat bestand beschrijven nog steeds donker.

| Token | Licht | Gebruik |
| --- | --- | --- |
| background | #F7F3ED | Warme schermachtergrond |
| surface | #FFFFFF | Witte kaarten |
| textPrimary | #26211C | Titels en bodytekst |
| textSecondary | #71665B | Onderschriften en metadata |
| brandAccent | #F28C26 | Herkenbaar merkaccent; niet voor kleine tekst op licht |
| accent | #A94F08 | Tekst, iconen, links en speler 1 |
| steelBlue | #405A73 | Speler 2 op lichte ondergrond |
| border | #DEC9B4 | Decoratieve kaartrand |
| divider | #E4DBD1 | Subtiele scheidingslijn |
| hover | #FFF6EB | Aanwijzer boven een kaart of knop |
| pressed | #FBE8D3 | Ingedrukte kaart of knop |
| focus | #A94F08 | Zichtbare toetsenbordfocus |

Kaarten houden radius 16, rand 1 en padding 16, zonder schaduw. Typografie,
layout en de gelijke nadruk op Coach en Scheidsrechter blijven behouden.
Gebruik de lichte rand niet als enige herkenning van een invoerveld of selectie;
gebruik daarvoor ook accent, vorm en/of een expliciet label.

Het heldere merkoranje blijft beschikbaar voor decoratie en grotere kleurvlakken.
Tekst en functionele iconen op wit of warm licht krijgen het diepere oranje.
Gebruik op een gevulde donkeroranje knop witte tekst. Voor het bestaande logo
met zwarte achtergrond blijft voorlopig een compact zwart beeldvlak zichtbaar;
de kaart toont dit expliciet. Een transparante logovariant is een afzonderlijke
ontwerpkeuze, geen automatische kleurinversie.

De functionele betekenis van spelers-, LET/STROKE-, fout-, succes-, baan- en
badgekleuren blijft gelijk. Behalve speler 1 en 2 zijn de lichte varianten daarvan
nog per toepassing te bepalen en op contrast te controleren bij implementatie.
De witte servermarkering moet op licht een even duidelijk equivalent krijgen,
met behoud van servicelabel en positie. Zie de [implementatiebacklog](BACKLOG.md#lichte-modus-in-apps-en-web-10-oktober-2026).

## Blauw en functionele wedstrijdkleuren

Blauw is een volwaardig onderdeel van de stijl, geen afwijking van de homepage. Oranje staat in wedstrijden voor speler 1, staalblauw voor speler 2. Gebruik namen, positie en labels naast kleur om het onderscheid duidelijk te houden.

| Bestaande AppColors-token | Hex (afgeronde sRGB) | Gebruik |
| --- | --- | --- |
| steelBlue | #59738C | Speler 2, score, selectie, avatar en statistieken |
| steelBlueDark | #40526B | Diepte / ingedrukte blauwe bediening |
| steelBlueLight | #8094AD | Lichtere blauwe accenten |
| coolSky | #8FBDEB | Beschikbaar lichtblauw accent uit het wedstrijdpalet |
| coolBlue | #6B94D1 | Rechter LET CALL-knop bij scheidsrechter |
| coolIndigo | #8C78E6 | Rechter STROKE-knop bij scheidsrechter |
| warmRed | #D94D4D | Linker STROKE-knop / fout- en waarschuwingstoepassingen |
| courtSand | #D1B899 | Baanvloer |
| courtLine | #BF6B52 | Baanlijnen |

Bron: `SquashAnalyzer/DesignSystem.swift` en `SquashAnalyzer/Views/RefereeView.swift`. De native waarden zijn fracties; hexwaarden zijn afgerond naar 8-bit sRGB. Geen betekenisvolle kleuren blind vervangen door het oranje merkaccent. Actieve server heeft bovendien een expliciet servicelabel en de bestaande witte scoremarkering. Staalblauw niet gebruiken voor kleine bodytekst met onvoldoende contrast; gebruik daar hoofdtekst of steelBlueLight, en behoud blauw in rand, icoon en markering.

In coachmodus blijft de contextafhankelijke invoervolgorde bestaan: score → punttype → zone → slag. De baan is geen permanent nieuw dashboardonderdeel. Analyse behoudt spelersfilters, heatmap en slagkleuren. In scheidsrechtermodus blijven beide scorekolommen en de twee rijen LET CALL / STROKE op dezelfde plaats.

## Typografie en maten

De webpreview is de compositiereferentie; gebruik native systeemfonts voor leesbaarheid en platformondersteuning. iOS gebruikt het afgeronde systeemfont waar beschikbaar; Android een ondersteund systeemfont met vergelijkbare gewichten. Geen extra lettertypeafhankelijkheid vereist.

| Element | Richtmaat | Gewicht / vorm |
| --- | --- | --- |
| Merknaam | 23 pt/sp | Bold, normale schrijfwijze |
| Paginatitel | 20 pt/sp | Semibold, gewone schrijfwijze |
| Sectietitel | 13–14 pt/sp | Semibold |
| Kaarttitel/teamnaam | 20 pt/sp | Semibold |
| Teamstatistiek | 24 pt/sp | Bold, oranje |
| Actietitel | 12–13 pt/sp | Semibold, kapitalen, lichte letterspatiëring |
| Body/menurij | 14–16 pt/sp | Regular |
| Ondersteunende tekst | 12–13 pt/sp | Regular |

De compacte webmockup bevat kleinere onderschriften (9–11 px). Neem die niet blind over als native leesbaarheidsnorm. Ondersteun Dynamic Type/font scaling. Eerst ruimte optimaliseren, nooit tekst afknippen of onleesbaar verkleinen om alles te laten passen.

## Componenten

- **Kaarten:** radius 16 pt/dp, binnenruimte 16. Sinds A3 (1 november 2026) zijn de tegels een stap zwaarder dan de teamkaart: tegels vulling 15% en rand 1,5 pt op 70%, teamkaart vulling 7% en rand 1 pt op 25%. Geen schaduw of decoratieve baanlijnen.
- **Coach en Scheidsrechter:** twee even brede en hoge tegels; circa 110 hoog als startmaat. Oranje icoon (32) boven gecentreerde titel. Onderschriften: “Start met coachen” en “Start met fluiten”. Geen pijltjes, geen kop erboven. De hele tegel is klikbaar. Beide acties zijn even belangrijk.
- **Mijn team:** links uitgelijnde inhoud, label, teamnaam met de stand als badge, gespeeld/punten en de volgende wedstrijd in een getinte balk. Geen pijltje. De hele kaart opent het teamoverzicht. Bij ontbrekende gegevens geen fictieve cijfers tonen; bied een compacte koppelmogelijkheid of lege toestand.
- **Menurijen:** oranje icoon links, tekst en eventueel een chevron rechts. De verwijderde pijltjes gelden voor de teamkaart en de twee actietegels, niet voor alle navigatie.
- **Iconen:** consistente eenvoudige symbolen. Clipboard voor Coach, fluitje voor Scheidsrechter, historie, spelers en medaille. Clipboard, fluitje, spelers, beker, delen en medaille tekent de app zelf als lijnicoon (`OutlineIcons.swift`, 24-raster, lijn 1,8), zodat iPhone en Android hetzelfde tonen (keuze 11 oktober 2026); de overige symbolen gebruiken de platformimplementaties via `AppSymbol`. Geen emoji als bedieningsicoon.

## Layout en toegankelijkheid

Logo circa 58 × 58, buitenmarges 20–24, 10–14 tussen tegels en 16–20 tussen secties. Instellingen rechts in de header. Volg safe areas en systeemnavigatie op beide platformen. Tikdoelen minimaal 44 pt op iOS en 48 dp op Android; ook het instellingenicoon krijgt een groter onzichtbaar tikgebied.

De normale startpagina moet op gangbare telefoons bij standaard tekstgrootte zonder scrollen bruikbaar zijn. Op kleine schermen, bij lange teamnamen en grote systeemtekst blijft scrollen beschikbaar; geen vaste schermhoogte of verborgen overflow. Teamnaam, tagline en vertaalde labels mogen afbreken. Respecteer verminderde beweging en zichtbare toetsenbordfocus.

## Toepassing op andere pagina’s

| Scherm | Overnemen | Behouden |
| --- | --- | --- |
| Spelers, historie, badges, instellingen | Zwarte basis, titels, marges, kaartvorm, iconen en tekstkleuren | Herkenbare badges, spelerfoto’s en functionele statussen |
| Teamdetail | Dezelfde kaart- en statistiekstijl | Duidelijke tabellen en wedstrijdgegevens |
| Wedstrijdstart | Headerhiërarchie, kaartvorm en knopfeedback | Herkenbare spelers en selectiefeedback |
| Live coach / scheidsrechter / analyse | Algemene typografie en consistente navigatie | Spelerkleuren, baanvisualisatie, scorecontrast, LET/STROKE en semantische kleuren |

Vervang functionele score- en spelerskleuren niet globaal door oranje. Het shared UI-package `Packages/SquashAnalyzerUI` is de aangewezen plek voor herbruikbare native stijlen. Harmoniseer daarmee `SquashAnalyzer/DesignSystem.swift` bij de implementatie; voorkom nieuwe losse paletten per scherm.

## Controle bij implementatie

Vergelijk iOS en Android met de stijlkaart. Controleer beide actietegels op gelijke afmetingen en kleuren, logo op zwart, volledige tagline, lange teamnamen, laden/fout/geen team, standaard en vergrote tekst, kleine en grote telefoons en alle vijf bestemmingen. Ontwerpwijzigingen voortaan eerst in deze gids en de tokens bijwerken en vervolgens in de componenten en visuele stijlkaart.
