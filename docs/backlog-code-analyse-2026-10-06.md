# Backlog uit code-analyse van 6 oktober 2026

Bron: `docs/code-analyse-2026-10-06.md` (stand `19fabb8`). Hier staat per punt
wat er mee gedaan is. Status: `[x]` opgelost met test, `[~]` deels of anders
opgelost (met uitleg), `[ ]` open, `[?]` wacht op een besluit van Gerd-Jan,
`[-]` niet van toepassing of al opgelost (met reden). Elke wijziging is een
eigen commit op `main`; nummers verwijzen naar het rapport (B = bug, §).

Afspraken: niets uploaden naar TestFlight of Play, geen versieverhoging
(`AGENTS.md`). Een punt dat een besluit vraagt (schema, back-upformaat,
badgeregels, kosten) wordt niet zonder jou doorgevoerd.

## Voor build 19 en voor het publiceren van de website

- [ ] B1 Deep-linkpatroon `/team*` kaapt de teamzip-links (AASA, manifest, `invite(from:)`)
- [ ] B2 Teamwedstrijden-bestand: atomisch schrijven, decodefout niet maskeren, versie, `restore` laat fouten zien, `BackupCounts`
- [ ] B3 Vernieuwen keert het perspectief om (`linkedOwnIsPlayer1`)
- [ ] B4 Foute of verlopen teamsleutel zichtbaar maken (verificatie bij Deelnemen, 401, `offline` in `TeamLiveCard`)
- [ ] B5 Privacytekst, releasenote, `PrivacyInfo.xcprivacy`, Google Fonts van `kaart/`, `jurisdiction('eu')`
- [ ] B19 Website: Play-knop op `team/` en `kaart/`, treden in de iPhone-handleiding, "wekelijks", Mijn team

## Sprint: Competitie en live robuust

- [ ] B6 `SessionSaver.save(exit:)` tijdens `busy`
- [ ] B7 Teamsleutel geeft schrijf- en wisrechten op alles (slot- of eigenaarssleutel, `fromLive` clampen)
- [ ] B8 Eén transiente 404 wist de live-sleutel; lege partij pushen; `retryPending` bij `onResume`
- [ ] B9 Speeldag-vraag pusht niet; `TeamTrackRequest`/500 ms
- [ ] B10 Back-up: `matchId` bij export, leeg vs. nil, `importFromJSON` dedupen
- [ ] B11 `loadHistory` committeert half-ingevoegde rijen, `keepAsAbandoned` slikt fouten
- [?] B12 Losse spellen onzichtbaar op iOS (tonen of `.game`-import weigeren)
- [ ] B13 Kaart-import en team-uitnodiging botsen met de modals
- [?] B14 Opgave/walkover in het teammodel; reglementsbron voor de gelijkspelregel
- [?] B15 Hat trick wordt elke wedstrijd opnieuw uitgereikt (exact of once)
- [ ] B16 Back-upformaat 4 golden bytes en iPhone-v4-fixture voor Android
- [ ] B17 Room-migraties: schema-assets, rewind-tests
- [ ] B18 `readJson` vroeg afbreken
- [ ] B20 Scripts: `asc_api.py` timeout, `play_upload.py` afkappen
- [ ] Laag: de lijst "Laag" uit §2, per punt hieronder afgevinkt zodra gedaan

## Cloudflare en CI

- [?] Kostenbesluit: Workers Paid of WebSocket-hibernation (SSE houdt het object wakker)
- [ ] Worker-vitest in `ci.yml`
- [ ] `workers_dev: false`, `website/404.html`, `deploy-website.yml` laten falen zonder screenshots/teams
- [ ] `server/live-worker/README.md` met de teamendpoints; `deploy-live-beta.yml` tekst

## Doorlopend opruimen

- [ ] Gedeelde basisklasse `LiveSession`/`TeamSession`
- [ ] Eén `LiveSender` voor `LiveShare`/`TeamLive`
- [ ] `TeamMatchSupport` naar Core met tests; `TeamMatch.swift` en `SharedTeamMatchViews.swift` splitsen
- [ ] `SharedFonts`, `SectionHeader`, `ChoiceChip`, `CloseButton`; `lint.sh` op `.font(.system(size:`
- [ ] Skip: `keyboardType` op Android, alert-patroon, `"plus"`-icoon
- [ ] Docs-drift uit §7, `docs/archief/`, `docs/skip-valkuilen.md`
- [ ] Tests uit §6 (lijst met prioriteit)
