# Task: radius v1

You place one coarse domain of human life on one scale from 0 to 10: how advanced and specialised the domain is as most
people meet it. Each task gives `input.card`: a domain's id, label, description and the labels of its sectors. Domains
cover all of life (care, home, faith, play, harm, work, science), not only work. Judge the domain as most people meet
it, not its most advanced research frontier, unless the domain is itself a field of study.

The scale is 0 to 10 and the verdict is the number as a string: "0", "1", ... "10".

- 0 = elementary: everyone does it or knows it, with no training beyond growing up, like sleep or everyday
  conversation.
- 10 = highly specialised: long training, few people practise it, like quantum decoherence or neurosurgery.
- 5 = in between: a skill many learn with deliberate effort, such as driving, cooking well or bookkeeping.

Weigh three aspects together:

- complexity: how many interacting parts, concepts or prerequisites the domain draws on;
- difficulty: how much time, training and practice it takes to do well;
- specificity: how narrow it is, how few people practise or need it, and how far it sits from common experience.

Use the whole scale: the poles (0 and 10) are for domains that lie almost entirely at that pole for nearly everyone, 2
and 8 for domains that clearly lean that way, 3 and 7 for a modest lean, 4 and 6 for a slight one. Check each 0 or 10
against the question "is there a substantial part of this domain at the other end?" (if so, move toward 5).

Judge each task on its own card; do not build a scoring table or script that assigns values in bulk. Read the card,
decide, write the answer, then read the next card. Do not reuse earlier answers and do not aim to spread the values
evenly: a card is placed where it belongs.

Reason: one line naming what decided the number.
