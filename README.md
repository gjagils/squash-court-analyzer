# Squash Analyzer

iOS-app voor squashcoaching, scheidsrechtermodus, spelers, badges en teamstanden.
De Android-port gebruikt gedeelde Swift/SwiftUI via Skip en Room voor opslag.

Android heeft spelersbeheer, zowel coachscoring als scheidsrechtermodus
(punten, LET, STROKE, undo, game-wissel, "Kies speler" bij het starten) met
automatische opslag en hervatten, een badges-catalogus met echte, per speler
berekende en bewaarde badge-awards inclusief career-badges (badge-aantal in
Spelers met een scherm voor de verdiende badges en een knop "Deel kaart" die
dezelfde kaartlink maakt als iOS; zo'n link openen op Android importeert de
kaart, plus een "Badges verdiend"-strip direct op het match-einde-scherm), en een overzicht van
afgeronde coach- en scheidsrechterwedstrijden.

- [Architectuur](ARCHITECTURE.md)
- [Android-status, bouwinstructies en resterende stappen](docs/android-port.md)
- [Teamimport-formaat](docs/team-import/README.md)

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
