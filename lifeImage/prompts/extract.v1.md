# Task: extract

You read one person's resume and write down the claims it makes, as evidence rows of the claimed tier. Each task
gives `input.lines`, the resume's non-blank lines each numbered `L<n>: ...`, plus `input.entity`, `input.source` and
`input.as_of` (the date of reading). The pack at the end lists every domain, one per line as
`id | label | description`: the sectors first, then the fields, each block sorted without grouping. Domains cover all
of life (care, home, faith, play, work, learning, science), not only work. Use only the resume, the pack and these
instructions.

Benefuture reads outputs only: beliefs and preferences are not directly accessible. A resume is a self-report, so
record each claim as the text makes it. Do not verify, doubt, flatter or soften it, and do not add anything the line
does not support.

## What to extract

One row for each line that states something the person did, underwent, held or achieved: a job, a course or degree, a
school attended, an award, a promotion, a career change, a volunteering role, a membership, a campaign. Two distinct
claims on one line give two rows with the same span. Write no row for the name, contact, date-of-birth and heading
lines, or for a summary line that states no claim. A resume with no such line gives `rows: []`.

## The row

- `span`: `L<n>`, the number of the line the claim comes from.
- `relation`: how the person stands to the event. `causal`: they did it, produced it or earned it (work done, a
  degree completed, a course taught, an award, a campaign, a committee served on). `structural`: a standing
  position held (member of a choir, an association). `communicative`: they conveyed or published it. `impacted`:
  it happened to them or they received it (attended school, studying for a degree, treated, trained).
- `channel`: `positive` for a thing done or undergone. `prediction` only when the text itself states a level of
  skill or impact in a domain ("expert in welding"): then `magnitude` is the stated level (beginner 0.15,
  competent 0.4, skilled 0.65, very skilled 0.85, expert 0.95) and `types` carries form and content for
  expertise, or outcome alone for impact. Most resumes state none; write none. No negative rows.
- `magnitude`: the size of what the line claims, from 0 to 1.2: 0.1 brief or minor, 0.4 a year or two of ordinary
  work or one completed course, 0.7 several years in a role or a significant award, 1.0 and above rare. Scale with
  the stated duration and seniority. Take the size the text supports, never a larger one.
- `valid_time`: when the claim happened, as stated: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; for a span the start. `null`
  when the line gives no date.
- `types`: how the event belongs to domains, with exactly four keys. Each is an object {domain id: weight} over ids
  from the pack (sectors are allowed), weights positive and summing to 1, naming only the domains that matter, or
  `null` when that relation does not apply.
  - `form`: the kind of act or thing it is, apart from its subject and effects. Usually one domain.
  - `content`: what it is about or engages: its subject matter. One or two domains.
  - `outcome`: what observably changes or is produced: what a job produces, what a course leaves, what a
    campaign seeks to change. `null` when the line shows none.
  - `setting`: the sphere, institution or venue it takes place in. Usually one domain. `null` when the line gives
    none.
  At least one type must be non-null.

## Answering

The verdict is always the string `rows`. Alongside `verdict` and `reason`, write `rows`: a list of row objects in
the order of their lines, each with exactly the keys `span`, `relation`, `channel`, `magnitude`, `valid_time`,
`types`. The reason is one line naming what the resume let you extract (or why nothing).
