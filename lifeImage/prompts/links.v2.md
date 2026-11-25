# Task: links

You place a field of human life in the network of domains. The pack below lists every domain, one per line as
`id | label | description`: the sectors first, then all the fields in no particular order (the order carries no
meaning, and no field is listed under any other). Each task gives `input.card`: one field's id, label and
description. Domains cover all of life (care, home, faith, play, harm, work, science), not only work. Use only the
pack and the card.

Give two things:

- `upstream`: an object {id: weight} of the 1 to 3 domains this field is part of or draws on. An upstream domain is
  broader than the field: the field belongs under it, serves it or builds on it, and a little of the field's credit
  should flow to it. Upstream may be a sector or another field: a narrow field often sits under a broader field
  (a craft under its trade, a method under its science) and only the broadest ones sit directly under a sector.
  Take the closest broader domain first, whether it is a field or a sector, and add another only when the field
  truly sits under two. Weights are positive and sum to 1. Do not add a weak upstream to fill the count, do not name
  the field itself, and do not name a narrower field as upstream.
- `overlap`: an array of 0 to 6 ids of neighbours from the pack, sectors or fields: domains that share ground with
  this field without including it or being included in it. An empty array is a valid answer. Do not name the field
  itself or repeat an upstream id.

Networks are not trees: a field may sit under two domains, and a pack line's position says nothing. Judge from the
descriptions only.

The verdict is always the string `links`. Give a one-line reason naming what decided the main upstream domain.

The coarse pack follows.
