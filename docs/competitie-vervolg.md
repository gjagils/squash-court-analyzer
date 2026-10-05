# Competitie: vervolgpunten (6 oktober 2026)

Gerd-Jan vroeg op 5 oktober (avond) na de eerste versie van Competitie om
deze punten. Uploaden naar TestFlight of Play hoeft nog niet. Dit bestand is
de werklijst; een sessie die verder gaat (ook de herinnering van 00:00)
begint hier, vinkt af wat klaar is en commit per punt.

- [ ] **Deel verslag met dezelfde drie opties als bij een wedstrijd:**
      Scorekaart, Verslag en Plaatje (`MatchShareChoice`), met voorbeeld en
      één knop Delen. Core: `TeamMatchReport.text(_:style:)` en
      `ResultCard.from(teamMatch:)`; UI: een deelscherm voor teamwedstrijden
      naast `SharedMatchShareView`.
- [ ] **Bij "Kies wedstrijd" ook een nieuwe, bij te houden wedstrijd starten**
      (coach of scheidsrechter) voor deze partij. Na afloop wordt hij
      automatisch aan de partij gekoppeld, zonder de vraag van de speeldag.
- [ ] **Bij Spelers aangeven of een speler in jouw team zit** (vlag per
      speler, zonder schemawijziging: `TeamRoster` in Core, opgeslagen in de
      instellingen; zie "Besluiten" hieronder). De selectieknopjes bij een
      partij tonen die spelers, aangevuld met Mijn team.
- [ ] **Teamwedstrijden (en de teamvlag) in de back-up**: optionele velden in
      `FullBackup`, formatVersion 4, terugzetten bij Voeg toe en Vervang
      alles, op iOS en Android.
- [ ] **Antwoord: wat is er nodig voor live teamwedstrijden?** Uitgewerkt in
      `docs/plan-live-teamwedstrijd.md` (alleen een plan, niet gebouwd).
- [ ] Docs: `docs/wijzigingen-builds.md` (releasenotetekst), `ARCHITECTURE.md`,
      handleiding op de website (en publiceren met
      `npx wrangler deploy -c server/website-worker/wrangler.jsonc`).

## Besluiten

- De teamvlag van een speler staat in een eigen lijst (ids in
  `UserDefaults`, via `TeamRoster`), niet in SwiftData of Room: geen V8 en
  geen Room-migratie midden in de testperiode. De lijst reist mee in de
  back-up. Een echte kolom op de speler kan later.
- Niets uploaden naar TestFlight of Play tot Gerd-Jan het zegt.
