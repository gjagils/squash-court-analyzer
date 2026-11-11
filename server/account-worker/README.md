# Account-Worker (4.0, nog niet uitgerold)

Het spelersaccount uit [het voorstel](../../docs/voorstel-spelersaccount-4.0.md):
een Cloudflare Worker met een D1-database in de EU. De app praat er alleen mee
in 4.0-testbuilds (`Features.shared.playerAccount`, zie het
[releaseplan](../../docs/releaseplan-3x-4.0.md)).

## Testen

```bash
npm ci
npm test
```

De tests draaien met een lokale D1 (de migraties uit `migrations/`) en een
wegwerpsleutel in plaats van die van Google; ze tekenen hun eigen
Firebase-tokens (`vitest.config.js`, `test/helpers.js`).

## Lokaal testen met de app

```bash
npm run local
```

Dit start een stand-in voor Firebase Authentication op `http://localhost:9099` (dezelfde paden
als de Firebase-emulator, maar met echt getekende RS256-tokens) en `wrangler dev` op
`http://localhost:8787` met een lokale D1. De publieke sleutel van de stand-in komt in
`.dev.vars` (`TEST_FIREBASE_JWKS`); gebruikers en sleutel staan in `dev/.local`. Beide staan
buiten git. Mails worden niet verstuurd, alleen gelogd.

Een 4.0-debugbuild die deze opstelling gebruikt:

- iOS-simulator: `xcodebuild … SQUASH_PLAYER_ACCOUNT=YES SQUASH_ACCOUNT_SERVER=local`
- Android-emulator: `./gradlew assembleDebug -PsquashPlayerAccount=true -PsquashAccountServer=local`
  (de emulator ziet de Mac als `10.0.2.2`; een telefoon op hetzelfde netwerk:
  `-PsquashAccountServer=local:<ip van de Mac>`)

Een wedstrijd in een postvak leggen zoals een coach dat doet:
`node dev/send-match.mjs <spelerscode> [naam afzender]`.

## Testomgeving

Een tweede Worker met een eigen database, zodat testen nooit data in de echte
zet: `squash-account-test` op `test-account.squashanalyzer.com` (`[env.test]` in
`wrangler.toml`). 4.0-testbuilds wijzen erheen met `SQUASH_ACCOUNT_SERVER=test`
(iOS) of `-PsquashAccountServer=test` (Android). Zelfde Firebase-project.

- Eenmalig: `npx wrangler d1 create squash-account-test --jurisdiction eu`, het
  `database_id` in `[[env.test.d1_databases]]`.
- Uitrollen (migraties en Worker): `npm run deploy-test`.
- Leegmaken: `npm run reset-test` (vraagt eerst; alleen de testdatabase).
- Nep-coach: `node dev/send-match.mjs --test …` (zie de kop van het script).

Het draaiboek staat in `docs/testplan-4.0-koppelen.md`.

## Voor de eerste uitrol (Gerd-Jan)

1. Database in de EU aanmaken: gedaan op 1 november 2026
   (`npx wrangler d1 create squash-account --jurisdiction eu`, regio EEUR);
   het `database_id` staat in `wrangler.toml`.
2. Migraties: `npx wrangler d1 migrations apply squash-account --remote`.
3. `npx wrangler deploy`. De route `account.squashanalyzer.com` (eigen
   domein) staat in `wrangler.toml`; Cloudflare maakt het DNS-record zelf.
   CI rolt deze Worker niet uit, alleen de tests draaien daar.

## Accountmails (via Cirrux)

Bevestigen, wachtwoord vergeten en e-mailadres wijzigen verstuurt de Worker zelf
(`src/mail.js`). Daarvoor zijn drie secrets per omgeving nodig:
`FIREBASE_SERVICE_ACCOUNT`, `CIRRUX_API_KEY` en `CIRRUX_MAILBOX`. Zonder die secrets
antwoorden de mailroutes 503 en laat de app Firebase versturen. De stappen staan in
[docs/firebase-mailteksten.md](../../docs/firebase-mailteksten.md), sectie 7.

## Nog niet gebouwd

- Herinnering na 7 dagen (vraagt push, zoals de livemeldingen).
- Dubbele wedstrijden aanbieden als één keuze (team-id + partij eerst).
- Het Apple-token intrekken gebeurt in de app vóór `DELETE /api/v1/me` (gebouwd in Core:
  `FirebaseAuthREST.revokeAppleToken`, nog niet getest met een echt Apple-account).
- Verwijderformulier op de website (aanvraag per mail).
- Wedstrijdgegevens naar R2 bij een grote database (D1 max. 10 GB).
