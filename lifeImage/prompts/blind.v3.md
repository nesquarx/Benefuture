# Task: blind (pass 1 of two-pass extraction), version 3

You read one statement, of any detail, and categorise it, in your own words, the way a careful person would file it. You are not given any list of
categories, and you must not try to recall or invent identifiers for one: write plain short phrases. A second reader later maps your phrases onto a
fixed list, so a phrase must say clearly which thing it means. Each task gives `input.item`: the text of one statement. Use only these instructions
and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is observable in its text. Never infer
intentions, motives or beliefs; a stated intention is itself something said, and counts only as what it represents.

## Step 1: split the statement into events

A statement may hold several events: acts that could each happen without the other, each with its own outcome. Split first, then categorise each
event on its own. A statement that joins two acts with "and", "then" or "while" is two events (a worker who cleans a machine and orders a part
has done two things). Do not split one act into its steps or its parties: a sale with a seller and a buyer is one event. Most statements are one event.
Each event gets an `id` (`e1`, `e2`, ... in the order stated), a `text` (a short clause restating that event), its four facets and its relational
block. Events of one statement are linked through the relational block's `links`: `part_of`, `causes` or `concurrent`, with `other` the `id` of
the other event ("e2"); an answer of several events links them, a single event has no link to another event.

## Step 2: the four facets of each event

Each facet answers a different question about the event, so the lists differ. The key action decides, never the actor's name or occupation: a
baker who sells bread is doing a sale, not baking; a surgeon on stage is acting.

- form: the type of act, named at every level: the act itself, the actor's role in it, its purpose, and its regularity where the statement shows
  one (a yearly shot is an annual routine, a repeated trip a regular activity), listed most specific first. Name what is done, apart from what it is about
  and what it changes.
- content: the doing and what it involves: the objects, the interactions, the stages of the act, the things handled (bread, baked goods, food, a
  direct person-to-person transaction). A venue is not content (it belongs to the setting), nor is a result (the outcome).
- outcome: only the state changes the statement supports, from the actor's perspective and for each party the statement shows changing (money in,
  inventory spent; ticket obtained, seat booked, promise held). An outcome that is another entity's act belongs to that entity's event, not here
  (what a vehicle or an institution does is its own event). A result the statement leaves unstated is left out: reaching a destination, being
  healed, being protected are not state changes of an act unless the statement says so. Never an intention, never what the event was meant to do. A
  prevented harm counts when the statement shows it. A statement that supports one change gives one label; one that supports none leaves the
  outcome `null`.
- setting: the venue and sphere, concrete to generic (the place, the building, the institution, the sector), and it stops where the statement
  stops: where the statement gives nothing more, the next entry is `unknown`. Never guess a place the text does not state or show: where it gives
  none, the setting is the single entry `unknown`.

## Categories

For each facet list the categories in order, as many as the event supports, up to 10 (a rich event takes 6 to 10, a thin statement fewer). Within
a chain each label is more generic than the one before: the first is the most specific and the last the broad field the rest sit in. The leafier
the better, since a specific category carries its parents with it. A facet's list does not repeat itself or pad with a category that only shares a
keyword with the event.

- `label`: a short phrase of one to five words in everyday or professional wording ("sale", "baked goods", "seat booked"). Never an identifier,
  never a code, never a dotted name.
- `weight`: how central the label is to the event within its facet: a number above 0, the weights of one facet adding up to 1, never rising down
  the list and never equal between two entries (two decimals are enough). Weights reflect centrality, not rank alone: there is no fixed ladder of
  steps (0.4, 0.3, 0.2, 0.1 is a formula, not a judgement); one label may carry half the facet, and a few generic ones may share a small remainder.
  An entry `unknown` takes what the statement leaves open.
- `gloss`: one line that fixes the sense of the label, so a reader with a list cannot confuse it with another sense of the same word:
  "ticket (a document entitling travel)" is not "issue ticket (a tracked work item)". Always write one.

The same category may appear under more than one facet only when it truly applies to each, never by default; its gloss then says what it is in
each (retail as a type of act, and retail as the sphere where it happens). At most one `unknown` per facet, always last.

## The relational block of each event

Besides the categories, record the event's relational structure as the text states it, at whatever detail the text has:

- `participants`: the entities in the event, each `{"ref": "p1", "role": <one or two words>}` with refs `p1`, `p2`, and so on, distinct. The
  list may be empty when the text names nobody.
- `action`: one short line naming what is done or happens.
- `outcome`: `null` when no observable change is stated or directly shown, otherwise
  `{"text": <what changed>, "counterfactual": <what would otherwise have happened, or null when the text does not say or show it>}`.
  Never invent the counterfactual.
- `links`: relations to other events of the statement or to other occurrences the text states, each `{"type": <type>, "other": <the id of the other
  event, or a short label of an occurrence outside the statement>}` with type one of `part_of`, `causes`, `re_description`, `concurrent`. Empty
  when the text states none.

## Answer

The verdict is the string `blind`. Besides the usual keys the answer line carries `events`: a list of at least one event, each exactly
`{"id", "text", "blind", "relational"}`, where `blind` is an object with exactly the keys `form`, `content`, `outcome`, `setting` (each a list of
`{"label", "weight", "gloss"}` from the most specific to the most generic; `outcome` may be `null`) and `relational` is the block above. There is
no top-level `blind` or `relational`.

Give a one-line reason naming the key action of each event. Worked examples follow. The first two are the author's own categorisations of two events,
given here exactly as the author wrote them, then rendered as answers (the weights and glosses are added, the outcome gives the actor's change). The
others are invented. In every example the weights are only illustrative: yours follow the event.

The author's example 1. "A baker sells bread at the market": form sale, retail, exchange, financial transaction; content bread, baked goods,
food, direct human-to-human transaction; outcome money input, inventory spent; setting market, stall/store/shop, point of sale, retail, commerce,
business.

Event: "A baker sells bread at the market"
```json
{"events": [{"id": "e1", "text": "a baker sells bread at the market", "blind": {"form": [{"label": "sale", "weight": 0.4, "gloss": "handing goods over for money"}, {"label": "retail", "weight": 0.27, "gloss": "selling to final customers"}, {"label": "exchange", "weight": 0.19, "gloss": "goods given for value received"}, {"label": "financial transaction", "weight": 0.14, "gloss": "a payment between two parties"}], "content": [{"label": "bread", "weight": 0.36, "gloss": "the loaves sold"}, {"label": "baked goods", "weight": 0.28, "gloss": "flour products baked in an oven"}, {"label": "food", "weight": 0.21, "gloss": "things made to be eaten"}, {"label": "direct human-to-human transaction", "weight": 0.15, "gloss": "buyer and seller face to face, no platform between"}], "outcome": [{"label": "money input", "weight": 0.58, "gloss": "the baker's takings go up"}, {"label": "inventory spent", "weight": 0.42, "gloss": "the baker has fewer loaves"}], "setting": [{"label": "market", "weight": 0.28, "gloss": "an open place where traders sell"}, {"label": "stall/store/shop", "weight": 0.22, "gloss": "the trader's counter or premises"}, {"label": "point of sale", "weight": 0.18, "gloss": "where payment is taken"}, {"label": "retail", "weight": 0.14, "gloss": "the sphere of selling to consumers, here the place not the act"}, {"label": "commerce", "weight": 0.1, "gloss": "trade in general"}, {"label": "business", "weight": 0.08, "gloss": "an enterprise earning a living"}]}, "relational": {"participants": [{"ref": "p1", "role": "seller"}, {"ref": "p2", "role": "buyer"}], "action": "sells bread", "outcome": {"text": "money changes hands for bread", "counterfactual": null}, "links": []}}]}
```

The author's example 2. "A woman buys a train ticket": form purchase, booking, travel planning, logistics; content ticket/pass, receipt,
train, public transportation; outcome ticket obtained, promise obtained, seat booked, documentation; setting point of sale (rest unknown).

Event: "A woman buys a train ticket"
```json
{"events": [{"id": "e1", "text": "a woman buys a train ticket", "blind": {"form": [{"label": "purchase", "weight": 0.38, "gloss": "buying a good or a right for money"}, {"label": "booking", "weight": 0.29, "gloss": "reserving a seat or a place in advance"}, {"label": "travel planning", "weight": 0.19, "gloss": "arranging a journey ahead of time"}, {"label": "logistics", "weight": 0.14, "gloss": "organising the movement of people or things"}], "content": [{"label": "ticket/pass", "weight": 0.32, "gloss": "a document entitling travel, or a pass for a period"}, {"label": "receipt", "weight": 0.27, "gloss": "proof of payment"}, {"label": "train", "weight": 0.22, "gloss": "the rail vehicle the ticket is for"}, {"label": "public transportation", "weight": 0.19, "gloss": "shared transport open to anyone who pays"}], "outcome": [{"label": "ticket obtained", "weight": 0.33, "gloss": "the woman holds a travel document"}, {"label": "promise obtained", "weight": 0.27, "gloss": "the operator is bound to carry her"}, {"label": "seat booked", "weight": 0.22, "gloss": "a place is held for her on the journey"}, {"label": "documentation", "weight": 0.18, "gloss": "a record of the purchase now exists"}], "setting": [{"label": "point of sale", "weight": 0.6, "gloss": "where the ticket is paid for"}, {"label": "unknown", "weight": 0.4, "gloss": "the statement gives no venue or sphere beyond the sale"}]}, "relational": {"participants": [{"ref": "p1", "role": "buyer"}, {"ref": "p2", "role": "operator"}], "action": "buys a train ticket", "outcome": {"text": "she holds a ticket for a train journey", "counterfactual": null}, "links": []}}]}
```

A third example, an invented event with long lists: the form runs from the act through the actor's role, the purpose and the regularity; the
setting stops where the statement stops; the outcome names only what the act supports (protection is not stated, so it is left out). Event: "A nurse at a
school clinic gives a child the yearly flu vaccine"
```json
{"events": [{"id": "e1", "text": "a nurse at a school clinic gives a child the yearly flu vaccine", "blind": {"form": [{"label": "giving a vaccine", "weight": 0.22, "gloss": "injecting a vaccine into a person"}, {"label": "immunisation", "weight": 0.17, "gloss": "making a person resistant to an infection"}, {"label": "nursing care", "weight": 0.15, "gloss": "care given by a nurse, the actor's role"}, {"label": "preventive health care", "weight": 0.13, "gloss": "acting before illness to stop it, the purpose"}, {"label": "health protection of a child", "weight": 0.11, "gloss": "keeping a young person well"}, {"label": "school health service", "weight": 0.09, "gloss": "care provided to pupils by their school"}, {"label": "annual routine", "weight": 0.07, "gloss": "done once every year"}, {"label": "regular activity", "weight": 0.06, "gloss": "repeated at a fixed interval"}], "content": [{"label": "flu vaccine", "weight": 0.26, "gloss": "the vaccine given against influenza"}, {"label": "injection", "weight": 0.2, "gloss": "a needle used to give a dose"}, {"label": "vaccination schedule", "weight": 0.17, "gloss": "the routine shots offered to children"}, {"label": "influenza", "weight": 0.15, "gloss": "the viral infection prevented"}, {"label": "infectious disease", "weight": 0.12, "gloss": "illness spread between people"}, {"label": "child health", "weight": 0.1, "gloss": "the health of children as a field"}], "outcome": [{"label": "vaccine dose given", "weight": 0.55, "gloss": "the child has received one dose"}, {"label": "dose stock used", "weight": 0.45, "gloss": "the clinic has one dose fewer"}], "setting": [{"label": "school clinic", "weight": 0.5, "gloss": "a health room inside a school"}, {"label": "school", "weight": 0.32, "gloss": "the institution where children are taught"}, {"label": "unknown", "weight": 0.18, "gloss": "the statement says nothing beyond the school"}]}, "relational": {"participants": [{"ref": "p1", "role": "nurse"}, {"ref": "p2", "role": "child"}], "action": "gives a flu vaccine", "outcome": {"text": "the child has received a dose", "counterfactual": null}, "links": []}}]}
```
Here nothing in the text says the child is protected, so no outcome of protection is listed; "education" is not in the setting because the statement
gives a clinic and a school and nothing more.

A fourth example, an invented compound statement, split into two events that are linked as concurrent. Event: "A teacher marks the homework and phones a
parent about a pupil's absence"
```json
{"events": [{"id": "e1", "text": "a teacher marks the homework", "blind": {"form": [{"label": "marking", "weight": 0.3, "gloss": "checking pupils' work and grading it"}, {"label": "assessing pupils' work", "weight": 0.24, "gloss": "judging how well pupils have learned"}, {"label": "teaching work", "weight": 0.2, "gloss": "the teacher's role"}, {"label": "education", "weight": 0.14, "gloss": "the sphere of instruction"}, {"label": "regular school duty", "weight": 0.12, "gloss": "a task repeated through the school term"}], "content": [{"label": "homework", "weight": 0.38, "gloss": "work set to be done outside lessons"}, {"label": "written work", "weight": 0.32, "gloss": "pupils' texts and exercises"}, {"label": "learning", "weight": 0.17, "gloss": "what pupils are meant to gain"}, {"label": "education", "weight": 0.13, "gloss": "the field of instruction, here the subject matter"}], "outcome": [{"label": "homework marked", "weight": 1.0, "gloss": "the set of work now carries marks"}], "setting": [{"label": "unknown", "weight": 1.0, "gloss": "the statement names no place or sphere"}]}, "relational": {"participants": [{"ref": "p1", "role": "teacher"}], "action": "marks the homework", "outcome": {"text": "the homework is marked", "counterfactual": null}, "links": [{"type": "concurrent", "other": "e2"}]}}, {"id": "e2", "text": "the teacher phones a parent about a pupil's absence", "blind": {"form": [{"label": "phoning a parent", "weight": 0.3, "gloss": "a telephone call to a pupil's parent"}, {"label": "reporting an absence", "weight": 0.24, "gloss": "telling someone a pupil was not there"}, {"label": "school-home communication", "weight": 0.2, "gloss": "contact between a school and families"}, {"label": "pupil welfare follow-up", "weight": 0.14, "gloss": "checking on a pupil's wellbeing"}, {"label": "school administration", "weight": 0.12, "gloss": "the running of a school"}], "content": [{"label": "telephone call", "weight": 0.31, "gloss": "a spoken exchange over a phone"}, {"label": "absence", "weight": 0.25, "gloss": "a pupil missing from school"}, {"label": "parent", "weight": 0.2, "gloss": "the adult responsible for the pupil"}, {"label": "pupil attendance", "weight": 0.14, "gloss": "whether pupils turn up"}, {"label": "school-home relationship", "weight": 0.1, "gloss": "the tie between a school and a family"}], "outcome": [{"label": "absence reported", "weight": 0.55, "gloss": "the parent has been told of the absence"}, {"label": "parent informed", "weight": 0.45, "gloss": "the parent now knows"}], "setting": [{"label": "unknown", "weight": 1.0, "gloss": "the statement names no place or sphere"}]}, "relational": {"participants": [{"ref": "p1", "role": "teacher"}, {"ref": "p2", "role": "parent"}], "action": "phones a parent about an absence", "outcome": {"text": "the parent is told of the pupil's absence", "counterfactual": null}, "links": [{"type": "concurrent", "other": "e1"}]}}]}
```
The two acts each have their own facets, outcome and relational block; where the statement gives no place, the setting is the single entry `unknown`,
and where it supports one change the outcome has one label.
