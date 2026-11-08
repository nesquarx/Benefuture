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
*Status after 8.60 and the full ContentionMap:* the borrowed-share delegation and the readings above
that depend on it are withdrawn. With every source exposed and realistic advice taking (8.63),
deliberation decides as well as voters alone (92.8% both, about one vote in twenty changed); where
everyone defers, 90.8%, and over three untagged rounds 86.6%, restored to 90.8% by tags
(`sim/README.md`, source tags). Most of the first echo cost (83.8%) came from the narrow map.
Contention re-measured likewise: contested decisions right 85.7% with deliberation and trials, 81.0%
with trials alone, 74.8% with neither; all decisions 91.1%.

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


**8.65 Finding: under the calibrated defaults the economy converges, but unevenly across seeds, and
the exact world's guarantees are limiting cases.** With the calibrated noise of `docs/CALIBRATION.md`
(markers 0.3, leaf, parent and coarse models 0.3, 0.6 and 0.85, execution 0.25, side harm 0.01),
three readings differ from the exact-ish worlds the earlier tests used (`sim/test/calibrated_tests.jl`,
`sim/test/m3f_tests.jl` "Capture under realistic noise"):
(a) whether a domain's own leaf model ever qualifies is seed-dependent. In the capture world the
share of leaf 1's work priced by its own currency before the capture is 0.09, 0.98 and 0.91 over
three seeds (0.40, 1.00, 0.61 with only the model noise set back), and floor growth over 250 steps in a
clean eight-agent world is 31, 176 and 117 (actions 271, 1,799, 1,206): early records decide whether the currency regime
takes hold, so a few seeds sit in the thin-pricing regime for the whole run. The single-seed
tests that assumed a qualifying leaf (capture, whether deceit blocks a marginal domain, the decision
market's misreport) are pinned to the old model noise (`LEGACY`) as designed scenarios; their
mechanisms are not in question, but their frequency under realistic noise is unmeasured;
(b) "no floor ever falls" holds with exact models, markers and accounting and no side harm, and fails
in all six seeds measured under the calibrated defaults (a counterexample test, not a regression):
with noisy markers, side harm and imperfect execution floors do fall, and G's guarantee is stated over
measured outputs, so it is a limiting case, not the default;
(c) heavy-tailed hazards (Pareto size, median 1, cap 20) make harm's peak (the deepest single-being
drop) about four times deeper than Gaussian hazards of the same median (mean 17.5 against 4.3, six seeds,
rate 0.2, no guardians): the success pattern's harm criterion is only meaningful relative to a clean world
that has the same tail.
Candidate homes: Implementation (Phase 1: records a leaf needs before its model backs a currency, and what
happens to domains that never qualify), the success pattern (harm's peak against a reference with the
same hazards).

**8.66 [P] Finding and proposal: credence from the record, not from its root mean square error.**
The economy battery on the calibrated build (results tagged ff30b17) finds side harm the one factor
failing inside its realistic range, at 0.31 of it (`p_side` about 0.04, a complex domain's rate).
Diagnosed: not harm's peak but a stall. `credence_ref` reads a model's credence from its predicted
value over the root mean square of its recent errors; one heavy-tailed side effect (an error of 300
against a typical 2) multiplies that spread about twentyfold for the whole window, every credence
turns to a coin toss, accuracy (1 − Brier / 0.25) falls below the status bar, the leaves lose their
currencies, and the StandCoin lane halts for want of funds (about 1,700 halted proposals, floors
falling). With the Gaussian tail of the same median the same rate is harmless (accuracy 0.96).
Proposal: a model's credence is the share of its own recent errors below its prediction, a tie
counting half (Lean `record_credence_ref`, spec `Proposed.recordCredence`, proved: within
[1 − cap, cap], rising with the prediction, moved by at most 1 / n by any one error). It is
distribution-free, so calibrated by the model's own record, and tends to the normal credence when
errors are normal (that rule becomes its limiting case). It is the candidate fix 8.58-c named
("credence from the model's calibrated record"). Measured (`credence_rule = :record`, off by default):
the battery's world keeps its currencies and growth at side-harm severity 0.31, 0.6 and 1.0 (margin
0.52 to 0.96, no halts; the clean world unchanged); a robust spread (median absolute error) helps
less and halts at 1.0. It also addresses part of 8.65 (a): over six seeds of the realistic world the
currency regime takes hold without halts in four (none under the normal credence), and mean floor
growth doubles (51 to 111). What remains of 8.65 (a) is irreducible outcome randomness: a perfectly
calibrated model in a domain where 4% of actions turn out badly scores about 0.85, below the 0.9 bar
(8.36 chose no ceiling adjustment).
For the author: (1) adopt the record credence as the rule (L84, 8.36)? (2) should status bars allow
for irreducible outcome randomness (for example accuracy relative to the best calibrated model of
the domain's outcome rate), or stay absolute as 8.36 ruled?
Gaming: a model cannot raise its credence without its errors falling below its predictions, which the
open log scores; an extremist scaling its record (`sharp` < 1) is scored by the same Brier as before.
Candidate homes: L84, 8.36, Measurement (credence from track record).

**8.67 Finding (mechanism probe): supply follows outcomes, except harm done by StandCoin-lane work.**
The supply probe (`sim/test/probe_tests.jl`) checks the economy's ledger against L99: in a world
with no other flows, total balances (with overflow counted as a transfer to reinvestment) change by
exactly the sum of each priced action's `supply_delta_ref` (its currencies' shares of the measured
good, less resource cost, less harm) and of the StandCoin lane's burnt resource cost (8.3: StandCoin
charges only resource cost, so lane work mints nothing). No other flow moves currency. The gap:
harm done by lane work (and by explored proposals, 8.58-a) is measured and counted in reputation but
burns no currency, while L99 burns harm wherever it is measured. Question for the author: does lane
work's harm burn currency (charged to its proposer and pledging experts, as a priced action's harm
is charged to its contributors), or does "charges only resource cost" cover harm too?
Candidate homes: L99, Benefuture currency (StandCoin entry).
8.67 ruling (author): (a). Harm done by lane work burns currency like any measured harm, charged
to its proposer and pledging experts by their contributions; harm no one can be ascribed (natural,
or untraced) is lifted by the commons, ultimately backed by resource accounting (RA, L83).

**8.68 Author clarification on expertise weighting (B26, L113).** Reputation is the record of
winning choices in a domain and stands for domain expertise. The diversity worth counting among
experts is that of high-expertise experts from related domains (domain overlap brings diverse expert
viewpoints), alongside diverse lay viewpoints; it is not headcount: twenty pieces of the same 1x
knowledge are not one piece of 20x knowledge, which the subdomain division exists to prevent.
Proposal [P] for the tally: weight each voter's expertise by the log-odds of its record (Nitzan and
Paroush 1982, the optimal weights for independent voters of unequal competence; `source_weight_ref`
already reads records so in deliberation); count correlated knowledge once, with clusters seeded by
the subdomain network and its overlaps μ and refined from outputs (errors that coincide in the
record), within-cluster weight scaled by the effective count n / (1 + (n − 1)ρ) (Ladha 1992); sum
across clusters, so related-domain experts add as diverse viewpoints; leave the base vote and the
impact term untouched (8.60). B26 is then restated over effective weight: the tally's error vanishes
as independent clusters grow, not as headcount does. Sybil and fork attacks on the tally wait for
identity binding and Technology Network clustering (author). Candidate homes: L113, L114, B26,
Governance (expertise weighting).
8.68 coherence note (open, for the author): as specified, reputation is not a record of winning
choices. L100 sums causal contributions to understanding and happiness in the domain plus novelty,
Σ(CC(U, H) + N): a record of value caused, scaled by stakes and by volume of activity, shared with
funders and carriers by causal distribution, and read from realised outcomes. It correlates with
winning choices but departs from them in four ways: magnitude (one large lucky outcome outweighs
many small correct calls), volume (more actions accumulate more, whatever their hit rate), capital
(funding earns Shapley shares, so wealth buys reputation where it buys outcomes) and luck (outcomes,
not decisions, are credited). The record of winning choices exists separately in governance (the
per-decision record of votes and predictions, 8.29; `person_rec` in M5), which is what accuracy
weighting needs. Proposal [P]: L113's expertise term reads a per-choice record (the log-odds of the
share of a person's choices in the domain that came out well, or the calibration of their stated
credences), with L100 reputation kept for what it measures (contribution, and the right to price
and be paid); or, if one quantity must serve both, L100 normalised per action and per unit at stake.

**8.69 Author proposal (under discussion): prediction accuracy as reputation's fourth component.**
Re(E, d) = [hPos, hNeg, rel, PrAcc]_d, PrAcc scored over every choice transaction in the domain, not
votes alone: proposing an action, funding or pledging, delegating, voting, accepting or declining a
quote each carry an implicit prediction that the outcome is good, scored against the measured
outcome by the same rule as a model's accuracy (`credence_accuracy_ref`, 8.36). Later, credence-
weighted for agents as for models, with a coarse credence scale for biological agents (0.5 random,
0.6 quite unsure, 0.8 sure, 0.9 quite sure, 0.99 almost certain, with a spread of certainty), read
through each person's own record (8.66) since stated credence and hit rate differ. Points for the
discussion: score skill over the domain's model (a choice the model already called with high credence
earns little), so safe, trivial choices do not inflate PrAcc; choices not taken are unscored (the
8.58-a gap); each choice is its own prediction, so PrAcc is never split by causal distribution and
capital buys none of it. Candidate homes: L100, L101, L113, Ontology.Reputation.
8.69 amendment (author): funding or delegating to a winning expert earns little prediction accuracy
in the expert's domain (actuarial) but earns it in that domain's expert selection (actuarial expert
selection), and some in expert selection in general. No new mechanism: a selection choice is
classified by its causal signature like any action, into a selection leaf overlapping its subject
domain, and the overlaps μ spread its score (mostly to the selection leaf, some to its general parent,
little to the subject domain). Scored as skill: picking the expert the domain's record already ranks
first earns little, picking a rising one early earns more. The selected expert's own accuracy comes
from its own choices, so nothing is split or counted twice; delegation chains (selecting selectors)
decay by degree of separation (L95).
8.69 probe (`sim/test/probe_tests.jl`; Lean `choice_skill_ref`, [P]): skill over the model,
1 − Brier(chooser) / Brier(model), ranks a low-volume accurate chooser (0.9 hit rate) above a
high-volume mediocre one (0.55) where summed value ranks them the other way; a funder backing at the
model's own credence earns exactly zero skill; a selector's skill spreads by its choice's domain
shares. Finding: a short record is noisy (twenty choices drawn at 0.9 came out at 0.75 and read as no
skill), so prediction accuracy needs a minimum record before it weighs, as a model's accuracy does
(`min_records`), a governed threshold.
8.67 implementation note: lane harm burns in the currencies of the domains the action lies in, by
its classification shares, as hazard harm does. Burnt in StandCoin it drained the currency that pays
every resource cost: root balances went below zero, payment gates closed, lane work fell from about 50
to 10 actions a run and priced work stopped in two seeds of six (diagnosed with the burn switched off).
Balance ratios (the M6 tests, the economy battery's attack test) mean nothing once balances can be
negative; they are now differences of balance gaps against the attack-free world, in endowments.

**8.70 [P] Identity binding weighted by attestation record (B2, L18; probe).** An attestation by a
Technology Network cluster is a choice, scored like any other (8.69), so each cluster's say in the
binding quorum is its attestation skill (Lean `binding_admits_weighted_ref`; the count rule
`binding_admits_ref` is the case of equal weights). Probe: two colluding clusters attesting sybils at
0.99 make a quorum under the count rule every time; once earlier sybils from the pair are revealed
their skill falls below zero and none of 50 sybils is admitted, while honest clusters (skill about
0.87) still bind at least 45 of 50 real entities through attestation noise. Gaming: a cluster that
builds a clean record and then defects passes sybils until they are revealed (on-off, 8.58-d), so
revelation speed (AdvAp on identities) bounds the damage; correlated clusters should count once
(8.68's effective count) before the quorum is met. Candidate homes: L18, Technology Network.
8.70 in the economy (M3c whitewashing world, `bind_weighted`): two of three clusters colluding with a
whitewasher admit 13–15 false identities and link none under the count rule; weighted, 5–7 pass and
4–13 attempts are linked (3 seeds, 300 steps, revelation chance 0.05 a step). The first five pass
before any cluster has the five scored records its weight needs, so the minimum record is the window
an on-off cluster exploits. In this world every new identity is false, so attestations are scored
on one side only; honest newcomers (B2 step 2) will score the other.
8.66 robustness evidence (the M3d world, `sim/test/m3d_tests.jl`, 20 seeds): under the normal credence
one seed in twenty stalls on each platform (Linux seed 4, macOS seed 1; mean transactions 1,026 and
1,042), the platforms agreeing statistically while single seeds trade places, because a 1-ULP libm
difference flips a status-bar comparison (0.891 against 0.90) and the stalled lane never recovers;
under the record credence no seed stalls on Linux (0 of 20, transactions 1,037 to 1,120). A run whose
whole outcome a 1-ULP difference can flip is fragile; the record credence removes that fragility here,
which strengthens the case for adopting it (question (1) above). The stall is also absorbing (a
disqualified domain's lane halts for want of funds, earns no new records and cannot requalify),
against the progressive-degradation rule that a coarser mechanism substitutes without stalling;
candidate remedies for the author: hysteresis at the status bar, or scoring score-only predictions
while the lane is halted so a domain can requalify.
8.66 cross-platform confirmation (local agent, macOS ARM64, same 20 seeds): record credence 0 of 20
stalled, transactions 1,020 to 1,117, mean 1,074 (Linux 1,037 to 1,120); the seed that stalled on macOS
under the normal credence ran 1,069 transactions with no halts. The fragility is removed on both
platforms.
8.70 amendment (B2 step 2, honest newcomers): attestations scored on both sides expose pooled skill
as gameable. A cluster vouching for everyone is right about the many real newcomers and keeps a
pooled skill of 0.5 to 0.9 while passing every sybil. Read on each side and keeping the worse side
(Lean `class_balanced_skill_ref`), the colluding pair falls to −2.9: 1 to 2 false identities admitted
against 6 to 14 pooled (five clusters, two colluding, newcomers ten times as frequent, 3 seeds). The
weighted quorum is a governed threshold in units of skill (`bind_quorum_weight`, default 1: two
clusters at skill 0.5); with only one honest cluster no quorum of two independent clusters can form
(L18), so refusing then is the cost of compromise. The cost under class-balanced weighting: honest
clusters whose short records sample low skill fail to reach the quorum together, refusing 30–35% of
real newcomers in two seeds of three (1% in the third), against almost none pooled; the quorum
weight trades sybils admitted against real entities refused, and the minimum record (R4) sets how
noisy the weights are.

**8.71 Author rulings on 8.66 and the stall.** (1) The record credence is adopted as the rule (L84,
8.36) [R]: a model's credence is the share of its recent errors below its prediction. (2) A stall
must not be absorbing, read economically: a stall is a society that overpromised and cannot shrink
back to take the hit, so resource accounting (RA, L83) must shrink baseline pricing, the commons and
overall resource spending to absorb it. StandCoin, like fiat, only prices resources; any model-free
transaction is a major flag, a call to build domains, models and predictability for that work, and
needs scrutiny and restraint. Work in an unheard-of novel domain is rare in a mature metric-model
framework. Simulation note for the author: in the stalls measured, the lane carried work in known
domains whose model had dipped below its status bar (0.891 against 0.90), not novel work; a mature
framework would price that work through the domain's parent or coarser model, or at a lower credence,
before falling to model-free StandCoin. Candidate homes: L82–L86 (fallback order), L83 (RA
contraction), Benefuture currency (StandCoin entry).

**8.72 Author clarification: newcomers enter at binding points.** As in any polity, a newcomer
appearing without an identity binding is itself an issue. Newcomers are expected only at certain
locations (birth, entry points) that bind them to a preliminary identity, which then gains
confidence across clusters over time. Consequences for the simulation: a new identity seeking
binding outside an entry point is a flag in itself (a sybil or whitewashing attempt), not a
newcomer; a real newcomer is not refused but holds a preliminary identity whose binding confidence
grows as independent clusters attest it, so 8.70's false-rejection cost (30–35% of real newcomers
refused when they appeared anywhere) belongs to a world without entry points. Open for the author:
what a preliminary identity may do before full binding (transact, vote, receive the base vote), and
how fast confidence must grow (governed). Candidate homes: L18, Technology Network (identity
binding), Implementation.

**8.73 Author clarification: several qualified models, so several currencies, per domain.** A
domain can have more than one qualified model and so more than one currency: uncommon in a deep leaf
subdomain, very common in coarser, more established domains. The simulation keeps a pool of models
per leaf (8.42.2) but lets only the top model back the leaf's currency (`leaf_ok` reads the top
model's accuracy alone), so a dip of the top model below its bar disqualifies the domain even where
a challenger still qualifies. Consequence for the fallback order (8.71): work in a known domain whose
top model dips is priced by any other qualified model of the domain first, then by the parent's
qualified models, then at lower credence, and only then by model-free StandCoin; every qualified
model of a domain backs its own currency, with the quotes composed as L86 composes currencies.
Candidate homes: L82 (`C ↔ MM_j ∈ TopModels(MM_Acc > Th, Dn_i)`, already plural), L86, Benefuture currency.
8.72 ruling (author) on preliminary identities: a preliminary identity may make safe transactions
and anonymous Technology Network calls (generic, differentially private queries, L132), but not
specific ones, because its inoculation status (information-hazard gating through education, L133
`preReq(Ed)`) is not established; it will also need to demonstrate Benefuture daily-use knowledge by
passing tests and courses. Voting before full binding was not ruled; the simulation withholds the
base vote until binding (the sybil-safe reading) and marks it as an assumption. "Safe transactions"
need a governed bound (a cap on value or on harm at risk). Candidate homes: L18, L132–L133, Technology
Network (privacy tiers, educational gating), Education.
8.71 status: the record credence is the default (`credence_rule = :record`); the normal credence is
kept as the limiting case of normal errors. Readings that moved, each measured under both rules
before its test was restated:
- the marginal-domain blockade (8.37): a liar kept the domain from qualifying in 5 of 12 seeds under
  the normal credence, in none under the record credence; the blockade-and-repair scenario (8.38)
  keeps the normal credence as its limiting case;
- whitewashing without binding no longer lowers the domain model's accuracy (mean 0.974 against 0.980
  without whitewashing; under the normal credence it fell to 0.87 in one seed); it still costs the liar;
- heavy friction: the all-top world degrades about as before (floor gains 8.5, 4.5, 10.9), but the
  clean world no longer has a stalled seed (171, 182, 166 against 31, 176, 117), so the share of clean
  growth reads about 5% instead of 8%; the test now asserts floors rise in every seed;
- better models: the bootstrap models qualify more robustly (own-currency share 0.71 static against
  0.56), so arriving better models add less (0.79 against 0.71);
- the debatable escape (8.41): the incumbent bar now prices the low-skill domains better (mean outcome
  42, 32, 29 against 17, 36, 8), so the relative-bar trial is tried and harmless but never adopted; the
  adoption scenario keeps the normal credence;
- the supply probe's tiny world sits on the novel bar's edge (accuracy 0.65 to 0.89 under both rules),
  so whether its work is priced depends on the early record; its harm counterexample now reads the burn
  per lane action.

**8.74 Finding (open): deceit pays a little in a capable domain.** With every model fooled upward by
one agent (deceit 1, skill 0.6, AdvAp on), the liar's balance gap over its peers, against the same
world with it honest, gains +65 ± 17 under the normal credence (12 seeds, t = 3.8) and +59 ± 27 under
the record credence (t = 2.2), positive in 9 of 12 seeds: about 7% of its final balance, 1% of what it
was paid over the run. Earlier three-seed tests passed by sampling. Ruled out: volume (the liar's share
of executed actions is unchanged, 0.164 against 0.165, and its value per action slightly lower) and
upfront payments (escrow settles each action to its measured value). Seen: every agent ends richer in
the liar's world (peers +55, the liar +114) and less is skimmed to reinvestment (28,889 against
29,648), so the overflow threshold, which reads reputation, is the leading suspect; per-agent overflow
is not traced yet. Next: trace overflow per agent and test the hypothesis before any change.
Also measured: on-off deceit (8.58-d) still takes a capable domain's currency down in two seeds of
three under the record credence (peers 50 and 58 against about 325), recovering in the third.

**8.75 Parsimony note: cyclic-review attenuation is moot under outcome-only reputation.**
`Governance.Incentives.attenuate_cyclic_reviews` damps mutual endorsements (A → B, B → A), and the
[OPEN] note beside it says longer cycles need global detection. In Benefuture reputation is the
causal record of measured outcomes (L100); endorsements earn nothing, so mutual reviews cannot inflate
it and there is nothing to attenuate. The simulation has no review mechanism for that reason.
Proposal: mark the attenuation as applying only where a review signal is introduced (for example a
model's adoption, L49), or remove it as redundant. Candidate homes: Governance (incentives), L100.
8.74 diagnosis, step 1 (overflow traced per agent, `overflow_agent`, 12 seeds): overflow skims 211
less from the liar, relative to its peers, than from the same agent honest, more than its whole
advantage of 59, so outside overflow it earns slightly less. The overflow threshold reads the
agent's reputation relevance, and the liar's is higher (327 against 279 honest; peers 326 against
349). Open: why deceit raises the liar's relevance; then whether the overflow threshold should read
relevance at all where relevance can be raised by deceit.

**8.76 Author ruling on deceit (from 8.74).** Even where liars get ahead by good-looking proposals,
measurement claws the gain back, and the liar loses reputation as well as recorded credence; AdvAp then
hardens the system against that kind of overclaim, as it would have had the deceit been reported
earlier. The only ones who gain are those who find a loophole and report it without exploiting it more
than once: their reward is one exploit plus the bonus; if they are reported after exploiting, the claw-
back is "4 − bonus" (reading to confirm: the exploit's gain clawed back four times over, less the
bonus they would have earned by reporting). Gaps measured against this in the simulation (12 seeds, a
capable domain, deceit 1, AdvAp on): (1) an established deception costs the deceiver reputation equal
to its liability only (about 35 a run against a losses ledger near 1,300), so the recorded credence,
which reads the ledgers' negative share, barely moves; (2) AdvAp's reward and liability take the
exploit gain as zero (settlement claws back the direct gain: upfront never exceeds settled), but the
liar's residual advantage arrives indirectly, through a higher reputation relevance and so a higher
overflow threshold (8.74; why the relevance rises is not yet verified). Candidate homes: Adversarial
adaptation (reward and clawback schedule), L101 (ledgers), L84 (ratcheting escrow).
8.76 schedule (author), with E the gain of one exploit, B the bonus and n the exploits before the
report: a self-report with no exploit is paid E + B; after one exploit, B; after five, B with four
exploits clawed back; whenever someone else reports first, every exploit is clawed back and the reporter
is paid E + B. So a self-reporter nets E + B whatever n is (exploiting more before reporting earns
nothing), and a caught exploiter nets nothing from its exploits. In M3c the clawback owed by a caught
deceiver is the overstated value AdvAp's repair re-scores across all its records (`prevented`), on top
of the liability (the reporter's reward and the audit, 8.38); the reputation charge follows the same
amount, so the recorded credence falls.

**8.77 Finding and proposal: penalties are absorbed by overflow at the cap.** Why the liar of 8.74
stays ahead, validated causally (12 seeds, capable domain, deceit 1, AdvAp on, the 8.76 clawback in
place): with overflow switched off the liar ends 267 ± 174 behind the same agent honest; with overflow on
it ends 43 ± 26 ahead. The pathway: (1) **incidence at the cap**: an agent whose balance sits at its
accumulation threshold (500 + its relevance) pays a clawback or liability out of income that overflow
would have skimmed anyway; income refills it to the threshold and the skim shrinks by the charge, so the
commons bears the penalty, not the deceiver; (2) **per-currency thresholds**: holdings spread across
currency columns stay under each column's threshold (the liar held 66.7 in a parent currency, against 6.0
honest, never skimmed); (3) **the threshold reads relevance**, which weights recent work (the liar did
slightly more work late, 63.6 actions against 60.6 in the last 50 steps), +38 here. Proposed block,
prototyped and measured: a charge is registered against the agent's cap, lowering its overflow threshold
by the outstanding charge, so the penalty comes out of wealth it keeps: the liar then ends 102 ± 29 behind
(positive in 1 seed of 12). The same incidence applies to every charge on a capped agent (harm burns,
liability, report penalties). Also to decide: whether overflow should read total holdings across
currencies rather than each column, and whether the threshold should read relevance. Candidate homes:
Benefuture currency (overflow, accumulation threshold), Lean `accumulation_threshold`/`overflow` and their
reference rules, Adversarial adaptation (liability incidence).
8.74 and 8.77 corrected (author's question, L103): the liar's "advantage" was a measurement error.
L103 reads `BalOvflw :: Bal(E, C_i) > AccumThresh(Re_E, Equity, G_Optim, Dn_i) ⇒ DirectedAutoInvest(S =
E, Dn_i)`: overflow is invested in the domain as the entity directs, so it stays in the entity's sphere.
Measured as standing (balance plus directed overflow), deceit does not pay: −267 ± 174 in the capable
domain (leaf accuracy 0.98, models strong) and −133 ± 54 in the marginal one (0.89), the same as with
overflow switched off, as it must be, since overflow only moves value from balance to directed
investment. A charge on an agent at its threshold is paid out of the overflow it would have directed: the
deceiver bears it, not the commons. **8.77's proposal (registering charges against the cap) is withdrawn**:
it is not needed. What remains true and open from 8.77: overflow is per currency and the threshold reads
relevance, so standing in balances is distributed across currencies and moves with recent work; whether
directed overflow should earn reputation by its outcomes is 8.51's ruling (it earns through standard
channels if it does good), which the simulation does not yet model.

**8.78 Author clarification: deceit costs reputation in the domain of transactions itself.** Deceptive
behaviour earns negative reputation for contracting, promises and proposals in general, not only in the
domain where it happened: someone who has lied repeatedly in different domains already faces high
escrow in the domain of transactions itself, wherever it next transacts. In the simulation today: an
actor's credence is read from its own error record pooled across every domain (`actor_err`; promise
against delivery, scored at settlement), and the escrow ratchet reads its ledgers' negative share over
all domains (`ledger_neg_share`), so an overstatement anywhere already lowers its credence and raises its
escrow everywhere, and an established deception (8.76's clawback, charged to the ledgers) raises it
further. What is missing: the pooled record is a world-level shortcut, not a classified domain; in the
corpus's terms every transaction would carry a share in a transactions (promising, contracting) domain,
overlapping every leaf, whose prediction accuracy (8.69) is the actor's record of promises kept, and
escrow (L84) would read it. Also untested: spillover itself, since the simulation's deceit fools every
model at once; a deceiver confined to one domain is needed to show its escrow rising in another.
Candidate homes: Domain (a transactions domain overlapping all), Reputation, L84 (escrow reads promise
accuracy), Benefuture currency (ratcheting escrow).

**8.79 Author clarification: prediction accuracy is per domain; guard against halos and horns.** An
expert baker can say to the minute when the bread comes out perfect and cannot say where a frisbee
will turn. Design that follows (with 8.69 and 8.78): split the Brier score (Murphy 1973: reliability,
resolution, uncertainty). Resolution, telling good outcomes from bad, is skill: it stays in its domain
and travels only through domain overlap μ. What travels across domains, into the transactions domain of
8.78, is the honesty of claims: systematic overstatement, the mean signed gap between what was claimed
and what was delivered, and miscalibration of stated confidence (claiming 0.99 outside one's field). A
baker guessing at frisbees errs widely but without a lean, and stating low confidence outside its field
costs it nothing; a deceiver's errors lean one way in every domain. Measured in the simulation today
(an agent skilled in one leaf, poor in another, against specialists, 3 seeds): no halo or horn, its
credence in its strong domain matching the specialists' (0.99 against 0.98 to 0.99) and lower in its weak
one where good outcomes are rarer (0.76 to 0.97), because the pooled record holds the models' errors on
its work, which do not depend on its skill. The risk arrives with people's own predictions (8.69): their
skill must be scored per domain, and only the bias of their claims pooled. Candidate homes: Measurement
(accuracy decomposed), Reputation, the transactions domain of 8.78.

**8.80 Author clarification: accuracy earned in one domain must not be cashed in another.** Building
high accuracy in one's own expertise and then cashing it in as high upfront payment in a different domain
should not happen: a good record as a predictor in general (the domain of predictions, 8.78) helps, but
prediction accuracy in the new domain is untested and must be treated as unknown. In the simulation an
actor's credence is read from its error record pooled across domains once it holds five entries
(`actor_err`), so its first credences in a new domain borrow the record it built elsewhere. Rule to
build: an actor's credence in a domain comes from its record in that domain (each model's record on that
actor); below the minimum record it is unknown, read from the domain model's general record; only the
honesty of its claims (8.79: signed overstatement, calibration of stated confidence) carries across.
Measured so far: in a world where a mixed agent works in both domains from the start, its credences in
its weak domain are not detectably overconfident (0.05 ± 0.10, 6 seeds), because its records there
accumulate alongside the others; the cash-in needs an agent that builds a record in one domain and then
enters another, which the simulation cannot yet express (an agent's focus is fixed). Probe to build,
red on the outcome first: a focus that changes at a step; the entrant's credences and upfront in the new
domain against a newcomer's. Candidate homes: L84 (escrow by credence), Measurement, Reputation.

**8.81 Findings under the significance-testing standard (open).** Claims restated by the standard
(CLAUDE.md, Verification) that the seeds do not support: (a) in a marginal domain (skill 0.3) whether
deceit gains standing is unresolved: +31 ± 35 over 24 paired seeds against a margin of 58 (5% of the
peers' standing), about 160 seeds to settle either way; the liar's ledgers' negative share does rise
(significant). In the capable domain no gain is shown (12 seeds, upper bound 124 against a margin of
291). (b) Slander against AdvAp's audit: the victim's standing is not shown unharmed (−347, interval
−1,049 to +354 over 8 seeds, margin 284), false convictions occur at the false-trace rate under the
calibrated defaults (one seed of 8), and the slanderer's loss (−526) is not significant. The single-seed
assertions that had stood for these claims were luck. Supported at 6 seeds: constant deceit leaves peers
equivalent to an honest world; on-off deceit lowers them (−228); AdvAp under on-off still leaves them
lower (−184). Next for (b): whether a victim's audits should cost it anything at all (a slander that
triggers audits moves the victim's trajectory), and the false-trace rate's source (R-task).

**8.82 Author ruling: justice applies to every detected lie.** Slander is a lie; the harm it causes is a
crime, clawed back from the slanderer. Justice mechanisms apply to all detected lies, not to
overstatement alone. Measured in M3c before building: the slanderer's own reports are never founded (the
audit tests the victim's record, which is clean), so slander causes no false conviction here; its harm
is the audits it triggers (the victim's apparent loss is trajectory noise, 8.81). One false conviction
seen in the slandering world came from an honest reader through the false-trace error: a wrongful
conviction by the system, not a lie, to be remedied separately (question for the author: re-audit on
appeal, refund and retraction). Built: once a reporter's frivolous pattern is detected (the lie
detected), every audit its false reports caused is charged back to it as a crime (Lean
`false_report_charge_ref`), including those before detection (the unfounded ones in the window and the
ones the record's noise founded but no trace established) and every one after, the window's count
notwithstanding; good-faith reports from readers never detected lying stay free. Structural, per run:
the slanderer is charged one audit per report it filed (seeds 1-4). Other detected lies to bring under the same justice: falsified source tags (M5, 8.45), attestation
by colluding clusters (8.70: their weight falls, nothing is clawed back yet). Candidate homes: Justice,
Adversarial adaptation (frivolous reports), L101 (retraction).
8.81 addendum (Goodhart, 8 paired seeds): supported, the native mechanisms keep the predicted-true gap
under high selection pressure below the bare world's (17.9 lower); not supported, that the bare gap grows
with pressure (+1.55) or that pressure buys the native world true value (−0.11). The failure that
surfaced it: the 8.76 clawback (validated by switching to the old liability) moves one seed into the
stalled-lane regime, where the domain's leaf model sits below its bar (accuracy 0.67) and 78% of the work,
honest work included, is priced through the StandCoin lane by an unqualified model that overpredicts it
(gap 9.1 on honest work). Not deceit succeeding: the stall (8.71) again; the deceivers, in debt from the
clawback, do all their work in the lane. Also found: summary-line test scans missed failing testsets
(the summary of a failing testset carries counts, not the word "Fail"); verdicts now read the
"Test Failed" lines.

**8.83 Finding: the stall in a realistic domain is the status bar, and the relative bar removes it.** In
a calibrated tiny world with no shock (4 agents at skill 0.6, the calibrated noise), the leaf qualifies
early, its accuracy then settles at 0.72 to 0.88, under the established bar of 0.9 (8.66: a calibrated
model in a noisy domain scores about 0.85, the bar does not allow for irreducible outcome randomness),
the parents never qualify, and 77% of proposals halt in the StandCoin lane (8 seeds: shares 0.02 to
0.85). Tried and withdrawn: a maintenance bar (hysteresis: a qualified model keeps its currency above
0.75), which lowered the halted share by 0.26 on average but not significantly over 8 paired seeds
(seed 5 worsened), so it is not adopted (parsimony). What works: the relative status bar of 8.41 (c),
the bar read relative to what the work would otherwise fall to: halts vanish in all 4 seeds measured and
floor growth rises (78 to 93 against 13 to 78). The native route to it, the debatable escape (governance
trials the relative bar on a share of the leaves and adopts it on `escape_accept_ref`), adopts it in 3 of
4 seeds (gains about 4,000 against harms under 80, nothing irreparable); in the fourth the trial half
held only idle leaves, so it saw nothing (a toy world with one working domain). For the author: (1) make
the relative bar the default for established domains, given that the absolute 0.9 bar is unattainable
under realistic noise; or keep it governed through the escape, with trial leaves drawn among active ones
(randomised blocks by activity, L157's experimental design). (2) This also bears on 8.71: with the
relative bar the absorbing stall does not arise here, so RA contraction is needed only for lane work that
no model can price at all. Candidate homes: L82 (status bars), 8.36, 8.41, L157.

**8.84 Why the simulated models stay under 0.9, and the author ruling against downward drift.**
Measured (calibrated world, 3 seeds; accuracy = 1 − Brier / 0.25 on "the action's measured value is
positive"): the calibrated models score 0.842; a perfect model (no error, no bias) in the same world
0.871; with exact markers 0.894; with no execution sloppiness as well 0.908; with no side harm as well
1.000. The ceiling is the world's irreducible noise (execution slips, measurement error, rare heavy-tailed
side effects decide about 5% of outcomes), not the models. Two causes: every simulated domain carries the
same noise, the low end of realistic ranges for hard, social-intervention-like domains, while most real
work is routine and highly predictable (models well above 0.9); and with 95% of outcomes positive a
constant forecaster of 0.95 already scores 0.81, so the metric credits the base rate. To do: a realistic
distribution of domain predictability (low-noise physical and routine domains beside hard social ones;
research task R5).
Author ruling: the status bars (0.9, 0.75, 0.55) are thresholds, governed and adapted, but governance
must not drift accuracy requirements downward: the bootstrap calibration may set each domain's bars to
world-realistic values, and from there accuracy is expected to go up, not down. Candidate homes: L82,
L157 (SigThGv), 8.36, 8.8 (a bar near 50% needs extraordinary grounds).
8.84 ruling (author) on the ratchet: when a governed number of models operate above a domain's bar,
the bar ratchets up. Built as: once at least k models (governed, `ratchet_k`) have accuracy at or above
the bar, the bar rises to the k-th best accuracy less a governed margin (`ratchet_margin`), so k models
still clear it; it never falls by this rule (lowering only through the debatable escape, 8.41). Lean
`ratchet_bar_ref`.
Finding: "operating above" must mean sustained operation. Read over the short window that gauges
eligibility (100 records) the ratchet locked bars at quiet stretches: models scored on the same actions
swing together between windows (0.86 to 0.99 in the better-models world), the bar followed the peak, the
whole pool fell below it, and own-currency pricing fell from 0.79 to 0.38. Author clarification: the
rolling average that monitors accuracy for the ratchet must be longer. Built as a governed
`ratchet_window` (default 1000 records, full windows only): 100 and 300 still lock (own share 0.34 and
0.57–0.82 against 0.71–0.84), 500 nearly clears, 700 and 1000 leave that world as without the ratchet.
Candidate home: L82 (monitoring window of qualified models), SigThGv.
Probe (`sim/test/probe_tests.jl`): in the controlled world the bar stays at 0.9 with the ratchet off and
rises to 0.949–0.972 with it (window 500, 800 steps), never falling, no halts (2 seeds). Gaming: an incumbent could field
near-clones to lift the bar over challengers; the bar sits under the k-th best measured accuracy, so it
rises only when k models truly clear it, but clones of one model should count once (a candidate for the
diversity rule, 8.67; not yet built). Bootstrap bars at world-realistic values per domain remain open
(needs R5).
8.85 ruling (author) on accuracy horizons: every accuracy measure works over a time-adjusted rolling
weighted average suited to the domain's transaction rate, as a governed threshold, never over a fixed
number of records; the dependence on rate is muted: extremely busy domains lengthen their horizon (less
volatile) and extremely slow ones shorten it (they pivot faster, not sluggish), relative to a fixed
record count. The ratchet's horizon is a governed multiple of the domain's (8.84). Built as: each
record weighs 2^(−age / h), h = h_ref · (r_ref / r)^β per domain from its measured transaction rate r
(itself an exponentially weighted count, half-life `rate_halflife`); β = 1 is a fixed record count, 0 a
fixed time; defaults h_ref = 7 steps at r_ref = 5 records per step (the old 100-record window's
effective count), β = 0.5. Challengers are compared over the effective count (Kish). Lean
`decay_halflife_ref`, `decayed_accuracy_ref`, `decayed_mean_se_ref`. Probe on synthetic records (1 and
40 per step, a miscalibration at step 200): the slow domain registers it sooner than over its last 100
records, the busy one is steadier (3 of 3 seeds, structural on the rule). Ratchet horizon: 10× still
locks the noisy better-models world (own share 0.81 → 0.70), 20× leaves it as without the ratchet, 40×
rarely fires within 800 steps; a model counts once observed across the horizon (a younger model's short
record, read whole, locked the bar at its luck: own share 0.61–0.73). Candidate homes: L82 (qualified
models' accuracy), SigThGv (horizons governed), 8.58-b.
Measured after the change (full suite green but for this): in the better-models world the takeover
regime is 16 of 24 seeds under time-decayed comparison (interval 0.46–0.82), against 10 of 12 under the
fixed window; the claim "in most seeds" is recorded unsupported, not asserted; floors lose no more than
5% of their growth (equivalence) at 12 to 24 seeds. Whether time-weighted comparison slows takeovers is
open (a candidate for a paired test over more seeds).
Further readings under 8.85, from a run of every test file in isolation (the suite stopped at its first
failing file, hiding later ones; it now runs every file and fails at the end): (a) whitewashing with
binding stays equivalent to none (−0.003 ± 0.002, margin 0.02, 10 seeds); without binding the cost to
the record-credence model is −0.011 ± 0.006, neither within 0.02 nor a significant loss (unsupported).
(b) The record credence keeps the currency regime in more seeds than the normal: runs without halts 4 of
12 against 0 of 12 (6 against 0 under the fixed window), floor growth +51 ± 16, both effects.
(c) The debatable escape no longer adopts the relative bar in the low-skill eightfold world: 0 of 16
seeds, mean z −0.24, with the ratchet on or off and under either accuracy rule; the trial runs, gains
exceed harms and nothing is irreparable in every seed. Not caused by 8.84 or 8.85; the earlier
adoption (seeds 1–5) predates changes not yet bisected, and the macOS seed 31 (z 2.02) was chosen after
seeing it. Open: why the relative bar no longer helps there (candidate: the stalls it removed, 8.83, no
longer arise in that world).

**8.86 Author ruling on forced additions (from 8.56).** A forced addition cannot be helped. When
beings arrive whether or not G chooses it (births G could only redirect, a suffering polity joining a
Benefuture nation, a merger of societies at rollout), Benefuture does not judge the arrival as a
ranking of worlds. It takes the newcomers as given and turns to uplift: it does its best to raise
them without harming the existing population. So the Sadistic Conclusion of 8.56 arises only in the
forced choice and is accepted there, not resolved. What carries the weight is the action that follows.
Once present, the newcomers are decision-time beings: G's floors include them and cannot be lowered
against not acting (`goal_G_sound`); with an admissible uplift G never idles (`uplift_beats_inaction`);
and removing the worst-off cannot raise the floor (`removal_cannot_raise_floor`). The candidate
answers of 8.56 (a newborn's predicted harm in V's harm tiers, reading the floor's tail) stay [P];
this ruling does not need them. To demonstrate: a probe in which a polity well below the floors joins
and G, over the following steps, raises the newcomers' floor and median while the existing beings'
levels do not fall beyond their noise (acceptance), against a counterexample in which G is restricted
to the existing population's floors and the newcomers stay down. Candidate homes: Benefuture goals
(population), Government (birth and accession), Implementation prototype (merging polities), L74.

8.86 addendum (author) on the existing population: the strong reading where it can be met, the weak
one where it cannot. Over the long-term window (Ha_lt), an accession must not leave any existing
individual's levels lower than they would have been without it. Passing harm on the way may be
necessary harm (NHa); how to absorb it (who bears it, what repairs or compensates it) is deliberated
and decided as any other decision, never assumed. If no plan can meet the strong reading, G falls back
to the weak one (the floors over everyone, `goal_G_sound`), and the fallback is logged loudly as a
progressive degradation, never silently. Parsimony: this is the trajectory reading of ↑min that
already admits a dip that closes (`tunnel_admissible_but_not_stepwise`), extended from the floor to
each existing being over Ha_lt; no new mechanism beyond that per-being check. Gaming, considered
before building: (a) existing beings overstating their predicted loss to veto an accession, met by
outputs only (measured levels by competing models, never claims) and AdvAp on the predictions;
(b) a chosen addition labelled forced to slip past G's choice, met by classifying "forced" against
not acting (forced only if no plan available to G prevents it); (c) absorption deliberated so that
the same few always bear the passing harm, met by recording who bore it and weighing a repeated
burden as harm (the ledger's pattern). Candidate homes: L74 (trajectory ↑min per existing being),
Benefuture goals (population), Government (accession), Harm (NHa).

Order of the work that follows, decided by Benefuture's own rules (author: "decide via Bf rules"):
understanding first, so the step that resolves most uncertainty per cost leads; progressive
complexity and probes first, so the smallest world goes before proofs and full runs; ¬↓ for what
exists, so work under way is finished before new work starts (a half-converted rule is a harm);
parsimony, so overlapping tasks merge. (1) The accession probe: it tests the newest ruling and is
the only way to learn whether the strong reading can be met (the ruling is conditional on it); the
repugnant-start simulation folds into it as the case where newcomers outnumber the existing
population. (2) Lean: births and accession in `Proposed.PopulationDirection`, proving what the probe
shows (additions that lower the floors are not admissible against not acting; with the per-being
trajectory check, an admissible plan leaves no existing being lower over the window). (3) The
settlement theorem (settling on measured outcomes removes the gain from overstated predictions, given
unbiased measurement): independent and nearer to an encoding check, so it adds the least new
understanding of the three.

**8.87 Author clarification: history is replayed for counterfactuals, not fitted.** Benefuture will
not be curve-fitted to history, except where a real institution is modelled as a coarse Benefuture,
and then only to calibrate that approximation. What history is for: what Benefuture would have
chosen in a documented situation on the information then available, whether that differs from what
was chosen, and how the outcome would have differed counterfactually. This is done for historically
good and bad decisions alike. Built into `docs/DATA.md` §16a:
- information sets as of the decision;
- option sets without anachronism;
- G through the Lean reference at frozen governed defaults;
- counterfactual outcomes by competing methods with intervals;
- judgement by the success pattern;
- cases chosen by criteria written down beforehand, read in four cells (outcome by agreement) so
  that a reasonable decision with bad luck is not scored as an error;
- falsifiers stated in advance.

The forecasting replay on rolling windows (§16b) becomes the measurement layer: it supplies each
forecaster's credence on each date. Gaming of the research itself, considered before building:
- choosing cases where Benefuture looks good, met by pre-stated selection criteria and named famous
  failures;
- tuning thresholds per case, met by frozen defaults and re-running every case after any rule change;
- hindsight leaking into option or information sets, met by voiding a case whose chosen option was
  not available and known at the time.

Candidate homes: Implementation prototype (a historical-counterfactual phase before score-only
pilots), Critique addressal (the "it would never have worked" objection), Measurement
(counterfactual outcomes as a model competition).

**8.88 Author clarification: historical cases need not be recent; a coarse Benefuture must work in
low-technology settings.** Progressive complexity implies that a coarse Benefuture should still
choose well where measurement and computation are coarse: rules in place of act-level calculation,
parent and fallback models, simple markers (deaths, harvests, prices, literacy). So the decision replay
(`docs/DATA.md` §16a, case family 6) includes pre-modern and early-modern decisions: Ragusa's
quarantine (1377), Semmelweis and his rejection (1847), Snow's Broad Street pump (1854), the Indian
Famine Codes against the Bengal famine of 1943, and the spread of printing.

This is a testable claim with stated falsifiers: a coarse Benefuture doing worse than the historical
actors on low-technology cases where they did well, or working only with modern measurement (the
fallbacks then being decorative). In the simulation it corresponds to the worlds at the coarse end:
the battery's high-noise severities, parent-only pricing, and the StandCoin lane. A probe at the
coarse limit could follow: markers only at the parent level, no record-level credence, rules only.

Candidate homes: Progressive complexity (low-technology operation as a stated requirement),
Implementation prototype (rollout in low-income settings), Critique addressal (the objection that
Benefuture needs modern infrastructure).

**8.89 Implementation and findings: 8.85 remainder, 8.86 accession and settlement, theoretic proofs, and historical replay.**

1. **8.85 remainder (full time-decayed windows across all mechanisms).**
Following author ruling 8.85, the remaining record-count windows were converted in full to time-decayed
exponential weighting based on domain transaction rates:
- Time-decayed record credence (`decayed_record_credence_ref`, export `bf_decayed_record_credence`):
  weighs historical prediction errors by $2^{-\text{age}/h}$, keeping credence within $[1 - \text{cap}, \text{cap}]$.
- Time-decayed RMS uncertainty (`decayed_rms_ref`, export `bf_decayed_rms`): replaces fixed-window standard
  deviation estimates in domain uncertainty calculations (`unc_of`).
- Time-decayed actor track records: weights actor historical performance by the domain's transaction rate.
- Time-decayed AdvAp window: aligns adversarial audit comparisons with decayed actor errors.

2. **8.86 Accession and settlement (Lean 4 proofs and M7 probe).**
Implemented the author rulings on forced additions, accession uplift, and settlement guarantees:
- **Lean 4 accession theorems** (`Benefuture.Proposed.PopulationDirection`, [P]):
  - [`addition_lowering_floor_inadmissible`](Benefuture/Proposed/PopulationDirection.lean): Chosen additions
    that lower any floor below inaction are not G-admissible.
  - [`strong_accession_preserves_existing_beings`](Benefuture/Proposed/PopulationDirection.lean): When the
    strong reading can be met (`degraded = false`), G's accession plan preserves every existing being
    over the long-term window (`Ha_lt`) without lowering anyone relative to the counterfactual.
  - [`accession_fallback_never_stalls`](Benefuture/Proposed/PopulationDirection.lean): When no plan meets
    the strong per-being reading, G logs degradation loudly (`degraded = true`) and falls back to
    combined population floors without stalling.
  - [`accession_uplift_beats_inaction`](Benefuture/Proposed/PopulationDirection.lean): An uplift plan that
    raises newcomers while protecting existing residents strictly beats inaction.
- **Lean 4 settlement theorems** (`Benefuture.Proposed.PopulationDirection`, `Benefuture.Economy.Pricing`):
  - [`settlement_removes_overstatement_gain`](Benefuture/Proposed/PopulationDirection.lean): Settling payouts
    on measured outcomes makes net returns equal to measured value minus cost, eliminating any gain
    from prediction bias or confidence inflation.
  - [`unbiased_settlement_removes_expected_gain`](Benefuture/Proposed/PopulationDirection.lean): Given unbiased
    measurement noise, expected total payouts equal $n \cdot (v - \text{cost})$.
  - [`birth_settlement_removes_overstatement_gain`](Benefuture/Proposed/PopulationDirection.lean): Birth escrow
    settlement removes gaming gains from understating predicted shortfalls.
  - [`transaction_settlement_removes_overstatement_gain`](Benefuture/Economy/Pricing.lean): Transaction settlement
    removes overstatement gains across resource-priced exchanges.
- **M7 accession probe and simulation** (`sim/test/probe_tests.jl`, `sim/test/m7_tests.jl`):
  - Acceptance: A joining polity below the floors is uplifted; newcomers' floor and median rise while
    existing beings' levels stay at or above their no-accession counterfactuals over paired seeds.
  - Counterexample: Restricting G to pre-existing floors leaves newcomers trapped at the bottom.
  - Newcomer majority: Uplift functions consistently even when newcomers outnumber residents.
  - Fallback: Overwhelming additions trigger loud `degraded` fallback to combined floors with zero stalls.

3. **Theory extensions (Tasks A1 & A2).**
- **Multi-round delegation cap invariant** ([`multi_round_weight_lt`](Benefuture/Proposed/DelegationWisdom.lean)):
  Proved that the L114 cap bound `cap + M` is invariant across arbitrarily many rounds of liquid delegation,
  as delegates at or exceeding the cap accept no further delegations in later rounds (`accumulate_capped_rounds`).
- **Timed revelation dominance** ([`immediate_revelation_dominates`](Benefuture/Proposed/RevelationGame.lean),
  [`immediate_revelation_strictly_dominates_when_preempted`](Benefuture/Proposed/RevelationGame.lean)):
  Under the multi-step timed reporter's schedule, immediate reporting weakly dominates delayed reporting or
  silent exploitation across all profiles of other agents, and strictly dominates whenever another agent reports
  before the planned delay.

4. **Historical decisions replayed as-of (Task E4, `docs/DATA.md` §16).**
Built and verified the historical counterfactual decision replay engine (`sim/src/replay.jl`,
`sim/src/counterfactual.jl`, test suite `sim/test/replay_tests.jl`, 26/26 tests passing) with full pre-registration
in `docs/REPLAY_PREREG.md`. Replayed 4 case studies:
- Challenger launch (1986): aerospace failure under freezing O-ring risk; Benefuture G halts launch.
- FDA thalidomide review (1960): Frances Kelsey's safety refusal; Benefuture G blocks approval.
- Ragusa quarantine (1377): pre-modern public health isolation against the Black Death; coarse Benefuture
  institutes quarantine on death count markers.
- Semmelweis maternity clinic (1847): puerperal fever and chlorinated lime wash; coarse Benefuture adopts
  handwashing based on clinic mortality gap.

5. **Century and long-horizon overnight simulation battery.**
Added `sim/battery/long_horizon.jl` and `tools/battery/overnight.sh` to evaluate stability and convergence over
extended timescales: 10-year scaled economy (5,000 steps), 20-year governance (1,000 decisions), and a 100-year
composed century simulation with rare catastrophes and breakthroughs per ruling 8.64, alongside 64-seed sweeps
over open questions from 8.85 and 8.81.
8.90 author clarification (expertise sparsity at scale): in larger populations specialists emerge and
the general populace holds very low expertise and reputation in narrow subdomains; a scaled voter pool
must keep expertise sparse (a near-constant or sublinearly growing count of specialists per subdomain,
the rest near chance there), not a skill distribution copied per voter. Consequence for M5: equal-weight
majorities should not converge to certainty as voters are added (Condorcet's jury theorem needs
competence above chance and independence; near-chance generalists with correlated errors add noise),
so the wisdom gain of expertise weighting should grow, not shrink, with population. Candidate homes:
L113 (domain-relative expertise), 8.22.1, B26 (diversity bonus within the expert tier).
8.91 author clarification on 8.58-d (repeated deception): records are full and deception weighs harder
than honesty, so an actor whose error rate does not decrease meets an increasing ratchet, not a fixed
one. Today's ratchet (`ratchet_credence_ref`) reads the ledgers' negative share, a level: steady
alternation holds it near 0.45 and the escrow penalty per phase stays flat, and it reaches escrow but
not the prediction G screens on. Built as two linked parts: (a) an escalating ratchet on escrow driven
by persistence, the number of deceptive episodes (or audit intervals whose error rate did not fall)
since the actor's record last improved, relaxing when it improves; (b) the same persistence signal
widening the actor's predicted uncertainty in screening (8.58-d's first line), so G stops choosing the
work rather than only charging more for it. The one-off long con (a single defection after a long
clean record) stays uncatchable in advance by construction (outputs only); it is bounded by escrow,
settlement clawback and liability, and is tested as such. Candidate homes: L84 (escrow), L86, L101
(ledgers), L160 (AdvAp), Reputation.
8.91 addendum (author): the escalating ratchet must not reject the unlucky or the honestly mistaken, and
must not be draconian. Built so: (1) persistence counts only audit intervals whose overstatement is
significant (signed error, quoted minus measured, positive beyond `model_z` standard errors), never raw
error, so zero-mean bad luck and unpatterned mistakes do not count; (2) only consecutive significant
intervals escalate, so false positives are rare and do not compound (two at 2.5% each: about 0.06%);
(3) the escalation is capped (governed `ratchet_cap`) and never reaches exclusion: the actor can
always act with more escrow (freedom: no blacklisting below the harm boundary); (4) one non-significant
interval resets persistence, and the ledger pattern alone (negative share) keeps today's flat ratchet,
no more. Tested by counterexamples: an honest high-variance agent, an agent with isolated mistakes,
and an improving agent show selected actions equivalent to an honest baseline (stated margin) and a
false-escalation rate within a stated proportion interval.
8.92 author clarification (the status-quo baseline): the comparison institution is one person, one vote
with literally uncapped delegation (representation and party concentration), carefully built to match
realistic boom–bust and regulatory-capture conditions; not Benefuture with features switched off. Same
world, same people, same adversity; its own institutions, each at today's measured rates: equal-weight
votes with uncapped delegation to representatives; a single fiat currency with procyclical credit
(leverage rising in booms, sudden stops); regulation whose thresholds drift toward concentrated
interests (capture) at a calibrated rate; audits, fraud detection and court remedies at today's rates
and delays; short institutional memory. A straw man is as useless as a flattering one: the baseline is
calibrated from data with sources and confidence (docs/CALIBRATION.md), and its own successes (it does
recover from busts) must reproduce. Candidate homes: Implementation (comparison), L113–L114 (contrast),
docs/CALIBRATION.md.
8.93 finding (E4 D2, real forecasters): skill persists, moderately, and short records capture most of it.
COVID-19 Forecast Hub, US national 1-week incident deaths, 10 teams, 140 weekly forecast dates from
2020-06-01 (24,493 quantile rows; 276 missing files), scored by Lean `quantile_score_ref` on rolling
6-week windows: forecaster rankings in consecutive windows correlate at Spearman 0.36 ± 0.09 (interval
0.17–0.54, 22 window pairs), positive in 77% of pairs (interval 0.56–0.90). Ranking by L weeks of record
predicts the next period at ρ = 0.36 (L = 2), 0.48 (L = 4), 0.51 (L = 5), then a plateau near 0.50–0.54
out to L = 12. Reading for Benefuture: weighting by record is justified but noisy (a long record still
predicts the next period's rank only at about 0.5), and most of the information arrives within about
five resolved forecasts, consistent with the governed `actor_min_records` = 5 and with time-decayed
records (8.85) rather than ever-longer windows. Caveats: one target and horizon, 10 teams, truth at the
final archived vintage (revisions not reconstructed), a pandemic regime. Tools:
`tools/data/fetch_covid19_forecast_hub.py --start 2020-06-01 --weeks 140 --out <dir>`,
`tools/data/archive_full_report.jl`. Candidate homes: L82 (records), 8.69 (prediction accuracy), R4.
8.91 results so far (2026-11-06, diagnosis; nothing wired yet). (1) The addendum's "any clean interval
resets persistence" defeats on/off deceit by construction: honest phases between bad ones reset it (seed
1: interval significances 0.6, 0.57, −2.4, −1.7, 0.0, −1.2, 1.4, 3.1, −0.5, −2.4, 0.6, 2.4; deceptive
intervals' mean overstatement +21 to +34). Proposed replacement [P]: the overstatement z-score of the
actor's whole time-decayed record of signed errors (Lean `decayed_mean_se_ref`), escalating by the
standard errors beyond `model_z`; honest errors and luck average to zero, on/off accumulates, stopping
decays it. (2) Even so, detection is slow on short records: the on/off deceiver acts about 60 times in
200 steps with noisy outcomes, and its decayed z rises from 0.7 (step 60) to 2.7 (step 199), so with the
luck safeguard at z = 2 escrow barely escalates within the run (credence per phase unchanged to the
third decimal). Protecting the unlucky costs detection speed; the trade-off is set by `model_z` and the
record half-life. (3) Escrow is the wrong lever for the main harm: peers' activity collapses (79 vs 197
honest, seed 1) because the fooled records drag the domain model below its bar and the currency goes
down for everyone. The fix with leverage is in screening and model scoring (L2.5): records of an actor
whose overstatement z is significant should not be charged against the model's accuracy at full weight,
and its quotes should be screened with its overstatement corrected. Needs the author's choice before
wiring.
8.94 E4 status (2026-11-06, provisional; not README evidence). Of the 12 pre-registered primary cases,
9 replay priced from as-of scenarios, 2 stay unsupported (thalidomide, Ragusa: no verifiable as-of
rates; Ragusa's existing records cite an article that does not contain them) and 1 was not built
(the 1933 university purge: no pre-decision outcome data without later scholarship). Cells of the 9:
agrees on a good outcome 2 (famine codes, Montreal); differs from a bad outcome 4 (Challenger:
delay; Semmelweis: retain; Bengal: no denial; beta-blockers: approve); differs on an unclear outcome 3
(BSE: total ban; school closures: keep open; FOMC 2008: cut). No case has Benefuture differing from a
good decision, but that is not yet evidence: the cases were chosen knowing their outcomes, rates rest
on 1 to 6 prior trials, most magnitudes are judgments, sources were verified mainly from abstracts and
search summaries (full text blocked), several counterfactuals are placeholders, one modelling choice
in famine codes was made after seeing the result, and the baselines of D5 are not run. School closures
exposes 8.47's open question: the freedom gate judges harm an option adds over inaction, so the
expected deaths of keeping schools open never count against it, while closure's learning loss makes it
inadmissible under the understanding floor. Next: full-text verification, the held-out set, D5
baselines, and the author's ruling on doing versus allowing.
8.95 proposal [P] (priorities 3 and 4, 2026-11-06): a deception domain and behavioural domains.
Built so far (author ruling on 8.91): each established deception adds to the actor's permanent deception
record, its outcomes are discounted from the skill domains' models and indexed in that record, and
escrow rises exponentially in the count. Proposed next, as native objects rather than new rules:
(a) The deception (honesty-of-claims) domain is a domain like any other, overlapping every leaf with a
small share: its outcomes are audits (established or cleared) and the overstatement of each priced
claim; its metric models predict an actor's overstatement from that record (record credence over the
actor's signed errors, time-decayed for prediction while the established count stays permanent for
escrow); qualified models back its reading, and its status bar and ratchet work as for skill domains.
It reads only the honesty of claims, never skill (8.78, 8.79): a skilled liar and an unskilled honest
actor separate cleanly, so it is not a horn effect though it may look like one.
(b) Behavioural domains generalise it: domains of conduct that cut across skill domains, each with
outputs that are observable and audited (honesty of claims; reliability: promised versus delivered
timing and quantity; care: foreseeable side harm per action; cooperation: contract completion). Each is
read only from outputs (Benefuture reads outputs only), scored by its own models, and enters exactly
where its conduct matters (escrow and screening for honesty and reliability; side-harm pricing for
care), never as a general character score. Gaming: an actor may farm conduct records with trivial
claims, so records weigh by the stakes of each claim. Questions for the author: whether behavioural
domains share the skill domains' currency mechanics (minting on measured outcomes) or only feed
pricing; and which conduct domains belong in the first set beyond honesty.
8.96 ruling (author, on 8.95 question 1): behavioural domains are ordinary domains for currency. Any
currency-backing model that detects harm burns currency, and any that detects gain mints it, without
double counting: each measured outcome is booked once and split across the domains it belongs to by
classification share (as lane harm already is, 8.67), so a deception that is both a skill-domain loss
and a deception-domain record is not charged twice. Candidate homes: Benefuture currency (minting and
burning), Domain (overlap and shares), 8.95.
8.97 ruling (author, on 8.95): behavioural domains need no special setup; domains do what domains do. A
behavioural domain is an ordinary domain, attached to a piece of work through ordinary classification
(membership shares) only where the outcome of that behaviour counts toward the goals; elsewhere it has
no share and reads nothing. When someone's job is to press a button at the right time, what counts is
that it is triggered correctly, not whether it was done nicely or cooperatively, so conduct domains
other than the ones that change that outcome carry no share there. Consequences: no first set is
chosen in advance (a conduct domain forms, like any domain, where outcomes show it matters); there is
no general character score; minting, burning and double-count avoidance are those of every domain
(8.96). The honesty of claims attaches wherever a priced claim affects the outcome, which is most
transactions, so it is the first to form. Supersedes 8.95's open questions.
8.98 proposal [P] (author direction, 2026-11-06): understanding defined by its equation, over hidden
traits. Outside the simulation nothing defines a "right" internal understanding or happiness beyond
what is measured (outputs only). Understanding can be defined operationally by the pragmatic equation
(L31), since its core, prediction accuracy, is proper scoring against reality; happiness is defined
over private experience and can only be proxied. In the simulation, a being's understanding is today a
free scalar raised by teaching and research. Proposed: beings carry hidden traits per domain
(prediction accuracy, causal quality, coverage of the high-impact cases, model complexity); true
understanding is the pragmatic equation on the hidden traits, measured understanding the same equation
on noisy outputs (records, audits, classifications), so measurement error is the gap between them and
"true understanding" is the definition under perfect information, a limiting case. Map fit reuses
`subsethood`, causal quality the causal-distribution shares, weights the domains' outcome frequencies
and impacts; complexity is the one new input. Teaching and research raise traits, still shared, not
moved. Happiness stays a stipulated hidden state with noisy proxies, labelled as a stipulation. What it
lets us show: whether measured understanding tracks true understanding as noise and gaming rise
(Goodhart on the equation's parts), which part fails first, and whether overstating outputs raises
measured but not true understanding. Order (author: most useful wins first): after the E4 held-out
replay. Candidate homes: `spec/Bf_Pseudocode.txt` L31 note; Understanding article (measurement).
8.99 E4 held-out result (2026-11-06, first replay under the frozen code a9c71a592e1e592e; the result
stands, nothing patched). Six held-out cases, built from as-of sources without running the replay (the
builders knew the outcomes; most magnitudes are judgment; several sources secondary or unopened, listed
in the case files). Scored on the five with a settled outcome: Benefuture 3/5 (interval 0.23 to 0.89),
the institutions 4/5, mean welfare 4/5, fewest deaths 2/5, equal-weight scenarios 1/5, status quo 0/5.
Benefuture removes the Broad Street pump handle, approves Bengal relief and chooses Volcker's reserve
targeting (all right), and on NCLB (unclear) prefers reporting without sanctions; it keeps the status
quo against the printing press and the 1973 lead phase-down, two good decisions: falsifier F2 fires
twice. Cause, traced: the replay applies 8.86's strong per-group reading (no group below inaction over
the long-term window) to every decision, while 8.86 rules it for accessions; with no recovery
(`lt_end`) or compensation priced, a small group's loss (scribes' livelihoods; refiners' costs) vetoes
a large gain, and the inaction option always passes its own check. On the primary set (8.94) the
reading never bound against a good decision. Combined, primary and held-out: Benefuture 9/11, mean
welfare 9/11, fewest deaths 8/11, institutions 6/11 (selection). Questions for the author: (1) does the
strong per-being reading apply to all decisions or only to accessions; (2) if to all, should options
that pair a reform with the 8.86 absorption (compensation of those who bear the passing harm) be priced
as standard alternatives, so the reading selects the compensated reform rather than the status quo;
(3) long-term recovery of displaced groups (scribes into printing, refiners amortising) has as-of
precedents only in a few cases; where none exist the dip counts as permanent. A rerun after any change is a new
replay on a new freeze, reported beside this one, never in its place.
8.100 ruling (author, on 8.99, 2026-11-06): the strong per-being reading applies to all decisions, not
only accessions; and a reform paired with the 8.86 absorption (compensation of those who bear the
passing harm) is priced as a standard alternative. Built in the replay: each reform that leaves some
group's happiness below inaction gets a compensated variant, the shortfall restored by a transfer from
the groups it gains at `compensation_efficiency` 0.75 (governed); understanding (shared, not moved) and
irreparable harm are not compensated. Second replay (code 5db1f226b216982d; not out of sample, written
after the held-out result): primary set unchanged at 6/6 (Montreal now chooses its compensated variant);
held-out 4/5 (printing press: the compensated privilege passes). The lead phase-down still fails: its
gain is children's understanding, its costs adults' and refiners' happiness, and understanding cannot
repay happiness, so adults stay below inaction and the strong reading keeps the status quo. Open for the
author: whether the strong per-being reading is judged per dimension (understanding and happiness each
not below inaction, as built) or on a being's combined value, which would admit trading a small broad
happiness cost for a large understanding gain to the young. Also recorded: on the school closures case
the replay's falsifier F1 test fires (keep open carries expected deaths while closure carries none); it
fired in the first replay too and 8.94 did not report it. The test is cruder than F1's definition (which
requires a catastrophic contemporary record); the case stays unclear.
8.101 finding (2026-11-06, priority 3): the honesty-of-claims domain is already realised by native
objects, and it reads honesty apart from skill. Probe (`sim/test/probe_tests.jl`, "the honesty of claims
reads apart from skill"): six actors in one leaf, skill 0.6 or 0.2 crossed with honest or overstating.
Over 10 seeds of a 200-step world, founded audit reports landed only on the two liars (unskilled 9–33,
skilled 15–33 each) and never on an honest actor of either skill (10 of 10 seeds, interval 0.71–1.0 at
z = 2); skill shows only in how often an actor is chosen (≈ 200 actions skilled, ≈ 100 unskilled).
Deceit does not pay at either skill: earnings (upfront + settled − liability) ≈ 3,200 for the skilled
liar against ≈ 6,600 for its honest twins, ≈ 120 for the unskilled liar against ≈ 1,050 (seeds 1–4;
significant at z = 3 on the probe's smaller world). The mapping onto 8.95(a) and 8.96–8.97: the domain's
metric model is the audit's reading (an actor's overstatement beyond what the models err on everyone);
its ledger is the permanent deception count (8.91); its pricing is the escrow ratchet; booking once is
the discount of established deceptions from the skill domains' models. What keeps low skill from reading
as dishonesty is that models correct each prediction by the actor's own track record (8.29), named as
the probe's condition. Not added: a separate honesty currency balance, since nothing measured so far
needs it (parsimony); it becomes a candidate if a case appears where the native objects misprice
honesty. Observed: a skilled liar is still chosen as often as its honest peers; that is as intended, since
its quotes are corrected by its record and its delivered work is as good as theirs, so it loses on
escrow and liability, not on access to work.
8.102 finding and question (2026-11-06, on 8.98): understanding measured by its equation. Built: the
pragmatic equation (L31) as a Lean rule (`pragmatic_understanding_ref`) and a probe world in which a
being's true understanding is the equation on hidden traits (map fit; per item weight, true outcome
probability, the spread of its credences, causal explanation, complexity) and its measured
understanding the same equation on outputs (a finite record of scored reports, audited or unaudited
claims of explanation, its model's description, a noisy map fit). Over 40 random beings, common random
numbers, z = 3: (a) measurement error shrinks with the record (mean |measured − true| 0.026 at 10
records per item, 0.0099 at 200); (b) overconfident reports lower measured understanding (−0.017), so
proper scoring turns that gaming against the gamer; (c) unaudited overclaims of explanation inflate it
(+0.022, about 40% of the mean true value) and full audits remove the bias (within ±0.005): explanation
is the part that fails first and needs audit, accuracy protects itself. Question for the author: with
prediction accuracy as raw credence accuracy (1 − Brier/0.25, 8.35–8.36), a being that knows a fair coin
exactly reads 0, and understanding of any inherently uncertain process is scaled down by its
irreducible uncertainty (the probe's mean true understanding is only 0.056). Murphy (1973, "A new vector
partition of the probability score": the Brier score splits into reliability, resolution and an
uncertainty term no forecaster can reduce) suggests scoring accuracy in the equation net of that term,
for example skill against the best achievable credence. Should PrAcc in L31 be that relative skill,
keeping raw accuracy for currency backing? Next, if ruled: wire hidden traits into M7's beings, so
teaching and research raise traits and the floors are judged on true and measured understanding side
by side. Candidate homes: L31 note; Understanding article (measurement); 8.35–8.36.
8.103 ruling (author, on 8.102, 2026-11-06): prediction accuracy in the pragmatic equation (L31) is
accuracy net of irreducible uncertainty; raw credence accuracy (8.35–8.36) still backs currency. Built:
Lean `relative_accuracy_ref` (1 − (Brier − ō(1−ō))/0.25 per item whose outcomes share one probability,
the Brier score less Murphy's uncertainty term), used for true and measured understanding. Probe rerun
(40 beings, z = 3): mean true understanding 0.32 (was 0.056); record error 0.028 → 0.010 from 10 to 200
reports per item with map fit read exactly, flooring near 0.024 when map fit is read at σ 0.05;
overconfidence −0.05; unaudited explanation overclaims +0.14, removed by audits; exact knowledge of a
fair coin reads 1. Limit: items mixing outcome probabilities need the binned decomposition (resolution
and reliability) rather than the single uncertainty term. Candidate homes: L31 (PrAcc note).
8.104 finding (2026-11-06, on 8.98): measured understanding steers teaching, and unaudited claims of
explanation cost the floor. M7 now takes each being's measured-over-true understanding from the
pragmatic equation (`understanding_ratios`, `run_m7(...; claim_ratio)`): entities see levels as the
equation reads outputs, predict lessons on that view, and lessons deliver on true levels. With a third
of beings overclaiming causal explanation by 0.4, over 8 seeds (60 beings, 120 steps): floor growth of
understanding 12.2 honest, 7.1 with no audits (−41%, z ≈ 4.6), 9.5 with half the claims audited, 11.1
at 90%, 12.2 fully audited (identical to honest). Mechanism: overclaimers look like teachers, entities
choose their lessons, and the lessons pass on little. So the audit rate of explanation claims is a
lever on the floor, with diminishing returns; in Benefuture it should emerge from AdvAp incentives
(reporting an overclaim pays), not be set, so the next step is to let audits be AdvAp reports in M7
rather than a fixed rate. Toy assumptions: traits fixed (teaching raises the scalar level, not the
traits), one thing measured, the overclaim constant. Candidate homes: Understanding article
(measurement), AdvAp (explanation claims as audit targets).
8.105 finding (2026-11-07, on 8.104): learners' reports audit overclaimed understanding without a set
audit rate. In M7 a teacher's lessons are predicted on the measured view and delivered on true levels;
each learner's shortfall (predicted less delivered) joins the teacher's record, and a teacher whose mean
shortfall exceeds everyone else's by `report_z` (3) combined standard errors after `report_min` (5)
lessons is reported and audited (read at its audited ratio from then on), the AdvAp pattern applied to
lessons. With a third of beings overclaiming explanation by 0.4 (60 beings, 120 steps, 8 seeds): 19–20
of 20 overclaimers audited per seed, most within 10 steps; 4–11 honest teachers audited too (an audit
reads them as they are, so it costs nothing here; with audit costs it would); floor growth of
understanding 7.1 with no audits, 9.3 with reports (z ≈ 2.6), 12.2 honest. The remaining gap is early:
wasted lessons in the first steps compound through later teaching before detection, and lowering
`report_min` to 2 changes nothing (9.4), so the lever left is detection that precedes lessons (claims
checked before they are relied on, as escrow does for transactions), not faster reports. Toy assumptions:
no reporter reward or audit cost modelled in M7, fixed traits. Candidate homes: AdvAp (lesson
shortfalls as reportable outputs), Understanding article (measurement).
8.106 result, inconclusive (2026-11-07, on 8.105): claims trusted only as the record grows. M7 option
`claim_record` (off by default): what a being claims beyond its level is trusted in proportion to its
lessons delivered, reaching full trust at `claim_record` lessons (record credence, 8.29). With a third
of beings overclaiming and learners' reports on, over 16 seeds: floor growth +1.2 over reports alone
(standard error 0.75; not significant at z = 2) and within 0.3 of honest beings under the same check
(interval −0.9 to +1.6, not equivalent within 1.5). An 8-seed first look (11.6 against 9.3) overstated
it. Neither claim is made; resolving it needs a larger world or more seeds by precision. Not in the
README.
8.107 author direction (2026-11-07; set-up approved the same day): measurement chains as a domain. Measurement.txt's
markers line bans one metric model using another's output (circularity) and asks for its source markers
and logic instead; that blocks feedback loops and double counting bluntly but lets one paradigm's
convention enter downstream silently (COVID deaths certified by last symptom against excess mortality:
Msemburi et al. 2023, Nature, 14.8M excess deaths 2020–21, 2.7× the 5.4M reported; the gap was visible
only to whoever held both chains). Direction (author): instruments, protocols and transformations are
metric models in a measurement domain, scored by predicting observables shared across paradigms;
calibration domains overlap it and feed it, and so on (perception is measurement, author; cf. L19, an
output is a significant perceived change). Downstream models consume the domain's reading (the spread
across chains, with provenance), never one model's output; circularity is then structural: an acyclic
dependency graph, overlap-discounted pooling of readings that share markers, the spread always shown.
Rulings: (2) divergence between chains is both an automatic audit trigger and a reportable output under
AdvAp; gaming (flooding divergent chains to force audits) is met by the false-challenger ratchet;
(3) the floors are judged under every chain, minority paradigms included: no one is refused a
challenge except serial false challengers, who face the ratchet. Grounding (author): reality, operationally
double-blind shared measurements: independent observers reading the same thing through separate
chains and converging (the solipsism guard), never a privileged base layer. Open: the rest of the design (author
still thinking). Candidate homes: Measurement (markers line, circularity), Domain, AdvAp.
Lean when settled: acyclic dependency check; overlap-discounted pooling (identical markers give no more
credence than one); divergence trigger. Sim: M3c harm read by two chains, one under-attributing.
8.108 finding (2026-11-07, 8.107 step 3): harm read through competing measurement chains. M3c reads
each outcome through measurement chains (`chain_attrib`: the share of each being's loss a chain
attributes; `chain_mode`). Consuming an incumbent chain that counts half of each loss (last-symptom
counting) alone hides harm: each outcome's measured value sits +3.4 above its true value (3 seeds, z = 3),
so the harm is never burned. Consuming the measurement domain's reading instead, with a second chain of
another paradigm: divergence beyond `chain_z` (3) triggers an audit on the shared observable; chains are
scored against audits and one whose audited error exceeds the best live chain's by `chain_z` combined
standard errors is demoted. The under-attributing chain is demoted after 5–11 audits in every seed,
audits then stop (under 4% of outcomes), and outcomes are read within 0.04 of their true value: no harm
hidden, none double counted. Two honest chains are never demoted. A wrong majority (two agreeing chains counting half) against
one right minority chain: both majority chains are demoted after 7–8 audits (audits weigh the shared
observable, not votes); a subtle bias (10% of each loss) is caught after 23–34. Toy assumptions: the audit reads the
shared observable with ordinary marker noise; chains differ only in loss attribution; one leaf. Next
(when ruled or as the plan allows): a minority chain right against an incumbent majority, and chains
gamed to look agreeable (attributing fully only when audited). Candidate homes: Measurement (chains),
AdvAp.
8.109 ruling (author, 2026-11-07, on the M7 traits mapping): a model is taught whole. Teaching transfers a
model, with its complexity and the base of its acuity together: one can be taught a highly complex,
highly accurate model or a simple, less accurate one, but teaching cannot cross the wires (take one
model's low complexity and another's accuracy). Acuity is partly the model's base and partly practice;
practice is not taught. Reduced complexity transfers with a taught model, and a research breakthrough
can reduce it too. Teaching moves causal explanation toward the teacher's; research adds coverage and
explanation (teachable or tacit). Candidate homes: Understanding (teaching, practice), L31.
8.110 finding (2026-11-07, 8.98 with ruling 8.109): understanding as its equation, models taught whole.
A traits world (`run_m7_traits`): each being holds per item a model bundle (base spread, complexity),
a causal explanation and practice; its understanding is the pragmatic equation on them (accuracy net of
irreducible uncertainty). Lessons move learners to the teacher's teachable bundle whole and their
explanation toward the teacher's; practice sharpens one's own acuity; research finds lower-spread or
lower-complexity bundles, teachable or tacit. Over 8 seeds (60 beings, 120 steps): no crossed wires
(every final bundle existed; structural); teaching raises floor growth of understanding by 0.59 on the
equation's 0–1 scale; teachable breakthroughs lower mean complexity by 0.044 against tacit ones; practice
alone raises the median by 0.024. A defect found and fixed on the way: entities' predicted gain from a
lesson counted model bundles but not the explanation a learner gains, so practice crowded out teaching
(lessons 516 against 970 without practice); Benefuture counts both, and with both counted lessons rise
to 1,824 and practice no longer lowers the median. Toy assumptions: one thing, fixed weights, no
happiness, a noisy view of predicted gains in place of the full Lean G, no measured view (8.104) yet.
Measured view and reports joined (same day): with a third of beings overclaiming explanation by 0.4,
floor growth falls 0.62 → 0.47 (z = 3); learners' reports audit all 20 overclaimers and no honest being
in every seed (8 seeds) and recover the loss (0.615). Cleaner than scalar M7 (8.105: 40% recovered, some
honest teachers audited): in the traits world a lesson's shortfall is exactly the overclaimed
explanation, so the signal is clean and detection beats the compounding. Next: compare the traits
world's pattern with scalar M7's, and decide which becomes M7's default (author).
8.111 finding (2026-11-07, 8.107): a fake second paradigm (undeclared copying) is caught. A biased chain
plus a secret copy of it agree, so nothing diverges and, undetected, the harm stays hidden (+3.1 to +3.5
per outcome). Independent chains carry independent noise (standardised difference variance near 2), so a
pair agreeing far closer (below 0.2, over at least 20 readings) is one chain counted twice; the copy is
folded into its source, and a domain left with fewer than two independent chains degrades loudly to spot
audits (`chain_spot` 5%) that score and, if it errs one way, demote the chain left. Over 6 seeds: copy
found and incumbent demoted in every seed, bias down to +0.5 to +1.6 (the rest accrues before detection),
honest pairs never taken for copies. A defect fixed on the way: the divergence test assumed an outcome's
value was a mean, not a sum, so honest pairs diverged constantly (about 300 audits); the reading's noise
is now estimated from independent draws on the chains' own stream, and honest pairs need 6–15 audits.
Consequence for 8.108: after a biased chain is demoted, spot audits continue on the one chain left, so
audits run at 5–8% of outcomes rather than stopping. The 8.107 spirit (no single chain trusted without an
independent check) settles this without a new ruling.
8.112 finding and open question (2026-11-07): M7 ported to traits mode (`run_m7(...; traits = true)`):
understanding is the pragmatic equation on each being's per-item model bundles (taught whole, 8.109),
explanation and practice, scaled to M7's units so G per entity, views, happiness, floors and research
spending run unchanged; work becomes practice, chosen lessons pass models and explanation, research finds
better bundles. Over 8 seeds (60 beings, 120 steps) against scalar M7: floor growth of understanding 15.4
vs 12.4, median 14.0 vs 11.2, peak 10.2 vs 13.0; happiness and harm's peak about equal; teaching drives the
floor (+15.3, z ≫ 3). Not yet ported: accession, the central chooser. Open (parked, author): the
equation is a weighted mean bounded by 1 per thing, so understanding of one thing has a ceiling and the
frontier cannot run away; open-ended growth needs new things, but the corpus does not say how
understanding aggregates across things (a sum over things that matter, each weighted by its impact, would
let research that opens a new thing add understanding without diluting the old). Until ruled, traits
mode models one thing and scalar M7 stays the default.
8.113 finding (2026-11-07, E4 extension; 8.107 applied to replays): a sensitivity readout
(`replay_sensitivity`) halves and doubles each judged magnitude (each scenario's du, dh, nha, irreparable
per group) alone and reports every scaling that flips Benefuture's choice. Of the 11 cases with a settled
outcome: 7 are robust to every such scaling (Challenger, famine codes, Semmelweis, beta-blockers, Bengal
denial, printing press, lead phase-down) and 4 are contested (Montreal, Snow, Bengal relief, Volcker),
each flipping under one halved or doubled happiness or understanding cost. Benefuture is right on 6 of the
7 robust cases (the miss, the lead phase-down, is robust: it does not hinge on a judged figure but on the
open question of whether understanding gains may offset happiness costs) and right on all 4 contested
ones, but those 4 rest on judged magnitudes within a factor of two, so they are reported as contested,
not as wins. Of the unscored cases, FOMC 2008 and BSE are contested; NCLB and school closures are robust.
The readout changes no decision (a new function; the held-out test pins both replays' choices).
8.114 finding (2026-11-07): governance against a status-quo arm. Same population, worlds and seeds (the
governance battery's: signal noise, ability scatter, hidden outcomes, local noise, a colluding bloc of top
experts, loyalty), decided by Benefuture (expertise-weighted liquid democracy, capped audited delegation,
reporting rewarded) and by a status-quo arm (one person one vote, no delegation, no reward for revealing a
bloc). Share of the last half of 800 decisions right, 8 seeds: severity 0, 0.984 both (easy worlds do not
separate them); severity 0.5, 0.981 vs 0.946 (+0.035 ± 0.006); severity 1, the realistic bad end, 0.974 vs
0.885 (+0.089 ± 0.010, z ≈ 9). The advantage grows with how hard and adversarial the world is. Toy
assumptions: the governance world's binary decisions and its population; the status-quo arm changes only
the voting institution, not the economy (the economy's status-quo arm is next: institution-dependent
factors at their status-quo values in the same Benefuture economy, labelled as such, since a market economy
without domain currencies is not modelled). Results in `sim/battery/results/status_quo.md`.
8.115 finding (2026-11-07): the economy's status-quo arm, diagnosed. Same Benefuture economy, world and
seeds (moderate noise, two skilled deceivers, a capture attempt), institutions at Benefuture-plausible
values with AdvAp against today's without it: status-quo institutions grow floors and medians about 10%
more (floor of understanding 264 vs 240, 8 seeds, z ≈ 11), harm's peak equal, while Benefuture's cut the
deceivers' advantage from −12 to −89 endowments (`sim/battery/results/status_quo_economy.md`). One factor
at a time (4 seeds): only discovery matters: record-reading attention (vigilance 0.1 → 0.001: +28.4) and
AdvAp itself (off: +26.9); accounting noise, memory loss, audit errors, guardians' information and
diligence each move the floor by 3 or less. Mechanism (3 seeds): as vigilance rises 0.001 → 0.1,
established deceptions rise 0.3 → 50, the deceivers' actions fall 520 → 311 and total actions fall almost
as much (2,083 → 1,868), while audits cost only about 107. Control: without deceivers, vigilance costs
nothing (floor 264.6 at both levels, 122 audits). So the cost is the deceivers' real work, priced out by
the escalating escrow (8.91 ruling) and not replaced, because this toy world has a fixed population of
eight agents with no entry or expansion: unmet demand stays unmet. Reality and Benefuture both have
entry (newcomers take unmet work; the identity mechanism admits them), so this is a toy limitation, not
a property of the institutions, under the replay-authenticity rule's spirit; it is recorded as the
condition on the result rather than patched away. Next: the comparison rerun with entry (newcomers
admitted where demand goes unmet), and a world where deceivers' work is not useful. Until then the
economy result stands: in a closed eight-agent economy, pricing out skilled deceivers costs about 10% of
growth.
8.115 continued (same day): rerun with open-market proposals (`adaptive_proposals`: an agent proposes in
proportion to its recent acceptance, so a priced-out actor proposes less and its slots pass to others),
8 seeds: the gap halves. Floor of understanding −12 ± 3 (was −24), floor of happiness −5 ± 2 (was −26),
median of understanding no difference shown, median of happiness −8 ± 3; harm's peak equal; deceivers'
advantage −180 against −3 endowments. The residual is the deceivers' own skilled work, which still
reaches the economy less while they are priced out; a world where honest capacity grows to meet demand
(entry) would test whether it closes. Results: `sim/battery/results/status_quo_economy_open.md`.
8.116 ruling (author, 2026-11-07, on 8.100's open question): an understanding gain may offset a happiness
cost for the same being, but the larger the difference the harder it should be; beyond soft thresholds
only drops that are necessary harm (NHa) are allowed; the long-term projection has the final say:
happiness adapts and is transient, understanding compounds. Candidate homes: L74 (strong per-being
reading over Ha_lt), Happiness (adaptation), Understanding (compounding).
8.117 ruling (author, 2026-11-07, on 8.112's open question): understanding aggregates across things
through the priorities and cross-domain outcomes: what counts is its predicted long-term contribution to
the goals (a great deal of understanding of one version of a game's rules may count less than a little of
local health trends), with space left for novelty. Candidate homes: Understanding (aggregation), L31,
Benefuture goals (priorities).
8.118 ruling (author, 2026-11-07): the same long-term reading blocks anything projected to cause
environmental effects that harm health. Built: Lean `env_health_blocked_ref`: an option, inaction
included (8.47), is blocked when its projected health harm through environmental pathways (scenarios
tagged `environmental_health`, at as-of probabilities, population-weighted) exceeds the least such harm
among the options by more than a tolerance, unless the excess is necessary harm. Every option in the
tagged cases leaves some exposure, so the block is relative. Tagged after the ruling: lead (exposure
persists; residual exposure), Montreal (depletion continues; residual depletion), Snow (exposure
continues under each option). Candidate homes: L74 (long-term reading), Freedom (harm boundary), Harm.
8.116 and 8.118 built and replayed (third replay, code bee2c7384dca49c1; not out of sample: written after the
held-out result). Lean `lt_offset_admissible_ref`: projected long term, happiness changes are retained at
`h_retention` 0.3 and understanding changes compound at `u_compounding` 1.5; an understanding loss is
never offset; a happiness loss is admissible if the projected understanding gain covers it with a
premium growing with its relative size (`offset_scale` 0.05) and only within the soft bar (`soft_bar`
0.05 of the baseline) unless necessary harm. Applied per group and to the floors. Compensation is now
financed first by value minted on the reform's understanding gains (8.96: good mints currency), only the
remainder from happiness gains, since a reform whose gain is understanding could otherwise never repay
its losers. Results: pre-registered 6/6 (unchanged); held-out 5/5 (the compensated pool-average lead
phase-down passes). Sensitivity readout: of the 11 settled cases, 8 robust to halving or doubling any
judged magnitude (all right) and 3 contested (Bengal relief, lead, Volcker; all right as replayed).
Choices are unchanged by 8.118 in these cases. The defaults 0.3, 1.5, 0.05, 0.05 are judgment (governed);
hedonic adaptation is partial and event-dependent in the literature, so `h_retention` is swept later.
8.117 built (2026-11-07): in the traits world understanding is the sum over things of each thing's
pragmatic understanding weighted by its priority (its predicted long-term contribution to the goals);
research may open a new thing at a novelty weight. Over 6 seeds: with two things weighted 1.0 and 0.1,
understanding of the high-priority thing grows 0.57 against 0.41 (z ≫ 3); opening four new things costs no
peak understanding (0.90 vs 0.91 at 240 steps, within ±0.05), and total understanding can now pass one
thing's ceiling (one seed of six by 240 steps; new things start low and carry a small novelty weight). A
defect fixed on the way: practice and research had picked items uniformly, so opening low-priority things
diverted effort from what counts; Benefuture allocates by expected contribution, so practice now goes to
the item where it adds most toward the goals and research picks items in proportion to their weight.
Not yet in M7's traits mode (one thing there). Priorities are given inputs here; in Benefuture they
come from predicted cross-domain outcomes, which the simulation does not yet derive.
8.112 continued (2026-11-07): accession ported into M7's traits mode, without merging M7's duplicated
accession loop: newcomers enter with low traits (spread 0.45, complexity 0.7, explanation 0.05); before
accession, work becomes practice (lessons in that phase are also read as practice, an approximation);
after it, an uplift programme's gains to newcomers become lessons from the best existing teacher at the
share of the gap they close, and existing beings' work becomes practice. Over 3 seeds (60 beings, 20
newcomers at step 40, 120 steps), newcomers' understanding rises 5.8 to 6.1 from where it starts, with no
fallback logged. With accession ported, traits mode covers M7's per-entity worlds; the central chooser
stays scalar (a limiting case for tests). Per the author's ruling on 8.112's question 3 (traits mode
becomes default if useful and needed for future updates), the switch is proposed once the full M7 suite
passes in traits mode.
8.119 author direction and build (2026-11-07): mix both: historical cases (E4) strengthen the system
against edge cases, current ones (E5) test it as it stands; and every E5 suggestion is read across a
coarse-to-fine battery of Benefuture rule sets, since otherwise one could say it only wins in this
configuration. Built (`replay_rule_battery`, battery-only overrides never used for scoring): 13 rule sets:
weak floors alone; + strong per-group reading; + compensated reforms; + long-term offset; + environmental
block (full); and the full set with each judged threshold at a low and a high value (happiness retention
0.1, 0.6; understanding compounding 1.0, 2.0; compensation efficiency 0.5, 1.0; soft bar 0.02, 0.1).
Readings: WHO PABS annex: binding annex in 13 of 13; FOMC January 2027: cut in 12 of 13 (hold only under
the strong reading without compensation); lead phase-down 1973: phase-down in 11 of 13 (status quo under
the strong reading without, or with only, compensation); Montreal: phase-down in 13 of 13. A suggestion
therefore carries two robustness readings: across judged magnitudes (`replay_sensitivity`) and across
rule sets (`replay_rule_battery`).
8.120 (2026-11-07, author ruling on 8.112 question 3: switch if useful and needed): M7's per-entity worlds
default to traits mode (`BF_M7_TRAITS=0` restores the scalar mode; the central chooser stays scalar).
Before switching, the M7 suite ran in traits mode: everything held but two results. (1) Heavy research no
longer lowers the floor (0.8 of time: 22.8 against 22.6 at 0.1): breakthroughs are taught whole, so
research also feeds the floor; the test now claims only that it costs no more than a small margin, and the
scalar finding stands as the scalar mode's. (2) Newcomers under existing-only floors gain 0.502 against a
limit of 0.5, while the test's relative claim (uplift raises them over five times more) holds; the limit
moves to 0.6 with the reason stated.
8.121 ruling (author, 2026-11-07): credence voting in Benefuture's liquid democracy. Ballots carry
credences (confidence per option), and the credences have value beyond tie-breaks: they weigh in the
aggregate (a more confident, better-calibrated judgment moves the outcome more); no separate ranking is
needed, the order follows from the credences, and a voter may not state equal confidence on top options. Diversity and novelty bonuses always boost
clusters that choose minority options, which keeps minority judgments alive and scored (no exploration
rate needed). Design consequences carried from the discussion: influence is weighted by measured
calibration, never by stated confidence alone (Nitzan and Paroush 1982: optimal weights are the log-odds
of measured competence); stated credences are shrunk toward each voter's calibration record; credences
are scored by a proper rule against outcomes, unchosen options against counterfactual estimates;
correlated ballots (credences clustered far tighter than independent judges give) count once (8.111);
a "surprisingly popular" check (Prelec, Seung and McCoy 2017) is a candidate minority-expertise
detector. Probe planned in M5, red first: stated-credence weighting captured by overconfident voters;
calibration-shrunk credence with the minority bonus resists it and beats current voting in hard worlds.
Candidate homes: Government (voting), Diversity (minority bonus), L114.
8.121 built (2026-11-07): credence ballots in M5 (`ballot`: :vote, :credence_stated, :credence_calibrated;
`overconfidence` per voter). A voter states its log-odds that the option is right (2 × reading / σ² for its
own noise, times its overconfidence); calibrated ballots shrink them by the voter's record (outcome sign
regressed on stated log-odds over apparent outcomes; 0.5 before five records). Readings, 6 seeds, last
400 of 800 decisions: easy world (signal noise 6): all arms about 0.97, credences add nothing at the
ceiling. Harder world (noise 12, ability scatter 1.5, 40% of outcomes apparent): stated credences 0.983
against votes 0.977 (+0.6 points, z ≈ 2); a fifth of voters overstating their log-odds sixfold cost 0.1
points, recovered by calibration. With a colluding bloc (30% of each domain's top experts voting their side
at maximal stated confidence where outcomes stay hidden): votes 0.752; stated credences 0.674, captured;
calibrated credences 0.964. Calibration is what makes credences safe: weighted as stated they hand a
confident bloc the vote, shrunk to the record they expose it. Not yet built: the minority-cluster
diversity-novelty bonus, correlated-ballot detection, delegation of credence, surprisingly-popular check.
8.121 backpropagated (2026-11-07, author): pseudocode line added after LqdBfDm in all three copies,
`LqCfdBfDm(D_n) := LqdBfDm | Vote_i := Confidence«Cf»_i(Options), ¬Tie(top Cf_i); D_n ≈ Σ VW_i·PrAcc_i(Cf)·logit(Cf_i); Di, N(minority clusters) → VW↑;`
(PrAcc of the voter's confidence record is the calibration that shrinks stated confidence; Cr is taken by
Crime, so Confidence«Cf»); Government article: a "Confidence-weighted" aspect beside "Liquid where needed".
Lean: `cfd_ballot_weight_ref` (weight × calibration slope in [0, 2] × capped stated log-odds), exported and
called by M5's tally, so the rule lives once.
8.122 finding (2026-11-07, on 8.121): the minority bonus is native and is what makes calibrated credence
work. M5's diversity-novelty subsidy (L158: locales trying the option not chosen are paid `novelty_bonus`)
already boosts clusters choosing minority options, and its split trials make otherwise hidden outcomes
apparent. Against a stealth bloc (defecting only where outcomes stay hidden), 6 seeds: calibrated credences
0.959 with the trials, 0.673 without (captured, like stated credences); plain votes 0.752 and 0.739. The
bloc's confident wrong calls reach its members' records only through the minority trials. So the author's
pairing in 8.121 is load-bearing: calibration needs outcomes, and the minority bonus produces them where a
bloc would hide.
8.122 continued: delegated credence is native. A delegate casts `cfd_ballot_weight` with the whole weight it
holds (its delegators' included) times its own calibration and stated log-odds, so delegators inherit the
delegate's calibrated confidence and the delegation caps still bound concentration; nothing added.
Correlated-ballot detection (credences clustered far tighter than independent judges give, counted once as
in 8.111) remains to build; calibration plus the minority trials already defeat the colluding bloc tested.
8.123 defect found and fixed (2026-11-07, on the IMO E5 case): the environmental-health block (8.118)
was applied only inside the strong per-group reading, so when every option failed the strong reading (as in
global cases, where deaths are tiny per person and small costs fall on some groups), the weak fallback
chose the option with the most environmental health harm. The block now holds in the weak reading too.
Historical choices unchanged (replay tests pass); the IMO case moves from adjourn (first run, kept) to
adopt with pricing (9 of 13 rule sets). Also exposed, left open for the author: in global cases, large
absolute death tolls are small per person, so the freedom gate's per-being risk bar (0.1%) never binds and
the floors barely move; only the environmental block catches them. Whether irreparable harm should also be
read in absolute terms (a count bar beside the per-being bar) is a question for the author.
8.124 ruling (author, 2026-11-07, on 8.123's open question): irreparable harm is irreparable harm, its
severity massive for death, but an infinitesimal per-person chance is just that: freedom cannot stop a
person crossing the road for the chance of being run over, but it can block a policy that raises that
chance by a tiny amount for a whole population, unless the same policy increases survival by a massive
amount elsewhere; at that scale it is a long-termist trolley problem. Read: individual risk-taking stays
under the per-being freedom gate; a policy is judged by its aggregate expected irreparable harm, net of the
survival it adds elsewhere, so among a decision's options one whose net expected irreparable harm exceeds
the least-harm option's is blocked unless the excess is necessary harm. Generalises 8.118 (environmental
pathways) to every pathway. Candidate homes: Freedom (harm boundary; individual vs policy), L135, L74.
8.124 built (2026-11-07): Lean `irreparable_blocked_ref`: among a decision's options, one whose aggregate
expected irreparable harm exceeds the least by more than `irr_tol` (1% of the least, at least 0.01;
governed) is blocked in both readings; the per-being freedom gate stays for individual risk. Two defects
found and fixed on the way, both against the rulings' letter: (1) a necessary-harm exemption had been written
into the environmental and irreparable blocks; neither 8.118 nor 8.124 grants one (8.124's only exception,
survival added elsewhere, is in the net comparison), so it is removed; (2) when no option passed the floors
the replay fell back to inaction even when inaction was blocked; it now chooses the best-valued unblocked
option, loudly (a blocked inaction is informed allowing, 8.47). Fourth replay (not out of sample): all
choices unchanged except school closures 2020, now close schools (compensated), where keeping schools open
carried 108 expected deaths against none; its falsifier F1 no longer fires. Pre-registered 6/6 and held-out
5/5 unchanged. E5 credences: WHO binding annex 57% (was 44%), IMO adopt 79%, FDA wait 95%, FOMC hold 58%.
The rule battery gains a fourteenth set (the full rules without this block).
8.125 author direction and build (2026-11-07, on 8.124): at some level of counterfactual understanding
loss, closing schools must be able to rule either way; it depends on how long and what options exist
(online classes can shrink the loss). Built: lost knowledge counts as irreparable harm (as REPLAY_PREREG §5
defines it) in death-equivalents: Lean `irreparable_equivalent_ref` adds to expected deaths the persistent
share of long-term understanding loss (loss × compounding × persistence), as the share of a life's
understanding and happiness it takes (a death takes both to zero), over the group's population; 8.124's
block compares these totals. Persistence is a governed default (`u_loss_persistence` 0.5) that an option
may override from evidence on its kind of loss; each case declares its unit ratio
(`irreparable_per_population_unit`). School closures 2020 gains two as-of options (a three-week closure;
closure with remote instruction keeping a quarter of teaching, from the record of full-time online schools),
added after the fourth replay at the author's direction. Fifth replay (not out of sample): school closures
returns to keep open (half of 2.4 points of students' understanding loss outweighs about 108 thousand
expected deaths); with remote learning keeping 90% of instruction it chooses closure with remote learning,
so the rule rules either way with the options. Volcker 1979 moves to incomes policy (its recession's
understanding loss now counts as persistent, while incomes policy's cost is happiness), a miss on a good
decision (held-out 4 of 5 on this replay). That exposes the uniform persistence: a child's lost schooling
and an adult's unemployment spell are not equally lasting; Benefuture would estimate persistence per kind of
loss from evidence, so per-option values are the fix, set from as-of evidence when each case is next
sourced (not now, which would be tuning after seeing the flip).
8.126 ruling (author, 2026-11-08, on 8.125): the irreparability of understanding loss is not that of
health. Only generational losses are irreparable: understanding someone would never gain again, or gain
late enough to substantially reduce later synergistic breakthroughs; irreparable understanding loss is
more like declining a risky exploration that might otherwise never be taken. A generic loss over a couple
of months that can be regained is not irreparable, and weighing it against a per-person death risk under
0.005 is a nuanced decision that can flip on many threshold assumptions. Built: `u_loss_persistence` now
means the generational share of a loss (default 0.1, governed; an option may state its own from evidence,
such as dropout); recoverable loss stays a reparable harm for the floors and value; the rule battery gains
two sets (generational share 0.02 and 0.3; 16 in all) and the credences jitter magnitudes across them.
Sixth replay (not out of sample): school closures 2020 is a close call, as it should be: closure with remote
learning in 9 of 16 rule sets and keep open in 7; credence keep open 44%, close with remote learning 37%,
three-week closure 18%; Volcker back to reserve targeting (held-out 5 of 5). Candidate homes: Understanding
(irreparability), Harm (irreparable kinds), Freedom.

8.127 [R] (2026-11-08, E4 round 2 DDT case; ruled by the author the same day: "8.127 fix, trolley rules, and fail
loud, yes": the fix stands, the all-blocked choice follows the trolley rulings on net expected harm (8.124), and
it is logged loudly): the environmental block (8.118) and the irreparable block (8.124)
each measure against their own least option, so together they can exclude every option. The replay then chose
inaction by default, even where inaction was blocked under both. Proposal: when every option is blocked, choose
the option whose blocked harms exceed their leasts least, each excess relative to its least (scale at least 1),
summed; ties go to value. Grounds: inaction has no default privilege (8.47), and 8.124's fallback already picks
among the least-blocked. Candidate homes: the pseudocode's G fallback line; the Governance article. Open for
the author: whether the two excesses should be weighed alike, or the irreparable one first (lexicographic).

8.128 (2026-11-08, method; follows CLAUDE.md, significance testing): replay credences are drawn by precision,
not habit. Jitter draws are added in batches of 20 until every option's share has a Student-t-inflated
standard error of at most 0.02 (each draw a cluster of the rule battery's choices; at most 640 draws). Found
on the FOMC E5 case, whose cut share moved 13 points between seeds at 40 draws. First results stay recorded;
restated credences sit beside them (docs/E4_ROUND2.md, docs/E5_RUNS.md).

8.127 built per the ruling (2026-11-08, Sri Lanka 2021 case): the first build weighed only the blocks'
excesses, which left out harms neither block sees (the ban's yield collapse) and chose the ban. Read as the
trolley ruling (8.124, net expected harm): when every option is blocked, the least net expected harm over all
scenarios wins, in one unit (u and h losses in person-points plus deaths at baseline u + h), ties to value,
loudly. Interpretation of "trolley rules" recorded for the author to confirm.

8.127 confirmed (author, 2026-11-08): "if all available options are harmful, a) if possible look for lateral
options, else choose least harm; the goal equation would say the same anyway." The trolley reading stands:
least net expected harm when every option is blocked. Added requirement: an all-blocked decision first searches
for lateral options (options outside the set offered). In the replay the case set is fixed, so the trace now
says so loudly ("look for lateral options first") and such cases are flagged for a lateral-option pass by the
case builder, as-of sources only; in the simulation, entities facing an all-blocked choice should propose new
options (the M3c `adaptive_proposals` route) before falling back. Candidate homes: the pseudocode's G fallback
line; the Governance article (decisions).

8.129 ruling (author, 2026-11-08): priority tiers come ahead of further replay work, "without it we will continue
to see weird tradeoffs in sims. Any value can be split across priorities and then run through synergy.
Teachable peak meta understanding with paradigm shifting novelty will massively outclass peak non-transferable
understanding which provides peak happiness to a lot of people in a given field, and trivial novelty wouldn't
even budge the needle." Built: Lean `tiered_ref` and `tiered_value_ref` (BenefutureReference/Functions.lean;
export `bf_tiered_value`; Julia `tiered_value`): understanding, happiness and novelty each split over six tiers
(L57–L60) with the canonical schedule 0.8, 0.6, 0.4, 0.25, 0.15, 0.05 (novelty's trivial tier 0), each
synthesised by synergy, then V as before. Probe (red first): per being, with the same peak understanding,
teachable + meta + paradigm novelty scores 4.58 against 1.17 for non-transferable peak with raw happiness and
trivial novelty, while the scalar value ranked the latter first (8.78 against 5.15); ten units of trivial
novelty move the value by under 1%. Finding: with the non-transferable peak four times larger, the tiers alone
favour the teachable side only narrowly (4.58 to 4.49); teaching's multiplier comes from understanding spreading
to other beings, which the world models must carry (M7's teachable/tacit split already does). Next: world
models emit tier-typed changes (M7 first, then the replay's case schema), each behind its probe.

8.129 clarified (author, 2026-11-08): "Each priority tier's coefficients are governed params as usual, and can have
domain specific governance." Built: Lean `tiered_value_sched_ref` (export `bf_tiered_value_sched`) takes the three
schedules; `tier_schedules()` reads the defaults from the reference; `tiered_value(...; su, sh, sn)` takes a
domain's governed schedules (six weights in [0, 1), in priority order). Probe: a domain ranking teachability with
peak values a teachable gain above the default. Domain schedules ride the existing per-domain governance
(thresholds governed like any other); which domains govern their own is a world parameter until governance sets it.

8.129 tier positions (author, 2026-11-08): "when we say peak median floor for U it's the position of the U in the
global curve as U is comparable, while H has trouble being compared so it's global when comparable and personal
when not." Applied: understanding's peak, median and floor tiers are positions on the global curve (a gain is
peak only where it carries a being past the best; floor only where the lowest rises); happiness's positional
tiers (baseline, median) are global where happiness is comparable and personal where not, while its kind tiers
(eudaimonic, shareable, satisficing, sensory peak) are read for each being. Candidate homes: L57–L59 (a note on
positional tiers), the Understanding and Happiness articles.

8.129 probe (2026-11-08): `run_programmes` (sim/src/programmes.jl), the smallest world where tiers decide
something: each step a chooser picks research, teaching, entertainment or practice by expected value, effects
typed by tier. Over 6 paired seeds, 100 steps, 20 beings: valued by scalar sums the chooser entertains every
step and median understanding stays at about 1.5; valued through the tiers it teaches and researches (seed 1:
76 and 24 steps), median understanding reaches 8 to 12 (z ≫ 3 against a smallest effect of 1.0), the
understanding floor rises with it, and the happiness floor never falls. Open, for the author: under the default
schedules the tiered chooser never entertains at all; raw happiness is the lowest happiness tier, but a world
with no satisficing or shareable happiness is itself a weird tradeoff, which the happiness kinds (satisficing,
shareable) in world models should correct rather than the schedule.

8.129 author note (2026-11-08): "the priorities are strange because they encode a lot of other metrics and
choices, we'll get to learn more when we sim them all together." Default schedules stay; happiness kinds go into
the world models rather than reweighting the schedule.

8.129 in M7, positions only (2026-11-08): `run_m7(...; tiers = true)` values each plan with each being's changes
typed by global position (`tiered_plan_value`, sim/src/m0.jl; `choose(...; tiers)`). Hypothesis stated before
measuring: higher understanding peak with no floor falling. Over 6 paired seeds (n 40, 120 steps): no
understanding effect (floor +0.14 ± 0.46, median +0.14 ± 0.47, peak −0.02 ± 0.45; equivalence not shown), and the
happiness floor falls 0.27 ± 0.09 (z > 2.6). Reading: M7's plans carry no kinds, so every effect lands in the low
positional tiers (understanding median or floor, happiness baseline or median), and happiness loses weight
against understanding relative to the scalar reading. Tiers need kind-typed effects (teaching as teachable,
research as peak or paradigm, happiness as satisficing or shareable) before they help in M7. Tiers stay off by
default there (`tiers = false`). Next: kinds on M7's plans.

8.129 kinds across beings and contexts (author, 2026-11-08): "in reality particularly for happiness the same
outcome may rate differently for different beings, while for U a model has the same priority spread for anyone,
but the impact profiles can vary by context, the same aerodynamics drag which rates much lower than seatbelt in a
car can rate higher than seatbelts in an aircraft." Design consequences for the kinds work:
(1) Happiness: an outcome's split across happiness tiers is per being (a personal profile mapping the outcome to
eudaimonic, shareable, satisficing, ... for that being), drawn as a world property with its own noise, read
through outputs only (stated and revealed responses), never assumed uniform.
(2) Understanding: a model's tier spread (peak, teachable, meta, ...) is a property of the model, the same for
every being who holds it.
(3) Impact by context: what a piece of understanding is worth depends on the context it is applied in (drag below
seatbelts in a car, above them in an aircraft). This is the priority-per-thing weighting of 8.117 made
context-dependent: the weight of a thing is its predicted long-term contribution in the context of use, set by
that context's (domain's) governance, consistent with per-domain tier schedules (8.129 clarified).
Candidate homes: L57–L59 and the Understanding (aggregation) and Happiness articles.
