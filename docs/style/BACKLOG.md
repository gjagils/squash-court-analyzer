# Stijlbacklog voor Claude Code

## Scope en afspraken

De homepage wordt in deze wijziging doorgevoerd voor iOS en Android. De overige schermen krijgen **geen redesign**. De HTML-previews in `docs/homepage-options/pages.html` zijn door de gebruiker afgewezen en mogen niet als implementatiereferentie dienen.

## Nog uit te voeren

- [ ] Inventariseer afwijkende kleuren op vervolgschermen in iOS en het gedeelde Skip/Android-package.
- [ ] Trek alleen achtergrond (echt zwart), primaire/secundaire tekst en algemene oranje accenten gelijk met `docs/style/tokens.json`.
- [ ] Behoud layout, afstanden, knoppen, kaartvormen en bestaande tekstgroottes; uitzondering: paginatitels hieronder.
- [ ] Maak paginatitels consistent 20 pt op iOS / 20 sp op Android, met gewone schrijfwijze: Coach, Scheidsrechter, Coach dashboard, Wedstrijden, Spelers, Alle badges, Mijn team, Instellingen. Laat dynamische speler- en badgenamen intact.
- [ ] Behoud functionele kleuren: oranje/blauw voor de spelers, koel blauw/indigo voor rechter scheidsrechteracties, rood voor STROKE/fouten, baan- en badgekleuren. Gebruik namen/labels naast kleur.
- [ ] Controleer beide platformen met standaard en vergrote tekst. Test navigatie en bestaande flows; beperk de verandering tot presentatie.

## Relevante bronnen

- `docs/style/README.md` en `tokens.json`: ontwerpwaarden en functionele kleuren.
- `SquashAnalyzer/DesignSystem.swift`: iOS-palet.
- `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI`: gedeelde presentatie en lokale paletten.
- `SquashAnalyzer/Views`: iOS-schermen.

Pas niet globaal alle kaartvormen, margins of fonts aan op basis van de oorspronkelijke stijlgids. De latere gebruikersafspraak hierboven gaat voor. Stem af op de laatste code van de foutanalyse; draai geen fixes van andere wijzigingen terug.
