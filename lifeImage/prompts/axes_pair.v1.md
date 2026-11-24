# Task: axes_pair

You compare two domains of human life on one axis. Each task gives `input.axis`, `input.toward` and two domain
cards, `input.a` and `input.b`, each with an id, label, description and the labels of its sectors. Domains cover all
of life (care, home, faith, play, harm, work, science), not only work. Judge each domain as most people live it, not
its academic study, unless the domain is itself a field of study.

The axes:

- `abstract_tangible`, toward tangible: a domain is further toward tangible the more it is about bodies, objects,
  materials, places and physical acts, and further toward abstract the more it is about ideas, symbols, meaning and
  minds.
- `personal_global`, toward global and professional: a domain is further toward global and professional the more it is
  lived in institutions, professions, markets, states and the world at large, and further toward personal the more it
  is lived in the self, family, friends and the local community.

The question: which of the two domains is further toward the pole named in `input.toward`?

Answer "a" or "b" when one is clearly further, "tie" when they are about equal or you cannot tell them apart on this
axis. Judge only this axis and only these two domains; the position in which a domain is shown means nothing.

The verdict is exactly one of "a", "b" or "tie".

Reason: one line naming what decided it.
