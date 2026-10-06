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
| surface | accent met 10% dekking | Alle interactieve kaarten |
| border | accent met 35% dekking | Dunne kaartomlijning |
| hover | accent met 18% dekking | Pointerfeedback |
| pressed | accent met 25% dekking | Aanraakfeedback |
| divider | wit met 9% dekking | Subtiele scheidingslijnen |

De transparante kaartvulling wordt op zwart getekend (circa #180E04). Gebruik dezelfde compositie op beide platformen. Geen groen, grijze teamkaart, oranje verloop of gevulde oranje hoofdtegel in deze homepage. Kleur alleen is nooit de enige statusindicator.

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

- **Kaarten:** radius 16 pt/dp, rand 1 pt/dp, binnenruimte 16. Mijn team en beide actietegels delen exact dezelfde vulling, rand en afronding. Geen schaduw of decoratieve baanlijnen.
- **Coach en Scheidsrechter:** twee even brede en hoge tegels; circa 110 hoog als startmaat. Oranje icoon boven gecentreerde titel. Onderschriften: “Start met coachen” en “Start met fluiten”. Geen pijltjes. De hele tegel is klikbaar. Beide acties zijn even belangrijk.
- **Mijn team:** links uitgelijnde inhoud, label, teamnaam, stand/gespeeld/punten en volgende wedstrijd. Geen pijltje. De hele kaart opent het teamoverzicht. Bij ontbrekende gegevens geen fictieve cijfers tonen; bied een compacte koppelmogelijkheid of lege toestand.
- **Menurijen:** oranje icoon links, tekst en eventueel een chevron rechts. De verwijderde pijltjes gelden voor de teamkaart en de twee actietegels, niet voor alle navigatie.
- **Iconen:** consistente eenvoudige symbolen. Clipboard voor Coach, fluitje voor Scheidsrechter, historie, spelers en medaille. Gebruik de bestaande platformimplementaties; geen emoji als bedieningsicoon.

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
