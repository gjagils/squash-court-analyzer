# Buildplanning testperiode — bijgewerkt 6 oktober 2026

De externe test is op 5 oktober gestart met **iOS 2.2 (18)** en
**Android 0.5 (5)**. De voorgenomen planning bevat twee testupdates, rond
10 en 15 oktober. Dit zijn richtdata, geen uploadopdrachten.

## Build 19 — iOS 2.2 (19), Android 0.6 (6)

**Competitie en live teamwedstrijden** zijn de gekozen feature en zijn op main
gebouwd: vier partijen, handmatig invullen of koppelen aan bijgehouden
wedstrijden, teamstand en verslag, plus live volgen en samenwerken via een
teamlink. Teamdata reist mee in back-upformaat 4 wanneer die aanwezig is.
Dit is een bewuste aanvulling op het eerdere streven formaten ongemoeid te laten.

Simulator- en emulatortests staan als geslaagd gedocumenteerd. Praktijktesten
van live teamwedstrijden op iPhone en A13 staan nog open. De app-build is nog
niet geüpload. Zie [Competitie](competitie-vervolg.md),
[live teamwedstrijden](plan-live-teamwedstrijd.md) en
[opleveren en hosting](opleveren-en-hosting.md).

## Volgende testupdate — beoogd build 20 / Android 0.7 (7)

Badgevoortgang schuift volgens de keuze van 5 oktober één build door en is
de volgende geplande feature. Bugfixes uit testfeedback gaan voor; definitieve
inhoud en uploadmoment volgen uit de releasebacklog en een uploadopdracht.

Onderlinge stand bij Kies speler en een spelersprofiel met trends blijven
backlog. De oude toewijzingen aan builds 20–22 zijn achterhaald; hiervoor zijn
nog geen vervangende releasedatums vastgelegd. SquashLevels-profielen per
opgeslagen speler zijn eveneens backlog, zonder toegewezen build.

## Productieaanvraag Android

De interne wens van een testperiode van twaalf dagen is **geen bewijs dat
Google Play productie al toestaat**. Voor nieuwe persoonlijke accounts waarop
de regel van toepassing is, vereist Google minimaal 12 testers die 14 dagen
aaneengesloten zijn aangemeld. Controleer de feitelijke voortgang en verdere
vragen in de Play Console vóór de productieaanvraag. Zie
[de officiële Google Play-uitleg](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB).
Er is geen gegarandeerde productiedatum of automatische App Store-indiening.

## Werkwijze

- Bugfixes voor opslaan, herstellen, hervatten en echte wedstrijdsituaties gaan voor.
- Zet feedback en besluiten in [wijzigingen per build](wijzigingen-builds.md).
- Houd schema's en badge-ids compatibel; formatwijzigingen vereisen gerichte hersteltests.
- Voer vóór een upload de controles uit [opleveren en hosting](opleveren-en-hosting.md) uit.
  Dat document bevat de actuele commando's; het UI-package heeft geen los Swift-testtarget.
- Werk releasenotes, handleidingen en de testpagina bij voor de daadwerkelijk
  aangeboden versie. Vooruitblikken moeten herkenbaar blijven.
- TestFlight/Play-upload en versieverhoging gebeuren alleen op expliciete opdracht.

## Later

SBN-uitslagen vergelijken, Teamspeler-badges, onderlinge stand, spelersprofielen,
SquashLevels-links, trainingsmodus en clubranglijst staan op de backlog.
Partijen achteraf invullen en live teamwedstrijden zijn al gebouwd en horen
niet meer in die lijst.
