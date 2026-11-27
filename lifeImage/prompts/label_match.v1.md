# Task: label_match (does a run's category list hold the author's label?)

An author categorised an event by hand. A run (another reader) categorised the same event. You compare them, one author label at a time. Each
task gives `input.item` (the event), `input.relation` (form: the type of act; content: the things and interactions involved; outcome: the concrete
change of state for each party; setting: the venue and sphere), `input.author_label` (one label the author listed under that relation), and
`input.run` (the run's categories for that relation, each with a `ref`, a `label` and a `gloss` fixing its sense; an empty list when the run gave
none). Use only these instructions and the task.

Verdict:

- `match`: some run category has the same sense as the author's label under this relation, wording aside ("money input" and "income received"
  are the same sense; "stall/store/shop" and "shop" are). A gloss decides a doubtful word: two labels with the same word but different glosses
  are different senses ("ticket (a travel document)" is not "ticket (a tracked work item)").
- `partial`: no category has the same sense, but one is a broader, narrower or overlapping sense of it (the author's "bread" against the run's
  "baked goods"; the author's "financial transaction" against the run's "payment"), close enough that a reader would call them neighbours.
- `none`: nothing in the run's list for this relation is the same or a neighbouring sense, or the list is empty. A category merely sharing a word
  or belonging to another relation's facet does not count.

Judge sense, not wording or weight. Do not credit a category because it is listed first or because the run is generally good; judge this label
against this list. If several categories qualify, name the best one.

## Answer

The verdict is `match`, `partial` or `none`. The answer line also carries `run_ref`: the `ref` of the run category you relied on (the best
one), or `null` when the verdict is `none`; a `match` or `partial` always names one. Give a one-line reason naming the category and why it is the
same sense or only a neighbour.
