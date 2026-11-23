# Task: confirm

You judge one life event three ways, in one answer: how it belongs to domains (A), how each listed participant takes
part in it (B), and what occurrences it contains and how they link (D). Each task gives `input.item`: the `id` and
`text` of one event and its `participants`, each `{id, label}`; a participant may be a person, a group, an
institution, an animal, a thing or a process. The domain pack follows the vocabulary at the end of this prefix, one
domain per line as `id | label | description`, sectors first, then fields, each block sorted without grouping. Use
only this prefix and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is
observable in its text. Never infer intentions, motives or beliefs; a stated intention is something said, not an
established fact. **Declining is correct and expected**: `null` where the text gives no record is better than a value
guessed from a role, a stereotype or what is usual.

## The observed outcome

The outcome is the observed change against what would otherwise have happened. Use the counterfactual only when the
text states or implies it, else null: a vaccinated child who stays well through an outbreak that is stated, or an
operation after which a patient walks again where before they could not, has an outcome; a text that records only an
act, or records a result that is what would have happened anyway (a failed rescue, a treatment that changes nothing),
has none. A prevented harm counts when the text gives what it was prevented against. With no outcome, `outcome` is
null in A, every contribution and responsibility in B is 0 and every impact is empty.

## A: membership, per relation type

The types are in the vocabulary below: form, content, outcome, setting and flavour.

- form: what kind of act or thing the event is, apart from what it is about and what it changes. Depicting an act is a
  different act from doing it.
- content: what the event is about or engages, as one type.
- outcome: as above.
- setting: where, or in which sphere of life, the event takes place; null when the text gives no place.
- flavour: answer as the definition says, without second-guessing.

For each type answer in `types` either an object {domain id: weight} over ids from the pack (sectors are allowed;
weights positive, summing to 1 within the type; name only the domains that matter), or `null` when the relation does
not apply. Every type of the vocabulary must appear. Also answer `other`: a short string naming a relation of the
event to a domain that the types could not express, or `null` when they sufficed.

## B: participation, per participant

Answer for exactly the listed participants, once each. Contribution and responsibility are measured against the
observed outcome above.

- `contribution`: a number in [0, 1], the share of the observed outcome that the participant's act accounts for,
  against the counterfactual in which the participant had not acted. Additive: the contributions of all listed
  participants to one outcome sum to at most 1; the remainder is chance or causes the text does not list. A
  participant who made no difference gets near 0, however present or well meant.
- `responsibility`: a number in [0, 1], the degree of responsibility in the sense of Chockler and Halpern: 1/(k+1),
  where k is the smallest number of changes to what the other participants did that would make this participant's
  act pivotal. k = 0 gives 1; k = 1 gives 1/2; k = 2 gives 1/3. A participant whose act lies on no path to the outcome
  gets 0. Not additive: several participants may each be near 1.
- `impact`: a list of `{"party": <id or short name>, "sign": 1 or -1, "magnitude": 0..3}`, one entry per party whose
  observed condition the participant's act changed: +1 benefit, -1 harm; magnitude 0 (none) to 3 (severe or lasting).
  The party may be another participant (use its id), the participant itself, or an unlisted affected party. Empty when
  the text records no observable effect.
- `production`: produced = the participant's act yields an output others can use or assess (a review, a meal for
  others, a repaired roof); consumed = they take in or use up an output without yielding one; both; null if no record.
  Presence, intention or a stated purpose is not production. Take the participant's own act, not the event's.
- `acting_for`: the id or name of the entity the participant acts on behalf of, when the text says so; otherwise
  `null`. Acting for oneself is `null`.
- `under_agreement`: the contract, consent, law, order or lease the text names as the basis on which the participant
  acts, in a few words; otherwise `null`.
- `informed`: the record of disclosure that establishes the participant was informed of the relevant facts, in a few
  words; `null` when the text records none. Do not infer it from expertise or role.
- `volition`: `"free"` when the text records a choice among options with no constraint on it; `"constrained"` when
  the text records a prior threat, an order, a compulsion or an absence of options; otherwise `null`.
- `volition_record`: a few words naming the option set or the prior threat the text records. Required when
  `volition` is `"constrained"`; optional when `"free"`; `null` when `volition` is `null`.

## D: sub-events and links

List each distinct occurrence the text states or directly shows as a short label (two to eight words, an act or
happening, not a judgement) with an id `e1`, `e2`, and so on; at most 12. The whole scenario may itself be listed when
other sub-events are parts of it. Split only where the text records separate occurrences; a text may be a single
occurrence with no links. Each link is `{"from": <id>, "to": <id>, "type": <type>, "confidence": <number>}`, with a
confidence strictly between 0 and 1 (confidence never reaches 1). Link only where the text states or directly shows
the relation. Types:

{{link_types}}

Choose the type that fits; where two seem to fit, give the better one the higher confidence and omit the other. Give
at most one link per pair of sub-events and type; for the symmetric types the order of `from` and `to` is free but a
pair appears once. Not every pair is linked.

## Answer

The verdict is the string `confirm`. Besides the usual keys, the answer line carries `types` and `other` (A),
`participants` (B: one object per listed participant, every key present) and `subevents` and `event_links` (D):

```
"types": {"<type>": <{domain id: weight} or null>, ...}, "other": <string or null>,
"participants": [{"id": <participant id>, "contribution": <number 0..1>, "responsibility": <number 0..1>,
  "impact": [{"party": <string>, "sign": <1 or -1>, "magnitude": <integer 0..3>}],
  "acting_for": <string or null>, "under_agreement": <string or null>, "informed": <string or null>,
  "volition": <"free" or "constrained" or null>, "volition_record": <string or null>,
  "production": <"produced" or "consumed" or "both" or null>}],
"subevents": [{"id": <string>, "label": <string>}],
"event_links": [{"from": <id>, "to": <id>, "type": <type>, "confidence": <number>}]
```

The placeholders show types only, not values. The contributions must sum to at most 1. Give a one-line reason naming
what decided the most important judgement.

Validate with the repository's validator (when you can run code):

```
python -c "import sys; from lifeimage.confirm import validate_confirm_answers as v; \
b=open(sys.argv[1]).read().splitlines(); a=open(sys.argv[2]).read().splitlines(); \
e=v(b,a); print('\n'.join(e) or 'ok')" BATCH.jsonl ANSWERS.jsonl
```
