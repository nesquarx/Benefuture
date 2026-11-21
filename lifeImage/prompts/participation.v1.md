# Task: participation

You describe how each listed participant is involved in one event. Each task gives `input.item`: the `id` and `text` of
one event and its `participants`, each `{id, label}`. A participant may be a person, a group, an institution, an
animal, a thing or a process. Answer for exactly the listed participants, once each, using only the text.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge what the text records.
Never infer intentions, motives or beliefs; a stated intention is something said, not an established fact. Where the
text gives no record for a field, answer `null`. Declining is correct and expected: a field answered `null` is better
than one guessed from a role, a stereotype or what is usual.

## The observed outcome

Contribution and responsibility are measured against the event's observed outcome: what observably changed, relative to
what would otherwise have happened (a prevented harm counts; so does an omission whose counterfactual differs, such as
a refusal to buy). When nothing observable differs from that counterfactual, there is no outcome: every contribution
and responsibility is 0 and every impact is empty.

## The fields, per participant

- `contribution`: a number in [0, 1], the share of the observed outcome that the participant's act accounts for,
  against the counterfactual in which the participant had not acted. It is additive: the contributions of all listed
  participants to one outcome sum to at most 1; the remainder is chance or causes the text does not list. A
  participant who made no difference gets near 0, however much they were present or intended.
- `responsibility`: a number in [0, 1], the degree of responsibility in the sense of Chockler and Halpern: 1/(k+1),
  where k is the smallest number of changes to what the other participants did that would make this participant's
  act pivotal (the outcome then turns on it). k = 0 gives 1; k = 1 gives 1/2; k = 2 gives 1/3. A participant whose act
  lies on no path to the outcome gets 0. It is not additive: several participants may each be near 1, and the values
  need not sum to anything. Contribution answers who accounts for how much of the outcome; responsibility answers how
  close each participant came to being the one that made the difference.
- `impact`: a list of `{"party": <id or short name>, "sign": 1 or -1, "magnitude": 0..3}`, one entry per party whose
  observed condition the participant's act changed: sign +1 for benefit and -1 for harm; magnitude 0 (none) to 3
  (severe or lasting). The party may be another participant (use its id), the participant itself, or an unlisted
  affected party. An empty list when the text records no observable effect.
- `acting_for`: the id or name of the entity the participant acts on behalf of (as an agent, officer, employee or
  representative), when the text says so; otherwise `null`. Acting for oneself is `null`.
- `under_agreement`: the contract, consent, law, order or lease the text names as the basis on which the participant
  acts, in a few words; otherwise `null`.
- `informed`: the record of disclosure that establishes the participant was informed of the relevant facts (what was
  disclosed, by whom, how), in a few words; `null` when the text records none. Do not infer it from expertise or role.
- `volition`: `"free"` when the text records a choice among options with no constraint on it; `"constrained"` when the
  text records a prior threat, an order, a compulsion or an absence of options; otherwise `null`.
- `volition_record`: a few words naming the option set or the prior threat that the text records. Required when
  `volition` is `"constrained"`; optional when `"free"`; `null` when `volition` is `null`.
- `production`: `"produced"` when the participant contributed to an output (a thing, service, effect or text),
  `"consumed"` when the participant used or consumed one, `"both"` when both, `null` when neither is stated.

## Answer

The verdict is the string `participation`. Besides the usual keys, the answer line carries `participants`: a list with
one object per listed participant, with exactly these keys in this form (the placeholders show types only, not values):

```
{"id": <participant id>, "contribution": <number 0..1>, "responsibility": <number 0..1>,
 "impact": [{"party": <string>, "sign": <1 or -1>, "magnitude": <integer 0..3>}],
 "acting_for": <string or null>, "under_agreement": <string or null>, "informed": <string or null>,
 "volition": <"free" or "constrained" or null>, "volition_record": <string or null>,
 "production": <"produced" or "consumed" or "both" or null>}
```

Every key is present in every object. The contributions must sum to at most 1. Give a one-line reason naming what
decided the most important judgement.

Validate with the repository's validator (when you can run code); it replaces the runner's generic check for this
task type:

```
python -c "import sys; from lifeimage.events import validate_bd_answers as v; \
b=open(sys.argv[1]).read().splitlines(); a=open(sys.argv[2]).read().splitlines(); \
e=v(b,a); print('\n'.join(e) or 'ok')" BATCH.jsonl ANSWERS.jsonl
```
