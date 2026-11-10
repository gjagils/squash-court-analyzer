# Testronde 4.0 build 1: twee telefoons, twee accounts

Voor Gerd-Jan, 10 november 2026. Een kortere versie van de afvinklijst in het
[testdraaiboek](testplan-4.0-koppelen.md), voor thuis met twee telefoons:

| Telefoon | App | Account |
|---|---|---|
| iPhone | 4.0 (1) uit TestFlight | **Gerd-Jan van Gils** |
| A13 | 4.0 (1) uit Play | **Kristian Koster** |

Build 1 praat met de **echte** server. De meldingen van je teamwedstrijd, Seizoen per
speler en de nieuwe badges (Teamspeler, Matchwinnaar) zitten pas in build 2; die test je
nu dus niet.

Noteer per stap: werkte het (✓/✗), hoe lang duurde het, welke tekst was onduidelijk. Bij
iets vreemds: screenshot en de tijd. Claude kan dan de serverlog van de account-Worker
meelezen.

## 0. Klaarzetten (2 minuten)

- [ ] Op beide telefoons: Instellingen → **Mijn account** toont de goede naam en je bent
  ingelogd.
- [ ] Op beide telefoons staat in **Mijn team** hetzelfde team (het team van jou en
  Kristian). Staat het er op de A13 niet, kies het daar eerst.

## 1. Dit ben ik (5 minuten)

- [ ] **iPhone:** Mijn account → **Dit ben ik** → kies Gerd-Jan uit Mijn team. Je
  SBN-naam staat daarna bij je account.
- [ ] **A13:** hetzelfde, kies Kristian Koster.
- Let op: staat Kristian niet in het SBN-team, dan kan dat op de A13 niet. Noteer dat en
  sla stap 3 over; stap 2, 4 en 5 werken ook zonder.

## 2. Postvak: van A13 naar iPhone (10 minuten)

- [ ] **A13:** Coach, best of 1, Gerd-Jan tegen Kristian (uit Mijn team), speel uit tot
  het eind en sla op.
- [ ] **iPhone:** de wedstrijd staat in het **Postvak** (Mijn account). Hoe lang duurde
  het?
- [ ] **iPhone:** gebruik hem. Hij staat in Afgeronde wedstrijden en telt mee voor je
  badges.
- [ ] **A13:** kijk of de wedstrijd ook bij Kristian zelf staat, of in zijn Postvak.
  Noteer wat je ziet.

## 3. Postvak: van iPhone naar A13 (10 minuten)

- [ ] **iPhone:** Scheidsrechter, best of 1, Kristian tegen Gerd-Jan, tot het eind.
- [ ] **A13:** de wedstrijd staat in het Postvak van Kristian; gebruiken lukt.
- [ ] **iPhone:** krijg jij hem ook in je Postvak, of telt hij meteen? Noteer wat je ziet.

## 4. Teamwedstrijd vinden zonder link (15 minuten)

- [ ] **iPhone:** Mijn team → kies een wedstrijd uit het programma → maak er een
  **teamwedstrijd** van. Stuur géén link.
- [ ] **A13:** Competitie → **Lopende teamwedstrijden**: de teamwedstrijd staat er, met
  **Meedoen**. Tik erop.
- [ ] **A13:** het beginscherm (Mijn team-kaart) toont de balk met de teamwedstrijd.
- [ ] **A13:** vul partij E2 in (een paar punten is genoeg). **iPhone:** de stand van E2
  verschijnt in de teamwedstrijd (ververst elke minuut).
- [ ] **iPhone:** vul E1 in. **A13:** E1 verschijnt.
- [ ] Stop de teamwedstrijd op de iPhone (Live stoppen). Op de A13 verdwijnt hij uit
  Lopende teamwedstrijden.

## 5. Deellink (10 minuten)

- [ ] **A13:** partij met iemand buiten het team (typ een naam) → op het eindscherm
  **Stuur naar speler** → via WhatsApp naar jezelf.
- [ ] **iPhone:** tik op de link. Hij opent **de app** (niet de browser); Toevoegen
  werkt. Tik de link nog eens: "al toegevoegd".
- [ ] Andersom: iPhone maakt de link, A13 opent hem.

## 6. Zonder netwerk (5 minuten)

- [ ] **A13:** vliegtuigmodus aan, korte partij met Gerd-Jan tot het eind, app sluiten.
- [ ] Vliegtuigmodus uit, app openen. **iPhone:** de wedstrijd komt alsnog in het
  Postvak.

## 7. Na een uur (1 minuut, later)

- [ ] Ruim een uur na het inloggen op beide telefoons de app helemaal sluiten (wegvegen)
  en opnieuw openen. Nog ingelogd, Postvak laadt, geen "Log opnieuw in". Op Android is
  dit nog nooit gezien, dus vooral de A13 telt.

## 8. Opruimen

- [ ] Is het account van Kristian een testaccount? Verwijder het dan op de A13: Mijn
  account → **Account verwijderen**. Daarna staat het niet meer in de app en kun je met
  dat adres niet meer inloggen.
- [ ] Zet de testpartijen en de teamwedstrijd eventueel weg op beide telefoons.

## Uitslag

| Stap | ✓/✗ | Tijd | Opmerking |
|---|---|---|---|
| 0. Klaarzetten | ✓ | | 10 nov |
| 1. Dit ben ik | ✓ | | 10 nov, Gerd-Jan en Kristian |
| 2. A13 → iPhone | ✓ | | 10 nov |
| 3. iPhone → A13 | ✓ | | 10 nov; Postvak zit te diep in Instellingen → voorstel blok op het beginscherm |
| 4. Teamwedstrijd zonder link | ✓ | | 10 nov; aanbod kwam eerder onder Competitie dan op het beginscherm → kaart vraagt nu elke minuut |
| 5. Deellink | – | | overgeslagen: minder belangrijk zolang spelers zelf een account maken |
| 6. Zonder netwerk | ✓ | | 10 nov |
| 7. Na een uur | | | |
| 8. Opruimen | | | |

Al gezien op 10 november: de verificatiemail van Firebase is kaal (u-vorm, afzender
"squash-analyzer-18fb3"). Dat staat op de roadmap; je hoeft het niet opnieuw te melden.
