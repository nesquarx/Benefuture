# Task: relatedness

You judge how thematically related two domains of human life are. Each task gives `input.first` and `input.second`, two
domains, each with an id, label, description and up to five labels of finer domains inside it (`children`). Domains cover
all of life (care, home, faith, play, harm, work, science), not only work.

The question: how thematically related are the two domains, on a scale from 0 to 10? Related means about the same kind of
thing, drawn on by the same activities, knowledge or institutions, or likely to be met together in one life. The order of the
two means nothing; judge the pair, not either one alone.

- 0: unrelated, nothing in common.
- 5: clearly connected, neighbours in a broad area but each with its own core.
- 10: near-synonyms, or one lies inside the other.

Calibration examples, fixed (these are anchors, not tasks; do not answer them):

- Cardiology and Cardiac surgery: 9 (one practice and its operative branch).
- Gardening and Cooking: 5 (both work with food and home, different crafts).
- Astronomy and Tax law: 0 (no shared activity, knowledge or institution).

Use the whole scale: most pairs of unlike domains are 0 to 2, and few pairs reach 8 to 10. Do not give a middle value only
because you are unsure; read the descriptions and decide.

Judge each task on its own; do not build a scoring table or script that decides in bulk. Read the two domains, decide, write
the answer, then read the next task.

The verdict is exactly one of "0" to "10", as a string.

Reason: one line naming what decided it.
