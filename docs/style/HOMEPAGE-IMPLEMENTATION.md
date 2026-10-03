# Homepage — implementatie 3 oktober 2026

De gekozen Clubhuis-variant is geïmplementeerd in de gedeelde `HomeMenu.swift` en aangesloten op beide hosts. Merkheader met bestaand logo, gekozen tagline, zwarte achtergrond, identieke teamkaart/actietegels en drie compacte navigatierijen. De kaartvulling is vooraf op zwart samengesteld om kleurverschillen tussen SwiftUI en Compose te vermijden.

`HomeTeamSummary` deelt de teamweergave tussen iOS en Android. Bestaande teamfetch/cache, instellingen, navigatie, wedstrijdhervatting en opslag blijven bij de bestaande hosts. Zonder gekoppeld team blijft de teamkaart, zoals voorheen, verborgen. Scrollen blijft beschikbaar bij kleine schermen of lange inhoud.

Validatie:
- iOS simulatorbuild geslaagd.
- Android debugbuild en bestaande unittests geslaagd.
- Android HomeScreenTest: 2 tests geslaagd (instellingen openen/terug, activity recreation).
- Native visuele controle iPhone 17 Pro, met en zonder tijdelijke voorbeeldteamgegevens. Alles past met standaardtekst zonder scrollen.
- Android-emulator: logo, tagline, beide actietegels en drie navigatierijen gecontroleerd.
- Bestaande Android-tests verwijzen nu naar de merknaam `SquashAnalyzer`.

Screenshots staan lokaal in `output/homepage/`. Niet gepubliceerd naar TestFlight of Google Play. Geen globale stijlwijziging van vervolgschermen; zie `BACKLOG.md` voor Claude Code.
