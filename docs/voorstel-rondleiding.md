# Voorstel: rondleiding voor nieuwe gebruikers

Stand: 10 oktober 2026, voorstel, nog niet gebouwd. Aanleiding: testersrapport
van Testers Community (punt 4, "Lack of User Onboarding Walkthrough"). Besluit
Gerd-Jan: een rondleiding maken, die ook vanuit Instellingen opnieuw te starten is.

## Vorm

Een rondleiding van **zes schermen** die je doorveegt (of met *Volgende*),
schermvullend, bij de eerste start van de app. Op elk scherm staan een groot
pictogram of een kleine schermafbeelding, een titel, twee of drie regels tekst
en onderaan stipjes voor de voortgang. Rechtsboven staat altijd **Overslaan**,
op het laatste scherm **Aan de slag**.

Bewust géén rondleiding die over de echte schermen heen wijst ("tik hier"). Die
breekt bij elke schermwijziging, werkt op iPhone en Android verschillend en is
met Skip lastig te bouwen. Losse schermen zijn één gedeeld onderdeel voor
beide platforms en goed bij te houden.

## De zes schermen

1. **Welkom bij Squash Analyzer.** "Jouw spel scherp in beeld." Twee manieren
   om een wedstrijd bij te houden: als **coach** of als **scheidsrechter**.
2. **Coach.** Per punt leg je vast wie scoorde, hoe (winner, druk, fout of
   servicepunt), waar op de baan en met welke slag. Na elke game zie je de
   analyse en krijg je advies.
3. **Scheidsrechter.** Tik op de score van wie de rally wint. LET, STROKE,
   undo en de servicekant zitten erbij; de app houdt games en tijd bij.
4. **Kies speler: badges en profiel.** Sla spelers op en kies ze bij het
   starten via *Kies speler*. Alleen dan verdienen ze badges en groeit hun
   profiel over de wedstrijden. *(Dit wordt nu het vaakst gemist; daarom een
   eigen scherm.)*
5. **Competitie.** Speel je bij SBN? Vul je teamlink in, dan zie je je
   programma en de stand, en kun je een teamwedstrijd live delen met je team.
   Knop: *Teamlink invullen* (opent Instellingen), naast *Volgende*.
6. **Live meekijken en je gegevens.** Met LIVE deel je de stand met een link.
   Alles staat op je eigen telefoon; maak af en toe een back-up (Instellingen).
   Knoppen: *Aan de slag*, en een link naar de handleiding.

## Wanneer verschijnt hij

- **Nieuwe installatie:** bij de eerste start, vóór het beginscherm.
- **Bestaande gebruikers** (update van een eerdere versie): niet vanzelf. Te
  herkennen aan opgeslagen wedstrijden of spelers. Zie open vraag 1.
- **Opnieuw bekijken:** in Instellingen, onder *Handleiding*, een knop
  **Rondleiding opnieuw bekijken**.
- Een opgeslagen versienummer (`onboardingVersion`). Bij een grote
  vernieuwing zetten we dat nummer omhoog, zodat iedereen de rondleiding nog
  één keer ziet.

## Bouw

- Eén gedeeld scherm `SharedOnboardingView` in SquashAnalyzerUI, voor iOS en
  Android. Zelf gebouwde schermwisseling (vegen en knoppen), geen `TabView`
  in paginastijl: hoe Skip die omzet is onzeker.
- De regel "wanneer tonen" in Core (`Onboarding.shouldShow(...)`), met tests.
- Kleuren alleen uit `SharedColors`, zodat de rondleiding meteen goed is in de
  lichte modus die eraan komt.
- iOS heeft een eigen beginscherm en eigen Instellingen (`HomeView`,
  `SettingsView`); Android gebruikt de gedeelde (`HomeMenu`,
  `SharedSettingsView`). De knop en de eerste start komen in beide.
- Gecontroleerd bij standaard en 1,3× tekstgrootte, met VoiceOver en TalkBack
  (titel en tekst per scherm voorgelezen, *Overslaan* altijd bereikbaar).
- Handleiding: een regel over *Rondleiding opnieuw bekijken*.
- Inschatting: ongeveer een dag, plus de tekstronde met jou.

## Open vragen voor Gerd-Jan

1. Bestaande testers: de rondleiding één keer laten zien na deze update, of
   alleen bij nieuwe installaties?
2. Beeld per scherm: grote pictogrammen in de huisstijl (licht, werkt in
   beide thema's) of kleine schermafbeeldingen van de app (concreter, maar
   bij elke schermwijziging bijwerken)?
3. Scherm 5 (Competitie) voor iedereen tonen, of eerst vragen "Speel je
   competitie bij SBN?" en het anders overslaan?
4. Mogen de teksten hierboven zo blijven, of wil je ze zelf aanscherpen?
