# Team importeren (spelers met foto)

Maak een map met een `team.json` en een map `photos/`, zip die map, en kies het zip-bestand in de app via **Spelers → importeer-icoon** (het pijltje naast +).

```
team/
├── team.json
└── photos/
    ├── gerd-jan.jpg
    └── gerrie.jpg
```

`team.json`:

```json
{
  "team": "Squash Club 1",
  "players": [
    { "name": "Gerd-Jan van Gils", "photo": "photos/gerd-jan.jpg", "focus": ["Backhand", "Conditie"], "notes": "Linkshandig" },
    { "name": "Gerrie Ananias",    "photo": "photos/gerrie.jpg" },
    { "name": "Kristian Koster" }
  ]
}
```

- Alleen `name` is verplicht. `photo` is een pad relatief aan `team.json`; `focus` gebruikt de tags uit de app (Conditie, Voorhand, Backhand, Serve, Volley, Drop, Boast, Beweging, Achterwand, Mentaal, Tactiek, Snelheid).
- Bestaande spelers worden op naam gematcht (hoofdletterongevoelig) en bijgewerkt, niet gedupliceerd. Velden die in de import ontbreken blijven staan.
- Foto's worden vierkant gecropt en verkleind tot 512px; JPG, PNG en HEIC werken.
- Het hele bestand wordt eerst gecontroleerd; bij een fout (ontbrekende foto, onbekende tag) wordt er niets geïmporteerd.
- Foto's gaan mee in de gewone backup/restore.

Zippen op de Mac: rechtsklik op de map → *Comprimeer*. Op de iPhone: in Bestanden lang drukken op de map → *Comprimeer*.
