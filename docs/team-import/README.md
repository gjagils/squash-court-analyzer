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

## Importeren via een link

Een team kan ook met een link in de app komen, op iPhone (**Spelers → importeer-icoon → Via link**) en Android (**Spelers → Team**). De app accepteert alleen links van de vorm `https://squashanalyzer.com/teams/<code>/<naam>.zip` (ook `www.`). Het bestand achter de link is precies dezelfde zip als hierboven. Controle en samenvoegen zijn gedeeld (`TeamImport` in SquashAnalyzerCore): iOS gebruikt `TeamImportService`, Android `RoomTeamImporter`.

## Een team op squashanalyzer.com zetten (alleen de beheerder)

Er is geen uploadformulier. Gerd-Jan zet teams online, op verzoek van een captain of coach. Zie ook de privacyverklaring ("Teams op squashanalyzer.com").

1. **Toestemming**: de captain bevestigt dat alle spelers in het team akkoord zijn met naam en foto op de site.
2. **Inhoud nakijken**: alleen `name`, `photo` en eventueel `focus`. **Haal `notes` weg** (coachingnotities horen niet online). Controleer dat de zip in de app importeert.
3. **Code maken**: een lange willekeurige mapnaam, bijvoorbeeld `openssl rand -hex 12`. Zet de zip in `website/teams/<code>/team.zip`. Die map staat in `.gitignore`: teambestanden met namen en foto's gaan **nooit** in git (de repo is openbaar).
4. **Online zetten**: upload `teams/<code>/team.zip` via Portainer, zoals de rest van de website. `robots.txt` houdt `/teams/` uit zoekmachines; nginx toont geen maplijst.
5. **Link delen** met de captain: `https://squashanalyzer.com/teams/<code>/team.zip`.
6. **Verwijderen of bijwerken** op verzoek: vervang of verwijder het bestand op de server, binnen een maand. Een speler weghalen = nieuwe zip zonder die speler.

Houd lokaal (buiten git) een lijstje bij welke code bij welk team en welke captain hoort, zodat een verwijderverzoek snel af te handelen is.

## Voorbeeldspelers bij installatie

De app levert twee voorbeeldspelers mee, **Bombardino** en **Whiskey** (met foto),
zodat je meteen een wedstrijd met "Kies speler" kunt proberen. Ze zitten als
gewone team-zip in `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/voorbeeldspelers.zip`
(foto's 512 px) en gaan via dezelfde teamimport erin: iOS
`TeamImportService.addSamplePlayersIfNew`, Android in `MainActivity`. Dat gebeurt
één keer (`SamplePlayers`, UserDefaults-sleutel `samplePlayersSeeded`) en alleen
als er nog geen spelers zijn, dus bestaande gebruikers krijgen ze niet bij een
update. Verwijder je ze, dan komen ze niet terug. Niet tijdens tests en
screenshot-scenario's.
