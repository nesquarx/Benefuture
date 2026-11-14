"""Check that every Bf_Pseudocode.txt line citation (e.g. `AdvAp, L161`, `L151 Harm_Intv`, or
audit table rows) resolves to the term it names on that line of `spec/Bf_Pseudocode.txt`.
Usage: python3 tools/check_pseudocode_lines.py (exit status 1 on any mismatch)."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC_PATH = ROOT / "spec" / "Bf_Pseudocode.txt"
SPEC_LINES = SPEC_PATH.read_text().splitlines()

# Canonical pseudocode terms and unambiguous prose/code aliases -> substring(s) expected on the cited spec line.
TERM_MARKERS = {
    "§Sets": ("§Sets",),
    "§Defs": ("§Defs",),
    "§Af_Axioms": ("§Af_Axioms",),
    "Params": ("Params«Pm»",),
    "Synergy": ("Synergy«Sy»",),
    "Reality": ("Reality«ℝ»",),
    "Domain": ("Domain«Dn»",),
    "Sentience": ("Sentience«St»",),
    "Threshold": ("Threshold«Th»",),
    "PrAcc": ("PrAcc(",),
    "CausalExplanation": ("CausalExplanation«CE»",),
    "Understanding": ("Understanding«U»",),
    "Sapience": ("Sapience«Sp»",),
    "LongTerm": ("LongTerm«lt»",),
    "Diversity": ("Diversity«Di»", "Di_N_Balance"),
    "Novelty": ("Novelty«N»",),
    "Happiness": ("Happiness«H»",),
    "Ignorance": ("Ignorance«Ig»",),
    "Truth": ("Truth«Tr»",),
    "Measurement": ("Measurement«Me»",),
    "Assess": ("Assess«As»",),
    "Assessment": ("Assess«As»",),
    "MetricMl": ("MetricMl«MM»",),
    "CorrSc": ("CorrSc(",),
    "Harm": ("Harm«Ha»",),
    "NHa": ("NecessaryHa«NHa»",),
    "NecessaryHa": ("NecessaryHa«NHa»",),
    "Priorities": ("Priorities:",),
    "Goal": ("Goal«G»",),
    "Good": ("Good«Gd»",),
    "Bad": ("Bad«Bd»",),
    "RcAccounting": ("RcAccounting«RA»",),
    "ProbabilisticEscrow": ("ProbabilisticEscrow«PE»",),
    "Escrow": ("ProbabilisticEscrow«PE»",),
    "TransactionProposal": ("TransactionProposal«TP_k»",),
    "TxTree": ("TxTree(",),
    "CausalContribution": ("CausalContribution",),
    "CausalDistribution": ("CausalDistribution«CD»",),
    "Reputation": ("Reputation«Re»", "Re("),
    "BalOvflw": ("BalOvflw",),
    "AccumThresh": ("AccumThresh(",),
    "Overflow": ("BalOvflw",),
    "Law": ("Law«Lw»", "Law"),
    "Administration": ("Administration«Ad»",),
    "Democracy": ("Democracy«Dm»",),
    "Power": ("Power«Po»",),
    "Influence": ("Influence«Inf»",),
    "Impact": ("Imp(",),
    "BfDm": ("BfDm(",),
    "FractalScope": ("FractalScope",),
    "LqdBfDm": ("LqdBfDm(",),
    "LqCfdBfDm": ("LqCfdBfDm(",),
    "Crime": ("Crime«Cr»",),
    "Inaction": ("Inaction(",),
    "ExternalHaResponse": ("ExternalHaResponse«EHR»",),
    "EHR": ("ExternalHaResponse«EHR»",),
    "Liability": ("Liability«Lia»",),
    "Enforcement": ("Enforcement«En»",),
    "Accolade": ("Accolade«Aco»",),
    "Fork": ("Fork(",),
    "Forks": ("Fork(",),
    "Merge": ("Merge(",),
    "Culture": ("Cu :=",),
    "Art": ("Art :=",),
    "T_a": ("T_a :=",),
    "InfoHazard": ("InfoHazard«IHz»",),
    "CriticalThinking": ("CriticalThinking«CrT»",),
    "Education": ("Education«Ed»",),
    "SoNet": ("SoNet«SN»",),
    "BindId": ("BindId(",),
    "TN": ("TN :=",),
    "ContentionMap": ("ContentionMap",),
    "IH": ("IH(TN)",),
    "Freedom": ("Fr :=",),
    "Fr": ("Fr :=",),
    "Morality": ("Morality«Mr»",),
    "1shotGame": ("1shotGame",),
    "Economy": ("Economy«Ec»",),
    "EmbeddedLaws": ("EmbeddedLaws«EL»",),
    "Implementation": ("Implementation«Im»",),
    "SophontOversight": ("SophontOversight«SO»",),
    "Af": ("Af :=",),
    "S_BaselnIncm": ("S_BaselnIncm«SB»",),
    "Mem": ("Mem :=",),
    "Harm_Intv": ("Harm_Intv",),
    "Rc_Innovation": ("Rc_Innovation",),
    "CvCnt": ("CvCnt",),
    "Progressive": ("Progressive«Prog»", "Prog("),
    "SigThGv": ("SigThGv",),
    "Di_N_Balance": ("Di_N_Balance",),
    "Di_N": ("Di_N_Balance",),
    "AntiCorruption": ("AntiCorruption«AC»",),
    "AdvAp": ("AdvAp",),
    "TrustMin": ("Trust«Tt»Min",),
    "Trust«Tt»Min": ("Trust«Tt»Min",),
    "TtMin": ("Trust«Tt»Min",),
}

L_RE = re.compile(r"\bL(\d+)(?:[-–](\d+))?\b")
AUDIT_ROW_RE = re.compile(r"^\|\s*\*{0,2}L(\d+)(?:-\d+)?(?:\s*:)?\s*`([^`]+)`")


def range_matches_markers(lo: int, hi: int, markers: tuple[str, ...]) -> bool:
    for ln in range(max(1, lo), min(len(SPEC_LINES), hi) + 1):
        if any(m in SPEC_LINES[ln - 1] for m in markers):
            return True
    return False


def expected_lines(markers: tuple[str, ...]) -> list[int]:
    return [i + 1 for i, s in enumerate(SPEC_LINES) if any(m in s for m in markers)]


def check_audit_doc(errors: list[str]) -> int:
    audit_path = ROOT / "docs" / "pseudocode_lean_coherence_audit.md"
    checked = 0
    for idx, line in enumerate(audit_path.read_text().splitlines(), 1):
        m = AUDIT_ROW_RE.match(line)
        if not m:
            continue
        ln, raw = int(m.group(1)), m.group(2)
        sym = re.split(r"[\s(:«;]", raw)[0].rstrip(",")
        markers = TERM_MARKERS.get(sym, (sym,))
        checked += 1
        if not range_matches_markers(ln, ln, markers):
            exp = expected_lines(markers)
            actual = SPEC_LINES[ln - 1].strip()[:50] if 1 <= ln <= len(SPEC_LINES) else "<out of bounds>"
            errors.append(f"docs/pseudocode_lean_coherence_audit.md:{idx}: row L{ln} `{sym}` (spec has `{actual}`, expected {exp})")
    return checked


def scan_files() -> tuple[int, list[str]]:
    errors: list[str] = []
    checked = check_audit_doc(errors)
    targets = (
        sorted((ROOT / "Benefuture").rglob("*.lean"))
        + sorted((ROOT / "BenefutureReference").rglob("*.lean"))
        + sorted((ROOT / "sim").rglob("*.jl"))
        + [
            ROOT / "docs" / "DATA.md",
            ROOT / "docs" / "ODD.md",
            ROOT / "docs" / "OSTROM.md",
            ROOT / "docs" / "SPEC_DIVERGENCES.md",
            ROOT / "docs" / "THEOREM_INDEX.md",
            ROOT / "docs" / "CLAIMS.md",
            ROOT / "sim" / "README.md",
        ]
    )
    for path in targets:
        if not path.exists():
            continue
        rel = path.relative_to(ROOT)
        for idx, line in enumerate(path.read_text().splitlines(), 1):
            for m in L_RE.finditer(line):
                lo = int(m.group(1))
                hi = int(m.group(2)) if m.group(2) else lo
                pre = line[max(0, m.start() - 32):m.start()]
                post = line[m.end():min(len(line), m.end() + 32)]
                # Only bind forward if separated by space/colon/paren (not comma joining separate items or filename `.txt`).
                am = re.match(r"^\s*[:(\"`' ]+\s*(?:§[A-Za-z_]+\s*:\s*)?([A-Za-z_§][A-Za-z0-9_]*)(?!\.txt\b)", post)
                # Only bind backward if not immediately after another `L<n>` item in a comma list (e.g. `L114 LqdBfDm, L158`).
                pm = None
                if not am:
                    cand = re.search(r"([A-Za-z_§][A-Za-z0-9_]*)\s*(?:,\s*|\(\s*|\s+)$", pre)
                    if cand and not re.search(r"\bL\d+\s+[A-Za-z_§][A-Za-z0-9_]*\s*,\s*$", pre):
                        pm = cand
                for match_group in (am, pm):
                    if not match_group:
                        continue
                    tok = match_group.group(1)
                    if tok not in TERM_MARKERS:
                        continue
                    checked += 1
                    markers = TERM_MARKERS[tok]
                    if not range_matches_markers(lo, hi, markers):
                        exp = expected_lines(markers)
                        actual = SPEC_LINES[lo - 1].strip()[:50] if 1 <= lo <= len(SPEC_LINES) else "<out of bounds>"
                        errors.append(f"{rel}:{idx}: `{tok}` cites L{lo}" + (f"-{hi}" if hi != lo else "") + f" (spec L{lo} is `{actual}`, expected {exp})")
    return checked, errors


def main() -> int:
    checked, errors = scan_files()
    if errors:
        print("\n".join(errors))
        return 1
    print(f"all {checked} pseudocode line citations match spec/Bf_Pseudocode.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
