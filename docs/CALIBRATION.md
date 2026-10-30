# Calibration of the simulation's world parameters and noise to empirical sources

A table adapting every world parameter, noise distribution and range in `sim/` to realistic
empirical sources, as far as they exist. It extends `docs/DATA.md` (which maps datasets to objects)
with numbers: a proposed default, range and distribution shape per parameter, the dimensionless
quantity a source can pin down, and a confidence. Documentation only: no code, default or battery
range has changed, and nothing here is validated against a run. Governed thresholds are not
calibrated here (they are governed, SigThGv L157); section 4 lists institutional analogues only.

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
"Proposal" is a realistic default, range and shape. Keys such as [YAN04] point to section 8.

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

| Source | Finding, weighted to the parameter | Bears on |
|---|---|---|
| [BAI23] Bailey et al. 2022/2023, *Current Psychology* 42, doi 10.1007/s12144-022-03573-2 (ok) | Meta-analysis, 346 effect sizes, 129 datasets, N = 17,296, judge-advisor paradigm **(abs)**. Advice-quality cues are the only unique predictor; age, gender, individualism do nothing **(abs)**. Average weight of advice (WOA) 0.39, 95% CI [0.37, 0.42], as quoted by a later paper **[unverified: not read in the original]**. | Mean weight on advice: about 0.4 pooled over advisor types; moves with perceived quality |
| [YAN04] Yaniv 2004, OBHDP 93, doi 10.1016/j.obhdp.2003.08.002 (ok); [YK00] Yaniv & Kleinberger 2000, doi 10.1006/obhd.2000.2909 (ok) | Judges shift toward advice but give their own view about two thirds to 70% (egocentric discounting); weight rises with the advisor's track record (reputation formation); normative averaging would be 0.5. Figures about 0.2–0.35 **[unverified]**. | Mean weight 0.2–0.4; weight tracks record (the sim's direction is right, its level is not) |
| [SL09] Soll & Larrick 2009, JEP:LMC 35, doi 10.1037/a0015145 (ok) | People mostly *choose* one estimate or *average*; averaging would have been more accurate for most participants **(abs)**. A secondary report gives about 50% of cases choosing (own or advisor's), 20% averaging, 30% intermediate weighting **[unverified, secondary]**; the weight distribution is described as trimodal at 0, 0.5, 1 **[unverified, secondary]**. | **Shape**: point masses at 0, 0.5 and 1 plus a spread; a large mass at 0 (stay put) |
| [BD06] Bonaccio & Dalal 2006, doi 10.1016/j.obhdp.2006.07.001 (ok) | Review: advisor expertise and confidence raise use; the judge's own knowledge lowers it; people discount advice because they know their own reasons and not the advisor's. | Own-versus-advisor asymmetry; expertise effect size not given here |
| [SSD04] Sniezek, Schrah & Dalal 2004, doi 10.1002/bdm.468 (ok); [GM07] Gino & Moore 2007, doi 10.1002/bdm.539 (ok); [HF97] Harvey & Fischer 1997, doi 10.1006/obhd.1997.2697 (ok) | Committed money raises use of *expert* advice but not novice advice **(abs)**; advice is used more when the task is hard; judges credit advisors with expertise by moving toward them. | Expert multiplier on the weight |
| [LOG19] Logg, Minson & Moore 2019, doi 10.1016/j.obhdp.2018.12.005 (ok) | Lay people lean toward algorithmic over human advice; experts do not **[unverified detail]**. | Weight a layperson gives a published model reading (`model_share`) |
| [HILL17] Hill 2017, J. Politics, doi 10.1086/692739 (ok) | Subjects update political facts as "cautious Bayesians" at about 73% of Bayes' rule, less for information inconsistent with prior beliefs; beliefs do not polarise **(abs)**. | Conservatism: effective update about 0.7 of Bayes; asymmetry for disconfirming input |
| [MOB22] Möbius et al. 2022, doi 10.1287/mnsc.2021.4294 (ok); [PE66] Phillips & Edwards 1966, doi 10.1037/h0023653 (ok); [EDW68] Edwards 1968 (chapter, no DOI; reprint https://www.cambridge.org/core/books/judgment-under-uncertainty/conservatism-in-human-information-processing/8B7029284C4E87E35765A09F768060CE, not fetched) | Updating is too little overall (conservatism) and asymmetric about self-relevant news **(abs for Möbius)**; classical result that people revise by a fraction of the Bayesian amount **[unverified size]**. | Same: conservative updating as a general property |
| [MER17] Mercier 2017, doi 10.1037/gpr0000111 (ok) | Review: communication is "much less influential than often believed"; people check plausibility, calibrate trust to competence and benevolence, evaluate arguments **(abs)**. | Epistemic vigilance: a floor of resistance even to experts |
| [DVG10] DellaVigna & Gentzkow 2010, *Annu. Rev. Econ.* 2, doi 10.1146/annurev.economics.102308.124309 (ok), NBER w15298 https://www.nber.org/papers/w15298 (200); [DVK07] DellaVigna & Kaplan 2007, doi 10.1162/qjec.122.3.1187 (ok) | The *persuasion rate* is the share of those not yet convinced who are converted **(abs: definition)**. Fox News: 3–8% of non-Republican viewers moved to vote Republican on inclusive audience measures, 11–28% on restrictive ones (as quoted from the review in a search snippet **[unverified]**). A get-out-the-vote mailer raised turnout by about 1 pp. Typical field persuasion rates are single digits to low tens of percent **[unverified range]**. | Population-level persuasion per exposure: 3–15%, not 70–100% |
| [KB18] Kalla & Broockman 2018, APSR, doi 10.1017/S0003055417000363 (ok) | 49 field experiments: the best estimate of persuasion by campaign contact and advertising in US general elections is zero **(abs)**. | Lower bound: for a settled, high-salience choice the mean effect is about 0 |
| [CHV20] Coppock, Hill & Vavreck 2020, *Sci. Adv.*, doi 10.1126/sciadv.abc4046 (ok); [HEW24] Hewitt et al. 2024, APSR, doi 10.1017/S0003055423001387 (ok) | 49 ads in 59 experiments, N = 34,000: 0.05 points on a five-point favourability scale (SD across experiments 0.07) and 0.7 pp on vote choice (SD 2 pp) **(abs)**. 146 campaign experiments, 617 ads, over 500,000 respondents: 0.8 pp (2020 presidential) to 2.3 pp (2018 down-ballot) on immediate vote choice **(abs)**. | Effect of one message: 1–2 pp of a binary opinion; small variance across messages |
| [WP19] Wood & Porter 2019, *Political Behavior*, doi 10.1007/s11109-018-9443-y (ok); [GC20] Guess & Coppock 2020, BJPS, doi 10.1017/S0007123418000327 (ok) | Backfire (moving away from counter-attitudinal evidence) is rare: essentially absent across dozens of issues (about 52 issues and 10,100 subjects **[unverified]**); three survey experiments find no backlash even under favourable conditions **(abs for GC20)**. | Backfire probability near 0 (at most 1–2% of persons): do not model repulsion; model resistance (zero movement) |
| [VDL15] van der Linden et al. 2015, PLoS ONE, doi 10.1371/journal.pone.0118489 (ok); [BD18] Bolsen & Druckman 2018, doi 10.1177/1368430217737855 (ok); [VDL19] van der Linden 2019 replication, doi 10.1016/j.jenvp.2019.01.009 (ok) | A consensus message raised *perceived* consensus (about +13% on average and up to +20% in some arms, from a Yale summary **[unverified]**); belief and policy support moved much less (gateway belief model, N = 1,104 **(abs)**). Partisan identity and politicisation "stunt" the effect **(abs for BD18)**. | Expert-consensus messaging moves beliefs by a few points, less for the opposed camp |
| [LFJ02] Luskin, Fishkin & Jowell 2002, BJPS, doi 10.1017/S0007123402000194 (ok); [FL05] Fishkin & Luskin 2005, doi 10.1057/palgrave.ap.5500121 (ok); [FAR10] Farrar et al. 2010, doi 10.1017/s0007123409990433 (ok, corrected); [FSDB21] Fishkin et al. 2021, APSR, doi 10.1017/S0003055421000642 (ok) | Deliberative Polls (information, balanced briefing, small groups): statistically significant net opinion change on many items, larger on less salient issues; a review of 22 polls reports significant change "far more rule than exception" (Han, Fishkin & Luskin, title and venue **[unverified]**). Typical item shifts 10–30 pp, up to about 30 pp on some items in America in One Room **[unverified, secondary]**; knowledge items move far more (about 20% to 74% correct on one item **[unverified]**). | Upper bound under ideal conditions (paid, balanced, moderated, attentive): a *minority* of persons move far, the majority move little |
| [MOU13] Moussaïd et al. 2013, doi 10.1371/journal.pone.0078433 (ok); [LOR11] Lorenz et al. 2011, doi 10.1073/pnas.1008636108 (ok); [BEC17] Becker et al. 2017, doi 10.1073/pnas.1615978114 (ok) | Estimates shift toward others' but weight falls with distance from one's own estimate; influence shrinks the diversity of the crowd and can reduce its accuracy. | Weight is not constant: it falls as the gap grows (a confidence interval around one's view) |
| [DMZ03] DeMarzo, Vayanos & Zwiebel 2003, doi 10.1162/00335530360698469 (ok); [ENZ19] Enke & Zimmermann 2019, doi 10.1093/restud/rdx081 (ok) | People double-count correlated information (persuasion bias; correlation neglect). | Supports source tags: untagged echoes are counted as independent (the sim's `rounds`) |
| [BUR11] Burgman et al. 2011, doi 10.1371/journal.pone.0022998 (ok); [SHA92] Shanteau 1992, doi 10.1016/0749-5978(92)90064-E (ok); [GRO00] Grove et al. 2000, doi 10.1037/1040-3590.12.1.19 (ok) | Expert status is a poor predictor of expert performance; experts are accurate only where the task has feedback and structure; mechanical prediction rarely loses to clinical judgment. | Why deferring to a *reputation* is not always right (and why weight should track audited records, which the sim does) |

### 1.3 Reading across the evidence

1. A non-expert who hears an expert keeps most of their own position. The pooled weight on advice
   is about 0.3–0.4 even in lab tasks that reward moving, and about 0 for settled political choices.
   With the advisor's quality visible the weight rises, but the mean stays well below 0.5.
2. The distribution is not a bell. It is a *mixture*: a large mass at exactly 0 (the person stays
   put), a spike near 0.5 (averaging), a small spike near 1, and a spread in between.
3. Mean persuasion per message in the field is 1–3 pp of a binary opinion; persuasion rates
   (share of the unconvinced converted) are single digits to low tens of percent for sustained
   exposure.
4. Backfire is rare: model resistance, not repulsion.
5. Deliberation under ideal conditions moves a minority of persons a long way, mostly on facts and
   on low-salience items. That is the upper bound on weight, not the typical weight.
6. Updating is conservative: about 0.7 of Bayes' rule (Hill) or less (Edwards), and asymmetric
   against disconfirming news.

### 1.4 Proposed per-person weight on advice

Let *w* be the share of the way a person moves from their own reading toward the pooled reading of
a source they judge better than themselves. Proposed (one draw per person per domain, redrawn
slowly):

| Component | Probability | Value |
|---|---|---|
| Stay put (never moves) | 0.30 | w = 0 |
| Average with the source | 0.20 | w ≈ 0.5 (narrow, SD 0.05) |
| Defer (adopt the source's reading) | 0.05 | w ≈ 1 (narrow, SD 0.05) |
| Intermediate weighting | 0.45 | w ~ Beta(2, 3) (mean 0.40, SD 0.20) |

Mixture mean is 0.33 (0.10 + 0.05 + 0.18) and 0.32 of persons sit at or below w = 0.1 (0.30 at zero
plus 0.45 × 0.052 from the Beta). That matches the pooled mean of about 0.3–0.4 [BAI23, YAN04] and a
choosing share near a third to a half [SL09]. Variation to explore: the mean of *w* from 0.15
(settled, politicised issues; [KB18], [BD18]) to 0.5 (visible expert, hard task, incentives;
[SSD04], [GM07]). A robustness sweep should move the stay-put mass between 0.1 and 0.6. Three
conditioning rules, each with direct support:

- **Quality cue multiplier.** When the source's audited record is visible and clearly better, shift
  mass from 0 to the Beta part (stay-put 0.30 → 0.20, mean about 0.40; [BAI23], [SSD04]); when the
  record is invisible or the topic is politicised, shift the other way (stay-put 0.45, mean about
  0.25; [BD18]).
- **Distance falloff.** Multiply *w* by a factor decreasing in the gap between the voter's reading
  and the source's, in units of the domain's spread (a bounded-confidence rule; [MOU13]).
- **Backfire.** Probability 0 by default; at most 0.01–0.02 of persons repel on a politicised
  topic, as a robustness test only [WP19, GC20].

Population-level targets this should reproduce (validation, not fit): about 1–3 pp of opinion change
per message exposure; a persuasion rate of 3–15% over a sustained campaign [DVG10, DVK07, CHV20,
HEW24]; deliberation moving a minority a long way on facts [FSDB21, LFJ02]; consensus messaging
raising the perceived expert share much more than the held belief [VDL15].

**Confidence: medium** for the mean and the mixture (the lab literature is large and consistent, but
the exact masses come from one secondary report); **low** for the conditioning multipliers and the
mapping from lab estimation tasks to votes on options.

**Caveats (proxy validity).** The judge-advisor paradigm measures numeric estimates, not votes on a
policy menu. A vote is a sign (the code uses `sign(reading)`), so weights on advice are real only
through their effect on whether the reading's sign flips; with *w* < 0.5 on average, most experts
change few signs unless the voter's own signal is weak. Field persuasion studies measure an output
(vote, turnout), the quantity Benefuture can read. Sources study mostly Western and student or online
panels. The effect of *audited records* on trust (the sim's mechanism) has no direct field analogue
except reputation systems on e-commerce sites ([RZSL06], [CH10]).

**Relation to the code (a proposal for an increment, not a change made here).** Replace "hear a
better source at weight = record" by weight = record × *w_i*, where *w_i* is drawn per person from
the mixture, keeping `p_novel` for novel input. The sim's own floor `own ≥ 0.1` already sets a
minimum weight on one's own view; the data say the voter's own weight is about 0.6–0.7 on average
and 1.0 for the stay-put mass. Acceptance test: mean *w* in 0.25–0.45; share at exactly 0 in
0.2–0.45; no sign flips beyond a set share when a better source disagrees with a confident voter.
Counterexample test: with *w* = 1 for all, governance accuracy over-rewards a single captured
expert (the sim's present behaviour), which the field's resistance would dampen.

### 1.5 Other deliberation parameters (M5)

| Parameter (file) | Now (range) | Represents; dimensionless target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `n_contacts` (m5.jl) | 5 (0–20) | Persons each voter hears when `info_handling` is off | Core discussion network about 2–3 persons; plus weak ties; range 0–10; heavy-tailed degree, homophilous | [MCP06] McPherson, Smith-Lovin & Brashears 2006, doi 10.1177/000312240607100301 (ok): mean core discussion network 2.08 in 2004, modal 0 **[unverified numbers]**; [MSC01] McPherson et al. 2001, doi 10.1146/annurev.soc.27.1.415 (ok) | Medium. Self-reported "important matters" network; media and online sources are not contacts |
| `p_novel` (0.05; 0–0.2) | Chance a weaker source brings novel input to a listener | No direct source. Weak-tie information value is established qualitatively | none | Low. Treat as free |
| `rounds` (1; 1–5) | Passes of readings before the vote | Number of echo passes: online reshare chains are mostly size 1 with rare deep cascades | Mostly 1; tail to 5+ | [VOS18] Vosoughi, Roy & Aral 2018, doi 10.1126/science.aap9559 (ok); Goel et al. 2016 in `docs/DATA.md` | Low-medium |
| `camp_bias` (0; 0–2) | Experts' paradigm lean, in units of signal | Share of expert disagreement due to systematic lean; no direct source. Crowd-rated notes show bridging needs cross-camp agreement | 0.2–1 in contested domains, 0 in settled ones | Community Notes, Polis (`docs/DATA.md` section 10) | Low |
| `tag_liars`, `tag_lie` (none; 0–30%) | Share misattributing or omitting origins | Quotation and citation errors: 25.4% of quotations in medical papers contain an error, 11.9% major **(abs)**; citation distortion builds unfounded authority | Fraction of readings with false origin 5–25% (error, mostly unintentional); intentional share unknown | [JB15] Jergas & Baethge 2015, doi 10.7717/peerj.1364 (ok); [GRE09] Greenberg 2009, doi 10.1136/bmj.b2680 (ok) | Medium for error rate; low for intent |
| `source_tags` echoes | off | Double counting of one origin | Correlation neglect is the norm: treat naive as default and tags as the intervention | [DMZ03], [ENZ19] | Medium |
| `model_σ0`, `p_new_model`, `improve_*`, `scale_min` (M5) | 5, 0, −0.1, 0.3, 0.1 | See section 3.3 (models) | | | |
| `model_capture` | none | A top model publishes one side for a spell | Sponsor bias: industry-funded studies report favourable results and conclusions more often than other sponsors **(abs: direction)**; rating inflation from competition between raters | [LUN17] Lundh et al. 2017, doi 10.1002/14651858.MR000033.pub3 (ok); [BFS12] Bolton, Freixas & Shapiro 2012, doi 10.1111/j.1540-6261.2011.01708.x (ok); [BM11] Becker & Milbourn 2011, doi 10.1016/j.jfineco.2011.03.012 (ok); [DAL06] Dal Bó 2006, doi 10.1093/oxrep/grj013 (ok) | Medium for existence and direction; low for size (relative risk of favourable results about 1.3 **[unverified]**) |
| `p_apparent` (0.7; 0.2–1) | Decision's optimality becomes apparent | No direct source. Replication and evaluation analogues: most policies are never rigorously evaluated | 0.1–0.6 for most social decisions | none | Low |

---

## 2. Method for the remaining tables

Each row gives: parameter (code name, file), now (range), what it represents and the dimensionless
target, proposal (default; range; shape), sources, confidence and caveats. Where the proposal
lies outside the current range the row says so, and section 7 collects the disagreements.

## 3. Parameters by area

### 3.1 The world's plans and its measurement (`ToyParams`, M0; `marker_σ`, `classify_σ`)

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `ToyParams.spread` (m0.jl) | 1.0 (0.5–3) | Scatter of a plan's effect across beings, relative to its mean (CV of treatment effect) | Heavy: between-site SD of effects is usually at or above the mean effect; CV 1–3; heavy-tailed, signed | [VIV20] Vivalt 2020, doi 10.1093/jeea/jvaa019 (ok): heterogeneity across impact evaluations is large relative to the mean **[unverified size]**; [MEA19] Meager 2019, doi 10.1257/app.20170299 (ok); [BTY21] Bryan, Tipton & Yeager 2021, doi 10.1038/s41562-021-01143-3 (ok) | Medium. Heterogeneity across *sites* not across beings within a plan |
| `touch`, `shift` (0.05–0.3, 0.5) | Share of beings a plan touches; scatter of its mean | Interventions reach a minority; effect sizes: median 0.1 SD of test score in education trials | touch 0.01–0.3 (right-skewed); shift as 0.1–0.3 of the spread | [KRA20] Kraft 2020, doi 10.3102/0013189X20912798 (ok) | Low-medium |
| `marker_σ` (0.05; 0.02–0.2) | Marker error as a share of spread | Reliability r of a test or survey item: noise/spread = sqrt(1 − r). Life-satisfaction single item r about 0.6–0.7 (noise 0.55–0.63); good tests r 0.9 (noise 0.32); administrative counts r above 0.99 (noise 0.1) | Understanding via tests: 0.3 (0.15–0.5); happiness via single items: 0.6 (0.5–0.7); behavioural counts: 0.05–0.15 | `docs/DATA.md` section 2 (Krueger & Schkade 2008, doi 10.1016/j.jpubeco.2007.12.015; Lucas & Donnellan 2012); PISA plausible values | High that 0.05 is optimistic for survey markers; the battery's top (0.2) is the realistic *bottom* for self-report markers. Units: depends on whether `marker_σ` is relative to the population SD |
| `classify_σ`, `spread` of causal signatures (0.03; 0.03–0.1) | Noise in classifying an action to a domain | Inter-rater agreement kappa about 0.6–0.8 for coding tasks (substantial) | Misclassification 10–25% of items; modelled as signature noise 0.05–0.2 | Landis & Koch 1977 conventions **[unverified, no link]**; [PAN-WVC] https://webis.de/data/pan-wvc-10.html (200) | Low |
| `attribution_σ` (0.1; 0–0.3) | Error in separating an upstream output's part | Overclaiming: co-authors or spouses' claimed shares of a joint product sum to well over 100% (about 120–140% **[unverified]**) | 0.1–0.4 relative; biased upward for self | [RS79] Ross & Sicoly 1979, doi 10.1037/0022-3514.37.3.322 (ok) | Medium. Egocentric bias is directional, the sim's noise is symmetric |
| `cost_σ` (0.1; 0–0.3) | Resource accounting error | Stock assessments carry CVs of 0.2–0.5 **[unverified]**; firms' cost estimates err by 10–30% | 0.1–0.3 | Ralston et al. 2011, Fishery Bulletin **[unverified, no link]** | Low |

### 3.2 Skills, agents, execution and choice noise

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `DomainAgent.skills` (m3c; battery 0.6 or 0.1–0.5) | Uniform / fixed | Spread and tail of productivity: CV by job complexity about 0.2 (simple), 0.3 (medium), 0.5 (complex) **[unverified numbers]**; individual output in science, arts, sport follows a Paretian (power-law) tail, not a bell; plant TFP 90-10 ratio about 2 in the US and 4–5 in India and China **[unverified]** | Log-normal with log-SD 0.3–0.5 for ordinary tasks; Pareto tail (exponent 2–3) for research and creative output; top 1% hold 10–30% of output | [HUN90] Hunter, Schmidt & Judiesch 1990, doi 10.1037/0021-9010.75.1.28 (ok); [OBA12] O'Boyle & Aguinis 2012, doi 10.1111/j.1744-6570.2011.01239.x (ok); [SYV11] Syverson 2011, doi 10.1257/jel.49.2.326 (ok); [SIN16] Sinatra et al. 2016, doi 10.1126/science.aaf5239 (ok) | Medium-high for heavy tails. Output is an output (the sim's skills are latent) |
| `sloppiness` (0; 0–0.6) | Share of a plan not carried out as chosen | Intention-behaviour gap: a medium-large change in intention (d = 0.66) yields a small-medium change in behaviour (d = 0.36) **(abs)**; about 47% of those intending to act fail to **[unverified]** | Default 0.25 (0.1–0.5) for individuals; for projects see section 3.10 | [WS06] Webb & Sheeran 2006, doi 10.1037/0033-2909.132.2.249 (ok); [SHE02] Sheeran 2002, doi 10.1080/14792772143000003 (ok) | Medium. Default 0 is a limiting case; world default should be mildly imperfect (8.33) |
| `signal_σ`, `ability_spread` (M5; 1, 0.5; 1–40, 0–1.5) | A voter's signal noise (a probability correct p = Φ(1/σ)) and its scatter | Competence of ordinary voters on a hard question: 0.55–0.75 correct (σ = 1 gives 0.84, σ = 2 gives 0.69, σ = 4 gives 0.60, σ = 40 gives 0.51). Voting correctly (matching own preferences) about 75% in US presidential elections **[unverified]**; scatter is wide (informed minority, uninformed majority) | Non-experts σ 2–4 (p 0.6–0.69); experts in own domain σ 0.5–1 (p 0.84–0.98); ability spread 0.5–1.5; bimodal informed/uninformed | [LR97] Lau & Redlawsk 1997, doi 10.2307/2952076 (ok); [BAR96] Bartels 1996, doi 10.2307/2111700 (ok); [GAL07] Galton 1907 (Vox Populi), doi 10.1038/075450a0 (ok) | Medium. Condorcet competence is not directly observable; this is a cross-domain proxy |
| `choice_σ`, `choice_gain`, `ability_spread` (economy; 0.5, 5, 0.5) | Choice noise in co-funding judgements, with skill gain | Judgement noise between professionals: "noise audits" found median pairwise differences of about 50% between underwriters on identical cases **[unverified]**; grant reviewers show no agreement on the same applications **(abs)** | CV 0.3–0.6 of the judged quantity; low agreement for ex ante evaluation of novel work | Kahneman, Sibony & Sunstein 2021, *Noise* (book, ISBN 978-0316451406 **[unverified link]**); [PIE18] Pier et al. 2018, doi 10.1073/pnas.1714379115 (ok); [FAN16] Fang et al. 2016, doi 10.7554/eLife.13323 (ok) | Medium |
| `view_σ`, `pred_σ` (M7; 0.2, 0.2; 0–1) | Entity's noisy view of reality, its prediction noise (G run by everyone, 8.50) | As above: single-person estimation error CV 0.3–0.6; wisdom-of-crowd median error far lower | 0.3–0.6 default; range 0.1–1 | [GAL07], [LOR11], Kahneman et al. 2021 | Low-medium |
| `p_act`, `action_scale`, `options` (0.2, 0.05, 3) | Share acting per step, share of a plan per action, options per entity | Participation inequality: about 1% create, 9% contribute occasionally, 90% observe (the 90-9-1 rule) | p_act as share active in a period: 0.01–0.3, very skewed across persons | [CAC14] Carron-Arthur et al. 2014, doi 10.1016/j.invent.2014.09.003 (ok); Nielsen 2006, https://www.nngroup.com/articles/participation-inequality/ (200) | Medium for skew; low for step mapping |
| `p_informed`, `diligence` (0.8, 0.95) | A guardian learning of a hazard in time; acting on a known duty | Compliance with a known protocol: hand-hygiene compliance averages about 40% at baseline and reaches 60–70% with interventions **[unverified numbers]** | diligence 0.5 (0.3–0.9) for routine duties without audit; 0.9+ only with audit and stakes | [ERA10] Erasmus et al. 2010, doi 10.1086/650451 (ok) | Medium. A professional-safety domain; the default 0.95 is high |
| `p_foresee` (0.5; 0–1) | Share of side effects foreseeable | Preventable share of in-hospital adverse events: 43.5% median **(abs)**; negligent share about 28% in the Harvard study **[unverified]** | 0.43 (0.25–0.6) | [DEV08] de Vries et al. 2008, doi 10.1136/qshc.2007.023622 (ok); [BRE91] Brennan et al. 1991, doi 10.1056/NEJM199102073240604 (ok) | Medium |

### 3.3 Metric models and forecasters

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `σ_leaf` (0.15; 0.05–0.45) | Established leaf model's error relative to the domain's spread | Residual SD / outcome SD = sqrt(1 − R²). Numerical weather prediction: anomaly correlation about 0.95 at day 3, 0.8 at day 6 (noise 0.3–0.6) **[unverified numbers]**; social and economic forecasting typically R² of 0.2–0.6 (noise 0.65–0.9) | Natural-science mature domain: 0.3 (0.15–0.6); social-science domain: 0.7 (0.5–0.9); 0.15 is a limiting case reached only at short horizons in physics | [BAU15] Bauer, Thorpe & Brunet 2015, doi 10.1038/nature14956 (ok); [MEL14] Mellers et al. 2014, doi 10.1177/0956797614524255 (ok); [CRA22] Cramer et al. 2022, doi 10.1073/pnas.2113561119 (ok) | Medium. Largest single mismatch between default and field |
| `σ_branch`, `σ_coarse` (0.3, 0.45; 0.2–0.6, 0.35–0.75) | Parent and coarse models | Coarse models ("it will be warmer in summer"): noise 0.8–1 of spread (no information beyond base rate) | branch 0.6 (0.4–0.9), coarse 0.85 (0.7–1.0); keep order leaf < branch < coarse | as above | Low-medium |
| `bias_σ` (0.1; 0–0.2) | Systematic model bias, relative | Overconfidence and optimism: CFOs' 80% intervals contain the truth only about 36% of the time **[unverified size]**; forecasters over-extreme | 0.1–0.3 relative bias; larger for judgmental than statistical models | [BDGH13] Ben-David, Graham & Harvey 2013, doi 10.1093/qje/qjt023 (ok); [MH08] Moore & Healy 2008, doi 10.1037/0033-295X.115.2.502 (ok) | Medium |
| `p_extremist`, `extremise` (0; 0.5) | New models extremising credences; share of uncertainty stated | Aggregates of forecasts are under-extreme; individuals are over-extreme | Extremising factor 1.2–2.5 for aggregates; share of overconfident individuals 0.3–0.6 | [BAR14] Baron et al. 2014, doi 10.1287/deca.2014.0293 (ok); [SAT14] Satopää et al. 2014, doi 10.1016/j.ijforecast.2013.09.009 (ok) | Medium |
| `p_new_model`, `improve_drift`, `improve_σ`, `scale_min` (0, −0.1, 0.3, 0.1; 0–0.1, −0.3–0.1, 0.1–0.5, 0.05–0.3) | Arrival chance per step and domain; log error ratio of an arrival to the best; scatter; least error vs bootstrap | In forecasting hubs and competitions new entrants join often and most are worse than the incumbent ensemble; the best method beats a standard benchmark by about 10–20% (log ratio about −0.1 to −0.2) **[unverified: M4 winner OWA about 0.82 against 1 for the benchmark]** | `improve_drift` +0.0 to +0.3 for a *typical* new model (mostly worse), with a thin lower tail to −0.2 for the best; `improve_σ` 0.3–0.5; `scale_min` 0.2–0.5 (floor is high in social domains) | [CRA22], [MAK20] Makridakis et al. 2020, doi 10.1016/j.ijforecast.2019.04.014 (ok), `docs/DATA.md` section 7 | Medium for the sign (typical entrants are worse); the sim's average improvement of −0.1 per arrival is the *best-entrant* case |
| `model_σ0` (5; 0.5–20) | Bootstrap model noise in M5 | Initial expert reading accuracy | Express relative to signal: p about 0.6–0.7 for first-generation models (σ 2–4 where the truth is 1) | as `signal_σ` | Low |
| `max_credence` (0.99; governed) | Credence cap | Metaculus restricts forecasts to 1–99% **[unverified, 403]** | Analogue only (section 4) | | |

### 3.4 Ledgers, reputation and memory

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `λpos`, `λneg` (0.05, 0.02; governed) | Decay of rights and wrongs | Human forgetting is a power law, not an exponential [RW96]; negative information is stickier than positive [BAU01]; legal analogue in section 4 | Ratio of half-lives (λpos/λneg) 2–4; use a power-law or a two-rate mixture; half-life of a positive record about a quarter of `window` | [RW96] Rubin & Wenzel 1996, doi 10.1037/0033-295X.103.4.734 (ok); [MD15] Murre & Dros 2015, doi 10.1371/journal.pone.0120644 (ok); [BAU01] Baumeister et al. 2001, doi 10.1037/1089-2680.5.4.323 (ok) | Low-medium. Decay is governed, so this is a world-realism note, not a default |
| `memory_loss` (0.02; 0–0.1) | Records failing to reach memory | Digital records decay: odds that a dataset is available fall about 17% a year with article age **[unverified]**; one in five scholarly articles suffers reference rot (link rot or drift) **(abs: one in five in the title)** | 0.02–0.15 per year; heavy for informal records, low for official | [VIN14] Vines et al. 2014, doi 10.1016/j.cub.2013.11.014 (ok); [KLE14] Klein et al. 2014, doi 10.1371/journal.pone.0115253 (ok) | Medium. Loss is not random (selection) |
| `vigilance` (0.05; 0.01–0.3) | Chance per step an agent reads another actor's record | People rarely read: 74% skip privacy policies **[unverified]**; between 0.05% and 0.2% of consumers open the terms of service **[unverified]**; salience of a tax changes behaviour about 8% | 0.001–0.02 per step for passive readers; 0.1–0.5 only for stakeholders with a stake or a bounty | [BAK14] Bakos, Marotta-Wurgler & Trossen 2014, doi 10.1086/674424 (ok, corrected); [OOH20] Obar & Oeldorf-Hirsch 2020, doi 10.1080/1369118X.2018.1486870 (ok); [CLK09] Chetty, Looney & Kroft 2009, doi 10.1257/aer.99.4.1145 (ok); [SIM03] Sims 2003, doi 10.1016/S0304-3932(03)00029-1 (ok) | Medium. Battery severity 0 (0.3) is unrealistically attentive |
| `pattern_attention`, `stake_attention` (9, 2; 0–20, 0–5) | Multiplier on reading a negative-ledger actor; own stake | Attention concentrates on bad news and on stakeholders (journalists on large frauds, employees with money at stake) | Multiplier 3–20 on negative pattern; 2–10 for stakeholders | [DMZ10] Dyck, Morse & Zingales 2010, doi 10.1111/j.1540-6261.2010.01614.x (ok): monetary incentives explain employee whistleblowing; reputational incentives weak except for journalists in large cases **(abs)** | Medium |
| `endowment` (5), `overflow_*`, balance Gini | Initial balances; concentration | Wealth is Pareto-tailed: top 0.1% US wealth share about 20% **[unverified]**; income Gini 0.25–0.6, wealth Gini 0.6–0.9 | Initial balance log-normal, log-SD 0.5–1.0; tail exponent 1.5–2 | [GAB16] Gabaix 2016, doi 10.1257/jep.30.1.185 (ok); [SZ16] Saez & Zucman 2016, doi 10.1093/qje/qjw004 (ok); https://wid.world/ | Medium for shape; endowment has no unit |

### 3.5 Audit, deception, whistleblowing, collusion and identity

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `deceit` (0; 0–2), prevalence | Magnitude of fooling the metric models; share of deceivers | Most people cheat a little or not at all; a few cheat fully; about 2% admit fabricating or falsifying research and about 34% questionable practices **[unverified second number]** | Magnitude: point mass at 0 for 55–70%, small cheaters 25–40% (size 10–20% of the available gain), full cheaters 2–5%; bimodal | [MAZ08] Mazar, Amir & Ariely 2008, doi 10.1509/jmkr.45.6.633 (ok); [GER19] Gerlach, Teodorescu & Hertwig 2019, doi 10.1037/bul0000174 (ok); [ABE19] Abeler, Nosenzo & Raymond 2019, doi 10.3982/ECTA14673 (ok); [FAN09] Fanelli 2009, doi 10.1371/journal.pone.0005738 (ok) | Medium-high for shape (honest majority, few big liars) |
| `p_trace` (0.5; 0.1–0.9) | Examination establishing a revealed deception | Detection of fraud: only about a third of corporate fraud is ever detected **[unverified]** (`docs/DATA.md`); price-fixing conspiracies are indicted with probability 0.13–0.17 per year **(abs)**; tips detect about 43% of occupational frauds **[unverified]** | Per-year detection 0.1–0.35; given a revelation reaching an examiner, 0.5–0.8 | [BE91] Bryant & Eckard 1991, doi 10.2307/2109581 (ok, corrected); [DMZ23] Dyck, Morse & Zingales 2023, doi 10.1007/s11142-022-09738-5 (ok); ACFE Report to the Nations 2024, https://www.acfe.com/report-to-the-nations/2024/ (200) | Medium. Detection (per year) differs from establishing (given a report) |
| detection lag | (via `vigilance`) | Time to detect: Wikipedia vandalism reverted in minutes; hoaxes mostly removed quickly but a small number survive long **(abs)**; retractions take 32.9 months on average, 49.8 months before 2002 and 23.8 months after **(abs)** | Geometric-like lags with a heavy tail: median minutes (cheap, watched), months (science), years (cartels: durations bimodal, about 5 years on average **(abs)**) | [PRI07] Priedhorsky et al. 2007, doi 10.1145/1316624.1316663 (ok); [VWD04] Viégas et al. 2004, doi 10.1145/985692.985765 (ok); [KUM16] Kumar, West & Leskovec 2016, doi 10.1145/2872427.2883085 (ok); [STE13] Steen et al. 2013, doi 10.1371/journal.pone.0068397 (ok); [LS06] Levenstein & Suslow 2006, doi 10.1257/002205106776162681 (ok); [GH13] Geiger & Halfaker 2013, doi 10.1145/2491055.2491061 (ok) | High for the heavy-tailed shape |
| `p_false_trace` (0.01; 0–0.1) | Honest actor wrongly convicted | Malpractice claims: a few percent with no injury and over a third with no error **[unverified]**; false conviction among death-sentenced defendants at least 4.1% **[unverified]**; bots set to 0.1% false positives **[unverified]** | 0.01–0.05; higher in adversarial, high-stakes settings | [STU06] Studdert et al. 2006, doi 10.1056/NEJMsa054479 (ok); [GOS14] Gross et al. 2014, doi 10.1073/pnas.1306417111 (ok) | Medium |
| whistleblowing, `adv_z`, AdvAp response | (world) | Who reveals: employees, media, industry regulators, not standard monitors; monetary incentives raise employee revelation **(abs)**; revelation shares: employees about 17%, media 13%, tips 43% (ACFE) **[unverified]** | Reveal chance given a witness 0.1–0.4 (no reward), up to 0.5–0.7 with a 10–30% reward | [DMZ10]; SEC programme https://www.sec.gov/whistleblower [403]; ACFE | Medium |
| `collusion_gain`, `loyalty`, `p_weigh` (1, 0, 0.05) | Gain to each from a hidden defection; revealing cost | Defection rates in prisoner's dilemmas: about 47% cooperate on average, driven by the temptation/risk ratio; cartels collapse quickly or last long (bimodal) | `p_weigh` 0.05–0.3 per period; loyalty as a cost 0–10 of gain; cartel lifetimes bimodal | [SAL95] Sally 1995, doi 10.1177/1043463195007001004 (ok); [MEN18] Mengel 2018, doi 10.1111/ecoj.12548 (ok); [MIL09] Miller 2009, doi 10.1257/aer.99.3.750 (ok): leniency increases detection; [LS06] | Medium-low for mapping |
| `whitewash` (0; 0–0.1), `bind_miss` (0.1; 0.01–0.5), `bind_clusters` | Identity change; missing a new identity | Sockpuppetry is common but a small share of accounts; cheap pseudonyms make reputations worthless without a cost to entry | whitewash 0.01–0.1 of adversaries per period; bind_miss 0.05–0.3 for behavioural linking | [KUM17] Kumar et al. 2017, doi 10.1145/3038912.3052677 (ok); [FR01] Friedman & Resnick 2001, doi 10.1111/j.1430-9134.2001.00173.x (ok); [DOU02] Douceur 2002, doi 10.1007/3-540-45748-8_24 (ok) | Low-medium |
| `launder` (0; 0–1), `frivolous` (0; 0–1) | Harm laundering; frivolous reports | No direct source. Bug-bounty programmes see many invalid and duplicate reports (Hacktivity) | none; measure from HackerOne data | `docs/DATA.md` section 12 | Low |
| `repair_efficiency` (0; 0.2–1) | Repair restoring harm | Life satisfaction recovers from widowhood and unemployment only partly and slowly (years) | 0.3–0.7 over a window of 5–10 years; incomplete for loss of a spouse or a job | [CDGL08] Clark et al. 2008, doi 10.1111/j.1468-0297.2008.02150.x (ok); [LUC07] Lucas 2007, doi 10.1111/j.1467-8721.2007.00479.x (ok) | Medium |

### 3.6 Delegation and participation

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `p_delegate` (0; 0–1) | Chance of delegating when unaffected enough | In LiquidFeedback, a minority of users receive many delegations, super-voters have high theoretical power but mostly vote with the majority **(abs)**; in DAOs voting rights are highly concentrated and turnout is low **(abs)** | Share delegating 0.1–0.4 with a heavy-tailed in-degree (a few delegates get most); the delegating share rises when the stake is low | [KLI15] Kling et al. 2015, doi 10.1609/icwsm.v9i1.14618 (ok), arXiv 1503.07723; [FMW24] Fritsch et al. 2024, doi 10.1016/j.bcra.2024.100208 (ok); [FEI23] Feichtinger et al. 2023, arXiv 2302.12125; [KMP21] Kahng et al. 2021, doi 10.1613/jair.1.12261 (ok); [BER25] Berinsky et al. 2025, doi 10.1287/mnsc.2023.02470 (ok) | Medium for the shape; low for the share delegating **[unverified numbers]** |
| `participation` (0.9; 0.6–1) | Experts joining co-funding | Voter turnout in national elections about 60–70%; compulsory voting about 90% | 0.5–0.9 depending on duty and cost | [CG16] Cancela & Geys 2016, doi 10.1016/j.electstud.2016.03.005 (ok); https://www.idea.int/data-tools/data/voter-turnout-database | Medium |
| `optional_below`, impact thresholds | governed | Duty to vote above a threshold | analogue only | | |

### 3.7 Teaching, research and innovation (M7)

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `ε` (0.3 in readings; 0–0.6) | A lesson's share of the teacher's lead | Gain per course divided by the teacher-learner gap. A year of school gives 0.3–0.4 SD for grades 4–8 and 0.5–1.5 SD earlier; a teacher or tutor is 2–4 SD ahead; tutoring adds about 0.37 SD (a third) **[unverified]** | Per course (one year): 0.1–0.2, range 0.03–0.4; per hour: orders of magnitude lower | [HBBL08] Hill et al. 2008, doi 10.1111/j.1750-8606.2008.00061.x (ok); [KRA20] Kraft 2020; Nickow et al. 2020 (NBER w27476); [BLO84] Bloom 1984, doi 10.3102/0013189X013006004 (ok) | Medium for magnitude, low for the lead gap (not observable in SD units) |
| teacher quality spread | (implicit) | SD of teacher effects about 0.1–0.2 SD of student scores | Multiplier on ε: log-normal CV 0.4–0.6 | [ROC04] Rockoff 2004, doi 10.1257/0002828041302244 (ok); [NKH04] Nye et al. 2004, doi 10.3102/01623737026003237 (ok); [HR12] Hanushek & Rivkin 2012, doi 10.1146/annurev-economics-080511-111001 (ok); [CFR14] Chetty et al. 2014, doi 10.1257/aer.104.9.2593 (ok) | Medium-high |
| `reception_σ` (0.5; 0–1.5) | Learners' reception scatter around the lesson's share | CV of individual gains; gains correlated 0.7 pre-post imply a gain SD of about 0.77 of the score SD against a mean gain of 0.3–0.4 (CV 2, inflated by test noise) | 0.8 (0.4–1.5), right-skewed (a few learn a lot) | [HBBL08]; [VIV20]; [BTY21] | Low-medium |
| `class`, `lessons` (10, 3; not set) | Class size and lessons | OECD average class about 21 (primary) and 23 (lower secondary) **[unverified]**; STAR: classes of 13–17 vs 22–25 raised scores a few percentile points; fade-out of gains over years | class 20–25 (5–40); effect of class size small (0.1–0.2 SD for a 7-student reduction) **[unverified]** | [KRU99] Krueger 1999, doi 10.1162/003355399556052 (ok); [BDOY16] Bailey et al. 2016, doi 10.1080/19345747.2016.1232459 (ok); OECD Education at a Glance 2023 [403] | Low-medium |
| `research_share` (0.1; governed) | Share of time on research | OECD gross R&D spend about 2.7% of GDP; world about 2.6%; researchers under 1% of employment **[unverified]** | Analogue only (section 4) | World Bank https://data.worldbank.org/indicator/GB.XPD.RSDV.GD.ZS (200); OECD MSTI [403]; [BJVW20] Bloom et al. 2020, doi 10.1257/aer.20180338 (ok) | The sim's research stands for all learning beyond the frontier; unaligned by design |
| `p_research` (0.05; 0.01–0.2) | Chance a research attempt succeeds | Phase-transition success of drug development: 13.8% overall (older 10.4%), 3.4% in oncology **(abs for oncology)**; grant success about 20% (NIH); success is rarer and heavy-tailed with novelty | 0.02–0.15 per attempt; heavily domain-dependent | [WSL19] Wong, Siah & Lo 2019, doi 10.1093/biostatistics/kxx069 (ok); [HAY14] Hay et al. 2014, doi 10.1038/nbt.2786 (ok); NIH success rates https://report.nih.gov/funding/nih-budget-and-spending-data-past-fiscal-years/success-rates (200) | Medium |
| `research_σ` (1; 0.5–2) | Scatter of researchers' chance | A personal multiplier stable over a career; the best work falls at random within a career | Log-normal log-SD 0.5–1 | [SIN16], [OBA12] | Medium |
| `research_gain` (2; 0.5–5) | Size of a breakthrough | Value of innovations and patents is Pareto-tailed (exponent near 1): most worth little, a few worth most | Pareto tail, exponent 1–1.5, scaled to median 1 | [SV07] Silverberg & Verspagen 2007, doi 10.1016/j.jeconom.2006.10.017 (ok); [KPSS17] Kogan et al. 2017, doi 10.1093/qje/qjw040 (ok); [PLF23] Park, Leahey & Funk 2023, doi 10.1038/s41586-022-05543-x (ok) | Medium |
| `p_innovate` (0.01; 0–0.05) | In-job innovation chance | About half of EU enterprises report product or process innovation over three years (Eurostat CIS) **[unverified]** | 0.05–0.2 per year at firm level; far lower for radical innovation | https://ec.europa.eu/eurostat/web/science-technology-innovation/database (200) | Low-medium |
| `p_teachable` (0.5; 0–1), `research_cost` | Share codifiable; cost | Tacit knowledge share: no source | none | | Low |
| decline of research productivity | (constant `p_research`) | Ideas get harder to find: researchers needed per unit of growth rise steeply | Make the chance fall as the frontier rises (rate about 5% per year in the cases studied **[unverified]**) | [BJVW20] | Medium (validation target) |

### 3.8 Population (M7 deaths and births)

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `p_birth` (0.02; 0–0.1) | Chance of a birth option per step | Crude birth rate about 17 per 1,000 per year (world, about 6 in Japan and Italy, about 45 in Niger) **[unverified]** | 0.017 per year (0.006–0.045), age-structured | UN WPP https://population.un.org/wpp/ (200); HMD https://www.mortality.org/ (200) | High, given a step mapping |
| death hazards (rung M7) | fixed | Mortality rises about 8–9% per year of age (Gompertz), doubling in 8 years; crude death rate about 7.5 per 1,000 **[unverified]** | Age-specific hazard from life tables | WPP; HMD | High |
| `growth` (0.1; 0–0.3) | A death's predicted growth per step | Foreclosed future: no direct source | none (a model of the value of a life, 8.47 [P]) | | Low |
| `birth_pred_σ` (0.5; 0.2–2), `pool` | Error of birth-prediction models | Fertility projections: wide intervals, TFP 80% interval widening to about ±0.5 children by 2100 **[unverified]** | 0.3–1 relative to the mean | [RAF12] Raftery et al. 2012, doi 10.1073/pnas.1211452109 (ok) | Medium-low |
| `inherit` (0.5; 0–1), `birth_spread` (1; 0.5–2) | Newborn's mature levels: inheritance from the causer, scatter | Parent-child correlation in education about 0.4–0.5; earnings elasticity about 0.4 in the US; heritability about 0.5 across traits | inherit 0.3–0.5 (education/cognition), 0.1–0.3 (happiness) **[unverified for happiness]** | [HER07] Hertz et al. 2007, doi 10.2202/1935-1682.1775 (ok); [COR13] Corak 2013, doi 10.1257/jep.27.3.79 (ok); [POL15] Polderman et al. 2015, doi 10.1038/ng.3285 (ok) | Medium. The sim's "inheritance" is causal, not genetic: a proxy |
| `settle_σ`, `income`, `birth_joy` | | no source | none | | Low |

### 3.9 Harm, hazards, side effects and black swans

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `p_side` (0; 0–0.2), `side_share` (0.3), `side_size` (1) | Chance an action has side harm; share of touched beings harmed; size | In-hospital adverse events: 9.2% of admissions (median), 43.5% preventable, 7.4% lethal **(abs)**; 18% of patients harmed in a US study **[unverified]** | `p_side` 0.05–0.1 in complex domains, 0.01 in simple ones; severity heavy-tailed | [DEV08]; [BRE91]; [LAN10] Landrigan et al. 2010, doi 10.1056/NEJMsa1004404 (ok) | Medium. Default 0 is a limiting case |
| `p_hazard` (0; 0–0.3), `hazard_share` (0.1), `hazard_size` (1), `hazard_σ` (0.2; 0–1) | Hazard chance per step, share threatened, harm per being, its scatter | Event sizes are heavy-tailed: war deaths, epidemics (generalised Pareto exponent about −0.71 **(abs)**), blackouts, quakes follow power laws with exponents 1.4–2.5; CV of damage above 1 | `hazard_size` Pareto tail (exponent 1.5–2) with median 1; `hazard_σ` as CV 1–2 (default 0.2 is far thinner); `p_hazard` 0.05–0.3 per period with rare large events | [CSN09] Clauset, Shalizi & Newman 2009, doi 10.1137/070710111 (ok); [CLA18] Clauset 2018, doi 10.1126/sciadv.aao3580 (ok); [CT16] Cirillo & Taleb 2016, doi 10.1016/j.physa.2016.01.050 (ok); [CT20] Cirillo & Taleb 2020, doi 10.1038/s41567-020-0921-x (ok); [MAR21] Marani et al. 2021, doi 10.1073/pnas.2105482118 (ok); EM-DAT https://www.emdat.be/ (200) | Medium for the shape; low for rates per step |
| black swans (`shock(:catastrophe)`) | event | Annual probability of a COVID-like pandemic about 2% **[unverified]**; interstate war large-event rate steady | Rare (0.5–2% per year), size from the tail above | [MAR21]; [CLA18] | Medium |
| `irreparable_loss` | none (2–∞) | Share of burden that is years of life lost vs lived with disability | Per cause from GBD | `docs/DATA.md` section 3 | Low |
| `p_shock`, `shock_size` (0, 0.2) | Prevention shocking those it protects | No source | none | | Low |
| `p_contracted`, `contract_share` (0, 0.2) | Contracted being, share | Labour share of income about 0.5–0.6 (analogue) | none | [KN14] Karabarbounis & Neiman 2014, doi 10.1093/qje/qjt032 (ok) | Low |

### 3.10 Execution failure of plans and projects

| Parameter | Now | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `sloppiness` for projects, `p_upstream`, `β_upstream` | 0; 0; 0.5 | Projects: nine of ten over budget; costs are fat-tailed (a minority overrun several-fold); megaproject benefit shortfalls; mean overrun for the Olympics 172% **[unverified]**; cost overrun distributions are power-law-tailed (regression to the tail) | Plan fidelity: 0.5–0.7 of intended effect delivered on average, with a fat right tail of failures (Pareto exponent about 1.5–2 for the overrun) | [FHB02] Flyvbjerg, Holm & Buhl 2002, doi 10.1080/01944360208976273 (ok); [FLY09] Flyvbjerg 2009, doi 10.1093/oxrep/grp024 (ok); [FLY14] Flyvbjerg 2014, doi 10.1002/pmj.21409 (ok); [FAB18] Flyvbjerg et al. 2018, doi 10.1016/j.tra.2018.07.013 (ok); [FBL20] Flyvbjerg et al. 2020, doi 10.1177/0308518X20958724 (ok) | Medium. Public-works samples are biased toward large, visible projects |
| `p_upstream`, `β_upstream` | | Share of works building on a recent one; share of value carried | See `docs/DATA.md` section 15 (citations) | | Low |

### 3.11 Resources and the commons (`capacity`, `regen`, `regen_σ`, `cost_per_touch`)

| Parameter | Now (range) | Represents; target | Proposal | Sources | Confidence; caveats |
|---|---|---|---|---|---|
| `regen_σ` (0.1; 0–0.5) | Variability of regeneration | Recruitment variability in exploited fish stocks: log-SD about 0.6–0.8 in many species | 0.3–0.8 (log-normal) | [THO14] Thorson, Jensen & Zipkin 2014, doi 10.1139/cjfas-2013-0645 (ok); [RIC12] Ricard et al. 2012, doi 10.1111/j.1467-2979.2011.00435.x (ok) | Medium for fisheries; the sim's commons are generic |
| `regen`, `capacity`, `cost_per_touch` | 0.02, 1e4, 0.05 | Surplus-production rate | Stock-specific; no cross-domain value | RAM Legacy https://www.ramlegacy.org/ | Low |

---

## 4. Governed thresholds: institutional analogues (not defaults)

These values are governed (SigThGv); nothing below is a proposed default. Each row names a
human institution's convention as a reference point, so a governance run can be read against the
world's own practice. **Analogues only.**

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

## 6. Top ten changes to defaults, by effect on realism

1. **M5 weight on others' readings** (section 1.4): from "weight = record, better sources heard in
   full" to a per-person mixture (30% stay put, mean 0.33). Changes governance accuracy, expert
   capture and echo results more than any other single default.
2. **`σ_leaf`, `σ_branch`, `σ_coarse`**: 0.15, 0.3, 0.45 to about 0.3 to 0.7 for a leaf, depending on
   the domain, with 0.15 as a limiting case. Moves the eligibility cliff (8.32) and the status bars.
3. **`signal_σ` (voter competence)**: 1 (p = 0.84) to 2–4 (p = 0.6–0.69) for non-experts, with a
   bimodal ability spread.
4. **`sloppiness` and project fidelity**: 0 to 0.25 for people, and fat-tailed overruns for
   projects (nine in ten over budget).
5. **`vigilance`**: 0.05 per step (battery severity 0: 0.3) to 0.001–0.02 for passive readers; this
   decides how much AdvAp's frictions matter.
6. **`hazard_σ`, `hazard_size`, `p_hazard`**: thin Gaussian-like hazards (σ 0.2) to Pareto tails
   (exponent 1.5–2, CV 1–2) and a non-zero `p_hazard`; the success pattern's harm peak depends on it.
7. **`p_side` and `p_foresee`**: 0 to 0.05–0.1 in complex domains, foreseeable share 0.43.
8. **Skill and productivity distributions**: uniform or fixed to log-normal (log-SD 0.3–0.5) with a
   Pareto tail for creative output; changes reputation concentration and the research rung.
9. **`marker_σ` for survey-type markers**: 0.05 to 0.3–0.6 (reliability 0.6–0.9); the battery's top
   (0.2) is the realistic bottom.
10. **`deceit` and `p_false_trace`**: a bimodal deceiver population (most honest, few large) and
    a false-conviction rate of 0.01–0.05; plus `ε` and `reception_σ` in M7 (a course closes 10–20%
    of the lead, with reception log-normal and heavy-tailed).

## 7. Where existing battery ranges disagree with the proposals

`sim/battery/economy.jl` (severity 0 to 1, rays to 2) and `sim/battery/governance.jl`.

| Factor | Battery range (severity 0 to 1) | Proposed realistic range | Disagreement |
|---|---|---|---|
| markers (`marker_σ`) | 0.02–0.20 | 0.15–0.6 for survey markers, 0.05–0.15 for counts | The battery's top is the realistic bottom for self-reports |
| model error (`σ_leaf`) | 0.05–0.45 | 0.3–0.9 (domain-dependent) | The battery's bottom (0.05) is unreachable except in physical limiting cases; the top is the realistic middle |
| model bias | 0–0.2 | 0.1–0.3 | Slightly low at the top |
| execution (`sloppiness`) | 0–0.6 | 0.1–0.5 for individuals as a default, not a stress | Severity 0 (perfect execution) is a limiting case only |
| hazards (`p_hazard`, `p_informed`, `diligence`) | 0–0.3; 1 to 0.6; 1 to 0.7 | `p_informed` 0.6–0.95, `diligence` 0.3–0.9 | Floor of diligence (0.7) too high |
| side harm (`p_side`) | 0–0.2 | 0.01–0.1 | Consistent; top high |
| inattention (`vigilance`) | 0.3 at severity 0 down to 0.01 | 0.001–0.05 passive, 0.1–0.5 for stakeholders | Severity 0 (0.3) is unrealistically attentive: the world is more inattentive than the clean case |
| audit errors (`p_false_trace`) | 0–0.1 | 0.01–0.05 | Consistent |
| accounting (`cost_σ`, `regen_σ`) | 0–0.3; 0–0.5 | 0.1–0.3; 0.3–0.8 | `regen_σ` top too low for fisheries-like resources |
| attribution | 0–0.3 | 0.1–0.4, biased upward | Slightly low; symmetric noise misses bias |
| memory loss | 0–0.1 | 0.02–0.15 per year | Consistent |
| deceit size | 0–2 | shape matters (bimodal), no size source | None testable |
| `signal_σ` (governance) | 1 to 40 | 1–4 for laypeople | Severity 1 (40, p = 0.51) is a coin flip, far beyond the realistic top (about 4–6) |
| `ability_spread` | 0–1.5 | 0.5–1.5 | Consistent |
| `p_apparent` | 0.9 to 0.1 (table 0.2–1) | 0.1–0.6 | The battery's severity 0 (0.9) is optimistic for social decisions |
| `local_σ` | 1 to 4 (table 0.5–3) | no source | Battery and table disagree with each other (README note) |
| delegation (`p_delegate`) | 0–1 | 0.1–0.4 | Realistic range inside the battery's; top (1) is stress |
| collusion, loyalty | top 0–50% of experts; 0–10 | unknown | None testable |

`attack.jl` sizes attackers by a budget in units of "one attack at the top of its realistic range",
so it inherits the issues above rather than adding ranges of its own.

## 8. References

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

Sources dropped after a DOI check failed to match (wrong DOI guessed, not used): Ambuehl & Li 2018,
Lau, Andersen & Redlawsk 2008, Johnson et al. 2013 (Penn World Table), Scherer 1998, Arthur et al.
1998 (a DOI exists, `10.1207/s15327043hup1101_3`, not used), and the Han, Fishkin & Luskin review of 22
Deliberative Polls (no DOI found; named only as **[unverified]** in 1.2).
