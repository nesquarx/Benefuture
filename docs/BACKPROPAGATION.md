# Back-Propagation Audit: What Formalisation Found That the Sources Miss

Formalising Benefuture in Lean forced decisions the pseudocode and articles leave implicit, and proved
some properties that only hold under conditions the sources do not state. This document lists each
such nuance with its evidence and a proposed edit to the sources. Sections 1–6 are proposals the
author decides; section 7 lists edits applied to the sources as [P], awaiting ratification; section 8
holds simulation findings and the author's rulings on them, each with a status line where the
simulation, the Lean or the sources have followed. Items are never deleted: settled, superseded or
withdrawn ones are marked.

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
Status: resolved. L113 now opens with `Base_VW` and carries the domain-relative expertise term
`Re(Dn_i)/ΣRe(Dn_i)` (8.22.1).

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
Exponential vs subtractive decay (§3.4 of SPEC_DIVERGENCES; the Lean's lazy decay in §4.3 is
exponential) and one vs per-RelType partitions of unity (§3.2) remain open in the sources.

## 6. Process

**6.1 Three pseudocode copies diverged.** The root copy predated recorded decisions; it is now synced.
The third copy is the block embedded in `docs/articles/Benefuture.txt` (CLAUDE.md: edit all three or
none). Keep one source (spec/), or generate the others.

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
Status: the expertise half is resolved by 8.22.1 (L113's Re/ΣRe term; Lean `relative_expertise` in
`Governance.Democracy`); end-of-horizon conduct (B25) stays open.

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
Propagated to Domain, Benefuture currency (StandCoin) (articles).

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
Propagated to Domain (sub-domain reputation), Benefuture currency (StandCoin) (articles).

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
Propagated to Benefuture currency (StandCoin), Domain (novelty) (articles).

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
Propagated to Domain (novelty), Benefuture currency (StandCoin), Measurement (usable stage) (articles).

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
Propagated to Domain (weighted membership) (articles).

**8.13 Resolved by 8.14. Causal contribution along a transaction tree: range versus conservation.** L94 gives
CC a range of [0, 1], and `Systems.Substrate` computes it as clamped value added
(`causal_contribution_ratio`: (produced − received) / outcome, zero when either is non-positive);
L96 distributes rewards and penalties in proportion to CC, net of escrow paid. Along a chain with a
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
paid onward. Candidate homes: L94–96, Benefuture currency (Causal Distribution), `Systems.Substrate`.
- Finding (M3d, transactions): admitting every transaction that beats inaction, rather than G's
  single best choice, roughly triples floor growth and raises the share of executed work measured
  harmful from 2% to 9% (27% under model bias); settlement claws it back. Whether the screen should
  require more than beating inaction (a margin scaled to the model's uncertainty, as in 8.1) is
  open.

**8.14 Author ruling: outcomes are credited by their parts.** A positive outcome pays its
contributors and a negative outcome penalises its contributors; a mixed outcome is split into its
constituent parts by domain and by understanding and happiness impact. A part's side is decided by
its assessment against not acting (As, L48), not by the raw sign of a change. Each contributor's
share of a side is its part over the side's total, in [0, 1] as L94 states, so the chain of 8.13
pays A 10 and B 5 and penalises C 10. Candidate homes: L94–96 and Benefuture currency (Causal
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

**8.15 [OPEN] Harm through inaction when action was expected (a driver who does not brake).** Answered
in parts by 8.17.3, 8.22.2, 8.25.3 and 8.46 (status below).
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
- Status: answered by 8.17.3 (laws are contracts once communicated; a hazard one creates is direct
  harm), 8.22.2 (the braking driver), 8.25.3 (inaction is culpable only against a mandate) and 8.46
  (duties minimal but real). Lean gap fixed: `Subgoals.Justice.Crime`'s `h_culpable` admits
  `breachedDuty` (`informed_inaction_under_duty_is_crime`, `uninformed_breach_is_accident`).
  Simulation gap closed by M3e (hazards, guardians bound by contract).

**8.16 [P] Outcome-first causal distribution (author's outline; specification proposed).**
The author's model: there are no mixed outcomes. A measurement records an outcome, positive or
negative; a positive outcome generates currency (L97), a negative one requires destruction or
reparation (L99, Justice: Repair(Ha)). Metric models then assess each contributing action (and
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
communicated laws), L94–99 (outcome events, Shapley CC, minting and destruction by sign), L115 and
Crime.txt (intent; repair regardless), Justice.txt (reparation by the outcome's nature).
Propagated to Benefuture currency (Causal Distribution), Law (duties), Crime (hazards) (articles).

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

**8.19 Finding: duties and repair under hazards (M3e, `sim/README.md`).** With hazards in half of
all steps, unguarded domains lose about a sixth of their floor growth and the floor falls in twice
as many steps; guardians bound by contract recover most of it. What they miss for lack of notice is
accident, negligence is crime, and penalties fund repair either way. Toy assumptions: duty
fulfilled costs and earns nothing (contract payments are not modelled; L121 accolades for good
beyond duty neither); natural hazards with no guardian are not repaired (the sources do not say who
repairs harm with no contributor: the commons, insurance, or no one).

**8.20 Resolved by 8.22.3 (was [OPEN]). What SigThGv's adaptation measures.** SigThGv := Ap(Th ∈ Debatable? LqdBfDm :
Perturb(Th ± δ ∈ Fr)) (L157), with Ap the adaptation of L52 (`adapt«Ap»`). `Systems.ParamSpace`
gives the perturbation step ([R]: adopt a candidate within δ if admissible) but no selection, so
without adaptation the parameters walk at random inside the admissible region. The simulation
([P]) keeps a candidate only if the floors moved at least as well during its epoch as during the
previous one. Finding: over epochs of 50 steps this is a coin toss (half of candidates reverted),
because floor movement varies far more between epochs than any effect of a 0.02 change; outcomes
do not depend on the value parameters within that range. Questions: what does adaptation measure
(G's objective as measured, the floors, a parameter-specific outcome), over what horizon, and
against what comparison (the previous epoch, or a paired counterfactual from records)? Which
thresholds are debatable? Also: the simulation's own gates (currency eligibility, classification,
formation, overflow, the causal-assessment confidence) are not in `ParamVector`; adding them, with
their admissible ranges, would let SigThGv govern them.
Status: adaptation is experimental design (8.22.3; M4, `select_candidate_ref`, `gauge_radius_ref`);
the simulation's gates are listed in `sim/README.md` (Governed thresholds) but are not yet in
`ParamVector`.

**8.21 Settled by 8.22.1. Finding: raw reputation concentrates voting weight; the domain-relative term does not (M5).**
L113 adds expertise as Σŵ·Re in raw units to a base weight; with reputations in the hundreds, the
top expert in a domain holds about a third of all weight with no delegation at all, beyond the
reach of L114's delegation cap. The domain-relative term in Government's discussion (reputation as
a share of the domain's total, summing to 1) keeps nearly all the accuracy (98.0–98.6% correct
against 98.5%) with the largest holding at 13–21%. Decision needed (open in PLAN: carry into L113
and `Governance.Democracy`, or reject): adopt the relative term, and what expertise weight relative
to the base? The toy assumes skill sharpens judgement; how reputation relates to judgement in
reality is the open empirical question.

**8.22 Author rulings on governance, contribution types, adaptation and unassigned harm.**
1. Reputation in voting is normalised (domain-relative, settling 8.21). A domain may have only a few
   experts with meaningful reputation, one of whom holds 30% of the expertise weight when optional
   voters abstain; impact weight should still mitigate that. LqdBfDm should be scalable: a
   household decision works as well as global policy. Candidate homes: L113, Government.
   Status: L113's expertise term is Re(Dn_i)/ΣRe(Dn_i) in all three pseudocode copies; Lean
   `relative_expertise`, `relative_expertise_sum_one`, `relative_expertise_le_one`
   (`Governance.Democracy`).
2. Contribution types (L96: CD ∝ CC + N_CCtype): passing an output on outside any contract or duty
   is still a communicative contribution to the behavioural transaction substrate and earns an
   accolade, a minor share but a share; passing it under contract or duty is paid as completion of
   the contract or duty, not as contribution. The researcher who told a colleague of a new
   development that led to a project's completion gets an accolade share; the delivery driver of a
   rocket part gets the contracted share. A driver who brakes and saves a pedestrian gets the
   substrate's payment for using driving skill well and nothing else, and may face a clawback for
   the pedestrian's shock. Candidate homes: L96, L121 (Accolade), Benefuture currency (Causal
   Distribution), Contract.
3. Threshold adaptation (SigThGv, settling 8.20) is experimental design or gradient descent: gauge
   the threshold's freedom range, beyond which it is easily harmful; choose the outcomes the
   threshold is meant to improve; perturb within the range; observe; shift the threshold to the best
   performing value. Debatability is the escape: when someone proposes moving a threshold beyond
   the harm zone, a test case goes to a vote, and domain experts decide whether it is worth trying
   and at what scale; a success may redraw the threshold's harm boundaries once its outcomes are
   measured. Candidate homes: L157, Threshold of significance, Government.
4. Unassigned harm (settling 8.19): the administration repairs it through the commons, as insurer
   against every unassigned hazard to the extent of its capability. Catastrophe and black-swan
   tests are needed to see whether Benefuture adapts; the corpus has material on these.
   Candidate homes: Administration, Antifragility, L150.
   Simulation status: (1) M5, relative reputation by default; (2) M3d, `carry_fee_ref` in the Lean
   reference (the N_CCtype term of L96; L121 Accolade). [P] the fee comes out of the maker's
   positive share, and nothing comes out of a loss. ~~A prevention's duty payment at a governed
   rate on the harm avoided (`duty_payment_ref`).~~ Withdrawn by 8.24: a prevention is an ordinary
   recorded action. Gaming check on the fee: relays inserting themselves into a chain to collect
   accolades drain the maker's share; the accolade should require that the carrying was needed
   (the output would not otherwise have reached), which the causal assessment can judge. An M6 test.
   (4) M3e: the administration repairs unassigned harm from the commons, to what the commons holds.
   ~~[OPEN]~~ how the administration is funded (ruled 8.26.4: resource accounting and escrows; the
   balance stays open, 8.26.7): the pseudocode defines it (L106, CRUD of laws and
   infrastructure) and ranks its liability (L119) but names no fund; the simulation uses the pool
   balance overflow reinvests (L103), whose DirectedAutoInvest is directed by the entity, not the
   administration. Gaming check: harm passed off as unassigned escapes its contributor at the
   commons' cost; the causal assessment must find contributors before insurance pays. [P] repair
   from the commons is work paid its resource cost (L83), not the harm's value: value is minted to
   whoever does the work when its outcome is measured (screened: pricing at value repaired 0.7% of
   a catastrophe).
   (f) Black swans: outage, catastrophe, capture and breakthrough tested with native fallbacks.
   [P] during a measurement outage, payment falls back to escrow's prediction-based upfront and the
   actions stay unmeasured; candidate home L154 (Progressive) or the article on measurement.
   ~~[OPEN]~~ whether actions taken during an outage are re-measured once markers return (ruled
   8.26.5: yes, where possible).
   (3) M4: experimental design in randomised blocks (a fixed order was confounded by the trend in
   floor movement), shifting only on a gain of `gov_z` standard errors (Lean `select_candidate_ref`);
   the freedom radius gauged in the same rounds (`gauge_radius_ref`). [P] randomised blocks,
   significance in standard errors and the gauging rule as Perturb's method; candidate home L157.
   ~~Reading L25's significance threshold as the z-threshold.~~ Withdrawn: L25 measures value
   changes, not standard errors, and its bootstrap 0.5 made adaptation chase noise. Gaming check: a faction able to time its
   activity to a candidate's epochs could bias the trial; randomised order hides which candidate is
   live, so do not publish the schedule ahead of time.
Propagated to Government (1), Threshold of significance (3), Administration and Benefuture currency (4) (articles).

**8.23 Author ruling on degradation and enhancement (extending 8.22.4).** System Design and
Progressive complexity apply: any lack or corruption of capability, process, data or inputs is
handled by falling back to simpler heuristics and toy models, ruling and acting in practice; any
enhancement is consumed by researching and implementing means to use it better, keeping room for
the diversity–novelty balance axiom. For the simulation: every component that consumes a model,
measurement or record has a named simpler fallback, and the catastrophe tests check that the
fallback engages, that outcomes degrade gracefully rather than collapse, and that recovery follows
when the capability returns; a positive shock (a breakthrough) is tested for being put to use
without crowding out the pre-N sample. Candidate homes: Progressive complexity, System Design,
Antifragility, L142. Native: L154 Progressive (Cx↓ → Maintain, Degraded, Fallback; Cx↑ → Leverage),
and L151 Rc_Innovation.
Propagated to Progressive complexity (articles).

**8.24 Author ruling on parsimony, duties and gaming.**
1. Parsimony: add no mechanism unless sure the existing ones do not handle the case; ideally the
   simulation needs nothing beyond what the Lean provides. Pursue it though it is impractical in
   full, actively reducing complexity, and propose simplifications where the corpus double counts.
2. A duty fulfilled is no special kind of payment: the record of the duty event and its
   understanding and happiness outputs generate currency natively (L97 Cycle, L145 Mem → measure),
   which flows as causal distribution directs, and laws learn from the event.
3. Duties are not a separate set of rules binding people: freedom pushes against the encroachment
   of duties and laws, which protect only against outcomes beyond the freedom harm boundary.
4. Consider how each new mechanism can be gamed or maliciously complied with: a duty payment for
   braking would reward near misses with pedestrians.
5. Every modifier, gate and coefficient gets threshold treatment.
Candidate homes: Freedom, Law, Contract, AdvAp (L160), the article on causal distribution.
Propagated to Law (duties), Freedom (articles).

**8.25 Corpus simplifications from the parsimony audit ([R], ratified 8.26.4; applied to the three
pseudocode copies, the quoted Lean docstrings, the coherence audit and the Crime and Accolade articles).**
1. L99 `{J(Ha) ∨ RA ∨ CD(Bd)} → ⊖Bal`: a harm can be destroyed both through causal distribution of
   a bad outcome and through justice. L96 already routes disputes from causal distribution to
   justice; say that one harm is debited once, by causal distribution unless disputed.
2. Accolade (L121, Acknowledge(Gd > Duty)) and N_CCtype (L96) both weigh contributions by type.
   One home: the accolade is the N_CCtype weight for good beyond any contract or duty.
3. Crime's Inaction (L115) is culpable only against a mandate (L104 Law: mandate; a contract):
   say so, so no free-standing duty to act is read into it (8.24.3).
4. L142 Af's Redundancy and FailSafes and L154 Progressive's Fallback name one idea; Af could cite
   Progressive for degradation.

**8.26 Author rulings on repair pricing, carrying, scale, the commons and outages.**
1. Catastrophic repair prices recovery and prevention efforts by their predicted good, which is
   great enough to fund them (the corpus has this: TP_Gen, L86, prices a transaction by cost less
   predicted value). Repair and prevention are ordinary transactions, not a separate insurance
   price. Simulation: repair from the commons is priced by `transaction_price` (resource cost less
   accuracy × predicted good); the commons pays only a positive remainder. Still held: repair is a
   direct restoration rather than a repairer's recorded action.
2. Communicating an output needs no reward when it is contracted: the contract was worth more than
   the counterfactual of not taking it, since someone else would. If no one would have done it
   unprompted, it is a merit (an accolade). Held for future fixing: the simulation pays a carrying
   fee on every uncontracted carry (`carry_fee_ref`); it should pay only where the causal
   assessment finds the carrying would not otherwise have happened.
3. The debatable escape's scale is both a share of the population or domains and a limited time,
   decided by domain experts (L157 Debatable → LqdBfDm).
4. The commons fund is provided by resource accounting and escrows in general. Candidate homes:
   Administration (L106), L83 (resource cost), L86 (escrow), Benefuture currency.
5. Actions taken during a measurement outage are re-measured once markers return where possible:
   an attempt must be made, else outages can be gamed. As catastrophe prevention examines causes,
   which would uncover sabotage, outages are examined too. Candidate homes: L145 Mem, L146
   Tx → Trigger(MM_Me), L154 Progressive, Antifragility. Simulation: deferred measurements run when
   markers return, with extra noise (`remeasure_σ`, 0.3; the author: coarse post-outage records are
   noisy) and through the causal-assessment confidence gate, so a noisy late measurement falls back
   to the traversal. The unmeasured record stays and the measurement is appended (Mem immutable).
   An outage that never ends still hides negligence: examining its cause is an M6 item.
6. 8.25 ratified.
7. Resource accounting must eke out the commons by balancing resources, commons and gains; the act
   of reparation carries its own pricing, which can partly pay for it. [OPEN] the balance: the
   corpus has a resource-accounting contribution taken from credits that funds sophont baseline
   and shared infrastructure ("Life in Benefuture"), and supply tracks good less resource
   consumption less harm (Benefuture currency), but no rule for the share. The simulation's stage:
   the commons holds the resource costs paid for work, less what it has spent.
8. The framework is the insurer; insurance cannot be a business, or it becomes a mechanism of
   arbitrage. Simulation: the commons banks no surplus from a self-funding repair. Candidate homes:
   Administration, Benefuture currency, Anti-Corruption.
Propagated to Threshold of significance (3), Administration and Benefuture currency (4, 8), Measurement (5) (articles).


**8.27 Author clarification on resource accounting and scarcity.**
1. Resource accounting is a universal balance sheet: it calculates resource efficiency and adjusts
   thresholds to maintain the commons and baseline rates, funding both freedom (the sophont
   baseline) and insurance. Candidate homes: L83 RcAccounting, L143 S_BaselnIncm, Benefuture
   currency (Resource Accounting), Administration.
2. Benefuture is not a post-scarcity framework: it is a framework to discover and diminish
   scarcities. Candidate homes: Benefuture (introduction), Benefuture currency, L151 Rc_Innovation.
3. Held open: how the balance sets the commons' share (8.26.7), and whether the debatable escape is
   demonstrated on a threshold with a measurable effect (overflow against inequality, or the
   causal-assessment confidence), since the value parameters show none at current scales.
   Status: the second half is settled by 8.41 (demonstrated on the status bar relative to the
   alternative); 8.26.7 stays open.
Propagated to Benefuture currency, Critique addressal (articles).

**8.28 M6 finding: overpromising pays (screened; needs the author).** An agent whose plans fool
every metric model upward (`deceit` 1.0, a world property) in a toy domain of six equal agents,
300 steps:
1. Escrow works as written: the liar received 12,233 upfront on outcomes settled at 1,872, and
   settlement (`measured − upfront`) took the excess back. The models it fooled lost accuracy
   (0.77 → 0.63), for every agent in the domain.
2. Yet it ends richer: by 34% over its honest self and 28% over its peers. Screening (overflow off;
   decay rates varied) traced this to balance overflow, whose threshold rises with net relevance.
   With losses decaying faster than gains (λ₋ 0.05 > λ₊ 0.02, the simulation's default, not
   ratified; the Lean bootstrap has both at 0.05), the liar's doubled churn leaves net relevance
   (851 against 542), so overflow takes less from it. This contradicts the ledger asymmetry of the
   Reputation article (positive and negative reputation are summed separately and do not cancel),
   since L103's AccumThresh(Re_E, ...) is applied to the net. [P] key AccumThresh to the positive
   ledger discounted by the negative one weighted for loss aversion, or decay losses no faster
   than gains. Candidate homes: L101, L103, Reputation.
3. With symmetric decay it ends below its peers but still 3–9% above its honest self: fooled
   prices get more of its (genuinely positive) work through. [P] native defence: probabilistic
   escrow conditioned on the actor's own record (L84: Pay_t0 by P(As(V, A, t0) > 0); Benefuture
   currency: "overestimating models face ratcheting escrow requirements"), so a deceiver's upfront
   collapses without lowering its peers' prices. Candidate homes: L84, Benefuture currency.
4. Relay farming is bounded by the governed accolade rate (5% of the carried outputs' positive
   shares in the test world); ruling 8.26.2 (held) removes it where carrying was not needed.
Kept as `@test_broken` requirements in `sim/test/m6_tests.jl` until ruled on. Status: ruled by 8.29;
they are ordinary passing tests now (no `@test_broken` remains in `sim/test`).
5. Colluding voters (M5 world): normalised expertise holds a bloc of the most reputable fifth of
   experts (accuracy 97% → 93%); delegation amplifies a larger bloc's capture (30%: 85% without
   delegation, 70% with), since delegations flow to the most reputable. The cap holds per delegate.
   [P] model L114's bulk audit and retraction: delegators audit delegates' votes against measured
   outcomes and retract, a native defence to test next.


**8.29 Author rulings on 8.28.**
1. Mistakes decay slower than wins: that is what ledger asymmetry means (λ₋ < λ₊). Candidate homes:
   L101, Reputation (ledger asymmetry), `Systems.ParamSpace` (an admissibility constraint).
2. Models estimate from track record: the same action is valued by who takes it and in what state
   (a diabetic pays more for a pastry than an athlete; anyone pays more for a fifth pastry in a
   day). A deceiver's record of overpromising is part of what models use to price its next action.
   Candidate homes: L84 (P(As(V, A, t0) > 0)), L86 (MM_Pr(V ← A)), Measurement, Benefuture currency.
3. Delegation is audited and retractable (L114). Colluding experts whose votes prove suboptimal
   lose reputation, though suboptimality is not always apparent; diversity at scale captures data
   on other options locally (discovered through the diversity–novelty balance); deliberation
   helps. Not a fully solved problem: the final hope is that collusion's suboptimal results are
   aired by adversarial adaptation (AdvAp, L160) or anti-corruption (L159). Candidate homes: L114,
   Government, Anti-Corruption.
   Status: (1) `Admissible` gains λ₋ < λ₊ in `Systems.ParamSpace` and the reference (bootstrap λ₊
   0.05, λ₋ 0.02); the simulation refuses losses decaying faster than gains (equal rates only as the
   reduction to M2). (2) Models correct each actor's estimates by its recent errors
   (`track_window`, 20, governed). Together they end 8.28's finding: over 8 seeds the liar acts and
   is paid as an honest agent and ends no richer beyond noise. (3) M5: votes earn or cost
   reputation by the weight cast once outcomes are apparent, and delegations are audited and
   retracted; against a bloc of the top 30% with delegation, accuracy 65.5% → 96.1% and the bloc's
   expertise share 0.80 → 0.03. Gaming check, measured: a bloc defecting only where outcomes will
   not become apparent keeps most of its expertise (0.80 → 0.51) and lowers accuracy on hidden
   decisions to 69% (99% on apparent ones); the diversity at scale, deliberation, AdvAp and anti-corruption
   the author names are the remaining defences, not yet modelled.
Propagated to Reputation (1), Measurement (2), Government (3) (articles).

**8.30 Author rulings on outages and collusion defences.**
1. A sabotaged outage is examined as an outcome: the lost measurement is its harm, and causal
   assessment and justice find its contributors, so a saboteur is penalised through causal
   distribution.
2. AdvAp is a whole global mechanism, deliberation needs social networks, and diversity is an
   axiom at global scale; build diversity or AdvAp first, as a mechanism reusable elsewhere.
   Simulation: diversity first, as a split trial (alternatives tried side by side on shares of the
   scope, compared by `select_candidate_ref`), reusable for the debatable escape (8.26.3), M4's
   experiments in space rather than time, and the diversity–novelty balance's pre-N sample (L158 Di_N_Balance).
3. (Author, on the split trial) By the diversity–novelty axiom the alternative is never forced on
   anyone: it is subsidised elsewhere, by novelty bonuses, until some local body chooses it.
   Simulation: each locale judges the options by its own noisy reading and takes the alternative
   when its estimate plus the novelty bonus favours it; the share trying it is chosen, not set. A
   significant trial makes the outcome apparent, and an alternative proved better is adopted.
   An earlier version imposed a fixed share; withdrawn.
8.30.1 status: an outage harms the beings who lose its services and is examined when markers
return; traced to a saboteur (`p_trace`) it is a crime of informed volition penalised through
causal distribution, else its harm is insured through the commons. Repair's predicted good now comes
from the domain's best model with its error, not the measured harm; with mildly inaccurate models
(the realistic case, per the author) repair still funds itself.
Propagated to Measurement (1), Diversity (3) (articles).

**8.31 Author ruling on imperfect agents and friction.** Agents are not perfectly rational: their
choices carry a noise gate with a random maximum per person per domain (a general reflection of
personal abilities), noisily inverse to expertise. Following epistemic antifragility, the
simulation should demonstrate convergence under heavy friction. Candidate homes: Being, Measurement
(noise), Antifragility, Progressive complexity.
Simulation status: per-person, per-domain ceilings on choice noise (`ability_caps`, `choice_noise`)
for voters and locales in M5; from inverted reputations under heavy friction, decisions converge
to the accuracy true reputations give within a few hundred decisions. Screened on the way: easy
decisions left every rule near perfect, so comparisons of voting rules now use hard decisions.
Next: the same ceilings for agents' choices in M3c (co-funding, guardians) and an M3c run with every
noise source at the top of its range.
8.31 status (economy): co-funding is a judgement: an expert pledges only if the screened prediction plus its choice noise (personal ceiling per domain, inverse to skill on average) is positive.


**8.32 Finding: the currency-eligibility threshold is a cliff under heavy friction (screened; needs
the author).** M3c world, 8 agents, 300 steps, 3 seeds. Each noise source at the top of its range,
one at a time: markers, model bias, classification, cost, regeneration, memory loss,
participation, attribution and hazards with weak guardians leave convergence intact (floor growth
145–185 against 182 clean). Two break it: model error at σ 2 (accuracy 0.35) and agents' execution
noise at 2 (accuracy 0.55), floor growth about 2. All the robust sources together still converge
(70.5), but with accuracy at 0.56, on the threshold's edge; adding moderate model error (σ 1) or
execution noise (1) stops every currency pricing at once (floor growth about 0; only the StandCoin
lane runs, about 67 actions in 300 steps).
Two causes:
1. Accuracy (`1/(1+√MSE)`) is absolute: it blames models for outcomes no model could predict (an
   agent's execution noise), so friction that is nobody's error disqualifies every model alike.
2. The eligibility gate (L82, Acc > Th) duplicates what probabilistic escrow already does by degree
   (L84, L86: upfront is accuracy × predicted value, the rest held), and turns a gradual loss of
   confidence into a cliff, against Progressive (L154: degrade, fall back).
[P] candidates: (a) accuracy relative to what is achievable, a skill score against a naive
baseline, so aleatoric noise does not disqualify; (b) let the best available model price below the
threshold, with escrow holding by its low accuracy, the threshold then ranking currencies rather
than switching them off; (c) the threshold governed down by SigThGv under friction, within its
freedom range (novel leaves never below 0.5). Candidate homes: L82, L84, L154, Measurement.
Kept as a `@test_broken` requirement in `sim/test/friction_m3c_tests.jl`. Status: ruled by 8.35–8.36;
it is an ordinary passing test now (no `@test_broken` remains in `sim/test`).


**8.33 Author ruling: nothing is perfect, in the world or in the work.** The simulation need not
model perfect models, perfect people or perfect processes: all are impossible. Benefuture's logic
applies to the work itself: truth levels cannot reach 1. Simulation: every world default is mildly
imperfect (the low end of each realistic noise range), exact worlds appear only as limiting cases
in tests, and claims are stated with their confidence and assumptions.
Laundering (M6): harm dumped outside what an action measurably touches is examined as an outcome of
no apparent cause, as outages are; it pays only when practically untraceable (+2% at a tracing rate
of 0; a loss from 0.1). The tracing rate is the frontier to defend: anti-corruption (L159) and AdvAp
(L160), which reward exposure, are its native levers.


**8.34 Ruled for now (below; was [OPEN]). Does a fork divide the base vote?** L122 has a fork split social power (SoPo: C, Re,
...); the Being article treats near-identical patterns as a domain pattern, not identities; L113
gives every voter a base weight. If each identity gets its own base vote, forking is a sybil attack
on voting. M5 world, 100 voters, one forker voting one side: with the base vote divided among a fork
family, forking gains nothing; with a base vote per identity, 50 copies cut decision accuracy from
99.5% to 92.8%, 100 to 74.5%, and 200 capture every decision. [P] the base vote is part of the social
power a fork divides, and a copy earns its own only as its novelty N (L122) separates it into a
distinct identity. Candidate homes: L113, L122, Being, Government. Simulation: `fork_rule`, default
`:divided` (the proposal), `:per_identity` measured.


**8.34 ruling (for now).** Yes: a fork divides the base vote with the rest of its social power, and
a copy earns its own only as its novelty separates it into a distinct identity. More nuance later.
The simulation's default (`fork_rule = :divided`) stands.
Propagated to Being (articles).

**8.35 Author rulings on 8.32 (model accuracy and currency status) and on forks.**
1. Options (a) and (b) together: accuracy as skill, and escrow scaling trust continuously.
2. The threshold (L82) is a status threshold: which models may back a currency. At least 0.9 for
   established sub-domains; at least 0.75 for new or very coarse ones; 0.55 only for discovering
   something with no precedent ("magic").
3. Accuracy adjusts for all convolving noise (what the outcome carries that no model could predict:
   measurement, the actor's execution); its reference echoes the state of the art's understanding of
   the domain's spread of outcomes. Corrected by the author: accuracy 0 is no better than random
   guessing, not than the domain's average (that is skill, which competition between models, L82,
   already handles). Models predict with credence; accuracy is the quality of the credence match
   (a proper score, calibration); the credence is what feeds probabilistic escrow (L84: Pay_t0 by
   P(As(V, A, t0) > 0)). [P] accuracy = (B_random − B_model) / (B_random − B_ideal) on the Brier
   score of credences that an action's assessed value is positive, B_ideal the best attainable given
   the convolving noise; escrow's upfront = credence × predicted value. Awaiting confirmation.
   Superseded by 8.36 (accuracy = 1 − Brier_model / Brier_random, not adjusted for noise).
4. Below the threshold, work goes to StandCoin: permissiveness is a race to the bottom; today's
   coarsest models already exceed 0.75 in probabilistic accuracy, so nothing worse should back a
   currency.
5. Forks (refining 8.34): human birth is a merge of two forks, partialised by memory loss; by the
   time personhood suffices for a relevant vote, enough novel identity and reputation has accrued
   for a fresh base vote. A base vote follows novelty and personhood, not identity count.
Candidate homes: L82, L84, Measurement (accuracy), Being, L113, L122–123.
Propagated to Measurement (2, 4), Being (5) (articles).

**8.36 Author rulings: credence and accuracy (settling 8.35's proposal).**
1. Start simple: a model's credence that an action's assessed value is positive (L84). The goal is
   a model predicting a U/H/N marker from other marker inputs, history included, and stating a
   single credence for that outcome; it may hold a full distribution for a transaction, but only a
   single credence is reducible to currency (it feeds probabilistic escrow).
2. Accuracy 1 is perfect prediction, generally unattainable: accuracy = 1 − Brier_model /
   Brier_random (random guessing, credence 0.5, scores 0.25), so no ceiling adjustment.
3. The status thresholds (0.9 established, 0.75 new or coarse, 0.55 for the unprecedented) apply on
   that scale: 0.5 is halfway from random guessing to perfect.
Candidate homes: L82, L84, Measurement (accuracy as credence quality).
8.36 status: credences (`credence_ref`: predicted value over the model's uncertainty, through the
normal distribution function, capped at `max_credence` 0.99 since truth levels never reach 1) feed
probabilistic escrow; a model's uncertainty is its own track record, per actor once there are a few
records (8.29); accuracy is `credence_accuracy_ref` over a window of 100. Status thresholds 0.9
(established leaf), 0.75 (novel leaf, coarse parent), never below 0.55; below them, StandCoin. Model
error is now relative to the domain's natural spread, and realistic noise ranges top out at the edge
of a functional domain (accuracy about 0.75). Measured: with every noise at its realistic top,
pricing thins but floors still rise (about 14% of clean growth; 9% after the scoring correction in 8.38's status); far beyond, no currency qualifies.
The author's point on noise adjustment (it would rule out models that turn noise into mechanics) is
kept: accuracy is not adjusted for noise.
Propagated to Measurement, Benefuture currency (escrow) (articles).

**8.37 Finding: under status thresholds a deceiver can take a domain's currency down (screened;
needs the author).** M6 world (six agents of moderate skill, 0.3): the leaf model's accuracy hovers
near the 0.9 bar even without a liar (0.83–0.88; marginal work makes the sign of outcomes uncertain).
A liar fooling every model lowers it further (to 0.74–0.86 with track records), so the domain loses
status more often and everyone's work falls (peers' actions about 20–40% lower); deceit itself does
not pay. Without track records the liar drives accuracy to 0.16–0.37 and the domain loses status
outright: peers act 0–19 times against 210–929 in an honest world, a denial of service, while the
liar itself barely acts. Candidate native defences: accuracy computed per actor as well as per model,
so one actor's record cannot disqualify a model for everyone; and the track record (8.29), which
already limits it. Candidate homes: L82, L84, Measurement.

**8.38 Author rulings on 8.37 and the debatable escape.**
1. A deception, once uncovered, is adjusted for in every case: that is part of repair. What it
   corrupted is restored as well as what it harmed: the records it falsified (models' scores, prices
   built on its claims) are corrected, and its costs (the audit, the reward for revealing it) are
   charged down its causal chain. So a deceiver cannot take a domain's currency status down for long:
   once uncovered, the models it fooled are re-scored on what they would have predicted without the
   falsified input. Candidate homes: L160 AdvAp (reveal → adapt), Justice (restorative), L82
   (accuracy), Measurement, Crime (informed falsehood).
2. The debatable escape's threshold (8.26.3) is another governed threshold. Whatever it is set to,
   a demonstration must show at least gains greater than harms and no irreparable harm. Candidate
   homes: L157 SigThGv, Harm (irreparable), Threshold of significance.
3. Held: 8.26.1–2, 8.26.7. Next: AdvAp (L160) and the remaining defences (deliberation,
   anti-corruption).
Status (economy, M3c): AdvAp as reports read from the open log, audits by the significance rule
against other actors on the same models and by examination of cause, and repair of the falsified
records; the reporter's reward (`advap_reward_ref`, a share of the overstatement repaired, at least
a floor) and the audit are charged to the deceiver (`advap_liability_ref`); unfounded reports cost
nothing in good faith, their audits past a frivolous pattern (`report_penalty_ref`). Readings in
`sim/README.md` (Adversarial adaptation): repair lifts the blockade 8.37 describes in most worlds,
honest worlds draw almost no reports. Screened on the way, and corrected: models scored on actions
they had not quoted used estimates neither deceit nor the track record reached, so a model's own
bias could hold a domain below its bar; and audits against zero found every honest actor
overstating (selection and model bias). 8.37's tracked case is restated: in a marginal domain a
liar can keep it from ever qualifying (2 seeds of 6), and otherwise raises activity.
Status (governance, M5): the manufactured prisoner's dilemma. After a hidden defection a bloc member
may weigh revealing it, and reveals when the reward beats its share of the bloc's gain and its
loyalty, by its own noisy judgement; an established revelation strikes the bloc's votes from the
falsified decisions, recounts them, and debits each falsified vote as wrong (the revealer keeps its
reputation; the rest of the bloc is charged). Against the stealthy bloc of 8.29.3 (top 30%), hidden
decisions end 99.7% right against 79.2%, and the bloc's expertise share falls from 0.74 to 0.15.
[P] Repairing a decision means recounting it without the falsified votes: AdvAp's revelation is the
evidence that makes a hidden decision's corruption apparent even where its outcome is not.
Candidate homes: L160, L113–L114, Government, Adversarial adaptation.
[P] Exploit gain in the reward: in an economy with probabilistic escrow, deceit's gain is what
settlement could not claw back (nothing, here); the reward then rests on the harm prevented.
Candidate homes: L160, Adversarial adaptation (reward structure), L86.
Propagated to Adversarial adaptation and Justice (1), Threshold of significance (2) (articles).

**8.39 Finding: a liar can raise a marginal domain's activity (screened; for the author's
attention).** Six agents of skill 0.3, the leaf model's accuracy near 0.9: in 3 seeds of 6, a liar
fooling every model raises everyone's actions (peers 692–829 against 210–442 honestly) and the floors'
growth (about twice). Its overstatement, partly corrected by the track record, gets more of its
own positive work past G's floor check, and the activity keeps the domain's records fresh. G is
conservative where models are noisy and the track record removes the selection bias from estimates,
so honest marginal work is often screened out. Not a defect of deceit's accounting (it does not
pay); a sign that marginal domains under-act. Candidate native levers: the diversity–novelty
balance (L158) trying screened-out work, and the status thresholds' governance (L157).

**8.40 Finding: which threshold the debatable escape is demonstrated on (needs the author).** The
escape's acceptance is built (Lean `escape_accept_ref`: adopt only if the proposal beats the
incumbent by the significance rule, its gains exceed its harms where tried, and it caused no
irreparable harm; 8.38.2). For the demonstration, a threshold with a measurable effect is needed
(8.27.3: the value parameters show none at current scales). The established-leaf status threshold
has one, in one direction: eight leaves, 16 agents, 3 seeds, the bar set world-wide:

| Skill | Bar 0.95 | 0.9 | 0.8 | 0.7 | 0.6 |
|---|---|---|---|---|---|
| 0.3: floor growth (losses) | 65.9 (−95) | 67.5 (−100) | 67.3 (−48) | 68.4 (−42) | 68.5 (−38) |
| 0.15: floor growth (losses) | 7.7 (−177) | 9.4 (−233) | 7.2 (−13) | 15.1 (−34) | 19.6 (−34) |

Where no leaf model reaches 0.9, work falls to the coarse parent model or to StandCoin, which price
worse than the leaf model would; lowering the bar admits fewer harmful actions, not more. An escape
proposing a lower bar in a low-skill domain would likely be adopted, against the spirit of 8.35
("permissiveness is a race to the bottom"). Options: (a) demonstrate on the status bar anyway,
the escape deciding locally and temporarily; (b) choose another threshold (the causal-assessment
confidence, overflow, the delegation cap); (c) read the result as a sign that the bar should be
relative to the alternatives a domain has (a leaf model at 0.7 against a parent at 0.75 with coarser
errors), a refinement of 8.35. Candidate homes: L82, L157, Measurement.

**8.41 Author ruling on 8.40.** Option (c): the status bar is relative to the alternatives a domain
has, and a local trial is still needed to demonstrate it. Simulation: Lean `relative_bar_ref`
(a leaf model backs its currency if it matches the accuracy of the qualified currency its work would
otherwise fall to, up to the established bar 0.9, never below the coarse bar 0.75, which stands when
the alternative is StandCoin), proposed as a debatable escape and tried on half the domains for 100
steps, compared by domain and epoch and accepted by `escape_accept_ref`. Eight leaves, 16 agents:
in low-skill domains (0.15) the trial adopts it in 2 seeds of 4 (trial arm 39.6 and 31.5 per domain
and epoch against 20.4 and 6.2; harms 7 and 3 against gains 799 and 632) and finds no improvement in
the other two; in capable domains (0.3, 0.6) it is rejected as no better. With the bar set
world-wide, losses fall by half at skill 0.3 and by an order of magnitude at 0.15. The toy's losses
are all passing harm, so irreparable harm is a world classification (`irreparable_loss`, none by
default); where much smaller losses count as irreparable, the same proposal is rejected. Process
reading: governance, anti-corruption and adversarial adaptation are now native in the simulation;
anti-corruption needs no mechanism of its own, since Lean's `good_strictly_easier_than_bad` is
carried by restorative friction (causal-distribution penalties, AdvAp liability) and distributed
power (delegation cap, overflow). Candidate homes: L82, L157, Measurement, Anti-Corruption.
Propagated to Measurement (articles).

**8.42 Author guidance on 8.39, on better models, and on monoculture.**
1. The more overstatements are uncovered, the more scrutiny they should bring: thresholds ratchet
   with each one (Benefuture currency: "overestimating models face ratcheting escrow requirements").
   AdvAp should work overtime in marginal domains, to solidify them.
2. Every domain should get more accurate models as Benefuture progresses. Causal discovery is hard
   to simulate; the simulation may state openly that it assumes better models keep being produced
   (a safe bet given the framework: L82 competition, L49 adoption) and show that those models take
   over measurement and prediction in the economy and in governance, and are overtaken when they slip.
3. Monoculture (L158 Di_N_Balance) is any paradigm homogeneity: model proliferation, vote decisions,
   technology or process uptake, cultural progression. Candidate homes: L158, Diversity, Progressive.
4. (Author) All decisions access full records; the reputation ledgers exist to detect patterns of
   mistakes or deception as well as of success, honesty and excellence; their entries never decay,
   only the rolling net does. AdvAp working overtime means arranging the environment so it does,
   not forcing it.
Status of 1 and 4: escrow's credence is pulled towards a coin toss by the negative share of the
actor's ledgers (Lean `ratchet_credence_ref`); readers' attention, a world property, follows
negative patterns and their own stake in a marginal domain. Over 24 seeds of the marginal liar world,
AdvAp cuts blocked domains from 9 to 3 and attention following the ledgers triples the deceptions
uncovered (4.2 → 14.2); activity moves within the bistable spread. In this toy the escrow ratchet is
inert where settlement follows within the step (balances move by measured value less cost).
Status of 2 (economy): a pool of competing models per domain, new ones arriving as a stated
assumption; each scored on the open log, each stating credences from its own record, a challenger
taking over when it beats the incumbent by the significance rule. Better models take over the
domain's own pricing (leaf 1 priced by its own currency 100% against 70% mid-run) and a captured
model is overtaken (73% against 0% during capture); floors grow about as much.
Simulation reading of 2 in governance: models do not vote (delegation goes to experts, and full
delegation is not permitted); they inform votes, as expert commentary does, and voters weigh each
source by its audited record, which is the truth-level tagging of clean deliberation (Government).
Propagated to Benefuture currency (1), Adversarial adaptation (1, 4), Diversity (3), Reputation (4) (articles).

**8.43 Finding: deliberation over shared sources makes votes dependent (screened; needs the author).**
Clean deliberation simulated (M5, 100 voters, hard decisions, 1,200 decisions, 3 seeds): before voting
each voter hears its own reading, five contacts' and the domain's models' published predictions,
each weighed by the rolling net of its audited record of published readings (log-odds of accuracy,
the optimal weights for independent binary judges: Nitzan and Paroush, 1982). Decisions right in the
last third: alone 92.8%; with contacts 91.2%; with models (noise 5 → 0.5, assumed improving) 85–86%;
with models alone 72–86%. As models improve their share of the weight in readings rises to 0.7–0.95
(they take over prediction), and a captured model loses its weight entirely. But every voter weighing
the same sources correlates the votes, and the decision tends to those sources' own accuracy: a
crowd of independent experts aggregates better than any source weaker than its aggregate (a model
right 85% of the time pulls the decision from 93% to 85%). Herding by shared information is a
known result (Lorenz et al. 2011, PNAS: social influence undermines the wisdom of crowds; Ladha 1992:
correlated votes weaken Condorcet's theorem), and the monoculture of 8.42.3 at the level of votes.
Options: (a) votes stay on voters' own readings, and shared sources enter the decision once, weighed
by their records (a published input to the tally beside L113's person weights; a new rule); (b)
deliberation informs only voters without expertise in the domain (those whose own record is weak),
experts voting on their own judgement (the Government article's "experts are expected to exercise
their own judgment"); (c) leave deliberation free and rely on Di_N (L158) to keep alternatives
alive. Candidate homes: Government (clean deliberation), L113–L114, L158.

**8.44 Author ruling on 8.43.** Deliberation trickles understanding down from higher reputation and
across between peers; it rarely influences a higher reputation from a lower one. An expert has no
reason to listen to a layman, except for the rare novel input that raises understanding for both.
Simulation: a voter weighs a source (person or model) only if the source's record is at least as good
as its own, or, rarely (`p_novel`), when the source brings novel input. Candidate homes: Government
(clean deliberation), Education (understanding shared, not moved), L113.
Propagated to Government (articles).

**8.45 Finding on 8.44: echoes count information many times (ruled below).** Deliberation now
trickles down and across only (a voter weighs a source whose record is at least its own, rarely a
weaker one for novel input), and the social network's information handling (L133 IH: SourceVerify by
Re(Dn)) surfaces the domain's most reputable sources. 100 voters, hard factual decisions, 3 seeds,
right in the last third: alone 92.8%; five random contacts 91.4%; IH's ContentionMap (the most
reputable on each side) 83.5%; IH and models improving to noise 0.5 89.0%, to 0.3 89.6%. Screened: no defect found; the mechanism is that in this
toy every decision is purely factual and every voter carries a full base vote (L113), so each layman
who echoes an expert or model casts that source's information again with its own weight; a few
sources' information is counted many times and outweighs the middle ranks' independent readings
(laymen alone cancel out as noise). Real decisions mix values (impact, preferences), where an echo
double-counts nothing. Options: (a) count information once: the share of a voter's reading that came
from sources it heard passes to them as fractional delegation (L114, capped), the voter keeping the
share that is its own; (b) separate a decision's factual part (weighed by expertise, informed by
deliberation and models) from its value part (base and impact weights, one person one share); (c)
make the base vote optional where a voter's reading is mostly borrowed (L113's optional threshold).
Candidate homes: L113, L114, Government, IH (L133).
Contention (author: the real test is experts divided, voters listening to all and judging by IH,
diversity and their own limited expertise): the network's ContentionMap surfaces the most reputable
sources on each side; with two expert camps of equal standing, one leaning by an honest bias,
contested decisions end right 86.7% with deliberation and split trials, against 80.7% with trials
alone and 75.8% with neither (`sim/README.md`, M5).
*Author ruling (8.45 resolved):* echoes must not count information many times. Information handling's
source tags (L133 IH) must not let an echo pass for a source: a reading carries the tags of the sources
it came from, a voter hearing several contacts that repeat one source hears that source once, and the
borrowed share of a voter's reading is not counted again as an independent source. Implementation
reading, [P]: the borrowed share passes to the tagged source as fractional delegation, capped (option
(a), L114), the voter keeping its own share. Candidate homes: L133 (IH), L113, L114.

**8.46 Author ruling on duties.** Contribution and participation at some level is a duty: voting is
mandatory above a threshold, and so is taking care not to harm others in obvious ways. The line where
duties become recommendations is itself a governed threshold. This settles the Government article's
list of duties against 8.24.3 (duties stay minimal, not absent). Candidate homes: Law (Duties,
Responsibilities), Government, L113 (mandatory voting threshold), L157. Propagated to Law (articles).

**8.47 Finding: nothing in G blocks a small sacrificial trade-off in the toy (ruled below).** M7
(deaths): G's floors are taken over the decision-time population, a life a plan would end keeping its
place at the bottom (Lean `removal_cannot_raise_floor`, and for the quantile
`removal_cannot_raise_quantile_floor`). That bound covers lowering levels with no one else gaining. A
plan that removes fewer beings than the quantile's rank and lifts everyone else raises the thresholded
quantile floor (L74: min := Th_quantile): with 50 beings, removing the two worst-off and giving the
rest +3 raised the 10% quantile in 20 trials of 20, and G chose it; only the literal minimum stays
down. Freedom is a subgoal reported per plan, not a filter on G (SPEC_DIVERGENCES §8.8 [R]: a filter
fails tragic choices), and should emerge from V's convex harm weights; but valuing the deaths in the
irreparable tier (Ha_wt, L61) still leaves the plan's total value positive (143–336 against the deaths'
−55 to −168 each), so Freedom does not emerge here, though Fr, reported, marks the plan impermissible.
(A first version of the simulation filtered G by Fr, against §8.8; withdrawn.) Candidate native
answer: harm over the long-term window (Ha_lt): a death forecloses all of a being's future
understanding and happiness, which the toy's one-step drop to the bottom undercounts. Options: (a)
value a death over Ha_lt (its foreclosed future), (b) take G's floor as the literal minimum where lives
are at stake, (c) accept that Fr's emergence needs dominance (`dominated_plan_not_chosen`) and that
organ-harvest cases are left to law and contract. Candidate homes: Benefuture goals, Freedom, Harm, L61,
L74, L135; conjecture A36.
*Author ruling (8.47 resolved):* generally the standard trolley rules (redirecting harm so that fewer
are harmed is acceptable), but prefer to avoid irreparable harm traded against non-breakthrough gains.
Implementation reading, [P]: option (a), a death valued over the long-term window (Ha_lt, its
foreclosed future) in the irreparable tier, so that irreparable harm is outweighed by preventing more
irreparable harm, or only by a breakthrough-scale gain, never by ordinary gains spread over the rest.
The preference stays inside V and G (§8.8: Freedom reported, not a filter). Open: whether doing and
allowing differ (the footbridge and organ-harvest variants), which the standard rules split on.
Status (M7, [P]): Lean `foreclosed_ref` (a life's levels plus its predicted growth over the long-term
window) and `life_value_ref` (∓ breakthrough scale × the irreparable tier's weight × that foreclosed
future, a life saved against not acting counting as much as one ended), inside ΣV; G's floors keep the
decision-time population. In 20 trials of 50 beings the trolley switch (five die by default, one if
switched) is chosen unless the one holds the peak of understanding (8.55); the reversed switch never;
the sacrifice of the two worst-off for +3 to the rest is no longer chosen (its value about −500 against
an uplift's positive one) though its quantile floor still rises; +30 to the rest (a breakthrough-scale
gain) outweighs it at the default scale 20 and not at 1000. Doing and allowing are not distinguished:
the footbridge would read as the switch. The scale and the long-term window are governed thresholds.

**8.48 Author ruling on normalisation.** Normalising reputation must not reduce anyone's net
reputation when someone surpasses them: only vote weights are normalised, because they scale
oddly; "I have not done less if someone else has done more, yet they may have more to say."
Status: the simulation normalises only at the vote (M5's expertise weights; L113's Re/ΣRe; Lean
`relative_expertise`); ledgers and the rolling net stay absolute. A right vote earns reputation in
proportion to the weight share it cast (its causal contribution to the decision), so as others grow
each vote earns less, while the record already earned stays whole. Propagated to Government (articles).
Candidate homes: L113, Reputation, Government.

**8.49 Finding: research as spending has an uplift optimum; teaching and research are complements.**
M7, 100 beings. Teaching is one to many, at any level downstream, reception varying; only research
extends the frontier, apart from rare in-job innovation near the top (author). Research is spending
(author): a share of beings' time and the commons' resources, a very noisy chance of success rising
with the researcher's understanding and novelty, gains teachable or tacit. Uplift (floor and median of
understanding) peaks near a tenth of time on research (floor 30 against 4 with none and 4 at 80%);
beyond about a fifth, research spending harms uplift while the peak keeps rising and concentrating
(top decile 18% → 48%). At a tenth, teaching raises floor, median and peak together (floor 16 → 38,
peak 29 → 42 for ε 0 → 0.6): more beings near the frontier make research succeed more often.
Screened: with research as one option in G's single choice, lessons outvalued it and the frontier
stalled (an artefact of the menu, withdrawn); level-independent ordinary plans had carried the peak
(the author's question exposed it); a breakthrough first landed a researcher at the peak whatever its
level; diverted time first cost nothing. [P] research share is a governed threshold (L157), the
diversity–novelty balance (L158) its trigger when spreading's marginal value stalls. Candidate homes:
L151 Rc_Innovation, L158, Education, conjecture B17.

**8.50 Author ruling: G is not a global bottleneck.** Every entity runs its own messy approximation of
G, messy because its inputs approximate reality messily. Simulation: each acting entity reads the
world through its own noisy view, predicts its options' effects with its own error, and chooses by the
Lean rules (`choose`) among its own options; many entities act each step, concurrently. A single global
G choosing one plan a step (M0, the first M7 rungs) is a limiting case, kept for tests. Candidate
homes: L74 (Goal), Benefuture goals, Decision, Being.
Status (M7): with G per entity, about 17 of 100 entities act each step; uplift peaks near a fifth of
time on research (floor 50) rather than a tenth, and the floor grows more than under one global G
(49 against 30); exact inputs never let the floor fall, messy ones (σ 1) in 1.7% of steps. Concurrent
lessons first summed past their teachers; capped at the best teacher a learner met.
Later (author): simulate noise as hidden convolving factors and let models evolve to capture them,
an evolutionary search towards minimum-description-length models, more informative than
random-number noise.


**8.51 Does balance overflow boost reputation? (ruled below).** Benefuture currency
(Aspects) says accumulation beyond the needs threshold "boosts Domain-specific Reputation and is
redirected into reinvestment in that domain"; Reputation says reputation is earned, and "cannot be
purchased, traded, or transferred". If overflowed balance raises reputation, money above the threshold
buys standing, against the second. The pseudocode is silent: L103 (BalOvflw) only redirects the excess
(DirectedAutoInvest) and L100 builds reputation from causal contribution and novelty. The simulation
follows L103: overflow reinvests and leaves reputation untouched. Readings: (a) the boost is the
reputation the reinvestment earns once its outcomes are measured, through ordinary causal
distribution (then the currency article should say so); (b) overflow itself confers no reputation (drop
the clause); (c) a direct boost (Reputation and L100 would need an exception). Candidate homes: L100,
L103, Reputation, Benefuture currency.
*Author ruling (8.51 resolved, reading (a)):* the currency article was wrong. Overflow is reinvested
(L103); if the reinvestment does good, it earns reputation through the standard channels (L100). The
article is corrected, and the Lean definition `overflow_to_reputation_gain` with its theorem
`overflow_awards_strictly_positive_reputation` is removed (Democracy.lean keeps a note).

**8.52 Author ruling on births.** Models predict a birth's outcomes as an optimistic average, at
sufficient confidence that the birth escrow pays for what the baseline cannot cover. So a newborn's low
initial understanding does not drag G's floors as a fresh low: the plan that includes a birth is valued
by the models' predicted trajectory for the newborn, and the escrow (posted by those causing the birth)
covers the gap between the newborn's needs and the baseline until the prediction is borne out.
Implementation reading, [P]: the optimistic average is the mean of the model pool's predictions above a
governed quantile, accepted when the pool's confidence clears a governed threshold; the escrow is sized
to the predicted shortfall below the baseline over the dependency window, and settles against measured
outcomes like any escrow. Candidate homes: Government (Birth), L68, L74, the escrow lines.
Status (M7, [P]): Lean `optimistic_average_ref` (mean of the pool's predictions at or above its
q-quantile), `birth_level_ref` (that average when the pool's confidence reaches the threshold, else the
initial level), `birth_escrow_ref` and `shortfall_ref` (the shortfall below the baseline along the
predicted trajectory over the dependency window); settlement and the ratchet are the existing
`settlement_ref`, `neg_share_ref` and `ratchet_credence_ref`. The newborn counts in G's floors at its
predicted level until its window closes; it is not among the decision-time beings whose V G sums (L74,
B(t); `dist_score_ignores_absent`), so only its causers' stake enters ΣV. Findings in 8.54 and 8.56.


**8.53 Proposals from the audit against Ostrom's design principles ([P]).**
From `docs/OSTROM.md` (Ostrom 1990; Cox, Arnold & Villamayor Tomás 2010). Each rides on existing
mechanisms; none adds a rule set.

**8.53-a [P] A floor on the impacted's share of decision weight (principle 3).** L113 weights
expertise and impact, and the simulation's default expertise weight (5) exceeds impact weight (1), so
experts far from a decision's effects can outvote those who bear them. Proposal: a governed threshold,
the least share of a decision's total weight held by voters with predicted impact above Th_b; below
it, impact weights are scaled up for that decision. The share is reported as an output of every
decision (and in M5). Gaming: inflating predicted impact to gain weight is a prediction, scored like
any (L82). Candidate homes: L113, Government (Aspects, "Expertise and Impact-Distance Weighting").

**8.53-b [P] Provision priced as negative usage (principle 2b).** Appropriation pays its resource
cost directly (L83, L86), but restoring or regenerating a resource earns only through the
understanding and happiness outcomes it eventually causes, often below the causal-assessment gate.
Proposal: resource accounting reads a measured increase in an accounted resource as negative usage,
credited at the price depletion would pay. Gaming: depleting to be paid for restoring nets the
accounting's error only, since depletion is charged at the same price; deliberate deplete-and-restore
cycles become AdvAp patterns. Candidate homes: L83 (RA), Economy, Benefuture currency (Aspects);
relates to 8.26.7.

**8.53-c [P] Graduated sanctions stated where the rules live (principle 5).** Escalation by
repetition exists only in the Justice article (rehabilitation: reparation, education, restraint "if
... significant or repeated") and in side levers (ratcheting escrow, ledgers keeping every entry,
mistakes decaying slower, frivolous-report patterns). Causal distribution charges a first,
non-informed harm its full assessed value (L96, L99). Proposal: (i) L116 reads `J := Repair(Ha) ∧
Prevent(Cr), Restorative, Rehabilitate(Escalate ← pattern(Re_-ve(Dn)))`; (ii) what a non-informed
harm (an accident, L115) costs its contributor is bounded by capacity, the administration carrying the
rest as Justice (Reparation) already says, stated in L119 or L96; (iii) Implementation prototype's
"graduated sanctions (reputation penalties, escrow mechanisms)" is corrected: escrow ratcheting is
graduated, reputation penalties are proportional. Gaming: a capacity bound invites actors to hold no
capacity (shell identities); identity binding (L132) and liability overflow on forks (L122) are the
defence, an M6 test. Candidate homes: L116, L119, Justice, Implementation prototype.

**8.53-d [P] Name the sources of deterrence (principle 5).** A sanction equal to the harm deters
only if the chance of being traced times the penalty exceeds the gain. Benefuture's deterrence comes
from V's convexity (the assessed harm, loss-averse, exceeds the saving: laundering at full tracing
left the launderer 1,046% below honest agents) and from AdvAp raising detection; below a tracing rate
near 0.1 laundering paid (+2% at zero). Proposal: the Justice discussion states that reparation-first
deters through assessed harm and detection, not through punishment, and the simulation adds an M6
sweep of detection against gain with V's convexity removed (q₋ = q₊) to show which carries it.
Candidate homes: Justice (Discussion), Critique addressal.

**8.53-e [P] Disputes as priced transactions (principle 6).** Dispute resolution is named (L96,
L99) but its cost and speed are not, and the simulation has no disputes. Proposal: a dispute is a
transaction priced like any other (L86: resource cost less predicted good, so a likely-founded dispute
is cheap); re-assessment is done by a different model of the domain's pool, or by a weighted panel
(Government, Examples, "Dispute Resolution") above a governed significance; frivolous disputes are
charged past a pattern as AdvAp reports are (`report_penalty_ref`). Gaming: disputing every penalty to
delay it is the frivolous pattern; collusion with a panel is AdvAp's. Candidate homes: L96, Justice
(Deliberation), Benefuture currency ("Disputes").

**8.53-f [P] Scoped thresholds and the recognition boundary (principles 2a, 7).** The corpus does
not say whether a governed threshold may settle at different values in different scopes, nor when a
scope's own rules need no wider approval. Proposal: governed thresholds carry a scope (domain ×
locality); a scope's own rules and threshold values within the freedom range (L135) and the admissible
region need no wider approval; a wider scope intervenes only beyond the freedom harm boundary or where
effects fall on beings outside the scope. Gaming: a scope drawn to exclude those it harms is caught by
the spill-over test of 8.53-g. Candidate homes: L157 (SigThGv), L135, Government ("Fractal
Scope"), Freedom.

**8.53-g [P] Subsidiarity by impact (principle 8).** FractalScope (L113) does not say which scope
decides, nor how nested scopes' conflicting decisions are reconciled. Proposal: a decision is taken at
the narrowest scope whose members bear at least a governed share of its predicted impact (Pr_Imp in
L113); the same test settles conflicts between scopes. Gaming: understating spill-overs to keep a
decision local is a prediction, scored like any. Candidate homes: L113, Government ("Fractal Scope").
Simulation: nested decision scopes in M8.

**8.53-h [P] Resource systems as accounted units (principles 1b, 4b).** Domains are fuzzy by
design (L22), and the simulation has one resource stock and one commons. Proposal: resources and the
commons are accounted per resource system, a domain at the granularity of the resource's causal
structure, with the system's condition measured as an output like any other; use, regeneration and
insurance of unassigned harm are then bounded where the resource is. Candidate homes: L83 (RA),
Administration ("Insuring the unassigned"), Domain; relates to 8.26.7.

**8.54 Findings on births (M7; for the author).** 100 beings, 200 steps, 3 seeds, G per entity,
baseline the happiness floor at birth, dependency window 20, optimistic quantile 0.5, confidence
threshold 0.75. (1) Births happen (11–17 a run) and do not drag the floors G reads: the floor of
understanding fell in 16% of steps against 20% without births, happiness 22% against 25%. With the
pool's confidence below the threshold (0.6) no birth is chosen: the newborn would count at a fresh
low. (2) The optimistic average under-escrows by construction: clawbacks are about 5% of the measured
shortfall in an honest world (posted 2342 against measured 2373 over the three runs; nothing uncovered).
(3) Over-optimism to dodge escrow (a causer bringing 3 models 20 too high into a pool of 5) is clawed
back at settlement (uncovered 0.1% of the measured shortfall) and the ratchet pulls its credence to 0.67,
below the threshold (honest 0.88), so its later births count at a fresh low; without the ratchet it
causes 0.98 births each against 0.65 with it. But births chosen before its first settlement escape
the ratchet: it still causes slightly more than honest causers (0.65 against 0.62). Candidate native
remedy, [P]: count pending (unsettled) birth escrows in the causer's ledger, or hold the escrow at the
pool's plain mean until the causer has a settled record. (4) The nearest-rank quantile floor ignores a
single fresh low in small populations (50 beings: one newborn moves the 10% quantile up a rank); with
55 it falls. (5) Open: a causer whose child is predicted below the floor cannot add it without lowering
the floor, so births by the worst-off depend on how optimistic the prediction is; whether the baseline
or teaching should lift the prediction is for the author. Candidate homes: Government (Birth), L74, L84,
the escrow lines.

**8.55 Finding: G's peak filter refuses a trolley switch onto the peak holder (M7; for the author).**
G's ¬↓ U(max) (L74) is read counterfactually against the course; when the one on the side track holds
the peak of understanding, switching lowers the peak against letting five die, so G refuses it although
the switch saves four lives and its value is positive (1 trial in 20; a deterministic test). The standard
trolley rules (8.47) would switch. Options: (a) accept it (the frontier is irreparable in its own way);
(b) read the peak over the long-term window, where the frontier is carried by those taught and
recovers; (c) value the peak holder's death in V alone and drop the peak from admissibility where lives
are at stake. Candidate homes: L74, Benefuture goals, 8.47.

**8.56 Finding: population ethics with births (M7; docs/SOTA.md item 10).** Toy assumption: level 0
is a life barely worth living. Repugnant Conclusion: 200 lives at 0.5 carry a larger total and a larger
stake in ΣV than 10 lives at median + 1, but drag the floors and medians, so G takes the 10; the
success pattern avoids the Repugnant Conclusion. Sadistic Conclusion: 3 lives at −5 leave the 10%
quantile floor and the median higher than 30 lives at 1, so the success pattern ranks the few negative
lives above the many barely positive ones: it gives up Non-Sadism (adding lives below neutral is never
better than adding lives above it), one of the conditions of Arrhenius's impossibility theorems
(Arrhenius 2000, https://doi.org/10.1017/S0266267100000249; the condition's exact name and statement
to be confirmed against the paper). It also gives up Mere Addition (adding lives worth living below
the floor is judged worse). The literal minimum would keep Non-Sadism. Against not acting G admits
neither addition (both lower the floors); forced to choose between them (the mild births happen unless
redirected), the sadistic one is admissible and only the causers' stakes in ΣV decide, since newborns
are not decision-time beings. Candidate answers, [P]: count a newborn's predicted harm (a life below
neutral) in V's harm tiers through those causing it, or read the floor's tail (L74, `tail → Me`) so
that lives below neutral weigh beyond their rank. Candidate homes: L74, Benefuture goals, conjecture
A35, Government (Birth).


**8.57-a Finding: forks game Shapley shares (false-name manipulation).** Aziz,
Bachrach, Elkind & Paterson (2011, *JAIR*, https://doi.org/10.1613/jair.3166) show that splitting one
player into several identities can raise Shapley-type shares. Tested in the funding game that causal
distribution uses (an actor's effect counts only when the coalition can fund the action;
`sim/test/shapley_sampling_tests.jl`, "False names"): a funder whose pledge is indispensable, split into
k indispensable identities, takes k/(k+1) of the outcome alongside the actor instead of 1/2 (k = 4:
0.8). Diminishing returns in the assessed value (a concave valuation of summed effects) also reward
forking (by up to about 17% of the forker's share in random small games); increasing returns penalise
it; additive effects are neutral. What holds: the forks never take more than the whole outcome. The
no-gain bound fails, exactly or sampled. Candidate remedy, [P]: share among bound identities, as 8.34
does for the base vote: a fork family (identity binding, L122) is one player in the coalition game,
its share then divided among its members; alternatively, funders are credited in proportion to their
pledges within the funding side rather than as separate Shapley players. Either keeps causal and
ideological inheritance and grants no claim from the fork itself. Candidate homes: L93–L95, L122,
Benefuture currency (causal distribution), `Proposed.OutcomeDistribution`.

**8.57-b Proposal [P]: asymmetric or causal Shapley for causal distribution.**
Causal distribution runs over transaction trees, where contributions have an order (a maker's output
exists before the carrier carries it). Symmetric Shapley ignores that order. Asymmetric Shapley (Frye,
Rowat & Feige 2020, NeurIPS) restricts the orderings averaged to those consistent with a causal order;
causal Shapley (Heskes, Sijben, Bucur & Claassen 2020, NeurIPS) values coalitions by interventions on a
causal graph, splitting direct from indirect effects. Both fit L94–L95 (the causal-explanation model's
graph and the substrate's degree of separation) better than symmetric shares, and the sampling estimator
(`shapley_sampled_ref`) carries over to asymmetric Shapley unchanged (sample only consistent orderings).
No implementation; for the author with 8.18 (coalition values). Candidate homes: L94, L95,
`Proposed.OutcomeDistribution`.

**8.57-c Note: reusing Holliday–Norman–Pacuit's voting formalisation.** Their
formalisation (LORI 2021, https://doi.org/10.1007/978-3-030-88708-7_9; repository
github.com/chasenorman/Formalized-Voting) is Lean 3 (`leanpkg.toml`), shows no licence on its repository
page, and is built on ordinal profiles (each voter's strict preference over candidates) with social
choice correspondences and Split Cycle. Benefuture's governance (L113–L114) is cardinal and weighted:
binary or few-option decisions decided by an expertise- and impact-weighted tally with capped
delegation. Findings: nothing ports directly (Lean 3 to Lean 4 is a rewrite, and an unlicensed source
cannot be copied); the ordinal machinery matters only if Benefuture adopts ranked multi-option
decisions, in which case the minimal definitions (profile, margin, Condorcet winner, an axiom such as
positive involvement) would be written afresh in Lean 4 over weighted voters. Its value now is as a
checklist of axioms against which weighted voting with a cap could be tested (anonymity fails by
design: weights differ; neutrality and monotonicity should hold). Nothing to change in the sources.


**8.58-a [P] Full support where predictions are scored (M6; `sim/README.md`, attacks).** Metric
models are scored only on what is carried out, and their own predictions select what is carried out:
the decision-market setting of Chen, Kash, Ruberry & Shnayder (2014), where honest reporting needs
every action taken with positive probability. SigThGv's randomised blocks (8.22.3) give full support
over threshold candidates, not over plans. A misreport against a proposer (every model understating
its plans) is never scored: in the toy its plans are never carried out and no model holds a record on
it. Proposal: with a governed chance a step (`explore_share`), one proposal not carried out, each
with equal chance, is carried out anyway, paid at full resource cost by its proposer and scored,
credited and logged like any action (Lean `explore_pick_ref`). At 0.05 the misreport is caught in
every seed and the track record corrects it; the whole success pattern barely moves in an honest
world. Open for the author: whether to adopt it and at what share (it trades real outcomes for
scoring coverage; off by default), whether explored work should be restricted (for example to plans
models disagree on, or within the freedom harm boundary), and whether scores should be weighted by
the inverse of the chance a plan was carried out (Chen et al.'s condition for strict properness when
reports move the selection). Gaming: a proposer of harmful work hoping to be explored pays its cost
and owns its measured harm. Candidate homes: L82, L84, Measurement, Threshold of significance.

**8.58-b Finding: best-of-several model takeover on few records rewards extremised credences
(fixed natively).** Witkowski et al. (2023): rank-based rewards make forecasters exaggerate, proper
scores or not. With the best of eight equal challengers taking over by the significance rule (z 2) on
the proper per-record score, one stating half its uncertainty took over 16.4% of contests on 10
records against 7.1% for each honest equal; on 50 records 2.2% against 1.9%. A challenger now
competes only once its record spans `takeover_records` (governed, default the scoring window, 100),
comparing like with like. Retirement by rank (the least accurate challenger dropped) retires
extremisers more often, so it rewards nothing. Candidate homes: L82 (competition of models), L49.

**8.58-c Finding: honest credences are underconfident where outcomes are mostly positive.**
`credence_ref` reads a model's credence from its predicted value over its record's RMS error, with no
prior over outcomes. In a capable domain (outcomes mostly positive) credences of 0.7–0.9 come true
100% of the time, so a model stating half its uncertainty is better calibrated, and the proper score
rightly lets it take over (every takeover in the extremist world was an extremist's; no honest equal
took over). Not a gaming success but a miscalibration of the honest rule. Candidate fix for the
author: credence from the model's calibrated record (for example the outcome rate among its past
predictions of similar value, or a posterior including the domain's outcome distribution).
Candidate homes: L84, 8.36, Measurement.

**8.58-d Finding: on-off deceit defeats the track record and takes a capable domain's currency
down (screened; needs the author).** An agent alternating 25-step phases of honest good work and
harmful work passed off by deceit fools the models afresh in each bad phase (the 20-action track
record has forgotten), the leaf model falls below its status bar, and the domain's currency goes down
for everyone: peers' selected actions 59 against 324 with constant deceit (which the track record
learns) and 330 honest. The ledgers keep the pattern (negative share 0.39–0.49 against peers' ≤ 0.17;
entries never decay, 8.42.4), but the pattern reaches only escrow's credence and readers' attention,
not the prediction G screens on; AdvAp establishes the deception but its repair, estimated over all
the actor's records, honest phases included, understates it and does not restore the domain. Lines
the author may choose between: the ledger's negative pattern widening an actor's predicted
uncertainty (a ratchet on screening, not only on escrow); repair estimated per deceptive episode
(since the last audit, or by change point) rather than over the whole record; the track record keyed
to the worst recent phase. Candidate homes: L84, L86, L101, L160, Reputation, Adversarial adaptation.

**8.58-e Finding: Shapley shares are not false-name-proof where an outcome mixes gains and harms.**
Aziz et al. (2011) on false-name manipulation. With superadditive assessed value, splitting one's
gain across identities lowers one's share (it does not pay), but splitting a harm of 2 beside a
co-contributor's gain of 1.5 lightens the splitter's penalty by 11% and shrinks the co-contributor's
positive share. A sybil adding nothing earns nothing (null player) and totals are conserved
(efficiency). The reputation recount is symmetric in Cheng and Friedman's (2005) sense, so by their
theorem it is not sybilproof; identity binding (Technology Network) is what must stop sybils and
whitewashers, and in the toy it does (whitewashing attempts linked, leaf accuracy 0.995 against 0.941
unbound). Candidate homes: Technology Network (identity binding as a stated prerequisite of causal
distribution), Benefuture currency (Causal Distribution), L94–L96.

**8.59 Status of the 8.45 ruling: source tags in M5.** Each reading carries its
origins' tags (persons by identity, models by identity); a listener counts each origin once, an echo
of itself not at all (Lean `count_once_ref`, `tagged_reading_ref`), and the borrowed share of its vote
passes to the origins as fractional delegation under L114's cap, cast on each origin's logged output,
the voter keeping its own share and any share the cap blocks (`borrowed_shares_ref`, with the
existing `accumulate_capped_ref`; reading [P]). 100 voters, hard factual decisions, 3 seeds, right in
the last third, untagged → tagged: alone 92.8%; five random contacts 91.4% → 92.7%; IH's
ContentionMap 83.8% → 93.1%; with three rounds of passing readings on, contacts 91.2% → 93.1% and the
ContentionMap 80.2% → 92.9% (untagged, echoes compound across rounds; tagged, they do not). About a
seventh of the total weight passes on, bounded by the cap on the few sources the ContentionMap
surfaces. Contention (two expert camps, one leaning by an honest bias; 1,600 decisions, 4 seeds):
with deliberation and split trials, all decisions 89.5% → 91.8%, deliberation alone 78.9% → 88.2%
(the echo cost on uncontested questions removed), but contested questions 86.7% → 79.6% in the first
400 and 86.6% → 85.1% in the last 400: with the camps' shares capped, laymen no longer amplify the
camp whose record is better, and the trials take longer to settle the question. The persuasion-bias benchmark (DeMarzo, Vayanos and Zwiebel 2003) holds exactly: untagged
weights are walk counts, tagged ones each reachable origin once. Candidate homes: L133 (IH: source
tags as part of SourceVerify), L113, L114, Government (clean deliberation).

**8.60 Do models take their borrowed share? (ruled below).** Models do not vote (8.42.2:
they inform votes, as expert commentary does). With tags, a voter's share borrowed from models
therefore stays with the voter, cast on its own reading informed by the models, and every voter who
hears a model recasts it: the echo of 8.45 remains through models (IH and models improving towards
noise 0.5: 84.4% untagged, 82.3% tagged). If instead each model takes its borrowed share as capped
fractional delegation, cast on its published prediction (the same cap as a person: L114), the
decision counts each model once: 92.6%. Options: (a) models take their share, capped like persons
(models then cast weight, against the letter of 8.42.2, though no model holds a vote of its own);
(b) the model share passes to the model's operators or to the experts whose record the model's record
draws on; (c) models' published predictions enter the tally once, weighed by their records (8.43
option (a), a new rule). The simulation keeps 8.42.2 by default (`model_share = :voter`) and reports
(a) beside it. Candidate homes: L114, L133, Government (models in deliberation), 8.42.2.
*Author ruling (8.60):* models do not vote. Agents have access to all kinds of information whose
sources can be credited as experts, but credit never passes as vote shares: each agent votes, or
delegates (L114), with its full domain expertise and impact weight. Influence is inevitable; IH is
there to inform about sources and estimated truth levels, not to redistribute voting power. So 8.59's
[P] reading (the borrowed share passing to its origins as capped fractional delegation) is withdrawn,
with `borrowed_shares_ref`, its export and wrapper, and `model_share`; tags count each origin once in a
voter's reading, and the voter casts its full weight on that reading. *Author, on the ContentionMap:*
IH's ContentionMap exposes all expert sources, not a few; the simulation's map had surfaced only the
three most reputable on each side, so every layman heard the same six sources and recast their noise
together, which is the echo cost 8.45 measured. The map now exposes every source in the domain, each
weighed by its record (trickle-down, 8.44, still drops sources below the listener's own record).

**8.61 Gaming source tags.** Tags are outputs, auditable by AdvAp against the
open log (L160). (1) Misattribution (claiming a reputable source backs one's side, or slandering it):
inert under 8.59's reading, since a borrowed share passes to the origin's logged output whatever was
claimed and records read the log; in M5 with twenty liars, unaudited, the tally and every record are
identical to an honest run, and audited, every falsified tag is caught and debited to its maker as a
falsified output (`tags_falsified_ref`). Untagged, the same liars cost decisions. (2) Laundering by
omission (republishing what one heard as one's own, claiming independence, and voting it with full
weight): unaudited it pays (the launderers' records rise from 40% to 57% right, listeners borrow from
them, decisions fall 91.9% → 90.2%); an echo audit flags an output whose agreement with what its maker
heard exceeds what two independent judges of those accuracies would show by a governed margin
(`undisclosed_echo_ref`; margin 0.1, 3 standard errors, 20 outputs), flags at least three in four
launderers and under one in twenty honest voters, and splits a flagged voter's readings like anyone's.
Residual: a launderer copying only part of the time stays under the margin, bounding what it gains;
honest experts sharing a paradigm (8.45 contention) agree beyond independence and could be flagged,
which the margin is meant to absorb (untested). Candidate homes: L160, L133, Adversarial adaptation.

**8.62 Finding: liquid-democracy pathologies against direct voting (SOTA #3).** One
domain, 101 voters, 400 decisions, 6 seeds, direct voting 98.7% right. Bad delegation (Kahng,
Mackenzie and Procaccia 2021: all delegate to one somewhat better voter): uncapped 85.6%, capped at
5% 96.8%. Misleading reputation (Caragiannis and Micha 2019: the least competent most reputable):
uncapped and unaudited 77.6%, capped and audited 95.9%. Bribery of the three most reputable
(Alouf-Heffetz et al. 2024): uncapped 65.2% (vote reputation alone lowers the bought super-voter in
time), capped and audited 96.3% against 98.7% for direct voting with the same bribes. Super-voters
(Kling et al. 2015): uncapped, one voter holds most of the weight; capped, none above the cap plus one
voter's own. Cycles cannot form (delegation only to strictly higher reputation, delegates never
pass weight on) and no weight is lost. In these worlds the cap and audit bound delegation's losses to
about two points but do not make delegation beat direct voting; where delegation helps (Berinsky et
al. 2025) is not yet simulated. Candidate homes: L114, Government (liquid democracy).

**8.63 Author note: deliberation does not always change minds.** A non-expert may hear an expert and
keep its own position; the rate at which people take advice, and how far, should be drawn from
realistic sources (advice taking, field persuasion rates, deliberative polling), not assumed. More
generally, every gate and distribution the simulation uses is to be adapted to realistic source data as
far as possible (`docs/CALIBRATION.md`); governed thresholds keep governed defaults, with institutional
analogues as reference points. Candidate homes: L133 (IH), Government (clean deliberation), the
Implementation article's calibration of Phase 1.
*Author, on 8.63:* realistic figures are adapted to the scale of what they mean, and figures that would
work very differently in a Benefuture society are not used as defaults. Invariant figures (perception
noise, skill dispersion, partial advice taking) carry over; figures produced by today's institutions
(vigilance, deception and audit rates, whistleblowing, R&D share, delegation behaviour) are a
status-quo baseline or a sweep, since in Benefuture they should emerge from its incentives; each
figure is converted to the simulation's unit, step and population before use.

**8.64 Author ruling on horizons.** The economy should handle 10 years and governance 20; batteries
sometimes run century-long simulations of both working together, with dashes of catastrophe and
breakthrough at roughly realistic frequencies. Readings, [P]: an economy step is a month (a 10-year
run is 120 steps), governance takes 60 decisions a year (1,200 over 20 years), a population step is a
year; the century run needs the stages composed (economy, governance and population in one world, G
per entity) and draws catastrophes (M3f black swans) and breakthroughs (M7 research) at rates
converted from realistic frequencies (`docs/CALIBRATION.md`). Candidate homes: Implementation (phases
and horizons), the batteries.

