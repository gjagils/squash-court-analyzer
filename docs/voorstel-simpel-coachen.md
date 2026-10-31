# Voorstel: simpel coachen (alleen wie en waar)

Status: gebouwd op 31 oktober 2026 (zie `docs/wijzigingen-builds.md`, "Eenvoudig coachen"). De
keuzes: een nieuw punttype `Rally` ("Punt"), "waar eindigde de rally", een instelling
Uitgebreid/Eenvoudig met een eenmalige pop-up; standaard blijft Uitgebreid. Hieronder het
oorspronkelijke voorstel.

## Het idee

Nu kost een punt in Coach vier tikken: wie scoort → hoe (winner, fout, stroke, …) → waar
op de baan → welke slag. Op een competitie-avond, naast een teamgenoot die zelf ook nog moet
spelen, is dat veel. De simpele variant vraagt alleen:

1. **Wie maakt het punt** (tik op de score, zoals nu)
2. **Waar op de baan eindigde de rally** (tik op de zone, zoals nu)

Twee tikken per punt; het scherm springt na de zone direct terug naar het scorebord.

## Wat levert het op voor het coachen?

Met alleen *wie* en *waar* (plus wat de app al vanzelf weet: wie serveerde, van welke kant,
de rallytijd en de stand) komt er dit uit:

| Inzicht | Voorbeeld van wat de coach ziet | Waar het vandaan komt |
|---|---|---|
| Waar maakt een speler zijn punten | "Bob wint 6 van zijn 9 punten achterin links" | zone van punten van Bob |
| Waar verliest een speler ze | "Wim scoort steeds voorin rechts tegen Bob" | zone van punten van de tegenstander |
| Voor/achter en links/rechts | "70% van de rally's eindigt achterin; voorin wint Bob alles" | zones opgeteld per rij en kant (`ZoneProfile` bestaat al) |
| Verandering per game | "Game 1 eindigde alles achterin, game 2 voorin: het plan werkt" | dezelfde telling per game |
| Eigen service vs. ontvangen | "Bob wint maar 4 van de 11 rally's op eigen service" | `server` per punt |
| Servicekant | "Vanuit rechts wint Wim bijna alles" | servicekant per punt |
| Lange vs. korte rally's | "Rally's langer dan 20 s gaan naar Wim" | rallytijd per punt (al gemeten) |
| Reeksen en druk | "Langste reeks 5 (Wim, 4-6 naar 4-11)", "vanaf 8-8 won Bob 1 van de 4" | volgorde en stand |

Bruikbaar coachadvies dat daaruit volgt, in de taal van de bestaande coachkaart:

- *"Speel meer naar achterin links: daar maakt Bob zijn punten."*
- *"Wim wint voorin: blijf langer achterin en ga pas naar voren als hij uit positie is."*
- *"Op eigen service gaat het mis: kies een veiligere service."*
- *"Lange rally's verlies je: zoek eerder de aanval."*

Het meeste hiervan heeft het analysescherm al (zonekaart, service, rallytijd); het werkt
gewoon met minder gegevens.

## Wat je kwijtraakt

- **Winner of fout is onbekend.** Een punt "voorin links" kan een mooie drop van de scorer
  zijn of een bal van de tegenstander in de tin. De zone zegt dus *waar de rally eindigde*,
  niet *wie hem goed speelde*. Alles wat op winners/fouten rust valt weg: de verhouding
  winners–fouten, "onnodige fouten", de foutsoort, strokes, en de slagverdeling.
- **Badges** die winners, strokes of slagen tellen kunnen niet in een simpele wedstrijd
  (de score-badges zoals comebacks en reeksen wel).
- **Coachadvies** op basis van fouten en slagen valt weg; het advies hierboven komt ervoor
  in de plaats.

## Hoe het eruit kan zien

- In de wedstrijdopzet bij Coach een keuze **Invoer: Volledig · Simpel** (onthouden, net als
  Best of). Ook te wisselen midden in een wedstrijd via het tandwiel? Voorstel: nee, per
  wedstrijd vast, dan blijft de analyse eerlijk.
- Een punt in simpele modus wordt opgeslagen met `pointType` "onbekend" en zonder slag.
  Daarvoor is een nieuwe waarde in `PointType` nodig. Omdat SwiftData-schema V7 bevroren is,
  moet dit zonder modelwijziging: de `pointType` wordt als tekst opgeslagen, dus een nieuwe
  waarde ("Rally") past erin; oudere builds en de live-pagina moeten een onbekende waarde dan
  wel netjes tonen (eerst controleren).
- De analyse toont in simpele wedstrijden alleen de blokken die kloppen (zones, service,
  rallytijd, verloop) en een regel "Simpele invoer: winners en fouten zijn niet bijgehouden".

## Aanpak en grootte

1. Core: `PointType.rally` (of nil-type), `Game.addPoint` zonder slag na een zone in
   simpele modus, `Match.inputMode`; tests.
2. Opzet: de keuze Volledig/Simpel; scorescherm: na de zone direct terug.
3. Analyse en coachkaart: blokken verbergen die winners/fouten nodig hebben; nieuwe
   adviesregels op zone, service en rallytijd.
4. Back-up, live-pagina en oudere builds: een onbekend punttype mag niets breken.

Inschatting: twee à drie avonden werk, het meeste in de analyse (stap 3). Geschikt voor 3.1
build 2.

Open vragen voor Gerd-Jan:

- Is "waar eindigde de rally" duidelijk genoeg voor de coach, of liever "waar maakte de
  scorer het punt" (en bij een fout van de tegenstander de zone overslaan)? Het eerste is
  sneller en altijd invulbaar; het tweede is preciezer maar weer een keuze per punt.
- Mag simpel de standaard worden voor nieuwe gebruikers, met Volledig voor de echte coach?
