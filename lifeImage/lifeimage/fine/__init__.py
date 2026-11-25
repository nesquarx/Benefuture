"""The fine level: disciplines, occupation and skill groups, kinds of life activity, placed under the coarse domains.

Pipeline (no step runs a model except the `fine_parent` task, whose batches `parent.py` writes and whose answers
`tools/fine_apply.py` merges): public classifications and unmapped records -> `sources.py` -> `pool.py` (candidates,
deduplicated by `normalise.py`) -> `parent.py` (batches, votes) -> `compare.py` (data check) -> `placement.py` (arcs).
"""
