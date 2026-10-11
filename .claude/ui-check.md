# UI check — SquashAnalyzer

Config for the `ui-check` skill (`~/.claude/skills/ui-check`). Screens and
rules for the iOS app (SwiftUI) and the Android app (the same Swift through
Skip). Run from a worktree, not the main checkout.

## Build

- iOS: `xcodebuild build -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipPackagePluginValidation -derivedDataPath build/DerivedData-uicheck`
  → `build/DerivedData-uicheck/Build/Products/Debug-iphonesimulator/SquashAnalyzer.app`
- Android: `cd Android && export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ANDROID_HOME=$HOME/Library/Android/sdk && ./gradlew assembleDebug -q`
  → `Android/app/build/outputs/apk/debug/app-debug.apk`
- A Kotlin error in generated code after Swift edits can be a half-updated Skip
  output: `rm -rf Packages/SquashAnalyzerUI/.build/plugins/outputs/squashanalyzerui Packages/SquashAnalyzerUI/.build/gradle-skip-stamp` and build again (docs/skip-valkuilen.md).

## Devices

- iOS simulator: `iPhone 17 Pro Max`, bundle id `com.squashanalyzer.app`
- Android emulator: serial `emulator-5554`, package `com.squashanalyzer.android`
- **Never** use Gerd-Jan's Samsung A13 (`RF8W10L1P6N`) or his iPhone for this check,
  and never run `connectedDebugAndroidTest` with the A13 attached.

## Appearance

The app has its own setting (Instellingen → Weergave: Systeem / Licht / Donker,
default Donker), independent of the system.

- iOS: **terminate the app first** (`xcrun simctl terminate <udid> com.squashanalyzer.app`, wait 1 s):
  a running app writes its settings back on exit and undoes the change. Then
  `xcrun simctl spawn <udid> defaults write com.squashanalyzer.app appearance light` (or `dark`)
  and `defaults write … onboardingVersion -int 1` to skip the tour (`0` to show it).
- iOS scenario data mixes with what is already on the simulator (for example "Wedstrijd
  hervatten?" on setup): uninstall and install the app for a clean run.
- Android: open Instellingen (gear, content description "Instellingen") and tap
  "Licht" or "Donker" under Weergave, then back. A fresh install shows the tour
  first: tap "Overslaan".
- Large text: only Android (`android-textsize large`, font scale 1.3; put it back to
  normal afterwards). iOS uses fixed font sizes on purpose (`SharedFonts`), so a large-text
  pass there shows nothing new.
- Android has no scenarios and a fresh emulator has no matches: play a game via taps
  (Coach → names → START WEDSTRIJD → START GAME 1 → tap a score → SERVICEPUNT, 11 times).
  An unfinished match is not in Afgeronde wedstrijden; reach it again via Coach → Hervatten.

## Route

iOS uses the debug screenshot scenarios (launch argument `-screenshot <name>`,
sample data, see `SquashAnalyzer/Services/ScreenshotScenario.swift`). Android has
no scenarios: navigate by text from the home screen (`android-tap-text`), using
whatever data the emulator has.

| # | Screen | iOS | Android | Large text |
|---|---|---|---|---|
| 01 | Home | `-screenshot home` | launch | yes |
| 02 | Coach setup | `-screenshot setup` | tap "Coach" (then back) | yes |
| 03 | Coach scoring | `-screenshot coach-match` | — | no |
| 04 | Court / zone | `-screenshot coach-zone` | — | no |
| 05 | Game over | `-screenshot coach-gameover` | — | yes |
| 06 | Referee | `-screenshot referee` | tap "Scheidsrechter" | no |
| 07 | History | `-screenshot history` | tap "Afgeronde wedstrijden" | yes |
| 08 | Analyse (coach dashboard) | `-screenshot dashboard` | in History, tap a coach match | yes |
| 09 | Badges | `-screenshot badges` | tap "Badges" | no |
| 10 | Settings | from home: gear (tap with the simulator tool) | gear "Instellingen", swipe up for the rest | yes |
| 11 | Players | from home: "Spelers" | tap "Spelers" | no |
| 12 | Competitie | from home: "Competitie" | tap "Competitie" | no |
| 13 | Coach card | dashboard → "COACHKAART" | dashboard → "COACHKAART" | yes |
| 14 | Tour | `onboardingVersion -int 0`, launch | Instellingen → "Rondleiding opnieuw bekijken" | no |

On iOS, screens without a scenario need taps: use the iOS Simulator control tool
(`mcp__Claude_Code_iOS_Simulator__control`, points = pixels / 3 on this device).

## Palette and rules

Source: `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/SharedColors.swift`,
`docs/style/README.md`, `docs/style/tokens.json`.

- Dark: background #000000, text #F2EDE6 / #B3ADA6 / #807A73, accent (player 1)
  #F28C26, gold #E6B859, player 2 #59738C.
- Light ("warm licht"): background #F7F3ED, cards #FFFFFF, text #26211C / #71665B /
  #786C60, accent (player 1) #A94F08, gold #8A6412, player 2 #405A73, border #DEC9B4.
- Buttons are the app's own `ActionButton` (outlined, tinted, or filled); no system
  buttons. A disabled button is a quiet outlined one, never light text on grey.
- In light mode the serving player is shown in the full player colour, the other faded.
- Cards: radius 12–16, no shadow.

## Accepted differences (do not report)

- Segmented pickers look native on each platform (iOS grey pill, Android outlined chips).
- The app icon is always dark; the shared result picture is always dark.
- Screenshot scenarios use synthetic data: odd numbers there (for example service
  and return 12 of 12) are not bugs.
- Android top bars use Material styling with the app's colours.
