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

## Voor de eerste uitrol (Gerd-Jan)

1. Database in de EU aanmaken (de jurisdictie kan alleen bij het aanmaken):
   `npx wrangler d1 create squash-account --jurisdiction eu`, en het
   `database_id` in `wrangler.toml` zetten.
2. Migraties: `npx wrangler d1 migrations apply squash-account --remote`.
3. Een route kiezen (bijv. `account.squashanalyzer.com`) en `wrangler deploy`.

## Nog niet gebouwd

- Herinnering na 7 dagen (vraagt push, zoals de livemeldingen).
- Dubbele wedstrijden aanbieden als één keuze (team-id + partij eerst).
- Het Apple-token intrekken gebeurt in de app vóór `DELETE /api/v1/me`.
- Verwijderformulier op de website (aanvraag per mail).
- Wedstrijdgegevens naar R2 bij een grote database (D1 max. 10 GB).
