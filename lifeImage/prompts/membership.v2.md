# Task: membership

You describe how one life event belongs to domains. The pack at the end lists every domain, one per line as
`id | label | description`: the sectors first, then the fields, each block sorted without grouping. Each task gives
`input.item`: the text of one event. Domains cover all of life (care, home, faith, play, harm, work, science), not
only work. Use only the vocabulary below, the pack and the item.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. Judge an event by what is
observable in its text. Never infer intentions, motives or beliefs; a stated intention is itself something said, and
counts only as what it represents.

## The types, sharply

- form: what kind of act or thing the event is. Name the act itself, apart from what it is about and what it
  changes. Depicting an act is a different act from doing it: an actor playing a surgeon is acting (performing arts),
  a surgeon operating is surgery (medical care). Watching a film is spectating; writing a review of it is reviewing.
- content: what the event is about or engages: its subject matter or object domain, as one type. Watching a film and
  reviewing the same film share the film as content; an actor playing a surgeon and a surgeon operating share
  medicine as content.
- outcome: what observably changed relative to what would otherwise have happened. A prevented harm counts: a
  vaccinated child who stays well through an outbreak is an outcome in preventive health, where doing nothing would
  have left the risk standing. Never intentions, never what the event was meant to do. When the text shows no
  observable difference from the counterfactual, the outcome is null.
- setting (where the vocabulary has it): where, or in which sphere of life, the event takes place: a venue, an
  institution, a sphere. Null when the text gives no place.
- flavour (where the vocabulary has it): the domain whose flavour the event has. Answer it as the definition says,
  without second-guessing.

The vocabulary below repeats each definition with four worked examples. Each example shows one type's answer to one
event; the same four events recur so the types can be compared.

## Answering

For each relation type of the vocabulary, answer in `types` either:

- an object {domain id: weight} over ids from the pack (sectors are allowed): the domains the event belongs to
  through that relation. Weights are positive and sum to 1 within the type; name only the domains that matter; or
- `null`, when that relation does not apply to the event.

**Declining is correct and expected when a type does not apply.** Answer `null` for such a type, and use `other` for
a relation the vocabulary cannot express. Do not force a domain onto a type to fill it; an answer with some `null`
types is better than one that fits every type loosely. Most events have no observable outcome beyond the act itself,
and many give no setting.

Every type of the vocabulary must appear in `types`. A type may reuse a domain another type uses, when it truly
fits.

Also answer `other`: a short string naming any relation of the event to a domain that the vocabulary's types could
not express, or `null` when the types sufficed. Do not use it to restate a type.

The verdict is always the string `membership`. Give a one-line reason naming what decided the most important type.
