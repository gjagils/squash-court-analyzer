# Backlog Routine

Automatische verwerking van Linear-issues voor het Squash-court-analyzer project.

## Wat doet deze routine

1. **Log starttijd** (ISO-8601).
2. **Haal issues op** uit Linear-project `Squash-court-analyzer` met:
   - label: `claude-ready`
   - status: `Todo`
3. **Verwerk elk issue** op een eigen feature-branch (`claude/<branch-naam>`):
   - Maak de gevraagde codewijziging.
   - Commit met bericht `<titel> (<issue-id>)`.
   - Push naar origin.
   - Zet issue-status naar `In Progress` bij start, `Done` bij voltooiing.
4. **Log eindtijd, duur en samenvatting** van alle verwerkte issues.
5. **Ruim lege branches op**: verwijder remote branches die geen unieke commits ten opzichte van `main` bevatten.

## Uitvoering

```
Starttijd : <ISO-tijdstip>
Issues gevonden: <n>

[Per issue]
- <issue-id> "<titel>" → branch <branchnaam> → status Done ✓

Eindtijd  : <ISO-tijdstip>
Duur      : <mm:ss>
Samenvatting: <n> issue(s) verwerkt, <m> branch(es) opgeruimd.
```

## Criteria lege branch

Een branch is "leeg" als `git log --oneline main..<branch>` geen resultaten geeft
én de branch niet de actieve werkbranch is.

## Opmerkingen

- Voer nooit een force-push uit.
- Maak altijd een nieuwe commit; gebruik geen `--amend`.
- Controleer na push of de CI groen is voordat het issue op Done wordt gezet.
