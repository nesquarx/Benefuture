# E5 candidate list (round 1, drawn 2026-11-07)

Drawn from public agendas by the criteria of `docs/REPLAY_PREREG.md` §8, before any case is priced. Eligibility is checked when a case is built; a failure is recorded here with its reason, never silently replaced. Build order: Python `random.Random(20261107).shuffle` over the list as written below (at most two per family per round).

| Order | Family | Decision | Source | Status |
|---|---|---|---|---|
| 1 | health | WHO Pathogen Access and Benefit Sharing annex to the Pandemic Agreement, target the 80th World Health Assembly, May 2027 (adopt, extend negotiations, no annex) | [source](https://www.who.int/news/item/28-03-2026-who-member-states-agree-to-extend-negotiations-on-key-annex-to-the-pandemic-agreement) | built and reported (docs/E5_REPORTS.md); eligible; a voluntary-annex option was not priced (no separate as-of record) |
| 2 | environment | COP31 decisions, Antalya, 9–20 November 2026 (options to be read from the negotiating texts) | [source](https://www.unccd.int/index%2Ephp/de/node/30380) | ineligible on building (2026-11-07): no stated set of alternatives was found in public sources before the conference (criterion 1); recorded, not replaced |
| 3 | economy | FOMC rate decision, 26–27 January 2027 (hold, cut, hike) | [source](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm) | built and reported (docs/E5_REPORTS.md); eligible (the hike option lacks a separating record, priced by judgment) |
| 4 | governance | New Zealand local government reform, government's final decisions expected May 2027 | [source](https://www.waikatodistrict.govt.nz/your-council/simplifying-local-government/timeline) | deferred on building (2026-11-07): the Minister deferred decisions on Head Start proposals and amalgamations until after the November 2026 general election ([DIA](https://www.dia.govt.nz/Simplifying-Local-Government)), so the decision date fails criterion 5 for now; rebuild when the post-election timetable is published |
| 5 | technology | EU Grids Package, European Parliament plenary vote expected December 2026 | [source](https://publyon.com/?p=12260) | not built |
| 6 | economy | EU post-2027 Cohesion Policy legislative package (negotiations; consultations open) | [source](https://www.gov.ie/en/department-of-public-expenditure-ndp-delivery-and-reform/news/have-your-say-on-the-future-of-the-european-unions-cohesion-policy) | not built |

Gaps in round 1: no candidate yet for security and geopolitics, or for education; round 2 searches those agendas (UN Security Council programme of work, national education acts with scheduled votes).

# Round 2 (drawn 2026-11-07, security; education still without a dated candidate)

Build order: `random.Random(20261108).shuffle` over the list as written.

| Order | Family | Decision | Source | Status |
|---|---|---|---|---|
| 1 | security | UN Security Council: MONUSCO (DR Congo) mandate, expiring 20 December 2026 (renew, renew with drawdown, end) | [source](https://aa.com.tr/en/world/un-security-council-renews-mandate-of-peacekeeping-force-in-congo-for-another-year/3776162) | held on building (2026-11-07): the dated trials (violence after mission ends; violence during renewals) are confounded, since missions stay where violence rises, so raw rates would favour withdrawal misleadingly; pricing needs the literature's effect sizes (e.g. Hultman, Kathman and Shannon on UN troop numbers and civilian deaths) read from the papers, not memory. Build once sourced, before 20 December 2026 |
| 2 | security | UN Security Council: AUSSOM (Somalia) mandate, expiring 31 December 2026 (renew, renew with drawdown, end) | [source](https://allafrica.com/stories/202512240311.html) | held on building (2026-11-07), as MONUSCO: confounded trials; an African Union force, so UN-mission effect sizes transfer only by judgment; build once the effect sizes are read from full texts |

MONUSCO and AUSSOM direction of effect, read from abstracts (2026-11-07): more UN military troops and police are associated with fewer civilians targeted (Hultman, Kathman & Shannon 2013, AJPS, https://doi.org/10.1111/ajps.12036) and fewer battlefield deaths (2014, APSR, https://doi.org/10.1017/S0003055414000446); magnitudes are not in the abstracts.

# Round 3 (drawn 2026-11-07; chosen for crisp options, dated decisions, base rates in public records)

Build order: `random.Random(20261109).shuffle` over the list as written.

| Order | Family | Decision | Source | Status |
|---|---|---|---|---|
| 1 | health | FDA decision on z-rostudirsen (Dyne, Duchenne muscular dystrophy), accelerated approval on dystrophin production, PDUFA 21 January 2027 (approve with a confirmatory trial; complete response letter) | [source](https://www.2minutemedicine.com/?p=83226) | built and reported (docs/E5_REPORTS.md) |
| 2 | technology | Artemis III crewed Earth-orbit test flight, late 2027: go or no-go given as-of anomaly records (a Challenger-shaped decision; date not yet fixed, so watch-listed until it is) | [source](https://news.cgtn.com/news/2026-02-28/NASA-postpones-crewed-lunar-landing-to-2028-adds-new-Artemis-mission-1L7FeQ4wPXG/p.html) | watch-listed: date not fixed (criterion 5) |
| 3 | environment | IMO Net-Zero Framework, resumed extraordinary MEPC session, 4 December 2026 (adopt as agreed with its carbon price; adopt without the pricing element; adjourn again) | [source](https://gcaptain.com/imo-climate-talks-stay-alive-as-carbon-plan-survives-u-s-pushback-at-mepc-84/) | built and reported (docs/E5_REPORTS.md); built out of seeded order only by skipping the watch-listed Artemis case |

## Contrast candidates for priority tiers (8.129, 2026-11-08)

Cases chosen because their options are close in size but differ in the kind of change they make for the same
people, so the priority tiers, not magnitudes or blocks, should decide. Not yet built; each is built from as-of
sources and committed before its replay. Picked for the contrast, not for a known outcome: the outcome class of
each is noted only where already public, and none was chosen because Benefuture is expected to get it right.

| Candidate | Type | Contrast (kind against kind) | As-of sources to find |
|---|---|---|---|
| Bush's *Science, the Endless Frontier* and the NSF Act (1945-1950): basic research council against mission-directed applied research | E4 | peak and teachable understanding, paradigm novelty, against median understanding and incremental novelty | Bush 1945 report; Kilgore bill debate; wartime OSRD record |
| Head Start (1965) against a remedial reading programme of similar cost | E4 | meta understanding and the floor (learning to learn, early years) against median understanding (skills taught to the test) | Perry Preschool early results; Coleman Report (1966) for as-of evidence after the decision only as a check |
| England's Sure Start (1998) against an equal sum on GCSE attainment targets | E4 | meta and floor against median | Sure Start Treasury review 1998; school-improvement evaluations to 1998 |
| Preventive against curative health spending of equal cost: tobacco control (1964 Surgeon General's report) against expanded hospital capacity | E4 | eudaimonic and baseline happiness, floor of understanding over decades, against satisficing happiness now | 1964 report; hospital-construction (Hill-Burton) record |
| Public broadcasting (Public Broadcasting Act 1967) against an equal subsidy to commercial entertainment | E4 | teachable understanding and shareable happiness against sensory-peak happiness | Carnegie Commission report 1967 |
| A national research agency's next budget split between basic and applied lines (a current one) | E5 | as above, prospective | the agency's budget documents and prior evaluations |

Build order: Bush/NSF and Head Start first (the clearest contrasts, well documented as of their dates).
