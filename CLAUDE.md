# Benefuture — agent notes

## Read first
- `docs/CODING_STYLE.md`: the principal's methodology (dual-suite tests first, atemporal docs, zero speculative patching).
- `docs/PLAN.md` Part 2 (direction) every turn; Part 1 (history) only when needed.

## Sources of truth
1. `spec/Bf_Pseudocode.txt`; the root `Bf_Pseudocode.txt` and the block embedded in `docs/articles/Benefuture.txt` are copies, so edit all three or none.
2. `docs/articles/*.txt` (MediaWiki source).
3. Lean in `Benefuture/` formalises 1–2; `BenefutureReference/` is the Mathlib-free Float reference that generates `spec/vectors/*.json`.

Status tags: `[R]` ratified by the author, `[P]` proposed, `[OPEN]` unresolved, `[CONJ]` simulation conjecture. Divergences go in `docs/SPEC_DIVERGENCES.md`; findings that should flow back to the sources go in `docs/BACKPROPAGATION.md`; conjectures in `docs/SIM_CONJECTURES.md`.

## Corpus conventions
- Benefuture reads outputs only: beliefs and preferences are not directly accessible, so definitions, enforcement and alignment are stated over outputs.
- Understanding is shared, not moved: teaching raises the learner and leaves the teacher's level intact. Never model U as a fixed stock transferred between beings.
- The self is causal, over the long-term window (`Ha_lt`); the recognised self is a cognitive artefact kept in articles only, never measured. Neither self confers any claim over self-things beyond established relations (contracts, law, causal distribution). Property is not inherited; causal and ideological inheritance are.
- Articles spell everything out: no abbreviations (understanding, not U; personally identifiable information, not PII). Symbols belong in the pseudocode and Lean.
- Coherence critiques are independent of comparative ones and are welcome.

## Verification
- Lean cannot be built in cloud sessions (no toolchain; installing one is not permitted). Verify through GitHub Actions: push, then check the latest "Lean Action CI" run for the head commit. A red run is diagnosed from its job log before any further edit.
- The Lean analogue of the dual suites: acceptance theorems state what must hold; counterexample theorems (e.g. `survivor_floor_rises_on_removal`) state what must fail.
- `BenefutureReference` and `Main.lean` must not import Mathlib or `Benefuture.*` (CI guard).
