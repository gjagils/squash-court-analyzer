# App Review-notities 4.0 (App Store Connect, App Review Information)

Plak de tekst hieronder in het veld **Notes**. Zet de gebruikersnaam en het wachtwoord van het
testaccount in **Sign-In Information** (dat doet Gerd-Jan zelf; het wachtwoord staat nergens in de repo).
Vink **Sign-in required** aan.

```
SquashAnalyzer is a scoring and analysis app for squash. Everything works without an account;
an account is optional and only needed to receive matches that others send to you and to keep your
player card, form and badges together across devices.

To test the account features:
1. Open the app, tap the person icon at the top left of the home screen (or the "Maak je account" card).
2. Sign in with the demo account in Sign-In Information (email and password).
3. After signing in, Settings > Mijn account shows the account, the e-mail address and the option to
   delete the account. Account deletion is also possible outside the app: https://squashanalyzer.com/account-verwijderen

The app is in Dutch and English (follows the device language).
The scoring features (Scheidsrechter and Coach on the home screen) need no account and no network.
Team matches (Competitie) use the public SBN competition pages (sbn.toernooi.nl) to look up teams.
Push notifications are optional.
```

Checklist voor Gerd-Jan:

1. Maak in de app het account `satest+review@gerdjan.nl` met een eigen wachtwoord (op de echte
   server, want de beoordelaar gebruikt de store-build). Claude maakt het niet aan.
2. Controleer in de app dat inloggen op een schone installatie werkt.
3. Vul in ASC onder App Review Information de gebruikersnaam en het wachtwoord in en plak de notities.
4. Na goedkeuring: het testaccount in de app verwijderen (Mijn account) of laten staan voor de volgende review.
