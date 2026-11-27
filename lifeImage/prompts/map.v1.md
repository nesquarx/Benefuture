# Task: map (pass 2 of two-pass extraction)

An earlier reader, who did not see the domain list, suggested categories for one life event in its own words. You see
the domain pack, the event text and those suggestions (blind labels). You allocate each blind label to the domain it
matches, and review each label that matches no domain. The pack at the end lists every domain, one per line as
`id | label | aliases | description`: the sectors first, then the coarse fields, then the fine domains (a fine domain
ends with its coarse parent in square brackets), each block sorted without grouping. Domains cover all of life (care,
home, faith, play, harm, work, science), not only work. Use only the instructions below, the pack and the task.

Each task gives `input.item` (the event), `input.blind` (per relation `form`, `content`, `outcome`, `setting`: `null`
or a list of labels, each `{"ref", "label", "fit", "gloss"}` with refs like `form.0`, `content.1`) and `input.pass1`,
`input.pack`, which you ignore. The blind fits are the first reader's, made without the pack; they inform your fit but
do not bind it.

## Allocate every blind label

Every blind label gets exactly one entry in `labels`, keyed by its `ref`:

1. `match`: the label names the same thing as one pack domain. `domain` is that id (any level; prefer the fine domain
   when one fits the label as well as its parent, and the coarse one when none does), `kind` is `exact` when the
   label, lower-cased, equals the domain's label or one of its aliases, and `synonym` otherwise (a different word or
   wording for the same thing, a narrower or broader but still natural reading), and `match` is your confidence that
   the label and the domain are the same category, a number strictly between 0 and 1 (never 1). Several labels may
   match one domain. A label matches a domain only for the same category, not for a shared word: "kitchen" does not
   match a domain about kitchens as a trade.
2. `new_domain_candidate`: the label names a plausible category of life that no pack domain covers (including when
   only a much broader domain would hold it). Give `proposed_label` (a short name for the domain), `gloss` (one line
   saying what it covers), `nearest` (one to three existing pack ids closest to it), and `parent` (the one coarse field
   or sector id it would sit under). Do not propose a domain that restates one in the pack under another name: that
   is a `match`.
3. `noise`: the label is not a category of life worth a domain: too specific to this event (a name, a place), vague,
   about the writing rather than the event, or an artefact. Give `reason` (one line).

Unmatched labels never become memberships; they are recorded for review.

## Memberships by the ranked stopping rule

From the matched labels, build the memberships as before, per relation, using only domains that some label of that
relation matched. For each relation that applies:

1. Score each matched domain for fit, an integer 0 to 10: 9-10 the event plainly is, or centrally engages, that
   domain; 7-8 a clear, substantial part of it; 5-6 a real but secondary aspect, one a careful reader would accept
   (the lowest fit that is listed); 3-4 minor or loose: defensible only with a stretch or an extra assumption,
   tangential, or resting on a shared word rather than the event; 0-2 no real relation.
2. List the domains in decreasing fit, the primary first. Keep adding the next domain while its fit is at least 5 (the
   quality floor). Stop at the first domain whose fit is below 5: do not list it, and do not add any domain after it.
   Equal fits may come in either order. When the blind labels already name the same domain more than once, list it once.
3. Name the best rejected domain: the highest-scoring pack domain you did not list, with its fit, which must be below 5.
   It records where you stopped. If it would score 5 or more, it belongs in the list.
4. Weights: one per listed domain, positive, in the same order, never increasing down the list, summing to 1 within the
   relation. Weights follow the fits, not equal shares by habit.

A relation with no matched domain at fit 5 or more is `null` in both `types` and `ranks`; all four may be `null` when
nothing matched. Never add a domain to `types` that no label of that relation matched.

## Answer

The verdict is the string `map`. Besides the usual keys the answer line carries:

- `types`: an object with exactly the keys `form`, `content`, `outcome`, `setting`; each `null` or
  `{domain id: weight}` over ids from the pack, in rank order.
- `ranks`: the same four keys; each `null` exactly when its `types` entry is `null`, otherwise
  `{"listed": [{"domain": <id>, "fit": <integer>}, ...], "rejected": {"domain": <id>, "fit": <integer>}}`, `listed` having
  the same domains in the same order as `types`, fits never increasing and all at least 5, `rejected` a pack domain not
  in `listed` with a fit below 5.
- `labels`: one entry per blind label, as above:
  `{"ref", "action": "match", "domain", "kind", "match"}`,
  `{"ref", "action": "new_domain_candidate", "proposed_label", "gloss", "nearest": [ids], "parent": <id>}` or
  `{"ref", "action": "noise", "reason"}`.

Give a one-line reason naming what decided the most important relation and where its list stopped.

## Worked example

Event: "A woman bakes bread for her neighbours". Blind labels: form.0 "baking" (9), form.1 "neighbourly gifting" (6);
content.0 "bread" (8). Against a pack holding `f.baking_bread` (Baking bread, [c.cooking]), `c.cooking` (Cooking, alias
"food preparation") and no gifting domain:
```json
{"types": {"form": {"f.baking_bread": 1.0}, "content": {"f.baking_bread": 1.0}, "outcome": null, "setting": null},
 "ranks": {"form": {"listed": [{"domain": "f.baking_bread", "fit": 9}], "rejected": {"domain": "c.cooking", "fit": 4}},
           "content": {"listed": [{"domain": "f.baking_bread", "fit": 9}], "rejected": {"domain": "c.cooking", "fit": 4}},
           "outcome": null, "setting": null},
 "labels": [{"ref": "form.0", "action": "match", "domain": "f.baking_bread", "kind": "synonym", "match": 0.85},
            {"ref": "form.1", "action": "new_domain_candidate", "proposed_label": "Neighbourly gifting", "gloss": "giving goods or help to people nearby without payment", "nearest": ["c.cooking"], "parent": "s.home"},
            {"ref": "content.0", "action": "match", "domain": "f.baking_bread", "kind": "synonym", "match": 0.9}]}
```
