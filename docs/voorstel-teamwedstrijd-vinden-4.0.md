# Teamwedstrijd vinden zonder uitnodiging (4.0)

Stand 6 november 2026. Voorstel, nog niets van gebouwd. Vraag van Gerd-Jan:
"Als ik een competitiewedstrijd aanmaak, kunnen teamleden die SquashAnalyzer
gebruiken die dan zien als ze dezelfde wedstrijd starten?" Nu niet, ook niet
in 4.0 zoals het gepland stond. Dit voorstel maakt het mogelijk voor
teamleden met een spelersaccount, en laat de tegenstander meekijken.

Gebaseerd op de code van `main` op 6 november (commit `0418679`).

## Besloten (Gerd-Jan, 6 november 2026)

1. **Standaard zichtbaar voor het team.** Een teamwedstrijd uit het programma
   is vindbaar voor teamleden met een account, tenzij de maker het uitzet.
2. **Ook zonder Live delen**, voor teamleden en eventueel de tegenstander,
   maar **niet op het clubscherm**. Live delen blijft de stap naar buiten:
   clubscherm en kijkerslink voor supporters.
3. **Zichtbaar tot en met de dag na de speeldag.**

## Hoe het nu werkt

- Een teamwedstrijd staat per telefoon in een JSON-bestand
  (`JSONFileTeamMatchStore`). Telefoons synchroniseren dat bestand niet.
- Live delen maakt op de live-Worker een `TeamSession` aan (`POST /api/team`,
  `server/live-worker/src/index.js`). Die krijgt een willekeurig id, een
  schrijfsleutel voor de uitnodiging en een eigenaarssleutel die op de
  telefoon van de starter blijft. De kop bevat alleen de twee teamnamen en de
  datum (`validateTeamHeader`), geen SBN-wedstrijd of team.
- Een `TeamSession` komt **altijd** op het clubscherm van een club met een
  scherm: `reportToClubs` zoekt de schermen op teamnaam (`wallsOfTeam` in
  `club.js`). Er is geen manier om dat per wedstrijd uit te zetten.
- Meedoen kan alleen met de uitnodiging (`TeamInvite`: `id.key` als link of
  code). Wie zelf "dezelfde" wedstrijd aanmaakt, krijgt een tweede, losse
  teamwedstrijd.
- De sessie verdwijnt een dag na de laatste update (`TEAM_IDLE_MINUTES =
  1440` in `wrangler.toml`). Let op: het commentaar bovenaan `team.js` en een
  paar documenten zeggen nog twee uur. Dat geldt voor een losse
  livewedstrijd (`IDLE_MINUTES`), niet voor een teamwedstrijd.

Wat 4.0 al heeft en wat dit voorstel gebruikt:

- Elk account heeft een **teamsleutel** (`players.team_key`,
  `"<league uuid>/<teamnummer>"`, uit `LeagueTeamLink.accountKey`). De app
  zet die vanuit de link van Mijn team (`AccountSending.ownTeamKey()`).
- Een teamwedstrijd die uit het programma van Mijn team komt, bewaart de
  SBN-wedstrijd: `TeamMatch.fixtureId` is `LeagueFixture.id`, de link van die
  wedstrijd op sbn.toernooi.nl (`LeagueTeam.swift`, `team-match__wrapper`).
  **Beide teams zien dezelfde link**: daarmee kan ook de tegenstander de
  wedstrijd vinden.

## Wat de gebruiker ziet

**Kees maakt de teamwedstrijd aan** (Competitie → Nieuwe teamwedstrijd → kiest
de wedstrijd uit het programma, of straks *Start teamwedstrijd* bij Mijn team).
Hij heeft een account. Onder het aanmaken staat één regel met een schakelaar,
standaard aan:

> **Zichtbaar voor mijn team.** Teamleden met de app en een account zien deze
> wedstrijd en kunnen hun partij bijhouden. De tegenstander kan meekijken.
> Niet op het clubscherm.

Live delen (clubscherm en kijkerslink) staat los daarvan en blijft uit tot hij
het aanzet.

**Gerd-Jan, teamlid, opent op de speeldag de app.** Hij heeft een account en
Mijn team staat op hetzelfde team.

1. Onder *Competitie* en op de Mijn team-kaart bij de wedstrijd van vandaag
   staat: **"Kees heeft de wedstrijd tegen Bevo 3 aangemaakt. Meedoen?"**
2. Hij tikt op *Meedoen*. De app doet wat een uitnodiging nu doet
   (`TeamInvite` → Deelnemen). De vraag "welk team is van jou" slaat hij
   over, want de app weet het uit Mijn team.
3. Daarna kiest hij zijn partij (E1–E4) en start de wedstrijd, zoals nu.

**Gerd-Jan tikt zelf op Nieuwe teamwedstrijd** voor dezelfde wedstrijd. De app
vraagt eerst de server. Bestaat hij al, dan krijgt hij in plaats van een
nieuwe: "Kees heeft deze wedstrijd al aangemaakt. Meedoen?" Er komt geen
tweede teamwedstrijd.

**Lisa, van Bevo 3, de tegenstander**, heeft ook een account en Mijn team op
Bevo 3. Op de speeldag ziet zij: **"Squash City 2 houdt deze wedstrijd bij.
Meekijken?"** Ze opent de teampagina in de app (alleen kijken, zoals de
kijkerslink). Tikt ze toch op Nieuwe teamwedstrijd, dan vraagt de app
"Meekijken bij Squash City 2, of een eigen teamwedstrijd maken?". Een eigen
teamwedstrijd blijft mogelijk; die is dan op dezelfde manier vindbaar voor
haar team.

**Zonder account of zonder Mijn team** werkt alles zoals nu: met de
uitnodiging. Die knop blijft er, ook voor wie wel een account heeft.

## Hoe het werkt

### Live-Worker: een teamwedstrijd zonder clubscherm

Zichtbaar voor het team betekent dat er een `TeamSession` is, ook als Live
delen uit staat; anders is er niets om bij aan te sluiten. Zo'n sessie mag
niet op het clubscherm. Daarvoor krijgt de kop één veld:

- `validateTeamHeader` neemt `clubScreen` over (boolean, standaard `true`,
  zodat bestaande apps niets merken).
- `reportToClubs` en `leaveClubs` slaan de schermen over als
  `team.clubScreen === false`.
- Live delen aanzetten is een `PUT /api/team/:id` van de starter met
  `clubScreen: true` (die route bestaat al, met de eigenaarssleutel). Live
  delen weer uitzetten zet hem terug op `false` en haalt de wedstrijd van het
  scherm (`setTeam` roept `leaveClubs` al aan).
- De gebruikscijfers (`count('team', …)`) tellen zo'n sessie apart
  (`teamOnly`), zodat "live teamwedstrijden" in het weekrapport blijft
  betekenen wat het nu betekent.

De teampagina `/t/<id>` bestaat voor zo'n sessie wel. Het id is willekeurig en
wordt alleen aan het eigen team en de tegenstander gegeven, net als nu aan wie
de kijkerslink krijgt.

### Account-Worker: een wijzer per team en SBN-wedstrijd

De account-Worker (`squash-account`, D1 in de EU) krijgt een kleine tabel:

```sql
-- A team match that teammates (and the opponent) can find (docs/voorstel-teamwedstrijd-vinden-4.0.md)
CREATE TABLE team_lives (
  team_key TEXT NOT NULL,        -- "<league uuid>/<team number>" of the team keeping it
  fixture TEXT NOT NULL,         -- LeagueFixture.id: the SBN match link (the same for both teams)
  team_name TEXT NOT NULL,       -- shown to the opponent ("Squash City 2 houdt deze wedstrijd bij")
  live_id TEXT NOT NULL,         -- TeamSession id on the live Worker
  write_key TEXT NOT NULL,       -- the key of the invitation (never the owner key)
  starter_id TEXT NOT NULL,      -- players.id of whoever registered it
  starter_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,   -- end of the day after the match day
  PRIMARY KEY (team_key, fixture)
);
CREATE INDEX team_lives_fixture ON team_lives (fixture);
```

Drie routes, alleen met een account:

| Route | Wat |
|---|---|
| `GET /api/v1/me/team/lives?fixtures=<f1>,<f2>` | **Eigen team** (`team_key` van de beller): alle lopende rijen, met `liveId`, `writeKey`, `starterName`. **Andere teams**: alleen rijen voor de gevraagde wedstrijden (de app stuurt de wedstrijden van vandaag uit zijn eigen programma), met `liveId` en `teamName`, **zonder schrijfsleutel**. Verlopen rijen telt hij niet mee |
| `PUT /api/v1/me/team/lives` `{ fixture, teamName, liveId, writeKey, replaces? }` | Aanmelden voor het eigen team. Bestaat er al een rij voor deze wedstrijd en dit team, dan geeft hij die terug (409) en verandert hij niets. `replaces` met het `liveId` van de bestaande rij vervangt die: voor als de app zag dat die sessie weg is |
| `DELETE /api/v1/me/team/lives/:fixture` | Afmelden (schakelaar uit, teamwedstrijd verwijderd), alleen door wie hem aanmeldde |

De teamsleutel komt altijd uit het account van de beller, nooit uit het
verzoek. Aanmelden is één `INSERT … ON CONFLICT DO NOTHING` met daarna een
`SELECT`: maken twee telefoons tegelijk dezelfde wedstrijd, dan wint er één en
krijgt de ander de bestaande terug. Verlopen rijen worden bij elke aanmelding
gewist (`DELETE … WHERE expires_at < ?`) en tellen bij het lezen niet mee.

`expires_at` is het einde van de dag na de speeldag (Europe/Amsterdam). De
`TeamSession` zelf verdwijnt een dag na de laatste update; een rij waarvan de
sessie al weg is, ziet de app aan een 404 en vervangt hij met `replaces`.

### App

- **Aanmaken.** Bij een teamwedstrijd met `fixtureId`, een account, een
  teamsleutel en de schakelaar aan: eerst `GET`. Is er voor deze wedstrijd al
  een rij van het eigen team, dan controleert de app die met
  `GET /api/team/:id/verify`. Werkt hij, dan meedoen in plaats van aanmaken.
  Is hij weg (404), dan zelf aanmaken en aanmelden met `replaces`. Anders:
  `POST /api/team` met `clubScreen: false` en daarna `PUT`. Bij 409 (iemand was
  net eerder) stopt de app zijn eigen nieuwe sessie met de eigenaarssleutel en
  doet hij mee met de andere.
- **Live delen** op een zichtbare teamwedstrijd maakt geen nieuwe sessie meer,
  maar zet `clubScreen` aan en toont de kijkerslink. Zonder schakelaar of
  zonder account werkt Live delen zoals nu.
- **Synchroniseren.** Is de teamwedstrijd zichtbaar, dan stuurt en haalt het
  teamwedstrijdscherm de partijen zoals nu bij live (`mergeLive` bij openen
  en *Vernieuwen*), ook als Live delen uit staat.
- **Vinden.** Competitie en de Mijn team-kaart vragen `GET` op bij openen en
  bij *Vernieuwen*, alleen op de speeldag van een wedstrijd uit het programma
  (de app kent die datum al, net als `TeamMatchSupport.candidate`). Zo blijft
  het aantal verzoeken klein.
- **Meedoen** (eigen team): met `liveId` en `writeKey` maakt de app dezelfde
  `TeamInvite` als uit een link en gebruikt dezelfde code. De teamkant
  (thuis/uit) volgt uit Mijn team.
- **Meekijken** (tegenstander): opent de teampagina, zoals een kijkerslink.
  Lisa kan ook de lockscreen-volger aanzetten (`/followers`), zoals nu.
- **Schakelaar uit of teamwedstrijd verwijderd**: `DELETE` bij de
  account-Worker. Staat Live delen ook uit, dan ook `DELETE /api/team/:id`.

### Waarom de schrijfsleutel in de database mag

Het is dezelfde sleutel die nu al in de groepsapp gaat. De server geeft hem
alleen aan een account met dezelfde teamsleutel, nooit aan de tegenstander.
De eigenaarssleutel (namen wijzigen, clubscherm, stoppen) komt nooit op de
server. De rij verdwijnt na de dag na de speeldag.

## Wat de server niet afdwingt

Dit moet in de documentatie en de privacytekst kloppen (AGENTS.md punt 7):

- **De teamsleutel is niet gecontroleerd.** Een account zet zijn eigen
  teamsleutel vanuit Mijn team (`PATCH /api/v1/me`). Wie een account maakt en
  Mijn team op jouw team zet, ziet dus jullie teamwedstrijd en kan een partij
  schrijven. Dat is hetzelfde vertrouwen als bij de wedstrijden die op een
  naam in je team wachten (`open_matches` met `team:`), en vergelijkbaar met
  een uitnodiging die in een groepsapp rondgaat. Een echte controle kan pas
  met een koppeling met toernooi.nl (T8, na 4.0).
- **Meekijken als tegenstander is niet gecontroleerd.** Wie de link van een
  SBN-wedstrijd kent (die is openbaar), kan met een account vragen of er een
  teamwedstrijd voor bestaat en die bekijken. Hij krijgt alleen wat de
  teampagina toont: teamnamen, voornamen en de stand, geen schrijfsleutel.
- **Iedereen met de schrijfsleutel kan elke partij schrijven**, zoals nu.
- **Namen en stand gaan naar de server zonder Live delen.** Dat is nieuw: nu
  gebeurt dat alleen als de maker Live delen aanzet. De regel bij de
  schakelaar zegt het, en de privacypagina moet het noemen.

## Wat niet meedoet

- Een teamwedstrijd die met de hand is ingetypt (geen `fixtureId`): die kan
  niemand vinden. Uitnodigen blijft dan de weg.
- Teamleden en tegenstanders zonder account of zonder Mijn team: uitnodiging
  of kijkerslink.
- Supporters: kijkerslink via Live delen, zoals nu.
- Het clubscherm: alleen met Live delen.

## Samenhang met andere 4.0-punten

- **T6** (melding als een teamgenoot een partij invult): met deze tabel weet
  de server ook wie er bij het team hoort. Een melding "Kees heeft de
  teamwedstrijd aangemaakt" kan later dezelfde route gebruiken, als 4.0 push
  voor accounts heeft. Niet in deze stap.
- **Voorstel teamwedstrijd eenvoudiger**, punt 2 (na Deelnemen direct de
  partijkeuze) en 3 (*Start teamwedstrijd* bij Mijn team): passen hier goed
  bij en maken het geheel korter. Ze hangen er niet van af.
- **Dubbele invoer** (voorstel spelersaccount, stap 5): die herkent al op
  team en partij. Wordt er minder vaak een tweede teamwedstrijd gemaakt, dan
  komen daar ook minder dubbele verzoeken binnen.

## Omvang

| Onderdeel | Omvang |
|---|---|
| Live-Worker: `clubScreen` in de kop, overslaan in `reportToClubs`/`leaveClubs`, apart tellen, tests (geen clubscherm, later aan, weer uit, oude app zonder veld) | S |
| Account-Worker: migratie `team_lives` en drie routes, met tests (aanmelden, gelijktijdig, vervangen, ander team krijgt geen sleutel, tegenstander alleen voor gevraagde wedstrijd, verlopen) | S |
| `AccountAPI` en `TeamLive`: de aanroepen; Core-logica "aanmaken of meedoen" met tests (bestaande rij werkt, rij is weg, 409) | M |
| UI: schakelaar bij aanmaken, Live delen op een bestaande sessie, kaarten "Meedoen?" en "Meekijken?" op Competitie en Mijn team | M |
| Handleiding, privacypagina, `ARCHITECTURE.md`, testdraaiboek 4.0 | S |

Achter dezelfde vlag als het account (`Features.shared.playerAccount`). De
live-Worker-wijziging is zonder die vlag onschadelijk (veld ontbreekt =
clubscherm zoals nu) en kan eerder mee.

## Testen

Met de testomgeving uit `docs/overdracht-4.0-spelersaccount.md`
(`squash-account-test`) en de test-live-Worker:

1. Twee testaccounts met dezelfde Mijn team. A maakt een teamwedstrijd uit het
   programma, Live delen uit. B ziet de kaart en doet mee; B's partij komt op
   A's telefoon na Vernieuwen.
2. De wedstrijd staat niet op het clubscherm. A zet Live delen aan: nu wel.
   A zet het uit: weg van het scherm, B kan nog steeds schrijven.
3. B tikt zelf op Nieuwe teamwedstrijd voor dezelfde wedstrijd: krijgt
   "Meedoen?", er komt geen tweede teamwedstrijd.
4. A en B maken tegelijk aan: één teamwedstrijd.
5. Een account van de tegenstander ziet "Meekijken?", opent de teampagina en
   kan niet schrijven (de app heeft geen sleutel; de server geeft hem niet).
6. Een account van een ander team, zonder deze wedstrijd in zijn programma,
   ziet niets.
7. A zet de schakelaar uit: de kaart verdwijnt bij B en de tegenstander.
8. Zonder account: alles zoals nu, uitnodiging werkt.

## Open vragen voor Gerd-Jan

1. **Tegenstander standaard laten meekijken?** Voorstel: ja, mee met de ene
   schakelaar "Zichtbaar voor mijn team". Of een tweede schakelaar
   "Tegenstander mag meekijken"?
2. **Mag de tegenstander ook schrijven?** Voorstel: nee. Zij houden hun kant
   bij in hun eigen teamwedstrijd, of vragen de uitnodiging. Twee teams in één
   sessie maakt "wie is onze speler" en de eigenaarssleutel ingewikkeld.
