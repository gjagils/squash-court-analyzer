# Teamwedstrijd en Mijn team: eenvoudiger maken

Stand 8 oktober 2026. Aanleiding: Gerd-Jan merkte dat een slimme teamgenoot
op zijn telefoon snel aan het zoeken was. Dit bestand heeft twee delen: een
**handleiding in drie stappen** die je nu al kunt doorsturen, en een
**voorstel voor de app** zodat die handleiding straks overbodig wordt.
Gebaseerd op de code van 8 oktober (`SharedTeamMatchViews`,
`SharedTeamLiveViews`, `TeamInvite`); nog niet op een echte telefoon met
teamgenoten geprobeerd.

## Waar het nu wringt

1. **Twee dingen heten "team".** *Mijn team* (beginscherm) is alleen de stand
   en het programma uit SBN. *Competitie* is waar je een teamwedstrijd
   bijhoudt. Een teamgenoot zoekt de teamwedstrijd onder Mijn team.
2. **Drie knoppen met bijna dezelfde naam** op het teamwedstrijdscherm:
   *Live delen*, *Deel kijkerslink*, *Nodig teamgenoten uit*. Welke is voor
   de groepsapp en welke voor teamgenoten die zelf scoren?
3. **Twee soorten ontvangers, één link per keer.** De kijkerslink (alleen
   kijken) en de uitnodiging (meedoen) zijn aparte berichten.
4. **Meedoen is een lange route:** link openen, "welk team is van jou",
   Deelnemen, op de partij tikken, wedstrijd starten, schakelaar *Onderdeel
   van een teamwedstrijd*, partij kiezen, kiezen wie onze speler is.
5. **Niemand hoeft meer dan kijken te doen**, maar de app vraagt dat nergens
   af. Een kijker hoeft niets te installeren; dat staat nergens.

## Deel 1: handleiding in drie stappen (voor de groepsapp)

> **Teamwedstrijd live volgen met SquashAnalyzer**
>
> **Alleen kijken?** Open de link die een teamgenoot deelt. Meer hoef je niet te
> doen, je hebt geen app nodig.
>
> **Zelf je partij bijhouden?** (alleen als je de app hebt)
> 1. Open de uitnodiging van je teamgenoot. Opent de link de app niet? Kopieer
>    het bericht, open de app, tik op *Competitie* → *Deelnemen met link of
>    code* en plak.
> 2. Kies welk team van jou is en tik op *Deelnemen*.
> 3. Tik op jouw partij (E1 tot en met E4) en kies *Nieuwe wedstrijd*. Je
>    telt zoals altijd; de stand gaat vanzelf naar de teampagina.
>
> **Wie aanmaakt** (kan iedereen uit het team zijn): Competitie → *Nieuwe
> teamwedstrijd* → onderaan *Live delen* → stuur *Nodig teamgenoten uit* naar
> het team en *Deel kijkerslink* naar de supporters. Na afloop: *Deel verslag*.
>
> Alles op de teampagina verdwijnt 2 uur na de laatste update.

Bij uitnodigen gaat al zo'n bericht mee (`TeamLiveTexts.invite`); de tekst
hierboven is bedoeld voor één keer aan het begin van het seizoen.

## Deel 2: voorstel voor de app

Van klein naar groot. Elk punt staat los van de andere, en geen enkel punt
raakt het bevroren schema (V7) of de server-API.

| # | Wijziging | Wat het oplost | Omvang |
|---|-----------|----------------|--------|
| 1 | **Eén deelscherm** *Deel met team en supporters* met twee aparte knoppen: *Deel kijkerslink* (supporters, alleen kijken) en *Nodig teamleden uit* (meedoenlink en code). Niet één bericht met beide links: dan krijgt een supporter in de groepsapp ook de schrijfsleutel. De losse knoppen op het teamwedstrijdscherm verdwijnen. | punt 2 en 3 | klein (tekst en knoppen) |
| 2 | **Na Deelnemen direct de partijkeuze** ("Welke partij speel of tel jij?") in plaats van terug naar het overzicht, en daarna meteen wedstrijd starten met schakelaar en speler al ingevuld. | punt 4 | middel |
| 3 | **Mijn team: knop *Start teamwedstrijd* bij de eerstvolgende wedstrijd**, met teams en datum al ingevuld en Live delen alvast aan. | punt 1 en 4 | middel |
| 4 | **Uitleg bij het eerste gebruik:** drie regels boven in Competitie (zie handleiding), weg te tikken. | punt 5 | klein |
| 5 | **Kijkerslink zonder app uitleggen** in de deeltekst: "kijken kan zonder app". | punt 5 | klein |
| 6 | **Naamgeving:** *Mijn team* hernoemen naar *Stand en programma* of de teamwedstrijd ook vanaf Mijn team bereikbaar maken. | punt 1 | klein, maar dan moeten handleiding en schermen mee |

**Mijn advies:** begin met 1, 4 en 5 (alleen tekst en knoppen, een halve
dag), stuur de handleiding hierboven nu al naar het team, en kijk na één
speeldag of 2 en 3 nodig zijn. Wie het één keer heeft gedaan, ziet
vermoedelijk vooral de route in punt 4 als het zware deel.

## Open vragen voor Gerd-Jan

- Is de teamgenoot die op zijn telefoon zocht degene die aanmaakte of een meespeler?
  Dat bepaalt of 1 of 2 eerst moet.
- Mag *Live delen* standaard aan staan bij een nieuwe teamwedstrijd, of wil je
  dat bewust per avond kiezen? (Privacy: er gaan dan voornamen naar de server.)
- Zou je zelf de handleiding in de groepsapp zetten, of liever op
  `squashanalyzer.com/handleiding` als aparte korte pagina?

## Besluit 8 oktober

Gerd-Jan koos: kijkerslink en meedoenlink blijven aparte berichten. De
meedoenlink bevat de gedeelde schrijfsleutel en de server beperkt die niet
tot één partij of team (zie `docs/plan-live-teamwedstrijd.md`), dus hij hoort
alleen bij teamleden. De rol "captain" bestaat niet in de app: iedereen uit
het team kan de teamwedstrijd aanmaken; die telefoon wordt de eigenaar en kan
alleen zelf *Live stoppen* voor iedereen.

Het klikbare voorbeeld is alleen een mock-up. Bij het bouwen gebruiken we de
bestaande componenten en de stijl van `docs/style/README.md` (`ActionButton`,
`SectionHeader`, `SharedColors`, de LIVE-capsule uit `TeamLiveCard`) en
dezelfde plekken, namen en iconen op iPhone en Android. De labels EIGEN en
GEDEELD worden één gedeeld onderdeel in `SquashAnalyzerUI`.
