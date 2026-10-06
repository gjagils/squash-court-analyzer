# Backlog: SquashLevels-profiel openen vanuit Spelers

Status: afgesproken op 6 oktober 2026, nog niet gebouwd. Geen buildnummer
toegekend. Dit is een kleine, afzonderlijke feature voor iOS en Android.
Backlog: [Wijzigingen per build](wijzigingen-builds.md#backlog).

Aanvulling van Gerd-Jan: iedere opgeslagen speler krijgt een eigen link;
geen algemene SquashLevels-instelling. De koppeling kan ook al in een
team-zip staan en wordt dan samen met de speler geïmporteerd.

## Doel

Als coach wil ik bij een opgeslagen speler zijn SquashLevels-profiel
vastleggen, zodat ik met één knop zijn actuele Level, ranking en historie
op SquashLevels kan bekijken.

De app bewaart de verwijzing naar het profiel. De browser toont de gegevens
rechtstreeks bij SquashLevels. De app haalt geen rankingpagina's op, leest
geen browserinhoud uit en bewaart geen ratings, ranglijsten of inloggegevens.

## Bediening

1. In **Spelers → speler bewerken** staat een optioneel veld
   **SquashLevels-profiel**, met de uitleg: "Plak de link naar het profiel
   van deze speler, of vul het SquashLevels-speler-ID in."
2. Bewaren valideert de invoer lokaal. Een ongeldige verwijzing krijgt een
   duidelijke melding; de eerder opgeslagen koppeling blijft behouden.
   Annuleren verandert niets.
3. Bij een gekoppelde speler staat de knop **Bekijk op SquashLevels**, met
   een extern-linkicoon. De knop is bereikbaar vanuit de spelergegevens en
   het bestaande badgescherm van die speler; de bestaande tikactie in de
   spelerslijst blijft behouden. Geen afhankelijkheid van het geplande
   trendscherm.
4. De knop opent het profiel in de standaardbrowser via de platformfunctie
   voor een externe HTTPS-link. Terugkeren naar de app behoudt de context.
5. Een koppeling wijzigen of verwijderen kan in de spelereditor. Zonder
   koppeling wordt de bekijkknop niet getoond.

Inloggen, een niet-bestaand profiel of een storing worden door de website
afgehandeld. Als het systeem de browser niet kan openen, toont de app:
"De browser kon niet worden geopend. Probeer het opnieuw."
Opslaan van de koppeling werkt ook zonder netwerk.

## Team-zip en import via link

Voeg aan ieder spelerobject in `team.json` een optioneel veld
`squashLevelsProfileURL` toe. Dit bevat de volledige HTTPS-profiellink,
zodat een captain de link rechtstreeks uit de browser kan kopiëren. In de
app mag daarnaast een los speler-ID worden ingevoerd. De exacte toegestane
URL-vorm wordt vóór implementatie geverifieerd (zie hieronder).

- Dezelfde ondersteuning voor een lokaal zip-bestand en een team-zip
  opgehaald via de bestaande teamimportlink.
- Een oude zip zonder het veld blijft werken en laat een bestaande
  SquashLevels-koppeling ongemoeid. Een lege string geldt als ontbrekend;
  verwijderen gebeurt expliciet in de spelereditor.
- Een geldige aangeleverde link wordt bij een nieuwe speler opgeslagen en
  werkt bij een bestaande speler diens koppeling bij, volgens de bestaande
  teamimport die spelers op naam matcht. De mapping wordt daarna aan de
  gevonden lokale speler-UUID gekoppeld. De gebruiker kan een foutieve
  koppeling achteraf corrigeren.
- Valideer alle verwijzingen vóór de import iets wijzigt. Een ongeldige
  link breekt de import af met een melding die de betreffende speler
  noemt; geen half geïmporteerd team. Houd spelersopslag en koppelingen
  consistent als een opslagstap mislukt.
- Documenteer het veld met een gecontroleerd voorbeeld in
  `docs/team-import/README.md` zodra het geïmplementeerd is. Het veld wordt
  nu nog niet door de app ondersteund; dit document specificeert de uitbreiding.
- Teamzips met echte spelers blijven buiten de publieke Git-repository,
  volgens de bestaande projectafspraak.

## Linkformaat en validatie

- Gebruik het SquashLevels-speler-ID, niet een SBN-lidnummer, naam of
  positie in de ranglijst. Koppel het aan de bestaande lokale speler-UUID.
- Verifieer vóór implementatie met een echt, openbaar profiel welke
  profiel-URL bij dit ID hoort, ook voor de SBN-weergave. De definitieve
  URL-template en ondersteunde profielpaden zijn nog niet vastgesteld.
  Leg gecontroleerde voorbeelden vast voor de tests.
- Accepteer alleen een ID volgens het geverifieerde formaat, of een
  HTTPS-profiel-URL met een expliciet toegestane SquashLevels-host en
  herkend profielpad. Geen willekeurige URL, credentials, afwijkende poort,
  javascript-URL of host die alleen op SquashLevels lijkt.
- Lees uit een ondersteunde URL het ID en eventueel de noodzakelijke
  profielcontext; bouw de bestemmingslink centraal op. Neem geen
  trackingparameters, login-tokens of onnodige fragmenten over.
- Geen automatische naamzoekactie, profielcontrole via HTTP, prefetch of
  previewverzoek. Alleen de tik op de knop opent de website.

## Opslag en uitvoering

- Gedeelde validatie en URL-opbouw in `SquashAnalyzerCore`; gedeelde velden
  en knop in `SquashAnalyzerUI`. Sluit aan op `PlayerProfileFields`, de
  spelereditors op beide platforms en `SharedPlayerBadgesView`.
- Voorkeursaanpak tijdens de testperiode: een kleine lokale mapping van
  speler-UUID naar profielverwijzing in een apart, versieerbaar JSON-bestand,
  via een gedeelde store. SwiftData V7 blijft bevroren; geen nieuw veld
  toevoegen aan het bestaande schema. Een latere modelkolom vraagt V8 en
  een Room-migratie.
- Opslagfouten zichtbaar maken. Bij verwijderen van een speler zijn
  koppeling opruimen; een naamswijziging behoudt de koppeling. Gelijke
  spelersnamen leiden niet automatisch tot dezelfde koppeling.
- De mapping gaat mee in handmatige én automatische volledige back-ups,
  met hetzelfde formaat op iOS en Android. Volg de bestaande afspraken
  over formaatversies en checksum; bepaal de versie bij implementatie.
  Oude back-ups blijven leesbaar.
- Bij **Voeg toe** vult de import ontbrekende koppelingen aan; een
  bestaande, afwijkende koppeling blijft behouden. Bij **Vervang alles**
  volgt de mapping de herstelde spelers en koppelingen (een oude back-up
  zonder dit veld levert dan geen koppelingen op). Geen verweesde IDs.
- Geen profielverwijzing toevoegen aan publieke badgekaarten of
  livewedstrijden. Teamzips krijgen de hierboven beschreven ondersteuning.

## Klaar wanneer

- [ ] Toevoegen via ID en via gecontroleerde profiellink werkt op iPhone
      en Android; herstart, bewerken, annuleren en verwijderen getest.
- [ ] De knop opent het juiste profiel in de browser; geen netwerkverzoek
      vanuit de app bij opslaan of het tonen van de speler.
- [ ] Ongeldige invoer en mislukte opslag geven bruikbare meldingen.
- [ ] Core-tests dekken URL-opbouw, validatie en geweigerde hosts/paden.
- [ ] Opslag en back-up zijn getest, inclusief iOS ↔ Android, oude
      back-ups, Voeg toe, Vervang alles en conflicterende koppelingen.
- [ ] Teamimport uit bestand en via link neemt de profiel-URL per speler
      mee, ook bij een bestaande speler. Oude zips blijven werken; ontbrekende
      of lege velden behouden bestaande links. Ongeldige links en
      opslagfouten veroorzaken geen gedeeltelijke import.
- [ ] De bediening past bij de huisstijl, werkt met vergrote tekst en
      heeft begrijpelijke VoiceOver- en TalkBack-labels.
- [ ] Handleidingen en buildnotities bijgewerkt; privacytekst vermeldt
      dat de browser een externe website opent als aanvulling nodig is.
- [ ] Vereiste projectchecks volgens `AGENTS.md` uitgevoerd vóór opleveren.

## Achtergrond en buiten scope

De [robots.txt van de SBN-site](https://sbn.squashlevels.com/robots.txt)
sluit onder meer `/players` en `/player_detail` uit voor robots
(gecontroleerd 6 oktober 2026). De gekozen feature is gewone navigatie
door de gebruiker. Automatisch rankings of Levels tonen in de app is een
apart onderwerp, waarvoor eerst een toegestane API of data-afspraak met
SquashLevels/SBN nodig is.

De bestaande **Mijn team**-koppeling haalt gegevens van `sbn.toernooi.nl`
op; dat is een andere dienst en geeft geen automatische toegang tot
SquashLevels. Deze feature verandert Mijn team niet.
