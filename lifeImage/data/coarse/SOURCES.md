# Coarse seed sources (draft v0)

Provenance of this file: drafted by a Sonnet subagent on 2026-11-20. Network access worked for a few pages but most
primary pages were not read in full. Code lists below are written from memory of the published top levels
(confidence about 0.8 for ICATUS, COICOP, ICF, ISCO, ISIC top levels; about 0.6 for OpenAlex field numbers) and
must be checked against the primary pages before the anchors are trusted. Licence statements are NOT verified
from a primary licence page unless the row says so; treat every "recalled" licence as unverified.

| Source | What it is | Top-level codes used | Licence / reuse (recalled) | Verified? |
|---|---|---|---|---|
| UN ICATUS 2016 | International Classification of Activities for Time-Use Statistics | divisions 01-09 (employment; own-use production; unpaid domestic; unpaid care; volunteer/trainee; learning; socialising, community, religion; culture, leisure, media, sport; self-care) | UN statistical classification; UN Terms of Use apply, classification text generally reusable with attribution | No. Page https://unstats.un.org/unsd/classifications/Econ/ reachable (HTTP 200) but its terms were not read |
| COICOP 2018 | Classification of Individual Consumption According to Purpose | divisions 01-13 | As ICATUS (UN Statistics Division) | No. Same host reachable, terms not read |
| WHO ICF | International Classification of Functioning, Disability and Health | activities and participation chapters d1-d9 | WHO copyright; WHO site terms say content is copyrighted with limited reuse; the ICF text may need WHO permission, possibly CC BY-NC-SA 3.0 IGO for some publications | Partly. https://www.who.int/about/policies/terms-of-use fetched and shows "All Rights Reserved" copyright notice; ICF-specific terms not found. Treat as restrictive; only chapter titles used as anchors (labels, not text) |
| OpenAlex | Open scholarly graph; domains, fields, subfields, topics | fields/11-36 (26 fields; numbering recalled, 24 and the other gaps omitted) | CC0 (recalled from OpenAlex docs) | No. docs.openalex.org redirected (301); api.openalex.org returned a rate-limit error (no key), so the field list could not be fetched |
| ESCO | European skills, competences, qualifications and occupations | not used in v0 (top skill groups S1-S8 and occupation groups are for the fine level) | European Commission reuse policy, recalled as CC BY 4.0 with attribution | No. Terms page URL tried returned 404 |
| ISCO-08 | ILO International Standard Classification of Occupations | major groups 0-9 | ILO copyright; reuse with attribution, commercial reuse may need permission | No. ilo.org page returned no readable licence text |
| ISIC Rev.4 | UN International Standard Industrial Classification | sections A-U | UN Statistics Division terms, as ICATUS | No. Page reachable, terms not read |

Anchors in `seed_v0.jsonl` use `source` in {icatus, coicop, icf, isco08, isic4, openalex} with `code` the top-level
code and `label` the official title as recalled. Anchors are correspondences only; no source text beyond titles is
copied. Because ICF and ISCO terms are the least permissive, a release must re-check them before publishing the
basemap (DESIGN.md: the basemap needs a licence compatible with its sources).

Not yet consulted: UNODC ICCS (for the later negative channel), ICD, O*NET, Wikidata.
