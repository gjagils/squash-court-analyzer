# Toestellentest Android (voorstel)

Stand 7 november 2026: script gebouwd en één keer over alle profielen gedraaid. **Nog niet
verplicht in de uploadstap:** dat besluit Gerd-Jan (zie "Te besluiten").

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

## Wanneer

Niet bij elke PR, wel voor elke build die naar testers buiten gaat (keuze Gerd-Jan, 7 november):
als stap vóór `scripts/play_upload.py`, naast de `ui-check`. Wachttijd **ongeveer 21 minuten** voor
alle profielen op de Mac; mijn werk daarna is de beelden bekijken, een paar minuten. Niet in GitHub
Actions: daar is een emulator traag en de Mac heeft alles al.

## Eerste run, 7 november 2026

Alle route-stappen liepen op alle profielen. Gevonden op de beelden:

| Wat | Status |
| --- | --- |
| Lege balk van ongeveer 58 dp boven Coach en Scheidsrechter op elk Android-toestel: de lege band op de schermafbeelding van de OnePlus | Hersteld |
| Waarschuwingsdriehoek in plaats van het icoon bij *Ophalen bij SBN* (Android) | Hersteld |
| OnePlus krijgt een ander coachscherm: één regel als scorebord, geen titel | Bewust zo, maar **te besluiten** |
| Op 345-360 dp breed en ongeveer 740 dp hoog valt *Badges* half onder de rand; scrollen kan | Open, klein |
| Een lege partij heet "All Inn Squash 8 E1"; op smalle schermen valt de E-aanduiding weg (het rondje E1 staat er wel) | Open, klein |

## Wat er misging

De eerste versie van het script zette *Deel met mijn team* niet echt uit. Daardoor stond op 7
november rond 01:15 ongeveer 10 minuten een lege testwedstrijd "All Inn Squash 8 - Squash Delft 8" op de
echte live-server, en dus mogelijk op het clubscherm van All Inn. Hij is met *Live stoppen*
verwijderd. De gebruikscijfers kunnen er één teamwedstrijd van tellen. Het script controleert dit nu
vóór het aanmaken en stopt anders.

## Te besluiten

1. **Verplicht maken?** Voorstel: ja, als vaste stap in `docs/opleveren-en-hosting.md`, en
   `play_upload.py` waarschuwt als er voor deze build geen run is.
2. **Compacte opzet:** de grens van 740 dp stamt van vóór het weghalen van de lege balk. Lager
   (bijvoorbeeld 680 dp) geeft de OnePlus hetzelfde scorebord als de A13, maar minder ruimte voor de baan.
   Voorstel: proberen op de profielen en dan kiezen.
3. **Echte toestellen erbij?** Firebase Test Lab heeft echte telefoons, ook om OxygenOS en One UI te zien.
   Gratis: 5 runs per dag op fysieke toestellen (samen 30 minuten), daarna 5 dollar per
   toestel-uur ([prijzen](https://firebase.google.com/docs/test-lab/usage-quotas-pricing)). Welke
   Samsung- en OnePlus-modellen er zijn, is nog niet nagekeken. Voorstel: pas doen als de emulator
   een klacht niet kan naspelen; het vraagt een Firebase-project dat Gerd-Jan zelf aanmaakt.
