# Roadmap per release

Gekozen door Gerd-Jan op 31 oktober 2026; de twee meldingen zijn op 4 november 2026 van 3.3 naar 4.0 verplaatst; op 10 november 2026 gingen spelers vergelijken en Linkshandig naar 4.1. De bronnen zijn de
[persona-backlog](backlog-personas-2026-10-11.md), de
[backlog van 21 oktober](backlog-2026-10-21.md) en de
[buildbacklog](wijzigingen-builds.md#backlog). Hoe 3.x en 4.0 naast elkaar
lopen staat in het [releaseplan](releaseplan-3x-4.0.md).

## 3.1 (in de stores sinds 2 november 2026, opgevolgd door 3.2)

| Punt | Bron |
|---|---|
| Vorige uitslag en stand van de tegenstander vanuit het programma | T5 — **gebouwd 31 oktober** |
| Trainingsmodus: oefenpartij zonder badges en zonder telling in het profiel | C8 — **gebouwd 31 oktober** |

## 3.2 (in de stores: build 4, App Store sinds 8 november 2026)

| Punt | Bron |
|---|---|
| SquashLevels-profiellink bij een speler | [plan](plan-squashlevels-profiel.md) — **gebouwd** (build 2; opruimen bij verwijderen 7 november) |
| Voortgang naar de volgende badgetrede ("nog 2 tot zilver") | buildbacklog — **gebouwd** (build 2) |
| Onderlinge stand bij Kies speler | buildbacklog — **gebouwd** (build 2) |
| Scouting: profiel van de tegenstander openen, ook vanuit het programma | C6 — **gebouwd** (build 2) |
| Officiële timers voor de scheidsrechter | R2 — **gebouwd** (build 2) |
| De vlag `Features.playerAccount` (uit) en de tests in beide standen | [releaseplan](releaseplan-3x-4.0.md) — **gebouwd** |
| Teamwedstrijd op het beginscherm, Competitie compleet, Niet gezien bij coachen, Nieuw in 3.2 en kleinere punten | 7 november, zie [wijzigingen](wijzigingen-builds.md) — **gebouwd** (build 3) |

Na 3.2 gaat het werk naar **4.0** (besluit Gerd-Jan, 7 november 2026): het account is het eerste grote nieuwe ding
en houdt andere wensen tegen. Geen 3.3 tussendoor tenzij hij erom vraagt.

**Parallel aan 4.0, op de server:** het clubscherm verder (QR-code naar de app op het lege scherm, losse wedstrijden
erop; [voorstel](voorstel-clubscherm.md)).

**Naast 3.2, alleen op de server:** het clubscherm voor de tv, als gratis proef
met een geheime link ([voorstel](voorstel-clubscherm.md)). **Gebouwd 3 november 2026.**

## 3.3

| Punt | Bron |
|---|---|
| Coachingfocus koppelen aan cijfers | C7 — **gebouwd 4 november 2026** (op `main`, in de volgende 3.2-build) |

## 4.0

| Punt | Bron |
|---|---|
| Spelersaccount met centrale badges, kaart, vorm en trend | [voorstel](voorstel-spelersaccount-4.0.md) |
| Teamwedstrijd vinden zonder uitnodiging: teamleden met een account zien een lopende live-teamwedstrijd van hun team en doen mee (gekozen op 6 november 2026) | [voorstel](voorstel-teamwedstrijd-vinden-4.0.md) — **gebouwd**, kaart op het beginscherm 10 november; handleiding nog niet |
| Seizoensoverzicht per teamlid: in Mijn team, uit de SBN-stand en de teamwedstrijden in de app (keuze Gerd-Jan, 10 november 2026) | T2 — **gebouwd 10 november** |
| Badgecategorie Teamspeler: een reeks met treden voor gespeelde competitiepartijen, plus de badge Matchwinnaar (keuze Gerd-Jan, 10 november 2026) | T7 — **gebouwd 10 november** |
| Melding als een teamgenoot een partij invult tijdens een live teamwedstrijd: wie maakt of meedoet volgt vanzelf, met een melding bij de start en de uitslag van andermans partij (verplaatst van 3.3 op 4 november 2026; keuze Gerd-Jan, 10 november 2026) | T6 — **gebouwd 10 november**, nog niet op een telefoon geprobeerd |
| Avatar bij je account: een foto die je zelf instelt, met toestemming dat wie jou als speler of tegenspeler kiest hem mag zien. De app haalt hem vanzelf op bij een speler die aan jouw SBN-naam gekoppeld is; een eigen foto op die telefoon gaat voor. Met melden van een foto, privacybeleid, Play-gegevensveiligheid en Apple-privacy (gevraagd door Gerd-Jan, 10 november 2026, in build 2) | **gebouwd 10 november**; server: migratie 0004 en uitrol nog doen |
| Nette accountmails: afzender SquashAnalyzer van noreply@squashanalyzer.com, je-vorm in nl/en, link naar de eigen pagina squashanalyzer.com/account/ in plaats van firebaseapp.com (gevraagd door Gerd-Jan, 10 november 2026). Firebase weigert template-wijzigingen voor dit project; supportverzoek lukte nog niet (fout bij versturen). Alternatief: zelf versturen via de account-Worker en een maildienst | [mailteksten](firebase-mailteksten.md) — **pagina live, DNS-records (SPF, firebase=, DKIM) staan in Cloudflare**; templates en actie-URL nog niet |

Al gebouwd, van de 4.0-lijst gehaald op 10 november 2026: de losse melding bij een gewonnen game, partij of
einduitslag als je live volgt. Die zit sinds 3.0 in de live-Worker (`scoreAlert` en `teamAlert` in
`server/live-worker/src/push.js`, iOS en Android) en staat uit te zetten in Instellingen → Live meekijken.

## 4.1

| Punt | Bron |
|---|---|
| Spelersprofiel: twee spelers vergelijken, en AI Coach-advies over de trend (gekozen op 7 november 2026, naar 4.1 op 10 november 2026) | [wijzigingen](wijzigingen-builds.md) |
| Vinkje Linkshandig bij een speler, zodat de focus Backhand en Voorhand de juiste kant van de baan toont (gekozen op 4 november 2026, naar 4.1 op 10 november 2026) | [bewuste keuzes](bewuste-keuzes.md) |

## Na 4.0

| Punt | Bron |
|---|---|
| Conduct-straffen | R3 |
| "No let" en appeals vastleggen | R4 |
| Blessuretimer per soort en opgave | R6 |
| Wedstrijdformulier als pdf | R8 |
| Liggend scherm en tablet | R9 |
| Verslag voor de speler als pdf of plaatje | C5 |
| Geavanceerde coachmodus (plek van winner en fout, start-tik per rally) | A1–A3 |
| Vergelijken met de officiële SBN-uitslag | T3 |
| Opstelling plannen | T4 |
| Koppeling met toernooi.nl | T8 |
| Scores doorgeven aan SBN | B2 |
| Coachen betaald, scheidsen en delen gratis | B3 |
| Clubabonnement voor het clubscherm | B1 |

## Later, nog niet gepland

| Punt | Bron |
|---|---|
| Vraag om een beoordeling in App Store en Play na een paar wedstrijden ("hoeft niet nu", 7 november 2026) | [persona-backlog](backlog-personas-2026-10-11.md) |
| Clubranglijst | [wijzigingen](wijzigingen-builds.md) |
| Spelersprofiel exporteren als plaatje | [wijzigingen](wijzigingen-builds.md) |
| Na meedoen direct je partij kiezen (eerst een speelavond afwachten) | [voorstel](voorstel-teamwedstrijd-eenvoudiger.md) |
| Uitleg bij het eerste gebruik van Competitie | [voorstel](voorstel-teamwedstrijd-eenvoudiger.md) |
| Knop "Clubscherm openen" in de app (mogelijk vervallen door de geheime link) | [voorstel](voorstel-clubscherm.md) |
| Privacylabels App Store en Play gelijktrekken (Gerd-Jan, in de consoles) | [code-analyse](backlog-code-analyse-2026-10-06.md) |
| Afspreken wie wekelijks de crashes bekijkt | [persona-backlog](backlog-personas-2026-10-11.md) |
| `testen.html` omzetten naar downloadlinks na de launch | [persona-backlog](backlog-personas-2026-10-11.md) |
| Levels en ranglijsten van SquashLevels in de app (vraagt een afspraak met SquashLevels) | [plan](plan-squashlevels-profiel.md) |
| Nieuw seizoen: historie bewaren en een nieuwe teamlink (S2). **Vóór september 2027**: de seizoenslink staat vast in de app | [backlog](backlog-2026-10-21.md) |

## Weggehaald

| Punt | Bron |
|---|---|
| Programma in je agenda (.ics) | T1 |
| Stand omroepen | R7 |
| Invoer zonder te kijken (Apple Watch, klikker) | R10 |
