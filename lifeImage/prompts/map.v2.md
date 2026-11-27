# Task: map (pass 2 of two-pass extraction, hybrid)

An earlier reader, who did not see the domain list, suggested categories for one life event in its own words. You see
the domain pack, the event text and those suggestions (blind labels). You build the event's memberships from the event
text by the ranked rule below, using the blind labels as hints; you allocate each blind label to the domain or domains
it matches, and review each label that matches no domain. The pack at the end lists every domain, one per line as
`id | label | aliases | description`: the sectors first, then the coarse fields, then the fine domains (a fine domain
ends with its coarse parent in square brackets), each block sorted without grouping. Domains cover all of life (care,
home, faith, play, harm, work, science), not only work. Use only the instructions below, the pack and the task.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge the event by what is
observable in its text. Never infer intentions, motives or beliefs.

Each task gives `input.item` (the event), `input.blind` (per relation `form`, `content`, `outcome`, `setting`: `null`
or a list of labels, each `{"ref", "label", "fit", "gloss"}` with refs like `form.0`, `content.1`) and `input.pass1`,
`input.pack`, which you ignore. The blind fits are the first reader's, made without the pack; they inform your fit but
do not bind it. The labels are hints, not the only source: a label may be too narrow, too fine, filed under another
relation, or missing an obvious category of the event.

## The four relations, sharply

- form: what kind of act or thing the event is, apart from what it is about and what it changes.
- content: what the event is about or engages: its subject matter or object domain.
- outcome: what observably changed relative to what would otherwise have happened; null when the text shows no
  observable difference.
- setting: where, or in which sphere of life, the event takes place; null when the text gives no place.

## Allocate every blind label

Every blind label gets at least one entry in `labels`, keyed by its `ref`:

1. `match`: the label names the same thing as a pack domain. `domain` is that id (any level), `kind` is `exact` when
   the label, lower-cased, equals the domain's label or one of its aliases, and `synonym` otherwise (a different word
   or wording for the same thing, a narrower or broader but still natural reading), and `match` is your confidence
   that the label and the domain are the same category, a number strictly between 0 and 1 (never 1). **A label may
   match several domains: give one `match` entry per domain, with the same `ref`.** When a label names a fine domain
   and its coarse parent (the one in square brackets) also fits the label, match both: the fine domain and its
   parent are not alternatives. Likewise a label may match a coarse field and a near-duplicate field when both name
   the category. Several labels may match one domain. A label matches a domain only for the same category, not for a
   shared word: "kitchen" does not match a domain about kitchens as a trade.
2. `new_domain_candidate` (the only entry of its ref): the label names a plausible category of life that no pack
   domain covers (including when only a much broader domain would hold it). Give `proposed_label` (a short name),
   `gloss` (one line saying what it covers), `nearest` (one to three existing pack ids closest to it), and `parent`
   (the one coarse field or sector id it would sit under). Do not propose a domain that restates one in the pack
   under another name: that is a `match`.
3. `noise` (the only entry of its ref): the label is not a category of life worth a domain: too specific to this
   event (a name, a place), vague, about the writing rather than the event, or an artefact. Give `reason` (one line).

Unmatched labels never become memberships; they are recorded for review.

## Memberships by the ranked stopping rule, from the event text

Build the memberships as in a one-pass reading of the event: per relation, from the whole pack, with the blind
labels as hints and the domains they matched as the first candidates. For each relation that applies:

1. Score every domain you consider for fit, an integer 0 to 10: 9-10 the event plainly is, or centrally engages, that
   domain; 7-8 a clear, substantial part of it; 5-6 a real but secondary aspect, one a careful reader would accept
   (the lowest fit that is listed); 3-4 minor or loose: defensible only with a stretch or an extra assumption,
   tangential, or resting on a shared word rather than the event; 0-2 no real relation.
2. List the domains in decreasing fit, the primary first. Keep adding the next domain while its fit is at least 5 (the
   quality floor). Stop at the first domain whose fit is below 5: do not list it, and do not add any domain after it.
   Equal fits may come in either order. A domain that several labels name is listed once. The fine domain and its
   coarse parent may both be listed when both are true of the event.
3. Do not pad: a domain that merely resembles the event in a keyword, or would only be true under an extra assumption,
   scores below 5. Do not stop early either: a domain with fit 5 or more that you leave out breaks the rule.
4. Name the best rejected domain: the highest-scoring pack domain you did not list, with its fit, which must be below 5.
   If it would score 5 or more, it belongs in the list.
5. Weights: one per listed domain, positive, in the same order, never increasing down the list, summing to 1 within the
   relation. Weights follow the fits, not equal shares by habit.

A listed domain that no blind label of that relation matched is an unlabelled addition: add it to `unlabelled_add`
with its relation. Add one only for an obvious domain of the event (fit 7 or more, or a coarse parent of a listed
domain); the labels were the first source and an addition is the exception. A relation with no domain at fit 5 or
more is `null` in both `types` and `ranks`; all four may be `null`.

## Answer

The verdict is the string `map`. Besides the usual keys the answer line carries:

- `types`: an object with exactly the keys `form`, `content`, `outcome`, `setting`; each `null` or
  `{domain id: weight}` over ids from the pack, in rank order.
- `ranks`: the same four keys; each `null` exactly when its `types` entry is `null`, otherwise
  `{"listed": [{"domain": <id>, "fit": <integer>}, ...], "rejected": {"domain": <id>, "fit": <integer>}}`, `listed` having
  the same domains in the same order as `types`, fits never increasing and all at least 5, `rejected` a pack domain not
  in `listed` with a fit below 5.
- `labels`: the entries above, in any order: `{"ref", "action": "match", "domain", "kind", "match"}` (one per domain a
  label matches), `{"ref", "action": "new_domain_candidate", "proposed_label", "gloss", "nearest": [ids], "parent": <id>}` or
  `{"ref", "action": "noise", "reason"}`; every ref has entries, a `new_domain_candidate` or a `noise` alone.
- `unlabelled_add`: a list (empty when none) of `{"relation", "domain"}`, one for every listed domain that no label of
  that relation matched; every listed domain is either matched by a label of its relation or named here, never both.

Give a one-line reason naming what decided the most important relation and where its list stopped.

## Worked example

Event: "A woman bakes bread for her neighbours". Blind labels: form.0 "baking" (9), form.1 "neighbourly gifting" (6);
content.0 "bread" (8). Against a pack holding `f.baking_bread` (Baking bread, [c.cooking]), `c.cooking` (Cooking, alias
"food preparation"), `c.neighbours_community` (Neighbours and community) and no gifting domain:
```json
{"types": {"form": {"f.baking_bread": 0.6, "c.cooking": 0.4}, "content": {"f.baking_bread": 0.6, "c.cooking": 0.4}, "outcome": null,
           "setting": {"c.neighbours_community": 1.0}},
 "ranks": {"form": {"listed": [{"domain": "f.baking_bread", "fit": 9}, {"domain": "c.cooking", "fit": 8}], "rejected": {"domain": "c.neighbours_community", "fit": 3}},
           "content": {"listed": [{"domain": "f.baking_bread", "fit": 9}, {"domain": "c.cooking", "fit": 7}], "rejected": {"domain": "c.neighbours_community", "fit": 3}},
           "outcome": null,
           "setting": {"listed": [{"domain": "c.neighbours_community", "fit": 7}], "rejected": {"domain": "c.cooking", "fit": 2}}},
 "labels": [{"ref": "form.0", "action": "match", "domain": "f.baking_bread", "kind": "synonym", "match": 0.85},
            {"ref": "form.0", "action": "match", "domain": "c.cooking", "kind": "synonym", "match": 0.7},
            {"ref": "form.1", "action": "new_domain_candidate", "proposed_label": "Neighbourly gifting", "gloss": "giving goods or help to people nearby without payment", "nearest": ["c.neighbours_community"], "parent": "s.home"},
            {"ref": "content.0", "action": "match", "domain": "f.baking_bread", "kind": "synonym", "match": 0.9},
            {"ref": "content.0", "action": "match", "domain": "c.cooking", "kind": "synonym", "match": 0.6}],
 "unlabelled_add": [{"relation": "setting", "domain": "c.neighbours_community"}]}
```
Here the one label "baking" matches the fine domain and its coarse parent, both are listed; the setting is an obvious domain of the
event that no blind label named, so it is an unlabelled addition.
