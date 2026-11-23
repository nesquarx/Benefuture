"""Governed values: every default or threshold a rule falls back on, in one place, each with its source.

A value here is a threshold to be governed later; rules read it by name through `governed`.
"""

GOVERNED = {
    "responsibility.no_option_set": {
        "default": 0.5,
        "source": "LI.40 / LI.42: option set missing; neither full freedom nor coercion is assumed (midpoint).",
    },
    "responsibility.floor": {
        "default": 0.1,
        "source": "LI.40: responsibility when no less harmful alternative was open; coercion lowers it, never to 0.",
    },
}


def governed(name):
    """The governed default of `name`; unknown names raise KeyError."""
    return GOVERNED[name]["default"]
