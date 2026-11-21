# Task: roundtrip

Each task gives `input.annotation`: how one life event relates to domains, with no event text. For each relation type
it lists the domains (id, label, weight) the event belongs to through that relation, or `null` when the type did not
apply. It also gives `input.candidates`: five event texts `c1` to `c5`. Exactly one is the event the annotation was
made from; the other four are distractors. Distractors can be close: some share the act, the subject or the place, and
some differ from the original only in a detail.

Pick the candidate the annotation describes. Judge only by what the annotation and the texts contain: the act, what
it concerns, what observably changed, where it took place, as the annotation's types say. Never infer intentions.
A `null` type is information too (nothing observable changed, no place was given). When several candidates fit
equally, still pick one: choose the one that fits every type best, and say in the reason which type decided it, or
that nothing in the annotation separated them.

The verdict is the id of the chosen candidate, exactly one of `c1` to `c5`. Give a one-line reason.
