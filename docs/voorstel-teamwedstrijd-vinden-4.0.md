# Teamwedstrijd vinden zonder uitnodiging (4.0)

Stand 6 november 2026. Voorstel, nog niets van gebouwd. Vraag van Gerd-Jan:
"Als ik een competitiewedstrijd aanmaak, kunnen teamleden die SquashAnalyzer
gebruiken die dan zien als ze dezelfde wedstrijd starten?" Nu niet, ook niet
in 4.0 zoals het gepland staat. Dit voorstel maakt het wel mogelijk, voor
teamleden met een spelersaccount.

Gebaseerd op de code van `main` op 6 november (commit `2b21c0b`).

## Hoe het nu werkt

- Een teamwedstrijd staat per telefoon in een JSON-bestand
  (`JSONFileTeamMatchStore`). Telefoons synchroniseren dat bestand niet.
- Live delen maakt op de live-Worker een `TeamSession` aan (`POST /api/team`,
  `server/live-worker/src/index.js`). Die krijgt een willekeurig id, een
  schrijfsleutel voor de uitnodiging en een eigenaarssleutel die op de
  telefoon van de starter blijft. De kop bevat alleen de twee teamnamen en de
  datum (`validateTeamHeader`), geen SBN-wedstrijd of team.
- Meedoen kan dus alleen met de uitnodiging (`TeamInvite`: `id.key` als link
  of code). Wie zelf "dezelfde" wedstrijd aanmaakt, krijgt een tweede, losse
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
  Beide teams zien dezelfde link; per team is hij eenduidig.

## Wat de gebruiker ziet

**Kees maakt de teamwedstrijd aan** (Competitie → Nieuwe teamwedstrijd → kiest
de wedstrijd uit het programma, of straks *Start teamwedstrijd* bij Mijn team)
en zet Live delen aan. Er verandert voor hem niets, behalve één regel onder
de schakelaar: "Teamleden met een account zien deze wedstrijd ook."

**Gerd-Jan opent op de speeldag de app.** Hij heeft een account en Mijn team
staat op hetzelfde team.

1. Onder *Competitie* (en op de Mijn team-kaart bij de wedstrijd van vandaag)
   staat: **"Kees heeft de wedstrijd tegen Bevo 3 gestart. Meedoen?"**
2. Hij tikt op *Meedoen*. De app doet wat een uitnodiging nu doet
   (`TeamInvite` → Deelnemen). De vraag "welk team is van jou" slaat hij
   over, want de app weet het uit Mijn team.
3. Daarna kiest hij zijn partij (E1–E4) en start de wedstrijd, zoals nu.

**Gerd-Jan tikt zelf op Nieuwe teamwedstrijd** voor dezelfde wedstrijd, zonder
de kaart te zien. De app vraagt dan eerst de server. Loopt er al een, dan
krijgt hij in plaats van een nieuwe: "Kees heeft deze wedstrijd al gestart.
Meedoen?" Er komt geen tweede teamwedstrijd.

**Zonder account of zonder Mijn team** werkt alles zoals nu: met de
uitnodiging. Die knop blijft er, ook voor wie wel een account heeft.

## Hoe het werkt

### Server: een wijzer in de account-Worker

De live-Worker verandert niet. De account-Worker (`squash-account`, D1 in de
EU) krijgt een kleine tabel die per team en SBN-wedstrijd zegt welke
live-teamwedstrijd erbij hoort:

```sql
-- A live team match that teammates can find (docs/voorstel-teamwedstrijd-vinden-4.0.md)
CREATE TABLE team_lives (
  team_key TEXT NOT NULL,        -- "<league uuid>/<team number>", as players.team_key
  fixture TEXT NOT NULL,         -- LeagueFixture.id: the SBN match link
  live_id TEXT NOT NULL,         -- TeamSession id on the live Worker
  write_key TEXT NOT NULL,       -- the key of the invitation (never the owner key)
  starter_id TEXT NOT NULL,      -- players.id of whoever registered it
  starter_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,   -- the match day plus a day; removed after that
  PRIMARY KEY (team_key, fixture)
);
```

Drie routes, alleen met een account, en altijd voor het eigen team
(`players.team_key` van de beller, niet een teamsleutel uit het verzoek):

| Route | Wat |
|---|---|
| `GET /api/v1/me/team/lives` | De lopende live-teamwedstrijden van mijn team: `fixture`, `liveId`, `writeKey`, `starterName`. Verlopen rijen telt hij niet mee |
| `PUT /api/v1/me/team/lives` `{ fixture, liveId, writeKey, replaces? }` | Aanmelden. Bestaat er al een rij voor deze wedstrijd, dan geeft hij die terug (409) en verandert hij niets. `replaces` met het `liveId` van de bestaande rij vervangt die: voor als de app zag dat die sessie weg is |
| `DELETE /api/v1/me/team/lives/:fixture` | Afmelden bij *Live stoppen*, alleen door wie hem aanmeldde |

Aanmelden is één `INSERT … ON CONFLICT DO NOTHING` met daarna een `SELECT`:
starten twee telefoons tegelijk, dan wint er één en krijgt de ander de
bestaande terug.

Opruimen gebeurt bij het lezen (`expires_at < nu` telt niet) en in de
dagelijkse taak, als de account-Worker die tegen die tijd heeft; anders met
een `DELETE … WHERE expires_at < ?` bij elke aanmelding.

### App

- **Starten.** Bij Live delen van een teamwedstrijd met `fixtureId`, een
  account en een teamsleutel: eerst `GET`. Is er voor deze wedstrijd al een
  rij, dan controleert de app die met `GET /api/team/:id/verify` op de
  live-Worker. Werkt hij, dan meedoen in plaats van starten. Is hij weg (404),
  dan zelf starten en aanmelden met `replaces`. Is er geen rij, dan starten
  zoals nu (`POST /api/team`) en daarna `PUT`. Krijgt de app dan 409, omdat
  iemand net eerder was, dan stopt hij zijn eigen nieuwe sessie met de
  eigenaarssleutel en doet hij mee met de andere.
- **Vinden.** Competitie en de Mijn team-kaart vragen `GET` op bij openen en
  bij *Vernieuwen*, alleen op de speeldag van een wedstrijd uit het programma
  (de app kent die datum al, net als `TeamMatchSupport.candidate`). Zo blijft
  het aantal verzoeken klein.
- **Meedoen.** Met `liveId` en `writeKey` maakt de app dezelfde
  `TeamInvite` als uit een link, en gebruikt dezelfde code. De teamkant
  (thuis/uit) volgt uit Mijn team, zodat de vraag "welk team is van jou"
  overbodig is.
- **Stoppen.** *Live stoppen* door de starter doet ook `DELETE`.

### Waarom de schrijfsleutel in de database mag

Het is dezelfde sleutel die nu al in de groepsapp gaat. De server geeft hem
alleen aan een account met dezelfde teamsleutel. De eigenaarssleutel (namen
wijzigen, stoppen) komt nooit op de server. De rij verdwijnt een dag na de
speeldag.

## Wat de server niet afdwingt

Dit moet in de documentatie en de privacytekst kloppen (AGENTS.md punt 7):

- **De teamsleutel is niet gecontroleerd.** Een account zet zijn eigen
  teamsleutel vanuit Mijn team (`PATCH /api/v1/me`). Wie een account maakt en
  Mijn team op jouw team zet, ziet dus jullie lopende teamwedstrijd en kan
  een partij schrijven. Dat is hetzelfde vertrouwen als bij de wedstrijden
  die op een naam in je team wachten (`open_matches` met `team:`), en
  vergelijkbaar met een uitnodiging die in een groepsapp rondgaat. Een echte
  controle kan pas met een koppeling met toernooi.nl (T8, na 4.0).
- **Iedereen met de schrijfsleutel kan elke partij schrijven**, zoals nu.
- Tegenstanders zien niets: hun teamsleutel is anders. Zij kunnen voor
  dezelfde wedstrijd hun eigen teamwedstrijd hebben, zoals nu.

## Wat niet meedoet

- Een teamwedstrijd die met de hand is ingetypt (geen `fixtureId`): die kan
  niemand vinden. Uitnodigen blijft dan de weg.
- Teamleden zonder account of zonder Mijn team: uitnodiging.
- Supporters: kijkerslink, zoals nu.

## Samenhang met andere 4.0-punten

- **T6** (melding als een teamgenoot een partij invult): met deze tabel weet
  de server ook wie er bij het team hoort. Een melding "Kees heeft de
  teamwedstrijd gestart" kan later dezelfde route gebruiken, als 4.0 push
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
| Migratie `team_lives` en drie routes in de account-Worker, met tests (aanmelden, gelijktijdig aanmelden, vervangen, ander team ziet niets, verlopen) | S |
| `AccountAPI`: drie aanroepen; Core-logica "starten of meedoen" met tests (bestaande rij werkt, rij is weg, 409) | M |
| UI: regel bij Live delen, kaart "… heeft gestart. Meedoen?" op Competitie en Mijn team, meedoen zonder teamvraag | M |
| Handleiding, privacypagina, `ARCHITECTURE.md`, testdraaiboek 4.0 | S |

Achter dezelfde vlag als het account (`Features.shared.playerAccount`).

## Testen

Met de testomgeving uit `docs/overdracht-4.0-spelersaccount.md`
(`squash-account-test`):

1. Twee testaccounts met dezelfde Mijn team. A maakt een teamwedstrijd uit het
   programma en zet Live delen aan. B ziet de kaart en doet mee; B's partij
   staat op de teampagina van A.
2. B tikt zelf op Nieuwe teamwedstrijd voor dezelfde wedstrijd: krijgt
   "Meedoen?", er komt geen tweede teampagina.
3. A en B zetten tegelijk Live delen aan: één teampagina.
4. A stopt live: B's kaart verdwijnt na Vernieuwen.
5. Een account met een ander team ziet niets.
6. Zonder account: alles zoals nu, uitnodiging werkt.

## Open vragen voor Gerd-Jan

1. **Standaard zichtbaar voor het team?** Voorstel: ja, met de regel onder de
   schakelaar. Of een eigen schakelaar "Zichtbaar voor mijn team"?
2. **Ook zonder Live delen?** Nu niet: zonder live is er geen gedeelde
   teamwedstrijd om bij aan te sluiten. Wil je dat aanmaken altijd live maakt
   voor het team, dan stuurt de app namen en stand naar de server zonder dat
   de maker dat aanzet.
3. **Hoe lang zichtbaar?** Voorstel: tot en met de dag na de speeldag, net zo
   lang als de teampagina zelf na de laatste update blijft staan.
