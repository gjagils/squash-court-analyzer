#!/bin/sh
# Project rules the compiler does not check (T23). Run locally or in CI:
#   scripts/lint.sh
# Exits 1 and lists the offending lines when a rule is broken.
cd "$(dirname "$0")/.." || exit 1
failed=0

report() {
    if [ -n "$2" ]; then
        echo "✗ $1"
        echo "$2" | sed 's/^/    /'
        failed=1
    else
        echo "✓ $1"
    fi
}

# 1. Shared screens draw icons through AppSymbol: Skip's Image(systemName:)
#    only knows a few SF Symbols and shows a warning triangle for the rest.
#    Apple-only code (#if os(iOS) && !SKIP, or the #else of #if SKIP) is fine.
hits=$(grep -rn 'Image(systemName:' Packages/SquashAnalyzerUI/Sources --include='*.swift' \
    | grep -v 'AppSymbol.swift' \
    | grep -v 'MatchResultOverlay.swift' \
    | grep -v 'HomeMenu.swift:.*icon.symbol')
report "Image(systemName:) only via AppSymbol in the shared UI" "$hits"

# 2. Colours come from SharedColors (docs/style/tokens.json), not loose values
hits=$(grep -rn 'Color(red:' Packages/SquashAnalyzerUI/Sources SquashAnalyzer --include='*.swift' \
    | grep -v 'SharedColors.swift')
report "Color(red:…) only in SharedColors" "$hits"
hits=$(grep -rnE '(Color)?\.(green|red|blue|yellow|orange|purple|pink)\b' Packages/SquashAnalyzerUI/Sources SquashAnalyzer --include='*.swift' \
    | grep -E 'Color\.(green|red|blue|yellow|orange|purple|pink)\b|(foregroundColor|fill|stroke|tint|background)\(\.(green|red|blue|yellow|orange|purple|pink)\b|[?:] \.(green|red|blue|yellow|orange|purple|pink)\b')
report "No system colours (.green, Color.red, …) outside SharedColors" "$hits"

# 2b. Fonts go through SharedFonts.system (one place for a later text-size step)
hits=$(grep -rn 'system(size:' Packages/SquashAnalyzerUI/Sources SquashAnalyzer --include='*.swift' \
    | grep -v 'SharedFonts.swift')
report "Fonts only via SharedFonts.system" "$hits"

# 3. No keypath literals in Core: Skip cannot transpile them (use closures)
hits=$(grep -rnE '\\\.[a-zA-Z]' Packages/SquashAnalyzerCore/Sources --include='*.swift' | grep -vE '^\S+:\s*//')
report "No keypath literals in SquashAnalyzerCore" "$hits"

# 4. No enum case named `out` in Core: a Kotlin keyword
hits=$(grep -rnE '^\s*case out\b' Packages/SquashAnalyzerCore/Sources --include='*.swift')
report "No enum case 'out' in SquashAnalyzerCore" "$hits"

# 5. iOS and Android carry the same version and build (scripts/version.py)
hits=$(python3 scripts/version.py check 2>&1)
report "iOS and Android versions agree" "$hits"
hits=$(python3 scripts/test_version.py 2>&1 | grep -E 'FAIL|ERROR')
report "Version scheme tests" "$hits"

exit $failed
