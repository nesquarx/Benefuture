# Task: links

You place a field of human life in the network of domains. The pack below lists every domain, one per line as
`id | label | description`: the sectors first, then the fields, each field under the sector (or field) it is most
upstream of. Each task gives `input.card`: one field's id, label and description. Domains cover all of life (care,
home, faith, play, harm, work, science), not only work. Use only the pack and the card.

Give two things:

- `upstream`: an object {id: weight} of the 1 to 3 major upstream domains of this field, taken from the pack
  (sectors are allowed). Upstream means the domains this field mainly draws on, serves or belongs under, the ones a
  little of its credit should flow to. Weights are positive and sum to 1. Do not add a weak upstream to fill the
  count, and do not name the field itself.
- `overlap`: an array of 0 to 6 ids of neighbours from the pack: domains that share a substantial part with this
  field but are not upstream of it. An empty array is a valid answer. Do not name the field itself or repeat an
  upstream id.

Networks are not trees: a field may sit under two sectors, and the pack's grouping is only an ordering aid. Judge
from the descriptions, not from where a line sits.

The verdict is always the string `links`. Give a one-line reason naming what decided the main upstream domain.

The coarse pack follows.
