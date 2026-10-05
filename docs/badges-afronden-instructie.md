# Instructie voor Claude Code op de Mac: badges afronden en testbuilds maken

Kopieer alles onder de lijn in Claude Code in de lokale checkout
(`/Users/gerd-janvangils/Github/squash-court-analyzer`). De cloudsessie van 5
oktober heeft de treden en de nieuwe badges gebouwd op branch
`claude/great-pasteur-eyskxy`; deze instructie laat dat lokaal verifiëren,
opruimen, bouwen en uploaden. De concepten voor releasenotes en website staan
onderaan; pas ze aan als het testen iets anders laat zien.

---

Rond de badge-integratie af en maak voor iPhone én Android een testbuild, met
releasenotes en websiteteksten. Gerd-Jan heeft al akkoord gegeven voor de
upload: vraag alleen tussendoor iets als een stap faalt of iets op het toestel
niet klopt. Werk stap voor stap en meld na elke stap kort wat je zag.

## 0. Lees eerst

- `docs/style/badge-artwork-overdracht-claude-code.md` (sectie "Integratie"):
  wat er is gebouwd en waarom `perfect-ten` zijn id houdt.
- `docs/wijzigingen-builds.md`, blok "Volgende build": de gebruikerstekst.
- `docs/android-port.md`, secties "Nieuwe Skip-eigenaardigheden" en "Drie
  nieuwe, echte Skip-bugs": de valkuilen bij transpileren.
- `docs/google-play.md`, "Uploaden met het script", en de kop van
  `scripts/testflight_distribute.py` voor de uploadcommando's.

## 1. Branch ophalen

```bash
git fetch origin
git checkout claude/great-pasteur-eyskxy
git merge --ff-only origin/claude/great-pasteur-eyskxy
```

De branch bevat alles van `main` plus één commit (`13ade79`). Werk op deze
branch; merge naar `main` pas in stap 9.

## 2. Automatische tests (nog niets uploaden)

Draai alles en los wat rood is op zonder tests te verzwakken:

```bash
scripts/lint.sh
swift test --package-path Packages/SquashAnalyzerCore
skip test --package-path Packages/SquashAnalyzerCore
swift test --package-path Packages/SquashAnalyzerUI
cd Android && ./gradlew :app:testDebugUnitTest && cd ..
xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation
cd Android && ./gradlew :app:connectedDebugAndroidTest && cd ..
```

In de cloud zijn de Core-tests al groen gedraaid op Linux (29 Core-tests, 21 in
de app-kopie), maar de SwiftUI-code in `SquashAnalyzerUI`, de Skip-transpilatie
en de Android-build zijn daar niet gecontroleerd. Verwachte risico's bij Skip:
`BadgeKind.families` (static computed property), `family.series`, de
`for … where`-lussen in `BadgeEngine`, `BadgeSeriesArtwork` in
`BadgeCatalog.swift` en de ternary `family.hasTiers ? size : size + 12.0`.
Schrijf het type voluit of splits de expressie als Kotlin klaagt. Verander de
ids (`rawValue`) van `BadgeKind` nooit: die staan op gedeelde kaarten.

## 3. Op simulator en emulator nakijken

Op de iPhone 17 Pro Max-simulator en de Android-emulator, met standaardtekst en
met 1,3× tekst:

1. Beginscherm → Badges: de catalogus toont per badge met treden drie
   medaillons naast elkaar (brons, zilver, goud) met de regel "Brons 4 · Zilver
   6 · Goud 8"; de zeven nieuwe badges staan erbij (Rock solid, Back wall boss,
   Sneltrein, Vette winst, Clubicoon, Rivalen, Hand-out held). Getallen op
   56 pt leesbaar? Drie treden duidelijk verschillend?
2. Coachwedstrijd met twee gekozen spelers; speel een game waarin speler 1
   acht drops wint. Na de wedstrijd: de strip "Badges verdiend" toont één
   gouden Drop it like it's hot (niet drie). Tik erop: "Drop it like it's hot ·
   Goud" met "8 drops in één game".
3. Spelers → speler 1 → badges: de tegel toont het gouden plaatje met
   "Goud · 1×"; tik: de momenten tonen "Goud · Tegen …", "Zilver · Tegen …" en
   "Brons · Tegen …" (drie momenten van één wedstrijd). Veeg één weg en terug.
4. Deel kaart: het plaatje toont per badge de hoogste trede en "x van 37
   badges". Open de link in de browser (`website/kaart/index.html` lokaal
   serveren, bijvoorbeeld `python3 -m http.server` in `website/`): dezelfde
   hoogste trede, "Goud · 1×", en in de lijst "Drop it like it's hot · Goud ·
   tegen …".
5. Scheidsrechterwedstrijd 11-3, 11-4, 11-5 met gekozen spelers: winnaar krijgt
   Vette winst en Clean sweep; met één game 11-6 niet.
6. Een bestaande back-up terugzetten (van build 17): oude badges blijven
   staan als brons, een oude Perfect ten verschijnt als gouden 5 points in a
   row, niets dubbel, geen crash in Spelers of op de kaart.
7. Android `connectedDebugAndroidTest` wist de app-data: zet daarna de
   testgegevens terug als je ze nog nodig hebt.

Maak van punt 1, 2 en 3 op beide platformen een screenshot in
`docs/screenshots-oktober/` (naam `ios-badges-…png` / `android-badges-…png`).

## 4. Oude assets opruimen (pas na stap 3)

De oude imagesets zonder tredeachtervoegsel worden nergens meer geladen:

```bash
cd Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/Resources/Module.xcassets
for id in five-in-a-row drop-it kriss-cross back-from-the-death ace-of-pace lob-story volleywood \
          drive-me-crazy boast-buster hat-trick centurion ten-out-of-ten front-row-king endurance \
          iron-man nemesis veteran perfect-ten; do git rm -r "badge-$id.imageset"; done
cd -
```

Laat `website/badges/<id>.png` van die achttien staan: oude kaartlinks en
zoekmachines verwijzen er nog naar (de kaartpagina gebruikt ze niet meer).
Controleer daarna `grep -rn '"badge-perfect-ten"\|badge-five-in-a-row"' Packages SquashAnalyzer`:
geen treffers. Bouw iOS en Android opnieuw en open de catalogus nog eens.

## 5. Versienummers

- iOS: `CURRENT_PROJECT_VERSION` 17 → 18 in `SquashAnalyzer.xcodeproj/project.pbxproj`
  (beide plekken), `MARKETING_VERSION` blijft 2.2.
- Android: `scripts/play_upload.py --bump` (versionCode 4 → 5) en in
  `Android/app/build.gradle.kts` `versionName = "0.5"`.

## 6. Releasenotes

Schrijf, in de stijl en structuur van `release-notes/2.2-17.md` en
`release-notes/android-0.4-4.md`:

- `release-notes/2.2-18.md` (TestFlight "What to Test", platte tekst, max
  4000 tekens, geen emoji).
- `release-notes/android-0.5-5.md` (Play, max 500 tekens).

Gebruik de concepten onderaan als basis en neem de punten over uit
`docs/wijzigingen-builds.md` (grote systeemtekst, scoreschermen 1,3×,
wedstrijdklok, Mijn team). Verwijder `release-notes/concept-volgende-build.md`
als die verouderd is.

## 7. Website

- `website/testen.html`: regel "iPhone 2.2 (build 18) · Android 0.5 (5) ·
  oktober 2026"; sectie "Nieuw in deze versie" vervangen door de badge-treden,
  de nieuwe badges, grote tekst en Mijn team (concept onderaan). De huidige
  "Nieuw"-punten (live meekijken, unforced error, START GAME, Deel score,
  startscherm) verhuizen naar "Uit eerdere versies, nog steeds welkom".
- `website/index.html`, sectie Nieuws: de lijst "Nieuw:" aanvullen met de
  badge-treden en de zeven nieuwe badges (bovenaan).
- `website/badges/index.html` en `website/kaart/index.html` zijn al
  bijgewerkt; de handleidingen noemen al 37 badges. Controleer de
  badgepagina in de browser: 37 kaarten, 17 met drie plaatjes.
- `Android/play/listing-nl-NL.json`: de regel over badges aanvullen met
  "in brons, zilver en goud"; daarna `scripts/play_listing.py --dry-run` en
  zonder `--dry-run`.
- `website/appstore-metadata.md`: dezelfde zin in de App Store-beschrijving,
  als die badges noemt.
- Publiceer de website zoals gebruikelijk (Portainer, stack 85) en open
  squashanalyzer.com/badges en /testen.

## 8. Bouwen en uploaden

iOS:

1. Xcode: Product → Archive → Distribute App → App Store Connect (zoals in
   `website/appstore-metadata.md`, stap 7).
2. `scripts/testflight_distribute.py --version 2.2 --build 18 --notes release-notes/2.2-18.md`
3. `scripts/testflight_expire_old.py`

Android:

```bash
cd Android && ./gradlew :app:bundleRelease && cd ..
scripts/play_upload.py --notes release-notes/android-0.5-5.md --name "0.5 (5)"
```

Controleer met `scripts/play_upload.py --check` dat 0.5 (5) op internal, alpha
en Google Group testers staat.

## 9. Afsluiten

- `docs/wijzigingen-builds.md`: het blok "Volgende build" wordt
  "## iOS 2.2 build 18 en Android 0.5 (5), <datum> (geüpload)" met de
  verwijzing naar de releasenotes; nieuw leeg blok "Volgende build" erboven.
- `docs/android-port.md`: korte paragraaf "Badges met treden" met de
  testresultaten (aantallen groen) en eventuele nieuwe Skip-eigenaardigheden.
- `docs/style/badge-artwork-overdracht-claude-code.md`: onder "Integratie"
  noteren dat de oude imagesets zijn verwijderd en op welke toestellen is
  getest.
- Commit per stap (tests/fixes, opruimen, versies en releasenotes, website,
  docs), push de branch en merge in `main`:

```bash
git checkout main && git merge --no-ff claude/great-pasteur-eyskxy && git push origin main
```

Meld aan het eind: testaantallen per suite, wat op de toestellen afweek, de
buildnummers die online staan en wat open blijft.

---

## Concept releasenotes iPhone (`release-notes/2.2-18.md`)

```
Squash Analyzer 2.2 (build 18) — "Brons, zilver en goud"

Hoi Squashteam! Deze build draait om badges: zeventien badges hebben nu drie treden, er zijn zeven nieuwe badges, en grote systeemtekst past weer overal. Alle uitleg staat ook op squashanalyzer.com/testen.

NIEUW
• Badges met treden: brons, zilver en goud. De rand van de badge laat de trede zien en het getal in de badge is de drempel. 5 points in a row 5/7/10 (goud is de oude Perfect ten), de slagbadges 4/6/8 per game, Front row king en Back from the dead 5/7/9, Endurance 60/90/120 s, Iron man 60/75/90 min, Hat trick 3/5/7, Nemesis 5/10/20, Ten out of ten 10/25/50, Centurion 100/500/1000, Veteran 25/50/100. Haal je goud, dan krijg je in die wedstrijd alle drie. Je oude badges blijven brons.
• Zeven nieuwe badges: Rock solid (wedstrijd zonder unforced error), Back wall boss (5 winners vanuit de achterste vakken in één game), Sneltrein (game in minder dan 6 minuten), Vette winst (tegenstander in geen game boven de 5), Clubicoon (10 verschillende tegenstanders), Rivalen (10 wedstrijden tegen dezelfde tegenstander) en Hand-out held (5 rally's op rij gewonnen op de service van de ander). In totaal 37 badges.
• Alle badges toont per badge de drie treden; het spelersscherm, de badgekaart en "Badges verdiend" tonen je hoogste trede.
• Mijn team: je eigen team valt op in de stand, met een Vernieuwen-knop onderaan.

OPGELOST
• Grote systeemtekst: titels, tegels en knoppen blijven op één regel; de scoreschermen op Android groeien mee tot 1,3×.
• De wedstrijdklok telt na hervatten de gesloten tijd niet meer mee.

PROBEER VOORAL
• Speel in coachmodus een game met 6 of 8 drops (of crosses, lobs, drives, boasts): zie je zilver of goud op de strip, bij de speler en op de gedeelde kaart?
• Open Spelers, medaille-icoon: staan je oude badges er nog, als brons? Een oude Perfect ten is nu de gouden 5 points in a row.
• Win een scheidsrechterwedstrijd met 11-5 of lager in elke game: krijgt de winnaar Vette winst?
• Zet de tekst groot (Tekstgrootte) en loop het beginscherm, Coach en Scheidsrechter door.

NOG STEEDS WELKOM OM TE TESTEN (EERDERE BUILDS)
• Live meekijken: tik op LIVE bij Coach of Scheidsrechter en deel de link.
• Unforced error met soort fout, START GAME bij de eerste service, Deel score als scorekaart, verslag of plaatje.
• Deel kaart: plaatje plus link van de badgekaart; ontvangen kaarten koppel je aan een speler.
• Baan in 6 of 9 vakken, de slag Kill en de schakelaar "Uit de lucht".
• Mijn team via je teamlink van sbn.toernooi.nl; wekelijkse back-up in iCloud Drive.

Iets kapot of raar? Stuur een screenshot via TestFlight (schud je telefoon) of app Gerd-Jan. Veel speelplezier!
```

## Concept releasenotes Android (`release-notes/android-0.5-5.md`, max 500 tekens)

```
Vijfde testversie. Nieuw: badges in brons, zilver en goud (zeventien badges met drie treden; je oude badges blijven brons), zeven nieuwe badges zoals Vette winst, Sneltrein en Clubicoon, en je eigen team valt op in de stand van Mijn team. Opgelost: grote systeemtekst past weer overal, de wedstrijdklok telt na hervatten de gesloten tijd niet meer mee. Alles wat je kunt testen: squashanalyzer.com/testen
```

## Concept website `testen.html`, "Nieuw in deze versie"

```
Badges in brons, zilver en goud
Zeventien badges hebben nu drie treden. De rand laat de trede zien en het getal in de badge is de drempel, bijvoorbeeld 4, 6 en 8 drops in één game, of 5, 7 en 10 punten op rij (goud is de oude Perfect ten). Haal je goud, dan krijg je in die wedstrijd alle drie de treden. Badges die je al had, blijven brons. Open Spelers, medaille-icoon of de pagina Badges voor alle drempels.

Zeven nieuwe badges
Rock solid (wedstrijd zonder unforced error), Back wall boss (5 winners vanuit de achterste vakken), Sneltrein (game in minder dan 6 minuten), Vette winst (tegenstander in geen game boven de 5), Clubicoon (10 verschillende tegenstanders), Rivalen (10 wedstrijden tegen dezelfde tegenstander) en Hand-out held (5 rally's op rij gewonnen op de service van de ander). Samen 37 badges.

Hoogste trede in beeld
Het spelersscherm, de badgekaart die je deelt en "Badges verdiend" na de wedstrijd tonen per badge je hoogste trede; bij de momenten zie je welke trede je wanneer haalde.

Grote tekst en Mijn team
Titels, tegels en knoppen blijven bij grote systeemtekst op één regel; de scoreschermen op Android groeien mee tot 1,3×. In Mijn team valt je eigen team op in de stand en haal je de stand op met Vernieuwen. De wedstrijdklok telt na hervatten de gesloten tijd niet meer mee.

Probeer vooral
- Speel in coachmodus een game met 6 of 8 drops: zie je zilver of goud op de strip, bij de speler en op de gedeelde kaart?
- Staan je oude badges er nog, als brons? Een oude Perfect ten is nu de gouden 5 points in a row.
- Win een scheidsrechterwedstrijd met 11-5 of lager in elke game: krijgt de winnaar Vette winst?
- Zet de tekst groot en loop beginscherm, Coach en Scheidsrechter door.
```

## Concept website `index.html`, sectie Nieuws (bovenaan de lijst "Nieuw:")

```
<li>Badges in brons, zilver en goud: zeventien badges met drie treden, en zeven nieuwe badges</li>
```

## Concept Play-listing en App Store-beschrijving

Vervang de regel over badges door:

```
• Spelers verdienen 37 badges, zoals 5 punten op rij of een game met 11-0; zeventien ervan in brons, zilver en goud
```
