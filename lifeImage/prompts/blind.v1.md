# Task: blind (pass 1 of two-pass extraction)

You read one event, of any detail, and suggest how it could be categorised, in your own words. You are not given any
list of categories, and you must not try to recall or invent identifiers for one: write plain short phrases. A second
reader later maps your phrases onto a fixed list; your job is to say what the event is, and what it could be filed
under, as faithfully and as widely as the text supports. Each task gives `input.item`: the text of one event. Use only
these instructions and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is
observable in its text. Never infer intentions, motives or beliefs; a stated intention is itself something said, and
counts only as what it represents.

## The four relations, sharply

- form: what kind of act or thing the event is. Name the act itself, apart from what it is about and what it
  changes. Depicting an act is a different act from doing it: an actor playing a surgeon is acting, a surgeon
  operating is surgery.
- content: what the event is about or engages: its subject matter or object. An actor playing a surgeon and a surgeon
  operating share medicine as content.
- outcome: what observably changed relative to what would otherwise have happened. A prevented harm counts. Never
  intentions, never what the event was meant to do. When the text shows no observable difference from the
  counterfactual, the outcome is null.
- setting: where, or in which sphere of life, the event takes place: a venue, an institution, a sphere. Null when the
  text gives no place.

## Suggest categories, best first

For each relation that applies, list the categories you would file the event under, best first:

- `label`: a short phrase of one to five words, in everyday or professional wording (for example "bread baking",
  "neighbourly gifting", "physiotherapy"). Never an identifier, never a code, never a dotted name.
- `fit`: an integer 0 to 10 for how well the event belongs under that label: 9-10 the event plainly is, or centrally
  engages, it; 7-8 a clear, substantial part; 5-6 a real but secondary aspect a careful reader would accept; 4 a fair
  categorisation, defensible though minor.
- `gloss`: one line saying what you mean by the label here, so a reader with a list can match it to its entry.

List labels in decreasing fit, never more than 6 per relation, and keep only labels with a fit of at least 4. Do not
pad: a label that only shares a keyword with the event does not belong. Do not stop early either: a label you would
accept at 4 or more belongs in the list. Use the wording the event invites, including fine and unusual categories; a
label need not be a common one. A relation that does not apply is `null`: declining is correct and expected (most
events have no observable outcome beyond the act itself, and many give no setting). Do not force a label onto a
relation to fill it. A label may appear under several relations when it truly fits each.

## The relational extraction

Besides the categories, record the event's relational structure as the text states it, at whatever detail the text
has (a bare statement gives very little; a long account gives more):

- `participants`: the entities in the event, each `{"ref": "p1", "role": <one or two words>}` with refs `p1`, `p2`, and so
  on, distinct. Roles are plain words (actor, helper, patient, beneficiary, organisation, bystander). The list may be
  empty when the text names nobody.
- `action`: one short line naming what is done or happens.
- `outcome`: `null` when no observable change is stated or directly shown, otherwise
  `{"text": <what changed>, "counterfactual": <what would otherwise have happened, or null when the text does not say or show it>}`.
  Never invent the counterfactual.
- `links`: relations to other occurrences the text states, each `{"type": <type>, "other": <short label of the other
  occurrence>}` with type one of `part_of` (this event is a part of the other, or the other of this), `causes` (this
  event brings the other about, or the other this), `re_description` (the same occurrence described differently),
  `concurrent` (they happen together). Empty when the text states none.

## Answer

The verdict is the string `blind`. Besides the usual keys the answer line carries:

- `blind`: an object with exactly the keys `form`, `content`, `outcome`, `setting`; each `null` or a list of
  `{"label": <string>, "fit": <integer>, "gloss": <string>}` in decreasing fit.
- `relational`: `{"participants": [...], "action": <string>, "outcome": <null or object>, "links": [...]}`.

Give a one-line reason naming what decided the most important relation. Worked example (an invented event, not a real
one):

Event: "A retired joiner repairs a neighbour's fence on Sunday and the gate stops sticking"
```json
{"blind": {"form": [{"label": "carpentry repair", "fit": 9, "gloss": "mending woodwork with joinery skill"}, {"label": "neighbourly help", "fit": 7, "gloss": "unpaid help given to someone nearby"}],
           "content": [{"label": "fences and gates", "fit": 8, "gloss": "the structure repaired"}, {"label": "home maintenance", "fit": 6, "gloss": "keeping a property in working order"}],
           "outcome": [{"label": "restored function", "fit": 7, "gloss": "the gate works again"}],
           "setting": [{"label": "residential street", "fit": 5, "gloss": "a neighbour's property"}]},
 "relational": {"participants": [{"ref": "p1", "role": "helper"}, {"ref": "p2", "role": "neighbour"}], "action": "repairs a fence",
                "outcome": {"text": "the gate stops sticking", "counterfactual": "the gate would have kept sticking"}, "links": []}}
```
