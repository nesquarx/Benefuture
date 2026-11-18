"""Sanity checks for the pseudocode (Bf_Pseudocode.txt).

Usage: python3 tools/check_pseudocode.py [--symbols-report-only]

Blocking checks (exit 1 on failure):
  1. Copy identity: spec/Bf_Pseudocode.txt, the root Bf_Pseudocode.txt and the block between
     <syntaxhighlight lang="haskell"> and </syntaxhighlight> in docs/articles/Benefuture.txt are identical.
  2. Line citations: tools/check_pseudocode_lines.py passes.
Symbol check (exit 1 on findings unless --symbols-report-only, which prints them and emits a GitHub
warning annotation instead):
  3. Every abbreviation used is designated somewhere in the pseudocode (author ruling 8.162: ordinary
     English words may appear undefined; ambiguous abbreviations must always be designated `Name«Abbr»`).

What counts as an abbreviation (deterministic, no system dictionary, so CI and local runs agree): a
capitalised identifier is split at `_` and then at camel-case boundaries (`TxLog` -> `Tx`, `Log`;
`IHzGatedPII` -> `I`, `Hz`, `Gated`, `PII`). A component is an ordinary word when it has at least five letters,
contains a lower-case vowel and is not all capitals, or when it is on SHORT_WORDS (an explicit list of ordinary
English words shorter than five letters). Every other component (`Re`, `CC`, `Wt`, `Estd`, `Rlv`, `Cx`, `X`) is
an abbreviation and is reported unless it is designated (see below) or on ALLOW. The rule is conservative: a
five-letter-plus abbreviation that looks like a word passes, and a short word missing from SHORT_WORDS is
reported (add it there). Lower-case tokens are never abbreviations here.

How definitions are found: `Name«Abbr»` defines both Name and Abbr; the head of the left side of `:=` and
`::` defines a symbol; a statement-initial `Name:` label and a `§Section` define a symbol. Subscripted and
composite forms (`Re_-ve`, `Ha_lt`, `Sy_{κ=2}`) are checked part by part, split at `_`.

What is checked as a use: capitalised identifiers and abbreviations (Latin, first letter upper case; also
`Δ`-prefixed ones with their base) and lower-case words directly applied as functions, `word(`. Other
lower-case words (adjectives, camelCase verbs such as `onExec`) are prose-like labels and not checked.
Reported, not guessed: a symbol is listed unless it is defined or on the allow-list below."""
from __future__ import annotations
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "spec" / "Bf_Pseudocode.txt"
ROOT_COPY = ROOT / "Bf_Pseudocode.txt"
ARTICLE = ROOT / "docs" / "articles" / "Benefuture.txt"
OPEN, CLOSE = '<syntaxhighlight lang="haskell">', "</syntaxhighlight>"

# Allow-list: common parlance and operators the pseudocode uses without defining them. The author rules
# what counts as common parlance; keep this short and add to it only on a ruling.
ALLOW = {
    # math operators and functions
    "max", "min", "sgn", "avg", "Avg", "argmax", "norm", "Norm", "logit", "find", "P", "Σ", "Π",
    # generic English verbs/nouns of Info and CRUD used as notation
    "Info", "CRUD", "True", "False",
    # units
    "Energy", "Matter",
    # URL and metadata fragments
    "URL",
    # author ruling 8.163 (2026-11-15): unambiguous or common parlance, used directly
    "X",      # bound variable of the sum at L31
    "Tech",   # technology
    "Eval",   # evaluate
    "Exec",   # execute
    "OptOut", "EQ", # opt out
    "PII",    # personally identifiable information
}
# Ordinary English words shorter than five letters that the pseudocode uses; see the docstring. Add a word
# only if it is an ordinary word, never an abbreviation.
SHORT_WORDS = {
    "Info", "Sub", "Type", "Map", "Fit", "Meta", "Bias", "Kind", "Open", "Self", "Top", "Cost", "Net", "Pay",
    "Bind", "Mono", "Auto", "Log", "Logs", "Tree", "Duty", "Once", "Per", "Base", "Vote", "Tie", "For", "Due", "Fork", "New",
    "Core", "Data", "Path", "Fact", "Deep", "Only", "Risk", "Fail", "Need", "Gain", "Fair", "Act", "Rule",
    "Out", "Tit", "Tat", "Min", "Max", "Fix", "Set", "Get", "Add", "Use", "Run", "Key", "Pool", "Test", "Goal",
    "Rate", "Rank", "Time", "Task", "Role", "Plan", "Mode", "Loss", "Gap", "Law", "Pact", "Name", "List",
}
CAMEL = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+")
GREEK = re.compile(r"^[Α-Ωα-ω]")

IDENT = re.compile(r"[A-Za-zΑ-Ωα-ω§][A-Za-z0-9Α-Ωα-ω]*")
DEF_ABBR = re.compile(r"([A-Za-z§][A-Za-z0-9_]*)«([^»]+)»")
DEF_LHS = re.compile(r"(?:^|[;,{(\s])(Δ?[A-Za-z§][A-Za-z0-9_]*)(?:_\{[^}]*\})?(?:\([^()]*\))?\s*:{1,2}=?\s", re.M)
DEF_LABEL = re.compile(r"^\s*([A-Za-z§][A-Za-z0-9_]*)\s*:\s*[{A-Za-z(]", re.M)


def parts(tok: str) -> list[str]:
    return [p for p in re.split(r"_", tok) if p]


def is_abbreviation(comp: str) -> bool:
    """True for a camel-case component that is not an ordinary word (see the module docstring)."""
    if comp in SHORT_WORDS or comp.isdigit():
        return False
    ordinary = len(comp) >= 5 and any(ch in "aeiouy" for ch in comp) and not comp.isupper()
    return not ordinary


def abbreviations_in(sym: str, defined: set[str]) -> list[str]:
    """Undesignated abbreviation components of an undefined symbol."""
    if not (sym[0].isupper() or sym[0] == "§"):
        return []
    comps = CAMEL.findall(re.sub(r"[ΑΩα-ω]", " ", sym.lstrip("§")))
    return [c for c in comps if is_abbreviation(c) and c not in defined]


def pseudo_block(text: str) -> str | None:
    a = text.find(OPEN)
    b = text.find(CLOSE, a + 1)
    if a < 0 or b < 0:
        return None
    return text[a + len(OPEN):b].strip("\n")


def check_copies() -> list[str]:
    errs = []
    spec = SPEC.read_text()
    if ROOT_COPY.read_text() != spec:
        errs.append("copy identity: Bf_Pseudocode.txt differs from spec/Bf_Pseudocode.txt")
    block = pseudo_block(ARTICLE.read_text())
    if block is None:
        errs.append(f"copy identity: no {OPEN} block in docs/articles/Benefuture.txt")
    elif block.strip("\n") != spec.strip("\n"):
        a, b = block.splitlines(), spec.splitlines()
        n = next((i for i in range(min(len(a), len(b))) if a[i] != b[i]), min(len(a), len(b)))
        errs.append(f"copy identity: docs/articles/Benefuture.txt block differs from spec/Bf_Pseudocode.txt "
                    f"(first difference at pseudocode line {n + 1})")
    return errs


def check_lines() -> list[str]:
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "check_pseudocode_lines.py")],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return ["line citations: " + l for l in (r.stdout + r.stderr).strip().splitlines()]
    return []


def definitions(lines: list[str]) -> set[str]:
    text = "\n".join(lines)
    defined = set()
    for name, abbr in DEF_ABBR.findall(text):
        defined.update(parts(name))
        defined.update(parts(abbr))
    for m in DEF_LHS.finditer(text):
        defined.update(parts(m.group(1).lstrip("Δ")))
    for m in DEF_LABEL.finditer(text):
        defined.update(parts(m.group(1)))
    return defined


def undefined_symbols(lines: list[str]) -> dict[str, list[int]]:
    defined = definitions(lines) | ALLOW
    found: dict[str, list[int]] = {}
    for n, line in enumerate(lines, 1):
        if "(http" in line:
            continue
        line = line.replace("\u0302", "")  # Ŝy is Sy with a hat
        for m in IDENT.finditer(line):
            tok = m.group()
            if GREEK.match(tok):
                continue
            prev = line[m.start() - 1:m.start()]
            if tok[0].isupper() or tok[0] == "§":
                cands = [p for p in parts(tok) if p[0].isupper() or p[0] == "§"]
            elif line[m.end():m.end() + 1] == "(" and tok.islower() and len(tok) > 2 and prev not in "_-":
                cands = [tok]
            else:
                continue
            for c in cands:
                if c not in defined and abbreviations_in(c, defined):
                    if n not in found.setdefault(c, []):
                        found[c].append(n)
    return {k: v for k, v in found.items() if v}


def main() -> int:
    report_only = "--symbols-report-only" in sys.argv
    blocking = check_copies() + check_lines()
    for e in blocking:
        print(f"::error::{e}" if report_only else e)
    lines = SPEC.read_text().splitlines()
    und = undefined_symbols(lines)
    if und:
        print(f"undesignated abbreviations ({len(und)}), symbol: pseudocode lines")
        for sym in sorted(und, key=lambda s: und[s][0]):
            print(f"  {sym}: " + ", ".join(f"L{n}" for n in und[sym]))
        if report_only:
            print(f"::warning::pseudocode: {len(und)} abbreviations used but never designated (report-only; "
                  f"see docs/BACKPROPAGATION.md)")
    else:
        print("all pseudocode abbreviations are designated")
    if blocking:
        return 1
    return 1 if (und and not report_only) else 0


if __name__ == "__main__":
    sys.exit(main())
