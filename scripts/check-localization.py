#!/usr/bin/env python3
r"""Checks the String Catalogs against the code. Run after every catalog change.

Four checks, in the order the mistakes actually happened:

1. COMPLETENESS — every localizable call site in the code has a catalog key.
   A missing key does not fail the build and does not look broken in English;
   it silently shows the English source text to a German reader. Four such gaps
   shipped past four eyes on 07.08.2026, one of them a pure quotation-mark
   mismatch (straight " against typographic “ ”).

2. TRANSLATION — every key carries both `en` and `de` in state `translated`.

3. PLURALS — every key interpolating a count either carries plural variations
   or stands on the exemption list below with a reason. This is the check that
   was missing on 07.08.2026: five keys lost the plural rules that
   `GermanPlural` used to enforce, and "1 Aufgaben" reappeared — the same
   defect class already fixed once in July 2026.

4. NO STRAY GERMAN — no German text in a Swift string literal. Check 1 only
   sees text that *asked* to be localized; a literal that never went through
   `String(localized:)` is invisible to it. On 09.08.2026 the overflow dialog
   built its title in code as "\(lane): \(count) von \(limit)", so English
   readers were shown "In Progress: 4 von 3" while this script reported all
   clear. The source language is English, so any German in a literal is either
   a leak or belongs in the catalog. Comments are skipped — this project quotes
   German UI text in its reasoning on purpose.

Usage: python3 scripts/check-localization.py
Exit code 0 = clean, 1 = problems found.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "GlassKanban" / "Localizable.xcstrings"
SOURCES = sorted((ROOT / "GlassKanban").glob("*.swift"))
LANGUAGES = ("en", "de")

# Keys that interpolate a count but need no plural rule. Each needs a reason —
# "it reads fine" is one, "the number can never be 1" is the stronger one.
PLURAL_EXEMPT = {
    "%lld days to the record": "gap == 1 has its own key, so this starts at 2",
    "%lld done today": "'1 done today' reads correctly",
    "%lld not yet due": "'1 not yet due' reads correctly",
    "%lld of them not yet due": "'1 of them not yet due' reads correctly",
    "%lld of %lld": "bare ratio, no noun to inflect",
    "%lld of %lld cards": "the noun follows the limit, which is never 1 in practice",
    "Board is filtered — %lld active (⌘F)": "no noun to inflect",
    "In this column for %lld days": "only shown from agingThresholdDays (3) upwards",
    "Last %lld Days": "fixed window, WrappedStats.trendWindowDays == 30",
    "Last %lld days: something done on %lld of them": "window is fixed at 30; the second count is phrased to be number-neutral in both languages",
    "Little's Law: tasks in progress divided by your pace over the last %lld days — an estimate, not a promise": "fixed 30-day window",
    "Median time from “Captured” to “Done” for one-off tasks over the last %lld days — with load and pace, the third figure in Little's Law": "fixed 30-day window",
    "Milestone reached: %lld tasks done": "milestones are 50, 100, 250 … never 1",
    "Milestone reached: %lld": "milestones are 50, 100, 250 … never 1",
    "Recurring tasks whose next due date hasn't arrived yet rest behind the fold at the bottom of the Backlog — one click brings them forward, nothing is ever hidden for good. Beyond %lld cards, the rest folds regardless.": "fixed BacklogFold.collapsedLimit (15)",
    "Show %lld more": "'Show 1 more' reads correctly; German inherited from before the localization",
    "Show %lld older": "'Show 1 older' reads correctly; German inherited from before the localization",
    "Your limit: %lld": "bare number, no noun to inflect",
    "Your throughput: tasks completed per week, averaged over the last %lld days — the pace in Little's Law": "fixed 30-day window",
}

# German in a Swift literal, by its own letters or by function words that no
# English word shares. Deliberately conservative: a missed leak costs one more
# round, a false alarm costs trust in the check.
GERMAN = re.compile(
    r"[äöüÄÖÜß]|\b(?:von|und|nicht|kein|keine|keinen|dein|deine|deinem|deinen|"
    r"noch|mehr|weniger|oder|aber|auch|wenn|dann|durch|gegen|ohne|zwischen|"
    r"wird|wurde|werden|gerade|schon|immer|etwas|nichts|alles|jede|jeder|"
    r"das|der|ein|eine|einen|ist|sind)\b",
    re.IGNORECASE)

# Call sites that resolve through the catalog.
CALL_SITE = re.compile(
    r"(?:String\(localized:\s*|Text\(|Button\(|Label\(|TextField\(|Toggle\(|Section\(|Menu\(|"
    r"CommandMenu\(|DatePicker\(|Picker\(|\.help\(|\.accessibilityLabel\(|fieldCaption\(|"
    r"factRow\(|emptyValue\(|sectionHeading\(|row\(|filterRow\()"
    r'"((?:[^"\\]|\\.)*)"'
)

# Literals that are structural rather than copy: a bare value, or two Text runs
# composed for styling (CardView's priority marks in front of the title).
NOT_COPY = {"{}", "{} {}"}


def normalise(text):
    """Collapse Swift interpolations and %-specifiers to one marker, so a call
    site and its catalog key compare equal."""
    out, i = [], 0
    while i < len(text):
        if text.startswith("\\(", i):
            depth, i = 1, i + 2
            while i < len(text) and depth:
                if text[i] == "(":
                    depth += 1
                elif text[i] == ")":
                    depth -= 1
                i += 1
            out.append("{}")
        else:
            out.append(text[i])
            i += 1
    return re.sub(r"%lld|%@", "{}", "".join(out))


def code_literals(text):
    """Every string literal that reaches the compiler, with its line number.
    Runs a small scanner rather than a regex because the two have to be told
    apart both ways: a `//` inside a string does not start a comment, and a
    quote inside a comment does not start a string."""
    in_block = False
    for number, line in enumerate(text.splitlines(), 1):
        index, in_string, buffer, found = 0, False, [], []
        while index < len(line):
            pair = line[index:index + 2]
            if in_block:
                in_block, index = (False, index + 2) if pair == "*/" else (True, index + 1)
                continue
            if in_string:
                if line[index] == "\\":
                    buffer.append(line[index:index + 2])
                    index += 2
                elif line[index] == '"':
                    found.append("".join(buffer))
                    buffer, in_string, index = [], False, index + 1
                else:
                    buffer.append(line[index])
                    index += 1
                continue
            if pair == "//":
                break
            if pair == "/*":
                in_block, index = True, index + 2
                continue
            in_string, index = (True, index + 1) if line[index] == '"' else (in_string, index + 1)
        for literal in found:
            yield number, literal


def main():
    catalog = json.loads(CATALOG.read_text())["strings"]
    problems = []

    # 1 — completeness
    known = {normalise(key) for key in catalog}
    for path in SOURCES:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for match in CALL_SITE.finditer(line):
                literal = match.group(1)
                shape = normalise(literal)
                if not literal.strip() or shape in NOT_COPY:
                    continue
                if shape not in known:
                    problems.append(
                        f"missing key: {literal!r}  ({path.name}:{number})")

    # 2 — both languages translated
    for key, entry in catalog.items():
        localizations = entry.get("localizations", {})
        for language in LANGUAGES:
            unit = localizations.get(language)
            if unit is None:
                problems.append(f"missing {language}: {key!r}")
                continue
            if "stringUnit" in unit:
                state = unit["stringUnit"].get("state")
                if state != "translated":
                    problems.append(f"{language} is {state}: {key!r}")
            elif "variations" in unit:
                for form, sub in unit["variations"]["plural"].items():
                    state = sub["stringUnit"].get("state")
                    if state != "translated":
                        problems.append(f"{language}/{form} is {state}: {key!r}")
            else:
                problems.append(f"{language} has neither text nor variations: {key!r}")

    # 3 — plurals
    for key, entry in catalog.items():
        if "%lld" not in key or key in PLURAL_EXEMPT:
            continue
        for language in LANGUAGES:
            unit = entry.get("localizations", {}).get(language, {})
            if "variations" not in unit:
                problems.append(
                    f"counts but has no plural rule ({language}): {key!r}\n"
                    f"      add variations.plural, or list it in PLURAL_EXEMPT with a reason")

    # 4 — no German that never asked to be localized
    for path in SOURCES:
        for number, literal in code_literals(path.read_text()):
            if GERMAN.search(literal):
                problems.append(
                    f"German in a raw literal: {literal!r}  ({path.name}:{number})\n"
                    f"      route it through String(localized:) and add the key")

    stale = sorted(set(PLURAL_EXEMPT) - set(catalog))
    for key in stale:
        problems.append(f"exemption no longer matches any key: {key!r}")

    if problems:
        print(f"✗ {len(problems)} problem(s):\n")
        for problem in problems:
            print(f"   - {problem}")
        return 1

    print(f"✓ {len(catalog)} keys — complete, translated in {'/'.join(LANGUAGES)}, "
          f"plurals accounted for, no stray German")
    return 0


if __name__ == "__main__":
    sys.exit(main())
