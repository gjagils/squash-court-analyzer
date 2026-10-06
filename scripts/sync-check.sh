#!/bin/sh
# Check at the START and at the END of every session (AGENTS.md, "Werken zonder
# elkaar in de weg te zitten"): is this checkout up to date with origin/main, is
# anything left uncommitted, and are there branches or worktrees with work that
# is not on main? Prints what to do; exits 1 when something needs attention.
#   scripts/sync-check.sh
cd "$(dirname "$0")/.." || exit 1
git fetch -q --prune origin || { echo "✗ git fetch lukte niet (geen verbinding?)"; exit 1; }
problem=0
branch=$(git branch --show-current)
behind=$(git rev-list --count HEAD..origin/main)
ahead=$(git rev-list --count origin/main..HEAD)
dirty=$(git status --porcelain --untracked-files=no | wc -l | tr -d ' ')

echo "Branch: ${branch:-(losgekoppeld)}  ·  $ahead commit(s) voor en $behind achter op origin/main  ·  $dirty gewijzigde bestand(en)"

if [ "$behind" -gt 0 ]; then
    echo "✗ Je loopt $behind commit(s) achter op origin/main."
    if [ "$dirty" -gt 0 ]; then
        echo "    Er staan ook niet-gecommitte wijzigingen: eerst committen (of vragen van wie ze zijn),"
        echo "    dan 'git pull --rebase origin main'. Begin niet te bewerken op een verouderde basis."
    else
        echo "    Doe: git pull --rebase origin main"
    fi
    problem=1
fi
if [ "$dirty" -gt 0 ] && [ "$behind" -eq 0 ]; then
    echo "! Niet-gecommitte wijzigingen. Aan het einde van een sessie hoort hier niets te staan:"
    echo "    commit klein en push direct: git pull --rebase origin main && git push origin HEAD:main"
    problem=1
fi
if [ "$ahead" -gt 0 ] && [ "$branch" = "main" ]; then
    echo "! Lokale main loopt $ahead commit(s) voor: git push origin HEAD:main"
    problem=1
fi

# Remote branches other than main: leftovers, or someone's unmerged work
for ref in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -E '^origin$|^origin/(HEAD|main)$'); do
    unique=$(git rev-list --count origin/main.."$ref")
    if [ "$unique" -eq 0 ]; then
        echo "! $ref is leeg (alles staat in main): verwijderen met git push origin --delete ${ref#origin/}"
    else
        echo "! $ref heeft $unique commit(s) die niet in main staan: niet verwijderen, vraag Gerd-Jan"
    fi
    problem=1
done

# Other worktrees with uncommitted changes (someone else's session): do not touch
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r tree; do
    [ "$tree" = "$(pwd)" ] && continue
    n=$(git -C "$tree" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && echo "! $tree heeft $n niet-gecommitte wijziging(en) van een andere sessie: niet aanraken"
done

[ "$problem" -eq 0 ] && echo "✓ Alles is bij en gecommit."
exit $problem
