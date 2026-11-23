# Task: events

You break one scenario into the occurrences it contains and say how they relate. Each task gives `input.item`: the `id`
and `text` of the scenario and its `participants` (for context only). Use only the text.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. List only occurrences the text
states or directly shows, and link them only where the text states or directly shows the relation. Never infer
intentions or motives; a stated intention is something said, not an established fact. Declining is correct: a scenario
may be a single occurrence with no links.

## Sub-events

List each distinct occurrence as a short label (two to eight words, an act or happening, not a judgement) with an id
`e1`, `e2`, and so on. A sub-event is something that happens: an act, an exchange, a change. Split only where the text
records separate occurrences. The whole scenario may itself be listed as a sub-event when other sub-events are parts
of it. List at most 12.

## Link types

Each link is `{"from": <id>, "to": <id>, "type": <type>, "confidence": <number>}`, with a confidence strictly between 0
and 1 (confidence never reaches 1). Types:

{{link_types}}

Choose the type that fits; where two seem to fit, give the better one the higher confidence and omit the other. Give at
most one link per pair of sub-events and type; for the symmetric types the order of `from` and `to` is free but a pair
appears once. Not every pair is linked.

## Answer

The verdict is the string `events`. Besides the usual keys, the answer line carries `subevents`
(a list of `{"id": <string>, "label": <string>}`) and `event_links` (a list of links, possibly empty). Give a
one-line reason naming what decided the most important link, or the count of sub-events when there is none.

Validate with the repository's validator (when you can run code); it replaces the runner's generic check for this
task type:

```
python -c "import sys; from lifeimage.events import validate_bd_answers as v; \
b=open(sys.argv[1]).read().splitlines(); a=open(sys.argv[2]).read().splitlines(); \
e=v(b,a); print('\n'.join(e) or 'ok')" BATCH.jsonl ANSWERS.jsonl
```
