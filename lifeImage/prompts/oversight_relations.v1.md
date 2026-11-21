You are reviewing a relation-type design. Everything you need is below; do not look for other files. Answer in under 700 words, in the format at the end.

CONTEXT
A domain graph classifies any life event or behaviour (care, home, faith, play, harm, work, science, consumption). Domains are a network (tree-ish, DAG-ish, sometimes cyclic), learnt from records rather than declared. One graph serves four consumers:
- a behavioural transaction substrate (which domains' currencies quote and settle an action);
- metric models (which domain's models predict an action's value, and what they measure);
- per-domain currencies and reputation (reputation never transfers between domains; no halo);
- Life Image, a circular per-entity picture: domains placed once by position, colour channels for knowledge/expertise, positive impact, negative impact. It shows only colour-relevant relations: watching films gives at most capped expertise in cinema; writing reviews (an output) counts fully. Colour never bleeds to neighbouring domains, a little to major upstream ones.

Fixed constraints:
1. Membership of a thing T: Dn(T) = [(domain, relation type, weight)], weights sum to 1 within each relation type (no double counting within a type; an action can count fully in two types).
2. Outputs only: beliefs, intentions and preferences are not observable; only outputs and observed changes.
3. Relations route value; they never mint it (value is measured separately).
4. Everything is a domain (harm, consumption, life events included).
5. Parsimony: a type stays only if a consumer needs it and it is not definable from others.

THREE LAYERS
A. Event -> domain membership.
B. Entity -> event participation. Current proposal: no role list; quantities already in the system: causal contribution in [0,1] (Shapley-style, incl. upstream enablers and counterfactual omission under duty), signed impact, informedness, volition; plus row fields "acting for" (agency) and "under agreement" (consent/contract).
C. Domain <-> domain. Proposed recorded: directed co-membership (conditional weights), signed causal, analogous (shared models, no shared events), normative (laws/contracts/norms), reference (A's acts are about B). Derived: specialisation, prerequisite (temporal precedence), currency flow (from transactions). Lineage lives in versioned migration tables.

LAYER A CANDIDATES AND MEASUREMENT
- A4: form (kind of act), material (carrier/input), outcome (observed change), reference (subject).
- A6: A4 + mechanism (domain whose workings produce it) + normative.
- R156 (current ruling): causal, structural, communicative.
- ACP: act, content, purpose.
192 items (151 everyday events, 41 adversarial), 3 independent runs of a small model per vocabulary, over 263 coarse domains. Krippendorff alpha on each type's top domain:
- A4: form .88, outcome .70, material .46, reference .33 (outcome/reference swap on 26% of items)
- A6: form .89, outcome .74, normative .45, material .38, mechanism .29 (applies 17%), reference -.06 (loses mass to normative 21%, mechanism 17%)
- R156: causal .82, communicative .56, structural .52
- ACP: act .86, content .75, purpose .64 (fills every type in 92% of answers)
"Other" (inexpressible) was used under 1%, even on adversarial items: the small model forces a fit, so completeness is untested.
Robust everywhere: "kind of act" and "what it is about/for". Unstable: material vs reference.

ADVERSARIAL BREAKS FOUND
Surgery vs assault (identical except consent); coercion; CEO signing for a firm; failed treatment (intent vs outcome); theft by hacking (mechanism or second form?); conference dinner (several coexisting outcomes forced to share weight); five sufficient shooters (overdetermination); fluid dynamics vs traffic (shared structure, no shared events); alchemy -> chemistry (identity drift); spam reviews, citation rings (cheap reference to gain credit); same act classified differently across cultures.

QUESTIONS
1. What is the most parsimonious layer-A set that serves all four consumers? Is "form + outcome + one content type" right, and should content split into carrier vs subject?
2. Which proposed types in A, B or C are redundant, ill-posed, or violate outputs-only?
3. What is missing? Give the strongest counterexamples you can that break the best set (not those listed).
4. How should directionality between domains be detected and recorded?
5. What better test would measure completeness, given the small model never declines?
6. Prior art worth adopting or testing against (name it, one line on why).

FORMAT
Numbered answers to the six questions; then "Recommended sets" (A, B, C, one line each); then "Top 3 risks". No preamble.
