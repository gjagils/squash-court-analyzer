# Squash Analyzer

iOS-app voor squashcoaching, scheidsrechtermodus, spelers, badges en teamstanden.
De Android-port gebruikt gedeelde Swift/SwiftUI via Skip en Room voor opslag.

Android heeft spelersbeheer, zowel coachscoring als scheidsrechtermodus
(punten, LET, STROKE, undo, game-wissel, "Kies speler" bij het starten) met
automatische opslag en hervatten, en een badges-catalogus. Echte badge-awards
en het overzicht van opgeslagen wedstrijden volgen nog.

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
