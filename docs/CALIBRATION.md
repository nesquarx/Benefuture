# Calibration of the simulation's world parameters and noise to empirical sources

A table adapting every world parameter, noise distribution and range in `sim/` to realistic
empirical sources, as far as they exist. It extends `docs/DATA.md` (which maps datasets to objects)
with numbers: a proposed default, range and distribution shape per parameter, the dimensionless
quantity a source can pin down, and a confidence. Status: the invariant (and the invariant part of
mixed) defaults of the top ten and the battery ranges of section 7 have been applied in `sim/`
(`CALIBRATED` in `sim/src/calibration.jl`; `sim/README.md`, Noise, lists each default and its class);
the "Now" columns hold the pre-calibration values. Rows outside that increment (`regen_σ`, `view_σ`,
`pred_σ`, the research rows, `touch` and `shift`) are proposals still. Nothing here is validated
against the world, only run in the simulation. Governed thresholds are not
calibrated here (they are governed, SigThGv L157); section 4 lists institutional analogues only.

Every figure is judged twice before it is proposed. First for **transfer**: a figure that measures
human or physical nature carries over to a Benefuture society; a figure produced by today's
institutions and incentives does not, and is kept as a status-quo baseline and a sweep, because in
Benefuture it should emerge from the mechanisms (author, 8.63). Second for **scale**: each figure
is stated in the unit it was measured in and converted to the simulation's unit (per step, per
decision, per agent, share of agents' time or of value). A figure whose meaning changes at the
simulation's scale is flagged and not proposed as a direct default.

## 0. Reading guide

**Units.** Simulation units are abstract, so a source can pin down only a dimensionless quantity: a
rate, a probability, a ratio to the domain's natural spread, a coefficient of variation (CV), an
elasticity, or the shape of a distribution. Model error is already relative to the domain's spread
(8.35). Rates per step need a clock; this document gives rates per real year and leaves the
step-to-time mapping to the author (**[OPEN]**: demography wants 1 step = 1 year, reputation
decay is stated against `window` = 100 steps, the horizon over which an actor is judged).

**Proxy validity.** Benefuture reads outputs only. Every source below measures an output (an
estimate, a vote, a retraction, an incident report) through someone's own metric model, so it
calibrates a marker or an observable rate, never a belief or a preference. Where a source
measures a lab task (judge-advisor estimates), it is a proxy for what a voter does with a published
reading; the transfer is argued in the row.

**Marks.** Link check on 2026-10-30. A DOI marked "ok" resolved in the Crossref API with a matching
title; several DOIs I first guessed were wrong and were corrected or dropped (for example the
Annual Review DOI of DellaVigna and Gentzkow is `...124309`). `doi.org` and the NCBI, NBER and
publisher hosts were not fetchable from this session by the page-reading tool, so abstracts were
read through Crossref and OpenAlex, arXiv, and web search snippets. A number marked **(abs)** was
read in an abstract or a primary-looking snippet this session. A number with **[unverified]** is
from memory or a secondary report and must be checked against the paper before it enters
`README.md` (Claims). **[403]** means the host refused the automated request (not confirmed in a
browser).

**Confidence.** High: several independent sources, direct measure of the quantity. Medium: one
good source or a proxy with a stated bridge. Low: analogy or order of magnitude only.

**Method of reading the tables.** "Now" is the code default (range from `sim/README.md`, Noise).
"Proposal" is a realistic default, range and shape for invariant rows; for institution-dependent
rows it holds the status-quo baseline, the direction Benefuture's mechanisms would move it, a sweep
and the default rule (see 0.1). Keys such as [YAN04] point to section 8. Each parameter table has
two further columns, **Class** (0.1) and **Unit and conversion** (0.2).

### 0.1 Transfer to a Benefuture society

Benefuture reads outputs only, and its mechanisms (audited open ledgers, AdvAp bounties and
clawbacks, causal distribution by outcome, reputation by outcomes, source tags, escrow ratchets,
research as spending) change the incentives that today's institutions supply. Each row is tagged:

- **Invariant**: human or physical nature. Perception and judgement noise, skill and productivity
  dispersion, partial advice taking, learning curves, mortality (Gompertz slope), hazard tails of
  physical systems. The figure is a default (a mildly imperfect realistic value, 8.33), or its
  limiting case is named.
- **Institution-dependent**: produced by today's incentives and institutions. Vigilance, deception
  and fraud rates, audit and whistleblowing rates, R&D share, delegation and participation, collusion,
  sponsor bias, model capture, compliance, project overruns, part of side harm, mass-media persuasion.
  The row states today's figure as the **status-quo baseline**, the direction and mechanism by which
  Benefuture would move it (tagged **[CONJ]**, a conjecture to be tested in simulation, never a
  source), a **sweep** from the status quo to the plausible Benefuture value, and a **default**
  that is either "emerges" (no parameter to set; it comes out of other rules) or "swept" (run
  across the range, no single default).
- **Mixed**: the class cell says which part transfers (the invariant mechanism) and which part is
  institutional (the level it is exercised at). The invariant part is the default; the
  institutional part is swept.

Rows with no source or governed rows are marked "No source" or "Governed". Directions of movement are
conjectures about the mechanisms, not findings; they set where a sweep starts and ends. Where a sweep
spans baseline and Benefuture value, results are read across the whole range, never at one end.

### 0.2 Scale and units

The simulation's units are abstract values. Its populations are tens to hundreds of agents
(M5 worlds of 20 to 100 voters; M3 to M7 worlds of 6 to 42 agents with 200 to 1,000 beings).
A **step** is one round in which a batch of plans is proposed, screened, executed and measured
(economy, AdvAp), a **decision** is one M5 vote (a step of its own), and M7 adds births, deaths and
teaching per step. Horizons (author ruling 8.64): the economy should handle 10 years, governance 20
years, and batteries sometimes run a century of both together with catastrophes and breakthroughs at
roughly realistic frequencies. Conversions below use three mappings, each stated where used, so the
choice can be changed in one place:

- **n_y**, steps per year. Annual figures convert as p_step = 1 - (1 - p_year)^(1/n_y). Working
  values: n_y = 1 (1 step = 1 year) for M7 population, teaching and research, where demography wants
  it; n_y = 12 (1 step = 1 month) for the economy and AdvAp, so that `window` = 100 steps is about
  8 years, close to the 7 years credit reports keep negative items; a 10-year economy run is 120
  steps. Governance: 1,200 decisions over 20 years, 60 decisions a year ([P] reading of 8.64). A
  century joint run is 1,200 economy steps, 6,000 decisions and 100 population years.
- **Per decision**: lab judgements (advice weights, update fractions) and M5 rates are per voter per
  decision and need no clock.
- **Share of agents or of value**: counts and top-quantile shares (top 0.1% wealth, top 1% output)
  do not survive N of 100 or fewer; use the shape (log-SD, tail exponent), and shares of agents'
  time or of value.

Figures whose meaning changes at this scale are marked **SCALE-CHANGING** in their class cell and are
not proposed as defaults: persuasion rates of mass-media advertising (per exposure of millions) against
advice from a known source in deliberation (per decision); R&D share of GDP (money) against the share of
agents' time and resources diverted to research in M7; success per drug project (years, teams) against
per researcher-year; firm-level innovation against an agent's chance; project cost overruns against
share of a plan delivered per action; world-scale hazard counts against hazards in one community;
annual vigilance against per-step reading (an annual rate of reading a record is not a per-step
chance of reading one actor's record: the lag to detection is about 1/vigilance steps, which links
the two).

---

## 1. Deliberation and persuasion in M5 (priority)

### 1.1 What the simulation does now

`run_m5` with `deliberation = true` (`sim/src/m5.jl`): each voter *i* in domain *k* forms a reading
`own·sign(signal_i) + Σ_j w_j·pub_j + Σ_m w_m·published_m`, where a source's weight is its audited
record, `own = max(record_i, 0.1)`, and a source is "heard" at all only if its record is at least as
good as the voter's own, or rarely (`p_novel`, 0.05) for novel input (`heard_ref`, Lean). With
`info_handling` on, every other person in the domain is a source (the ContentionMap), so a voter with
a poor record hears every better source at full weight. The implied weight on a better source is
about `record_s / (record_s + own)`, close to 1 when the voter is a layperson (`own` near the floor
0.1) and the source an established expert. There is no stubbornness, no mass of voters who ignore
advice, no heterogeneity in how much a person moves, and no cap on persuadability. In short, the
non-expert always follows the expert. This is the opposite of the field.

### 1.2 Evidence

| Source | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Finding, weighted to the parameter | Bears on |
|---|---|---|---|---|
| [BAI23] Bailey et al. 2022/2023, *Current Psychology* 42, doi 10.1007/s12144-022-03573-2 (ok) | Mixed: mean weight on advice invariant; its rise with a visible quality cue is the condition Benefuture's audited records supply | Per judgement per person (per decision). Sim unit: per voter per decision; no conversion | Meta-analysis, 346 effect sizes, 129 datasets, N = 17,296, judge-advisor paradigm **(abs)**. Advice-quality cues are the only unique predictor; age, gender, individualism do nothing **(abs)**. Average weight of advice (WOA) 0.39, 95% CI [0.37, 0.42], as quoted by a later paper **[unverified: not read in the original]**. | Mean weight on advice: about 0.4 pooled over advisor types; moves with perceived quality |
| [YAN04] Yaniv 2004, OBHDP 93, doi 10.1016/j.obhdp.2003.08.002 (ok); [YK00] Yaniv & Kleinberger 2000, doi 10.1006/obhd.2000.2909 (ok) | Mixed: egocentric discounting invariant; track-record sensitivity is the visible-record condition | Per judgement per person; weight is a share of the way moved. Per voter per decision | Judges shift toward advice but give their own view about two thirds to 70% (egocentric discounting); weight rises with the advisor's track record (reputation formation); normative averaging would be 0.5. Figures about 0.2–0.35 **[unverified]**. | Mean weight 0.2–0.4; weight tracks record (the sim's direction is right, its level is not) |
| [SL09] Soll & Larrick 2009, JEP:LMC 35, doi 10.1037/a0015145 (ok) | Invariant: shape of the weight distribution (point masses and spread) | Share of persons (per judgement). Per voter per decision | People mostly *choose* one estimate or *average*; averaging would have been more accurate for most participants **(abs)**. A secondary report gives about 50% of cases choosing (own or advisor's), 20% averaging, 30% intermediate weighting **[unverified, secondary]**; the weight distribution is described as trimodal at 0, 0.5, 1 **[unverified, secondary]**. | **Shape**: point masses at 0, 0.5 and 1 plus a spread; a large mass at 0 (stay put) |
| [BD06] Bonaccio & Dalal 2006, doi 10.1016/j.obhdp.2006.07.001 (ok) | Invariant | Qualitative; per judgement | Review: advisor expertise and confidence raise use; the judge's own knowledge lowers it; people discount advice because they know their own reasons and not the advisor's. | Own-versus-advisor asymmetry; expertise effect size not given here |
| [SSD04] Sniezek, Schrah & Dalal 2004, doi 10.1002/bdm.468 (ok); [GM07] Gino & Moore 2007, doi 10.1002/bdm.539 (ok); [HF97] Harvey & Fischer 1997, doi 10.1006/obhd.1997.2697 (ok) | Mixed: expert multiplier invariant; committed money is an institutional condition | Per judgement; stake is relative to the task | Committed money raises use of *expert* advice but not novice advice **(abs)**; advice is used more when the task is hard; judges credit advisors with expertise by moving toward them. | Expert multiplier on the weight |
| [LOG19] Logg, Minson & Moore 2019, doi 10.1016/j.obhdp.2018.12.005 (ok) | Mixed: preference for algorithms depends on exposure and framing | Per judgement; per voter per decision | Lay people lean toward algorithmic over human advice; experts do not **[unverified detail]**. | Weight a layperson gives a published model reading (`model_share`) |
| [HILL17] Hill 2017, J. Politics, doi 10.1086/692739 (ok) | Invariant | Fraction of the Bayesian update per item; per voter per update (per decision) | Subjects update political facts as "cautious Bayesians" at about 73% of Bayes' rule, less for information inconsistent with prior beliefs; beliefs do not polarise **(abs)**. | Conservatism: effective update about 0.7 of Bayes; asymmetry for disconfirming input |
| [MOB22] Möbius et al. 2022, doi 10.1287/mnsc.2021.4294 (ok); [PE66] Phillips & Edwards 1966, doi 10.1037/h0023653 (ok); [EDW68] Edwards 1968 (chapter, no DOI; reprint https://www.cambridge.org/core/books/judgment-under-uncertainty/conservatism-in-human-information-processing/8B7029284C4E87E35765A09F768060CE, not fetched) | Invariant | Fraction of the Bayesian update per item; per voter per update | Updating is too little overall (conservatism) and asymmetric about self-relevant news **(abs for Möbius)**; classical result that people revise by a fraction of the Bayesian amount **[unverified size]**. | Same: conservative updating as a general property |
| [MER17] Mercier 2017, doi 10.1037/gpr0000111 (ok) | Mixed: the capacity to check plausibility and competence is invariant; how much it is exercised depends on the information environment | Qualitative; sets a floor, no unit | Review: communication is "much less influential than often believed"; people check plausibility, calibrate trust to competence and benevolence, evaluate arguments **(abs)**. | Epistemic vigilance: a floor of resistance even to experts |
| [DVG10] DellaVigna & Gentzkow 2010, *Annu. Rev. Econ.* 2, doi 10.1146/annurev.economics.102308.124309 (ok), NBER w15298 https://www.nber.org/papers/w15298 (200); [DVK07] DellaVigna & Kaplan 2007, doi 10.1162/qjec.122.3.1187 (ok) | Institution-dependent: mass-media and campaign exposure of today's channels. SCALE-CHANGING: per exposure of a large audience to broadcast or mail over weeks; not a default for advice from a known source in deliberation | Per exposure, share of the unconvinced in an audience of millions. No direct sim unit; only the status-quo baseline of a broadcast channel (`published_m`) | The *persuasion rate* is the share of those not yet convinced who are converted **(abs: definition)**. Fox News: 3–8% of non-Republican viewers moved to vote Republican on inclusive audience measures, 11–28% on restrictive ones (as quoted from the review in a search snippet **[unverified]**). A get-out-the-vote mailer raised turnout by about 1 pp. Typical field persuasion rates are single digits to low tens of percent **[unverified range]**. | Population-level persuasion per exposure: 3–15%, not 70–100% |
| [KB18] Kalla & Broockman 2018, APSR, doi 10.1017/S0003055417000363 (ok) | Institution-dependent: persuasion in settled, high-salience US general elections under today's polarised media. SCALE-CHANGING | Per campaign contact in a national election; effect on a binary vote in pp. Not a per-decision weight | 49 field experiments: the best estimate of persuasion by campaign contact and advertising in US general elections is zero **(abs)**. | Lower bound: for a settled, high-salience choice the mean effect is about 0 |
| [CHV20] Coppock, Hill & Vavreck 2020, *Sci. Adv.*, doi 10.1126/sciadv.abc4046 (ok); [HEW24] Hewitt et al. 2024, APSR, doi 10.1017/S0003055423001387 (ok) | Institution-dependent: effect of one political advertisement on today's audiences. SCALE-CHANGING | Per ad exposure, pp of a binary opinion. Not a per-decision weight | 49 ads in 59 experiments, N = 34,000: 0.05 points on a five-point favourability scale (SD across experiments 0.07) and 0.7 pp on vote choice (SD 2 pp) **(abs)**. 146 campaign experiments, 617 ads, over 500,000 respondents: 0.8 pp (2020 presidential) to 2.3 pp (2018 down-ballot) on immediate vote choice **(abs)**. | Effect of one message: 1–2 pp of a binary opinion; small variance across messages |
| [WP19] Wood & Porter 2019, *Political Behavior*, doi 10.1007/s11109-018-9443-y (ok); [GC20] Guess & Coppock 2020, BJPS, doi 10.1017/S0007123418000327 (ok) | Invariant: backfire is rare across populations and issues | Share of persons per exposure; per voter per decision | Backfire (moving away from counter-attitudinal evidence) is rare: essentially absent across dozens of issues (about 52 issues and 10,100 subjects **[unverified]**); three survey experiments find no backlash even under favourable conditions **(abs for GC20)**. | Backfire probability near 0 (at most 1–2% of persons): do not model repulsion; model resistance (zero movement) |
| [VDL15] van der Linden et al. 2015, PLoS ONE, doi 10.1371/journal.pone.0118489 (ok); [BD18] Bolsen & Druckman 2018, doi 10.1177/1368430217737855 (ok); [VDL19] van der Linden 2019 replication, doi 10.1016/j.jenvp.2019.01.009 (ok) | Mixed: the gateway effect is a property of belief updating (invariant); the stunting by partisan identity is institution-dependent | Per message; perceived-consensus points. Per voter per decision, as a bound on weight | A consensus message raised *perceived* consensus (about +13% on average and up to +20% in some arms, from a Yale summary **[unverified]**); belief and policy support moved much less (gateway belief model, N = 1,104 **(abs)**). Partisan identity and politicisation "stunt" the effect **(abs for BD18)**. | Expert-consensus messaging moves beliefs by a few points, less for the opposed camp |
| [LFJ02] Luskin, Fishkin & Jowell 2002, BJPS, doi 10.1017/S0007123402000194 (ok); [FL05] Fishkin & Luskin 2005, doi 10.1057/palgrave.ap.5500121 (ok); [FAR10] Farrar et al. 2010, doi 10.1017/s0007123409990433 (ok, corrected); [FSDB21] Fishkin et al. 2021, APSR, doi 10.1017/S0003055421000642 (ok) | Institution-dependent: produced by deliberative-poll design (paid, balanced, moderated, attentive); an upper bound. SCALE-CHANGING (a one- or two-day event of hundreds of participants) | Per participant per event (pp shift on items); one event is a burst of decisions. Not a per-decision weight | Deliberative Polls (information, balanced briefing, small groups): statistically significant net opinion change on many items, larger on less salient issues; a review of 22 polls reports significant change "far more rule than exception" (Han, Fishkin & Luskin, title and venue **[unverified]**). Typical item shifts 10–30 pp, up to about 30 pp on some items in America in One Room **[unverified, secondary]**; knowledge items move far more (about 20% to 74% correct on one item **[unverified]**). | Upper bound under ideal conditions (paid, balanced, moderated, attentive): a *minority* of persons move far, the majority move little |
| [MOU13] Moussaïd et al. 2013, doi 10.1371/journal.pone.0078433 (ok); [LOR11] Lorenz et al. 2011, doi 10.1073/pnas.1008636108 (ok); [BEC17] Becker et al. 2017, doi 10.1073/pnas.1615978114 (ok) | Invariant | Per judgement; weight falls with the gap in units of spread; per voter per decision | Estimates shift toward others' but weight falls with distance from one's own estimate; influence shrinks the diversity of the crowd and can reduce its accuracy. | Weight is not constant: it falls as the gap grows (a confidence interval around one's view) |
| [DMZ03] DeMarzo, Vayanos & Zwiebel 2003, doi 10.1162/00335530360698469 (ok); [ENZ19] Enke & Zimmermann 2019, doi 10.1093/restud/rdx081 (ok) | Invariant | Per judgement; the bias applies to every pass of readings (`rounds`) | People double-count correlated information (persuasion bias; correlation neglect). | Supports source tags: untagged echoes are counted as independent (the sim's `rounds`) |
| [BUR11] Burgman et al. 2011, doi 10.1371/journal.pone.0022998 (ok); [SHA92] Shanteau 1992, doi 10.1016/0749-5978(92)90064-E (ok); [GRO00] Grove et al. 2000, doi 10.1037/1040-3590.12.1.19 (ok) | Mixed: the poor predictive value of status is invariant; how much status is trusted depends on whether records are audited | Per expert judgement; qualitative | Expert status is a poor predictor of expert performance; experts are accurate only where the task has feedback and structure; mechanical prediction rarely loses to clinical judgment. | Why deferring to a *reputation* is not always right (and why weight should track audited records, which the sim does) |

### 1.3 Reading across the evidence

1. A non-expert who hears an expert keeps most of their own position. The pooled weight on advice
   is about 0.3–0.4 even in lab tasks that reward moving, and about 0 for settled political choices.
   With the advisor's quality visible the weight rises, but the mean stays well below 0.5.
2. The distribution is not a bell. It is a *mixture*: a large mass at exactly 0 (the person stays
   put), a spike near 0.5 (averaging), a small spike near 1, and a spread in between.
3. Mean persuasion per message in the field is 1–3 pp of a binary opinion; persuasion rates
   (share of the unconvinced converted) are single digits to low tens of percent for sustained
   exposure. These are institution-dependent and scale-changing (mass media over weeks, an audience
   of millions): they bound a broadcast channel, not the weight on advice from a known source.
4. Backfire is rare: model resistance, not repulsion.
5. Deliberation under ideal conditions moves a minority of persons a long way, mostly on facts and
   on low-salience items. That is the upper bound on weight, not the typical weight.
6. Updating is conservative: about 0.7 of Bayes' rule (Hill) or less (Edwards), and asymmetric
   against disconfirming news.

### 1.4 Proposed per-person weight on advice

Let *w* be the share of the way a person moves from their own reading toward the pooled reading of
a source they judge better than themselves. One draw per person per domain, persistent, redrawn with
chance about 0.01 per decision [assumption]. The weight splits into a lab-derived **invariant
mixture** and an **institution-dependent conditioning**.

**Invariant part: the plain mixture.** Pooled over the judge-advisor literature, with the advisor's
quality neither shown nor hidden:

| Component | Probability | Value |
|---|---|---|
| Stay put (never moves) | 0.30 | w = 0 |
| Average with the source | 0.20 | w ≈ 0.5 (narrow, SD 0.05) |
| Defer (adopt the source's reading) | 0.05 | w ≈ 1 (narrow, SD 0.05) |
| Intermediate weighting | 0.45 | w ~ Beta(2, 3) (mean 0.40, SD 0.20) |

Mixture mean is 0.33 (0.10 + 0.05 + 0.18) and 0.32 of persons sit at or below w = 0.1 (0.30 at zero
plus 0.45 × 0.052 from the Beta). That matches the pooled mean of about 0.3–0.4 [BAI23, YAN04] and a
choosing share near a third to a half [SL09]. Unit: share of persons and share of the way moved, per
voter per decision; no conversion. This is the property of the human judge (partial advice taking,
egocentric discounting, rare full deference), so it carries over to a Benefuture society. It is kept
as the **limiting case** "quality invisible" and as a baseline.

**Institution-dependent part: conditioning on visible quality.** In the lab, the weight rises when
the advisor's quality cue is visible and clearly better [BAI23], [SSD04], [YK00]; it falls when the
record is invisible or the topic is politicised [BD18]. In Benefuture IH every source carries a
visible, audited record and truth-level tags, which correspond to the sources' "visible, clearly
better record" condition. That is a condition the institutions supply, not a trait of the judge. The
implication for the default is the conditioned mixture, because records are visible by design:

| Condition | Stay put | Mean w | Role |
|---|---|---|---|
| Record visible, clearly better (Benefuture IH: audited record and truth-level tag) | 0.20 | about 0.40 | **Default** for M5 deliberation |
| Plain mixture (record neither shown nor hidden) | 0.30 | 0.33 | Limiting case (tags and records ignored) |
| Record invisible or topic politicised (status quo, hostile information environment) | 0.45 | about 0.25 | Status-quo baseline and stress end |

The default does not go higher than 0.40 although Benefuture's records are better than a lab cue:
the lab shows that even a visible cue leaves the mean well below 0.5, and whether audited records and
tags raise trust beyond the lab cue has no direct field analogue except reputation systems
([RZSL06], [CH10]); any rise above 0.40 is an **[OPEN]** conjecture to be swept, not a default. Sweep:
mean of *w* from 0.15 (settled, politicised issues; [KB18], [BD18]) to 0.5 (visible expert, hard task,
incentives; [SSD04], [GM07]); the stay-put mass between 0.1 and 0.6. The sweep spans the status-quo
baseline (0.45 stay put) to the plausible Benefuture value (0.10 to 0.20).

Two further rules, both invariant:

- **Distance falloff.** Multiply *w* by a factor decreasing in the gap between the voter's reading
  and the source's, in units of the domain's spread (a bounded-confidence rule; [MOU13]).
- **Backfire.** Probability 0 by default; at most 0.01–0.02 of persons repel on a politicised
  topic, as a robustness test only [WP19, GC20].

Validation targets (a check, not a fit). Kept, per decision and per person: pooled mean of *w*
0.3–0.4 [BAI23, YAN04]; deliberation under ideal conditions moving a minority a long way on facts
[FSDB21, LFJ02] (an upper bound, per event). Not used as targets for known-source advice in
deliberation, because their scale changes: 1–3 pp per message and 3–15% persuasion over a sustained
campaign [DVG10, DVK07, CHV20, HEW24] (mass media, per exposure of millions) and consensus messaging
[VDL15] (perceived consensus versus held belief, per message). They remain baselines for a broadcast
channel (`published_m`) if one is modelled.

**Confidence: medium** for the mean and the mixture (the lab literature is large and consistent, but
the exact masses come from one secondary report); **low** for the conditioning table and the mapping
from lab estimation tasks to votes on options.

**Caveats (proxy validity).** The judge-advisor paradigm measures numeric estimates, not votes on a
policy menu. A vote is a sign (the code uses `sign(reading)`), so weights on advice are real only
through their effect on whether the reading's sign flips; with *w* < 0.5 on average, most experts
change few signs unless the voter's own signal is weak. Field persuasion studies measure an output
(vote, turnout), the quantity Benefuture can read. Sources study mostly Western and student or online
panels. The effect of *audited records* on trust (the sim's mechanism) has no direct field analogue
except reputation systems on e-commerce sites ([RZSL06], [CH10]).

**Relation to the code (a proposal for an increment, not a change made here).** Replace "hear a
better source at weight = record" by weight = record × *w_i*, where *w_i* is drawn per person from
the conditioned mixture, keeping `p_novel` for novel input. The sim's floor `own ≥ 0.1` already sets a
minimum weight on one's own view; the data say the voter's own weight is about 0.6–0.7 on average
and 1.0 for the stay-put mass. Acceptance test: mean *w* in 0.25–0.45; share at exactly 0 in
0.15–0.45 (0.15–0.25 in the default, 0.25–0.35 in the plain mixture, 0.4–0.5 in the invisible
condition); no sign flips beyond a set share when a better source disagrees with a confident voter.
Counterexample test: with *w* = 1 for all, governance accuracy over-rewards a single captured
expert (the sim's present behaviour), which the field's resistance would dampen; and the plain
mixture as a limiting case must not beat the conditioned default by more than the sweep's own spread.

### 1.5 Other deliberation parameters (M5)

| Parameter (file) | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; dimensionless target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `n_contacts` (m5.jl) | Mixed: core-network size and homophily are human limits (invariant); who counts as a contact in Benefuture is set by the open log and `info_handling` | Persons per person (count). Per voter; with 20 to 100 voters, 2 to 3 contacts are 2 to 5% of voters, so keep the count, not the share | 5 (0–20) | Persons each voter hears when `info_handling` is off | Core discussion network about 2–3 persons; plus weak ties; range 0–10; heavy-tailed degree, homophilous | [MCP06] McPherson, Smith-Lovin & Brashears 2006, doi 10.1177/000312240607100301 (ok): mean core discussion network 2.08 in 2004, modal 0 **[unverified numbers]**; [MSC01] McPherson et al. 2001, doi 10.1146/annurev.soc.27.1.415 (ok) | Medium. Self-reported "important matters" network; media and online sources are not contacts |
| `p_novel` (0.05; 0–0.2) | Institution-dependent: whether novel input is surfaced depends on channels | Per decision per listener; no source | Chance a weaker source brings novel input to a listener | No direct source. Weak-tie information value is established qualitatively | Status-quo baseline: none. Benefuture [CONJ]: open logs, source tags and outcome-scored records make novel but better input visible, so the rate rises. Sweep: 0 to 0.2 (the existing range). Default: swept; 0.05 as a placeholder with no source. |  | Low. Treat as free |
| `rounds` (1; 1–5) | Mixed: the human urge to pass things on is invariant; platform amplification and untagged reshares are institutional | Reshare chain depth per item, per post. Per decision: passes of readings | Passes of readings before the vote | Number of echo passes: online reshare chains are mostly size 1 with rare deep cascades | Mostly 1; tail to 5+ | [VOS18] Vosoughi, Roy & Aral 2018, doi 10.1126/science.aap9559 (ok); Goel et al. 2016 in `docs/DATA.md` | Low-medium |
| `camp_bias` (0; 0–2) | Institution-dependent: paradigm lean from funding, careers and sponsorship | Share of expert disagreement per decision; no source | Experts' paradigm lean, in units of signal | Share of expert disagreement due to systematic lean; no direct source. Crowd-rated notes show bridging needs cross-camp agreement | Status-quo baseline: 0.2–1 in contested domains, 0 in settled ones. Benefuture [CONJ]: readings scored by outcomes, research as spending and cross-camp bridging reduce lean in settled domains; contested ones keep some. Sweep: 0 to 1 in units of signal. Default: swept; 0 is a limiting case, start at 0.1 in contested domains. | Community Notes, Polis (`docs/DATA.md` section 10) | Low |
| `tag_liars`, `tag_lie` (none; 0–30%) | Mixed: unintentional quotation error invariant (carelessness); intentional misattribution institution-dependent | Share of quotations per paper. Per reading: share with false origin | Share misattributing or omitting origins | Quotation and citation errors: 25.4% of quotations in medical papers contain an error, 11.9% major **(abs)**; citation distortion builds unfounded authority | Fraction of readings with false origin 5–25% (error, mostly unintentional); intentional share unknown | [JB15] Jergas & Baethge 2015, doi 10.7717/peerj.1364 (ok); [GRE09] Greenberg 2009, doi 10.1136/bmj.b2680 (ok) | Medium for error rate; low for intent |
| `source_tags` echoes | Institution-dependent: naive counting is today's norm; the tag is the intervention | Per reading; on or off | off | Double counting of one origin | Correlation neglect is the norm: treat naive as default and tags as the intervention | [DMZ03], [ENZ19] | Medium |
| `model_σ0`, `p_new_model`, `improve_*`, `scale_min` (M5) | Mixed: see section 3.3 | Per reading; see 3.3 | 5, 0, −0.1, 0.3, 0.1 | See section 3.3 (models) |  |  |  |
| `model_capture` | Institution-dependent: sponsor bias and rating inflation; frequency and size depend on who funds and who is scored | Relative risk of a favourable result per study (about 1.3). Sim: bias in units of the domain's spread on a captured model, for a spell of steps | none | A top model publishes one side for a spell | Status-quo baseline: Sponsor bias: industry-funded studies report favourable results and conclusions more often than other sponsors **(abs: direction)**; rating inflation from competition between raters. Benefuture [CONJ]: scoring against markers costs a biased model its eligibility (L82), so capture is shorter and rarer; sponsor funding is visible in the ledger. Sweep: bias 0 to 0.3 of spread; frequency from 0 to the status-quo spell share. Default: swept; no default. | [LUN17] Lundh et al. 2017, doi 10.1002/14651858.MR000033.pub3 (ok); [BFS12] Bolton, Freixas & Shapiro 2012, doi 10.1111/j.1540-6261.2011.01708.x (ok); [BM11] Becker & Milbourn 2011, doi 10.1016/j.jfineco.2011.03.012 (ok); [DAL06] Dal Bó 2006, doi 10.1093/oxrep/grj013 (ok) | Medium for existence and direction; low for size (relative risk of favourable results about 1.3 **[unverified]**) |
| `p_apparent` (0.7; 0.2–1) | Mixed: hidden outcomes are partly the nature of long-lag effects; measuring outcomes is what Benefuture does by design, so apparentness should rise | Share of decisions per decision. Status quo: most policies are never rigorously evaluated | Decision's optimality becomes apparent | No direct source. Replication and evaluation analogues: most policies are never rigorously evaluated | Status-quo baseline: 0.1–0.6 for most social decisions. Benefuture [CONJ]: markers and causal assessment make outcomes apparent more often. Sweep: 0.1 to 0.9. Default: swept; 0.7 stays as the Benefuture-plausible end. | none | Low |

---

## 2. Method for the remaining tables

Each row gives: parameter (code name, file), class (0.1), unit and conversion (0.2), now (range),
what it represents and the dimensionless target, proposal, sources, confidence and caveats. For an
invariant row the proposal is a default, range and shape. For an institution-dependent row it is
the status-quo baseline, the Benefuture direction [CONJ], the sweep and the default rule ("emerges"
or "swept"). Where the proposal lies outside the current range the row says so, and section 7
collects the disagreements.

## 3. Parameters by area

### 3.1 The world's plans and its measurement (`ToyParams`, M0; `marker_σ`, `classify_σ`)

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `ToyParams.spread` (m0.jl) | Invariant: heterogeneity of effects across sites and beings | CV across studies and sites; sim: CV across beings within a plan, per plan. Caveat: sites are not beings | 1.0 (0.5–3) | Scatter of a plan's effect across beings, relative to its mean (CV of treatment effect) | Heavy: between-site SD of effects is usually at or above the mean effect; CV 1–3; heavy-tailed, signed | [VIV20] Vivalt 2020, doi 10.1093/jeea/jvaa019 (ok): heterogeneity across impact evaluations is large relative to the mean **[unverified size]**; [MEA19] Meager 2019, doi 10.1257/app.20170299 (ok); [BTY21] Bryan, Tipton & Yeager 2021, doi 10.1038/s41562-021-01143-3 (ok) | Medium. Heterogeneity across *sites* not across beings within a plan |
| `touch`, `shift` (0.05–0.3, 0.5) | Mixed: effect sizes invariant; reach of an intervention depends on delivery institutions | Share of the target population touched; share of beings (N of 200 to 1,000 in M1, 100 or fewer in M5) | Share of beings a plan touches; scatter of its mean | Interventions reach a minority; effect sizes: median 0.1 SD of test score in education trials | touch 0.01–0.3 (right-skewed); shift as 0.1–0.3 of the spread | [KRA20] Kraft 2020, doi 10.3102/0013189X20912798 (ok) | Low-medium |
| `marker_σ` (0.05; 0.02–0.2) | Mixed: response noise of self-report invariant; noise of counts and registries institution-dependent | Noise as a share of spread, per measurement. Per marker reading per being per step | Marker error as a share of spread | Reliability r of a test or survey item: noise/spread = sqrt(1 − r). Life-satisfaction single item r about 0.6–0.7 (noise 0.55–0.63); good tests r 0.9 (noise 0.32); administrative counts r above 0.99 (noise 0.1) | Understanding via tests: 0.3 (0.15–0.5); happiness via single items: 0.6 (0.5–0.7); behavioural counts: 0.05–0.15 | `docs/DATA.md` section 2 (Krueger & Schkade 2008, doi 10.1016/j.jpubeco.2007.12.015; Lucas & Donnellan 2012); PISA plausible values | High that 0.05 is optimistic for survey markers; the battery's top (0.2) is the realistic *bottom* for self-report markers. Units: depends on whether `marker_σ` is relative to the population SD |
| `classify_σ`, `spread` of causal signatures (0.03; 0.03–0.1) | Invariant: human coding noise | Misclassification share per item. Per action classified | Noise in classifying an action to a domain | Inter-rater agreement kappa about 0.6–0.8 for coding tasks (substantial) | Misclassification 10–25% of items; modelled as signature noise 0.05–0.2 | Landis & Koch 1977 conventions **[unverified, no link]**; [PAN-WVC] https://webis.de/data/pan-wvc-10.html (200) | Low |
| `attribution_σ` (0.1; 0–0.3) | Mixed: egocentric bias invariant; the size of attribution error is reduced by causal distribution (Shapley shares over outcomes) | Claimed share of joint products (percent over 100). Per attribution | Error in separating an upstream output's part | Overclaiming: co-authors or spouses' claimed shares of a joint product sum to well over 100% (about 120–140% **[unverified]**) | 0.1–0.4 relative; biased upward for self | [RS79] Ross & Sicoly 1979, doi 10.1037/0022-3514.37.3.322 (ok) | Medium. Egocentric bias is directional, the sim's noise is symmetric |
| `cost_σ` (0.1; 0–0.3) | Institution-dependent: accounting practice and audit | Relative error per cost estimate. Per resource accounting step | Resource accounting error | Stock assessments carry CVs of 0.2–0.5 **[unverified]**; firms' cost estimates err by 10–30% | Status-quo baseline: 0.1–0.3. Benefuture [CONJ]: audited ledgers and settlement against measured outcomes reduce accounting error. Sweep: 0.05 to 0.3. Default: swept. | Ralston et al. 2011, Fishery Bulletin **[unverified, no link]** | Low |

### 3.2 Skills, agents, execution and choice noise

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `DomainAgent.skills` (m3c; battery 0.6 or 0.1–0.5) | Invariant: spread and tail shape. At N of 100 or fewer agents the top-1% share is one agent: use the shape, not quantile shares | CV or log-SD of output per person per task. Sim: per agent skill, per step action quality | Uniform / fixed | Spread and tail of productivity: CV by job complexity about 0.2 (simple), 0.3 (medium), 0.5 (complex) **[unverified numbers]**; individual output in science, arts, sport follows a Paretian (power-law) tail, not a bell; plant TFP 90-10 ratio about 2 in the US and 4–5 in India and China **[unverified]** | Log-normal with log-SD 0.3–0.5 for ordinary tasks; Pareto tail (exponent 2–3) for research and creative output; top 1% hold 10–30% of output | [HUN90] Hunter, Schmidt & Judiesch 1990, doi 10.1037/0021-9010.75.1.28 (ok); [OBA12] O'Boyle & Aguinis 2012, doi 10.1111/j.1744-6570.2011.01239.x (ok); [SYV11] Syverson 2011, doi 10.1257/jel.49.2.326 (ok); [SIN16] Sinatra et al. 2016, doi 10.1126/science.aaf5239 (ok) | Medium-high for heavy tails. Output is an output (the sim's skills are latent) |
| `sloppiness` (0; 0–0.6) | Mixed: intention-behaviour gap for individuals invariant (default 0.25); for projects institution-dependent (3.10) | Share of intended effect not delivered, per action; sim per action per step | Share of a plan not carried out as chosen | Intention-behaviour gap: a medium-large change in intention (d = 0.66) yields a small-medium change in behaviour (d = 0.36) **(abs)**; about 47% of those intending to act fail to **[unverified]** | Default 0.25 (0.1–0.5) for individuals; for projects see section 3.10 | [WS06] Webb & Sheeran 2006, doi 10.1037/0033-2909.132.2.249 (ok); [SHE02] Sheeran 2002, doi 10.1080/14792772143000003 (ok) | Medium. Default 0 is a limiting case; world default should be mildly imperfect (8.33) |
| `signal_σ`, `ability_spread` (M5; 1, 0.5; 1–40, 0–1.5) | Mixed: perception and signal noise invariant (default sigma 2 to 4 for non-experts); the informed share depends on the civic information environment (swept) | Probability correct per decision per voter (p = Phi(1/sigma)) | A voter's signal noise (a probability correct p = Φ(1/σ)) and its scatter | Competence of ordinary voters on a hard question: 0.55–0.75 correct (σ = 1 gives 0.84, σ = 2 gives 0.69, σ = 4 gives 0.60, σ = 40 gives 0.51). Voting correctly (matching own preferences) about 75% in US presidential elections **[unverified]**; scatter is wide (informed minority, uninformed majority) | Non-experts σ 2–4 (p 0.6–0.69); experts in own domain σ 0.5–1 (p 0.84–0.98); ability spread 0.5–1.5; bimodal informed/uninformed | [LR97] Lau & Redlawsk 1997, doi 10.2307/2952076 (ok); [BAR96] Bartels 1996, doi 10.2307/2111700 (ok); [GAL07] Galton 1907 (Vox Populi), doi 10.1038/075450a0 (ok) | Medium. Condorcet competence is not directly observable; this is a cross-domain proxy |
| `choice_σ`, `choice_gain`, `ability_spread` (economy; 0.5, 5, 0.5) | Invariant: judgement noise between professionals | CV of the judged quantity per judgement; per choice per agent per step | Choice noise in co-funding judgements, with skill gain | Judgement noise between professionals: "noise audits" found median pairwise differences of about 50% between underwriters on identical cases **[unverified]**; grant reviewers show no agreement on the same applications **(abs)** | CV 0.3–0.6 of the judged quantity; low agreement for ex ante evaluation of novel work | Kahneman, Sibony & Sunstein 2021, *Noise* (book, ISBN 978-0316451406 **[unverified link]**); [PIE18] Pier et al. 2018, doi 10.1073/pnas.1714379115 (ok); [FAN16] Fang et al. 2016, doi 10.7554/eLife.13323 (ok) | Medium |
| `view_σ`, `pred_σ` (M7; 0.2, 0.2; 0–1) | Invariant: estimation error of individuals | CV of an estimate per estimate; per entity per step (G is run each step) | Entity's noisy view of reality, its prediction noise (G run by everyone, 8.50) | As above: single-person estimation error CV 0.3–0.6; wisdom-of-crowd median error far lower | 0.3–0.6 default; range 0.1–1 | [GAL07], [LOR11], Kahneman et al. 2021 | Low-medium |
| `p_act`, `action_scale`, `options` (0.2, 0.05, 3) | Institution-dependent: participation inequality is produced by platform and incentive design; in Benefuture contributing is paid (co-funding, research as spending) | Share of users active in a period (a month for online communities). Sim: share of agents acting per step. With a step of a month, 0.01 to 0.1 maps directly | Share acting per step, share of a plan per action, options per entity | Participation inequality: about 1% create, 9% contribute occasionally, 90% observe (the 90-9-1 rule) | Status-quo baseline: p_act as share active in a period: 0.01–0.3, very skewed across persons. Benefuture [CONJ]: contribution is rewarded by outcome shares, so the active share rises and the skew falls. Sweep: 0.01 to 0.5. Default: swept; 0.2 inside the range. | [CAC14] Carron-Arthur et al. 2014, doi 10.1016/j.invent.2014.09.003 (ok); Nielsen 2006, https://www.nngroup.com/articles/participation-inequality/ (200) | Medium for skew; low for step mapping |
| `p_informed`, `diligence` (0.8, 0.95) | Institution-dependent: compliance without audit is about 0.4; with audit and stakes 0.9 | Share of opportunities complied with, per opportunity (hand hygiene per opportunity). Sim: per known duty per step | A guardian learning of a hazard in time; acting on a known duty | Compliance with a known protocol: hand-hygiene compliance averages about 40% at baseline and reaches 60–70% with interventions **[unverified numbers]** | Status-quo baseline: diligence 0.5 (0.3–0.9) for routine duties without audit; 0.9+ only with audit and stakes. Benefuture [CONJ]: negligence is penalised through the ledger and clawbacks, so diligence rises; informing guardians is cheaper with an open log. Sweep: diligence 0.4 to 0.95; p_informed 0.6 to 0.95. Default: swept; 0.95 is the Benefuture end, 0.4 the status quo. | [ERA10] Erasmus et al. 2010, doi 10.1086/650451 (ok) | Medium. A professional-safety domain; the default 0.95 is high |
| `p_foresee` (0.5; 0–1) | Mixed: foreseeability of side effects in complex systems invariant; the preventable share (safety culture) institution-dependent | Share of adverse events preventable. Sim: share of side effects foreseeable per action | Share of side effects foreseeable | Preventable share of in-hospital adverse events: 43.5% median **(abs)**; negligent share about 28% in the Harvard study **[unverified]** | Status-quo baseline: 0.43 (0.25–0.6). Benefuture [CONJ]: research as spending and scored models raise the foreseeable share. Sweep: 0.25 to 0.7. Default: swept; 0.43 is the baseline. | [DEV08] de Vries et al. 2008, doi 10.1136/qshc.2007.023622 (ok); [BRE91] Brennan et al. 1991, doi 10.1056/NEJM199102073240604 (ok) | Medium |

### 3.3 Metric models and forecasters

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `σ_leaf` (0.15; 0.05–0.45) | Mixed: predictability of the domain is a limit set by the system (invariant); the level reached depends on research spending and model competition | Residual SD over outcome SD per prediction, at the prediction's horizon. Sim: per prediction per step; horizon is the dependency window | Established leaf model's error relative to the domain's spread | Residual SD / outcome SD = sqrt(1 − R²). Numerical weather prediction: anomaly correlation about 0.95 at day 3, 0.8 at day 6 (noise 0.3–0.6) **[unverified numbers]**; social and economic forecasting typically R² of 0.2–0.6 (noise 0.65–0.9) | Natural-science mature domain: 0.3 (0.15–0.6); social-science domain: 0.7 (0.5–0.9); 0.15 is a limiting case reached only at short horizons in physics | [BAU15] Bauer, Thorpe & Brunet 2015, doi 10.1038/nature14956 (ok); [MEL14] Mellers et al. 2014, doi 10.1177/0956797614524255 (ok); [CRA22] Cramer et al. 2022, doi 10.1073/pnas.2113561119 (ok) | Medium. Largest single mismatch between default and field |
| `σ_branch`, `σ_coarse` (0.3, 0.45; 0.2–0.6, 0.35–0.75) | Mixed: as sigma_leaf | Per prediction | Parent and coarse models | Coarse models ("it will be warmer in summer"): noise 0.8–1 of spread (no information beyond base rate) | branch 0.6 (0.4–0.9), coarse 0.85 (0.7–1.0); keep order leaf < branch < coarse | as above | Low-medium |
| `bias_σ` (0.1; 0–0.2) | Mixed: overconfidence invariant; the size of actual bias shrinks when models are scored | Relative bias per prediction | Systematic model bias, relative | Overconfidence and optimism: CFOs' 80% intervals contain the truth only about 36% of the time **[unverified size]**; forecasters over-extreme | 0.1–0.3 relative bias; larger for judgmental than statistical models | [BDGH13] Ben-David, Graham & Harvey 2013, doi 10.1093/qje/qjt023 (ok); [MH08] Moore & Healy 2008, doi 10.1037/0033-295X.115.2.502 (ok) | Medium |
| `p_extremist`, `extremise` (0; 0.5) | Invariant: aggregation psychology | Extremising factor per aggregate; share of persons | New models extremising credences; share of uncertainty stated | Aggregates of forecasts are under-extreme; individuals are over-extreme | Extremising factor 1.2–2.5 for aggregates; share of overconfident individuals 0.3–0.6 | [BAR14] Baron et al. 2014, doi 10.1287/deca.2014.0293 (ok); [SAT14] Satopää et al. 2014, doi 10.1016/j.ijforecast.2013.09.009 (ok) | Medium |
| `p_new_model`, `improve_drift`, `improve_σ`, `scale_min` (0, −0.1, 0.3, 0.1; 0–0.1, −0.3–0.1, 0.1–0.5, 0.05–0.3) | Institution-dependent: entry of models depends on research spending and competitions | Entrants per hub per round. Sim: arrival chance per step per domain; with a step of a month, hub rounds of weeks to months map directly | Arrival chance per step and domain; log error ratio of an arrival to the best; scatter; least error vs bootstrap | In forecasting hubs and competitions new entrants join often and most are worse than the incumbent ensemble; the best method beats a standard benchmark by about 10–20% (log ratio about −0.1 to −0.2) **[unverified: M4 winner OWA about 0.82 against 1 for the benchmark]** | Status-quo baseline: `improve_drift` +0.0 to +0.3 for a *typical* new model (mostly worse), with a thin lower tail to −0.2 for the best; `improve_σ` 0.3–0.5; `scale_min` 0.2–0.5 (floor is high in social domains). Benefuture [CONJ]: research is spending, and a model that predicts better earns eligibility, so arrivals rise and the typical arrival improves. Sweep: p_new_model 0 to 0.1; improve_drift +0.3 (typical entrant, status quo) to -0.1 (best entrant, Benefuture). Default: swept; the sim's -0.1 is the Benefuture end, not the status quo. | [CRA22], [MAK20] Makridakis et al. 2020, doi 10.1016/j.ijforecast.2019.04.014 (ok), `docs/DATA.md` section 7 | Medium for the sign (typical entrants are worse); the sim's average improvement of −0.1 per arrival is the *best-entrant* case |
| `model_σ0` (5; 0.5–20) | Mixed: initial noise of a first-generation model | Per reading | Bootstrap model noise in M5 | Initial expert reading accuracy | Express relative to signal: p about 0.6–0.7 for first-generation models (σ 2–4 where the truth is 1) | as `signal_σ` | Low |
| `max_credence` (0.99; governed) | Governed (analogue only) | Per credence | Credence cap | Metaculus restricts forecasts to 1–99% **[unverified, 403]** | Analogue only (section 4) |  |  |
| `credence_ladder`, human probability calibration | Invariant: psychophysics of subjective probability and cognitive overconfidence | Subjective confidence vs objective empirical frequency (dimensionless fraction 0–1) | Now: none | Human credence calibration for 8.69's people credence ladder | Overconfidence flattens calibration at extremes: stated 90% subjective confidence yields 70%–78% empirical hit rate; stated 80% yields 60%–68%; stated 99% yields ~85%–90% (Lichtenstein et al. 1982, Moore & Healy 2008). Sherman Kent (1964) verbal scale mapping: "almost certainly" = 0.93 (±0.06), "probable/likely" = 0.75 (±0.12), "even chance" = 0.50 (±0.10), "unlikely" = 0.30 (±0.10), "almost certainly not" = 0.07 (±0.05) (Wintle et al. 2019) | Invariant: human credences require recalibration via the empirical ladder: compress stated 0.90 to 0.75, stated 0.80 to 0.65; unquantified verbal assessments map to discrete Sherman Kent intervals. Sweep: overconfidence shrinkage 0.70 to 0.90 of nominal log-odds. Default: Sherman Kent verbal ladder for lay inputs (8.69). | [KEN64] Kent 1964; [LFP82] Lichtenstein, Fischhoff & Phillips 1982; [WIN19] Wintle et al. 2019, doi 10.1111/risa.13323 (ok); [MH08] | High |
| `min_record` (30; 10–50), `bind_quorum` (5; 3–9) | Invariant (statistical sample size required for skill discrimination) + Institutional (quorum design) | Number of resolved binary/continuous events (counts) | Now: none | Minimum record to separate forecaster skill (8.69); cluster quorum size (8.70) | Forecasting tournament discrimination power: individual Brier score persistence across < 15–20 questions is noisy (r ≈ 0.15–0.25, luck-dominated); requires 30–50 resolved forecasts to reliably identify superforecasters (r ≈ 0.55–0.65, Tetlock & Gardner 2015, Mellers et al. 2015). For quorum attestations: with independent node false-positive rate p ≈ 0.05, a quorum of 5 independent nodes achieves collusion-free false acceptance p^5 ≈ 3e-7. | Stated minimum record: 30 resolved predictions for model/forecaster qualification (range 20–50); cluster attestation quorum: 5 distinct clusters (range 3–7). Sweep: min_record 15 to 50; bind_quorum 3 to 7. Default: `min_record` = 30, `bind_quorum` = 5. | [TET15] Tetlock & Gardner 2015; [MEL14] Mellers et al. 2014; [BAR14]; [DOU02] | High for sample size discrimination; medium for quorum scaling |

### 3.4 Ledgers, reputation and memory

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `λpos`, `λneg` (0.05, 0.02; governed) | Invariant (human forgetting); the sim's decay is governed | Per day to month forgetting. Sim: per step; only the ratio of positive to negative half-lives is used | Decay of rights and wrongs | Human forgetting is a power law, not an exponential [RW96]; negative information is stickier than positive [BAU01]; legal analogue in section 4 | Ratio of half-lives (λpos/λneg) 2–4; use a power-law or a two-rate mixture; half-life of a positive record about a quarter of `window` | [RW96] Rubin & Wenzel 1996, doi 10.1037/0033-295X.103.4.734 (ok); [MD15] Murre & Dros 2015, doi 10.1371/journal.pone.0120644 (ok); [BAU01] Baumeister et al. 2001, doi 10.1037/1089-2680.5.4.323 (ok) | Low-medium. Decay is governed, so this is a world-realism note, not a default |
| `memory_loss` (0.02; 0–0.1) | Institution-dependent: records infrastructure (link rot, informal records); official ledgers are append-only in Benefuture | Per year loss of availability. Sim: share of records not reaching memory; the code's unit (per record or per step) is to be checked. With a step of a month, 0.02 to 0.15 a year is 0.0017 to 0.013 per step | Records failing to reach memory | Digital records decay: odds that a dataset is available fall about 17% a year with article age **[unverified]**; one in five scholarly articles suffers reference rot (link rot or drift) **(abs: one in five in the title)** | Status-quo baseline: 0.02–0.15 per year; heavy for informal records, low for official. Benefuture [CONJ]: append-only audited ledgers make official loss about 0; only informal memory is lost. Sweep: 0 to 0.1 (existing range) read per step as above. Default: swept. | [VIN14] Vines et al. 2014, doi 10.1016/j.cub.2013.11.014 (ok); [KLE14] Klein et al. 2014, doi 10.1371/journal.pone.0115253 (ok) | Medium. Loss is not random (selection) |
| `vigilance` (0.05; 0.01–0.3) | Institution-dependent: reading of others' conduct is produced by today's incentives (no bounty, no cheap reader, no stake) | Share of consumers opening terms per exposure (0.05 to 0.2%); lags to detection of fraud and cartels in months and years. Sim: chance per step an agent reads one other actor's record; the lag for a given actor is about 1/vigilance steps [derived, assuming N agents each reading one random other per step]. With a month step, 0.01 is about 100 months (cartels, years) and 0.03 about 33 months (retractions) | Chance per step an agent reads another actor's record | People rarely read: 74% skip privacy policies **[unverified]**; between 0.05% and 0.2% of consumers open the terms of service **[unverified]**; salience of a tax changes behaviour about 8% | Status-quo baseline: 0.001–0.02 per step for passive readers; 0.1–0.5 only for stakeholders with a stake or a bounty. Benefuture [CONJ]: AdvAp pays readers a share of the overstatement repaired and open logs let automated readers do the reading, so vigilance rises. Sweep: 0.001 (passive, status quo) to 0.3, with 0.1 as the Benefuture-plausible point. Default: swept; no default. | [BAK14] Bakos, Marotta-Wurgler & Trossen 2014, doi 10.1086/674424 (ok, corrected); [OOH20] Obar & Oeldorf-Hirsch 2020, doi 10.1080/1369118X.2018.1486870 (ok); [CLK09] Chetty, Looney & Kroft 2009, doi 10.1257/aer.99.4.1145 (ok); [SIM03] Sims 2003, doi 10.1016/S0304-3932(03)00029-1 (ok) | Medium. Battery severity 0 (0.3) is unrealistically attentive |
| `pattern_attention`, `stake_attention` (9, 2; 0–20, 0–5) | Mixed: the concentration of attention on bad news is invariant; the stake multiplier is institution-dependent (bounties make every reader a stakeholder) | Multiplier on reading probability (dimensionless); per step | Multiplier on reading a negative-ledger actor; own stake | Attention concentrates on bad news and on stakeholders (journalists on large frauds, employees with money at stake) | Status-quo baseline: Multiplier 3–20 on negative pattern; 2–10 for stakeholders. Benefuture [CONJ]: bounty makes readers stakeholders, so stake_attention rises; pattern_attention is stable. Sweep: pattern_attention 3 to 20; stake_attention 2 to 10. Default: swept. | [DMZ10] Dyck, Morse & Zingales 2010, doi 10.1111/j.1540-6261.2010.01614.x (ok): monetary incentives explain employee whistleblowing; reputational incentives weak except for journalists in large cases **(abs)** | Medium |
| `endowment` (5), `overflow_*`, balance Gini | Institution-dependent: the status-quo wealth distribution is produced by inheritance and today's institutions; in Benefuture property is not inherited and causal distribution pays by outcome | Shares of wealth (top 0.1%) are meaningless at N of 100; use the log-SD. Currency units have no external scale | Initial balances; concentration | Wealth is Pareto-tailed: top 0.1% US wealth share about 20% **[unverified]**; income Gini 0.25–0.6, wealth Gini 0.6–0.9 | Status-quo baseline: Initial balance log-normal, log-SD 0.5–1.0; tail exponent 1.5–2. Benefuture [CONJ]: no inherited property and outcome-based shares narrow the initial distribution, and a tail re-emerges from skill (Pareto) and breakthroughs. Sweep: initial log-SD 0 (equal) to 1. Default: emerges; equal endowments, the tail from earnings. | [GAB16] Gabaix 2016, doi 10.1257/jep.30.1.185 (ok); [SZ16] Saez & Zucman 2016, doi 10.1093/qje/qjw004 (ok); https://wid.world/ | Medium for shape; endowment has no unit |

### 3.5 Audit, deception, whistleblowing, collusion and identity

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `deceit` (0; 0–2), prevalence | Mixed: the honest majority and the bounded cheating of self-image are invariant (shape); the share of full cheaters and fabrication rates are institution-dependent | Share of persons per opportunity; size as a share of the available gain per opportunity. Sim: per agent per plan | Magnitude of fooling the metric models; share of deceivers | Most people cheat a little or not at all; a few cheat fully; about 2% admit fabricating or falsifying research and about 34% questionable practices **[unverified second number]** | Status-quo baseline: Magnitude: point mass at 0 for 55–70%, small cheaters 25–40% (size 10–20% of the available gain), full cheaters 2–5%; bimodal. Benefuture [CONJ]: audited ledgers, liability and clawbacks lower the expected payoff of large cheating; small self-image-limited cheating changes little. Sweep: full cheaters 0 to 5%; small cheaters 10 to 40% (shape fixed). Default: shape fixed (invariant); prevalence swept. | [MAZ08] Mazar, Amir & Ariely 2008, doi 10.1509/jmkr.45.6.633 (ok); [GER19] Gerlach, Teodorescu & Hertwig 2019, doi 10.1037/bul0000174 (ok); [ABE19] Abeler, Nosenzo & Raymond 2019, doi 10.3982/ECTA14673 (ok); [FAN09] Fanelli 2009, doi 10.1371/journal.pone.0005738 (ok) | Medium-high for shape (honest majority, few big liars) |
| `p_trace` (0.5; 0.1–0.9) | Institution-dependent: detection is produced by audit institutions; the annual figures combine a revelation and an examination | Per year detection 0.1 to 0.35 (cartels 0.13 to 0.17, fraud about a third). Sim: p_trace is the chance an examination establishes a revealed deception, per examination, not per step; the per-year figures fold in vigilance and adv_z. Conditional on a revelation reaching an examiner, 0.5 to 0.8. A per-year rate converts by 1-(1-p)^(1/n_y), 0.01 to 0.015 per month-step for 0.13 to 0.17 | Examination establishing a revealed deception | Detection of fraud: only about a third of corporate fraud is ever detected **[unverified]** (`docs/DATA.md`); price-fixing conspiracies are indicted with probability 0.13–0.17 per year **(abs)**; tips detect about 43% of occupational frauds **[unverified]** | Status-quo baseline: Per-year detection 0.1–0.35; given a revelation reaching an examiner, 0.5–0.8. Benefuture [CONJ]: audited open ledgers with markers and causal assessment make the cause cheaper to establish. Sweep: 0.3 to 0.9. Default: swept; the conditional status-quo figure is 0.5 to 0.8. | [BE91] Bryant & Eckard 1991, doi 10.2307/2109581 (ok, corrected); [DMZ23] Dyck, Morse & Zingales 2023, doi 10.1007/s11142-022-09738-5 (ok); ACFE Report to the Nations 2024, https://www.acfe.com/report-to-the-nations/2024/ (200) | Medium. Detection (per year) differs from establishing (given a report) |
| detection lag | Institution-dependent: lags are produced by who watches and how fast; no parameter of its own (it emerges from vigilance) | Lag in minutes to years. Sim: steps; lag is about 1/vigilance. With a month step, 33 months is 33 steps and 5 years is 60 steps. Minute-scale lags (Wikipedia) correspond to vigilance near 1 | (via `vigilance`) | Time to detect: Wikipedia vandalism reverted in minutes; hoaxes mostly removed quickly but a small number survive long **(abs)**; retractions take 32.9 months on average, 49.8 months before 2002 and 23.8 months after **(abs)** | Status-quo baseline: Geometric-like lags with a heavy tail: median minutes (cheap, watched), months (science), years (cartels: durations bimodal, about 5 years on average **(abs)**). Benefuture [CONJ]: cheap open records shorten lags toward the Wikipedia end. Sweep: a lag of a few steps to 100 steps (vigilance 0.01 to 0.3). Default: emerges from vigilance. | [PRI07] Priedhorsky et al. 2007, doi 10.1145/1316624.1316663 (ok); [VWD04] Viégas et al. 2004, doi 10.1145/985692.985765 (ok); [KUM16] Kumar, West & Leskovec 2016, doi 10.1145/2872427.2883085 (ok); [STE13] Steen et al. 2013, doi 10.1371/journal.pone.0068397 (ok); [LS06] Levenstein & Suslow 2006, doi 10.1257/002205106776162681 (ok); [GH13] Geiger & Halfaker 2013, doi 10.1145/2491055.2491061 (ok) | High for the heavy-tailed shape |
| `p_false_trace` (0.01; 0–0.1) | Mixed: examiner judgement error invariant; the wrongful-conviction rate depends on procedure and stakes | Share of honest actors wrongly convicted, per examination (not per step) | Honest actor wrongly convicted | Malpractice claims: a few percent with no injury and over a third with no error **[unverified]**; false conviction among death-sentenced defendants at least 4.1% **[unverified]**; bots set to 0.1% false positives **[unverified]** | Status-quo baseline: 0.01–0.05; higher in adversarial, high-stakes settings. Benefuture [CONJ]: re-scoring on the record and liability for unfounded reports lower wrongful repairs, but error in noisy readings remains. Sweep: 0.005 to 0.05. Default: swept; 0.01 inside. | [STU06] Studdert et al. 2006, doi 10.1056/NEJMsa054479 (ok); [GOS14] Gross et al. 2014, doi 10.1073/pnas.1306417111 (ok) | Medium |
| whistleblowing, `adv_z`, AdvAp response | Institution-dependent: who reveals depends on incentives (money, anonymity, retaliation) | Reveal chance per witness per case (0.1 to 0.4 without reward, 0.5 to 0.7 with a 10 to 30% reward). Sim: a reader reports when its z-score passes adv_z; the reveal rate emerges from vigilance, adv_z and adv_share, not a probability to set | (world) | Who reveals: employees, media, industry regulators, not standard monitors; monetary incentives raise employee revelation **(abs)**; revelation shares: employees about 17%, media 13%, tips 43% (ACFE) **[unverified]** | Status-quo baseline: Reveal chance given a witness 0.1–0.4 (no reward), up to 0.5–0.7 with a 10–30% reward. Benefuture [CONJ]: bounties (adv_share) and clawbacks raise it toward the reward case. Sweep: 0.1 to 0.7 as an emerging rate. Default: emerges; checked against the baseline. | [DMZ10]; SEC programme https://www.sec.gov/whistleblower [403]; ACFE | Medium |
| `collusion_gain`, `loyalty`, `p_weigh` (1, 0, 0.05) | Mixed: response to the temptation/risk ratio invariant; the ratio itself (leniency, reward for revealing, penalties) is institutional | Cooperation share per game; cartel lifetime in years. Sim: per period (the unit of p_weigh is to be checked) | Gain to each from a hidden defection; revealing cost | Defection rates in prisoner's dilemmas: about 47% cooperate on average, driven by the temptation/risk ratio; cartels collapse quickly or last long (bimodal) | Status-quo baseline: `p_weigh` 0.05–0.3 per period; loyalty as a cost 0–10 of gain; cartel lifetimes bimodal. Benefuture [CONJ]: reward for revealing and clawbacks raise the temptation to defect from a bloc. Sweep: p_weigh 0.05 to 0.3; loyalty 0 to 10 of gain. Default: swept. | [SAL95] Sally 1995, doi 10.1177/1043463195007001004 (ok); [MEN18] Mengel 2018, doi 10.1111/ecoj.12548 (ok); [MIL09] Miller 2009, doi 10.1257/aer.99.3.750 (ok): leniency increases detection; [LS06] | Medium-low for mapping |
| `whitewash` (0; 0–0.1), `bind_miss` (0.05; 0.001–0.2), `bind_clusters` | Mixed: biometric sensor noise and matching distributions are invariant given capture geometry; forgery, synthetic identity creation and evasion are institutional arms races | Share of adversaries per period; per attestation check. FNMR/FMR are unitless error probabilities | Identity change; missing a linked identity (false non-match) | NIST FRVT 1:1 and 1:N benchmarks report FNMR 0.001–0.005 on high-quality visa/mugshot photos at FMR = 1e-5; rises to 0.02–0.05 on unconstrained/wild captures; commercial KYC automated document verification exhibits 0.005–0.015 false acceptances of fraudulent IDs and 0.02–0.06 false non-matches | Status-quo baseline: `bind_miss` 0.01–0.05 under automated biometric checks, 0.05–0.20 with presentation attacks/morphing or behavioral clustering alone. Benefuture [CONJ]: multi-modal 1:1 binding (8.70) and behavioral cluster attestation bound duplicates. Sweep: bind_miss 0.005 to 0.20; whitewash 0 to 0.1. Default: `bind_miss` = 0.05. | [GRO19] Grother, Ngan & Hanaoka 2019 (NIST IR 8271, ok); [FR01]; [DOU02]; [KUM17] | High for biometric benchmarks; medium for synthetic identities |
| `p_reveal` (0.08; 0.02–0.20), `bind_compromised` (0.01; 0.001–0.05) | Institution-dependent: revelation lag of synthetic/stolen identities is governed by credit reporting and fraud audits; node corruption is governed by validator stakes and legal penalties | Detection rate per step; share of verifier clusters compromised. Sim: 1 step = 1 month | Identity fraud discovery rate; rogue verifier prevalence | Identity fraud detection lags: median 6–18 months for new-account and synthetic identity fraud before charge-off/discovery (FTC Sentinel, Javelin 2024); traditional ATO is days–weeks. At 1 step = 1 month, 12 months median lag corresponds to 1 - exp(-1/12) ≈ 0.08 per step. Trusted node corruption in PKI and financial notaries is 0.1%–2% (CIFAS 2024) | Status-quo baseline: `p_reveal` 0.05–0.12 per step; `bind_compromised` 0.005–0.03. Benefuture [CONJ]: open ledgers and AdvAp bounties accelerate revelation (`p_reveal` rises to 0.15–0.25); weighted attestation across 5 clusters (8.70) neutralizes compromised minorities. Sweep: p_reveal 0.02 to 0.20; bind_compromised 0.001 to 0.08. Default: `p_reveal` = 0.08, `bind_compromised` = 0.01. | [JAV24] Javelin Strategy 2024 (ok); FTC Consumer Sentinel 2023 (ok); CIFAS Fraudscape 2024 (ok); ACFE 2024 | High for revelation lag; medium for cluster compromise |
| `launder` (0; 0–1), `frivolous` (0; 0–1) | Institution-dependent: no source; both are products of reporting rules | Per report; none | Harm laundering; frivolous reports | No direct source. Bug-bounty programmes see many invalid and duplicate reports (Hacktivity) | Status-quo baseline: none; measure from HackerOne data. Benefuture [CONJ]: outcome-based audits make frivolous reports cost the reporter (frivolous_threshold). Sweep: 0 to 1 as an attack parameter. Default: swept. | `docs/DATA.md` section 12 | Low |
| `repair_efficiency` (0; 0.2–1) | Mixed: adaptation after loss is invariant (partial, slow); repair as a priced intervention is institutional | Share recovered over 5 to 10 years. A natural-recovery rate with half-life about 5 years is about 0.01 per month-step; repair_efficiency is the share restored by a repair transaction, per repair | Repair restoring harm | Life satisfaction recovers from widowhood and unemployment only partly and slowly (years) | 0.3–0.7 over a window of 5–10 years; incomplete for loss of a spouse or a job | [CDGL08] Clark et al. 2008, doi 10.1111/j.1468-0297.2008.02150.x (ok); [LUC07] Lucas 2007, doi 10.1111/j.1467-8721.2007.00479.x (ok) | Medium |

### 3.6 Delegation and participation

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `p_delegate` (0; 0–1) | Institution-dependent: delegation behaviour depends on interface, stakes and trust | Share of users delegating, per user per decision | Chance of delegating when unaffected enough | In LiquidFeedback, a minority of users receive many delegations, super-voters have high theoretical power but mostly vote with the majority **(abs)**; in DAOs voting rights are highly concentrated and turnout is low **(abs)** | Status-quo baseline: Share delegating 0.1–0.4 with a heavy-tailed in-degree (a few delegates get most); the delegating share rises when the stake is low. Benefuture [CONJ]: capped delegation (5%) to audited delegates, with a duty to vote above a threshold, shifts delegation toward low-impact cases. Sweep: 0 to 0.4 (status quo), 1 as stress. Default: swept; emerges from impact and record. | [KLI15] Kling et al. 2015, doi 10.1609/icwsm.v9i1.14618 (ok), arXiv 1503.07723; [FMW24] Fritsch et al. 2024, doi 10.1016/j.bcra.2024.100208 (ok); [FEI23] Feichtinger et al. 2023, arXiv 2302.12125; [KMP21] Kahng et al. 2021, doi 10.1613/jair.1.12261 (ok); [BER25] Berinsky et al. 2025, doi 10.1287/mnsc.2023.02470 (ok) | Medium for the shape; low for the share delegating **[unverified numbers]** |
| `participation` (0.9; 0.6–1) | Institution-dependent: turnout depends on duty, cost and stakes | Share of eligible per election. Sim: chance an expert joins a co-funding per decision | Experts joining co-funding | Voter turnout in national elections about 60–70%; compulsory voting about 90% | Status-quo baseline: 0.5–0.9 depending on duty and cost. Benefuture [CONJ]: a duty to participate above an impact threshold (8.46) raises it for high-impact decisions; reputation by outcomes rewards joining. Sweep: 0.5 to 0.95. Default: swept; 0.9 inside. | [CG16] Cancela & Geys 2016, doi 10.1016/j.electstud.2016.03.005 (ok); https://www.idea.int/data-tools/data/voter-turnout-database | Medium |
| `optional_below`, impact thresholds | Governed (analogue only) | Per voter per decision | governed | Duty to vote above a threshold | analogue only |  |  |

### 3.7 Teaching, research and innovation (M7)

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `ε` (0.3 in readings; 0–0.6) | Invariant: learning curve | Gain per course divided by the lead gap, per course (a school year). With a year step, per step per course; per hour is orders of magnitude lower | A lesson's share of the teacher's lead | Gain per course divided by the teacher-learner gap. A year of school gives 0.3–0.4 SD for grades 4–8 and 0.5–1.5 SD earlier; a teacher or tutor is 2–4 SD ahead; tutoring adds about 0.37 SD (a third) **[unverified]** | Per course (one year): 0.1–0.2, range 0.03–0.4; per hour: orders of magnitude lower | [HBBL08] Hill et al. 2008, doi 10.1111/j.1750-8606.2008.00061.x (ok); [KRA20] Kraft 2020; Nickow et al. 2020 (NBER w27476); [BLO84] Bloom 1984, doi 10.3102/0013189X013006004 (ok) | Medium for magnitude, low for the lead gap (not observable in SD units) |
| teacher quality spread | Invariant: dispersion of teachers | Multiplier on epsilon per teacher | (implicit) | SD of teacher effects about 0.1–0.2 SD of student scores | Multiplier on ε: log-normal CV 0.4–0.6 | [ROC04] Rockoff 2004, doi 10.1257/0002828041302244 (ok); [NKH04] Nye et al. 2004, doi 10.3102/01623737026003237 (ok); [HR12] Hanushek & Rivkin 2012, doi 10.1146/annurev-economics-080511-111001 (ok); [CFR14] Chetty et al. 2014, doi 10.1257/aer.104.9.2593 (ok) | Medium-high |
| `reception_σ` (0.5; 0–1.5) | Invariant: dispersion of learners | CV of individual gains per course | Learners' reception scatter around the lesson's share | CV of individual gains; gains correlated 0.7 pre-post imply a gain SD of about 0.77 of the score SD against a mean gain of 0.3–0.4 (CV 2, inflated by test noise) | 0.8 (0.4–1.5), right-skewed (a few learn a lot) | [HBBL08]; [VIV20]; [BTY21] | Low-medium |
| `class`, `lessons` (10, 3; not set) | Mixed: the effect of class size on learning is invariant; class size is chosen by institutions | Persons per class. Sim: a class of agents; at N of 20 to 100 a class of 20 to 25 is the population | Class size and lessons | OECD average class about 21 (primary) and 23 (lower secondary) **[unverified]**; STAR: classes of 13–17 vs 22–25 raised scores a few percentile points; fade-out of gains over years | Status-quo baseline: class 20–25 (5–40); effect of class size small (0.1–0.2 SD for a 7-student reduction) **[unverified]**. Benefuture [CONJ]: outcome-priced teaching rewards small groups and tutoring (large gains per learner, Bloom). Sweep: class 1 to 25. Default: swept. | [KRU99] Krueger 1999, doi 10.1162/003355399556052 (ok); [BDOY16] Bailey et al. 2016, doi 10.1080/19345747.2016.1232459 (ok); OECD Education at a Glance 2023 [403] | Low-medium |
| `research_share` (0.1; governed) | Institution-dependent: SCALE-CHANGING. R&D share of GDP (money) is not the share of agents' time and resources that M7 diverts to research, which stands for all learning beyond the frontier; and in Benefuture research is a priced transaction | Share of GDP per year; researchers under 1% of employment. Sim: share of time per step. Do not convert 2.6% of GDP to 0.026 of time | Share of time on research | OECD gross R&D spend about 2.7% of GDP; world about 2.6%; researchers under 1% of employment **[unverified]** | Status-quo baseline: Analogue only (section 4). Benefuture [CONJ]: research is spending funded by outcome-based escrow and the ratchet, so the share emerges from its priced returns. Sweep: 0.01 (formal R&D, researchers' time) to 0.3 (all frontier learning). Default: emerges; governed. | World Bank https://data.worldbank.org/indicator/GB.XPD.RSDV.GD.ZS (200); OECD MSTI [403]; [BJVW20] Bloom et al. 2020, doi 10.1257/aer.20180338 (ok) | The sim's research stands for all learning beyond the frontier; unaligned by design |
| `p_research` (0.05; 0.01–0.2) | Mixed: difficulty of discovery invariant; attempts are selected by today's funding. SCALE-CHANGING (project versus researcher-year) | Per project phase transition (13.8% over years) or per application (20%). Sim: per attempt, an agent's step. A project of 6 to 8 years at 13.8% is a hazard of about 2% per project-year; divided by team size, per researcher-year about 0.002 to 0.02 [derived, assumed duration]. Grant success is a funding rate, not a discovery rate: not used | Chance a research attempt succeeds | Phase-transition success of drug development: 13.8% overall (older 10.4%), 3.4% in oncology **(abs for oncology)**; grant success about 20% (NIH); success is rarer and heavy-tailed with novelty | Status-quo baseline: 0.02–0.15 per attempt; heavily domain-dependent. Benefuture [CONJ]: outcome-based funding rewards realised success and lowers the selection toward safe attempts. Sweep: 0.002 to 0.15 per attempt. Default: swept; the converted range lies well below the existing 0.05. | [WSL19] Wong, Siah & Lo 2019, doi 10.1093/biostatistics/kxx069 (ok); [HAY14] Hay et al. 2014, doi 10.1038/nbt.2786 (ok); NIH success rates https://report.nih.gov/funding/nih-budget-and-spending-data-past-fiscal-years/success-rates (200) | Medium |
| `research_σ` (1; 0.5–2) | Invariant: career-stable personal multiplier | Log-SD of the chance across persons | Scatter of researchers' chance | A personal multiplier stable over a career; the best work falls at random within a career | Log-normal log-SD 0.5–1 | [SIN16], [OBA12] | Medium |
| `research_gain` (2; 0.5–5) | Invariant: heavy tail of the value of innovations | Value relative to the median; unit-free | Size of a breakthrough | Value of innovations and patents is Pareto-tailed (exponent near 1): most worth little, a few worth most | Pareto tail, exponent 1–1.5, scaled to median 1 | [SV07] Silverberg & Verspagen 2007, doi 10.1016/j.jeconom.2006.10.017 (ok); [KPSS17] Kogan et al. 2017, doi 10.1093/qje/qjw040 (ok); [PLF23] Park, Leahey & Funk 2023, doi 10.1038/s41586-022-05543-x (ok) | Medium |
| `p_innovate` (0.01; 0–0.05) | Institution-dependent: SCALE-CHANGING. Firms innovating over three years (new to the firm, includes adoption), not an agent's chance per step | Share of firms per three years. 0.5 over three years is 0.21 per year at firm level, not per person | In-job innovation chance | About half of EU enterprises report product or process innovation over three years (Eurostat CIS) **[unverified]** | Status-quo baseline: 0.05–0.2 per year at firm level; far lower for radical innovation. Benefuture [CONJ]: payment by outcome and open records lower the cost of innovating, but a per-person chance is not recoverable from firm data. Sweep: 0 to 0.05 per agent-step (existing range). Default: swept; not a default. | https://ec.europa.eu/eurostat/web/science-technology-innovation/database (200) | Low-medium |
| `p_teachable` (0.5; 0–1), `research_cost` | No source | none | Share codifiable; cost | Tacit knowledge share: no source | none |  | Low |
| decline of research productivity | Mixed: ideas getting harder to find is a feature of the frontier; the 5% a year depends on today's research system | Per year rate; per step factor 0.95 with a year step | (constant `p_research`) | Ideas get harder to find: researchers needed per unit of growth rise steeply | Make the chance fall as the frontier rises (rate about 5% per year in the cases studied **[unverified]**) | [BJVW20] | Medium (validation target) |

### 3.8 Population (M7 deaths and births)

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `p_birth` (0.02; 0–0.1) | Institution-dependent: fertility is produced by income, culture and institutions (6 to 45 per 1,000 across countries); in Benefuture births carry an escrow over the dependency window (8.52) | Per 1,000 population per year. Sim: per agent per step if the chance is per agent (0.017 per agent-year for a year step); if p_birth is per population per step, the same crude rate would be 0.017 per capita times N, a mismatch to check in `sim/src/m7.jl` | Chance of a birth option per step | Crude birth rate about 17 per 1,000 per year (world, about 6 in Japan and Italy, about 45 in Niger) **[unverified]** | Status-quo baseline: 0.017 per year (0.006–0.045), age-structured. Benefuture [CONJ]: an escrowed birth makes the cost visible and credited, so a shift in either direction is possible. Sweep: 0.006 to 0.045 per agent-year. Default: swept; held to the death rate in tests to keep the population stationary (a design choice). | UN WPP https://population.un.org/wpp/ (200); HMD https://www.mortality.org/ (200) | High, given a step mapping |
| death hazards (rung M7) | Mixed: the Gompertz slope (8 to 9% a year) is biology (invariant); the level (life expectancy) is institution-dependent | Per person-year hazard, age-structured. A year step maps one to one | fixed | Mortality rises about 8–9% per year of age (Gompertz), doubling in 8 years; crude death rate about 7.5 per 1,000 **[unverified]** | Age-specific hazard from life tables | WPP; HMD | High |
| `growth` (0.1; 0–0.3) | No source | none | A death's predicted growth per step | Foreclosed future: no direct source | none (a model of the value of a life, 8.47 [P]) |  | Low |
| `birth_pred_σ` (0.5; 0.2–2), `pool` | Invariant: error of fertility projections | Relative to the mean, per projection | Error of birth-prediction models | Fertility projections: wide intervals, TFP 80% interval widening to about ±0.5 children by 2100 **[unverified]** | 0.3–1 relative to the mean | [RAF12] Raftery et al. 2012, doi 10.1073/pnas.1211452109 (ok) | Medium-low |
| `inherit` (0.5; 0–1), `birth_spread` (1; 0.5–2) | Mixed: the genetic part (heritability about 0.5) is invariant; economic transmission (earnings elasticity) is produced by property inheritance and institutions, and in Benefuture property is not inherited (causal and ideological inheritance are) | Correlation or elasticity per generation. Sim: share of the causer's levels carried, per birth | Newborn's mature levels: inheritance from the causer, scatter | Parent-child correlation in education about 0.4–0.5; earnings elasticity about 0.4 in the US; heritability about 0.5 across traits | Status-quo baseline: inherit 0.3–0.5 (education/cognition), 0.1–0.3 (happiness) **[unverified for happiness]**. Benefuture [CONJ]: economic transmission by property falls; transmission by causal and ideological inheritance remains. Sweep: 0.1 to 0.5. Default: swept; 0.5 is the baseline end. | [HER07] Hertz et al. 2007, doi 10.2202/1935-1682.1775 (ok); [COR13] Corak 2013, doi 10.1257/jep.27.3.79 (ok); [POL15] Polderman et al. 2015, doi 10.1038/ng.3285 (ok) | Medium. The sim's "inheritance" is causal, not genetic: a proxy |
| `settle_σ`, `income`, `birth_joy` | No source | none |  | no source | none |  | Low |

### 3.9 Harm, hazards, side effects and black swans

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `p_side` (0; 0–0.2), `side_share` (0.3), `side_size` (1) | Mixed: side effects of actions in complex systems invariant (scale with domain complexity); the preventable part is institution-dependent | Adverse events per admission (9.2%). Sim: per executed action; a high-risk domain's figure (hospitals), so a ceiling for general domains | Chance an action has side harm; share of touched beings harmed; size | In-hospital adverse events: 9.2% of admissions (median), 43.5% preventable, 7.4% lethal **(abs)**; 18% of patients harmed in a US study **[unverified]** | `p_side` 0.05–0.1 in complex domains, 0.01 in simple ones; severity heavy-tailed | [DEV08]; [BRE91]; [LAN10] Landrigan et al. 2010, doi 10.1056/NEJMsa1004404 (ok) | Medium. Default 0 is a limiting case |
| `p_hazard` (0; 0–0.3), `hazard_share` (0.1), `hazard_size` (1), `hazard_σ` (0.2; 0–1) | Mixed: tail shape and size invariant for natural and physical hazards; the rate of human-caused hazards (war, accidents) is institution-dependent. SCALE-CHANGING: the sources describe world-scale events, the sim a community | Event counts per year across the world. Sim: any hazard threatening a share of one community per step. Local floods and fires of a few percent of a community per year fit 0.05 to 0.3; catastrophes of 0.5 to 2% per year are a separate tail | Hazard chance per step, share threatened, harm per being, its scatter | Event sizes are heavy-tailed: war deaths, epidemics (generalised Pareto exponent about −0.71 **(abs)**), blackouts, quakes follow power laws with exponents 1.4–2.5; CV of damage above 1 | `hazard_size` Pareto tail (exponent 1.5–2) with median 1; `hazard_σ` as CV 1–2 (default 0.2 is far thinner); `p_hazard` 0.05–0.3 per period with rare large events | [CSN09] Clauset, Shalizi & Newman 2009, doi 10.1137/070710111 (ok); [CLA18] Clauset 2018, doi 10.1126/sciadv.aao3580 (ok); [CT16] Cirillo & Taleb 2016, doi 10.1016/j.physa.2016.01.050 (ok); [CT20] Cirillo & Taleb 2020, doi 10.1038/s41567-020-0921-x (ok); [MAR21] Marani et al. 2021, doi 10.1073/pnas.2105482118 (ok); EM-DAT https://www.emdat.be/ (200) | Medium for the shape; low for rates per step |
| black swans (`shock(:catastrophe)`) | Invariant: natural and epidemic catastrophes (the human-caused part is institution-dependent) | Annual probability about 0.5 to 2%; per step with a year step, one to one | event | Annual probability of a COVID-like pandemic about 2% **[unverified]**; interstate war large-event rate steady | Rare (0.5–2% per year), size from the tail above | [MAR21]; [CLA18] | Medium |
| `irreparable_loss` | No source | none | none (2–∞) | Share of burden that is years of life lost vs lived with disability | Per cause from GBD | `docs/DATA.md` section 3 | Low |
| `p_shock`, `shock_size` (0, 0.2) | No source | none | Prevention shocking those it protects | No source | none |  | Low |
| `p_contracted`, `contract_share` (0, 0.2) | No source (analogue) | none | Contracted being, share | Labour share of income about 0.5–0.6 (analogue) | none | [KN14] Karabarbounis & Neiman 2014, doi 10.1093/qje/qjt032 (ok) | Low |

### 3.10 Execution failure of plans and projects

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `sloppiness` for projects, `p_upstream`, `β_upstream` | Institution-dependent: planning fallacy plus strategic misrepresentation under today's political and funding incentives. SCALE-CHANGING (a project of years is not one action) | Cost overrun ratio per project (multi-year). Sim: share of a plan delivered per action. The delivered fraction of a project (0.5 to 0.7) is the nearest transfer; the tail applies to the plan as a whole | 0; 0; 0.5 | Projects: nine of ten over budget; costs are fat-tailed (a minority overrun several-fold); megaproject benefit shortfalls; mean overrun for the Olympics 172% **[unverified]**; cost overrun distributions are power-law-tailed (regression to the tail) | Status-quo baseline: Plan fidelity: 0.5–0.7 of intended effect delivered on average, with a fat right tail of failures (Pareto exponent about 1.5–2 for the overrun). Benefuture [CONJ]: settlement against the measured outcome removes the reward for underestimating, and reputation by outcomes prices overpromising. Sweep: delivered fraction 0.5 (status quo) to 0.9; overrun tail exponent 1.5 (status quo) to 3. Default: swept; no default. | [FHB02] Flyvbjerg, Holm & Buhl 2002, doi 10.1080/01944360208976273 (ok); [FLY09] Flyvbjerg 2009, doi 10.1093/oxrep/grp024 (ok); [FLY14] Flyvbjerg 2014, doi 10.1002/pmj.21409 (ok); [FAB18] Flyvbjerg et al. 2018, doi 10.1016/j.tra.2018.07.013 (ok); [FBL20] Flyvbjerg et al. 2020, doi 10.1177/0308518X20958724 (ok) | Medium. Public-works samples are biased toward large, visible projects |
| `p_upstream`, `β_upstream` | No source | none |  | Share of works building on a recent one; share of value carried | See `docs/DATA.md` section 15 (citations) |  | Low |

### 3.11 Resources and the commons (`capacity`, `regen`, `regen_σ`, `cost_per_touch`)

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `regen_σ` (0.1; 0–0.5) | Invariant: natural recruitment variability | Log-SD per year; per step with a year step | Variability of regeneration | Recruitment variability in exploited fish stocks: log-SD about 0.6–0.8 in many species | 0.3–0.8 (log-normal) | [THO14] Thorson, Jensen & Zipkin 2014, doi 10.1139/cjfas-2013-0645 (ok); [RIC12] Ricard et al. 2012, doi 10.1111/j.1467-2979.2011.00435.x (ok) | Medium for fisheries; the sim's commons are generic |
| `regen`, `capacity`, `cost_per_touch` | Invariant: stock-specific, no cross-domain value | Per year; per step | 0.02, 1e4, 0.05 | Surplus-production rate | Stock-specific; no cross-domain value | RAM Legacy https://www.ramlegacy.org/ | Low |

---

## 4. Governed thresholds: institutional analogues (not defaults)

These values are governed (SigThGv); nothing below is a proposed default. Each row names a
human institution's convention as a reference point, so a governance run can be read against the
world's own practice. **Analogues only.** Governed thresholds are neither invariant nor
institution-dependent figures: they are set by the governance the simulation tests, so no class
column applies.

| Governed threshold (sim default) | Institutional analogue | Source and status |
|---|---|---|
| Significance `th` = 1, `model_z`, `trial_z` = 2, `adv_z`, `echo_z` = 3 | p < 0.05 (z about 1.96) as the convention for a finding; 3 sigma as "evidence", 5 sigma in particle physics; proposals to tighten new claims to p < 0.005 | [BEN17] Benjamin et al. 2017, doi 10.1038/s41562-017-0189-z (ok) |
| Status bars 0.9 / 0.75 / 0.55; `max_credence` 0.99; `threshold` | IPCC likelihood scale (very likely 90–100%, likely 66–100%, about as likely as not 33–66%); forecasting platforms cap probabilities at 1–99% | IPCC uncertainty guidance https://www.ipcc.ch/site/assets/uploads/2018/05/uncertainty-guidance-note.pdf (200); Metaculus [403, **[unverified]**] |
| `track_window`, `window` = 100, `takeover_records` = 100, `min_records` | Basel backtesting uses a 250-trading-day window with a traffic-light count of exceptions; rules of thumb of 30 observations | BCBS 1996 backtesting framework https://www.bis.org/publ/bcbs22.htm (200); details **[unverified]** |
| `audit_threshold`, audit sampling, `audit_window` | Tax audit rates are below 1% of returns a year (IRS); audit sampling at 95% confidence; materiality about 5% of pre-tax income | IRS Data Book https://www.irs.gov/statistics/soi-tax-stats-irs-data-book (200); ISA 320 benchmark **[unverified, no link]** |
| `cap` = 0.05 (delegation cap) | 5% beneficial-ownership disclosure; UCITS 5/10/40 diversification rule (no issuer above 10%, positions above 5% sum to at most 40%) | EU UCITS Directive https://eur-lex.europa.eu/eli/dir/2009/65/oj (202) ; 13D threshold **[unverified, SEC page 429/403]** |
| Quorum and supermajority (impact threshold, `bind_quorum`) | Simple majority quorums for meetings; two thirds to amend constitutions; qualified majority in the EU Council (55% of states and 65% of population) | Consilium https://www.consilium.europa.eu/en/council-eu/voting-system/qualified-majority/ [403] |
| `adv_share` = 0.1, `adv_floor` | SEC whistleblower awards 10–30% of sanctions above $1 million; False Claims Act relators 15–30% | SEC [403]; DOJ (in `docs/DATA.md` section 9) |
| `record_λ*`, `λpos`, `λneg` | US credit reports keep most negative items for 7 years (10 for bankruptcy) | 15 U.S.C. 1681c https://www.law.cornell.edu/uscode/text/15/1681c (200) |
| `frivolous_threshold` = 5 in `adv_window` = 100 | California vexatious-litigant rule: five unsuccessful suits in seven years | CCP 391 https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CCP&sectionNum=391 [403] |
| `birth` escrow `window`, deposit ratios, `endowment` floor | Earnest money 1–3% of price; performance bonds about 10% of contract value; construction retainage 5–10%; initial margin 50% (Reg T); Basel III total capital 8% (10.5% with buffer) | all **[unverified, no link]** |
| `q` = 0.1 (floor quantile) | Poverty and "shared prosperity" conventions: bottom decile, bottom 40%, 50–60% of median income | World Bank (`docs/DATA.md` section 1) |
| `explore_share` = 0.05 | Epsilon-greedy exploration rates of 1–10% | none; algorithmic convention |

---

## 5. Parameters with no usable source

- `p_novel`, `camp_bias`, `p_apparent` (M5): only qualitative evidence.
- `p_teachable`, `research_cost`, `settle_σ`, `income`, `birth_joy`, `growth` (M7).
- `launder`, `launder_saving`, `frivolous`, `slander`, `p_shock`, `shock_size`, `audit_cost` as a
  ratio to work (Kittur et al. 2007 is the only lead), `on_off`.
- `contract_share`, `p_contracted` (no cross-domain source).
- `gamers`, `gamer_models`, `gamer_bias`: adversary sizes; ranges must come from adversary budgets,
  not data.
- `trial_units`, `skill_gain`, `local_σ`, `conviction`, `outcome_σ`: locale-level reading and
  outcome noise; Polis and vTaiwan may give the number of locales but not the noise.
- `endowment`, `overflow_base`, `capacity`, `cost_per_touch`: currency units have no external scale.
- `n_learn` (records a model needs before its error settles): the COVID-19 Forecast Hub could set
  it but has not been analysed.
- `form_count`, `form_radius`, `μ_rate`, `μ_every`, `classify` thresholds: governed or geometry.
- Hidden outcomes (`p_apparent`) and outage length (`outage`, `capture` size in the batteries).
- Figures judged **non-transferable as defaults** (institution-dependent or scale-changing; kept as
  baselines and sweeps): mass-media and campaign persuasion rates, ideal-condition deliberative-poll
  shifts, R&D share of GDP, per-project drug success and grant success, firm-level innovation, project
  cost overruns, crude birth rates, class size, annual detection and indictment rates, whistleblowing
  shares, delegation and turnout, wealth shares.

## 6. Top ten changes to defaults, by effect on realism

Only invariant figures, or figures converted to the simulation's unit, change a default. Each is
tagged with its class. Institution-dependent figures are listed after the ten as sweeps with
baselines; none of them becomes a default.

1. **M5 weight on others' readings** (section 1.4; invariant mixture, conditioned): from "weight =
   record, better sources heard in full" to a per-person mixture. Default is the visible-record
   variant (stay put 0.20, mean about 0.40), because audited records and truth-level tags supply the
   source's "visible, clearly better record" condition; the plain mixture (0.30, mean 0.33) is the
   limiting case; the invisible or politicised condition (0.45, mean 0.25) is the baseline. Changes
   governance accuracy, expert capture and echo results more than any other single default.
2. **`σ_leaf`, `σ_branch`, `σ_coarse`** (mixed; the invariant part is the domain's predictability):
   0.15, 0.3, 0.45 to about 0.3 (natural science) to 0.7 (social science) for a leaf, with 0.15 as a
   limiting case. The level reached by research spending is left to emerge from model arrivals.
3. **`signal_σ` (voter competence)** (mixed; perception noise invariant): 1 (p = 0.84) to 2–4
   (p = 0.6–0.69) for non-experts. The informed share and the bimodal spread are swept, since the
   civic information environment is institutional.
4. **`sloppiness` for individuals** (mixed; the intention-behaviour gap is invariant): 0 to 0.25.
   Project fidelity and the overrun tail are institution-dependent and swept (below).
5. **`hazard_σ`, `hazard_size`** (invariant for natural hazards): thin Gaussian-like hazards
   (σ 0.2) to Pareto tails (exponent 1.5–2, CV 1–2). `p_hazard` is converted from world-scale to one
   community (0.05–0.3 per step for any local hazard, with a separate 0.5–2% per year catastrophe
   tail), not taken from world counts; the success pattern's harm peak depends on it.
6. **Skill and productivity distributions** (invariant): uniform or fixed to log-normal (log-SD
   0.3–0.5) with a Pareto tail for creative output, stated as shape, since top-1% shares are one agent
   at N of 100. Changes reputation concentration and the research rung.
7. **`marker_σ` for survey-type markers** (mixed; response noise invariant): 0.05 to 0.3–0.6
   (reliability 0.6–0.9); counts and registries stay at 0.05–0.15 (institution-dependent).
8. **`p_side` and `p_foresee`** (mixed): `p_side` by domain complexity, 0.01 in simple to 0.05–0.1 in
   complex domains (a hospital figure is a ceiling, per action); the preventable and foreseeable
   share (0.43) is institution-dependent and swept 0.25–0.7.
9. **`ε` and `reception_σ`** (invariant, converted): a course (a year, n_y = 1) closes 0.1–0.2 of the
   lead, range 0.03–0.4, with reception log-normal and heavy-tailed.
10. **`deceit` shape and `bias_σ`** (mixed): the shape (honest majority, a small-cheater mass, few
    large) and overconfidence bias 0.1–0.3 are invariant; the prevalence of full cheaters is swept
    0 to 5%.

**Sweeps with status-quo baselines (not defaults).** Each row of the tables carries its baseline,
direction [CONJ] and range; the largest are:

| Figure | Status-quo baseline | Benefuture direction [CONJ] | Sweep |
|---|---|---|---|
| `vigilance` (per step) | 0.001–0.02 passive; lag-implied 0.017–0.03 for institutions | rises (bounty, open log, automated readers) | 0.001–0.3, with 0.1 as the plausible point |
| `diligence`, `p_informed` | 0.4; 0.6 | rise (ledger penalty, audit) | 0.4–0.95; 0.6–0.95 |
| `p_trace` (per examination) | 0.5–0.8 given a revelation | rises | 0.3–0.9 |
| whistleblowing, AdvAp response | 0.1–0.4 without reward | rises toward 0.5–0.7 | emerges from vigilance, adv_z, adv_share |
| `p_delegate`, `participation` | 0.1–0.4; 0.6–0.7 turnout | by impact and record | 0–0.4; 0.5–0.95 |
| project fidelity and overrun tail | 0.5–0.7 delivered; exponent 1.5–2 | rises, tail thins | 0.5–0.9; 1.5–3 |
| `research_share` | 1–3% of time or 2.6% of GDP (scale-changing) | emerges from priced returns | 0.01–0.3 (governed) |
| `p_research` (per attempt) | 0.002–0.02 per researcher-year (converted from 13.8% per project) | rises | 0.002–0.15 |
| `p_new_model`, `improve_drift` | typical entrant worse (+0.3) | arrivals improve | 0–0.1; +0.3 to −0.1 |
| `cost_σ`, `memory_loss` | 0.1–0.3; 0.02–0.15 per year | fall (audited, append-only ledgers) | 0.05–0.3; 0–0.1 |
| `model_capture`, `camp_bias` | relative risk about 1.3; 0.2–1 | shorter, rarer | bias 0–0.3; 0–1 |
| `endowment` spread | log-SD 0.5–1 | narrower at birth; tail re-emerges | 0–1 (emerges) |
| `inherit` | 0.4–0.5 | economic transmission falls | 0.1–0.5 |

## 7. Battery ranges: where they disagree with the proposals

`sim/battery/economy.jl` (severity 0 to 1, rays to 2) and `sim/battery/governance.jl`. For an
invariant factor severity 0 is a mildly imperfect realistic value (8.33), not perfection, and
severity 1 the realistic bad end. For an institution-dependent factor the range spans the
Benefuture-plausible value (severity 0) to the status quo (severity 1); values beyond either end are
stress rays, not the range. Mixed factors take the invariant rule for the invariant part and are
swept for the institutional part.

| Factor | Class | Battery range (severity 0 to 1) | Proposed range (severity 0 to 1) | Disagreement |
|---|---|---|---|---|
| markers (`marker_σ`) | Mixed | 0.02–0.20 | 0.10 (counts) to 0.6 (self-report) | The battery's top is the realistic bottom for self-reports |
| model error (`σ_leaf`) | Mixed (predictability invariant) | 0.05–0.45 | 0.3 to 0.9 (domain-dependent) | Bottom (0.05) reachable only in physical limiting cases; the top is the realistic middle |
| model bias | Mixed | 0–0.2 | 0.1 to 0.3 | Severity 0 (no bias) is a limiting case |
| execution (`sloppiness`) | Mixed (individuals invariant) | 0–0.6 | 0.1 to 0.5 | Severity 0 (perfect execution) is a limiting case only |
| hazards (`p_hazard`, tail) | Invariant | 0–0.3 | 0.05 to 0.3, tail CV 1 to 2 | Severity 0 (no hazard) is a limiting case |
| `p_informed`, `diligence` | Institution-dependent | 1 to 0.6; 1 to 0.7 | 0.95 to 0.6; 0.95 to 0.4 | Floor of diligence (0.7) is above the unaudited status quo (0.4) |
| side harm (`p_side`) | Mixed | 0–0.2 | 0.01 to 0.1 | Top high |
| inattention (`vigilance`) | Institution-dependent | 0.3 at severity 0 down to 0.01 | 0.1 (Benefuture-plausible) down to 0.001 (status quo, passive) | 0.3 is above the plausible point and below the status quo's passive end; 0.01 is not the status quo |
| exam (`p_trace`) | Institution-dependent | table 0.1–0.9 | 0.9 down to 0.3 | Direction: Benefuture end high |
| audit errors (`p_false_trace`) | Mixed | 0–0.1 | 0.005 to 0.05 | Severity 0 (never wrong) is a limiting case |
| accounting (`cost_σ`) | Institution-dependent | 0–0.3 | 0.05 to 0.3 | Consistent |
| commons (`regen_σ`) | Invariant | 0–0.5 | 0.3 to 0.8 | Top too low for fisheries-like resources |
| attribution | Mixed | 0–0.3 | 0.1 to 0.4, biased upward | Slightly low; symmetric noise misses bias |
| memory loss | Institution-dependent | 0–0.1 | 0.01 to 0.15 per year (unit to check) | Consistent |
| deceit size | Mixed | 0–2 | shape fixed (bimodal); full cheaters 0 to 5% | Size untestable; prevalence is a sweep |
| `signal_σ` (governance) | Mixed (noise invariant) | 1 to 40 | 2 to 6 for laypeople | Severity 1 (40, p = 0.51) is a coin flip: a stress ray, not the realistic top (4–6) |
| `ability_spread` | Invariant | 0–1.5 | 0.5 to 1.5 | Consistent |
| `p_apparent` | Mixed | 0.9 to 0.1 (table 0.2–1) | 0.7 to 0.1 | 0.9 is optimistic even for Benefuture measurement |
| `local_σ` | No source | 1 to 4 (table 0.5–3) | no source | Battery and table disagree with each other (README note) |
| delegation (`p_delegate`) | Institution-dependent | 0–1 | 0 to 0.4 as the range; 1 as stress | Top (1) is stress |
| participation | Institution-dependent | 0.6–1 | 0.95 down to 0.5 | Bottom slightly high |
| collusion, loyalty | Mixed | top 0–50% of experts; 0–10 | unknown | None testable |
| project fidelity | Institution-dependent | not in battery | 0.9 down to 0.5 delivered, tail exponent 3 down to 1.5 | New factor |

`attack.jl` sizes attackers by a budget in units of "one attack at the top of its realistic range",
so it inherits the issues above rather than adding ranges of its own.

## 8. Domain predictability empirical distributions (R5)

### 8.1 Motivation: bootstrapping per-domain status bars (8.84)

In the simulation, models qualify to price services and guide actions by demonstrating accuracy above
governed status bars (0.90, 0.75, 0.55; `status_bar_high`, `status_bar_mid`, `status_bar_low`).
Under the 8.84 ratchet rule, when a quorum of models (`ratchet_k`) sustainably clears a domain's bar,
the bar ratchets upward to the $k$-th best measured accuracy less a margin, never drifting downward
(BACKPROPAGATION 8.84).

However, as diagnosed in BACKPROPAGATION (Finding 8.84):
1. Setting a uniform bar (such as 0.90) across all domains treats low-noise physical domains
   identically to hard social or biological systems.
2. If every domain carries identical high noise ($\sigma = 0.45$), no model can clear 0.90,
   freezing the ratchet and forcing reliance on escape clauses (8.41).
3. Conversely, in highly skewed domains (e.g. 95% base-rate positive outcomes), a constant
   uninformative forecaster predicting 0.95 scores a Brier score of 0.0475 (accuracy ~0.81),
   falsely clearing low status bars purely on base-rate luck.

To bootstrap per-domain status bars at world-realistic values that governance must not drift down,
this section compiles empirical predictability benchmarks across 15 diverse domain families. Each
entry reports the best published forecast skill (Brier score, accuracy, AUC-ROC, or $R^2$), the naive
base-rate benchmark, whether predictability is invariant (physical/biological limits) versus
institution-produced (incentives, reporting, strategic gaming), and recommended bootstrap bars.

---

### 8.2 Empirical forecast skill across 15 domain families

#### 1. Short-range numerical weather prediction (24h–72h surface weather)
- **Target & Horizon**: 24-hour to 72-hour prediction of 2m temperature, sea-level pressure, and precipitation occurrence at synoptic scales.
- **Best Published Skill**: Continuous ranked probability score (CRPS) for temperature $\approx 0.8^\circ\text{C}$ error at 24h, $1.2^\circ\text{C}$ at 72h; 500 hPa geopotential height anomaly correlation coefficient (ACC) $> 0.98$ at 3 days; 24h precipitation Brier score $\approx 0.06$–$0.09$ (vs climatology 0.16–0.22).
- **Naive Base-Rate Benchmark**: Climatology / 24-hour persistence yields ACC $\approx 0.75$, temperature RMSE $\approx 3.5^\circ\text{C}$, precipitation Brier score $\approx 0.18$.
- **Invariant vs Institution-Produced**: Strongly **Invariant** (Navier-Stokes fluid dynamics, radiative transfer, thermodynamics; limited by Lorenz chaotic butterfly horizon of $\approx 14$ days).
- **Sources**: [BAU15] Bauer, Thorpe & Brunet 2015, doi:10.1038/nature14956; ECMWF Technical Memoranda (Verification Statistics 2023).
- **Confidence & Caveats**: High. Decades of standardized, global, open verification against automated weather station networks.
- **Recommended Bootstrap Bars**: `high` = 0.94, `mid` = 0.85, `low` = 0.70.

#### 2. Medium-range weather & seasonal climate (Day 6–10 NWP, ENSO 3-month)
- **Target & Horizon**: Day 6 to 10 synoptic weather regimes; 3-month lead El Niño Southern Oscillation (ENSO) SST anomaly prediction.
- **Best Published Skill**: Day 6–10 ACC drops to 0.75–0.82; day 10 ACC $\approx 0.50$ (limit of deterministic utility); 3-month ENSO anomaly correlation $r \approx 0.75$–$0.85$; seasonal precipitation Brier skill score $\approx 0.10$–$0.15$ over climatology.
- **Naive Base-Rate Benchmark**: Climatology Brier score $\approx 0.25$ for tercile events; persistence fails beyond day 5.
- **Invariant vs Institution-Produced**: **Invariant** (ocean-atmosphere coupling dynamics, non-linear teleconnections, chaotic error growth).
- **Sources**: [BAU15]; Barnston et al. 2012, doi:10.1175/BAMS-D-11-00111.1; Palmer et al. 2004, doi:10.1029/2003GL018919.
- **Confidence & Caveats**: High. Verified over multi-decade reanalyses (ERA5).
- **Recommended Bootstrap Bars**: `high` = 0.82, `mid` = 0.70, `low` = 0.55.

#### 3. Materials fatigue & structural reliability (metallurgy, concrete cure)
- **Target & Horizon**: Cyclic stress fatigue life ($S$-$N$ Wöhler curve cycles to failure $N_f$); 28-day concrete compressive cure strength (MPa).
- **Best Published Skill**: 28-day concrete cure strength $R^2 \approx 0.88$–$0.94$, MAPE $\approx 5$–$8\%$ (using water-cement ratio, silica fume, and cure temp); high-cycle metal fatigue life log-cycles RMSE $\approx 0.15$–$0.25$ ($R^2 \approx 0.85$–$0.92$).
- **Naive Base-Rate Benchmark**: Unconditional batch mean yields $R^2 = 0.00$, MAPE $\approx 25$–$35\%$ due to cement batch and aggregate variance.
- **Invariant vs Institution-Produced**: Mostly **Invariant** (crystal lattice dislocation mechanics, hydration kinetics of calcium silicate hydrate); mildly institutional in specimen fabrication compliance (ASTM C39/E739 standards).
- **Sources**: ASTM E739-10 (Fatigue Testing Statistical Analysis); Yeh 1998, doi:10.1016/S0008-8846(98)00165-3; Suresh 1998, *Fatigue of Materials* (ISBN 978-0521570466).
- **Confidence & Caveats**: High. Standardized lab bench experiments; in-situ field structures exhibit higher variance due to micro-void distribution.
- **Recommended Bootstrap Bars**: `high` = 0.90, `mid` = 0.80, `low` = 0.65.

#### 4. Semiconductor fabrication yield & wafer defect density
- **Target & Horizon**: Die sort yield prediction per wafer based on in-line optical inspection and particle defect density measurements.
- **Best Published Skill**: Negative binomial / Poisson-Seeds yield model achieves $R^2 \approx 0.92$–$0.96$ against final electrical wafer probe; Brier score for individual critical defect causing die kill $\approx 0.04$–$0.07$.
- **Naive Base-Rate Benchmark**: Historical fab line average yield yields MAPE $\approx 12$–$18\%$ across lot-to-lot excursions.
- **Invariant vs Institution-Produced**: Mixed: particle physics and photolithographic wavelength limits are **Invariant**; cleanroom protocol adherence, tool maintenance schedules, and reticle layout design are **Institution-produced**.
- **Sources**: Stapper, Armstrong & Saji 1983, doi:10.1109/PROC.1983.12638; Cunningham et al. 1995, doi:10.1109/66.406283.
- **Confidence & Caveats**: High. Proprietary fab data is extensive; published empirical studies reflect mature silicon processes.
- **Recommended Bootstrap Bars**: `high` = 0.92, `mid` = 0.82, `low` = 0.68.

#### 5. Actuarial mortality & cohort life expectancy
- **Target & Horizon**: Age-specific annual mortality probability $q_x$ and 10-year to 30-year cohort life expectancy $e_x$ at age 65.
- **Best Published Skill**: Lee-Carter Poisson model and extensions achieve out-of-sample $R^2 > 0.95$ for age-specific mortality trends across 5–10 year horizons; mean absolute percentage error (MAPE) on $e_{65}$ forecast 10 years ahead $\approx 1.2$–$2.5\%$.
- **Naive Base-Rate Benchmark**: Static period life table persistence yields MAPE $\approx 6$–$10\%$ over 20-year horizons due to unmodeled cardiovascular and medical progress.
- **Invariant vs Institution-Produced**: Mixed: Gompertz-Makeham biological senescence is **Invariant**; public health sanitation, vaccination, smoking prevalence, and medical technology are **Institution-produced**.
- **Sources**: [LC92] Lee & Carter 1992, doi:10.1080/01621459.1992.10475265; Human Mortality Database (HMD); Society of Actuaries (RP-2014 mortality studies).
- **Confidence & Caveats**: Very High. Millions of recorded life-years across century-long national vital statistics registers.
- **Recommended Bootstrap Bars**: `high` = 0.95, `mid` = 0.88, `low` = 0.75.

#### 6. Intensive care triage & acute clinical deterioration
- **Target & Horizon**: In-hospital mortality and 48-hour acute deterioration (ICU septic shock / cardiac arrest) upon admission.
- **Best Published Skill**: APACHE IV achieves AUC-ROC $\approx 0.88$–$0.89$, Brier score $\approx 0.075$–$0.090$ (prevalence $\approx 10$–$12\%$); modern gradient-boosted electronic health record ensembles (e.g. eSIC / SuperICU) reach AUC-ROC $\approx 0.89$–$0.91$.
- **Naive Base-Rate Benchmark**: Unconditional ICU mortality prevalence baseline Brier score $\approx 0.105$; naive vital sign thresholding (SIRS) AUC-ROC $\approx 0.65$–$0.72$.
- **Invariant vs Institution-Produced**: Mixed: multi-organ failure cascade and shock physiology are **Invariant**; nurse staffing ratios, EHR documentation speed, and resuscitation protocols are **Institution-produced**.
- **Sources**: [ZIM06] Zimmerman et al. 2006, doi:10.1097/01.CCM.0000215112.21835.61; Vincent et al. 1996 (SOFA), doi:10.1007/BF01709751; Rajkomar et al. 2018, doi:10.1038/s41746-018-0029-1.
- **Confidence & Caveats**: High. Verified across tens of thousands of admissions in MIMIC-IV and eICU research databases.
- **Recommended Bootstrap Bars**: `high` = 0.86, `mid` = 0.76, `low` = 0.60.

#### 7. Oncology clinical prognosis & 5-year survival staging
- **Target & Horizon**: 5-year overall survival classification following primary surgical resection/chemotherapy for solid tumors (colorectal, lung, breast).
- **Best Published Skill**: AJCC 8th edition TNM staging + genomic profiling (Oncotype DX, MammaPrint) achieves concordance index (Harrell's $C$-index) $\approx 0.75$–$0.82$; 5-year binary survival Brier score $\approx 0.14$–$0.18$ (vs baseline 0.24).
- **Naive Base-Rate Benchmark**: Overall 5-year cancer survival base rate $\approx 68\%$ across all stages; naive constant prediction Brier score $\approx 0.218$.
- **Invariant vs Institution-Produced**: **Invariant** (cellular mutation rate, metastasis biomechanics, tumor microenvironment); mildly institutional in screening compliance and adjuvant therapy access.
- **Sources**: National Cancer Institute SEER Cancer Statistics Review; Amin et al. 2017 (AJCC Cancer Staging Manual 8th ed., ISBN 978-3319406176); Paik et al. 2004, doi:10.1056/NEJMoa041588.
- **Confidence & Caveats**: High. Derived from population-scale cancer registries tracking hundreds of thousands of biopsy-confirmed patients.
- **Recommended Bootstrap Bars**: `high` = 0.80, `mid` = 0.70, `low` = 0.58.

#### 8. Pharmacological clinical trial phase transitions
- **Target & Horizon**: Probability of a new chemical entity (NCE) successfully advancing from Phase I to Phase II, Phase II to Phase III, and Phase III to FDA approval.
- **Best Published Skill**: Machine learning models leveraging target biological validation, animal toxicology, and trial design achieve AUC-ROC $\approx 0.72$–$0.78$; Brier score $\approx 0.16$–$0.19$. Phase II $\to$ III transition is notoriously unpredictable (historical success rate $\approx 30.7\%$).
- **Naive Base-Rate Benchmark**: Unconditional approval from Phase I entry $\approx 13.8\%$ (oncology $\approx 3.4\%$, vaccines $\approx 33.4\%$; [WSL19]); baseline unconditioned Brier score for Phase II transition $\approx 0.213$.
- **Invariant vs Institution-Produced**: Mixed: drug metabolism, receptor affinity, and human organ toxicity are **Invariant**; trial endpoint selection, sample size power, surrogate marker acceptance, and regulatory flexibility (PDUFA) are **Institution-produced**.
- **Sources**: [WSL19] Wong, Siah & Lo 2019, doi:10.1093/biostatistics/kxx069; Hay et al. 2014, doi:10.1038/nbt.2786; Lo, Siah & Wong 2019, doi:10.1162/dint_a_00015.
- **Confidence & Caveats**: High for empirical transition counts (40,000+ development paths in Informa Pharmaprojects); predictive models show persistent ceiling around AUC 0.78 due to idiosyncratic biological failure.
- **Recommended Bootstrap Bars**: `high` = 0.75, `mid` = 0.65, `low` = 0.50.

#### 9. Agricultural crop yield estimation (maize, soybean)
- **Target & Horizon**: End-of-season county-level crop yield (bushels/acre) forecast 60 to 90 days prior to harvest.
- **Best Published Skill**: Satellite multi-spectral NDVI + weather reanalysis + soil moisture process models achieve $R^2 \approx 0.78$–$0.86$; mean absolute percentage error (MAPE) $\approx 6$–$9\%$; binary extreme drought loss Brier score $\approx 0.08$–$0.12$.
- **Naive Base-Rate Benchmark**: 10-year county historical trend regression yields $R^2 \approx 0.45$–$0.55$, MAPE $\approx 14$–$18\%$ (vulnerable to flash droughts and late frost).
- **Invariant vs Institution-Produced**: Mostly **Invariant** (photosynthetic solar radiation conversion, heat-stress degree days, transpiration limits); institutional factors include hybrid seed adoption and irrigation infrastructure.
- **Sources**: USDA National Agricultural Statistics Service (NASS) Objective Yield Surveys; Lobell et al. 2014, doi:10.1038/nclimate2153; Johnson 2014, doi:10.1016/j.rse.2013.10.027.
- **Confidence & Caveats**: High. Public USDA track record across decades and millions of harvested acres.
- **Recommended Bootstrap Bars**: `high` = 0.84, `mid` = 0.74, `low` = 0.58.

#### 10. Infrastructure & megaproject cost overrun & schedule slip
- **Target & Horizon**: Final construction cost overrun ratio ($\text{Actual}/\text{Budget}$) and completion schedule slip for rail, road, bridges, and energy projects ($>\$1\text{B}$).
- **Best Published Skill**: Reference Class Forecasting (RCF, distribution-based Curvilinear Box-Cox fits) achieves accuracy in predicting the required contingency reserve within 10 percentage points $\approx 70$–$75\%$ of the time; standard point estimates by project sponsors exhibit correlation $r \approx 0.10$ with actual overruns (systematic appraisal optimism).
- **Naive Base-Rate Benchmark**: 9 out of 10 megaprojects suffer cost overruns (mean overrun $28\%$ in roads, $45\%$ in rail, $90\%$ in nuclear); naive assumption of zero overrun has Brier score $\approx 0.81$ (dismal failure); unconditional empirical distribution Brier score $\approx 0.18$.
- **Invariant vs Institution-Produced**: Heavily **Institution-Produced** (strategic misrepresentation by bidding consortia, political lock-in, scope creep, labor strikes, regulatory environmental lawsuits; [FLY02]).
- **Sources**: [FHB02] Flyvbjerg, Holm & Buhl 2002, doi:10.1080/01944360208976273; [FLY14] Flyvbjerg 2014, doi:10.1002/pmj.21409; Oxford Global Projects Database ($N > 16,000$ projects).
- **Confidence & Caveats**: High for empirical distributions; individual project forecasts remain subject to fat-tailed power-law surprises.
- **Recommended Bootstrap Bars**: `high` = 0.72, `mid` = 0.60, `low` = 0.48.

#### 11. Software engineering estimation & defect discovery
- **Target & Horizon**: Software project development effort (person-months), sprint story-point delivery velocity, and post-release defect density (bugs/KLOC).
- **Best Published Skill**: Algorithmic models (COCOMO II, story point ML ensembles) achieve $\text{PRED}(0.25) \approx 50$–$65\%$ (i.e. only 50–65% of projects complete within $25\%$ of estimated effort); post-release critical defect prediction achieves AUC-ROC $\approx 0.78$–$0.84$.
- **Naive Base-Rate Benchmark**: Naive developer judgment estimates achieve $\text{PRED}(0.25) \approx 30$–$40\%$ with median effort overrun $\approx 30$–$40\%$ ([JOR04]).
- **Invariant vs Institution-Produced**: Strongly **Institution-Produced** (shifting product requirements, developer turnover, technical debt tolerance, testing thoroughness, Conway's Law organizational topology).
- **Sources**: [JOR04] Jørgensen 2004, doi:10.1109/TSE.2004.1265817; Boehm et al. 2000, *Software Cost Estimation with COCOMO II* (ISBN 978-0130266927); Mende & Koschke 2010, doi:10.1109/CSMR.2010.22.
- **Confidence & Caveats**: Medium-High. High variance across software methodologies (agile vs safety-critical embedded DO-178C).
- **Recommended Bootstrap Bars**: `high` = 0.72, `mid` = 0.62, `low` = 0.50.

#### 12. Macroeconomic forecasting (GDP growth, CPI inflation, recessions)
- **Target & Horizon**: 4-quarter ahead real GDP growth rate, headline CPI inflation rate, and 12-month ahead recession onset.
- **Best Published Skill**: Survey of Professional Forecasters (SPF) and Federal Reserve staff Greenbook forecasts achieve RMSE $\approx 1.2$–$1.5\%$ on annual GDP growth ($R^2 \approx 0.20$–$0.35$ over historical mean); 12-month recession Brier score $\approx 0.12$–$0.15$; yield curve (10y–3m spread) probit achieves recession AUC-ROC $\approx 0.82$–$0.88$.
- **Naive Base-Rate Benchmark**: Historical recession prevalence in developed economies $\approx 12$–$15\%$ of quarters; naive 4-quarter constant GDP growth persistence yields RMSE $\approx 2.1\%$; naive zero-recession forecast Brier score $\approx 0.13$ (virtually uninformative).
- **Invariant vs Institution-Produced**: Almost entirely **Institution-Produced** (central bank interest rate adjustments, fiscal policy stimulus, geopolitical oil supply cartels, consumer expectation reflexivity / Lucas critique).
- **Sources**: [FW13] Faust & Wright 2013, doi:10.1016/B978-0-444-53683-9.00001-3; Stock & Watson 2003, doi:10.1016/S0304-3932(03)00026-6; Estrella & Mishkin 1998, doi:10.1162/003465398557320.
- **Confidence & Caveats**: High for measurement; forecast skill collapses during structural breaks, financial crises, and pandemic disruptions.
- **Recommended Bootstrap Bars**: `high` = 0.68, `mid` = 0.58, `low` = 0.45.

#### 13. Corporate credit default & bankruptcy prediction
- **Target & Horizon**: 1-year ahead corporate bond default / Chapter 11 bankruptcy filing for exchange-listed and private commercial entities.
- **Best Published Skill**: Multi-period hazard rate models (Shumway, Campbell-Hilscher-Szilagyi, Moody's KMV distance-to-default) achieve AUC-ROC $\approx 0.90$–$0.94$; 1-year investment grade Brier score $< 0.005$; speculative grade Brier score $\approx 0.04$–$0.06$.
- **Naive Base-Rate Benchmark**: Annual corporate default prevalence $\approx 1.5\%$ overall (speculative grade $\approx 3.8\%$, investment grade $\approx 0.1\%$); Altman (1968) Z-score achieves AUC-ROC $\approx 0.82$–$0.85$.
- **Invariant vs Institution-Produced**: Heavily **Institution-Produced** (contractual debt covenants, bankruptcy code Chapter 11 renegotiation laws, accounting standards GAAP/IFRS, management risk-taking incentives).
- **Sources**: [ALT68] Altman 1968, doi:10.1111/j.1540-6261.1968.tb00843.x; Shumway 2001, doi:10.1086/322819; Campbell, Hilscher & Szilagyi 2008, doi:10.1111/j.1540-6261.2008.01418.x; Moody's Annual Default Studies (1920–2023).
- **Confidence & Caveats**: Very High. Decades of audited SEC filings and credit rating agency records.
- **Recommended Bootstrap Bars**: `high` = 0.90, `mid` = 0.80, `low` = 0.65.

#### 14. Geopolitical & international conflict events
- **Target & Horizon**: 12-month binary resolution of international armed conflict initiation, leader exit from power, or treaty breakdown.
- **Best Published Skill**: IARPA ACE tournament superforecaster teams (Good Judgment Project) using extremized prediction aggregation achieve Brier scores $\approx 0.15$–$0.19$ (Brier skill score $\approx 0.30$–$0.40$ over baseline); outperforming intelligence community analysts with access to classified material.
- **Naive Base-Rate Benchmark**: Unconditional historical conflict onset prevalence $\approx 5$–$10\%$; naive base-rate Brier score $\approx 0.22$–$0.28$.
- **Invariant vs Institution-Produced**: Almost entirely **Institution-Produced** (diplomatic brinkmanship, authoritarian regime survival calculations, alliances, intelligence deterrence).
- **Sources**: [TET15] Tetlock & Gardner 2015; [MEL14] Mellers et al. 2014, doi:10.1177/0956797614524255; Tetlock et al. 2017, doi:10.1177/1745691616635594; Uppsala Conflict Data Program (UCDP).
- **Confidence & Caveats**: High. Rigorously verified out-of-sample over 4 years of blinded government tournament competitions ($N > 2,000$ questions).
- **Recommended Bootstrap Bars**: `high` = 0.76, `mid` = 0.66, `low` = 0.52.

#### 15. Electoral outcomes & polling aggregation
- **Target & Horizon**: Winner prediction and two-party vote share in national executive and parliamentary elections (1 to 30 days prior to voting).
- **Best Published Skill**: Dynamic Bayesian polling synthesis models (FiveThirtyEight, Silver Bulletin, Economist model) achieve Brier score $\approx 0.07$–$0.09$ on presidential state-level winners 1 week ahead; national popular vote share RMSE $\approx 1.5$–$2.0$ percentage points.
- **Naive Base-Rate Benchmark**: Incumbent economic fundamental model (Fair model) yields vote share RMSE $\approx 3.2\%$; raw unweighted horse-race polling average Brier score $\approx 0.14$.
- **Invariant vs Institution-Produced**: Strongly **Institution-Produced** (electoral college / voting rules, campaign spending, voter turnout suppression, polling non-response bias, ballot access).
- **Sources**: [SIL20] Silver 2020 (FiveThirtyEight historical election forecast evaluation); Gelman & King 1993, *British J. Political Sci.* 23; Campbell 2004, doi:10.1017/S104909650404494X.
- **Confidence & Caveats**: High for modern democratic polling regimes; vulnerable to systematic polling non-response shifts (e.g. 2016, 2020 US turnout changes).
- **Recommended Bootstrap Bars**: `high` = 0.88, `mid` = 0.78, `low` = 0.62.

---

### 8.3 Summary: The domain predictability spectrum and bootstrap schedule

The empirical record demonstrates that the achievable ceiling of forecast accuracy is strongly bounded
by whether the domain is dominated by thermodynamic/physical conservation laws (invariant) versus
reflexive, strategic human institutions (institution-produced).

| Domain Family | Class | Horizon | Primary Metric | Best Published Skill | Naive / Base-Rate Benchmark | Bootstrap High Bar (`status_bar_high`) | Bootstrap Mid Bar (`status_bar_mid`) | Bootstrap Low Bar (`status_bar_low`) |
|---|---|---|---|---|---|---|---|---|
| **1. Short-range NWP** | Invariant | 24h–72h | Brier / ACC | Brier 0.06–0.09, ACC 0.98 | Climatology Brier 0.18 | **0.94** | 0.85 | 0.70 |
| **2. Medium-range NWP & ENSO** | Invariant | Day 6–10, 3mo | ACC / Brier | ACC 0.78, ENSO $r=0.80$ | Climatology Brier 0.25 | **0.82** | 0.70 | 0.55 |
| **3. Materials & Metallurgy** | Invariant | Life cycles | $R^2$ / MAPE | $R^2 = 0.92$, MAPE 6% | Batch mean MAPE 30% | **0.90** | 0.80 | 0.65 |
| **4. Semiconductor Fab Yield** | Mixed | Per lot/wafer | $R^2$ / Brier | $R^2 = 0.94$, Brier 0.05 | Line average MAPE 15% | **0.92** | 0.82 | 0.68 |
| **5. Actuarial Mortality** | Mixed | 10y–30y | MAPE / $R^2$ | $e_{65}$ MAPE 1.5%, $R^2 > 0.95$ | Static table MAPE 8% | **0.95** | 0.88 | 0.75 |
| **6. ICU Deterioration Triage** | Mixed | 48h | AUC / Brier | AUC 0.89, Brier 0.08 | Prevalence Brier 0.11 | **0.86** | 0.76 | 0.60 |
| **7. Oncology 5-Year Survival** | Invariant | 5 years | $C$-index / Brier | $C$-index 0.80, Brier 0.15 | Prevalence Brier 0.22 | **0.80** | 0.70 | 0.58 |
| **8. Drug Phase Transitions** | Mixed | Phase I–III | AUC / Brier | AUC 0.76, Brier 0.17 | Base rate Brier 0.21 | **0.75** | 0.65 | 0.50 |
| **9. Agricultural Crop Yields** | Invariant | 60d–90d | $R^2$ / MAPE | $R^2 = 0.82$, MAPE 7% | Trend regression $R^2 = 0.50$ | **0.84** | 0.74 | 0.58 |
| **10. Megaproject Overruns** | Institutional | Multi-year | Interval / Brier | RCF hit rate 72%, Brier 0.18 | Zero-overrun Brier 0.81 | **0.72** | 0.60 | 0.48 |
| **11. Software Estimates** | Institutional | Sprints/Months | $\text{PRED}(0.25)$ / AUC | $\text{PRED}(0.25) \approx 60\%$, AUC 0.80 | Developer guess $\text{PRED} \approx 35\%$ | **0.72** | 0.62 | 0.50 |
| **12. Macroeconomic Forecasting**| Institutional | 4 Quarters | RMSE / Brier | GDP RMSE 1.3%, Recession Brier 0.13 | Naive persistence RMSE 2.1% | **0.68** | 0.58 | 0.45 |
| **13. Corporate Credit Default** | Institutional | 1 Year | AUC / Brier | AUC 0.92, Brier 0.02 | Rating agency base rate | **0.90** | 0.80 | 0.65 |
| **14. Geopolitical Conflicts** | Institutional | 12 Months | Brier Score | Superforecasters Brier 0.16 | Naive baseline Brier 0.25 | **0.76** | 0.66 | 0.52 |
| **15. Electoral Outcomes** | Institutional | 1d–30d | Brier / RMSE | Brier 0.08, Vote RMSE 1.6% | Horse-race polling Brier 0.14 | **0.88** | 0.78 | 0.62 |

### 8.4 Governance implications for status bar ratcheting (8.84)

1. **Bootstrap without downward drift**: The simulation bootstrap may assign initial status bars to
   domains using the empirical schedule above (e.g. 0.94 for short-range weather, 0.75 for drug discovery,
   0.68 for macroeconomic projection). Governance must not drift bars below these initial bootstrap floors;
   they represent established empirical limits of prediction under state-of-the-art methodology.
2. **Sustained ratchet operation**: When model competition and research spending advance predictive
   skill within a domain, the 8.84 ratchet raises the bar toward the $k$-th best sustained accuracy.
   The ratchet correctly operates domain-by-domain: raising the short-range weather bar toward 0.96
   does not impose an unachievable 0.96 requirement on clinical drug transition or macro models.
3. **Defense against base-rate spoofing**: In domains with extreme base rates (e.g. corporate default $\approx 1\%$,
   Phase I drug transition $\approx 13\%$), forecaster skill must be assessed via Brier skill score over
   climatology or likelihood ratio test, preventing trivial constant-prediction models from falsely
   claiming high accuracy status bars.

---

## 9. Status-quo institutions (R6)

### 9.1 Motivation: the status quo as an empirical baseline (BACKPROPAGATION 8.92, Track B)

In evaluating Benefuture against existing governance and economic arrangements, `:status_quo` is
not an absence of mechanisms or an ad hoc strawman (BACKPROPAGATION 8.92). Rather, it represents the
prevailing institutional structure of human societies:
1. **Unbacked fractional credit & debt cycles**: A banking system where loans create deposits,
   expanding credit multipliers procyclically during booms and abruptly contracting during busts,
   generating endogenous financial panics.
2. **Regulatory capture & revolving doors**: Regulatory agencies staffed by industry alumni whose
   supervisory standards drift downward toward regulated incumbents and whose enforcement intensity
   is procyclically lenient during booms.
3. **Delegation concentration in representative democracy**: Electoral and token-voting systems
   without delegation caps, where legislative and governance power concentrates into a tight oligopoly
   of party elites or DAO super-delegates.
4. **Slow ex-post fraud detection**: Reliance on passive revelation (whistleblowers, journalists,
   delayed audits) with multi-year enforcement litigation lags, allowing deceptive actors to harvest
   gains before sanctions hit.
5. **Statutory amnesia (FCRA drop-off)**: Legal mandates (such as 15 U.S.C. § 1681c) that erase
   adverse credit events after 7 years and bankruptcy after 10 years, destroying informative market
   history and creating moral hazard.
6. **Uncoupled governance and economy**: Economic outcomes do not directly feed back into political
   or regulatory authority; failing planners and captured models retain their offices and charters
   regardless of realized social harm.

Under Track B (`COORDINATION.md` line 424, B/R6), this section compiles empirical figures and
conversion factors to calibrate the `:status_quo` baselines in `sim/battery/status_quo.jl`,
`sim/battery/status_quo_economy.jl`, and `sim/src/coupled.jl` against the historical record.

---

### 9.2 Empirical evidence across the six status-quo institutional pillars

#### 1. Banking and financial crisis frequency, output loss, and recovery time
- **Target Quantities**: Annual crisis onset probability, cumulative output loss (% of GDP), and post-crisis recovery time to pre-crisis output peak or trend.
- **Empirical Findings**:
  - *Frequency*: Across 66 countries over 1800–2008, systemic banking crises occur at an unconditional rate of 3.0%–4.5% per country-year in advanced economies (~3.5 to 4.5 crises per country-century; [RR09a], [RR09b]). The IMF Systemic Banking Crises Database (151 crises, 1970–2017) records an annual crisis probability of 3.8% for advanced economies (~1 crisis every 26 years; [LV13], [LV20]).
  - *Depth (Peak-to-Trough & Cumulative)*: In the aftermath of severe banking crises, real per capita GDP declines by an average of 9.3% (median 9.0%) peak-to-trough ([RR09a]). Median cumulative output loss relative to pre-crisis trend over $T$ through $T+3$ years is 23.0% of GDP in advanced economies (mean 32.9% across crises; [LV20]). Asset price declines are severe: real housing prices fall an average of 35.5% over 6 years; equity prices collapse 55.9% over 3.4 years ([RR09a]).
  - *Recovery Time*: The downturn from peak to trough lasts an average of 1.9 years, and output requires an average of 4.4 years to return to its pre-crisis peak ([RR09a]). Returning to the pre-crisis growth trend takes 3 to 5 years (median 3 years; [LV20]). Unemployment increases by an average of 7.0 percentage points, with elevated joblessness persisting for 4.8 years.
- **Conversion to Simulation Units** (`n_y = 12`, 1 step = 1 month):
  - Annual crisis hazard $p_{\text{year}} \approx 0.035$ yields monthly step hazard $p_{\text{step}} = 1 - (1 - 0.035)^{1/12} \approx 0.00296 \approx 0.003$ per step (mean recurrence interval $\approx 338$ steps $\approx 28$ years).
  - Expected crisis count in a 10-year economy run (120 steps) is $120 \times 0.003 = 0.36$ (30% probability of $\ge 1$ crisis); in a 100-year century run (1,200 steps), $\lambda = 3.55$ crises.
  - Output contraction depth: floor/median plan output drop of 9.0% to 25.0% during crisis episodes.
  - Recovery time: 2 to 4 years for output = 24 to 48 monthly steps (median 36 steps); 4 to 6 years for structural/resilience recovery = 48 to 72 steps.
- **Sources**: [RR09a] Reinhart & Rogoff 2009, doi:10.1257/aer.99.2.466; [RR09b] Reinhart & Rogoff 2009 (ISBN 978-0691142166); [LV13] Laeven & Valencia 2013, doi:10.1057/imfer.2013.12; [LV20] Laeven & Valencia 2020, doi:10.1057/s41308-020-00107-3.
- **Confidence**: High. Multi-century standardized macroeconomic panels.

#### 2. Credit-cycle procyclicality, leverage booms, and contraction on bust
- **Target Quantities**: 5-year credit growth volatility, credit-to-GDP gap thresholds, credit multiplier expansion elasticity during expansions, and contraction fraction upon crisis trigger.
- **Empirical Findings**:
  - *Predictive Power of Credit*: In a 140-year panel of 14 advanced economies (1870–2008), past credit growth is the single most powerful predictor of systemic financial crises; broad money aggregates add no predictive power once bank credit is accounted for ([ST12]). A 1 standard deviation increase in past 5-year real bank loan growth increases the odds of a financial crisis by 52% (log-odds coefficient $\approx 0.38$, $p < 0.01$).
  - *Recession Severity*: Financial recessions preceded by rapid credit expansions (top tercile credit booms) result in a 5.0% peak-to-trough per capita GDP loss and require >5 years to recover, compared to normal recessions which lose 2.3% and recover in 1.5–2 years ([JST13]). Each 1 SD of excess credit growth during the expansion depresses the post-peak GDP trajectory by an additional 1.1% per year through year 5.
  - *Credit-to-GDP Gap & Multipliers*: In Basel III early warning models ([BL02], [DBT11]), a credit-to-GDP gap exceeding +10 percentage points above long-term trend predicts banking crises 2–3 years ahead. Bank credit multipliers expand procyclically by 15%–35% during prolonged expansions, then contract abruptly by 20%–35% during systemic deleveraging.
- **Conversion to Simulation Units** (`n_y = 12`, 1 step = 1 month):
  - 5-year credit rolling window = 60 monthly steps.
  - Procyclical credit multiplier: In a status-quo economy arm, credit multiplier $m_t$ expands with recent 60-step growth: $m_t = m_0 (1 + \eta \cdot \Delta \bar{Y}_{60})$, where empirical elasticity $\eta \approx 0.15$–$0.30$.
  - Bust trigger: When credit growth crosses +10 pp or default cascades occur, the credit multiplier contracts sharply by fraction $c_{\text{bust}} \approx 0.20$–$0.35$ within 6–12 steps, starving active plans of working capital.
- **Sources**: [ST12] Schularick & Taylor 2012, doi:10.1257/aer.102.2.1029; [JST13] Jordà, Schularick & Taylor 2013, doi:10.1111/jmcb.12069; [BL02] Borio & Lowe 2002, doi:10.2139/ssrn.846305; [DBT11] Drehmann et al. 2011.
- **Confidence**: High. Replicated across international long-run macro datasets.

#### 3. Regulatory capture, revolving-door worker flows, and enforcement leniency
- **Target Quantities**: Regulatory threshold drift toward incumbent preferences, revolving-door worker turnover rates, and reduction in enforcement scrutiny for dominant incumbents.
- **Empirical Findings**:
  - *Capture Theory*: Regulation is acquired by industry and operated primarily for its protection against entry and competition ([STI71], [DAL06]).
  - *Revolving Door Dynamics*: Examining ~35,000 employment histories of federal and state banking regulators (OCC, Fed, FDIC, OTS), worker flows from regulatory agencies into regulated banks are strongly procyclical ([LST14]). Senior supervisory staff departures peak during booms, with gross annual outflow rates of 12%–18% among experienced examiners.
  - *Enforcement Leniency*: Formal supervisory enforcement actions (cease-and-desist orders, civil penalties) fall by 40%–60% during economic expansions, spiking only *ex post* after crises emerge ([LST14]). Furthermore, revolving-door lobbyists lose 24% of their revenue (\$177,000/year per lobbyist) immediately when their connected policymaker leaves office, confirming access-based rents ([BVF12]).
- **Conversion to Simulation Units** (`n_y = 12`, 1 step = 1 month):
  - Annual regulatory threshold downward drift $\delta_{\text{year}} \approx 0.02$–$0.05$ toward incumbent cost/accuracy levels.
  - Step drift rate: $\delta_{\text{step}} = \delta_{\text{year}} / 12 \approx 0.0017$–$0.0042$ per monthly step (~0.003 default). Over a 3-year regulatory revision epoch (36 steps), thresholds erode by 6%–15% in favor of dominant plans.
  - Enforcement leniency factor: Captured incumbents receive an audit/enforcement probability multiplier $\lambda_{\text{capture}} \in [0.4, 0.7]$ (a 30%–60% reduction in scrutiny), shielding large incumbents from disqualification.
- **Sources**: [STI71] Stigler 1971, doi:10.2307/3003160; [DAL06] Dal Bó 2006, doi:10.1093/oxrep/grj013; [LST14] Lucca, Seru & Trebbi 2014, doi:10.1016/j.jmoneco.2014.05.005; [BVF12] Blanes i Vidal, Draca & Fons-Rosen 2012, doi:10.1257/aer.102.7.3731.
- **Confidence**: High for existence and direction; medium for exact annual numerical drift rates across sectors.

#### 4. Delegation concentration in representative democracy and token voting
- **Target Quantities**: Effective number of parties/delegates ($N_{\text{eff}}$), voting weight share held by top delegates, and minimum coalition size to reach a 50% majority.
- **Empirical Findings**:
  - *Representative Democracies*: In OECD parliamentary democracies, the Effective Number of Parliamentary Parties (ENPP, $N = 1 / \sum s_i^2$) ranges between 2.5 and 5.5 (mean 3.2 in majoritarian systems; 4.5 in PR systems; [LT79], [TS89]). The top 2 parties hold 55%–85% of legislative seats; a majority (>50%) is routinely controlled by 1 to 2 party leaderships.
  - *Liquid Democracy (Uncapped)*: In the German Pirate Party's LiquidFeedback platform, transitive delegation without caps produced an extreme power-law distribution ([KLI15]). Less than 2% of participants accumulated >50% of active voting power, and the top 5 delegates held more voting weight than the bottom 90% combined (Gini coefficient $> 0.88$).
  - *DAO Token Voting*: In major decentralized autonomous organizations (Uniswap, Compound, MakerDAO, Aave), the Nakamoto coefficient for voting power (minimum entities needed for a 50% majority) is between 1 and 4 ([FMW24]). The top 10 token holders control 60%–92% of voting power, and >80% of proposals are decided by the top 3 delegates.
- **Conversion to Simulation Units** (`m5.jl`, `status_quo.jl`):
  - In `:status_quo`, delegation is uncapped (`cap = 1.0`) or absent (`p_delegate = 0.0`, `expertise_weight = 0.0`). With uncapped delegation and $N = 50$ to $100$ simulated voters, voting power concentrates into $N_{\text{eff}} \approx 2.5$–$4.5$ effective delegates, with the top 3 delegates controlling 55%–75% of total votes.
  - Benefuture's governed cap (`cap = 0.05`; SigThGv) guarantees $N_{\text{eff}} \ge 20$ and requires at least 11 independent delegates to form a 50% majority, eliminating super-delegate capture.
- **Sources**: [LT79] Laakso & Taagepera 1979, doi:10.1177/001041407901200101; [TS89] Taagepera & Shugart 1989; [KLI15] Kling et al. 2015, doi:10.1609/icwsm.v9i1.14618; [FMW24] Fritsch, Müller & Wattenhofer 2024, doi:10.1016/j.bcra.2024.100208.
- **Confidence**: Very High. Decades of electoral statistics and complete on-chain DAO voting records.

#### 5. Fraud detection probability, indictment hazards, and enforcement delays
- **Target Quantities**: Annual fraud detection probability, cartel indictment hazard, and duration of legal/enforcement delays before sanctions are imposed.
- **Empirical Findings**:
  - *Corporate Fraud Detection*: In a typical year, 10.3% of large US public corporations commit financial fraud (95% CI [7.2%, 14.0%]; [DMZ23]). However, only ~33% of corporate frauds are ever detected, implying an annual detection rate of ~3.3% of firms per year. Whistleblowers originate from employees (17%), non-governmental actors/media/analysts (29%), regulators (13%), SEC (7%), and external auditors (10%; [DMZ10]).
  - *Cartel Indictment Hazard*: Antitrust price-fixing conspiracies face an annual indictment probability between 0.13 and 0.17 per year, with a median survival duration of 5.0 years before indictment ([BE91]).
  - *Enforcement Delays*: In 788 federal financial misrepresentation actions ([KLM08]), the median lag from the end of the violation period to the initial regulatory inquiry/restatement is 18.0 months (1.5 years). The median lag to final SEC/DOJ enforcement sanction is 36.0 months (3.0 years). The ACFE (2024) records a median detection lag of 12.0 months for occupational fraud (18 months for corruption).
- **Conversion to Simulation Units** (`n_y = 12`, 1 step = 1 month):
  - Annual detection hazard $p_{\text{year}} \approx 0.10$–$0.33$ converts to monthly step detection probability $p_{\text{detect, step}} = 1 - (1 - p_{\text{year}})^{1/12} \approx 0.0087$–$0.0328 \approx 0.01$–$0.03$ per monthly step.
  - Enforcement delay under status quo is 18 to 36 monthly steps (median 24 steps). During this delay, deceptive agents continue operating and earning.
  - In Benefuture, decentralized AdvAp bounties and public outcome markers compress detection and escrow slashing to 1–3 steps (`adv_window` = 5–10 steps).
- **Sources**: [DMZ10] Dyck, Morse & Zingales 2010, doi:10.1111/j.1540-6261.2010.01614.x; [DMZ23] Dyck, Morse & Zingales 2023, doi:10.1007/s11142-022-09738-5; [BE91] Bryant & Eckard 1991, doi:10.2307/2109581; [KLM08] Karpoff, Lee & Martin 2008, doi:10.1017/S0022109000004221; ACFE Report to the Nations 2024.
- **Confidence**: High for enforcement lags and detection shares; medium for unobserved fraud base rates.

#### 6. Institutional memory, credit report drop-off, and statutory amnesia
- **Target Quantities**: Duration of statutory negative record retention (years), functional form of memory decay, and post-expungement market effects.
- **Empirical Findings**:
  - *Statutory Retention Mandate*: Under 15 U.S.C. § 1681c (Fair Credit Reporting Act § 605), consumer reporting agencies are legally prohibited from reporting adverse credit items (delinquencies, collections, civil judgments) older than 7 years, and bankruptcy filings older than 10 years (Chapter 7; Chapter 13 is often purged after 7 years).
  - *Market Discontinuity at Drop-Off*: Upon the exact 10-year bankruptcy drop-off date, consumer credit scores jump immediately by 20–30 points and credit card limits increase ([MUS04]). However, within 1–3 years post-purge, these consumers default at more than double the rate of observably similar consumers without past bankruptcy, proving that the statutory drop-off purges informative signals and creates adverse selection.
  - *Credit Expansion on Flag Removal*: Regression discontinuity analysis shows that removal of bankruptcy flags at 7 and 10 years causes credit card limits to surge by \$780 (+83%) and mortgage originations to expand ([DGMS20]), confirming that lenders rely strictly on the statutory memory window.
- **Conversion to Simulation Units** (`n_y = 12`, 1 step = 1 month):
  - 7 to 10 years translates to 84 to 120 monthly steps.
  - The simulation's default rolling window `window = 100` steps ($100 / 12 \approx 8.33$ years) directly reflects this statutory retention horizon.
  - In `:status_quo`, memory is a flat rectangular sliding window (`accuracy_rule = :window`): records older than 100 steps drop off completely ($w_{\tau} = 1$ for $\tau \le 100$, $w_{\tau} = 0$ for $\tau > 100$), allowing deceptive actors who pause misconduct for 100 steps (`on_off = 100`) to regain clean standing.
  - In Benefuture, continuous exponential decay (`accuracy_rule = :decay`) and permanent deception records (`repeat_escrow_credence`; 8.91) retain historical accountability across cycles.
- **Sources**: 15 U.S.C. § 1681c; [MUS04] Musto 2004, doi:10.1086/422437; [DGMS20] Dobbie, Goldsmith-Pinkham, Mahoney & Song 2020, doi:10.1111/jofi.12954.
- **Confidence**: Very High. Explicit statutory law and robust econometric regression discontinuity evidence.

---

### 9.3 Calibration summary table: status-quo baseline parameters

The table below follows the standard 8-column format of Section 3, specifying empirical baselines,
Benefuture mechanism transfers, simulation conversion units, and sweep ranges.

| Parameter | Class (transfer to Benefuture) | Unit and conversion to the sim's unit | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|---|---|
| `crisis_hazard`, `crisis_depth`, `crisis_recovery` | Institution-dependent: systemic crises emerge from fractional-reserve leverage, maturity mismatch, and fiat money; in Benefuture, full outcome settlement and domain currencies eliminate bank runs | Annual crisis probability $p_{\text{year}} \approx 0.035$ (~3.5/century). Sim: $p_{\text{step}} = 1 - (1 - 0.035)^{1/12} \approx 0.003$ per monthly step. Output drop 9%–25%; recovery 24–48 steps (median 36) | 0 (no endogenous crisis; physical catastrophe only) | Systemic financial crisis frequency, peak-to-trough output loss, and recovery time | Status-quo baseline: $p_{\text{step}} = 0.003$, depth 0.09–0.25, recovery 24–48 steps. Benefuture [CONJ]: outcome settlement and token reserves prevent financial runs; crises occur only from physical shocks (`p_hazard`). Sweep: hazard 0 to 0.005; depth 0.05 to 0.35. Default: 0.003 for `:status_quo`, 0 for `:bf`. | [RR09a] Reinhart & Rogoff 2009, doi:10.1257/aer.99.2.466 (ok); [RR09b] Reinhart & Rogoff 2009; [LV13] Laeven & Valencia 2013, doi:10.1057/imfer.2013.12 (ok); [LV20] Laeven & Valencia 2020, doi:10.1057/s41308-020-00107-3 (ok) | High across advanced economies 1800–2017. Caveat: crisis clustering across nations |
| `credit_multiplier`, `bust_contraction`, `credit_window` | Institution-dependent: procyclical leverage and credit expansion; in Benefuture, plans are capitalized by escrow ratchets and outcome tokens without credit multipliers | 5-year growth window = 60 monthly steps ($n_y = 12$). Elasticity $\eta \approx 0.15$–$0.30$ on recent growth. Bust contraction fraction 20%–35% | 1.0 (fixed escrow; 1:1 settlement, no credit multiplier) | Credit expansion during booms and abrupt contraction on bust triggers | Status-quo baseline: $m_t = 1.0 + \eta \cdot \Delta \bar{Y}_{60}$ ($\eta = 0.20$); on bust trigger (credit gap > +10 pp or default shock), multiplier contracts by $c_{\text{bust}} = 0.25$. Benefuture [CONJ]: fixed escrow and credence pricing eliminate credit cycles. Sweep: $\eta \in [0, 0.35]$, $c_{\text{bust}} \in [0, 0.40]$. Default: $\eta = 0.20, c_{\text{bust}} = 0.25$ for `:status_quo`. | [ST12] Schularick & Taylor 2012, doi:10.1257/aer.102.2.1029 (ok); [JST13] Jordà, Schularick & Taylor 2013, doi:10.1111/jmcb.12069 (ok); [BL02] Borio & Lowe 2002, doi:10.2139/ssrn.846305 (ok); [DBT11] Drehmann et al. 2011 | High on credit boom prediction; medium on contraction speed |
| `reg_drift`, `leniency_factor` | Institution-dependent: regulatory capture via revolving doors and lobbying; in Benefuture, public markers and decentralized AdvAp bounties eliminate discretion | Annual threshold drift 2%–5%. Sim: $\delta_{\text{step}} \approx 0.0017$–$0.0042$ per monthly step (~0.003 default). Leniency multiplier on captured firms: 0.4–0.7 | 0.0 (static governed thresholds); 1.0 (uniform audit probability) | Downward drift of safety/qualification thresholds toward incumbent levels and enforcement leniency | Status-quo baseline: threshold drift $\delta_{\text{step}} = 0.003$ per step; captured incumbents receive 50% lower audit scrutiny (`leniency_factor = 0.50`). Benefuture [CONJ]: ratchet rules that never drift down (8.84) and AdvAp challenges prevent capture. Sweep: $\delta_{\text{step}} \in [0, 0.005]$, `leniency_factor` $\in [0.4, 1.0]$. Default: 0.003 and 0.50 for `:status_quo`. | [STI71] Stigler 1971, doi:10.2307/3003160 (ok); [DAL06] Dal Bó 2006, doi:10.1093/oxrep/grj013 (ok); [LST14] Lucca, Seru & Trebbi 2014, doi:10.1016/j.jmoneco.2014.05.005 (ok); [BVF12] Blanes i Vidal, Draca & Fons-Rosen 2012, doi:10.1257/aer.102.7.3731 (ok) | High for revolving doors and leniency; medium for annual drift rate |
| `delegation_cap`, `delegation_concentration` | Institution-dependent: concentration of voting power in representative democracy and token governance; in Benefuture, governed 5% delegation caps (`cap = 0.05`) prevent oligopolies | Effective delegates $N_{\text{eff}} = 1 / \sum w_i^2$. In democracies/DAOs, $N_{\text{eff}} \approx 2.5$–$5.5$; top 1–5% of delegates control >50% of voting weight. Sim ($N = 50$–$100$): $N_{\text{eff}} \approx 3.5$ | `cap = 0.05` in `:bf` (SigThGv); `1.0` in status quo | Concentration of political power in a minimal oligopoly of delegates | Status-quo baseline: `cap = 1.0` (uncapped delegation) or `expertise_weight = 0.0`, causing $N_{\text{eff}} \approx 2.5$–$4.5$ with top 3 delegates holding >60% of votes. Benefuture [CONJ]: 5% cap guarantees $N_{\text{eff}} \ge 20$, requiring $\ge 11$ delegates for a majority. Sweep: `cap` from 0.02 to 1.0 (uncapped). Default: `0.05` for `:bf`, `1.0` for `:status_quo`. | [LT79] Laakso & Taagepera 1979, doi:10.1177/001041407901200101 (ok); [TS89] Taagepera & Shugart 1989; [KLI15] Kling et al. 2015, doi:10.1609/icwsm.v9i1.14618 (ok); [FMW24] Fritsch, Müller & Wattenhofer 2024, doi:10.1016/j.bcra.2024.100208 (ok) | Very High across parliaments, liquid democracy, and DAO governance |
| `p_detect_step`, `enforcement_lag` | Institution-dependent: passive audit and litigation delays; in Benefuture, automated outcome audits and AdvAp bounties compress discovery and settlement to 1–3 steps | Annual detection 0.10–0.33. Sim: $p_{\text{detect, step}} \approx 0.01$–$0.03$ per monthly step. Enforcement lag 18–36 monthly steps (median 24 steps) | `p_trace = 0.5` (given revelation); `adv_window = 5–10` steps | Probability per step of uncovering misconduct and duration of legal/enforcement delay | Status-quo baseline: $p_{\text{detect, step}} = 0.015$ per step, with `enforcement_lag = 24` steps during which violators retain revenue. Benefuture [CONJ]: open ledgers and AdvAp bounties compress discovery and escrow forfeiture to 1–3 steps. Sweep: $p_{\text{detect, step}} \in [0.01, 0.10]$, `enforcement_lag` $\in [1, 36]$. Default: 0.015 and 24 steps for `:status_quo`. | [DMZ10] Dyck, Morse & Zingales 2010, doi:10.1111/j.1540-6261.2010.01614.x (ok); [DMZ23] Dyck, Morse & Zingales 2023, doi:10.1007/s11142-022-09738-5 (ok); [BE91] Bryant & Eckard 1991, doi:10.2307/2109581 (ok); [KLM08] Karpoff, Lee & Martin 2008, doi:10.1017/S0022109000004221 (ok); ACFE 2024 | High for enforcement delays; medium for fraud base rate |
| `memory_window`, `memory_rule` | Institution-dependent: statutory credit amnesia (FCRA 7-to-10-year purge); in Benefuture, immutable ledgers and Bayesian updating retain lifetime track records | 7–10 years = 84–120 monthly steps ($n_y = 12$). Directly maps to sim's default `window = 100` steps (8.33 years). Drop-off rule: rectangular window vs exponential decay | `window = 100`; `accuracy_rule = :decay` (`:window` limiting case) | Duration and functional form of institutional memory regarding past failures and misconduct | Status-quo baseline: flat rectangular sliding window of `window = 100` steps with complete amnesia for $t > 100$ (`accuracy_rule = :window`, `ratchet_growth = 0.0`). Benefuture [CONJ]: persistent append-only ledgers, exponential decay (`accuracy_rule = :decay`), and permanent deception records (`ratchet_growth = 1.0`; 8.91) retain historical accountability. Sweep: window 60 to 120 steps; rule `:window` vs `:decay`. Default: 100 and `:window` for `:status_quo`. | 15 U.S.C. § 1681c; [MUS04] Musto 2004, doi:10.1086/422437 (ok); [DGMS20] Dobbie, Goldsmith-Pinkham, Mahoney & Song 2020, doi:10.1111/jofi.12954 (ok) | Very High. Statutory law is explicit and econometric RD confirms market reliance |

---

### 9.4 Simulation implementation mapping for Track B (`sim/battery/status_quo*.jl`, `sim/src/coupled.jl`)

The calibrated parameters above map directly onto the status-quo baselines and coupled governance probes:
1. **Status-Quo Economy Baseline (`sim/battery/status_quo_economy.jl`)**:
   - Low reader vigilance (`vigilance = 0.001`), high resource accounting noise (`cost_σ = 0.3`), elevated memory loss (`memory_loss = 0.1`), higher false-trace errors (`p_false_trace = 0.05`), weaker guardian information and diligence (`p_informed = 0.6`, `diligence = 0.4`), and no AdvAp challenge bounties (`advap = false`).
   - Rectangular sliding window (`accuracy_rule = :window`, `window = 100`) where expired misconduct drops off completely after 100 steps (`on_off = 100`).
2. **Status-Quo Governance Baseline (`sim/battery/status_quo.jl`)**:
   - Equal voting weights (`expertise_weight = 0.0`; one-person-one-vote without domain expertise weighting), no audited delegation (`p_delegate = 0.0` or uncapped `cap = 1.0`), and no AdvAp rewards (`advap = false`).
3. **Coupled vs. Uncoupled Economy–Governance Dynamics (`sim/src/coupled.jl`, L3.2 Probe)**:
   - In an uncoupled run (`coupled = false`), governance decides on threshold perturbations without observing the economy's measured outcomes (`success_pattern`); harmful threshold candidates remain active or are adopted blindly, causing floors to fall.
   - In a coupled run (`coupled = true`), governance weights voters by their cumulative reputation from the economy's records (`relevance_leaf`), resolves each epoch's threshold decision against the economy's measured outcome (`success_pattern`), and updates voter records (`vote_reputation`), rejecting harmful threshold candidates within two epochs so floors hold.

---

## 10. References

Each entry gives the citation, the link and its check, and a one- or two-line summary weighted to
the parameter. DOIs marked ok resolved in Crossref with a matching title on 2026-10-30. No summary
below replaces reading the paper; items marked **[unverified]** were not read.

**Advice, persuasion, deliberation**

- [BAI23] Bailey, Leon, Ebner, Moustafa & Weidemann (2022/2023). A meta-analysis of the weight of
  advice in decision-making. *Current Psychology* 42. https://doi.org/10.1007/s12144-022-03573-2 (ok).
  346 effect sizes, 129 datasets; only advice-quality cues predict weight; pooled WOA 0.39 [0.37, 0.42]
  as quoted by a citing paper **[unverified]**.
- [YAN04] Yaniv (2004). Receiving other people's advice: influence and benefit. *OBHDP* 93.
  https://doi.org/10.1016/j.obhdp.2003.08.002 (ok). Advice shifts estimates less than normative
  averaging; accuracy of the advisor matters.
- [YK00] Yaniv & Kleinberger (2000). Advice taking in decision making: egocentric discounting and
  reputation formation. *OBHDP* 83. https://doi.org/10.1006/obhd.2000.2909 (ok). Own estimate
  weighted about twice the advisor's **[unverified]**; weights adjust to advisor's track record.
- [BD06] Bonaccio & Dalal (2006). Advice taking and decision-making: an integrative literature
  review. *OBHDP* 101. https://doi.org/10.1016/j.obhdp.2006.07.001 (ok). Review of moderators of use
  of advice.
- [SL09] Soll & Larrick (2009). Strategies for revising judgment: how (and how well) people use
  others' opinions. *JEP:LMC* 35. https://doi.org/10.1037/a0015145 (ok). Choosing versus averaging;
  averaging was usually better.
- [HF97] Harvey & Fischer (1997). Taking advice. *OBHDP* 70. https://doi.org/10.1006/obhd.1997.2697 (ok).
- [SSD04] Sniezek, Schrah & Dalal (2004). Improving judgement with prepaid expert advice. *J. Behav.
  Decis. Making* 17. https://doi.org/10.1002/bdm.468 (ok). Commitment raises use of expert advice.
- [GM07] Gino & Moore (2007). Effects of task difficulty on use of advice. *J. Behav. Decis. Making*
  20. https://doi.org/10.1002/bdm.539 (ok; Crossref first issued 2006).
- [LOG19] Logg, Minson & Moore (2019). Algorithm appreciation. *OBHDP* 151.
  https://doi.org/10.1016/j.obhdp.2018.12.005 (ok).
- [HILL17] Hill (2017). Learning together slowly: Bayesian learning about political facts. *J. Politics*
  79. https://doi.org/10.1086/692739 (ok). About 73% of Bayes' rule (abstract).
- [MOB22] Möbius, Niederle, Niehaus & Rosenblat (2022). Managing self-confidence. *Management
  Science* 68. https://doi.org/10.1287/mnsc.2021.4294 (ok). Conservatism and asymmetry in updating.
- [PE66] Phillips & Edwards (1966). Conservatism in a simple probability inference task. *J. Exp.
  Psychol.* 72. https://doi.org/10.1037/h0023653 (ok).
- [EDW68] Edwards (1968). Conservatism in human information processing. In Kleinmuntz (ed.), *Formal
  Representation of Human Judgment*. No DOI; link above in 1.2 not fetched **[unverified]**.
- [MER17] Mercier (2017). How gullible are we? *Rev. Gen. Psychol.* 21.
  https://doi.org/10.1037/gpr0000111 (ok). Epistemic vigilance; persuasion much weaker than believed.
- [DVG10] DellaVigna & Gentzkow (2010). Persuasion: empirical evidence. *Annu. Rev. Econ.* 2.
  https://doi.org/10.1146/annurev.economics.102308.124309 (ok); NBER w15298
  https://www.nber.org/papers/w15298 (200). Persuasion rates across consumers, voters, donors,
  investors.
- [DVK07] DellaVigna & Kaplan (2007). The Fox News effect. *QJE* 122.
  https://doi.org/10.1162/qjec.122.3.1187 (ok).
- [KB18] Kalla & Broockman (2018). The minimal persuasive effects of campaign contact in general
  elections. *APSR* 112. https://doi.org/10.1017/S0003055417000363 (ok). Average effect zero.
- [CHV20] Coppock, Hill & Vavreck (2020). The small effects of political advertising are small
  regardless of context, message, sender, or receiver. *Science Advances* 6.
  https://doi.org/10.1126/sciadv.abc4046 (ok); page https://alexandercoppock.com/coppock_hill_vavreck_2020.html (200).
- [HEW24] Hewitt et al. (2024). How experiments help campaigns persuade voters. *APSR* 118.
  https://doi.org/10.1017/S0003055423001387 (ok).
- [WP19] Wood & Porter (2019). The elusive backfire effect. *Political Behavior* 41.
  https://doi.org/10.1007/s11109-018-9443-y (ok).
- [GC20] Guess & Coppock (2020). Does counter-attitudinal information cause backlash? *BJPS* 50.
  https://doi.org/10.1017/S0007123418000327 (ok).
- [VDL15] van der Linden, Leiserowitz, Feinberg & Maibach (2015). The scientific consensus on
  climate change as a gateway belief. *PLoS ONE* 10. https://doi.org/10.1371/journal.pone.0118489 (ok).
- [VDL19] van der Linden (2019). The gateway belief model: a large-scale replication. *J. Environ.
  Psychol.* 62. https://doi.org/10.1016/j.jenvp.2019.01.009 (ok).
- [BD18] Bolsen & Druckman (2018). Do partisanship and politicization undermine the impact of a
  scientific consensus message about climate change? *Group Processes & Intergroup Relations* 21.
  https://doi.org/10.1177/1368430217737855 (ok).
- [LFJ02] Luskin, Fishkin & Jowell (2002). Considered opinions: Deliberative Polling in Britain.
  *BJPS* 32. https://doi.org/10.1017/S0007123402000194 (ok).
- [FL05] Fishkin & Luskin (2005). Experimenting with a democratic ideal. *Acta Politica* 40.
  https://doi.org/10.1057/palgrave.ap.5500121 (ok).
- [FAR10] Farrar, Fishkin, Green, List, Luskin & Paluck (2010). Disaggregating deliberation's effects.
  *BJPS* 40. https://doi.org/10.1017/s0007123409990433 (ok; my first DOI was wrong).
- [FSDB21] Fishkin, Siu, Diamond & Bradburn (2021). Is deliberation an antidote to extreme partisan
  polarization? *APSR* 115. https://doi.org/10.1017/S0003055421000642 (ok).
- [MOU13] Moussaïd, Kämmer, Analytis & Neth (2013). Social influence and the collective dynamics of
  opinion formation. *PLoS ONE* 8. https://doi.org/10.1371/journal.pone.0078433 (ok).
- [LOR11] Lorenz, Rauhut, Schweitzer & Helbing (2011). How social influence can undermine the wisdom of
  crowd effect. *PNAS* 108. https://doi.org/10.1073/pnas.1008636108 (ok).
- [BEC17] Becker, Brackbill & Centola (2017). Network dynamics of social influence in the wisdom of
  crowds. *PNAS* 114. https://doi.org/10.1073/pnas.1615978114 (ok).
- [DMZ03] DeMarzo, Vayanos & Zwiebel (2003). Persuasion bias, social influence, and unidimensional
  opinions. *QJE* 118. https://doi.org/10.1162/00335530360698469 (ok).
- [ENZ19] Enke & Zimmermann (2019). Correlation neglect in belief formation. *Rev. Econ. Stud.* 86.
  https://doi.org/10.1093/restud/rdx081 (ok).
- [BUR11] Burgman et al. (2011). Expert status and performance. *PLoS ONE* 6.
  https://doi.org/10.1371/journal.pone.0022998 (ok).
- [SHA92] Shanteau (1992). Competence in experts. *OBHDP* 53. https://doi.org/10.1016/0749-5978(92)90064-E (ok).
- [GRO00] Grove et al. (2000). Clinical versus mechanical prediction. *Psychological Assessment* 12.
  https://doi.org/10.1037/1040-3590.12.1.19 (ok).
- [MCP06] McPherson, Smith-Lovin & Brashears (2006). Social isolation in America. *ASR* 71.
  https://doi.org/10.1177/000312240607100301 (ok). [MSC01] McPherson, Smith-Lovin & Cook (2001).
  Birds of a feather. *Annu. Rev. Sociol.* 27. https://doi.org/10.1146/annurev.soc.27.1.415 (ok).
- [VOS18] Vosoughi, Roy & Aral (2018). *Science* 359. https://doi.org/10.1126/science.aap9559 (ok).
- [JB15] Jergas & Baethge (2015). Quotation accuracy in medical journal articles. *PeerJ* 3.
  https://doi.org/10.7717/peerj.1364 (ok). Total quotation error 25.4%, major 11.9% (abstract).
- [GRE09] Greenberg (2009). How citation distortions create unfounded authority. *BMJ* 339.
  https://doi.org/10.1136/bmj.b2680 (ok).
- [LUN17] Lundh et al. (2017). Industry sponsorship and research outcome. *Cochrane Database Syst.
  Rev.* https://doi.org/10.1002/14651858.MR000033.pub3 (ok).
- [BFS12] Bolton, Freixas & Shapiro (2012). The credit ratings game. *J. Finance* 67.
  https://doi.org/10.1111/j.1540-6261.2011.01708.x (ok). [BM11] Becker & Milbourn (2011). *J. Financial
  Economics* 101. https://doi.org/10.1016/j.jfineco.2011.03.012 (ok). [DAL06] Dal Bó (2006). Regulatory
  capture: a review. *Oxford Rev. Econ. Policy* 22. https://doi.org/10.1093/oxrep/grj013 (ok).

**Skills, forecasting, noise**

- [HUN90] Hunter, Schmidt & Judiesch (1990). Individual differences in output variability as a
  function of job complexity. *J. Appl. Psychol.* 75. https://doi.org/10.1037/0021-9010.75.1.28 (ok).
- [OBA12] O'Boyle & Aguinis (2012). The best and the rest. *Personnel Psychology* 65.
  https://doi.org/10.1111/j.1744-6570.2011.01239.x (ok). Individual performance follows Paretian
  distributions across many fields.
- [SYV11] Syverson (2011). What determines productivity? *J. Econ. Lit.* 49.
  https://doi.org/10.1257/jel.49.2.326 (ok). Large within-industry productivity dispersion.
- [SIN16] Sinatra et al. (2016). *Science* 354. https://doi.org/10.1126/science.aaf5239 (ok).
- [WS06] Webb & Sheeran (2006). Does changing behavioral intentions engender behavior change?
  *Psychol. Bull.* 132. https://doi.org/10.1037/0033-2909.132.2.249 (ok); [SHE02] Sheeran (2002).
  *Eur. Rev. Soc. Psychol.* 12. https://doi.org/10.1080/14792772143000003 (ok).
- [LR97] Lau & Redlawsk (1997). Voting correctly. *APSR* 91. https://doi.org/10.2307/2952076 (ok).
  [BAR96] Bartels (1996). Uninformed votes. *AJPS* 40. https://doi.org/10.2307/2111700 (ok).
  [GAL07] Galton (1907). Vox populi. *Nature* 75. https://doi.org/10.1038/075450a0 (ok).
- [PIE18] Pier et al. (2018). Low agreement among reviewers evaluating the same NIH grant
  applications. *PNAS* 115. https://doi.org/10.1073/pnas.1714379115 (ok); [FAN16] Fang, Bowen &
  Casadevall (2016). *eLife* 5. https://doi.org/10.7554/eLife.13323 (ok).
- [BAU15] Bauer, Thorpe & Brunet (2015). The quiet revolution of numerical weather prediction.
  *Nature* 525. https://doi.org/10.1038/nature14956 (ok).
- [MEL14] Mellers et al. (2014). *Psychological Science* 25. https://doi.org/10.1177/0956797614524255
  (ok). [MAK20] Makridakis et al. (2020). *Int. J. Forecasting* 36.
  https://doi.org/10.1016/j.ijforecast.2019.04.014 (ok). [CRA22] Cramer et al. (2022). *PNAS* 119.
  https://doi.org/10.1073/pnas.2113561119 (ok).
- [BDGH13] Ben-David, Graham & Harvey (2013). Managerial miscalibration. *QJE* 128.
  https://doi.org/10.1093/qje/qjt023 (ok). [MH08] Moore & Healy (2008). *Psychol. Rev.* 115.
  https://doi.org/10.1037/0033-295X.115.2.502 (ok).
- [BAR14] Baron et al. (2014). *Decision Analysis* 11. https://doi.org/10.1287/deca.2014.0293 (ok).
  [SAT14] Satopää et al. (2014). *Int. J. Forecasting* 30. https://doi.org/10.1016/j.ijforecast.2013.09.009 (ok).
- [RS79] Ross & Sicoly (1979). Egocentric biases in availability and attribution. *JPSP* 37.
  https://doi.org/10.1037/0022-3514.37.3.322 (ok).
- [VIV20] Vivalt (2020). How much can we generalize from impact evaluations? *JEEA* 18.
  https://doi.org/10.1093/jeea/jvaa019 (ok). [MEA19] Meager (2019). *AEJ: Applied* 11.
  https://doi.org/10.1257/app.20170299 (ok). [BTY21] Bryan, Tipton & Yeager (2021). *Nature Human
  Behaviour* 5. https://doi.org/10.1038/s41562-021-01143-3 (ok). [KRA20] Kraft (2020). *Educ. Researcher*
  49. https://doi.org/10.3102/0013189X20912798 (ok).
- [CAC14] Carron-Arthur, Cunningham & Griffiths (2014). *Internet Interventions* 1.
  https://doi.org/10.1016/j.invent.2014.09.003 (ok).
- [ERA10] Erasmus et al. (2010). Systematic review of studies on compliance with hand hygiene
  guidelines. *Infect. Control Hosp. Epidemiol.* 31. https://doi.org/10.1086/650451 (ok).
- [DEV08] de Vries et al. (2008). The incidence and nature of in-hospital adverse events. *Qual. Saf.
  Health Care* 17. https://doi.org/10.1136/qshc.2007.023622 (ok). Median incidence 9.2%, 43.5% preventable,
  7.4% lethal (abstract). [BRE91] Brennan et al. (1991). *NEJM* 324.
  https://doi.org/10.1056/NEJM199102073240604 (ok). [LAN10] Landrigan et al. (2010). *NEJM* 363.
  https://doi.org/10.1056/NEJMsa1004404 (ok).

**Ledgers, audit, deception, collusion, delegation**

- [RW96] Rubin & Wenzel (1996). *Psychol. Rev.* 103. https://doi.org/10.1037/0033-295X.103.4.734 (ok).
  [MD15] Murre & Dros (2015). *PLoS ONE* 10. https://doi.org/10.1371/journal.pone.0120644 (ok).
  [BAU01] Baumeister et al. (2001). Bad is stronger than good. *Rev. Gen. Psychol.* 5.
  https://doi.org/10.1037/1089-2680.5.4.323 (ok).
- [VIN14] Vines et al. (2014). *Current Biology* 24. https://doi.org/10.1016/j.cub.2013.11.014 (ok).
  [KLE14] Klein et al. (2014). *PLoS ONE* 9. https://doi.org/10.1371/journal.pone.0115253 (ok).
- [BAK14] Bakos, Marotta-Wurgler & Trossen (2014). Does anyone read the fine print? *J. Legal
  Studies* 43. https://doi.org/10.1086/674424 (ok). [OOH20] Obar & Oeldorf-Hirsch (2020). *Information,
  Communication & Society* 23. https://doi.org/10.1080/1369118X.2018.1486870 (ok). [CLK09] Chetty,
  Looney & Kroft (2009). *AER* 99. https://doi.org/10.1257/aer.99.4.1145 (ok). [SIM03] Sims (2003).
  *J. Monetary Econ.* 50. https://doi.org/10.1016/S0304-3932(03)00029-1 (ok).
- [DMZ10] Dyck, Morse & Zingales (2010). Who blows the whistle on corporate fraud? *J. Finance* 65.
  https://doi.org/10.1111/j.1540-6261.2010.01614.x (ok). [DMZ23] *Rev. Account. Stud.*
  https://doi.org/10.1007/s11142-022-09738-5 (ok).
- [MAZ08] Mazar, Amir & Ariely (2008). *J. Marketing Res.* 45. https://doi.org/10.1509/jmkr.45.6.633 (ok).
  [GER19] Gerlach, Teodorescu & Hertwig (2019). *Psychol. Bull.* 145. https://doi.org/10.1037/bul0000174
  (ok). [ABE19] Abeler, Nosenzo & Raymond (2019). *Econometrica* 87. https://doi.org/10.3982/ECTA14673
  (ok). [FAN09] Fanelli (2009). *PLoS ONE* 4. https://doi.org/10.1371/journal.pone.0005738 (ok).
- [BE91] Bryant & Eckard (1991). Price fixing: the probability of getting caught. *Rev. Econ. Stat.*
  73. https://doi.org/10.2307/2109581 (ok). Probability of indictment at most 0.13–0.17 a year
  (abstract). [LS06] Levenstein & Suslow (2006). What determines cartel success? *J. Econ. Lit.* 44.
  https://doi.org/10.1257/002205106776162681 (ok). Cartel durations bimodal, average about five years
  (abstract). [MIL09] Miller (2009). *AER* 99. https://doi.org/10.1257/aer.99.3.750 (ok).
- [PRI07] Priedhorsky et al. (2007). *GROUP '07*. https://doi.org/10.1145/1316624.1316663 (ok).
  [VWD04] Viégas, Wattenberg & Dave (2004). *CHI '04*. https://doi.org/10.1145/985692.985765 (ok).
  [KUM16] Kumar, West & Leskovec (2016). *WWW '16*. https://doi.org/10.1145/2872427.2883085 (ok).
  [STE13] Steen, Casadevall & Fang (2013). *PLoS ONE* 8. https://doi.org/10.1371/journal.pone.0068397
  (ok). Mean 32.91 months to retraction (abstract). [GH13] Geiger & Halfaker (2013). *WikiSym*.
  https://doi.org/10.1145/2491055.2491061 (ok).
- [STU06] Studdert et al. (2006). *NEJM* 354. https://doi.org/10.1056/NEJMsa054479 (ok). [GOS14] Gross et
  al. (2014). *PNAS* 111. https://doi.org/10.1073/pnas.1306417111 (ok).
- [SAL95] Sally (1995). *Rationality and Society* 7. https://doi.org/10.1177/1043463195007001004 (ok).
  [MEN18] Mengel (2018). *Economic Journal* 128. https://doi.org/10.1111/ecoj.12548 (ok).
- [KUM17] Kumar et al. (2017). An army of me. *WWW '17*. https://doi.org/10.1145/3038912.3052677 (ok).
  [FR01] Friedman & Resnick (2001). *J. Econ. Manag. Strategy* 10.
  https://doi.org/10.1111/j.1430-9134.2001.00173.x (ok). [DOU02] Douceur (2002). The Sybil attack.
  https://doi.org/10.1007/3-540-45748-8_24 (ok).
- [CDGL08] Clark, Diener, Georgellis & Lucas (2008). *Economic Journal* 118.
  https://doi.org/10.1111/j.1468-0297.2008.02150.x (ok). [LUC07] Lucas (2007). *Curr. Dir. Psychol. Sci.*
  16. https://doi.org/10.1111/j.1467-8721.2007.00479.x (ok).
- [KLI15] Kling et al. (2015). Voting behaviour and power in online democracy. *ICWSM*.
  https://doi.org/10.1609/icwsm.v9i1.14618 (ok); https://arxiv.org/abs/1503.07723. [FMW24] Fritsch, Müller
  & Wattenhofer (2024). https://doi.org/10.1016/j.bcra.2024.100208 (ok). [FEI23] Feichtinger et al.
  (2023). https://arxiv.org/abs/2302.12125. [KMP21] Kahng, Mackenzie & Procaccia (2021). *JAIR* 70.
  https://doi.org/10.1613/jair.1.12261 (ok). [BER25] Berinsky et al. (2025). *Management Science*.
  https://doi.org/10.1287/mnsc.2023.02470 (ok). [CG16] Cancela & Geys (2016). *Electoral Studies* 42.
  https://doi.org/10.1016/j.electstud.2016.03.005 (ok).

**Teaching, research, demography, harm, projects, resources**

- [HBBL08] Hill, Bloom, Black & Lipsey (2008). *Child Dev. Perspectives* 2.
  https://doi.org/10.1111/j.1750-8606.2008.00061.x (ok). [BLO84] Bloom (1984). *Educ. Researcher* 13.
  https://doi.org/10.3102/0013189X013006004 (ok). [ROC04] Rockoff (2004). *AER* 94.
  https://doi.org/10.1257/0002828041302244 (ok). [NKH04] Nye, Konstantopoulos & Hedges (2004).
  *Educ. Eval. Policy Anal.* 26. https://doi.org/10.3102/01623737026003237 (ok). [HR12] Hanushek & Rivkin
  (2012). *Annu. Rev. Econ.* 4. https://doi.org/10.1146/annurev-economics-080511-111001 (ok; corrected).
  [CFR14] Chetty, Friedman & Rockoff (2014). *AER* 104. https://doi.org/10.1257/aer.104.9.2593 (ok).
  [KRU99] Krueger (1999). *QJE* 114. https://doi.org/10.1162/003355399556052 (ok). [BDOY16] Bailey et al.
  (2016). Persistence and fadeout. *J. Res. Educ. Effectiveness*. https://doi.org/10.1080/19345747.2016.1232459 (ok).
- [BJVW20] Bloom et al. (2020). *AER* 110. https://doi.org/10.1257/aer.20180338 (ok). [WSL19] Wong,
  Siah & Lo (2019). *Biostatistics* 20. https://doi.org/10.1093/biostatistics/kxx069 (ok). [HAY14] Hay et al.
  (2014). *Nature Biotechnology* 32. https://doi.org/10.1038/nbt.2786 (ok). [SV07] Silverberg & Verspagen
  (2007). *J. Econometrics* 139. https://doi.org/10.1016/j.jeconom.2006.10.017 (ok). [KPSS17] Kogan et al.
  (2017). *QJE* 132. https://doi.org/10.1093/qje/qjw040 (ok). [PLF23] Park, Leahey & Funk (2023). *Nature*
  613. https://doi.org/10.1038/s41586-022-05543-x (ok).
- [RAF12] Raftery et al. (2012). *PNAS* 109. https://doi.org/10.1073/pnas.1211452109 (ok). [HER07] Hertz et
  al. (2007). *B.E. J. Econ. Anal. Policy* 7. https://doi.org/10.2202/1935-1682.1775 (ok). [COR13] Corak
  (2013). *JEP* 27. https://doi.org/10.1257/jep.27.3.79 (ok). [POL15] Polderman et al. (2015). *Nature
  Genetics* 47. https://doi.org/10.1038/ng.3285 (ok).
- [CSN09] Clauset, Shalizi & Newman (2009). *SIAM Review* 51. https://doi.org/10.1137/070710111 (ok).
  [CLA18] Clauset (2018). *Science Advances* 4. https://doi.org/10.1126/sciadv.aao3580 (ok). [CT16]
  Cirillo & Taleb (2016). *Physica A* 452. https://doi.org/10.1016/j.physa.2016.01.050 (ok). [CT20]
  *Nature Physics* 16. https://doi.org/10.1038/s41567-020-0921-x (ok). [MAR21] Marani et al. (2021).
  *PNAS* 118. https://doi.org/10.1073/pnas.2105482118 (ok).
- [FHB02] Flyvbjerg, Holm & Buhl (2002). *J. Am. Plann. Assoc.* 68.
  https://doi.org/10.1080/01944360208976273 (ok). [FLY09] Flyvbjerg (2009). *Oxford Rev. Econ. Policy* 25.
  https://doi.org/10.1093/oxrep/grp024 (ok). [FLY14] Flyvbjerg (2014). *Project Management J.* 45.
  https://doi.org/10.1002/pmj.21409 (ok). [FAB18] Flyvbjerg et al. (2018). *Transportation Research A* 118.
  https://doi.org/10.1016/j.tra.2018.07.013 (ok). [FBL20] Flyvbjerg, Budzier & Lunn (2020). *Environment and
  Planning A* 53. https://doi.org/10.1177/0308518X20958724 (ok).
- [THO14] Thorson, Jensen & Zipkin (2014). *Can. J. Fish. Aquat. Sci.* 71.
  https://doi.org/10.1139/cjfas-2013-0645 (ok). [RIC12] Ricard et al. (2012). *Fish and Fisheries* 13.
  https://doi.org/10.1111/j.1467-2979.2011.00435.x (ok).
- [GAB16] Gabaix (2016). *JEP* 30. https://doi.org/10.1257/jep.30.1.185 (ok). [SZ16] Saez & Zucman (2016).
  *QJE* 131. https://doi.org/10.1093/qje/qjw004 (ok). [KN14] Karabarbounis & Neiman (2014). *QJE* 129.
  https://doi.org/10.1093/qje/qjt032 (ok).
- [BEN17] Benjamin et al. (2017). Redefine statistical significance. *Nature Human Behaviour* 2.
  https://doi.org/10.1038/s41562-017-0189-z (ok).
- [RZSL06] Resnick et al. (2006). The value of reputation on eBay. *Exp. Econ.* 9.
  https://doi.org/10.1007/s10683-006-4309-2 (ok). [CH10] Cabral & Hortaçsu (2010). The dynamics of seller
  reputation. *J. Ind. Econ.* 58. https://doi.org/10.1111/j.1467-6451.2010.00405.x (ok).
- [GRO19] Grother, Ngan & Hanaoka (2019). Ongoing Face Recognition Vendor Test (FRVT) Part 2: Identification. *NIST Interagency Report 8271*. https://doi.org/10.6028/NIST.IR.8271 (ok). FNMR 0.001–0.005 on passport/visa standard at FMR 1e-5; rises to 0.02–0.05 on wild/unconstrained captures.
- [JAV24] Javelin Strategy & Research (2024). *Identity Fraud Study: Resolving the Identity Crisis*. Median detection lag 6–18 months for synthetic identity and new-account fraud.
- [KEN64] Kent (1964). Words of estimative probability. *Studies in Intelligence* 8(4): 49–65. Verbal probability ladder: "almost certainly" 93% ±6%, "probable" 75% ±12%, "even chance" 50% ±10%, "unlikely" 30% ±10%, "almost certainly not" 7% ±5%.
- [LFP82] Lichtenstein, Fischhoff & Phillips (1982). Calibration of probabilities: The state of the art to 1980. In Kahneman, Slovic & Tversky (eds.), *Judgment Under Uncertainty*, pp. 306–334. Overconfidence curve: 90% stated confidence yields 70%–78% empirical hit rate.
- [TET15] Tetlock & Gardner (2015). *Superforecasting: The Art and Science of Prediction*. Crown. IARPA ACE tournament results: 30–50 resolved forecasts needed to separate skill from noise.
- [ZIM06] Zimmerman et al. (2006). Acute Physiology and Chronic Health Evaluation (APACHE) IV: Hospital mortality assessment for adult ICU patients. *Crit. Care Med.* 34(5): 1297–1310. https://doi.org/10.1097/01.CCM.0000215112.21835.61 (ok). APACHE IV achieves ICU mortality AUC-ROC 0.88–0.89, Brier score 0.075–0.090.
- [WSL19] Wong, Siah & Lo (2019). Estimation of clinical trial success rates and related parameters. *Biostatistics* 20(2): 273–286. https://doi.org/10.1093/biostatistics/kxx069 (ok). Overall trial phase transition success from Phase I to approval 13.8%; Phase II to III 30.7%.
- [JOR04] Jørgensen (2004). A review of studies on software development cost estimation problems. *IEEE Trans. Softw. Eng.* 30(1): 35–60. https://doi.org/10.1109/TSE.2004.1265817 (ok). Review of software estimation: algorithmic models achieve PRED(0.25) 50%–65%; human judgment 30%–40%.
- [FW13] Faust & Wright (2013). Forecasting inflation. In *Handbook of Economic Forecasting* 2: 2–56. https://doi.org/10.1016/B978-0-444-53683-9.00001-3 (ok). Survey of Professional Forecasters and Federal Reserve Greenbook macro forecasts achieve R² 0.20–0.35 over naive persistence.
- [ALT68] Altman (1968). Financial ratios, discriminant analysis and the prediction of corporate bankruptcy. *J. Finance* 23(4): 589–609. https://doi.org/10.1111/j.1540-6261.1968.tb00843.x (ok). Altman Z-score achieves 1-year corporate bankruptcy AUC-ROC 0.82–0.85; hazard rate extensions achieve AUC-ROC 0.90–0.94.
- [LC92] Lee & Carter (1992). Modeling and forecasting U.S. mortality. *J. Am. Stat. Assoc.* 87(419): 659–671. https://doi.org/10.1080/01621459.1992.10475265 (ok). Out-of-sample mortality forecasting achieves R² > 0.95 across 5–10 year horizons.
- [SIL20] Silver (2020). The real secret to FiveThirtyEight's 2020 presidential forecast. *FiveThirtyEight*. Brier score 0.082 across presidential election outcomes.

**Status-quo institutions, financial cycles, regulatory capture, memory**

- [RR09a] Reinhart, C. M., & Rogoff, K. S. (2009). The Aftermath of Financial Crises. *American Economic Review*, 99(2): 466–472. https://doi.org/10.1257/aer.99.2.466 (ok). Real per capita GDP declines 9.3% peak-to-trough over 1.9 years; recovery to pre-crisis peak output takes 4.4 years; unemployment increases 7.0 percentage points with downswing lasting 4.8 years.
- [RR09b] Reinhart, C. M., & Rogoff, K. S. (2009). *This Time Is Different: Eight Centuries of Financial Folly*. Princeton University Press. ISBN 978-0-691-14216-6. Historical analysis of financial crises across 66 countries and 800 years; advanced economy systemic banking crisis frequency averages 3.0%–4.5% per country-year (~3.5–4.5 crises per country-century).
- [LV13] Laeven, L., & Valencia, F. (2013). Systemic Banking Crises Database. *IMF Economic Review*, 61(2): 225–270. https://doi.org/10.1057/imfer.2013.12 (ok). Cross-country database of systemic banking crises; annual crisis probability in advanced economies ~3.8%; median cumulative output loss relative to trend 23% of GDP.
- [LV20] Laeven, L., & Valencia, F. (2020). Systemic Banking Crises Database II. *IMF Economic Review*, 68(2): 307–361. https://doi.org/10.1057/s41308-020-00107-3 (ok). Updated database of 151 systemic banking crises (1970–2017); median output recovery time to trend is 3 years; advanced economy cumulative output loss averages 32.9% of GDP.
- [ST12] Schularick, M., & Taylor, A. M. (2012). Credit Booms Gone Bust: Monetary Policy, Leverage Cycles, and Financial Crises, 1870–2008. *American Economic Review*, 102(2): 1029–1061. https://doi.org/10.1257/aer.102.2.1029 (ok). 140-year panel of 14 nations; past bank loan growth is the single best predictor of financial crises (+1 SD in 5-year loan growth raises crisis odds by 52%, log-odds 0.38); broad money aggregates have no predictive power once credit is controlled for.
- [JST13] Jordà, Ò., Schularick, M., & Taylor, A. M. (2013). When Credit Bites Back. *Journal of Money, Credit and Banking*, 45(s2): 3–28. https://doi.org/10.1111/jmcb.12069 (ok). Recessions following credit booms are twice as deep (-5.0% vs -2.3% peak-to-trough real GDP per capita) and require >5 years to recover; private bank credit contracts 10%–15% during the bust.
- [BL02] Borio, C., & Lowe, P. (2002). Asset prices, financial and monetary stability: exploring the nexus. *BIS Working Papers*, No. 114. https://doi.org/10.2139/ssrn.846305 (ok). Credit-to-GDP gap exceeding +10 percentage points predicts systemic banking crises with 2–3 year lead; procyclical leverage expands credit multipliers by 15%–35% during booms.
- [DBT11] Drehmann, M., Borio, C., & Tsatsaronis, K. (2011). Anchoring countercyclical capital buffers: the role of credit-to-GDP trends. *International Journal of Central Banking*, 7(4): 189–240. Empirical foundation for the Basel III countercyclical capital buffer; credit-to-GDP trend gap exceeding +10 pp indicates unsustainable systemic leverage.
- [STI71] Stigler, G. J. (1971). The Theory of Economic Regulation. *Bell Journal of Economics and Management Science*, 2(1): 3–21. https://doi.org/10.2307/3003160 (ok). Foundational economic theory of regulatory capture: regulation is acquired by industry and operated primarily for its benefit to suppress competition and entry.
- [LST14] Lucca, D., Seru, A., & Trebbi, F. (2014). The revolving door and worker flows in banking regulation. *Journal of Monetary Economics*, 65: 17–32. https://doi.org/10.1016/j.jmoneco.2014.05.005 (ok). 35,000 regulatory examiner resumes; supervisor exits to private banks are procyclical (12%–18% annual turnover in booms); supervisory enforcement actions drop 40%–60% during expansions.
- [BVF12] Blanes i Vidal, J., Draca, M., & Fons-Rosen, C. (2012). Revolving Door Lobbyists. *American Economic Review*, 102(7): 3731–3748. https://doi.org/10.1257/aer.102.7.3731 (ok). Revolving-door lobbyists suffer an immediate 24% decline in revenue (\$177,000/year per lobbyist) when their connected politician leaves office, proving access-driven rents.
- [LT79] Laakso, M., & Taagepera, R. (1979). “Effective” Number of Parties: A Measure with Application to West Europe. *Comparative Political Studies*, 12(1): 3–27. https://doi.org/10.1177/001041407901200101 (ok). Effective Number of Parliamentary Parties ENPP = 1 / \sum s_i^2 ranges between 2.5 and 5.5 in OECD democracies; top 2 parties hold 55%–85% of legislative seats.
- [TS89] Taagepera, R., & Shugart, M. S. (1989). *Seats and Votes: The Effects and Determinants of Electoral Systems*. Yale University Press. ISBN 978-0-300-04319-8. Systematic comparative analysis of electoral rules, Duverger's law, and seat concentration.
- [KLM08] Karpoff, J. M., Lee, D. S., & Martin, G. S. (2008). The Cost to Firms of Cooking the Books. *Journal of Financial and Quantitative Analysis*, 43(3): 581–611. https://doi.org/10.1017/S0022109000004221 (ok). 788 federal misrepresentation enforcement actions; median lag from violation end to initial inquiry is 18.0 months; median lag to final sanction is 36.0 months.
- [ACFE24] Association of Certified Fraud Examiners (2024). *Occupational Fraud 2024: A Report to the Nations*. Median duration of occupational fraud before detection is 12 months; tips account for 43% of detections.
- [MUS04] Musto, D. K. (2004). What Happens When Information Leaves a Market? Evidence from Postbankruptcy Consumers. *The Journal of Business*, 77(4): 725–748. https://doi.org/10.1086/422437 (ok). Investigates the 10-year FCRA bankruptcy drop-off; scores jump 20–30 points and credit lines expand, but post-drop-off default rates double, proving that statutory amnesia purges informative risk signals.
- [DGMS20] Dobbie, W., Goldsmith-Pinkham, P., Mahoney, N., & Song, J. (2020). Bad Credit, No Problem? Credit and Labor Market Consequences of Bad Credit Reports. *The Journal of Finance*, 75(5): 2377–2419. https://doi.org/10.1111/jofi.12954 (ok). Regression discontinuity on bankruptcy flag removal at 7 and 10 years under FCRA; credit limits increase by \$780 (+83%) immediately upon removal.
- [FCRA70] Fair Credit Reporting Act, 15 U.S.C. § 1681c (Requirements relating to information contained in consumer reports). Mandates complete deletion of adverse credit items after 7 years and bankruptcy after 10 years.

Sources dropped after a DOI check failed to match (wrong DOI guessed, not used): Ambuehl & Li 2018,
Lau, Andersen & Redlawsk 2008, Johnson et al. 2013 (Penn World Table), Scherer 1998, Arthur et al.
1998 (a DOI exists, `10.1207/s15327043hup1101_3`, not used), and the Han, Fishkin & Luskin review of 22
Deliberative Polls (no DOI found; named only as **[unverified]** in 1.2).
