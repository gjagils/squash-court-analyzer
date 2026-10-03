# Squash Analyzer

iOS-app voor squashcoaching, scheidsrechtermodus, spelers, badges en teamstanden.
De Android-port gebruikt gedeelde Swift/SwiftUI via Skip en Room voor opslag.

Android heeft spelersbeheer, zowel coachscoring als scheidsrechtermodus
(punten, LET, STROKE, undo, game-wissel, "Kies speler" bij het starten) met
automatische opslag en hervatten, een badges-catalogus met echte, per speler
berekende en bewaarde badge-awards inclusief career-badges (badge-aantal in
Spelers met een scherm voor de verdiende badges en een knop "Deel kaart" die
dezelfde kaartlink maakt als iOS; zo'n link openen op Android importeert de
kaart, plus een "Badges verdiend"-strip direct op het match-einde-scherm), een overzicht van
afgeronde coach- en scheidsrechterwedstrijden, en Mijn team (stand, wedstrijden
en spelers van sbn.toernooi.nl; de teamlink vul je in bij Instellingen), en
een game-analyse na elke coachgame met tactisch advies en AI Coach (eigen
OpenAI-key in Instellingen), "Deel score" en back-ups (met de hand of automatisch eens per week naar een
gekozen map) die ook op een iPhone terug te zetten zijn (en andersom).

Coachen gaat met een baan van 6 vakken (of 9, in te stellen bij Instellingen →
Baanindeling). Per vak kies je alleen de slagen die daar passen, met een
schakelaar "Uit de lucht" voor volleys; nieuw is de slag Kill.

- [Visuele stijl en stijlkaart](docs/style/README.md)
- [Architectuur](ARCHITECTURE.md)
- [Android-status, bouwinstructies en resterende stappen](docs/android-port.md)
- [Google Play: Android-app ondertekenen, uploaden en testen](docs/google-play.md)
- [Teamimport: formaat, import via link en een team online zetten](docs/team-import/README.md)

Lokaal Android bouwen (Xcode/Swift, Skip en Android Studio SDK zijn nodig):

```bash
cd Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug :app:testDebugUnitTest
# Met een emulator of verbonden Android-toestel:
./gradlew :app:connectedDebugAndroidTest
```

Tijdens de Android-port worden iOS-builds lokaal getest. TestFlight-publicatie
wordt pas hervat na een expliciet afgesproken mijlpaal.
