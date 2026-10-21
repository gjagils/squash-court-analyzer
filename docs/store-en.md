# Engelse storeteksten — Squash Analyzer 3.0

Engelse teksten voor de App Store en Google Play bij versie 3.0 (release vrijdag 23
oktober 2026), opgesteld op 21 oktober 2026. Dit bestand wijzigt de vermeldingen niet:
Gerd-Jan zet de teksten zelf in App Store Connect (taal *English (U.S.)* of *English
(U.K.)* toevoegen) en in de Play Console (vertaling *en-US* of *en-GB* toevoegen).

**Bronnen:** `website/appstore-metadata.md` (App Store, stand iOS 2.2), `docs/google-play.md`
(B4, Play-vermelding), `release-notes/3.0-*.md` en `release-notes/android-3.0-*.md`, het
scherm "Nieuw in 3.0" (`WhatsNew` in `Onboarding.swift`) en de releasehomepage
`website/beta/index.html`. De Nederlandse App Store- en Play-teksten beschrijven nog niet
alles van 3.0 (Competitie, vergrendelscherm, Coachkaart, lichte weergave); die heb ik uit
de releasenotes en de homepage aangevuld, zodat de Engelse tekst bij 3.0 past.

**Woordenlijst** gelijk aan de app: team match, match (E1–E4), League, Referee, Coach,
Finished matches, Players, My team, Follow a match, Live sharing, Settings, Tour, Appearance,
zone, Backup, Pioneer.

Tekens geteld met Python `len()` (Unicode-tekens, zoals Apple en Google tellen); de
zoekwoorden van Apple zijn in bytes beperkt en bevatten alleen ASCII, dus gelijk.
Laat een native speaker de teksten nalezen.

---

## App Store (App Store Connect)

### Name — max. 30

```text
Squash Analyzer
```

*15 / 30 tekens*

### Subtitle — max. 30

```text
Squash Referee & Coach App
```

*26 / 30 tekens*

### Promotional text — max. 170

```text
New in 3.0: score a whole team match in League, share it live, follow the score on your lock screen and show your player the Coach card between games. Now on Android too.
```

*170 / 170 tekens*

### Description — max. 4000

```text
Squash Analyzer helps you keep track of squash matches as a coach or referee. Record the score, spot patterns and share the result. Free, no ads and no account.

REFEREE
• Keep the score, lets and strokes, with Undo and a rally-by-rally score line.
• The server and service box are tracked for you; set the preferred box per player.
• Join a match later or complete a result that was not tracked yet.
• Share the score live with a link, and follow your own match on your lock screen.

COACH
• Record winners, forced errors, unforced errors, strokes and service points.
• Choose a court with 6 or 9 zones and the shots that fit the chosen row: Drop, Boast, Kill, Drive, Cross or Lob. Mark a volley with the Volley switch.
• After each game, see the Analysis per player, zone and shot, with tactical advice.
• Show your player the Coach card between games: three coaching points and what changed since the last game.
• Ask for extra AI advice with your own OpenAI API key. The app sends match statistics without player names and picks an available model from a list of preferences. API use may incur costs at OpenAI.

LEAGUE
• Keep track of a whole team match, from E1 to E4, with the winner and bonus points under the Dutch squash federation (SBN) rules.
• Link a match you scored as coach or referee, or enter the game scores.
• Share the team match live: teammates add their own match and supporters follow the whole evening.

LIVE SHARING AND LOCK SCREEN
• Let others follow a match live through a browser link, with player photos if you like.
• Follow a match or team match on your lock screen, even with the app closed, with a notification for every game and the result.
• Live data is stored in the EU only and deleted 2 hours after the last score update.

PLAYERS AND BADGES
• Save players with a photo and coaching notes and pick them for a new match.
• Import a team through a zip file or a team link.
• Earn badges with saved players: 37 badges, seventeen of them in bronze, silver and gold. See when they were earned and share a player card.
• See the standings and matches of your SBN team in My team.

SHARE AND KEEP
• Share a Scorecard, Report or Image.
• Save matches, resume them and look back at finished matches.
• Make a backup to iCloud Drive by hand or automatically every week. Backups can be exchanged with the Android version.
• Choose a light or dark appearance, or let your phone decide.

The app follows your phone's language: English, or Dutch when your phone is set to Dutch.
```

*2503 / 4000 tekens*

### Keywords — max. 100 (komma's zonder spaties)

```text
squash,referee,coach,scoring,score,analysis,tactics,training,league,match,badges,live,scoreboard
```

*96 / 100 tekens*

### What's New in This Version (3.0) — max. 4000

```text
Squash Analyzer 3.0 is a big step forward:

• League: keep track of a whole team match, from E1 to E4, with the SBN scoring.
• Live sharing: your team and supporters follow the score through a link or on their lock screen.
• Badges in bronze, silver and gold. From 23 October everyone starts again; testers get the Pioneer badge.
• Coaching: record the shot and the place on the court for every rally. Afterwards there is a Coach card.
• My team: the standings and schedule of your SBN team, with your teammates ready to pick when you referee or coach.
• A light appearance, a new tour and English when your phone is not set to Dutch.
• Squash Analyzer is now on Android too, and backups work across both.
```

*705 / 4000 tekens*

### Links

- Support URL / Marketing URL: `https://www.squashanalyzer.com/en/`
- Privacy Policy URL: `https://www.squashanalyzer.com/en/privacy.html`

---

## Google Play (Play Console, Main store listing)

### App name — max. 30

```text
Squash Analyzer
```

*15 / 30 tekens*

### Short description — max. 80

```text
Referee and coach squash matches, play league with your team and earn badges.
```

*77 / 80 tekens*

### Full description — max. 4000

```text
Squash Analyzer helps coaches and referees keep track of squash matches, point by point. Free, no ads and no account.

REFEREE
• Tap the score to award a rally
• LET, STROKE and undo
• Service side left/right, automatic game change
• Matches are saved automatically and can be resumed

COACH
• Record for every point who scored, how (winner or error), with which shot and from which zone
• Court in 6 or 9 zones, with only the shots that fit
• Analysis after every game and the Coach card between games
• AI coaching advice with your own OpenAI key (statistics without names)
• Look back at finished matches later

LEAGUE
• Keep track of a whole team match, E1 to E4, with winner and bonus points under the SBN rules
• Share the team match live: teammates add their own match, supporters follow the evening

LIVE SHARING
• Share a link and others follow the score in their browser
• Follow a match or team match in a notification on your lock screen, with a message for every game
• Live data is stored in the EU only and deleted 2 hours after the last update

PLAYERS AND BADGES
• Save your players and pick them at the start of a match
• Players earn badges, such as 5 points in a row or an 11-0 game
• Share a player's badge card with a link; it opens in the app (Android and iPhone) or in the browser
• My team: the standings and matches of your SBN team

BACKUP AND PRIVACY
• Backups to a folder you choose, exchangeable with the iPhone version
• No account needed
• Your players and matches stay on your phone; no ads, no tracking
• Light or dark appearance
• The app follows your phone's language (Android 13+: choose it per app under Settings → Language)
```

*1662 / 4000 tekens*

### Release notes 3.0 (en-US) — max. 500

```text
Squash Analyzer 3.0: keep track of a whole team match in League (E1–E4, SBN scoring) and share it live. Follow the score on your lock screen, show your player the Coach card and earn badges in bronze, silver and gold. From 23 October everyone starts again with badges; testers get the Pioneer badge. New light appearance, a tour, and English when your phone is not set to Dutch.
```

*378 / 500 tekens*

---

## Na te lopen

- De schakelaar "Volley" (NL "Uit de lucht") en andere app-labels moeten gelijk zijn aan de Engelse app-teksten uit sprint 1–3; pas
  aan als die anders uitvallen.
- "English when your phone is not set to Dutch" klopt alleen als de Engelse app-vertaling
  in 3.0 meegaat; anders die zin weghalen uit Promotional text/What's New/Release notes.
- De App Store-beschrijving noemt de Android-versie; Apple staat verwijzingen naar andere
  platforms in de beschrijving soms niet toe ("Backups can be exchanged with the Android
  version" eventueel schrappen bij een afwijzing).
