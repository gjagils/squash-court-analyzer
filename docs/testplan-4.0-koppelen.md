# Testdraaiboek 4.0: wedstrijden koppelen zonder spelerscode

Voor Gerd-Jan, 1 november 2026. Zo test je het spelersaccount met een paar
telefoons, zonder dat er testdata in de echte database komt.

**Sinds 9 november 2026 test je met 4.0 build 1 uit TestFlight en Play.** Die praat met
de **echte** server (`account.squashanalyzer.com`), niet met de test-Worker. Gebruik
daarvoor de afvinklijst hieronder. De scenario's A t/m F verderop horen bij de
test-Worker en de eigen testbuilds.

## Testronde build 1: afvinklijst (echte server)

Wat je nu doet komt in de echte database. Speel als jezelf met je echte account, en
verwijder testaccounts aan het eind via de app (ronde 3). Wat nog nooit op een telefoon
is gezien en dus de meeste aandacht verdient: synchroniseren naar een nieuwe telefoon,
tokenvernieuwing na een uur, inloggen met Apple in een uitgeleverde build, en de deellink
via de gepubliceerde pagina `/wedstrijd`.

Noteer per stap: werkte het, hoe lang duurde het, welke tekst was onduidelijk. Bij iets
vreemds een screenshot met de tijd erbij; Claude kan dan de serverlog meelopen laten
(`npx wrangler tail` op de echte account-Worker, vanuit `server/account-worker`).

### Ronde 1: thuis, alleen (ongeveer een uur, plus één keer na een uur)

iPhone = jij als speler (build 1 via TestFlight; als interne tester kan dat vóór Apples
bètareview). A13 = coach, zonder account.

- [ ] **1. Bijwerken over 3.2.** 4.0 op de iPhone installeren zonder iets te wissen.
  Wedstrijden, spelers en badges staan er nog; zonder account werkt alles als in 3.2.
- [ ] **2. Account maken met e-mail** (Instellingen → Mijn account) en de tijd noteren.
  Geboortejaar en toestemming worden gevraagd, daarna ben je ingelogd. E-mail, zodat
  stap 10 ook op Android kan; Apple komt in stap 11.
- [ ] **3. Dit ben ik:** jezelf kiezen uit Mijn team. Je SBN-naam staat bij je account.
- [ ] **4. Postvak, van Android naar iPhone.** A13: best of 1 coachen met jou als
  SBN-speler, tot het eind. De wedstrijd staat in het Postvak op de iPhone.
- [ ] **5. Badges.** iPhone: de wedstrijd gebruiken. Hij staat in Afgeronde wedstrijden
  en telt mee voor je badges.
- [ ] **6. Ben jij "Gerd Lasso"?** A13: partij met een niet-gekoppelde naam (In mijn team
  aan). iPhone: onder Uit je team → **Dat ben ik**. Een volgende partij met Gerd Lasso
  gaat meteen naar het Postvak.
- [ ] **7. Deellink.** A13: partij met iemand buiten het team → **Stuur naar speler** →
  via WhatsApp naar jezelf. Op de iPhone opent de link **de app** (niet de browser);
  Toevoegen werkt; een tweede keer: "al toegevoegd". Herhaal andersom (iPhone-link
  openen op de A13).
- [ ] **8. Zonder netwerk.** A13: vliegtuigmodus aan, partij afmaken, app sluiten;
  netwerk aan, app openen. De wedstrijd komt alsnog aan.
- [ ] **9. Tokenvernieuwing.** Ruim een uur na stap 2 de app helemaal sluiten en openen.
  Nog ingelogd, Postvak laadt, geen "Log opnieuw in". Ook op de A13 als je daar ingelogd
  bent (Android is nog nooit aantoonbaar gezien).
- [ ] **10. Nieuwe telefoon.** Op de A13 inloggen met het account uit stap 2 (of de app op
  de iPhone verwijderen, opnieuw installeren en inloggen). Je geaccepteerde wedstrijden
  staan in Afgeronde wedstrijden en tellen mee voor je badges.
- [ ] **11. Apple.** Op de iPhone uitloggen en een tweede account maken met **Inloggen met
  Apple**. Lukt het, dan dit account in ronde 3 verwijderen. (Apple bestaat op Android
  nog niet.)

### Ronde 2: competitieavond met het team

Spreek vooraf met twee of drie teamgenoten af dat ze build 1 installeren en een account
maken.

- [ ] **Teamwedstrijd vinden zonder uitnodiging.** Jij maakt vanuit Mijn team een
  teamwedstrijd van de wedstrijd van die avond. Een teamgenoot met een account ziet hem
  onder Competitie → Lopende teamwedstrijden en kan **Meedoen**, zonder gedeelde link.
- [ ] **Elkaar coachen of fluiten.** Iemand houdt jouw partij bij, jij die van een ander.
  Ieder kijkt of de partij in zijn Postvak of onder Uit je team staat.
- [ ] **Teamgenoot zonder account.** Jij houdt zijn partij bij; hij maakt de volgende dag
  een account en kiest zichzelf bij Dit ben ik. De wedstrijd staat meteen in zijn Postvak.
- [ ] **Navragen:** wat snapte je niet, en wat ontbrak er?

### Ronde 3: randgevallen en opruimen

- [ ] **Niet ik** bij *Ben jij X?*: weg bij jou, een teamgenoot ziet hem nog.
- [ ] **Blokkeren** vanuit het Postvak: van die telefoon komt daarna niets meer.
- [ ] **Naam wijzigen** in Mijn account.
- [ ] **Jonger dan 16** opgeven: de app maakt geen account.
- [ ] **Account verwijderen**: één testaccount in de app, één via
  squashanalyzer.com/account-verwijderen. Met dat adres komt daarna niets meer terug.

### Stand testronde build 1

| Stap | Stand | Opmerking |
|---|---|---|
| Ronde 1 | Nog niet | |
| Ronde 2 | Nog niet | |
| Ronde 3 | Nog niet | |

## Hoe het werkt (kort)

- Een coach of scheidsrechter vult een wedstrijd in zoals altijd. Aan het eind
  gaat de wedstrijd naar de server voor elke speler die de app kan herkennen:
  - **Gekoppeld aan een SBN-speler** (bij Spelers, regel "SBN-speler"; spelers uit
    Mijn team krijgen die koppeling vanzelf als de naam gelijk is): de wedstrijd
    gaat naar die SBN-speler. Heeft die al een account, dan komt hij in het
    **Postvak**; anders wacht hij tot het account er is (max. 90 dagen).
  - **In Mijn team, maar niet gekoppeld** ("Gerd Lasso"): de wedstrijd gaat als
    "deze naam in dit team". Teamgenoten met een account zien hem onder
    **Uit je team → Ben jij "Gerd Lasso"?**. Tik je **Dat ben ik**, dan telt hij
    voor jou, en de telefoon van de coach leert dat Gerd Lasso jij bent. De
    volgende wedstrijd gaat dan meteen naar jouw Postvak.
  - **Iemand buiten het team**: op het eindscherm **Stuur naar speler** → link
    delen (WhatsApp). Wie de link in de app opent, voegt de wedstrijd toe.
- Oefenpartijen gaan nooit mee.
- Een spelerscode bestaat niet meer in de app.

## De testomgeving (eenmalig inrichten)

Alles gaat naar een **aparte test-Worker met een eigen database**:
`test-account.squashanalyzer.com`, database `squash-account-test`. De echte
database (`squash-account`) blijft leeg. Firebase is hetzelfde project: dat zijn
alleen logins.

Eenmalig in Terminal:

```bash
cd ~/Github/squash-court-analyzer && git pull
```

```bash
cd ~/Github/squash-court-analyzer/server/account-worker && npx wrangler d1 create squash-account-test --jurisdiction eu
```

Geef het `database_id` door aan Claude (die zet het in `wrangler.toml`), en dan:

```bash
cd ~/Github/squash-court-analyzer && git pull && cd server/account-worker && npm run deploy-test
```

Controle: `https://test-account.squashanalyzer.com/health` geeft `{"ok":true}`.
(Ingericht op 1 november 2026; eenmalig `npm ci` in `server/account-worker`.)

## Testlogins

Gebruik je eigen Gmail met een plus: alle mail komt in je eigen inbox.

| Rol | E-mailadres |
|---|---|
| Coach | `gerdjanvangils+coach@gmail.com` |
| Speler 1 (jij) | `gerdjanvangils+speler1@gmail.com` |
| Speler 2 | `gerdjanvangils+speler2@gmail.com` |

Een coach heeft geen account nodig om wedstrijden te sturen; de login is alleen
nodig als de coach zelf ook speler is.

## De telefoons

| Telefoon | Rol | Build |
|---|---|---|
| iPhone-simulator of je iPhone | Coach | 4.0-testbuild tegen de test-Worker |
| Je Android (A13) | Speler 1 | 4.0-test-APK tegen de test-Worker |
| Android-emulator (of een teamgenoot) | Speler 2 | idem |

Claude bouwt de testbuilds (iOS `SQUASH_PLAYER_ACCOUNT=YES SQUASH_ACCOUNT_SERVER=test`,
Android `-PsquashPlayerAccount=true -PsquashAccountServer=test -PsquashTestApp=true`).
Geen upload: installeren via Xcode en `adb install`.

De Android-testapp heet **SA 4.0 test** (`com.squashanalyzer.android.test4`) en
staat **naast** je gewone app: de Play-versie en haar gegevens blijven
onaangeroerd. Weggooien kan gewoon via de app-instellingen van Android.
Pushmeldingen voor live-scores werken in de testapp niet (andere pakketnaam);
voor dit testen is dat niet nodig.

## Met één telefoon: de nep-coach

Het script `dev/send-match.mjs` doet alsof het de telefoon van een coach is
(het onthoudt zijn apparaatsleutel, zoals een echte telefoon). Vanuit
`server/account-worker`:

```bash
node dev/send-match.mjs --test --team https://sbn.toernooi.nl/league/<uuid>/team/<nr> --name "Gerd Lasso"
```

```bash
node dev/send-match.mjs --test --sbn https://sbn.toernooi.nl/league/<uuid>/player/<nr>
```

```bash
node dev/send-match.mjs --test --link
```

```bash
node dev/send-match.mjs --test --links
```

De teamlink en spelerslink kopieer je van sbn.toernooi.nl. `--links` laat zien
wat de nep-coach al geleerd heeft.

## Scenario's

### A. Teamgenoot onder een andere naam ("Gerd Lasso")
1. **Coach**: Mijn team ingesteld (jouw SBN-team). Spelers: maak "Gerd Lasso"
   aan en zet **In mijn team** aan. Laat **SBN-speler** op "Niet gekoppeld".
2. **Coach**: coach een korte wedstrijd (best of 1) Gerd Lasso – Mark, tot het
   eind. Geen oefenpartij.
3. **Speler 1**: Instellingen → Mijn account → account maken met
   `+speler1`, bij Dit ben ik jezelf kiezen uit Mijn team.
4. **Speler 1**: onder **Uit je team** staat *Ben jij "Gerd Lasso"?* met de
   uitslag en de coach. Tik **Dat ben ik** → "De wedstrijd telt mee".
5. **Coach**: open Mijn team opnieuw (of herstart de app). Bij Spelers → Gerd
   Lasso staat nu **SBN-speler: Gerd-Jan van Gils**.
6. **Coach**: nog een wedstrijd met Gerd Lasso. **Speler 1**: hij staat nu in het
   **Postvak** (niet meer onder Uit je team).

### B. Gekoppelde speler zonder account
1. **Coach**: Spelers → een teamgenoot → SBN-speler kiezen (bv. speler 2).
2. **Coach**: wedstrijd met die speler tot het eind.
3. **Speler 2**: maakt pas daarna een account (`+speler2`) en kiest zichzelf bij
   Dit ben ik → de wedstrijd staat meteen in het **Postvak**.

### C. Iemand buiten het team: de link
1. **Coach**: wedstrijd met een speler die niet in Mijn team zit. Op het
   eindscherm **Stuur naar speler** → kies de speler → deel de link naar jezelf.
2. **Speler 1**: open de link op de telefoon. De app opent met *Wedstrijd voor je
   account* → **Toevoegen aan mijn account**.
3. Open dezelfde link nog eens: "al toegevoegd, of de link is verlopen".
4. Let op: zolang de website-aanpassing (pagina `/wedstrijd` en de app-link) niet
   gepubliceerd is, opent de link in de browser. Test dan met
   `squashanalyzer://wedstrijd#<token>` (bv. in Notities tikken) of via de
   nep-coach (`--link` print de link).

### D. Niet ik, en blokkeren
1. Nep-coach: `--team … --name "Kees"`. **Speler 1** ziet *Ben jij "Kees"?* →
   **Niet ik**: weg op deze telefoon; Speler 2 ziet hem nog.
2. Een wedstrijd in het Postvak → **Blokkeren**: daarna komen van die telefoon geen
   wedstrijden meer, ook niet onder Uit je team.

### E. Naam wijzigen en account verwijderen
1. Mijn account → **Naam wijzigen** → nieuwe naam bewaren.
2. **Account verwijderen**: account, wedstrijden en wat de coach-telefoon over
   jou geleerd had zijn weg (de coach ziet bij `--links` niets meer van jou).

### F. Zonder netwerk
1. **Coach**: vliegtuigmodus aan, wedstrijd afmaken, app sluiten.
2. Vliegtuigmodus uit, app openen: de wedstrijd gaat alsnog (Speler ziet hem).

## Opruimen na een testronde

```bash
cd ~/Github/squash-court-analyzer/server/account-worker && npm run reset-test
```

Typ `wissen` als het script erom vraagt. Daarmee is de testdatabase leeg (alleen
`squash-account-test`; het script weigert de echte). De testlogins verwijder je
in de app (Account verwijderen) of in de Firebase-console: Authentication →
Gebruikers → zoeken op `+speler` / `+coach` → verwijderen.

## Wat nog niet in deze ronde zit

- Synchroniseren is gebouwd maar nog niet op een telefoon gezien: zie [de overdracht](overdracht-4.0-spelersaccount.md).
- Inloggen met Google, en Apple op Android.
- "Dit ben ik niet" melden bij Gerd-Jan als iemand anders jouw wedstrijd claimde.
- Een herinnering (push) als er iets in je Postvak staat.

## Stand van de tests (1 november 2026)

| Scenario | Stand | Opmerking |
|---|---|---|
| A. Teamgenoot onder een andere naam | **Geslaagd** (A13) | Gerd Lasso – Paul van Rijn; claim → geaccepteerd; de A13 leerde *Gerd Lasso = Gerd-Jan van Gils* |
| B. Gekoppelde speler zonder account | **Geslaagd** | Paul van Rijn (`satest+speler2`) koos zichzelf bij Dit ben ik: de wachtende wedstrijd stond meteen in zijn Postvak |
| C. De deellink | **Geslaagd** (A13) | Toevoegen werkt; een tweede keer: "al toegevoegd, of de link is verlopen" |
| D. Niet ik | **Geslaagd** (A13) | Verdwijnt bij jou, blijft op de server staan voor de echte Kees. "Niet ik" blijft sinds 1 november ook na een herstart bewaard |
| E. Naam wijzigen en verwijderen | Deels | Naam wijzigen werkt (simulator, lokaal); verwijderen nog niet op de testserver |
| F. Zonder netwerk | Nog niet | |

Onderweg gevonden en hersteld: Opslaan onbereikbaar bij een nieuwe speler op Android (nu bovenaan),
"Ongeldig antwoord" na account maken (veld status ontbrak in Uit je team), en "Log opnieuw in"
zonder knop bij een sessie die de Worker weigert (nu uitloggen en het inlogscherm).
