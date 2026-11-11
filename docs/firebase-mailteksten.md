# Firebase-mails van het spelersaccount (4.0)

Voor Gerd-Jan, 10 november 2026. Firebase stuurt de mails voor het bevestigen van je
e-mailadres en het kiezen van een nieuw wachtwoord. Standaard komen die van
"squash-analyzer-18fb3", in u-vorm, met een link naar firebaseapp.com. Zo maak je ze
netjes. De instellingen staan in de Firebase Console van project `squash-analyzer-18fb3`;
die doe jij (of Claude via Chrome, met akkoord per stap).

## 1. Openbare naam (Projectinstellingen → Algemeen)

- **Openbare naam:** `SquashAnalyzer`

Die naam komt overal waar Firebase `%APP_NAME%` gebruikt, ook in "Team ...".

## 2. Eigen bevestigingspagina (Authentication → Templates)

Bij elk template op het potloodje → **Actie-URL aanpassen**:

    https://squashanalyzer.com/account/

Het geldt voor alle templates tegelijk. De pagina (`website/account/index.html`) bevestigt
het adres, laat een nieuw wachtwoord kiezen of zet een gewijzigd adres terug, in het
Nederlands of Engels (de `lang` uit de link). Ze praat rechtstreeks met Firebase en stuurt
niets naar onze eigen servers. Zolang de actie-URL niet is aangepast, gebruikt Firebase zijn
eigen pagina; de nieuwe pagina staat er dan los naast.

## 3. Afzender (Authentication → Templates, per template)

- **Naam afzender:** `SquashAnalyzer`
- **Van:** `noreply` @ eigen domein, zie stap 4 (tot die tijd blijft het
  `noreply@squash-analyzer-18fb3.firebaseapp.com`)
- **Beantwoorden naar:** `info@squashanalyzer.com`

## 4. Eigen domein voor de afzender (optioneel)

Templates → **Domein aanpassen** → `squashanalyzer.com`. Firebase geeft een paar DNS-records
(TXT en CNAME); die zet jij in Cloudflare. Na de controle (kan een paar uur duren) komt de
mail van `noreply@squashanalyzer.com` en belandt hij minder snel in spam.

## 5. Teksten

Firebase kiest de taal van het template met de taal die de app meestuurt, maar een
aangepaste tekst geldt voor alle talen. Daarom staan Nederlands en Engels in één mail,
Nederlands eerst. Plak de HTML in het tekstvak van het template.

### E-mailadres bevestigen

**Onderwerp:** `Bevestig je e-mailadres · Confirm your email address`

```html
<p>Hoi %DISPLAY_NAME%,</p>
<p>Fijn dat je een account hebt gemaakt bij SquashAnalyzer. Tik op de link hieronder om je e-mailadres te bevestigen.</p>
<p><a href="%LINK%">Bevestig mijn e-mailadres</a></p>
<p>Heb jij geen account gemaakt? Dan kun je deze mail negeren.</p>
<p>Groeten,<br>SquashAnalyzer</p>
<hr>
<p>Hi %DISPLAY_NAME%,</p>
<p>Thanks for creating a SquashAnalyzer account. Tap the link below to confirm your email address.</p>
<p><a href="%LINK%">Confirm my email address</a></p>
<p>Didn't create an account? You can ignore this email.</p>
<p>Cheers,<br>SquashAnalyzer</p>
```

### Wachtwoord opnieuw instellen

**Onderwerp:** `Kies een nieuw wachtwoord · Choose a new password`

```html
<p>Hoi %DISPLAY_NAME%,</p>
<p>Je hebt gevraagd om een nieuw wachtwoord voor je SquashAnalyzer-account (%EMAIL%). Tik op de link hieronder om er een te kiezen.</p>
<p><a href="%LINK%">Kies een nieuw wachtwoord</a></p>
<p>Heb je dit niet zelf gevraagd? Dan kun je deze mail negeren; je wachtwoord blijft hetzelfde.</p>
<p>Groeten,<br>SquashAnalyzer</p>
<hr>
<p>Hi %DISPLAY_NAME%,</p>
<p>You asked for a new password for your SquashAnalyzer account (%EMAIL%). Tap the link below to choose one.</p>
<p><a href="%LINK%">Choose a new password</a></p>
<p>Didn't ask for this? You can ignore this email; your password stays the same.</p>
<p>Cheers,<br>SquashAnalyzer</p>
```

### E-mailadres gewijzigd

Firebase laat bij dit template (en bij "Verificatie van e-mailadreswijziging") de tekst
mogelijk niet aanpassen, alleen afzender en onderwerp. Kan het wel:

**Onderwerp:** `Je e-mailadres is gewijzigd · Your email address was changed`

```html
<p>Hoi %DISPLAY_NAME%,</p>
<p>Het e-mailadres van je SquashAnalyzer-account is gewijzigd naar %NEW_EMAIL%.</p>
<p>Heb je dit niet zelf gedaan? <a href="%LINK%">Zet je oude adres terug</a> en kies daarna een nieuw wachtwoord.</p>
<p>Groeten,<br>SquashAnalyzer</p>
<hr>
<p>Hi %DISPLAY_NAME%,</p>
<p>The email address of your SquashAnalyzer account was changed to %NEW_EMAIL%.</p>
<p>Didn't do this yourself? <a href="%LINK%">Restore your old address</a> and then choose a new password.</p>
<p>Cheers,<br>SquashAnalyzer</p>
```

`%DISPLAY_NAME%` is leeg als het account geen naam bij Firebase heeft; dan staat er
"Hoi ,". Zie je dat in de testmail, vervang dan `Hoi %DISPLAY_NAME%,` door `Hoi,` en
`Hi %DISPLAY_NAME%,` door `Hi,`.

## 6. Controleren

Maak in de app een testaccount (bijvoorbeeld `satest+mail@gerdjan.nl`), kijk naar de mail
en tik op de link: de pagina op squashanalyzer.com/account/ moet "Je e-mailadres is
bevestigd" tonen. Daarna in de app *Wachtwoord vergeten* en een nieuw wachtwoord kiezen.
Testaccount verwijderen in de app.

## 7. Alternatief: zelf versturen via Cirrux (antwoord Cirrux, 11 november 2026)

Firebase blijft template-wijzigingen weigeren. Dan versturen we de drie mails zelf. Cirrux
vindt dat prima: transactionele mail (bevestigen, wachtwoord-reset) is waar het voor bedoeld
is, nieuwsbrieven en bulk niet.

Wat Cirrux biedt:

- **HTTP-API** (handigst vanuit de account-Worker): in admin.cirrux.co onder *API keys* een
  key met `email.read`, `email.write` en `email.send`, beperkt tot één mailbox. Versturen gaat
  in twee calls: een concept maken (`from: noreply@squashanalyzer.com`) en dat concept
  versturen. `GET /v1/mailboxes` geeft de uuid van de mailbox. Voorbeeld:
  https://cirrux.co/help/questions/transactional-mail-from-my-app
- **SMTP**: smtp.cirrux.co, poort 465 (SSL) of 587 (STARTTLS), inloggen met een
  app-wachtwoord (Cirrux Mail → Instellingen → Mailboxen → Wachtwoorden).
- **Afzender zonder eigen postvak**: `noreply@squashanalyzer.com` als alias op een bestaande
  mailbox (admin.cirrux.co → mailbox → *Create address*). Domein moet geverifieerd zijn en
  DKIM moet kloppen.
- **Limieten**: 100 per uur en 500 per dag per mailbox; 500 per uur en 2.000 per dag per
  workspace. Ruim genoeg.
- **Bounces en antwoorden** komen in de inbox van de mailbox achter de alias; eventueel een
  filter erop. Via de API staat elke mail ook in *Verzonden*, via SMTP niet. Een send-only
  API-call zonder kopie in Verzonden bestaat nog niet (Gerd-Jan wil die wel, als
  Cirrux-wens).

Wat er dan in de app en Worker verandert:

1. De account-Worker krijgt een Firebase-serviceaccount (secret) en vraagt de actielink op via
   Identity Toolkit `accounts:sendOobCode` met `returnOobLink: true`. Firebase verstuurt dan
   zelf niets.
2. De Worker zet de link om naar `https://www.squashanalyzer.com/account/?mode=…&oobCode=…`
   (de pagina bestaat al), vult de nl/en-tekst uit sectie 5 in en verstuurt via de Cirrux-API.
   Secrets: `CIRRUX_API_KEY`, `CIRRUX_MAILBOX`.
3. De app roept voor *bevestigen* en *wachtwoord vergeten* de Worker aan in plaats van
   Firebase `sendOobCode`. Ratelimit per adres in de Worker.
4. *E-mailadres gewijzigd* (recoverEmail) stuurt Firebase zelf bij een adreswijziging; die
   blijft op de standaardtekst tot de templates wel te bewerken zijn, of we zetten
   adres wijzigen ook via de Worker.

Inschatting: Worker en tests ongeveer een uur werk, app-kant een half uur, plus een testbuild.
