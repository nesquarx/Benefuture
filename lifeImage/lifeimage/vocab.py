"""Closed vocabularies of the contract, kept in one place so a deployment can configure them.

Validators and the projection take their vocabulary as an argument and default to these constants.
"""

UPSTREAM = "upstream"  # a major upstream domain: receives a little colour bleed and may place an axes-less domain
OVERLAP = "overlap"  # a neighbour: receives no colour and places nothing
LINK_RELS = frozenset({UPSTREAM, OVERLAP})  # domain-to-domain relations

# [P] the entity's relation to the event
EVENT_RELATIONS = frozenset({"causal", "structural", "communicative", "impacted"})

# [P] the relation through which an event belongs to a domain (Benefuture L22 RelType): the kind of act, what the
# event is about, what it is for. Weights sum to 1 within each.
MEMBERSHIP_RELS = frozenset({"act", "content", "purpose"})
