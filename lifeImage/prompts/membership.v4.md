# Task: membership (ranked, wide)

You describe how one life event belongs to domains. The pack at the end lists every domain, one per line as
`id | label | description`: the sectors first, then the fields, each block sorted without grouping. Each task gives
`input.item`: the text of one event. Domains cover all of life (care, home, faith, play, harm, work, science), not
only work. Use only the instructions below, the pack and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is
observable in its text. Never infer intentions, motives or beliefs; a stated intention is itself something said, and
counts only as what it represents.

## The four relations, sharply

- form: what kind of act or thing the event is. Name the act itself, apart from what it is about and what it
  changes. Depicting an act is a different act from doing it: an actor playing a surgeon is acting (performing arts),
  a surgeon operating is surgery (medical care). Watching a film is spectating; writing a review of it is reviewing.
- content: what the event is about or engages: its subject matter or object domain. Watching a film and reviewing the
  same film share the film as content; an actor playing a surgeon and a surgeon operating share medicine as content.
- outcome: what observably changed relative to what would otherwise have happened. A prevented harm counts: a
  vaccinated child who stays well through an outbreak is an outcome in preventive health. Never intentions, never what
  the event was meant to do. When the text shows no observable difference from the counterfactual, the outcome is null.
- setting: where, or in which sphere of life, the event takes place: a venue, an institution, a sphere. Null when the
  text gives no place.

## Wide memberships by a ranked stopping rule

An event usually belongs to several domains through one relation. Name them all, best first, and stop only where a
further domain would be a poor categorisation. For each relation that applies:

1. Score every domain you consider for fit, an integer 0 to 10: 9-10 the event plainly is, or centrally engages,
   that domain; 7-8 a clear, substantial part of it; 5-6 a real but secondary aspect, one a careful reader would accept
   (the lowest fit that is listed); 3-4 minor or loose: defensible only with a stretch or an extra assumption,
   tangential, or resting on a shared word rather than the event; 0-2 no real relation.
2. List the domains in decreasing fit, the primary domain first. Keep adding the next domain while its fit is at
   least 5 (the quality floor). Stop at the first domain whose fit is below 5: do not list it, and do not add any
   domain after it. Equal fits may come in either order.
3. Do not pad. A domain that merely resembles the event in a keyword, or that would only be true under an extra
   assumption, scores below 5. A plain event may well list one domain; a composite event lists several. Do not stop
   early either: a domain with fit 5 or more that you leave out breaks the rule.
4. Name the best rejected domain: the highest-scoring domain you did not list, with its fit, which must be below 5.
   It records where and why you stopped. If it would score 5 or more, it belongs in the list.
5. Weights: one per listed domain, positive, in the same order, never increasing down the list, summing to 1 within
   the relation. Weights follow the fits (a fit of 9 outweighs a fit of 5), they are not equal shares by habit.

A relation that does not apply to the event is `null` in both `types` and `ranks`: **declining is correct and
expected** (most events have no observable outcome beyond the act itself, and many give no setting). Do not force a
domain onto a relation to fill it. A domain may appear under several relations when it truly fits each.

## Answer

The verdict is the string `membership`. Besides the usual keys the answer line carries:

- `types`: an object with exactly the keys `form`, `content`, `outcome`, `setting`; each is `null` or
  `{domain id: weight}` over ids from the pack (sectors are allowed), written in rank order.
- `ranks`: an object with the same four keys; each is `null` exactly when its `types` entry is `null`, otherwise
  `{"listed": [{"domain": <id>, "fit": <integer>}, ...], "rejected": {"domain": <id>, "fit": <integer>}}`, where
  `listed` has the same domains in the same order as `types`, fits never increase down the list and are all at least 5,
  and `rejected` is a pack domain not in `listed` with a fit below 5.
- `other`: a short string naming any relation of the event to a domain that the four relations could not express, or
  `null` when they sufficed. Do not use it to restate a relation.

Give a one-line reason naming what decided the most important relation and where its list stopped.

## Worked examples

Each shows the `types` and `ranks` of one event (outcome and setting included where they apply).

Event: "Two friends watch a documentary about glaciers at a cinema"
```json
{"types": {"form": {"c.film_tv_video": 0.62, "c.cultural_visits": 0.38},
           "content": {"c.earth_sciences": 0.42, "c.film_tv_video": 0.38, "c.weather_climate_adaptation": 0.2},
           "outcome": null,
           "setting": {"c.cultural_visits": 0.55, "c.film_tv_video": 0.45}},
 "ranks": {"form": {"listed": [{"domain": "c.film_tv_video", "fit": 9}, {"domain": "c.cultural_visits", "fit": 5}], "rejected": {"domain": "c.festivals_events", "fit": 3}},
           "content": {"listed": [{"domain": "c.earth_sciences", "fit": 8}, {"domain": "c.film_tv_video", "fit": 7}, {"domain": "c.weather_climate_adaptation", "fit": 5}], "rejected": {"domain": "c.ecology_science", "fit": 4}},
           "outcome": null,
           "setting": {"listed": [{"domain": "c.cultural_visits", "fit": 7}, {"domain": "c.film_tv_video", "fit": 6}], "rejected": {"domain": "c.nightlife", "fit": 3}}}}
```

Event: "A nurse gives a child a measles vaccination at a clinic, and the child stays well through the outbreak that follows"
```json
{"types": {"form": {"c.medical_care": 0.5, "c.preventive_health": 0.3, "c.healthcare_work": 0.2},
           "content": {"c.preventive_health": 0.6, "c.public_health_science": 0.4},
           "outcome": {"c.preventive_health": 0.54, "c.physical_health": 0.46},
           "setting": {"c.medical_care": 0.62, "c.healthcare_work": 0.38}},
 "ranks": {"form": {"listed": [{"domain": "c.medical_care", "fit": 9}, {"domain": "c.preventive_health", "fit": 6}, {"domain": "c.healthcare_work", "fit": 5}], "rejected": {"domain": "c.childcare_other", "fit": 2}},
           "content": {"listed": [{"domain": "c.preventive_health", "fit": 9}, {"domain": "c.public_health_science", "fit": 5}], "rejected": {"domain": "c.medication_adherence", "fit": 3}},
           "outcome": {"listed": [{"domain": "c.preventive_health", "fit": 8}, {"domain": "c.physical_health", "fit": 7}], "rejected": {"domain": "c.public_safety_emergency", "fit": 2}},
           "setting": {"listed": [{"domain": "c.medical_care", "fit": 9}, {"domain": "c.healthcare_work", "fit": 5}], "rejected": {"domain": "c.public_administration", "fit": 2}}}}
```

Event: "A man waters tomato plants on his balcony"
```json
{"types": {"form": {"c.household_gardening": 1.0},
           "content": {"c.household_gardening": 1.0},
           "outcome": null,
           "setting": {"c.home_organisation": 1.0}},
 "ranks": {"form": {"listed": [{"domain": "c.household_gardening", "fit": 9}], "rejected": {"domain": "c.horticulture_farming", "fit": 3}},
           "content": {"listed": [{"domain": "c.household_gardening", "fit": 8}], "rejected": {"domain": "c.horticulture_farming", "fit": 4}},
           "outcome": null,
           "setting": {"listed": [{"domain": "c.home_organisation", "fit": 6}], "rejected": {"domain": "c.outdoor_recreation", "fit": 3}}}}
```
