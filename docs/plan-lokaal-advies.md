# Voorstel: betere regels voor het lokale coachadvies

Status: **gebouwd** op `codex/android-phase4` (1 oktober 2026). Geldt voor iOS en
Android tegelijk: de regels staan in `SquashAnalyzerCore` (`CoachAdvice`), het
dashboard op beide platforms toont ze alleen.

## Besluiten van Gerd-Jan (1 oktober 2026)

1. Drempels zoals voorgesteld (5 punten totaal, 3 per rij of kant, 50% en 70%).
2. Geen vinkje Linkshandig: links/rechts is gezien vanuit de speler die je
   coacht, de coach staat ernaast.
3. Maximaal 5 regels, **op volgorde van potentie**: meeste verloren punten of
   kansen eerst. Gebouwd als `potential` = aantal punten in het geding; wat al
   goed gaat telt voor 0,6 (lets mee 0,5, beste slag per rij 0,5, "Vermijd
   [vak]" 0,8). Bij gelijke potentie gaat een waarschuwing voor.
4. Patronen over games benoemen: een bevinding die ook in een eerdere game van
   de wedstrijd optrad krijgt "Net als in game 1." en de helft van die eerdere
   potentie erbij.
5. Geen "boven het blik": gewone taal ("Speel daar wat hoger en veiliger").

Gebouwd in `CoachAdviceRules.swift` (`CourtSide`, `AreaTally`, `ZoneProfile`),
`AdviceRules.swift` (de regels) en `CoachAdvice.local(in:for:match:)`; de tabel
is `ZoneProfileTable` (SquashAnalyzerUI) op iOS en Android. De kans-regel voor
de tegenstander is "waar maakt de tegenstander fouten" ("waar verliest de
tegenstander" is hetzelfde als "waar win jij" en zou dubbel zijn). Het oude,
ongebruikte iOS-scherm `AnalysisView` is verwijderd.

## Wat er vóór deze versie gebeurde (kort)

Per speler en per game: tempo (korte of lange rally's), eigen fouten en haast,
forced errors, lets, fouten en servicepunten van de tegenstander, "Vermijd
[vak]", "Speel naar [3 vakken]" en "Je [slag] is effectief". Zie
`CoachAdvice.local` en `Game.bestZone`/`recommendedZones`/`bestShotType`.

Zwakke plekken:

1. Vakken tellen **alle** punten met een vak, ook fouten van de tegenstander en
   strokes, en servicepunten krijgen automatisch een achtervak.
2. Geen minimum: na één winner al "Speel naar …" en "Je Drop is effectief".
3. Volleys spelen geen rol in het advies.
4. Er wordt alleen naar losse vakken gekeken, niet naar **voor/midden/achter**
   of **links/rechts**.
5. Teksten wisselen tussen "je" en de naam van de speler.

## Begrippen

Elk punt met een vak valt in een **rij** (voor, midden, achter) en, als het
niet in de middenkolom ligt, in een **kant** (links, rechts). Dat werkt bij 6 en
bij 9 vakken: de middenkolom telt wel mee voor de rij, niet voor de kant.

Per speler tellen we drie soorten punten, elk per rij en per kant:

| Soort | Welke punten | Betekenis |
|---|---|---|
| **Gewonnen** | eigen winners en forced errors | waar de speler punten maakt |
| **Verloren** | winners en forced errors van de tegenstander | waar de tegenstander punten maakt |
| **Fouten** | eigen unforced errors | waar de speler zelf de fout in gaat |

Strokes en servicepunten tellen hier **niet** mee: een stroke zegt niets over
plaatsing, en het vak van een servicepunt is automatisch gekozen.

## Wanneer is iets "vaak"?

Om toeval uit te sluiten geldt een regel pas als er genoeg punten zijn en het
verschil duidelijk is:

- **Rij** (drie rijen, dus "normaal" is een derde): minstens **3 punten** in die
  rij **én** minstens **50%** van die soort punten, bij minstens **5 punten** in
  totaal.
- **Kant** (twee kanten, "normaal" is de helft): minstens **3 punten** aan die
  kant **én** minstens **70%**, bij minstens **5 punten** aan beide kanten samen.
- **Losse vakken en slagen**: minstens **3 punten** (nu is dat 1).

## De nieuwe adviesregels

### A. Waar win je je punten (rij)

| Situatie | Advies |
|---|---|
| Gewonnen vooral **voor** | "Je wint je punten vooral voorin (5 van 8). Blijf de voorhoeken zoeken." |
| Gewonnen vooral **achter** | "Je wint je punten vooral achterin (5 van 8). Je lengte werkt, blijf druk zetten op de achterwand." |
| Gewonnen vooral **midden** | "Je wint je punten vooral vanuit het midden (4 van 7). Blijf de T pakken en de bal vroeg nemen." |

### B. Waar verlies je je punten (rij)

| Situatie | Advies |
|---|---|
| Verloren vooral **voor** | "Je verliest de meeste punten voorin (4 van 6). [Tegenstander] maakt het kort af: sta dichter bij de T en reageer eerder op korte ballen." |
| Verloren vooral **achter** | "Je verliest de meeste punten achterin (4 van 6). [Tegenstander] drukt je naar achteren: werk aan je terugslag uit de achterhoek en speel zelf meer lengte." |
| Verloren vooral **midden** | "Je verliest de meeste punten in het midden (3 van 5). [Tegenstander] neemt de bal vroeg: houd je slagen strakker langs de muur." |

### C. Waar maak je je fouten (rij)

| Situatie | Advies |
|---|---|
| Fouten vooral **voor** | "3 van je 4 fouten maak je voorin. Speel daar met meer marge boven het blik." |
| Fouten vooral **achter** | "3 van je 4 fouten maak je achterin. Kies uit de achterhoek vaker de veilige lengte." |
| Fouten vooral **midden** | "3 van je 4 fouten maak je in het midden. Neem de tijd, ook als de bal makkelijk lijkt." |

### D. Links of rechts (kant)

Dezelfde drie vragen per kant, met de minimums van "Kant":

- Gewonnen: "Je scoort vooral aan de linkerkant (6 van 8)."
- Verloren: "Je verliest de meeste punten aan de rechterkant (5 van 7). Daar zit [tegenstander] sterk."
- Fouten: "Je fouten vallen vooral links (3 van 4)."

**Forehand of backhand:** de app weet niet of een speler links- of
rechtshandig is. Zonder die informatie zegt het advies alleen links/rechts. Zie
de open vraag hieronder: met een vinkje "Linkshandig" bij de speler kan het
advies "backhandkant" of "forehandkant" zeggen. Bij een rechtshandige speler is
links de backhandkant.

### E. Tegenstander: waar ligt de opening

Vervangt "Vermijd [vak]" en "Speel naar [vakken]", nu op basis van rijen en
kanten in plaats van losse vakken:

- "[Tegenstander] verliest de meeste punten achterin (5 van 7). Speel meer lengte."
- "[Tegenstander] maakt de meeste fouten voorin (3 van 4). Dwing [tegenstander] naar voren."
- "Vermijd [vak]" blijft, maar alleen bij minstens 3 winners en forced errors van de tegenstander in dat vak.

### F. Volleys

| Situatie | Advies |
|---|---|
| ≥ 3 eigen punten uit de lucht | "Je wint 3 punten uit de lucht. Blijf de bal vroeg nemen, dat zet druk." |
| ≥ 3 punten uit de lucht van de tegenstander | "[Tegenstander] wint 3 punten uit de lucht. Speel hoger over of strakker langs de muur." |

### G. Beste slag per rij

In plaats van één "beste slag": de slag die per rij het meest scoort, met
minimaal 3 punten. Bijvoorbeeld "Voorin werkt je kill het best (3 punten)".
Een volley telt hierbij mee als dezelfde slag ("Volley drop" telt als drop).

### H. Bestaande regels

- Tempo, eigen fouten, haast, forced errors, lets en servicepunten blijven,
  met dezelfde drempels.
- Alle teksten in de je-vorm voor de speler en met de naam voor de
  tegenstander. Dubbelepunt of zin in plaats van een streepje.

## Hoeveel advies tegelijk

Met deze regels kan de lijst lang worden. Voorstel: **maximaal 5 regels**,
in deze volgorde:

1. Verloren-regels (B, D) en fouten-regels (C), het meest uitgesproken eerst
2. Tegenstander (E)
3. Tempo
4. Gewonnen-regels (A, D), volleys (F), beste slag (G)
5. Overige bestaande regels

"Het meest uitgesproken" = het hoogste percentage boven de verwachting
(boven 33% bij rijen, boven 50% bij kanten).

## Zichtbaar maken in het dashboard

Naast de heatmap een klein **profiel**, op iOS en Android gelijk:

```
          Voor   Midden  Achter     Links  Rechts
Gewonnen    5      1       2          6      2
Verloren    1      1       4          2      4
Fouten      3      0       1          3      1
```

Zo ziet de coach meteen waar het advies op gebaseerd is.

## AI Coach

Dezelfde telling per rij en kant gaat mee in de AI-prompt ("Gewonnen: voor 5,
midden 1, achter 2; links 6, rechts 2" …). Dan kan de AI-coach erop
voortbouwen, en zeggen lokaal advies en AI hetzelfde over de cijfers.

## Bouwen (als het voorstel akkoord is)

1. Core: `CourtSide` (links/rechts/geen), `ZoneProfile` (gewonnen/verloren/
   fouten per rij en kant) en de nieuwe regels in `CoachAdvice`, met tests voor
   elke drempel (net wel en net niet).
2. Core: de oude vakregels aanpassen (alleen winners en forced errors, minimum 3).
3. UI: profieltabel in het iOS-dashboard en `SharedCoachDashboard`.
4. AI-prompt uitbreiden.
5. Handleiding bijwerken (sectie Analyse) en release notes.

## Open vragen voor Gerd-Jan

1. Kloppen de drempels (5 punten totaal, 3 per rij of kant, 50% en 70%)?
   Strenger geeft minder maar betrouwbaarder advies.
2. Een vinkje **Linkshandig** bij een speler, zodat het advies forehand en
   backhand kan noemen? Dat is een kleine toevoeging aan de spelersgegevens
   (opslag op iOS en Android, plus de back-up).
3. Maximaal 5 adviesregels, of liever alles tonen?
4. Moet er ook advies over de **hele wedstrijd** komen (alle games samen), of
   blijft het per game?
5. Kloppen de squashtips in de teksten, of wil je die zelf formuleren?
