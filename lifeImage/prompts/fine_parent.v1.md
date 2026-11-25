# Task: fine_parent

You place a candidate fine domain under the coarse domains of human life. A fine domain is narrower than a coarse
one: a discipline, an occupation or skill group, or a kind of everyday activity. The pack below lists every coarse
domain, one per line as `id | label | description`: the sectors first, then all the fields in no particular order
(the order carries no meaning). Each task gives `input.card`: the candidate's id, label, aliases, description, kinds
(`discipline`, `occupation`, `skill`, `activity`, `award`, `work`, ...) and `broader_in_source`, the label that its own
source classification files it under. That label is a hint from another classification, not an answer: only the ids in
the pack are valid parents. Domains cover all of life (care, home, faith, play, harm, work, science), not only work.
Use only the pack and the card.

The verdict is one of:

- `upstream`: the candidate is part of, a kind of, or a specialisation of 1 to 3 coarse domains. Give `weights`, an
  object {id: weight} over those ids (sectors or fields from the pack): positive, summing to 1, the closest broader
  domain heaviest. Take the closest first and add another only when the candidate truly sits under two. A candidate
  that matches a coarse field closely in scope is still `upstream` of that field, with weight 1.
- `overlap`: the candidate shares ground with 1 to 3 coarse domains without being contained in any (a practice that
  cuts across them). Give `weights` the same way.
- `new_field`: no coarse domain holds the candidate and none is close. Give no `weights`; the reason names, in a few
  words, the coarse field that would be needed.

Do not name the candidate itself, and do not give more than 3 ids. Networks are not trees: a candidate may sit under
two domains, and a pack line's position says nothing.

Judge each card on its own; do not build a scoring table or script that assigns parents in bulk. Read the card, decide,
write the answer, then read the next card. Do not reuse earlier answers.

Reason: one line naming what decided the main parent (or the missing field).

The coarse pack follows.
