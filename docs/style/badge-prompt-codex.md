> **Afgeronde artworkopdracht van 5 oktober 2026.** Dit is de oorspronkelijke prompt, geen nieuwe opdracht. De treden zijn inmiddels geïntegreerd en uitgeleverd in build 18; zie [de overdracht](badge-artwork-overdracht-claude-code.md).

# Prompt voor Codex: badge-artwork voor brons, zilver en goud

Badges krijgen treden (brons, zilver, goud), plus een paar nieuwe badges. Claude
Code bouwt de logica; Codex maakt alleen de plaatjes. Kopieer alles onder de lijn.

---

Maak badge-artwork voor de app SquashAnalyzer in deze repository. Alleen plaatjes;
pas geen Swift- of Kotlin-code aan.

## Stijl (gelijk aan de bestaande 31 badges)

Bekijk eerst de bestaande badges in
`Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-*.imageset/`
(bijvoorbeeld `badge-five-in-a-row`, `badge-drop-it`, `badge-centurion`) en houd die stijl precies aan:

- Ronde medaille, transparant daarbuiten, vult het vierkant bijna helemaal.
- Low-poly / gefacetteerde illustratie, koningsblauwe achtergrond in de cirkel,
  oranje en goudgele accenten (vlammen, vegen, vonken).
- Een zwarte squashbal met twee gele stippen komt in elke badge terug.
- Getallen groot, crèmewit, dik en goed leesbaar op klein formaat (56 pt in de app).
- Geen tekst behalve het getal; geen namen of woorden.

## Treden: de rand bepaalt de trede

De bestaande badges hebben een dunne gouden rand. Voortaan:

- **Brons:** rand koperbrons (#B87333), illustratie verder gelijk.
- **Zilver:** rand zilver (#C0C7CF), iets meer glans.
- **Goud:** rand goud (#E8B547), met een paar extra vonken rond de rand.

Het getal in de badge is de drempel van die trede (bijvoorbeeld 4, 6, 8). Laat
de illustratie per trede gelijk (dezelfde compositie), alleen getal en rand
verschillen, zodat je ze als reeks herkent.

## Welke plaatjes

Per badge met treden drie plaatjes: `badge-<id>-bronze.png`, `badge-<id>-silver.png`,
`badge-<id>-gold.png`. Het bronzen plaatje is de bestaande badge met een bronzen
rand en het getal van de bronzen trede.

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

`perfect-ten` (10 op een rij) wordt de gouden trede van five-in-a-row; gebruik
het bestaande perfect-ten-plaatje als basis voor `badge-five-in-a-row-gold.png`.

Badges zonder treden (eleven-nil, going-the-distance, clean-sweep,
cool-under-pressure, full-house, houdini, off-the-mark, double-trouble,
brick-wall, unbreakable, photo-finish, stroke-of-genius, marathon-man) blijven
zoals ze zijn.

## Nieuwe badges (één plaatje per badge, gouden rand zoals nu)

| id | Wat | Beeld (suggestie) |
|---|---|---|
| rock-solid | wedstrijd gewonnen zonder unforced errors | bal tegen een stenen muur/rots, schild |
| back-wall-boss | 5 winners vanuit de achterste vakken in één game | achterwand van de baan, bal die vanuit achteren wegschiet, getal 5 |
| sneltrein | game gewonnen in minder dan 6 minuten | snelle trein of stopwatch met snelheidslijnen, getal 6 |
| vette-winst | wedstrijd gewonnen, tegenstander in geen game boven 5 | bal met trofee of dikke vlammen, getal 5 |
| clubicoon | tegen 10 verschillende tegenstanders gespeeld | clubhuis/schild met tien kleine silhouetten, getal 10 |
| rivalen | 10 wedstrijden tegen dezelfde tegenstander | twee gekruiste rackets, getal 10 |
| hand-out-held | 5 rally's achter elkaar gewonnen bij serve van de ander | hand die de bal onderschept, getal 5 |

## Bestanden en formaten

1. Maak elk plaatje eerst groot (1024 × 1024, transparant) en bewaar die in
   `design/badges-src/` (nieuwe map).
2. Zet een verkleinde versie van **240 × 240** (PNG met transparantie) in een
   eigen imageset: `.../Module.xcassets/badge-<naam>.imageset/badge-<naam>.png`,
   met een `Contents.json` zoals de bestaande imagesets (één universal-afbeelding).
3. Zet een versie van **180 × 180** in `website/badges/<naam>.png` (zonder
   `badge-`-voorvoegsel, zoals de bestaande bestanden daar).
4. Laat de bestaande imagesets (`badge-<id>.imageset`) staan; Claude Code ruimt
   ze op als de treden werken.
5. Controleer op klein formaat (56 px) dat het getal leesbaar is en de drie
   treden van één badge duidelijk verschillen.

Lever een lijst op van alle gemaakte bestanden.
