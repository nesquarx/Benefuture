# Task: blind (pass 1 of two-pass extraction), version 2

You read one event, of any detail, and categorise it, in your own words, the way a careful person would file it. You are not given any list of
categories, and you must not try to recall or invent identifiers for one: write plain short phrases. A second reader later maps your phrases onto a
fixed list, so a phrase must say clearly which thing it means. Each task gives `input.item`: the text of one event. Use only these instructions
and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is observable in its text. Never infer
intentions, motives or beliefs; a stated intention is itself something said, and counts only as what it represents.

## The four relations, each its own facet

Each relation answers a different question about the event, so the lists differ. The key action decides, never the actor's name or occupation: a
baker who sells bread is doing a sale, not baking; a surgeon on stage is acting.

- form: the type of act (sale, retail, exchange, financial transaction). Name what is done, apart from what it is about and what it changes.
- content: the things and interactions involved (bread, baked goods, food, a direct person-to-person transaction).
- outcome: the concrete change of state for each party (money in, inventory spent; ticket obtained, seat booked, promise held). Nearly every event
  changes something for someone, so give the outcome, one change per party where there are several (the seller's and the buyer's); a prevented harm
  counts. Only an event that truly leaves no trace for anyone has no outcome (`null`). Never an intention, never what the event was meant to do.
- setting: the venue and sphere, only as far as the statement gives them (market, stall, point of sale, retail, commerce). Never guess a place the
  text does not state or show: where it gives none, the setting is `unknown`.

## Categories: most specific to most generic

For each relation list 4 to 8 categories, from the most specific to the most generic, with a weight each. The leafier the better: a specific
category carries its parents with it, so the generic ones at the end are the broad fields the specific ones sit in. Weights decrease down the list
and sum to 1 within the relation (strictly decreasing, so no two are equal; two decimals are enough). The weight says how much of the relation the
category covers, not how likely you think it is.

- `label`: a short phrase of one to five words in everyday or professional wording ("sale", "baked goods", "seat booked"). Never an identifier,
  never a code, never a dotted name.
- `weight`: a number above 0, decreasing down the list; the weights of one relation add up to 1.
- `gloss`: one line that fixes the sense of the label, so a reader with a list cannot confuse it with another sense of the same word:
  "ticket (a document entitling travel)" is not "issue ticket (a tracked work item)". Always write one.

The same category may appear under more than one relation only when it truly applies to each, never by default. If a label repeats across
relations, its gloss must say what it is in each (retail as a type of act, and retail as the sphere where it happens). Do not pad: a category that
only shares a keyword with the event does not belong, and a relation whose specific categories run out ends with its generic ones rather than
repeating itself. When the statement gives very little (a setting it does not name), a short list is correct: end it with one entry labelled
`unknown` whose weight is what remains, with a gloss saying what is not stated. At most one `unknown` per relation, always last. The outcome is
`null` only when nothing at all changed.

## The relational extraction

Besides the categories, record the event's relational structure as the text states it, at whatever detail the text has:

- `participants`: the entities in the event, each `{"ref": "p1", "role": <one or two words>}` with refs `p1`, `p2`, and so on, distinct. The
  list may be empty when the text names nobody.
- `action`: one short line naming what is done or happens.
- `outcome`: `null` when no observable change is stated or directly shown, otherwise
  `{"text": <what changed>, "counterfactual": <what would otherwise have happened, or null when the text does not say or show it>}`.
  Never invent the counterfactual.
- `links`: relations to other occurrences the text states, each `{"type": <type>, "other": <short label of the other occurrence>}` with type one
  of `part_of`, `causes`, `re_description`, `concurrent`. Empty when the text states none.

## Answer

The verdict is the string `blind`. Besides the usual keys the answer line carries:

- `blind`: an object with exactly the keys `form`, `content`, `outcome`, `setting`; each a list of `{"label", "weight", "gloss"}` from most
  specific to most generic (`outcome` may be `null`).
- `relational`: `{"participants": [...], "action": <string>, "outcome": <null or object>, "links": [...]}`.

Give a one-line reason naming the key action. Worked examples follow. The first two are the author's own categorisations of two events, given
here exactly as the author wrote them, then rendered as answers (the weights and glosses are added, and the outcome gives each party's change).

The author's example 1. "A baker sells bread at the market": form sale, retail, exchange, financial transaction; content bread, baked goods,
food, direct human-to-human transaction; outcome money input, inventory spent; setting market, stall/store/shop, point of sale, retail, commerce,
business.

Event: "A baker sells bread at the market"
```json
{"blind": {"form": [{"label": "sale", "weight": 0.4, "gloss": "handing goods over for money"}, {"label": "retail", "weight": 0.28, "gloss": "selling to final customers"}, {"label": "exchange", "weight": 0.2, "gloss": "goods given for value received"}, {"label": "financial transaction", "weight": 0.12, "gloss": "a payment between two parties"}],
           "content": [{"label": "bread", "weight": 0.4, "gloss": "the loaves sold"}, {"label": "baked goods", "weight": 0.3, "gloss": "flour products baked in an oven"}, {"label": "food", "weight": 0.2, "gloss": "things made to be eaten"}, {"label": "direct human-to-human transaction", "weight": 0.1, "gloss": "buyer and seller face to face, no platform between"}],
           "outcome": [{"label": "money input", "weight": 0.4, "gloss": "the baker's takings go up"}, {"label": "inventory spent", "weight": 0.3, "gloss": "the baker has fewer loaves"}, {"label": "bread obtained", "weight": 0.2, "gloss": "the buyer now holds bread"}, {"label": "money spent", "weight": 0.1, "gloss": "the buyer's cash goes down"}],
           "setting": [{"label": "market", "weight": 0.3, "gloss": "an open place where traders sell"}, {"label": "stall, store or shop", "weight": 0.22, "gloss": "the trader's counter or premises"}, {"label": "point of sale", "weight": 0.18, "gloss": "where payment is taken"}, {"label": "retail", "weight": 0.14, "gloss": "the sphere of selling to consumers, here the place not the act"}, {"label": "commerce", "weight": 0.1, "gloss": "trade in general"}, {"label": "business", "weight": 0.06, "gloss": "an enterprise earning a living"}]},
 "relational": {"participants": [{"ref": "p1", "role": "seller"}, {"ref": "p2", "role": "buyer"}], "action": "sells bread", "outcome": {"text": "money changes hands for bread", "counterfactual": null}, "links": []}}
```

The author's example 2. "A woman buys a train ticket": form purchase, booking, travel planning, logistics; content ticket/pass, receipt,
train, public transportation; outcome ticket obtained, promise obtained, seat booked, documentation; setting point of sale (rest unknown).

Event: "A woman buys a train ticket"
```json
{"blind": {"form": [{"label": "purchase", "weight": 0.4, "gloss": "buying a good or a right for money"}, {"label": "booking", "weight": 0.3, "gloss": "reserving a seat or a place in advance"}, {"label": "travel planning", "weight": 0.2, "gloss": "arranging a journey ahead of time"}, {"label": "logistics", "weight": 0.1, "gloss": "organising the movement of people or things"}],
           "content": [{"label": "ticket", "weight": 0.35, "gloss": "a document entitling travel"}, {"label": "pass", "weight": 0.25, "gloss": "a travel entitlement for a period or a set of trips"}, {"label": "receipt", "weight": 0.2, "gloss": "proof of payment"}, {"label": "train", "weight": 0.12, "gloss": "the rail vehicle the ticket is for"}, {"label": "public transportation", "weight": 0.08, "gloss": "shared transport open to anyone who pays"}],
           "outcome": [{"label": "ticket obtained", "weight": 0.35, "gloss": "the woman holds a travel document"}, {"label": "promise obtained", "weight": 0.25, "gloss": "the operator is bound to carry her"}, {"label": "seat booked", "weight": 0.22, "gloss": "a place is held for her on the journey"}, {"label": "documentation", "weight": 0.18, "gloss": "a record of the purchase now exists"}],
           "setting": [{"label": "point of sale", "weight": 0.6, "gloss": "where the ticket is paid for"}, {"label": "unknown", "weight": 0.4, "gloss": "the statement gives no venue or sphere beyond the sale"}]},
 "relational": {"participants": [{"ref": "p1", "role": "buyer"}, {"ref": "p2", "role": "operator"}], "action": "buys a train ticket", "outcome": {"text": "she holds a ticket for a train journey", "counterfactual": null}, "links": []}}
```

A third example, an invented event in which one domain legitimately appears in two relations: it is the sphere where the act happens and also what the
act is of. Event: "A nurse vaccinates a child at the school clinic and the child is protected against measles"
```json
{"blind": {"form": [{"label": "vaccination", "weight": 0.45, "gloss": "giving a vaccine by injection"}, {"label": "immunisation", "weight": 0.25, "gloss": "making a person resistant to an infection"}, {"label": "nursing care", "weight": 0.18, "gloss": "care given by a nurse"}, {"label": "preventive health", "weight": 0.12, "gloss": "acting before illness to stop it"}],
           "content": [{"label": "measles vaccine", "weight": 0.35, "gloss": "the vaccine given against measles"}, {"label": "measles", "weight": 0.25, "gloss": "the viral infection prevented"}, {"label": "childhood vaccination schedule", "weight": 0.2, "gloss": "the set of routine shots given to children"}, {"label": "infectious disease", "weight": 0.12, "gloss": "illness spread between people"}, {"label": "child health", "weight": 0.08, "gloss": "the health of children as a field"}],
           "outcome": [{"label": "measles immunity", "weight": 0.4, "gloss": "the child is now protected against measles"}, {"label": "vaccine dose used", "weight": 0.32, "gloss": "the clinic has one dose fewer"}, {"label": "vaccination recorded", "weight": 0.28, "gloss": "the child's record shows the shot"}],
           "setting": [{"label": "school clinic", "weight": 0.4, "gloss": "a health room inside a school"}, {"label": "school", "weight": 0.25, "gloss": "the institution where children are taught"}, {"label": "public health", "weight": 0.2, "gloss": "the sphere of population-level disease prevention"}, {"label": "preventive health", "weight": 0.15, "gloss": "the sphere of acting before illness, here the place of the work not the act"}]},
 "relational": {"participants": [{"ref": "p1", "role": "nurse"}, {"ref": "p2", "role": "child"}], "action": "vaccinates a child", "outcome": {"text": "the child is protected against measles", "counterfactual": "the child would have stayed unprotected"}, "links": []}}
```
Here "preventive health" is under form (as the kind of act) and under setting (as the sphere), each with its own gloss, because it truly applies to both.

A fourth example, an invented event whose setting is unknown. Event: "A man repays a loan to his brother"
```json
{"blind": {"form": [{"label": "loan repayment", "weight": 0.4, "gloss": "paying back money that was borrowed"}, {"label": "payment", "weight": 0.25, "gloss": "handing over money owed"}, {"label": "settling a debt", "weight": 0.2, "gloss": "ending an obligation to pay"}, {"label": "financial transaction", "weight": 0.15, "gloss": "a transfer of money between two parties"}],
           "content": [{"label": "personal loan", "weight": 0.4, "gloss": "money lent between individuals, not by a bank"}, {"label": "debt", "weight": 0.25, "gloss": "an amount owed"}, {"label": "money", "weight": 0.2, "gloss": "the means of payment"}, {"label": "family relationship", "weight": 0.15, "gloss": "the tie between brothers"}],
           "outcome": [{"label": "debt cleared", "weight": 0.4, "gloss": "the brother no longer owes"}, {"label": "money received", "weight": 0.25, "gloss": "the lender's funds go up"}, {"label": "money spent", "weight": 0.2, "gloss": "the borrower's funds go down"}, {"label": "obligation discharged", "weight": 0.15, "gloss": "the promise to repay is kept"}],
           "setting": [{"label": "unknown", "weight": 1.0, "gloss": "the statement names no place or sphere"}]},
 "relational": {"participants": [{"ref": "p1", "role": "borrower"}, {"ref": "p2", "role": "lender"}], "action": "repays a loan", "outcome": {"text": "the debt is cleared", "counterfactual": "the debt would have stayed open"}, "links": []}}
```
Here nothing in the text says where the repayment happens, so the setting is the single entry `unknown`; a home or a bank would be a guess.
