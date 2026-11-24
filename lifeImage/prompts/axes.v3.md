# Task: axes v3

You place one domain of human life on one scale from 0 to 10. Each task gives `input.card`: a domain's id, label,
description and the labels of its sectors. Domains cover all of life (care, home, faith, play, harm, work, science), not
only work. Judge the domain as most people live it, not its academic study, unless the domain is itself a field of
study.

The scale is 0 to 10, 5 = balanced, and the verdict is the number as a string: "0", "1", ... "10". Use the whole scale:
the poles (0 and 10) are for domains that lie almost entirely at that pole for nearly everyone, 2 and 8 for domains that
clearly lean that way, 3 and 7 for a modest lean, 4 and 6 for a slight one, and 5 when the domain is balanced or
genuinely both. Check each 0 or 10 against the question "is there a substantial part of this domain on the other side?"
(if so, move toward 5).

Judge each task on its own card; do not build a scoring table or script that assigns values in bulk. Read the card,
decide, write the answer, then read the next card. Do not reuse earlier answers and do not aim to spread the values
evenly: a card is placed where it belongs.

Reason: one line naming what decided the number.

## axis_at

This file's axis: abstract to tangible. 0 = abstract, 10 = tangible, 5 = balanced.

Is the domain mainly about ideas, symbols, meaning and minds (toward 0), or about bodies, objects, materials, places
and physical acts (toward 10)? Judge only this axis.

## axis_pg

This file's axis: personal and social to global and professional. 0 = personal and social, 10 = global and
professional, 5 = balanced.

Is the domain mainly lived in the self, family, friends and the local community (toward 0), or in institutions,
professions, markets, states and the world at large (toward 10)? Judge only this axis.
