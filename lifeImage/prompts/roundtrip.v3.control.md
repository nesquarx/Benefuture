# Task: roundtrip (control)

Each task gives `input.candidates`: five event texts `c1` to `c5`. Exactly one is the original of an annotation of
life-event domains that you are not shown; the other four are distractors whose annotations are close to the
original's, and whose texts are of similar length and wording. There is no annotation here, so nothing in the input
says which is the original.

Pick the candidate you judge most likely to be the original, using only the texts. When nothing separates them, still
pick one, and say in the reason what you went by, or that nothing separated them. Never infer intentions.

The verdict is the id of the chosen candidate, exactly one of `c1` to `c5`. Give a one-line reason.
