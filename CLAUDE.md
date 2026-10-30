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
- Articles spell out Benefuture's own abbreviations and symbols (understanding, not U; metric model, not MM). Common parlance (AI, GDP, DNA) and names (M-Pesa, PNAS, author initials) stay as they are. Symbols belong in the pseudocode and Lean.
- Core article format: a minimal definition (following its pseudocode line's order where one exists, key terms linked up top), pithy aspects, pithy examples; exploration belongs in the discussion; every reference carries a link. Definitions and aspects restate the author; examples and discussion may be AI-written, and the disclaimer says which.
- Coherence critiques are independent of comparative ones and are welcome.

## Verification
- Toolchains: `tools/setup/toolchains.sh` installs Julia and Lean (idempotent; binaries in `~/.local/bin`). If they are missing, run it before verifying.
- Lean: `lake exe cache get` once per container, then `lake build`. Julia: `julia --project=sim -e 'using Pkg; Pkg.test()'`.
- CI is the gate: after pushing, check the "Lean Action CI" and "Julia Sim CI" runs for the head commit. A red run is diagnosed from its job log before any further edit.
- The Lean analogue of the dual suites: acceptance theorems state what must hold; counterexample theorems (e.g. `survivor_floor_rises_on_removal`) state what must fail.
- Simulation (`sim/`, Julia package `BenefutureSim`): each increment starts with acceptance tests against `spec/vectors/` and an adversarial suite, run red before implementing.
- Rules live once, in the Lean reference (`BenefutureReference`), exported through `BenefutureReference/Export.lean`; Julia calls them by `ccall` and holds only the world model and input guards. Loading `BenefutureSim` rebuilds the shared library only when the hash of the Lean sources changes. A new rule is a Lean reference function plus one export and one thin Julia wrapper, never a Julia reimplementation.
- `BenefutureReference` and `Main.lean` must not import Mathlib or `Benefuture.*` (CI guard).
- Lean ignores borrow annotations on `@[export]`: exported functions consume every argument. Arrays returned to Julia are read through `lean_floats` (`sim/src/domains.jl`), which takes a reference before each read.
- The simulation's outcome is a system of rules ready for implementation: the end state models the Lean objects one to one, keeps no toy assumptions, and absorbs messy reality. Toy worlds are stages that name the objects they approximate and the toy assumptions they still make, and graduate (`docs/PLAN.md`).
- Every gate value, modifier and coefficient a rule uses is a threshold to be governed later: list it in `sim/README.md` (Governed thresholds) with its default and source. Properties of the world (skills, noise, contract terms) are not thresholds; they go under Noise or the world's parameters.
- Every step that can go wrong in reality carries a noise parameter, on its own random stream, with a range to explore (`sim/README.md`, Noise).
- G is not a global chooser (author ruling 8.50): every entity runs its own messy approximation of G on its own noisy view of reality; many act each step, concurrently. A single global G is a limiting case for tests.
- Success is the Goal's whole pattern (L74), not the floor alone: floors and medians of understanding and happiness, the peak of understanding (none falling), and harm's peak (the deepest single-being drop). Tests and batteries judge by it (`success_pattern`, `sim/src/analysis.jl`).
- Nothing is perfect (author ruling 8.33): world defaults are mildly imperfect (the low end of each noise range); exact models, people or processes appear only as limiting cases in tests. Apply Benefuture's logic to the work: truth levels never reach 1, so claims carry their confidence and assumptions.

## Working
- Parsimony. Before adding a mechanism, establish that no existing one handles the case: an outcome recorded with its measured outputs mints or destroys currency, causal distribution shares it, laws and contracts learn from it. The simulation should need nothing beyond the Lean and the pseudocode; where it does, the extra is named in `sim/README.md` (Parsimony audit) as introduced, with the reason, and is a candidate for removal. Actively look for introduced mechanisms that native ones already cover, and for redundancy in the corpus (proposals go to `docs/BACKPROPAGATION.md`).
- Gaming. For every mechanism added, ask how it can be gamed or complied with maliciously before building it (a payment for braking rewards near misses), and record the answer with it; plausible exploits become M6 tests.
- Duties stay minimal, but are real (author ruling 8.46): some contribution and participation is a duty (voting above a threshold, care not to harm others in obvious ways), and the line where a duty becomes a recommendation is a governed threshold. Freedom pushes back on duties and laws: they protect only against outcomes beyond the freedom harm boundary. Never model duties as a separate rule set binding agents; they are contracts and communicated laws, assessed through ordinary outcomes.
- Failure-boundary batteries (`sim/battery/`) run in the background continuously, like threshold perturbation: never wait on them. When one finishes, record its results (tagged with the commit they ran on) and start a fresh run on the latest build if the simulation, the Lean reference or the battery itself changed since (seeds are fixed, so an unchanged build repeats its results); work from their data to improve the framework.
- When instructed to make progress and blocked on something that needs the author, first make the unambiguous progress that is independent of the block; then stop and ask. Not when asked for one specific task.

## Records
- `README.md` (Claims) states in plain words what is proved in Lean, true by construction, or demonstrated in simulation, with links, hypotheses and toy assumptions; never more. Links name the theorem (its ID) and its file, never a line number; `python3 tools/check_readme_claims.py` checks every named theorem exists. Update it with each increment; regenerate `docs/THEOREM_INDEX.md` with `python3 tools/theorem_index.py` when theorems change.
- Author clarifications, and strong requirements or proposals the work surfaces, go to `docs/BACKPROPAGATION.md` as they arise, with candidate homes in the sources; withdrawn proposals are marked, not deleted.
- Process changes the author asks for go into this file and `docs/PLAN.md` in the same commit.
