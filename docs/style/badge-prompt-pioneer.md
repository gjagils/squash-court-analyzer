# Testbadge "Pionier": omschrijving en artworkopdracht

> **Open opdracht (18 oktober 2026).** Het artwork is nog niet gemaakt en de
> logica nog niet gebouwd. Kopieer voor het artwork alles onder de lijn.

## Waarom deze badge

Bij de productierelease (3.0) gaan alle badges terug naar 0. Gekozen (18
oktober 2026): een vaste startdatum in Core (`seasonStart`). Awards van vóór die
datum worden verborgen, niet gewist. De datum zetten we pas als de
indiendatum vaststaat. Testers verliezen zo hun verzameling; deze ene badge
bedankt ze ervoor en blijft na de reset staan.

## Omschrijving in de app

| Veld | Tekst |
|---|---|
| id (`BadgeKind`) | `pioneer` |
| Naam | Pionier |
| Uitleg in de catalogus | Testte SquashAnalyzer mee vóór de release |
| Uitleg bij het verdienmoment | Bedankt voor het testen! Je badges uit de testperiode zijn bewaard, maar tellen niet meer mee. |
| Treden | Geen (één variant) |
| Eenmalig (`isOnce`) | Ja |
| Categorie | Speciaal (niet bij de carrièrebadges) |

**Wie hem krijgt:** elke spelerskaart met minstens één actieve award van vóór
`seasonStart`. Dat zijn dus de spelers die in de testperiode badges verdienden,
ook tegenstanders en trainingsmaatjes van de testers.

**Hoe (voor de bouw):** bij de eerste start van de releasebuild kent elk
toestel de badge toe aan de kaarten die aan die voorwaarde voldoen. Daarbij
geldt `earnedAt = seasonStart` en `matchId` is een vaste UUID in Core. Omdat het
award-id uit kaart, badge en wedstrijd wordt afgeleid, maakt elk toestel
hetzelfde record. Bij het samenvoegen van kaarten komt hij dan maar één keer
voor. Hij valt zelf niet onder de verberg-regel, want hij is verdiend op
`seasonStart` en niet ervoor.

---

Maak één nieuwe badge-afbeelding voor de app SquashAnalyzer in deze repository.
Alleen plaatjes; pas geen Swift- of Kotlin-code aan.

## Stijl (gelijk aan de bestaande badges)

Bekijk eerst de bestaande badges in
`Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-*.imageset/`
(bijvoorbeeld `badge-clubicoon`, `badge-off-the-mark`, `badge-centurion`) en houd die stijl precies aan:

- Ronde medaille, transparant daarbuiten, vult het vierkant bijna helemaal.
- Low-poly / gefacetteerde illustratie, koningsblauwe achtergrond in de cirkel,
  oranje en goudgele accenten (vlammen, vegen, vonken).
- Een zwarte squashbal met precies twee gele stippen.
- Geen tekst, geen getal, geen letters of symbolen (ook geen β).
- Rand: dun goud (#E8B547), zoals de badges zonder treden. Geen brons of zilver,
  want dit is geen trede.

## Motief

Een oranje vlag geplant op de T van een squashbaan (de rode lijnen in
perspectief, licht gefacetteerd). Op de vlag staat het vergrootglas van het
app-icoon (`AppIcon.svg`) als eenvoudig embleem. De zwarte squashbal ligt vóór de
vlagstok. Een paar goudgele vonken rond de vlag: de eerste die er stond. Het
moet op 56 pt nog leesbaar zijn: vlag, vergrootglas en bal zijn de enige
hoofdvormen.

## Bestanden

| Doel | Locatie | Formaat |
|---|---|---|
| Groot bronartwork | `design/badges-src/badge-pioneer.png` | 1024 × 1024, PNG met alpha |
| iOS-afbeelding | `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets/badge-pioneer.imageset/badge-pioneer.png` | 240 × 240, PNG met alpha |
| iOS-assetmetadata | Dezelfde imageset, `Contents.json` (één universal-afbeelding, zoals `badge-clubicoon.imageset`) | |
| Website-afbeelding | `website/badges/pioneer.png` | 180 × 180, PNG met alpha |

Zet de gebruikte prompt onder `## badge-pioneer.png` in `design/badges-src/PROMPTS.md`
en de vier paden in `design/badges-src/BESTANDEN.md`.

Voorbeeldprompt voor de generator:

> Use case: new badge in an existing set. Create ONE 1024x1024 PNG SquashAnalyzer medal with genuine transparent background, matching the provided existing badges exactly in style: faceted low-poly illustration, royal-blue circular field, orange and golden accents, thin gold rim #E8B547. Motif: an orange flag planted on the T of a squash court (red court lines in perspective), the flag carries a simple magnifying-glass emblem; a black squash ball with exactly two yellow dots lies in front of the flagpole; a few small golden sparks around the flag. No text, no numbers, no letters or symbols. Readable at 56px. Circle almost fills square with entire rim visible, fully transparent outside. Output badge-pioneer.png.
