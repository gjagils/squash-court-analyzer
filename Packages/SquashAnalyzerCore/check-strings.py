#!/usr/bin/env python3
"""Checks the English texts of SquashAnalyzerCore (docs/i18n.md).

Every L10n.text("…") key in Sources must have an entry in
Resources/en.lproj/Localizable.strings with the same number of %@
placeholders; entries nobody uses any more are listed too.
    python3 Packages/SquashAnalyzerCore/check-strings.py
Exits 1 when something is missing or wrong."""
import glob, os, re, sys

root = os.path.dirname(os.path.abspath(__file__))
sources = os.path.join(root, "Sources", "SquashAnalyzerCore")
table_path = os.path.join(sources, "Resources", "en.lproj", "Localizable.strings")

def unescape(text):
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")

used = {}
for path in glob.glob(os.path.join(sources, "*.swift")):
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.strip().startswith("//"):
            continue
        for match in re.finditer(r'L10n\.text\("((?:[^"\\]|\\.)*)"', line):
            used.setdefault(unescape(match.group(1)), f"{os.path.basename(path)}:{number}")
        # L10n.text(rawValue): the raw values of these enums are keys too
for name, enum in [("BadgeEngine.swift", "Category"), ("CourtZone.swift", "CourtZone"), ("PlayerProfile.swift", "CoachingFocusTag")]:
    text = open(os.path.join(sources, name), encoding="utf-8").read()
    body = text[text.index(f"enum {enum}"):]
    body = body[:body.index("\n}") if enum != "Category" else body.index("\n    }")]
    for raw in re.findall(r'case \w+ = "([^"]+)"', body):
        used.setdefault(raw, f"{name} ({enum})")

table = {}
content = open(table_path, encoding="utf-8").read()
content = re.sub(r"/\*.*?\*/", "", content, flags=re.S)
for match in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', content):
    key, value = unescape(match.group(1)), unescape(match.group(2))
    if key in table:
        print(f"twice in the table: {key!r}")
    table[key] = value

def placeholders(text):
    return len(re.findall(r"%(?:\d+\$)?@", text))

problems = 0
# Keys that are the same in English need no entry
same_in_english = {"Backhand", "Serve", "Volley", "Drop", "Boast"}
for key, where in sorted(used.items(), key=lambda item: item[1]):
    if key in same_in_english:
        continue
    if key not in table:
        print(f"no English for {key!r} ({where})")
        problems += 1
    elif placeholders(key) != placeholders(table[key]):
        print(f"placeholders differ for {key!r}: {table[key]!r}")
        problems += 1
for key in sorted(set(table) - set(used)):
    print(f"unused in the table: {key!r}")
print(f"{len(used)} keys in the code, {len(table)} English texts, {problems} problem(s)")
sys.exit(1 if problems else 0)
