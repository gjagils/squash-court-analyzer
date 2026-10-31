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

## Voor de eerste uitrol (Gerd-Jan)

1. Database in de EU aanmaken (de jurisdictie kan alleen bij het aanmaken):
   `npx wrangler d1 create squash-account --jurisdiction eu`, en het
   `database_id` in `wrangler.toml` zetten.
2. Migraties: `npx wrangler d1 migrations apply squash-account --remote`.
3. Een route kiezen (bijv. `account.squashanalyzer.com`) en `wrangler deploy`.

## Nog niet gebouwd

- Herinnering na 7 dagen (vraagt push, zoals de livemeldingen).
- Dubbele wedstrijden aanbieden als één keuze (team-id + partij eerst).
- Het Apple-token intrekken gebeurt in de app vóór `DELETE /api/v1/me` (gebouwd in Core:
  `FirebaseAuthREST.revokeAppleToken`, nog niet getest met een echt Apple-account).
- Verwijderformulier op de website (aanvraag per mail).
- Wedstrijdgegevens naar R2 bij een grote database (D1 max. 10 GB).
