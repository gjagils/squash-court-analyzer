# App Store Metadata – Squash Analyzer

## App Name (30 tekens max)
Squash Analyzer

## Subtitle (30 tekens max)
Coach & Scheidsrechter App

---

## Beschrijving (Nederlandse tekst, max 4000 tekens)

Squash Analyzer is de professionele squash-app voor coaches en scheidsrechters. Registreer wedstrijden in detail, ontvang AI-coaching advies en score professioneel — alles in één app.

**COACH MODUS**
Analyseer elke rally tot op het slag- en zoneniveau:
• Registreer winners, forced errors, eigen fouten, strokes en servicepunten
• Tik op het interactieve baandiagram om te markeren waar het punt viel
• Kies het slagtype: drive, cross, volley, drop, lob of boast
• Wie serveert en vanuit welke box (links/rechts) wordt automatisch bijgehouden
• Ontvang na elke game tactisch coaching advies gegenereerd door AI (GPT-4o)
• Deel de tussenstand direct via WhatsApp
• Sla volledige wedstrijden op, hervat een onderbroken wedstrijd en kijk alles terug
• Bekijk uitgebreide statistieken per speler, zone en slagtype

**SCHEIDSRECHTER MODUS**
Snel en professioneel scoren zonder afleiding:
• Best of 5 met de officiële serviceregels: de servicebox wisselt na elke gewonnen rally
• Links/Rechts per speler vast te zetten (bijvoorbeeld voor een linkshandige)
• Rally-voor-rally scorelijn tussen de spelers
• Let call en stroke registratie
• Match- en gametimer, undo laatste punt
• Deel de uitslag via WhatsApp: kort, als scorekaart of als verslag

**LATER INSTAPPEN**
• Begin bij game 2, 3 of 4 met de stand tot dan toe, in beide modi

**SPELERSPROFIELEN**
• Sla spelers op met foto, naam en persoonlijke coaching aandachtspunten
• Importeer je hele team in één keer
• Kies snel een speler bij het opstarten van een wedstrijd
• AI coaching houdt rekening met de aandachtspunten van de speler

**OPSLAAN & BACKUP**
• Wedstrijden worden veilig bewaard op je iPhone
• Maak een back-up naar iCloud Drive met één tik
• Herstel back-ups eenvoudig op een nieuw apparaat

Voor de AI coaching functie is een eigen OpenAI API-sleutel vereist (gratis aan te maken via platform.openai.com).

---

## Keywords (100 tekens max — kommagescheiden, geen spaties na komma)
squash,coach,scheidsrechter,analyse,tennis,sport,tactiek,training,wedstrijd,score

## Categorie
Sports

## Leeftijdscategorie
4+

## Support URL
https://www.squashanalyzer.com

## Marketing URL (optioneel)
https://www.squashanalyzer.com

## Privacy Policy URL
https://www.squashanalyzer.com/privacy.html

---

## Screenshots vereist (neem deze in de Simulator)

### iPhone – minimaal vereist: 6.7" (iPhone 16 Plus / 15 Plus)
Resolutie: 1320 × 2868 pixels (of 1290 × 2796 voor 15 Pro Max)

Aanbevolen volgorde:
1. Startscherm met mode-toggle (COACH / SCHEIDSRECHTER)
2. Coach modus – baan met geselecteerde zone
3. Coach modus – scorebord lopende game
4. Scheidsrechter modus – scorebord
5. Wedstrijdgeschiedenis

### iPad – optioneel maar aanbevolen: 12.9" (iPad Pro)
Resolutie: 2048 × 2732 pixels

---

## Wat je nog zelf moet doen in App Store Connect

1. Log in op https://appstoreconnect.apple.com
2. Maak een nieuwe app aan:
   - Platform: iOS
   - Bundle ID: com.squashanalyzer.app
   - SKU: squashanalyzer-001
3. Vul bovenstaande tekst in bij "App Information" en "Pricing & Availability"
4. Upload screenshots (zie hierboven)
5. Stel prijs in op "Gratis"
6. Voeg Privacy Policy URL toe: https://www.squashanalyzer.com/privacy.html
7. In Xcode: bump build number → Product → Archive → Distribute App → App Store Connect
8. Koppel de build aan je App Store listing
9. Dien in voor review

### Containers in Xcode (eenmalig)
Ga naar Signing & Capabilities → iCloud → Containers → klik + en voeg toe:
  iCloud.com.squashanalyzer.app

### PrivacyInfo.xcprivacy toevoegen (eenmalig)
Het bestand staat al klaar op:
  SquashAnalyzer/PrivacyInfo.xcprivacy

Stap:
1. Open Xcode → rechtsklik op de SquashAnalyzer map in de navigator
2. "Add Files to SquashAnalyzer..."
3. Selecteer PrivacyInfo.xcprivacy
4. Zorg dat ✅ "Add to target: SquashAnalyzer" aangevinkt staat
5. Klik Add
