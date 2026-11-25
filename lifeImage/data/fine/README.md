# Fine level: candidate pool

Candidate fine domains (disciplines, occupation and skill groups, kinds of life activity) for the parent task
`fine_parent` v1. Built by `tools/fine_fetch.py` (public classifications, network) and `tools/fine_pool.py` (offline).

- `sources/<source>.jsonl`: classes of a public classification, trimmed (code, label, aliases, description, broader).
  `sources/network.json` records per source whether the fetch succeeded or was blocked.
- `candidates_v0.jsonl`: the deduplicated pool. Each candidate carries its sources (code, label, licence status),
  aliases, kinds and the label its source files it under (`broader_in_source`, a hint for the task).
- `pool_report.json`: every raw item accounted for (raw = pool + merged + dropped), licence status per source, network
  status, the Wikidata accounting (161 unmapped rows: class candidates and logged instance drops).

Sources and licence status (`verified` = statement read on a primary page; `unverified` = believed, not stated on the
pages read; `restricted` = a reservation of rights was read):

| source | classes used | licence | status |
|---|---|---|---|
| OpenAlex subfields | 252 | CC0 1.0 (believed) | unverified |
| ESCO / ISCO-08 minor groups | 130 | ESCO reuse with attribution, believed CC BY 4.0 | unverified |
| ESCO skill groups (depth 2) | 75 | as above | unverified |
| ICATUS 2016 divisions and groups | 221 | United Nations copyright, all rights reserved | restricted (reference use only) |
| Wikidata, unmapped labels in `data/public/` | 48 class candidates from 161 rows | CC0 1.0 | verified |
| cached answers (a domain stated missing) | 1 | project data | verified |

Normalisation is mechanical (`lifeimage/fine/normalise.py`): residual categories ("Other ...", "not elsewhere
classified") are dropped, a candidate that only restates a coarse domain is dropped, the rest merge by normalised label.
Each drop is listed in the report with its reason.

Next: run the batches (`python3 lifeImage/tools/fine_build_batches.py`, then the runner agent type on
`data/batches/fine_parent.v1.var{0,1,2}.part{n}.jsonl`), then `python3 lifeImage/tools/fine_apply.py` writes
`fine_v0.jsonl` (cards, level `fine`, status `score_only`) and `fine_v0_summary.json`.
