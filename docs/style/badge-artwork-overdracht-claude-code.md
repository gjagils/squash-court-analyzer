# Overdracht badge-artwork aan Claude Code

## Actuele status (6 oktober 2026)

Artwork én integratie zijn afgerond en uitgeleverd in iOS 2.2 (18) en Android 0.5 (5). De oude achttien imagesets zijn opgeruimd; de app heeft 37 badgefamilies en 71 varianten. De secties hieronder beschrijven de oorspronkelijke artworkoverdracht; de laatste sectie beschrijft de afgeronde integratie.

## Oorspronkelijke artworkoverdracht

Het artwork uit `docs/style/badge-prompt-codex.md` is gemaakt: 17 badges met elk drie treden (51 ontwerpen) en 7 nieuwe badges zonder treden. In totaal 58 ontwerpen, 174 transparante PNG-bestanden en 58 `Contents.json`-bestanden.

Codex heeft alleen artwork, assetmetadata, controle-overzichten en documentatie toegevoegd. Er is geen Swift-, Kotlin- of websitecode aangepast. De badge-logica, selectie van de juiste trede en koppeling in de schermen zijn hiermee nog niet geïmplementeerd of getest.

Het artwork en deze overdracht worden samen in Git opgenomen. Bestaande badges zijn behouden.

Lokale repository: `/Users/gerd-janvangils/Github/squash-court-analyzer`.
Alle paden hieronder zijn relatief aan deze repository, zodat dit document ook op een andere checkout bruikbaar is.

## Wat staat waar?

Gebruik `<naam> = <id>-bronze`, `<id>-silver` of `<id>-gold` voor een trede. Voor de zeven nieuwe badges is `<naam>` alleen het id, zonder tredeachtervoegsel.

| Doel | Locatie | Formaat |
|---|---|---|
| Groot bronartwork | `design/badges-src/badge-<naam>.png` | 1024 × 1024, PNG met alpha |
| iOS-afbeelding | `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-<naam>.imageset/badge-<naam>.png` | 240 × 240, PNG met alpha |
| iOS-assetmetadata | Dezelfde imageset, bestand `Contents.json` | Eén universal-afbeelding |
| Website-afbeelding | `website/badges/<naam>.png` | 180 × 180, PNG met alpha |
| Volledige lijst van opgeleverde artworkbestanden | `design/badges-src/BESTANDEN.md` | Alle individuele paden |
| Gebruikte generatieprompts | `design/badges-src/PROMPTS.md` | Ingebouwde imagegen-tool, bestaande badges als referentie |
| Visuele controle: eerste 9 reeksen | `design/badges-src/overzicht-treden-1-56px.png` | Bestaand, brons, zilver en goud naast elkaar |
| Visuele controle: overige 8 reeksen | `design/badges-src/overzicht-treden-2-56px.png` | Bestaand, brons, zilver en goud naast elkaar |
| Visuele controle: 7 nieuwe badges | `design/badges-src/overzicht-nieuw-56px.png` | Alle nieuwe badges op 56 px |
| Deze overdracht | `docs/style/badge-artwork-overdracht-claude-code.md` | Integratieoverzicht |

Voorbeeld voor zilveren drop-it:

- Assetnaam in de iOS-catalogus: `badge-drop-it-silver` (zonder `.png`).
- Bron: `design/badges-src/badge-drop-it-silver.png`.
- iOS: `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-drop-it-silver.imageset/badge-drop-it-silver.png`.
- Website: `website/badges/drop-it-silver.png`.

Voorbeeld voor een nieuwe badge:

- Assetnaam: `badge-rock-solid`.
- Bron: `design/badges-src/badge-rock-solid.png`.
- iOS-imageset: `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-rock-solid.imageset/`.
- Website: `website/badges/rock-solid.png`.

De bestaande iOS-assets staan in de resourcecatalogus van het package SquashAnalyzerUI. Gebruik bij integratie de bestaande manier om afbeeldingen uit dat package te laden.

## Badges met treden

De tabel bevat de drempels uit de oorspronkelijke opdracht; het betreffende getal staat ook in het artwork. De bestandsachtervoegsels zijn exact `bronze`, `silver` en `gold`.

| id | Wat | Brons | Zilver | Goud |
|---|---|---|---|---|
| five-in-a-row | punten achter elkaar | 5 | 7 | 10 |
| drop-it | dropwinners in één game | 4 | 6 | 8 |
| kriss-cross | crosswinners in één game | 4 | 6 | 8 |
| drive-me-crazy | drivewinners in één game | 4 | 6 | 8 |
| boast-buster | boastwinners in één game | 4 | 6 | 8 |
| lob-story | lobwinners in één game | 4 | 6 | 8 |
| volleywood | volleywinners in één game | 4 | 6 | 8 |
| ace-of-pace | servicewinners in één game | 4 | 6 | 8 |
| front-row-king | winners voorin in één game | 5 | 7 | 9 |
| back-from-the-death | punten achterstand ingehaald | 5 | 7 | 9 |
| endurance | seconden in één rally | 60 | 90 | 120 |
| iron-man | minuten wedstrijd | 60 | 75 | 90 |
| hat-trick | gewonnen wedstrijden op rij | 3 | 5 | 7 |
| nemesis | keer gewonnen van dezelfde tegenstander | 5 | 10 | 20 |
| ten-out-of-ten | gewonnen wedstrijden in totaal | 10 | 25 | 50 |
| centurion | punten in totaal | 100 | 500 | 1000 |
| veteran | gespeelde wedstrijden | 25 | 50 | 100 |

Speciale koppelingen:

- `five-in-a-row-gold` is 10 punten op rij en gebruikt het oude `perfect-ten`-ontwerp als basis. Volgens de opdracht gaat de losse badge `perfect-ten` op in deze gouden trede. Het oude bestand is nog aanwezig; handel logica en eventuele bestaande behaalde badges af bij integratie.
- `ten-out-of-ten` blijft het technische id, ook voor de zilveren drempel 25 en gouden drempel 50.
- `endurance` gebruikt seconden; `iron-man` gebruikt minuten. Er staan alleen getallen in de nieuwe afbeeldingen, geen eenheden.

## Nieuwe badges zonder treden

Deze zeven bestanden hebben een gouden rand en géén `-gold` in de naam.

| id | Wat | Beeld (suggestie uit de opdracht) |
|---|---|---|
| rock-solid | wedstrijd gewonnen zonder unforced errors | bal tegen een stenen muur/rots, schild |
| back-wall-boss | 5 winners vanuit de achterste vakken in één game | achterwand van de baan, bal die vanuit achteren wegschiet, getal 5 |
| sneltrein | game gewonnen in minder dan 6 minuten | snelle trein of stopwatch met snelheidslijnen, getal 6 |
| vette-winst | wedstrijd gewonnen, tegenstander in geen game boven 5 | bal met trofee of dikke vlammen, getal 5 |
| clubicoon | tegen 10 verschillende tegenstanders gespeeld | clubhuis/schild met tien kleine silhouetten, getal 10 |
| rivalen | 10 wedstrijden tegen dezelfde tegenstander | twee gekruiste rackets, getal 10 |
| hand-out-held | 5 rally's achter elkaar gewonnen bij serve van de ander | hand die de bal onderschept, getal 5 |

`rock-solid` heeft geen getal in het artwork. De overige zes hebben het getal uit de oorspronkelijke opdracht.

## Bestaande badges die ongewijzigd blijven

Geen nieuwe varianten gemaakt voor:

`eleven-nil`, `going-the-distance`, `clean-sweep`, `cool-under-pressure`, `full-house`, `houdini`, `off-the-mark`, `double-trouble`, `brick-wall`, `unbreakable`, `photo-finish`, `stroke-of-genius`, `marathon-man`.

Ook de oude imagesets zonder tredeachtervoegsel van de 17 omgezette badges en `perfect-ten` staan nog op hun oorspronkelijke locatie. Verwijder oude assets pas nadat verwijzingen en eventuele migratie zijn afgehandeld en de nieuwe treden werken.

## Nog te doen bij integratie

1. Lees de bestaande badge-implementatie en koppel de ids en drempels hierboven aan de juiste berekeningen. De artworkopdracht specificeert niet alle randgevallen, bijvoorbeeld de afhandeling van onbekende foutregistratie of historische resultaten.
2. Selecteer de juiste assetnaam voor de behaalde trede en voeg de zeven nieuwe badges aan de catalogus en relevante schermen toe. Houd de bestaande resource-bundleconstructie van iOS aan.
3. Werk eventuele websiteverwijzingen naar badges bij; de PNG-bestanden staan al klaar onder `website/badges/`.
4. Controleer hoe Android badge-afbeeldingen momenteel laadt. Codex heeft geen Android-resources aangemaakt of aangepast. Hergebruik de aangeleverde PNG's via de bestaande laad- of exportmethode; als Android drawable-bestanden nodig heeft, gebruik dan geldige Android-resourcenamen (bijvoorbeeld underscores in plaats van koppeltekens).
5. Controleer de afhandeling van bestaande behaalde badges, met name `perfect-ten`, en test drempels en weergave op beide platforms.
6. Haal de laatste versie van de repository op voordat je op een andere checkout begint; het artwork en de metadata zijn met deze overdracht in Git opgenomen.

## Uitgevoerde controle

Alle 58 ontwerpen zijn in de drie gevraagde afmetingen aanwezig. PNG-alpha en imagesetmetadata zijn gecontroleerd. De getallen en het onderscheid tussen de treden zijn visueel op 56 pixels beoordeeld. Dit is een artworkcontrole; er is geen app-build of functionele badgetest uitgevoerd voor deze oplevering.

## Integratie (Claude Code, 5 oktober 2026)

Het artwork is gekoppeld; logica, schermen en back-upcompatibiliteit zijn op de Mac getest (zie de resultaten onderaan). Uitgeleverd in build 18 / Android 0.5 (5).

- **`BadgeKind`** (`Packages/SquashAnalyzerCore/.../BadgeEngine.swift`): de
  zilveren en gouden treden zijn eigen cases met de ids `<id>-silver` en
  `<id>-gold`; brons houdt het oude id, zodat al verdiende badges brons blijven.
  `perfect-ten` blijft bestaan als de gouden trede van `five-in-a-row` (het id
  staat op kaarten en mag niet veranderen). `family`, `tier`, `series`,
  `threshold`, `tierSummary` en `BadgeKind.families` beschrijven de reeksen;
  `imageName` wijst naar `badge-<id>-<trede>` of `badge-<id>`.
- **Regels** (`BadgeEngine`): een reeks kent elke trede toe waarvan de drempel is
  gehaald. Nieuw: Rock solid en Vette winst alleen als alle games rally voor
  rally zijn bijgehouden (`BadgeMatchInput.isFullyTracked`), Sneltrein op de
  gameduur (`BadgeGame.duration`), Hand-out held op de server per rally
  (`BadgeRally.server`; in scheidsrechtermodus afgeleid van de vorige rally),
  Clubicoon/Rivalen in `careerBadges`.
- **Schermen:** `SharedBadgeCatalogView` toont per badge de drie treden
  (`BadgeSeriesArtwork`); `SharedPlayerBadgesView`, de kaartafbeelding (iOS
  `PlayerCardImage`, Android `CardImage.kt`) en de strip na de wedstrijd tonen
  per badge de hoogste trede. Android laadt de plaatjes zoals voorheen uit het
  gedeelde asset-catalogus van SquashAnalyzerUI; er zijn geen drawables nodig.
- **Website:** `website/kaart/index.html` kent alle 71 ids en toont per badge
  de hoogste trede; `website/badges/` toont de treden naast elkaar.
- **Gedaan op de Mac (5 oktober 2026):** de oude imagesets `badge-<id>.imageset`
  van de zeventien omgezette badges en `badge-perfect-ten.imageset` zijn
  verwijderd (71 imagesets over); `website/badges/<id>.png` van die achttien
  blijft staan voor oude kaartlinks. Getest op de iPhone 17 Pro Max-simulator
  (iOS 26.5) en de Android-emulator Medium Phone API 36.1: catalogus met drie
  medaillons per reeks, coachwedstrijd met acht drops (gouden Drop it like
  it's hot op de strip, "Goud · 1×" bij de speler, drie momenten), badgekaart
  in app en browser, scheidsrechter 11-3/11-4/11-5 (Vette winst en Clean
  sweep), en een back-up van build 17 met een oude `perfect-ten` (verschijnt
  als gouden 5 points in a row, niets dubbel). Screenshots in
  `docs/screenshots-oktober/ios-badges-*.png` en `android-badges-*.png`.

