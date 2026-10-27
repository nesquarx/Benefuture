# Plan

Two parts, per `docs/CODING_STYLE.md` §7. Read Part 2 every turn; read Part 1 only when needed.

## Part 2: Direction and next steps

- **Ratify §7 of `docs/BACKPROPAGATION.md`.** Coherence edits applied to articles and pseudocode as [P].
- **Quantile floors in Lean.** Define the thresholded low quantile used by G's floors (L74) and prove `removal_cannot_raise_floor` for it: order statistics are monotone in each level, so the literal-minimum proof should generalise.
- **Domain-relative expertise.** Government proposes the expertise term relative within each domain; carry it into L113 and `Governance.Democracy`, or reject it.
- **Abbreviation sweep.** Articles spell out Benefuture's own abbreviations and symbols (common parlance and names are fine); earlier text still contains some (for example U/H, MM). Edited lines comply.
- **Simulation** (`sim/`, small increments, red first). Next operators against `spec/vectors/`: assessment, value (harm weight, value on being), escrow, pricing, reputation decay, democracy, harm, freedom, population, EHR; then agents and state per `Step`, then `SimTrace` and the `Conj_*` and B-list conjectures, including B20–B25.
- **Wiki.** Create the Morality, Art and Freedom pages on the wiki by hand (the sync tool cannot create pages), then add it to `docs/articles/_manifest.json` from a fresh fetch.
- **Open readings.** EHR (BACKPROPAGATION 5.5); reputation decay form and partition of unity (5.6); end-of-horizon conduct (B25).

## Part 1: Done

- Lean 4 specification of the pseudocode with invariants and sanity lemmas; behavioural claims as conjectures over `SimTrace`; Float reference library and JSON test vectors.
- Population direction: staged G, counterfactual floors, assessed distribution term, Pigou–Dalton for H, U shared rather than moved (`u_sharing_gain_nonneg`).
- Coherence audit against the articles: findings and applied edits in `docs/BACKPROPAGATION.md` §7; conjectures B20–B25.
- Self over the long-term window, causal and ideological inheritance, art success by spread of reception, debits for informed falsehood only (BACKPROPAGATION 7.12–7.13).
- Positioning line in Introduction (short) and Philosophy (full, glossed).
- Local toolchains (`tools/setup/toolchains.sh`): Lean builds and Julia runs in session; `sim/` package with synergy operators passing the vectors and an adversarial suite; Julia Sim CI.
- Freedom article, with links repointed (BACKPROPAGATION 7.17).
- Art article, with Culture's paragraph reduced to a pointer (BACKPROPAGATION 7.16).
- Morality article, with links repointed and Philosophy §Morality trimmed to its parallels (BACKPROPAGATION 7.15).
- Coding style imported to `docs/CODING_STYLE.md`; agent notes in `CLAUDE.md`.
