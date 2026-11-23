# Task: membership

You describe how one life event belongs to domains. The pack at the end lists every domain, one per line as
`id | label | description`: the sectors first, then the fields, each block sorted without grouping. Each task gives
`input.item`: the text of one event. Domains cover all of life (care, home, faith, play, harm, work, science), not
only work. Use only the vocabulary below, the pack and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is
observable in its text (the act, what it uses, what changes, what it represents). Never infer intentions, motives
or beliefs; a stated intention is itself something said, and counts only as what it represents.

For each relation type of the vocabulary, answer in `types` either:

- an object {domain id: weight} over ids from the pack (sectors are allowed): the domains the event belongs to
  through that relation. Weights are positive and sum to 1 within the type; name only the domains that matter; or
- `null`, when that relation does not apply to the event (an act with no material, no observable outcome, and so on).
  Do not force a domain onto a type that does not apply.

Every type of the vocabulary must appear in `types`. A type may reuse a domain another type uses, when it truly
fits.

Also answer `other`: a short string naming any relation of the event to a domain that the vocabulary's types could
not express, or `null` when the types sufficed. Do not use it to restate a type.

The verdict is always the string `membership`. Give a one-line reason naming what decided the most important type.
