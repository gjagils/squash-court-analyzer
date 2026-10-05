# Buildplanning testperiode (vanaf 5 oktober 2026)

De externe test is op 5 oktober gestart met iOS 2.2 (18) en Android 0.5 (5).
Tijdens de testperiode komen er drie tot vier externe builds, elk met
bugfixes en kleine verbeteringen uit de testfeedback en **hooguit één
feature**. Grote onderwerpen (competitiekoppeling, trainingsmodus,
clubranglijst) wachten tot na de testperiode.

Aanname: de testperiode duurt ongeveer vier weken, met een build per week of
per tien dagen. Schuift de periode, dan schuiven de builds mee; de volgorde
van de features blijft.

## Spelregels per build

- **Eén feature, klein genoeg voor één week:** vooral Core-logica met tests
  en één gedeeld scherm of kaart, zodat iPhone en Android gelijk blijven.
- **Bugfixes eerst.** Een gemelde fout die gegevens raakt (back-up, badges,
  opslaan, hervatten) gaat altijd mee, ook als de feature daardoor een build
  opschuift.
- **Geen schema- of formaatwijzigingen** zonder noodzaak: geen nieuwe
  SwiftData-versie, geen Room-migratie, geen wijziging van het back-upformaat
  of de kaartlink. Testers moeten tussen builds hun gegevens houden.
- **Badge-ids blijven zoals ze zijn**; nieuwe badges alleen als eigen feature.
- **Feature-freeze twee dagen voor de upload:** daarna alleen fixes, testen
  op de simulator, de emulator en beide toestellen (standaard en 1,3× tekst).
- **Elke build:** `scripts/lint.sh`, Core- en UI-tests via `swift test` en
  `skip test`, `xcodebuild test`, Android-unittests; releasenotes
  (`release-notes/2.2-<build>.md`, `release-notes/android-0.<n>-<n>.md`);
  `website/testen.html` ("Nieuw in deze versie" en de versieregel); upload
  met `scripts/testflight_distribute.py` en `scripts/play_upload.py`. De
  stappen staan uitgewerkt in `docs/badges-afronden-instructie.md`
  (stap 5 tot en met 9).
- **Versienummers:** iOS blijft 2.2 met oplopend buildnummer; Android
  `versionCode` en `versionName` lopen samen op (0.6 (6), 0.7 (7), …).

## Feedback verzamelen en verdelen

Meldingen van testers (TestFlight-screenshots, Play, WhatsApp, mail) komen in
`docs/wijzigingen-builds.md` onder "Volgende build" met één regel per melding:
wat, wie, platform, en de keuze **nu** (deze build), **volgende** of **later**.
Vuistregel: een fout die iemand in een echte wedstrijd hindert is "nu"; een
wens die één scherm raakt is "volgende"; alles wat een nieuw onderdeel vraagt
is "later" en gaat naar de backlog.

## De builds

### Build 19 · iOS 2.2 (19), Android 0.6 (6) · rond 12 oktober

- **Feature: voortgang naar de volgende trede.** Op de badgetegel en bij de
  momenten staat hoe ver de speler is: "Goud · 1×, zilver was 6, goud bij 8"
  wordt "nog 2 drops tot goud" op basis van de beste game of wedstrijd tot nu
  toe; bij carrièrebadges "nog 3 wedstrijden tot Veteran zilver". De
  drempels staan al op `BadgeKind.threshold`; de beste waarde per badge komt
  uit dezelfde geschiedenis als de carrièrebadges plus de opgeslagen
  wedstrijden. Puur Core (`BadgeProgress`, met tests) en één regel tekst in
  `SharedPlayerBadgesView` en de momentenlijst.
- **Bugfixes en klein:** alles wat de eerste week over de treden en de
  nieuwe badges binnenkomt (verkeerde trede, dubbele momenten, kaart in de
  browser, leesbaarheid van de getallen op kleine telefoons), plus de
  bekende kleine punten uit de handleiding-controle.
- **Website:** testen.html; badgepagina alleen als er iets aan de teksten
  verandert.

### Build 20 · iOS 2.2 (20), Android 0.7 (7) · rond 19 oktober

- **Feature: onderlinge stand bij "Kies speler".** Zodra beide spelers
  gekozen zijn, een kaartje in de huisstijl: hoe vaak tegen elkaar gespeeld,
  wie won, de laatste uitslag in games, en welke badge een van beiden in deze
  wedstrijd kan halen (Nemesis-trede of Rivalen). Gegevens uit de bestaande
  carrièregeschiedenis (`BadgeAwarder.history` op iOS,
  `BadgeAwardStore.careerHistory` op Android), berekening in Core
  (`HeadToHead`, met tests), één gedeeld kaartje in het kies-speler-scherm
  van coach en scheidsrechter.
- **Bugfixes en klein:** feedback van week 2, met voorrang voor alles rond
  hervatten, opslaan en live meekijken, omdat testers dan echte
  competitiewedstrijden spelen.

### Build 21 · iOS 2.2 (21), Android 0.8 (8) · rond 26 oktober

- **Feature: spelersprofiel met trend, eerste helft.** Het scherm "Profiel"
  uit de backlog met drie kaarten: Vorm (laatste 10 uitslagen), Winners
  tegenover unforced errors per game als trend, en Tegenstanders. De
  Core-berekening (`PlayerTrend`) wordt meteen compleet gebouwd en getest;
  de kaarten Slagen, Baan en Tempo volgen in build 22.
- **Bugfixes en klein:** feedback van week 3; tekstcorrecties in de
  handleiding en releasenotes van eerdere builds meenemen.

### Build 22 (optioneel) · iOS 2.2 (22), Android 0.9 (9) · rond 2 november

Alleen als de testperiode nog loopt en er genoeg feedback is om te
verwerken. De feature is één van deze twee, te kiezen op basis van wat
testers vragen:

- **Spelersprofiel, tweede helft:** Slagen, Baan en Tempo, plus de
  periode-keuze (10, 25, alles).
- **Partijen achteraf invullen** als eerste stap van de competitiekoppeling:
  bij een wedstrijd van Mijn team de vier partijen met game-standen invullen
  zonder ze bij te houden. Alleen als de competitiekoppeling in de
  testperiode al is verkend en het datamodel vaststaat; anders schuift dit
  naar de periode erna.

Daarna volgt de release in de App Store en de Play Store op basis van de
laatste testbuild, met de verzamelde fixes en zonder nieuwe feature.

## Wat niet in deze builds komt

- Competitiekoppeling als geheel (teamwedstrijd met vier partijen, live per
  teamwedstrijd, vergelijken met de SBN-uitslag).
- Badgecategorie voor competitiewedstrijden (Teamspeler).
- Clubranglijst uit gedeelde kaarten en de trainingsmodus.
- Nieuwe badges of ander badge-artwork.
