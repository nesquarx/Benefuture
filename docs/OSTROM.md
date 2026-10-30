# Audit against Ostrom's design principles

Benefuture (articles in `docs/articles/`, pseudocode `spec/Bf_Pseudocode.txt`, simulation `sim/`)
read against the eight design principles for long-enduring commons institutions (Ostrom 1990,
*Governing the Commons*, https://doi.org/10.1017/CBO9780511807763), in the refined form of Cox,
Arnold & Villamayor Tomás (2010), "A review of design principles for community-based natural
resource management", *Ecology and Society* 15(4) 38, https://doi.org/10.5751/es-03704-150438, who
found the principles well supported across 91 studies and split three of them (1a/1b, 2a/2b, 4a/4b).
Two further works frame the audit: Baggio et al. (2016), https://doi.org/10.18352/ijc.634, found
that no principle suffices alone and success depends on combinations; Ostrom (2007), "A diagnostic
approach for going beyond panaceas", *PNAS*, https://doi.org/10.1073/pnas.0702288104, warns against
any single institutional blueprint applied everywhere, which is a coherence critique Benefuture must
answer by its adaptivity (SigThGv, competing models, diversity) rather than by its design alone.
Wilson, Ostrom & Cox (2013), https://doi.org/10.1016/j.jebo.2012.12.010, generalise the principles
from resource commons to groups of any kind, which is the reading used here: Benefuture's commons
are understanding, happiness, resources, the open log and the decision process itself.

Line numbers (Lnn) are lines of `spec/Bf_Pseudocode.txt`. The articles already claim alignment with
the principles (Implementation prototype, introduction; Anti-Corruption, Discussion); this audit
checks the claim principle by principle. Proposals go to `docs/BACKPROPAGATION.md` as
**8.53-Data-a** to **8.53-Data-h** (to renumber at merge), all [P].

## Summary

| Principle (Cox et al. 2010) | Benefuture | Gap | Proposal |
|---|---|---|---|
| 1a User boundaries | Strong: identity binding, ontology of who counts and votes | Fork and Sybil handling partly simulated | – |
| 1b Resource boundaries | Partial: domains bound claims; resource accounting tracks use | One resource stock and one commons in the simulation; domains are fuzzy by design | 8.53-Data-h |
| 2a Congruence with local conditions | Strong in design: competing models, SigThGv, fractal scope, local trials | Thresholds are global by default | 8.53-Data-f |
| 2b Benefits proportional to costs | Strong for appropriation: causal distribution, resource pricing | Provision of a resource earns only through distant outcomes | 8.53-Data-b |
| 3 Collective-choice arrangements | Strong: impact-weighted democracy, laws as agreements | Expertise weight can outvote those affected | 8.53-Data-a |
| 4a Monitoring users | Strong: open immutable log, AdvAp by users, monitors scrutinised | Cost of false accusations on participation unmodelled | (test) |
| 4b Monitoring the resource | Partial: metric models, markers, resource accounting, Harm_Intv | Resource state monitored only through cost | 8.53-Data-h |
| 5 Graduated sanctions | Mixed: proportional to harm and contribution, escalation by pattern only through side levers | Strict liability for first harms; escalation not in the pseudocode; deterrence implicit | 8.53-Data-c, 8.53-Data-d |
| 6 Conflict resolution | Present: dispute resolution in causal distribution and Justice | Cost and speed unspecified; not simulated | 8.53-Data-e |
| 7 Recognised rights to organise | Present: fractal scope, diversity, phased rollout beside legacy institutions | When a sub-scope's own rules need no higher approval is unstated | 8.53-Data-f |
| 8 Nested enterprises | Strong in design: nested domains, fractal governance, holographic progressive strategies | Which scope decides is unstated; governance in the simulation is flat | 8.53-Data-g |

---

## 1a. Clearly defined user boundaries

*Ostrom:* who may use the resource is clearly defined.

**How Benefuture meets it.** Users are identified beings: the Technology Network binds identities
across clusters (L132 `Agg(LogIdMl[](E, 1:(0,1)) | ≥2 Cluster) ≥Th ⇒ BindId(E, 1:1)`; Technology
Network, Aspects, "Identity binding"); the ontology defines who counts (beings, L73–L74) and who votes
and contracts (persons, L71; Base_VW in L113); forks and merges split and join social power (L122–L123;
ruling 8.34: forks divide the base vote). Participation tiers (L140 `DataCollection{OptOut, Basic,
Active, Deep}`, `InformedConsent`) define degrees of membership.

**Gaps.** Benefuture's users are every being, not a bounded community; the principle's purpose
(excluding free riders from a rival resource) is met instead by pricing every use (L83, L86): use is
open but never free. Identity binding is not simulated (`sim/README.md`, Noise: "identity binding
(M6)"); forks are (`fork_rule`, M5). Sybil attempts are on the M6 list.

## 1b. Clearly defined resource boundaries

*Ostrom:* the boundaries of the resource system are clear.

**How Benefuture meets it.** Domains are "bounded classification patterns of reality" that give
"jurisdictional scope" (Domain, introduction; Domain, Discussion, "Bounded accountability"), and
resource use is accounted per transaction (L83 `RcAccounting ... ↓Usage{Rc, t}`), priced per
currency (L86).

**Gaps.** Domains are deliberately fuzzy (L22 `Nested(fuzzy)`, relations learnt from memory, never
declared), which suits measurement but not the crisp boundaries Ostrom found useful for a rival
resource. The simulation has one resource stock (`capacity`, `regen`) and one commons for the whole
economy (`sim/src/m3c.jl`; `docs/ODD.md` §6.2), so local depletion and local regeneration cannot
occur. How the commons balances resources against gains is open (8.26.7).

**Proposal.** 8.53-Data-h: resource stocks and the commons accounted per resource system (a domain
at whatever granularity the resource's causal structure has), so use, regeneration and insurance
are bounded where the resource is.

## 2a. Congruence with local conditions

*Ostrom:* rules fit local social and environmental conditions.

**How Benefuture meets it.** Competing metric models specialise by domain and context (L82; Domain,
Aspects, "Measurement"); embedded laws adapt dynamically (L138 `EmbeddedLaws(C, MM) | DynamicAp`);
thresholds are perturbed within the freedom range and debated where debatable (L157 SigThGv);
governance operates at every scale (L113 `FractalScope`; Government, Aspects, "Fractal Scope"); the
diversity axiom keeps alternatives alive locally (L158); progressive strategies degrade and enhance
by context (L154). In the simulation the debatable escape tries a proposal on a share of the
domains before adopting it everywhere (`escape_accept_ref`, M4), and split trials run per locale
(M5).

**Gaps.** Governed thresholds are single global values in the simulation (`sim/README.md`, Governed
thresholds); only the escape's trial is local, and an adopted proposal applies everywhere. The corpus
does not say whether a threshold may settle at different values in different scopes.

**Proposal.** 8.53-Data-f (with principle 7): governed thresholds carry a scope, and a scope may hold
its own value within the freedom range.

## 2b. Congruence between appropriation and provision; benefits proportional to costs

*Ostrom (Cox et al. 2b):* what each user takes is proportional to what they contribute.

**How Benefuture meets it.** Rewards and penalties are proportional to causal contribution (L94–L96
`CD ∝ CC + N_CCtype − PE_paid`), and every action pays its resource cost less the good it is predicted
to do (L86); supply follows measured good less resources and harm (L97, L99; Benefuture currency,
"Currency supply is endogenous"); overflow reinvests accumulation beyond need (L103); a baseline
income keeps basic needs priced at or below zero (L143 S_BaselnIncm). The simulation demonstrates
proportional sharing (Shapley shares with intermediaries earning nearly nothing, M3d) and the
overflow trade-off between reinvestment and spread of wealth (M5 readings).

**Gaps.** Appropriation is priced directly (resource cost per action), but provision (regenerating,
maintaining or restoring a resource) earns only through the understanding and happiness outcomes it
eventually causes, which may be far downstream and below the causal-assessment gate, so it falls to
the traversal fallback. Restoring a resource is thus paid less reliably than depleting it is
charged. In the simulation, regeneration is exogenous: no agent provides.

**Proposal.** 8.53-Data-b: resource accounting reads provision as negative usage, so restoring a
resource earns what depleting it would cost.

## 3. Collective-choice arrangements

*Ostrom:* most individuals affected by the rules can participate in modifying them.

**How Benefuture meets it.** Laws are agreements (L104 `Law := Agreed(I)`); decisions are expertise-
and impact-weighted direct democracy (L113), with those impacted weighted by predicted impact and
those above a weight obliged to vote (Government, Aspects; ruling 8.46: voting above a threshold is a
duty); delegation is temporary, audited and retractable (L114); debatable thresholds go to the vote
(L157). The simulation runs L113 and L114 through the Lean reference (`voting_weight_ref`,
`accumulate_capped_ref`, M5).

**Gaps.** Expertise weight (default 5) exceeds impact weight (default 1) in the simulation, and the
expertise term is domain-relative but not local: experts far from a decision's effects can outvote
those who bear them. Ostrom's principle is about the affected modifying the rules; the corpus states
the weighting but no guarantee that the impacted, together, hold a meaningful share.

**Proposal.** 8.53-Data-a: a governed floor on the share of decision weight held by the impacted, and
the share reported as a decision's output.

## 4a. Monitoring of users

*Ostrom:* monitors who audit behaviour are accountable to the users or are the users.

**How Benefuture meets it.** Every executed action and outcome is logged immutably (L145 Mem, the
behavioural transaction substrate); voting records and assessments are public (Government,
"Transparency and Accountability"); users themselves monitor and are paid to reveal gaming more than
exploiting it would gain (L160 AdvAp; Adversarial adaptation); the monitors (justice, enforcement,
administration) are under the same anti-corruption scrutiny (Justice, Enforcement and Administration,
Discussion; L159). The simulation runs AdvAp with users as readers of the open log (`vigilance`,
attention following ledger patterns and stakes; M6), audits by significance and cause, and repair of
falsified records.

**Gaps.** False accusations are tolerated in good faith and charged only past a pattern
(`report_penalty_ref`), which matches Ostrom's monitors-as-users; but the cost of wrongful
convictions (`p_false_trace`) on participation is not modelled, since agents never leave. Wikipedia's
experience (Halfaker et al. 2013, https://doi.org/10.1177/0002764212469365) is that strict automated
monitoring drove good-faith newcomers away. A test, not a proposal: agents exiting in response to
wrongful penalties (`docs/DATA.md` §9).

## 4b. Monitoring of the resource

*Ostrom:* the condition of the resource is monitored.

**How Benefuture meets it.** Metric models and markers monitor understanding and happiness, the
ultimate resources (L82, L145–L146); resource accounting tracks usage (L83); the antifragility axioms
require intervention when harm rises and innovation when resource cost rises (L150 Harm_Intv, L151
Rc_Innovation).

**Gaps.** Physical resource stocks are monitored only through the costs actions pay; the stock's
condition (and its regeneration) is not a measured output of its own. In the simulation the stock is
known exactly to the rules and noisy only in accounting (`cost_σ`, `regen_σ`).

**Proposal.** Covered by 8.53-Data-h (resource systems as accounted units, with their condition
measured like any output).

## 5. Graduated sanctions

*Ostrom:* sanctions start low and rise with the seriousness and repetition of violations. Her
reasons: most violations come from temptation or bad luck rather than settled intent; a small first
sanction tells the violator and others that monitoring works without alienating them; quasi-voluntary
compliance survives only if sanctions are seen as fair; escalation reserves severe sanctions for
those who persist.

**Benefuture's stance: reparation first.** Justice is repair of harm and prevention of crime,
restorative (L116 `J := Repair(Ha) ∧ Prevent(Cr), Restorative`; Justice, citing Zehr 1990). Negative
outcomes are penalised in proportion to causal contribution (L96), once per harm (L99 `OncePer(Ha)`),
the cost of reparation borne by those who caused it and supported by the administration where they
fall short (Justice, Reparation). Crime requires informed volition or informed inaction under a
mandate or contract (L115); accidents are not crimes.

**Where Benefuture already graduates.**
- *By intent*: crime against accident by notice (L115; `is_crime_ref`); justice's rehabilitation and
  restraint apply to crimes only.
- *By repetition*: Justice's rehabilitation escalates from contributing to reparation, to education,
  to restraint "if the education fails, and the harm is significant or repeated" (Justice,
  Rehabilitation); enforcement applies persuasion before force (Enforcement, Aspects; L120
  `Proportional, DueProcess`).
- *Through side levers that read history*: escrow requirements ratchet with an actor's record of
  overestimation (Benefuture currency, "Probabilistic Escrow"; Lean `ratchet_credence_ref`);
  reputation ledgers keep every entry and mistakes decay slower than wins (L101; ruling 8.29), so a
  pattern weighs more than an incident; frivolous reports are charged only past a pattern
  (`frivolous_threshold`); delegations are withdrawn from delegates whose records fall below the
  audit threshold (L114).
- *Against outsiders*: the external harm response is tit-for-tat with forgiveness weighted by the
  aggressor's positive reputation and overreaction weighted by its negative reputation (L117 EHR),
  closer to Ostrom's graduated logic than anything internal.

**Where it does not.**
- *Strict liability for the first harm.* Causal distribution penalises a negative contribution at its
  assessed value whatever the intent or history (L96, L99): an honest first accident costs its full
  repair. In the simulation, accidents and crimes are penalised alike to fund repair (M3e), and
  because V is loss-averse (q₋ > q₊) the assessed value of harm far exceeds the gains it displaces:
  laundering at full tracing left the launderer 1,046% below honest agents (`sim/README.md`,
  Laundering). Benefuture's sanctions are therefore steep, not graduated, for first offenders who
  cause large harm.
- *Escalation lives outside the pseudocode.* L116 says repair and prevent; the escalation by
  repetition is only in the Justice article, and the side levers that read history do so for other
  reasons (pricing, model estimates, delegation). The simulation models no rehabilitation or
  restraint.
- *Deterrence is implicit.* Reparation-only sanctions equal to the harm deter only if the chance of
  being traced times the penalty exceeds the gain. Benefuture gets deterrence from two places it does
  not name as such: V's convexity (the penalty is the assessed harm, which loss aversion inflates
  beyond its resource saving) and AdvAp raising the chance of detection. The laundering readings show
  the break-even near a tracing rate of 0.1; below it, laundering pays (+2% at zero tracing).
- *The articles overstate the alignment.* Implementation prototype lists "graduated sanctions
  (reputation penalties, escrow mechanisms)": escrow ratcheting is graduated, reputation penalties
  are proportional.

**Assessment.** Reparation-first is compatible with Ostrom's principle: her sanctions are also
mostly restitutive in small communities, and the principle is about the *profile* over seriousness
and repetition, not about punishment versus repair. Benefuture already graduates by intent and,
through rehabilitation and side levers, by repetition. What it lacks is (i) a statement that the
severity of what a first, non-informed harm costs its contributor is bounded by capacity, with the
administration carrying the rest (the Justice article says this; L96 and L119 do not), and (ii)
escalation by pattern stated where the rules live. Both can ride on existing mechanisms; neither
needs a new one.

**Proposals.** 8.53-Data-c (escalation by pattern through rehabilitation, stated in L116, and
first non-informed harms capped at capacity with the administration's support); 8.53-Data-d (name the
sources of deterrence and test them).

## 6. Conflict-resolution mechanisms

*Ostrom:* rapid, low-cost, local arenas resolve conflicts among users and with officials.

**How Benefuture meets it.** Causal distribution is subject to dispute resolution through justice
(L96 `| DisputeResolution(J)`; L99 `J(Ha) iff Disputed`); affected parties can contest assessments
(Benefuture currency, "Disputes", "Completed": accept, partially accept, or dispute); justice decisions
can use the weighted democracy with trained sophonts and affected parties weighted (Government,
Examples, "Dispute Resolution"); Life in benefuture walks through disputing a causal attribution.

**Gaps.** Nothing states the cost or speed of a dispute, and an expensive process is no arena for
small conflicts. The simulation has no disputes: assessments are final except by AdvAp's audit
(`p_false_trace` is the only proxy for wrongful outcomes). Medical malpractice data (Studdert et al.
2006, https://doi.org/10.1056/NEJMsa054479; `docs/DATA.md` §9) show what dispute systems get wrong.

**Proposal.** 8.53-Data-e: a dispute is a transaction priced like any other, its re-assessment done by
a different model of the pool (or a weighted panel above a significance), frivolous disputes charged
past a pattern as AdvAp reports are.

## 7. Minimal recognition of rights to organise

*Ostrom:* external authorities do not challenge users' rights to devise their own institutions.

**How Benefuture meets it.** Governance is fractal, from a family to a civilisation (L113
`FractalScope`); "It is *not* a ruling body, but a facilitator of societal self-governance"
(Government, introduction); diversity keeps minority alternatives alive (L158; split trials in M5);
freedom is maximised within the harm boundary (L135); rollout is phased beside legacy institutions
with informed consent (L140; Implementation prototype, Scenario, starting with a receptive regional
government). Toward outsiders, EHR (L117) is context-aware and transparent.

**Gaps.** The corpus does not say when a scope's own rules need no approval from a wider scope. Read
literally, every rule at every scale is subject to the same Goal and the same governed thresholds,
which leaves a sub-community's self-organisation at the wider scope's discretion. The freedom article
gives the natural boundary: outputs beyond the freedom harm boundary are excluded; others are free.

**Proposal.** 8.53-Data-f: a scope's own rules and threshold values within the freedom range (L135)
and the admissible region need no wider approval; a wider scope intervenes only beyond the freedom
harm boundary or where effects fall on beings outside the scope.

## 8. Nested enterprises

*Ostrom:* appropriation, provision, monitoring, enforcement, conflict resolution and governance are
organised in multiple nested layers.

**How Benefuture meets it.** Domains nest from broad to fine, fuzzily (L22; Domain, "Nested
Structure"); currencies price at leaves and fall back to parents (simulated, M3c); governance is
fractal (L113); progressive strategies are holographic and fractal (L156 `↑(Resilience,
Po_So)(Holographic, Fractal)`); the Technology Network is decentralised clusters with a shared core
(L132). Ostrom's own later work calls this polycentric governance (Ostrom 2010, "Beyond markets and
states", *AER*, https://doi.org/10.1257/aer.100.3.641).

**Gaps.** Which scope decides a given question, and how conflicting decisions of nested scopes are
reconciled, is unstated. In the simulation governance is flat (decisions in leaf domains, M5); only
measurement and pricing nest (M3c).

**Proposal.** 8.53-Data-g: subsidiarity by impact: a decision is taken at the narrowest scope whose
members bear nearly all of its predicted impact (L113 `Pr_Imp`), with the spill-over share a governed
threshold; the same test settles conflicts between scopes. For the simulation, nested decision scopes
belong to M8 (`docs/PLAN.md`).

---

## Simulation follow-ups (not proposals)

- Agents exiting in response to wrongful penalties and harsh first sanctions (principles 4a, 5): the
  simulation cannot see a chilling effect while agents never leave.
- A detection sweep for deterrence without V's convexity (principle 5; 8.53-Data-d).
- Local threshold values and nested decision scopes (principles 2a, 7, 8) with M8.
- Resource systems per domain with provision by agents (principles 1b, 2b, 4b) once 8.26.7 is ruled.
- Pitt, Schaumeier & Artikis (2012), https://doi.org/10.1145/2382570.2382575, axiomatise the
  principles for self-organising multi-agent institutions; their formalisation is a candidate template
  for stating the principles over `SimTrace` as conjectures.
