# Competitie: vervolgpunten (5 en 6 oktober 2026)

De eerste punten zijn gebouwd op 5 oktober; live teamwedstrijden en herstel van de koppeling volgden op 6 oktober. Wat nog open is, staat onderaan.

Gerd-Jan vroeg op 5 oktober (avond) na de eerste versie van Competitie om
deze punten. Uploaden naar TestFlight of Play hoeft nog niet. Dit bestand is
de werklijst; een sessie die verder gaat (ook de herinnering van 00:00)
begint hier, vinkt af wat klaar is en commit per punt.

- [x] **Deel verslag met dezelfde drie opties als bij een wedstrijd:**
      Scorekaart, Verslag en Plaatje (`MatchShareChoice`), met voorbeeld en
      één knop Delen. Core: `TeamMatchReport.text(_:style:)` en
      `ResultCard.from(teamMatch:)`; UI: een deelscherm voor teamwedstrijden
      naast `SharedMatchShareView`.
- [x] **Bij "Kies wedstrijd" ook een nieuwe, bij te houden wedstrijd starten**
      (coach of scheidsrechter) voor deze partij. Na afloop wordt hij
      automatisch aan de partij gekoppeld, zonder de vraag van de speeldag.
- [x] **Bij Spelers aangeven of een speler in jouw team zit** (vlag per
      speler, zonder schemawijziging: `TeamRoster` in Core, opgeslagen in de
      instellingen; zie "Besluiten" hieronder). De selectieknopjes bij een
      partij tonen die spelers, aangevuld met Mijn team.
- [x] **Teamwedstrijden (en de teamvlag) in de back-up**: optionele velden in
      `FullBackup`, formatVersion 4, terugzetten bij Voeg toe en Vervang
      alles, op iOS en Android.
- [x] **Antwoord: wat is er nodig voor live teamwedstrijden?** Uitgewerkt in
      `docs/plan-live-teamwedstrijd.md` (oorspronkelijk plan, inmiddels gebouwd op 6 oktober).
- [x] Docs: `docs/wijzigingen-builds.md` (releasenotetekst), `ARCHITECTURE.md`,
      handleiding op de website (en publiceren met
      `npx wrangler deploy -c server/website-worker/wrangler.jsonc`).

## Besluiten

- De teamvlag van een speler staat in een eigen lijst (ids in
  `UserDefaults`, via `TeamRoster`), niet in SwiftData of Room: geen V8 en
  geen Room-migratie midden in de testperiode. De lijst reist mee in de
  back-up. Een echte kolom op de speler kan later.
- Niets uploaden naar TestFlight of Play tot Gerd-Jan het zegt.
- Gerd-Jan koos op 5 oktober: lichte lijst voor de teamvlag, formaat 4 voor de
  back-up accepteren, live per telefoon, en bij een nieuwe wedstrijd vanuit
  een partij is de thuisspeler Speler 1.

## Gebouwd op 6 oktober

- [x] **Live teamwedstrijd** (kijkerslink, uitnodiging met link of code,
      iedere telefoon zet zijn eigen partij erop, punt voor punt vanuit een
      gekoppelde coach- of scheidsrechterwedstrijd, standaardnamen
      "Teamnaam E1", wissen na 2 uur). Keuzes en uitwerking:
      `docs/plan-live-teamwedstrijd.md`.
- [x] **Setup-optie "Onderdeel van een teamwedstrijd"** bij Coach en
      Scheidsrechter (partij kiezen en wie onze speler is).
- [x] **Een lopende gekoppelde wedstrijd blijft gekoppeld na verlaten en
      hervatten** (Gerd-Jan vond dit): `TeamPartij.trackingMatchId` en
      `trackingOwnIsPlayer1` bewaren de koppeling en de gebruikte namen in de
      teamwedstrijd; `TeamMatchSupport.track` zet ze bij het starten,
      `TeamMatchSupport.target(forMatchId:)` haalt ze terug bij Hervatten.
      Getest op de simulator (starten, Stop met bewaren, app herstarten,
      hervatten, punt: de livepagina liep door).

## Nog open

- Op een echte telefoon proberen (iPhone en A13 hebben de debug-build van
  6 oktober; Gerd-Jan heeft het nog niet geprobeerd).
- Upload van build 19 naar TestFlight en Play: alleen als Gerd-Jan het zegt.
