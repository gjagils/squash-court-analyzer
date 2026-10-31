# Releaseplan: kleine 3.x-releases naast 4.0

Stand: 31 oktober 2026. Gerd-Jan wil:

- 3.1 en 3.2 als kleine releases, met bugfixes en kleine wijzigingen;
- de grote features (spelersaccount, centrale badges en wat daarbij hoort)
  als 4.0.

Hieronder staat hoe dat aan te pakken is zonder dat de twee elkaar in de weg
zitten.

## Advies: alles op `main`, 4.0 achter een schakelaar

Er zijn twee manieren.

| | **Lange 4.0-branch** | **Op `main` achter een schakelaar** (advies) |
|---|---|---|
| Hoe | 4.0 wordt op een eigen branch gebouwd, `main` blijft 3.x. Pas bij de release wordt alles samengevoegd | Alles gaat in kleine stukjes naar `main`, zoals nu. Nieuwe 4.0-onderdelen staan uit in een 3.x-build |
| Samenvoegen | Wordt steeds pijnlijker. 4.0 raakt dezelfde bestanden als bijna elke 3.x-fix (Instellingen, beginscherm, Spelers, badges), en via Skip ook de Android-kant | Er valt niets samen te voegen |
| Bugfixes | Moeten op twee plekken | Eén keer |
| Testen | Twee codebases om groen te houden | De suites testen alles, ook 4.0 met de schakelaar aan |
| Past bij de werkafspraken | Nee, die zeggen: klein committen, direct naar `main` | Ja |

### De schakelaar

- **In de app:** in Core komt een vlag `Features.playerAccount`.
  - In een 3.x-build staat hij vast uit. Dan zie je geen menu-item, geen
    scherm en geen netwerkverkeer naar de account-API.
  - Voor 4.0-testbuilds staat hij aan, via een buildinstelling: een
    Xcode-configuratie en een Gradle-`buildConfigField`. Dat werkt hetzelfde
    als hoe de Firebase-waarden nu al in de Android-build komen.
  - Daarnaast een verborgen ontwikkelaarsschakelaar, zodat je 4.0 op je eigen
    iPhone kunt aanzetten zonder aparte build.
- **Op de server:** de account-Worker (zie het [voorstel](voorstel-spelersaccount-4.0.md))
  is nieuw en los. Hij kan gewoon live staan terwijl geen enkele app hem
  gebruikt.
- **Database-wijzigingen** in D1 gaan via genummerde migraties. Een 3.x-app
  merkt daar niets van.

Ook het clubscherm kan zo: eerst als proef met een geheime link. Daarvoor is
geen app-update nodig.

## Versies en builds

- **3.1** = wat nu in de test zit (build 2). Daar alleen nog bugfixes bij,
  dan naar productie.
- **3.2** = de volgende kleine release. Kandidaten (allemaal S of M, geen
  account nodig):
  - programma in je agenda (.ics, T1);
  - SquashLevels-link bij een speler;
  - voortgang naar de volgende badgetrede;
  - onderlinge stand bij Kies speler;
  - vorige uitslag tegen de tegenstander (T5);
  - eventueel de officiële timers voor de scheidsrechter (R2).
- **3.3 enzovoort** zolang 4.0 nog niet klaar is.
- **4.0** = spelersaccount en centrale badges, eventueel met het
  clubabonnement.

Twee versielijnen tegelijk testen kan in beide stores:

- **TestFlight** kent per versie een eigen reeks builds. 3.2 build 1 en
  4.0 build 1 kunnen naast elkaar staan, elk voor een eigen groep testers.
  Bijvoorbeeld Squashteam voor 3.x en een kleinere groep "4.0-proef".
- **Google Play** kijkt alleen naar de versionCode. Wie op twee tracks zit,
  krijgt de build met de hoogste code. 4.0 (versionCode 4.000.100 en hoger)
  is altijd hoger dan elke 3.x.
  - Zet de 4.0-testers op een **eigen gesloten track**.
  - Laat de 3.x-testers op intern, alpha en de Google Group zoals nu.
  - Testers die op beide tracks zitten, krijgen 4.0. Dat is precies wat je
    wilt voor de proefgroep.

`scripts/version.py` kan dit al aan: het schema rekent met major en minor.
Wel nodig: de 4.0-builds krijgen de schakelaar aan. Dat kan als extra vlag
bij `--xcode`/`--gradle`, of via een eigen buildconfiguratie. Het distributie-
en uploadscript moeten dan de juiste groep of track kiezen.

## Werkwijze per week (voorstel)

1. **Bugfixes en kleine wensen** gaan direct naar `main`, zoals nu. Ze komen
   in de volgende 3.x-build.
2. **4.0-werk** gaat in kleine stukken achter de schakelaar naar `main`, elk
   stuk met tests. Eerst de server, dan de app.
3. **Een 3.x-release** komt van `main` met de schakelaar uit. Voor de release
   controleren dat er niets van 4.0 zichtbaar is. Daar komt een test voor
   die de app met de schakelaar uit doorloopt.
4. **Een 4.0-proefbuild** komt van dezelfde `main` met de schakelaar aan, en
   gaat naar de 4.0-proefgroep.
5. **4.0 klaar:** de schakelaar wordt standaard aan en de oude-situatiecode
   gaat weg. De release-notes, de website en de handleiding krijgen een
   4.0-sectie.

`docs/wijzigingen-builds.md` krijgt twee kopjes per build: "3.x" en
"4.0 (achter de schakelaar)". Zo blijft zichtbaar wat in welke release
zit.

## Eerste stappen als je hiervoor kiest

1. 3.1 afronden en naar productie. Het privacylabel moet daarvoor nog worden
   aangepast, zie [wijzigingen per build](wijzigingen-builds.md).
2. Besluiten over de open keuzes in het
   [voorstel spelersaccount](voorstel-spelersaccount-4.0.md).
3. De schakelaar bouwen. Dat is klein en kan al in 3.2, uitgeschakeld.
4. De 3.2-lijst kiezen uit de kandidaten hierboven.
