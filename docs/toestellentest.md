# Toestellentest Android

Vaste stap vóór elke **productierelease** (App Store en Google Play-productie). Sinds 10 november 2026 niet
meer bij elke testbuild (Gerd-Jan; daarvoor vanaf 7 november wel). De productiescripts stoppen zonder geslaagde run.

```bash
scripts/android_devices.py release
```

Bouwt de debug-APK en draait op **Android 16** (de meest geïnstalleerde: wereldwijd ongeveer 25%, StatCounter, juli 2026; eigen
cijfers per versie hebben we niet) alle profielen en op **Android 17** (de nieuwste) OnePlus, Klein en Groot. Wachttijd ongeveer
30 minuten. Lukt alles, dan mag de upload door (`scripts/toestellen_gate.py`); wijzigt de app daarna, dan moet hij opnieuw. Een
versieverhoging of documentwijziging telt niet. Bekijk de beelden ook zelf. Overslaan kan alleen op verzoek van Gerd-Jan:
`--skip-device-test`. Bij een nieuwe Android-versie: `ANDROIDS` in het script bijwerken.

## Waarom

Een teamgenoot met een OnePlus Nord 3 zag het coachscherm heel anders dan op de A13 en de
iPhone. De app kiest zijn opzet op de ruimte in dp: smaller dan 380 dp valt de titel weg,
lager dan 740 dp wordt het scorebord één regel (`CoachScoringView`). Hoeveel dp een telefoon
heeft, hangt af van het scherm én van de ingestelde schermweergave. De lijst met toestellen is
dus vooral een lijst met schermmaten, en die zijn na te bootsen op één emulator.

## Wat het doet

```bash
scripts/android_devices.py run
```

```bash
scripts/android_devices.py run --only oneplus-nord3,small
```

- Zet per profiel op de emulator de schermmaat, dichtheid, tekstgrootte en navigatie (knoppen of
  gebaren), en loopt dan dezelfde route af: beginscherm met teamwedstrijd, teamwedstrijd,
  Competitie (boven en verder naar beneden), Mijn team, Instellingen, Wedstrijd volgen, Coach
  (tussen de punten, hoe, baan, slag, Eenvoudig) en Scheidsrechter (opzet en wedstrijd).
- Uitkomst: `output/toestellen/<datum>/index.html`, per scherm alle profielen naast elkaar (buiten git).
- Meldt zelf: tekst of knoppen buiten beeld of onder de statusbalk, Badges die niet op het eerste
  scherm past, en stappen die mislukken. **Dat is geen vervanging van kijken:** de run van 7 november
  meldde niets over de waarschuwingsdriehoek bij Ophalen bij SBN; die zag ik op de beelden.
- Draait alleen op een emulator; een echt toestel weigert het script. Hij wist eerst de appgegevens
  op de emulator. De teamwedstrijd van de test staat alleen op de telefoon: het script stopt als
  *Deel met mijn team* niet uit staat (zie "Wat er misging").

Emulator: `SA_Toestellen`, een eigen AVD met 10 GB data. Het script wist de appgegevens op de
emulator, dus deze staat los van `Medium_Phone_API_36.1` (sinds 7 november gewist, ook 10 GB).

```bash
~/Library/Android/sdk/emulator/emulator -avd SA_Toestellen -no-window -no-audio -no-snapshot
```

## De profielen

| Profiel | Maat in dp | Waarom |
| --- | --- | --- |
| OnePlus Nord 3, grote weergave | 354 x 792 | De teamgenoot. De dichtheid is afgeleid: de schermafbeelding heeft de compacte opzet zonder titel |
| Samsung Galaxy A13 | 384 x 856 | Gerd-Jans toestel. **Dichtheid geschat**, nog te controleren met `adb shell wm density` op de A13 |
| Samsung Galaxy A57, schermzoom | 345 x 748 | Competitie-avond 30 oktober; zoomstand geschat |
| Klein | 360 x 740 | De ondergrens die we verwachten |
| Smal (vouwtelefoon dicht) | 344 x 882 | Smal maar hoog: de titel weg, wel het volle scorebord |
| Grote tekst | 411 x 914, tekst 1,3 | Toegankelijkheid |
| Groot (Pixel Pro XL) | 448 x 997 | De bovengrens |

Een nieuw toestel met een klacht wordt een extra regel in `PROFILES`.

## Wat het niet ziet

- Fabrikantaanpassingen (OxygenOS, One UI), andere systeemlettertypen, en gedrag dat alleen op
  een trage telefoon opvalt. Het is Android 16 op de emulator; de app ondersteunt vanaf Android 9.
- Live en teamwedstrijden met anderen: de test deelt bewust niets.

## Eerste run, 7 november 2026

Alle route-stappen liepen op alle profielen. Gevonden op de beelden:

| Wat | Status |
| --- | --- |
| Lege balk van ongeveer 58 dp boven Coach en Scheidsrechter op elk Android-toestel: de lege band op de schermafbeelding van de OnePlus | Hersteld |
| Waarschuwingsdriehoek in plaats van het icoon bij *Ophalen bij SBN* (Android) | Hersteld |
| OnePlus krijgt een ander coachscherm: één regel als scorebord, geen titel | Grens van 740 naar 705 dp (zie "Compacte opzet"); de titel blijft weg onder 380 dp breed |
| Op 345-360 dp breed en ongeveer 740 dp hoog valt *Badges* half onder de rand; scrollen kan | Open, klein |
| Een lege partij heet "All Inn Squash 8 E1"; op smalle schermen valt de E-aanduiding weg (het rondje E1 staat er wel) | Open, klein |

## Wat er misging

De eerste versie van het script zette *Deel met mijn team* niet echt uit. Daardoor stond op 7
november rond 01:15 ongeveer 10 minuten een lege testwedstrijd "All Inn Squash 8 - Squash Delft 8" op de
echte live-server, en dus mogelijk op het clubscherm van All Inn. Hij is met *Live stoppen*
verwijderd. De gebruikscijfers kunnen er één teamwedstrijd van tellen. Het script controleert dit nu
vóór het aanmaken en stopt anders.

## Compacte opzet

Het scorebord wordt één regel als de ruimte tussen de systeembalken onder 705 dp is. Gemeten op 7 november op de
emulator (de echte statusbalk kan hoger zijn; dan zakken de waarden):

| Profiel | Scherm | Boven + onder | Beschikbaar |
| --- | --- | --- | --- |
| OnePlus Nord 3, grote weergave | 354 x 792 | 24 + 48 | 720 |
| Galaxy A57, schermzoom | 346 x 749 | 24 + 24 | 701 |
| Klein | 360 x 740 | 24 + 48 | 668 |
| Galaxy A13 | 384 x 856 | 24 + 48 | 784 |

Bij 680 en 700 dp kreeg de A57 het volle scorebord en verdween *Annuleren* bij de baan. De instructie staat nu altijd op
één regel. Dit blijft een marge van een paar dp: bij een klacht de maat van dat toestel erbij zetten.

## Echte toestellen: Firebase Test Lab

```bash
scripts/test_lab.py
```

Een automatische rondgang (Robo) van maximaal 5 minuten per toestel op een Galaxy A13 (Android 14) en een OnePlus Nord CE 3 Lite
(Android 14, OxygenOS). Hij ziet wat de emulator mist: de schermen van de fabrikant en echte hardware. Het Firebase-project
`squash-analyzer-18fb3` heeft geen betaalkoppeling, dus er zijn geen kosten; de grens is 5 runs per dag op echte toestellen
([prijzen](https://firebase.google.com/docs/test-lab/usage-quotas-pricing)). Elk toestel telt als een run. Inloggen eenmalig met `gcloud auth login`.

Robo tikt op alles, ook op LIVE. Daarom stuurt de app niets naar de live-server als Android `firebase.test.lab` meldt
(`isFirebaseTestLab` in `MainActivity.kt`). Wie dit nabootst: `svc wifi disable` haalt een emulator niet van het netwerk (7 november
kwam zo een testwedstrijd "Test A - Test B" op de live-server; meteen gestopt).

Google sluit Test Lab op 30 september 2027; daarna is de opvolger Developer Device Platform (melding van `gcloud`).
