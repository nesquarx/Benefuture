"""Responsibility by freedom (LI.40): a pure function of the contribution, the option set at the moment of producing
the outcome and the harm of the outcome produced.

The option set lists the alternatives open to the participant besides the course taken, each with its harm 0-3.
Freedom is how far the best open alternative undercut the harm done: with none less harmful than the outcome the
participant had no better way out and responsibility sits at the governed floor (a coerced handover, a self-defender
with no gentler defence); each step of harm the best alternative would have spared raises it, to 1 when a harmless
alternative existed. Contribution gates only: a participant who contributed nothing (a beneficiary who only receives)
carries 0; a small contribution does not scale responsibility down, since responsibility is a degree for culpability
and, unlike value routing, is not additive.

An outcome of harm 0 leaves nothing to excuse, so a contributor carries 1. A missing option set (None) is not an empty
one: [] records that no alternative existed (floor); None records nothing, and the governed default substitutes,
logged as a degradation record each time, never full freedom. If the default were dropped for 1.0 every unrecorded
coerced handover would read as free choice.
"""
import math

from .degradation import record_degradation
from .governed import governed
from .validate import ValidationError

MAX_HARM = 3
MECHANISM = "responsibility_from_freedom"


def validate_option_set(option_set):
    """The option set when it is a list of {alternative: non-blank text, harm: integer 0-3}, else ValidationError."""
    if not isinstance(option_set, list):
        raise ValidationError(f"option_set must be a list, not {option_set!r}")
    for o in option_set:
        if not isinstance(o, dict) or set(o) != {"alternative", "harm"}:
            raise ValidationError(f"an option needs exactly alternative and harm, not {o!r}")
        if not isinstance(o["alternative"], str) or not o["alternative"].strip():
            raise ValidationError(f"option alternative must be non-blank text, not {o['alternative']!r}")
        h = o["harm"]
        if isinstance(h, bool) or not isinstance(h, int) or not 0 <= h <= MAX_HARM:
            raise ValidationError(f"option harm must be an integer 0-{MAX_HARM}, not {h!r}")
    return option_set


def responsibility_from_freedom(contribution, option_set, outcome_harm, *, log=None, item=None):
    """Responsibility in [0, 1]. `option_set`: list of {alternative, harm} or None (missing: governed default,
    logged to `log` with `item` as the step). `outcome_harm`: integer 0-3, the harm of the outcome produced."""
    if isinstance(contribution, bool) or not isinstance(contribution, (int, float)) or not 0 <= contribution <= 1:
        raise ValidationError(f"contribution must be a number in [0, 1], not {contribution!r}")
    if isinstance(outcome_harm, bool) or not isinstance(outcome_harm, int) or not 0 <= outcome_harm <= MAX_HARM:
        raise ValidationError(f"outcome_harm must be an integer 0-{MAX_HARM}, not {outcome_harm!r}")
    if option_set is not None:
        validate_option_set(option_set)
    if contribution == 0:
        return 0.0
    if option_set is None:
        record_degradation(item, MECHANISM, f"governed default {governed('responsibility.no_option_set')}",
                           "option set missing from the record", log)
        return governed("responsibility.no_option_set")
    if outcome_harm == 0:
        return 1.0
    floor = governed("responsibility.floor")
    spared = outcome_harm - min((o["harm"] for o in option_set), default=outcome_harm)
    if spared <= 0:
        return floor
    return min(1.0, floor + (1 - floor) * spared / outcome_harm)
