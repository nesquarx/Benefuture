# Back-Propagation Audit: What Formalisation Found That the Sources Miss

Formalising Benefuture in Lean forced decisions the pseudocode and articles leave implicit, and proved
some properties that only hold under conditions the sources do not state. This document lists each
such nuance with its evidence and a proposed edit to the sources. Sections 1–6 are proposals the
author decides; section 7 lists edits applied to the sources as [P], awaiting ratification.

Classes:
- **A — Author's ruling, not yet in the sources.** Decided in discussion; the sources should say it.
- **B — Forced by proof.** A stated property only holds under a condition the sources omit.
- **C — Open.** The sources are under-specified and need the author's reading.

Notation follows the pseudocode. "Lean:" names the definition or theorem that carries the point.

---

## 1. Synergy and parameters (L11–L14)

**1.1 Subscripts of Sy are ambiguous (B).**
`Sy_{κ,q₊}` is the signature, but `Sy_{½,1.5}` (L61) was read as q₊ = ½, q₋ = 1.5, which made Ha_wt
concave in severity; by the signature it is κ = ½, q₊ = 1.5 (convex, as the article says).
Lean: `compute_harm_weight`, `harm_tier_superlinear`.
Proposed edit: name the subscripts. L61 `Ha_wt: 1 + Sy_{κ=½, q₊=1.5}(…)`; L73 `V := Sy_{κ=2}(…)`.

**1.2 Items are (x, w₊, w₋) (B).**
L13 declares `[(x, w_+ = 1, w_- = w_+)]`; L73's triples `(U, α, Ha_wt)` only make sense in that
reading (Ha_wt weighs losses). An earlier formalisation applied α·Ha_wt to gains too.
Lean: `net_synergy_signed`, `net_synergy_signed_gain_ignores_loss_weight`.
Proposed edit: L73 `V := Sy_{κ=2}(As([(U, w₊=α, w₋=Ha_wt), (H, w₊=β, w₋=α·Ha_wt), (N, w₊=γ)], A, t))`.

**1.3 λ ≤ 1 is required (B).**
Sy is Pareto-monotone (more of every good, less of every bad never scores lower) only for 0 ≤ λ ≤ 1.
Above 1, a dominated mix of gains and losses can outscore its dominator.
Lean: `net_synergy_raw_strict_mono_plus`, `sy_score_pareto_monotone`, `Admissible.lambda_le_one`.
Proposed edit: L13 `(κ = 1, q₊ = 1.1, q₋ = 1.5, λ = ½) ∈ SigThGv | κ ≥ 0, q₋ ≥ q₊ > 1, 0 ≤ λ ≤ 1`.

**1.4 Loss aversion needs threshold-normalised inputs (B).**
With q₋ > q₊ > 1, losses outweigh equal gains only for magnitudes ≥ 1; below 1 the exponents invert
it. As normalises by Th_Cx (L48) and significance means ≥ Th (L25), so every significant input is
≥ 1, but L13 never says its inputs are in threshold units.
Lean: `loss_aversion_fails_below_one`, `significant_assessment_preserves_loss_aversion`,
`admissible_loss_aversion`.
Proposed edit: L13 append `| x ← As(·) (threshold units, L48)`.

**1.5 One priority weight per tier (B).**
`(x_1 > … > x_n) := [(x_i, Pm_i)]` (L12) needs n weights; Ha_wt has 8 tiers but the generic
schedule had 6, silently dropping two. Harm now has its own schedule.
Lean: `harmSchedule`.
Proposed edit: L12 `| |Pm| = n`; L61 name its schedule (`Pm_Ha`).

**1.6 `find ∧ max(⋂ ↑x)` is Pareto-then-maximise (B, confirms).**
The tail of L13 reads as: keep options that are not dominated on every dimension, then maximise.
Lean: `pareto_front`, `pareto_front_nonempty`.
Proposed edit: none required; an article sentence would help ("first discard dominated options,
then maximise").

## 2. Harm, happiness, understanding (L37, L54–L55, L58–L59)

**2.1 Harm reference points (A).**
↓H is a fall below the rolling average (coming down from a peak is not harm); ↓U is a fall below
the being's running maximum (forgetting is harm). L54 says only `↓U ∨ ↓H`.
Lean: `h_harm`, `u_harm`, `coming_down_not_harm`, `forgetting_is_harm`.
Proposed edit: L54 `Ha(t) := (U(t) < max_{τ≤t} U(τ)) ∨ (H(t) < avg_{window} H)`.

**2.2 H is non-negative; bias is a graded, separate MM claim (A).**
Bias covers malice, doom-scrolling and impairing stupor. MMs attach (degree, confidence) to each
source; measurements stay raw; claims are made independently of tier so peak-tier sources are not
discounted twice.
Lean: `BiasClaim`, `happiness_score`, `happiness_score_nonneg`, `fully_biased_contributes_nothing`.
Proposed edit: L37 `H := ∫Positive(Se) + BiasMitigation + Di ≥ 0 | BiasMitigation := −Σ c·b·Se_i ← MM(claim ⊥ tier)`.

**2.3 Two different Di (B).**
L35's Di is system-level (order/chaos balance); L37's Di inside a being's H is read as variety
within one life. The same symbol names both.
Lean: `experiential_variety` (L37), `DiversityBalance` (L35).
Proposed edit: L37 `… + Di_exp` with `Di_exp := Variety(Se(b))`, or state the relation to L35.

**2.4 Priority tiers mix kinds and distribution positions (A).**
L58–L59 interleave kinds (eudaimonic, shareable, satisficing, peak; peak, teachable, meta,
undirected) with population positions (baseline, median, floor). The first come from MM labels on a
being's sources; the second from the population distribution.
Lean: `happiness_tiers_of`, `understanding_tiers_of`, `kind_tiers_partition_happiness`.
Proposed edit: mark positions, e.g. `H: Sy(eudaimonic > shareable > satisficing > baseline_q > median_q > peak)`.

**2.5 Fr is a subgoal, not a filter on G (A, superseded).**
An earlier reading had Fr filter first and NHa operate inside it. Author: Fr is a fair-weather rule
for action-space maximisation and fails on trolley problems; the priorities should produce it.
G now filters only ↑ℝ and counterfactual ↑min; Fr is reported per plan.
Lean: `dominated_plan_not_chosen` (trolley and Fr emergence), `inaction_admissible`.
Proposed edit: L135 drop `NHa ⊆ Fr, G ⊆ Fr`; Harm.txt states the everyday-rule reading.

## 3. Freedom (L135)

**3.1 Read literally, the irreversible clause blocks everything (A).**
Almost every action has some chance of irreversible harm. Author's reading: Fr blocks established
harm (confidence ≥ Th_conf) at long-term severity or worse, and any harm whose expected severity
exceeds Th_high; mild chances of passing harm do not block.
Lean: `fr_permissible`, `speculative_catastrophe_blocks`, `remote_irreversible_chance_permitted`.
Proposed edit: L135 `Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd(P ≥ Th_conf, ≥ longterm) ∨ P·severity > Th_high)`.

## 4. Population, distribution and the Goal (L62, L68, L73–L74)

**4.1 Bf ranks actions, not worlds (A).**
Being-level value exists only as an expected lifetime tally over Bounds_B, under the best available
uplift policy. Existing beings may only be uplifted; removal is dominated whenever uplift is
available and cannot raise the floor, which is taken over the decision-time population;
net-negative tallies never outweigh a positive population. Withholding uplift is not Ha, only
comparatively worse.
Lean: `expected_tally`, `dominated_plan_not_chosen`, `removal_cannot_raise_floor`,
`survivor_floor_rises_on_removal`, `net_negative_never_outweighs_positive`,
`withholding_incurs_no_harm`.
Proposed edit: an article section (Benefuture goals.txt or a population-ethics article) stating these.

**4.2 The Repugnant Conclusion is not "directly dissolved" by the floor or skew alone (B).**
Benefuture goals.txt says the skew requirement with q₊ > 1 "directly dissolves" it. A floor alone
only moves the threshold; skew alone can be met by pushing the worst-off further down. What blocks
it is the combination of directional pushDistr and ↑min held jointly, with V's convex harm weights.
Lean: `floor_shifts_repugnant_conclusion`, `skew_direction_alone_permits_min_decline`, `goal_G_sound`.
Proposed edit: reword to "is blocked by the skew directive held jointly with ↑min: …".

**4.3 pushDistr is directional, and ↑min holds over the trajectory (A, B).**
Skew sets direction, not a target shape (A). ↑min is hard but may dip inside an NHa tunnel that
closes within the prediction horizon (A); a step-by-step filter would reject every such tunnel (B).
Lean: `pushDistr_aligned`, `min_holds_over`, `tunnel_admissible_but_not_stepwise`,
`nonclosing_tunnel_triggers_harm_intv`.
Proposed edit: L62 `pushDistr(…direction…, ↑min over lt (NHa dips ⇒ Harm_Intv), …)`.

**4.4 pushDistr enters G as an assessed term, and ↑min is counterfactual (A).**
L74 says `argmax ΣV ∧ ↑ℝ`; L62 is not referenced by it. Author: V is already assessed, so assess
the distribution too and combine per being through Sy (not additively, so it is not discounted).
Measured at absolute levels through priority-shaped transforms (U slightly convex, H concave, Ha convex), dimensions U > Ha > H; no moment skew or gate. ¬↓ compares
A with ¬A (As, L48), so inaction is always admissible and a trolley pull does not lower the floor.
Lean: `goal_G`, `goal_G_sound`, `goal_G_some`, `inaction_admissible`, `goal_value_strict_mono`,
`levelling_down_never_helps`, `higher_u_gain_valued_more`, `lower_h_gain_valued_more`, `dim_priority_order`.
Proposed edits: L62 `pushDistr(Σ_{b ∈ B(t)} ΔW((U, convex), (H, concave), (Ha(¬NHa), convex))_lt | U > Ha > H, (N, norm(—^—)))`;
L74 `G(t) := argmax_{A(t)} [Σ_{b ∈ B(t)} Sy(V(A, b), As(pushDistr))] ∧ ↑ℝ ∧ ¬↓(U(max, min), H(min))`. Ha is counted over lt with closing NHa dips excluded (`ha_lt`). N's normal-shape skew term stays: it is Di's order/chaos balance, while Σ N (variety) enters through ΣV. N has no range bounds (floor: a proton's pattern; peak: any ID_t); novelty counts through its effects.

**4.5 No sentience multiplier (A).**
Capacity enters through absolute magnitudes of U and H.
Proposed edit: L73 note `| no St weight; capacity ∈ |ΔU|, |ΔH|`.

**4.6 Diversity is derived from N (B, confirms).**
Summing N(x) = 1/Frequency over a population gives exactly its number of distinct types (at most
that, counting history), so copies cannot buy diversity.
Lean: `population_novelty_eq_effective_types`, `population_novelty_hist_le`, `copies_add_no_diversity`.
Proposed edit: one sentence in Diversity.txt: "Total novelty of a population equals its number of
distinct kinds; duplicates add nothing".

## 5. Economy and governance (L82–L86, L99, L113–L117, L157)

**5.1 Infrastructure is a resource, not a fee (B, confirms).**
MM compute and Technology Network bandwidth enter the action's resource cost (L83, L86), are burned
(L99), and providers are paid via CD (L96). A flat protocol fee has no source.
Lean: `Economy.Pricing`, `price_strictly_increases_with_compute`, `heavier_model_less_efficient`.
Proposed edit: Benefuture currency.txt: "There is no protocol fee; infrastructure is accounted as
resources consumed".

**5.2 The delegation cap bounds concentration at cap + one delegation (B).**
Under L114, a delegate can end at most one delegator's weight above Th_k, not at Th_k.
Lean: `accumulate_capped_bound`.
Proposed edit: L114 note `⇒ CumulativeVoteWeight ≤ Th_k + max VW_i`.

**5.3 Base voting weight (B).**
Government.txt has VoteWeight = BaseWeight + ExpertiseWeight·Expertise + ImpactWeight·Impact;
L113 has no base term.
Proposed edit: L113 `BfDm := (Base + Expert(Σŵ·Re)·VW + Impacted·VW) …`.

**5.4 SigThGv must reject inadmissible proposals (B).**
Theorems hold everywhere in the admissible region; governance must not leave it. Perturbation drift
is bounded by n·δ after n steps, so large moves require debate.
Lean: `Admissible`, `gov_step`, `governed_params_admissible`, `perturb_run_drift`.
Proposed edit: L157 `SigThGv := Ap(Th ∈ Debatable? LqdBfDm : Perturb(Th ± δ ∈ Fr)) | Admissible(Pm)`.

**5.5 EHR is under-specified (C).**
L117 combines tit-for-tat with α·Re₊·P(Forgive) and δ·Re₋·P(Overreact); the spec encodes only
harm − α·Re₊. A generous tit-for-tat reading (forgiveness probability rising with Re₊, overreaction
with Re₋) is plausible but unratified.

**5.6 Reputation decay form and partition of unity (C).**
Exponential vs subtractive decay (§4.3 of SPEC_DIVERGENCES) and one vs per-RelType partitions of
unity (§3.2) remain open in the sources.

## 6. Process

**6.1 Two pseudocode copies diverged.** The root copy predated recorded decisions; it is now synced.
Keep one source (spec/), or generate the other.

**6.2 Encodings.** About 25 modules use fixed-point integers; they are within one micro-unit of the
ℝ definitions (`Systems.FixedPoint`). Not a source issue, but the sources could state SCALE
semantics if fixed point is intended for implementations.

## 7. Coherence audit: edits applied to the sources ([P])

Rulings from a coherence review, applied to the articles and pseudocode. Each line names the
source change; Lean and simulation counterparts are named where they exist.

**7.1 Outputs, not preferences.** Benefuture reads outputs only. Benesophont: alignment is a track
record of goal-aligned outputs (reputation), with the goals, not the mechanisms; dissent over
mechanisms goes through Adversarial adaptation. Enforcement: it influences outputs; force applies
only to violations of mandatory laws; lawful goal-negative outputs meet design, pricing,
persuasion and law updates.

**7.2 Understanding is shared, not moved.** Introduction (transmissibility) and Life in benefuture
say "shared". Lean: `u_sharing_gain_nonneg` replaces the fixed-stock transfer dual; B17 restated.

**7.3 Floors are thresholded quantiles; inaction is absence of outputs.** L74
`| min := Th_quantile, tail → Me`; L48 `¬A := ∄Ou(actor)` (both pseudocode copies and the copy
embedded in Benefuture.txt). Benefuture goals and Measurement state both. Lean: `DistrStats`
documents the quantile; `removal_cannot_raise_floor` is proved for the literal minimum.

**7.4 Baseline is negative pricing, owed to persons.** Law (rights belong to persons, appearing
as transactions priced at or below zero), Government (living persons; births: newborn needs are
baseline through caregivers' transactions, escrow covers only above-baseline upkeep), Benefuture
currency (life cycle), Life in benefuture (a guaranteed floor, also justified by return).

**7.5 Reputation tiers buy accuracy, not influence.** Implementation prototype: higher tiers give
a more accurate reputation and so a more precise voting weight; opt-outs sit outside the pilot
polity; tier is a declared confounder with population reweighting (also System Design); tier
adverse selection noted. B24.

**7.6 Infohazard gating.** No owner approval: access is by education alone. Completing the
education is a recorded acknowledgement, so misuse is informed crime (Technology Network, Crime,
Implementation prototype, Critique addressal on stalking). B21.

**7.7 Self-regarding risk.** Harm: freedom marks, it does not forbid; chosen risks are priced
against harm across the extended self; Benefuture holds no purely self-regarding boundary.

**7.8 Governance.** Government: Estlund's demographic objection answered (earned expertise,
domain-relative expertise term, back-loaded reputation, base and impact weight); ideological
impact is mapped through the same priorities, so offence contributes near zero; the death
mapping is harm through causal distribution, not a levy. System Design: Arrow is escaped by
cardinal comparable weights, manipulability is not, so detection is a conjecture. B23.

**7.9 Economy and measurement.** Benefuture currency: Hayek's knowledge problem and discovery by
model competition. B20, B22. Benefuture goals: the utility-monster sentence names what blocks it
(teachability, synergy, floors, concave happiness).

**7.10 Critique framing.** Critique addressal: coherence critiques are independent of
comparative ones and welcome.

**7.11 Open.** End-of-horizon conduct under no inheritance (B25). Expertise normalised within
domain is proposed in Government but not yet in L113 or `Governance.Democracy`.

**7.12 Self, lifespan and inheritance.** The self's harm horizon is the long-term window:
`Self«Sl» : ∃fuzzy(max(T ∈ ℝ) : Ha(Sl) = Ha_lt(B))` (all three pseudocode copies), so the self
includes its history. Being: the causal self (objective, mostly unrecognised; morality is
understanding it) and the recognised self (a cognitive artefact, articles only, not measured;
anything may be recognised, measured harm follows the usual tiers; neither self confers any
claim over self-things beyond established relations). The lifespan bounds
experienced harm, not the self's reach or intent; property is not inherited, causal and
ideological inheritance continue (Being, Government, Reputation). Philosophy §Morality: morality
grows with understanding; Socratic intellectualism and weakness of will. B25 restated.

**7.13 Art and speech.** Art success matches intent against the spread of reception
(`Success := match(p, Dist(q))`, all three copies); feeling counts through V, art's value is the
surplus. Philosophy positioning: art's value is measured, its making answers to no test; the
novelty space is the outside. Benefuture currency: only informed falsehood is debited; honest
error at most widens escrow.

**7.14 Power and domination.** Anti-Corruption: distributing power is the freedom gate applied to
power (`Fr`'s harm gate excludes concentrations whose expected harm is too high). Critique
addressal: non-domination is met by contestability, transparency and distributed power; unused
capacity matters only through the outputs it changes, measured as harm.

**7.15 Morality article.** New `docs/articles/Morality.txt`: definition in the order of the
pseudocode line (L136), seven aspects restating the author, examples, and a discussion covering
the self, propagation (strictness, chaos, the parallel cone, saturation, the worm, the closed
network across games), memory over repetition (Axelrod and Hamilton; Morozov and Feigel 2026),
dispositions, and placement among moral theories. Philosophy §Morality keeps the parallels and
points to it; links in Being, Benefuture goals, System Design, Justice, Benefuture (reading
order) and Introduction (where to go next) now target it. The wiki page must be created by hand:
`tools/wiki_sync` edits with `nocreate`.

**7.16 Art article.** New `docs/articles/Art.txt`: definition in the order of the pseudocode line
(L125), eight aspects restating the author, examples and a discussion (intent and reception,
art as understanding, many readings, feeling and value, the iron rule, found art, art in the
system), every reference linked. Craft mastery has craft understanding and craft value, not art
value (author). Culture's art paragraph is a one-line pointer; links in Benefuture goals,
Philosophy (positioning) and the reading order now target it. The wiki page must be created by
hand.

**7.17 Freedom article.** New `docs/articles/Freedom.txt`: definition in the order of the
pseudocode line (L135), nine aspects restating the author's rulings (range of meaningful outputs,
power within the harm gate, no blocking of all influence, the established-harm gate, harm
through the self, offence met by education, freedom to know, subgoal not filter, outputs only),
examples and a discussion (positive freedom, the gate and Pascal's mugging, the self and
paternalism, domination, speech and truth, freedom in the system), every reference linked.
Links in Harm, Anti-Corruption, Critique addressal, Benefuture goals, Government, Technology
Network, the reading order and Introduction now target it. The wiki page must be created by hand.

## 8. Simulation findings

**8.1 Floors are only as good as measurement (M1, `sim/README.md`).** G's ¬↓ filter (L74) holds
exactly under perfect measurement. With marker noise on current levels alone, the true floor
falls in about 9% of steps; with moderate prediction noise, about 14%; with heavy prediction
noise G chooses inaction in most steps. Candidate rule, for the author: an uncertainty margin on
admissibility, requiring a floor's predicted change to clear its measurement uncertainty, the
escrow principle applied to ↑min. Open.

**8.2 Domain profiles must be measured, not declared (M3, `sim/README.md`).** With a fixed
profile per action, attribution splits whole-action outcomes by declared shares: per-domain skill
cannot be identified, and an actor setting its own profile could steer reputation into domains
of its choosing. L22 already has domain relations come from memory, not declaration; the sources
could say the same of an action's profile: assigned by metric models from where its effects
land, open to dispute.

**8.3 Classification is tree traversal by currency metric models (author ruling; not yet in the
sources).** Currency metric models assign an action's profile by matching its causal reasons to
domains' causal signatures, descending the domain tree to a leaf. A match stuck at a branch goes
back up until a model is willing to price it. StandCoin is a root-level currency: it cannot
predict outcomes and charges only resource cost, by availability. Net-new scenarios land there and
are marked for adjudication; many blockages at one branch call for a new subdomain. Candidate
homes: Domain (Aspects: causal grounding, nested structure; anti-gerrymandering's orphan
detection), Benefuture currency (StandCoin entry), and pseudocode L22 or L86 (all three copies).

**8.4 Author clarifications on domains and pricing (ratified in discussion; not yet in the
sources).**
- Every transaction needs domains: pricing and reputation are both domain-scoped, so domains
  precede any economic mechanism (Domain, Benefuture currency).
- A domain's reputation sums its subdomains'; a subdomain's never counts its parent's (Domain:
  "a broader domain includes the reputation of its sub-domains" states only the first half).
- StandCoin has no universal value predictor; one would contradict incommensurability. Every
  outcome is measured, but an outcome no domain can price is a surprise that drives novelty,
  investigation, research and development (Benefuture currency, StandCoin entry; Novelty).
- A currency's willingness to price is its eligibility (L82: `MM_Acc > Th` in the domain) and
  its confidence score; no separate criterion.
- The domain structure is a tree-ish overlap network, not a strict tree: descent and fallback
  rules need fine tuning for nodes with several parents and for overlap zones (Domain: overlap
  zones, mandatory competition).
- Thresholds may be set approximately for simulation and handed to governance later.

**8.5 Withdrawn (author ruling, 8.8): models wait for accuracy thresholds before backing currencies.** Was: a newly formed domain prices from formation (surfaced by M3c). If a new
domain's currency had to earn eligibility from scored records before pricing anything, a new
top-level domain would deadlock: work only it could value is never done, so its model is never
scored. Proposed: a domain formed from blockages prices from formation at the confidence its
untrained model's expected error warrants (a large escrow hold), keeping eligibility only while
its rolling score stays above threshold. The research that formed the domain is its initial
model. Candidate homes: Domain (low-friction addition), L82, Implementation (Phase 1 score-only
applies to established systems, not to each new domain).

**8.6 Finding: blockages are the signal for new domains (M3c, `sim/README.md`).** In the toy,
clustered blockages identified every missing domain within about 20 steps and formed none
spuriously. Without formation, work in a domain at the root of the tree is never done, and its
only trace is a steady stream of blockages. Supports "too many cases of branch blockages ask for
new subdomains" as a rule. The anti-gerrymandering aspect (orphan detection, low-friction
addition) could name blockage clustering as the trigger.

**8.7 Finding: balance overflow trades reinvestment against concentration (M3c).** Raising the
accumulation threshold moves the share of net earnings reinvested from 84% to 11% while the Gini
of balances rises from 0.18 to 0.53. The threshold is a distributional choice, not just a
velocity floor; Benefuture currency (supply stability) and the overflow critique addressal could
say so.

**8.8 Author rulings on domains, eligibility and StandCoin (not yet in the sources).**
- Work only StandCoin would take still happens. It is priced high, since no predicted outcome
  offsets its resource cost, and halts only if the proposer cannot pay or gather other experts
  to provide enough currency (Benefuture currency: StandCoin entry, Transaction mechanics).
- Models wait for accuracy thresholds before backing currencies (L82). Novel domains may have a
  lower threshold; dropping to just over 50% would need extraordinary grounds, and it is never
  lower. A novel domain's model starts in the score-only phase (Implementation, Phase 1).
- An undiscovered top-level domain is extremely improbable; novelty normally appears as a
  missing subdomain.
- A domain can overlap strongly with a bigger domain and weakly with others; the domain network
  is an artifact mapping existing memberships and causal signature overlaps (Domain: weighted
  membership, overlap zones; Ontology.Domain [R]: parents as fuzzy sets of leaves). The rules may
  need refinement before the final model.
- The simulation must ultimately model the Lean objects one to one; toy models graduate to them.
- Every step that can go wrong in reality needs a noise parameter, so noise can be raised once
  the model is solid.
- Plan to move from proposals chosen by G to the transaction model, establishing the behavioural
  transaction substrate (L145; System Design: Behavioral Transaction Substrate).

**8.9 Findings from the domain network (M3c, `sim/README.md`).**
- Memory recovers domain overlap degrees almost exactly (error 0.005), supporting relations
  computed from memory rather than declared (L22).
- The score-only phase is a bottleneck: a novel domain qualifies only as fast as its work is
  executed and scored. With new-domain work a small share of activity, half the novel domains
  had not qualified after 500 steps; meanwhile their work is priced by the parent at coarse
  confidence. Open: whether this is acceptable, or whether qualification should also draw on
  evidence other than the new domain's own scored predictions.
- Under heavy noise, model bias can cost a parent its eligibility; its work then falls to
  StandCoin, where most of it halted for lack of funds, and floors grew 18% less.
- Resolved (8.11): work in the StandCoin lane is screened by the best available model.
- Resolved (8.11): experts who co-fund StandCoin work are credited through causal distribution.

**8.10 Superseded by 8.12. Was: memberships learnt from memory start from the bootstrap pattern.**
`Proposed.DomainHierarchy` damps sparse evidence toward zero (S·n/(n+k)). For a domain network
bootstrapped from established classifications (Domain: initial structure), the simulation blends
toward the bootstrap degree instead: μ = c·S + (1 − c)·μ₀, c = n/(n+k), so a new or sparsely used
leaf keeps its consortium membership until memory overrules it. Recorded in
`docs/SPEC_DIVERGENCES.md`.

**8.11 Author rulings on novelty, models and co-funding.**
- A new top-level domain is like discovering an aspect of reality with little or no overlap with
  anything else (antigravity, magic): implausible, and not modelled. Novelty appears as
  subdomains of existing domains.
- Benefuture as a whole starts with a score-only phase (Implementation, Phase 1) in which a
  robust set of domains and metric models forms; later novel subdomains are small additions to it.
- Having no model at all for an action is unrealistic. Work that no qualified currency can value
  is still predicted by the best available model (score-only models predict too), so G screens
  it before it runs; only its pricing falls to StandCoin (Benefuture currency: StandCoin entry;
  L86). In the simulation, a harmful agent's StandCoin work almost never passes the screen.
- Experts who co-fund StandCoin work are credited through causal distribution (L94) once the
  outcome is measured.
- 8.10 is settled by 8.12.

**8.12 Author ruling: domains do not fade; overlaps are long-term rolling averages.** Domains are
living classifications whose history memory keeps. A domain never fades from disuse; its overlaps
with other domains shift slowly to mirror shifts in reality, as the long-term rolling average of
the memberships of logged actions. This settles 8.10: neither the bootstrap blend nor
`Proposed.DomainHierarchy`'s damping toward zero (S·n/(n+k)), which would fade sparse leaves.
Candidate homes: Domain (weighted membership: "weights do not decay temporally" already says the
first half; add that overlaps are rolling averages of members' memberships), L22 (`Rel ← Mem`),
`Proposed.DomainHierarchy` (replace or reinterpret `S_with_confidence`).
- Finding (M3c): learning is slow by design. At a rolling rate of 0.02, a leaf with about 35
  logged actions has moved its overlap degrees about halfway from the bootstrap to their true
  values; busy leaves converge, quiet ones lag. The rate is a governed parameter (SigThGv), and
  the score-only start should be long enough for the network to settle.
- Requirement (author): the simulations' outcome is a system of rules ready for implementation,
  with no toy assumptions and robust to messy reality.

**8.13 Resolved by 8.14. Causal contribution along a transaction tree: range versus conservation.** L93 gives
CC a range of [0, 1], and `Systems.Substrate` computes it as clamped value added
(`causal_contribution_ratio`: (produced − received) / outcome, zero when either is non-positive);
L94 distributes rewards and penalties in proportion to CC, net of escrow paid. Along a chain with a
loss this over-distributes and leaves the loss with no one: links adding 10 and 5 followed by one
destroying 10 (outcome 5) receive 15, and the destroyer is not penalised (proved:
`cc_clamped_overdistributes`). Signed value added, each link credited with what it produced less
what it received, sums exactly to the measured outcome (rewards and penalties alike) and matches
the currency article's "each link is credited for the value it added", but leaves [0, 1] (the
destroyer's share is negative, an upstream link's can exceed 1). Options: (a) signed value added,
with CC's range widened, or [0, 1] kept for a separate positive-part score; (b) [0, 1] by
normalising positive and negative value added separately, rewards ∝ positive parts and penalties ∝
negative parts, each summing to its side of the outcome; (c) something else. The same rule settles
how co-funders of StandCoin work share the outcome (8.11): as links that produced the resources they
paid onward. Candidate homes: L93–94, Benefuture currency (Causal Distribution), `Systems.Substrate`.
- Finding (M3d, transactions): admitting every transaction that beats inaction, rather than G's
  single best choice, roughly triples floor growth and raises the share of executed work measured
  harmful from 2% to 9% (27% under model bias); settlement claws it back. Whether the screen should
  require more than beating inaction (a margin scaled to the model's uncertainty, as in 8.1) is
  open.

**8.14 Author ruling: outcomes are credited by their parts.** A positive outcome pays its
contributors and a negative outcome penalises its contributors; a mixed outcome is split into its
constituent parts by domain and by understanding and happiness impact. A part's side is decided by
its assessment against not acting (As, L48), not by the raw sign of a change. Each contributor's
share of a side is its part over the side's total, in [0, 1] as L93 states, so the chain of 8.13
pays A 10 and B 5 and penalises C 10. Candidate homes: L93–94 and Benefuture currency (Causal
Distribution): "rewards ∝ CC on the positive parts of an assessed outcome, penalties ∝ CC on its
negative parts".
- Superseded by 8.16–8.18 (outcome-first distribution; nothing is left undistributed). Were the
  simulation decisions: (1) a being's gains are valued together and its
  losses together, so only mixed outcomes are split; splitting understanding from happiness even
  in a wholly positive outcome discarded their synergy (κ), half of all measured value. (2) The
  remainder V(outcome) − Σ V(parts), from mixed beings and from contributors' effects meeting on
  one being, is not distributed; it is about 8% of measured value (12% with attribution error).
  (3) Co-funders of StandCoin work share the actor's parts in proportion to their share of the
  cost, as reputation only, since no currency can value that work; a currency share would follow
  once a domain qualifies.
- Finding (M3d trees): with half of all actions building on another agent's recent output, about
  10% of credit flows to upstream contributors; agents who add nothing to what they pass on earn
  almost nothing; a bad output is penalised through the losses it carries downstream.

**8.15 [OPEN] Harm through inaction when action was expected (a driver who does not brake).**
- Sources: inaction is ¬A := ∄Ou(actor), the actor producing no output (L48); assessment compares
  an action with that counterfactual, so not acting has zero assessed value by construction, and
  braking is assessed at the harm it prevents. Crime is harm by informed volition or informed
  inaction (L115, Crime.txt), so a driver who sees the pedestrian and does not brake commits a
  crime; one who could not have known causes an accident. Duty appears only in Accolade (L121:
  good beyond duty is acknowledged); what is expected of an actor is not defined.
- Causal attribution: the collision's harm is carried by the car's motion, an output of the
  driver's ongoing action (driving), so it reaches the driver through causal distribution as a
  negative part of the driving transaction, whatever the brake. Whether "not braking" is a
  separate inaction or part of the action of driving decides which branch applies; the sources
  do not say, and the answer matters for anyone who could have acted but was not acting (a
  bystander).
- Lean gap: `Subgoals.Justice.Crime` requires `hasVolition = true` (`h_culpable`) and
  `is_crime_classification` is informed ∧ volition, so informed inaction classifies as an
  `Accident`, contradicting L115 and the module's own docstring.
- Simulation gap: the toy world has no harm without action (beings change only when acted on), so
  ¬A always means no change and no case of harm through inaction can arise. Modelling it needs a
  world that moves on its own (hazards, decay), where the counterfactual is predicted from records
  (Mem_ctrl, L48) and assessment decides positive and negative parts against it.
- Questions: is not braking an inaction (no output) or part of driving? What makes an action
  "expected": a contract, law, role, or the actor's own prior outputs? Does informed inaction by a
  bystander who did not create the hazard count as crime, given L115's wording?

**8.16 [P] Outcome-first causal distribution (author's outline; specification proposed).**
The author's model: there are no mixed outcomes. A measurement records an outcome, positive or
negative; a positive outcome generates currency (L96), a negative one requires destruction or
reparation (L98, Justice: Repair(Ha)). Metric models then assess each contributing action (and
downstream actions) against its counterfactual: inaction (¬A, L48), or, where a contract or duty
commits the actor, the committed action. Those assessments give CC (L94: CC(O_i, E_j) ↔
MM_CE(TxLog)); without a confident enough assessment, CC falls back to domain-specific traversal of
the transaction substrate (L95). Outlined in the sources, never specified. Proposed changes:
- Sources: (1) define the outcome as the unit of distribution: a measured, signed record per
  being, domain and measurement period, its sign from assessment (L48); (2) give L48 a committed
  counterfactual: As against Pr(x ← A_committed) where a contract or duty binds the actor, else
  ¬A; (3) define Duty, now only in Accolade (L121), as outputs committed through contract (L76
  Intent := E_Precommit(Ou, Ct(Self)); Contract.txt), law as agreement (L102), and possibly
  hazards of one's own making; (4) state L94's switch: CC from MM_CE when its confidence reaches a
  threshold, else the L95 traversal, with its degree-of-separation weights and NetC terms
  specified; (5) normalise CC within each outcome among contributors on the outcome's side, with a
  rule for overdetermination (two causes each sufficient, each assessed at zero against its own
  counterfactual): Shapley-style averaging over contributor subsets, which Benefuture currency
  already names; (6) say who receives reparation for a negative outcome (the harmed being, its
  guardians, or the commons) and what is destroyed.
- Lean: an `Outcome` record (signed, per being, domain, period); a counterfactual type
  (inaction | committed by contract or duty) in `dynamic_assessment_real`; CC as assessed shares
  per outcome with a confidence gate and the traversal fallback, replacing the clamped
  value-added ratio (`cc_clamped_overdistributes` stays as the reason); minting and burning per
  outcome sign (`Systems.Economy`); `Subgoals.Justice.Crime` admitting informed inaction under duty
  (8.15). Theorems to aim for: each outcome fully distributed (shares sum to 1 on its side); no
  share without assessed contribution; a duty-bound non-action is negative when the duty was
  feasible; no duty, no share for a bystander's inaction.
- Simulation: replace the per-action split (`assessed_parts`, 8.14) with outcome records per
  being and period, valued as the being's assessed change in V (one signed number per being, so
  the synergy between understanding and happiness stays in the outcome and nothing is left
  undistributed); MM_CE as a model estimating each contributor's counterfactual contribution with
  confidence, falling back to traversal; a world that moves on its own (hazards), so inaction can
  cause harm; contracts and duties as agents' commitments; reparation to harmed beings.
- Decisions needed: the unit of an outcome (per being's ΔV per domain and period, or per
  marker); the overdetermination rule; the sources of duty; the confidence threshold and
  traversal weights; the recipient of reparation.

**8.17 Author rulings on outcome-first distribution (settling 8.16's decisions).**
1. An outcome is an event; a metric model's measurement estimates its understanding, happiness and
   novelty per domain and per being.
2. Overdetermination is handled as specified: CC from metric models' assessments, Shapley-style
   (Benefuture currency: "approximates shapley-esque mechanisms"). Simulation reading, open to the
   author: Shapley shares sum to the outcome, and a contributor working against it has a negative
   share; following 8.14, positive shares are paid and negative shares penalised, each side
   normalised within [0, 1].
3. Laws are contracts once communicated, and adjudicable against the goals (Contract.txt: invalid
   when proven to harm them). A hazard one creates is direct harm; intent decides accident or
   crime; repair happens either way.
4. Confidence thresholds and traversal weights are set approximately now and governed later.
5. Reparation depends on the outcome's nature: harm destroys at the being level; harm to a commons
   affects every being using it; contributors' penalties fund the repair.
Candidate homes: L48 (committed counterfactual), L76 and L121 (duty from contracts and
communicated laws), L94–98 (outcome events, Shapley CC, minting and destruction by sign), L115 and
Crime.txt (intent; repair regardless), Justice.txt (reparation by the outcome's nature).

**8.18 [P] Coalition values for Shapley shares (simulation decision, open to the author).** Shapley
shares depend on what a coalition's value means. If an outcome happened only when its actor acted,
an agent who merely passes an upstream output on would be necessary and receive half of what the
output carried, contradicting the netting rule ("each link is credited for the value it added and
not for the volume passing through it", Benefuture currency) and `pure_intermediary_earns_zero_cc`.
The simulation instead takes a coalition's value as V of its members' summed effects, as the
causal-explanation model estimates them (each contributor's effect separable, an intermediary
replaceable), except that the actor's own effect counts only if the coalition can fund the action,
so co-funders whose money was needed share the outcome. With this, intermediaries earn almost
nothing, outcomes are fully distributed (Shapley efficiency), and co-funders are credited. When
the assessment's confidence is below its threshold, shares come from the L95 traversal: the
actor's outcome net of the upstream output it received, the co-funders' payments and the upstream
output as logged, by degree of separation. Candidate homes: Benefuture currency (Causal
Distribution), L94–95.
