"""The speed work changes no output: rows, relational events, statistics and head verdicts on fixed seeds match the golden fingerprint taken before it
(`tests/_eventgen_fingerprint.py`; regenerate the golden only for an intended output change)."""
import json
import warnings
from pathlib import Path

from tests._eventgen_fingerprint import fingerprint


def test_outputs_match_the_golden_fingerprint():
    golden = json.loads((Path(__file__).parent / "data_eventgen_golden.json").read_text())
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        assert fingerprint() == golden


def test_the_table_is_validated_once_per_param_and_still_rejects_a_bad_one():
    import dataclasses

    import pytest

    from lifeimage.eventgen import calibration as cal
    table = cal.load_table()
    bad = dataclasses.replace(table.params[0], licence="not-a-licence")
    with pytest.raises(cal.CalibrationError):
        cal.Table([bad])
    with pytest.raises(cal.CalibrationError):
        cal.Table([table.params[0], table.params[0]])   # a duplicate key is still caught on the memoised path
