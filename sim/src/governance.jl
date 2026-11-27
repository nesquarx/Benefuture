# Governance rules (L113 BfDm, L114 LqdBfDm), computed by the Lean reference (`Voting_weight_ref`,
# `accumulate_capped_ref`; `Governance.Democracy`, `Governance.Incentives`).

"""
    voting_weight(base, expertise_weight, shares, reps, impact_weight, impact; optional_below) -> (weight, optional)

A vote's weight (L113): base + expertise weight × Σ share × reputation over the decision's domain
profile + impact weight × impact; voting is optional below the threshold.
"""
function voting_weight(base::Real, expertise_weight::Real, shares, reps, impact_weight::Real, impact::Real;
                       optional_below::Real, need_optional::Bool = true)
    check(profile_valid(shares) && length(reps) == length(shares) && all(isfinite, reps), "a decision profile and one reputation per domain")
    check(all(x -> isfinite(x) && x >= 0, (base, expertise_weight, impact_weight, impact, optional_below)), "weights non-negative")
    w = @lccall(sym(:bf_voting_weight), Float64, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64),
              base, expertise_weight, floatarray(shares), floatarray(reps), impact_weight, impact, optional_below)
    opt = need_optional && @lccall(sym(:bf_vote_optional), UInt8, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64),
                                 base, expertise_weight, floatarray(shares), floatarray(reps), impact_weight, impact, optional_below) == 1
    w, opt
end

"""
    voting_weight_sy(base, expertise_weight, shares, reps, impact_weight, impact; voluntary = 0, discount, optional_below,
                     κ = 1.0, q = 1.1) -> (weight, optional)

The synergised vote weight (L113; author rulings 8.158, 8.160; Lean `Voting_weight_sy_ref`): base + Sy([expertise, impact])
by the L13 synergy function (κ = 1, q₊ = 1.1 as governed there), the part of `impact` that is `voluntary` post hoc
exposure discounted by `discount`; impact discovered later, not chosen, counts in full.
"""
function voting_weight_sy(base::Real, expertise_weight::Real, shares, reps, impact_weight::Real, impact::Real;
                          voluntary::Real = 0.0, discount::Real, optional_below::Real, κ::Real = 1.0, q::Real = 1.1,
                          need_optional::Bool = true)
    check(profile_valid(shares) && length(reps) == length(shares) && all(isfinite, reps), "a decision profile and one reputation per domain")
    check(all(x -> isfinite(x) && x >= 0, (base, expertise_weight, impact_weight, impact, voluntary, optional_below, κ)) && q > 0 && isfinite(q) &&
          0 <= discount <= 1 && voluntary <= impact, "weights non-negative, voluntary exposure within the impact, discount in [0, 1]")
    s, r = floatarray(shares), floatarray(reps)
    w = @lccall(sym(:bf_voting_weight_sy), Float64, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64, Float64, Float64, Float64),
              base, expertise_weight, s, r, impact_weight, impact, voluntary, discount, optional_below, κ, q)
    opt = need_optional && @lccall(sym(:bf_vote_optional_sy), UInt8, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64, Float64, Float64, Float64),
                                 base, expertise_weight, floatarray(shares), floatarray(reps), impact_weight, impact, voluntary, discount, optional_below, κ, q) == 1
    w, opt
end

"The impact a vote's weight counts (Lean `Counted_impact_ref`; 8.160): the voluntary post hoc part discounted, the rest in full."
function counted_impact(impact::Real, voluntary::Real, discount::Real)
    check(all(x -> isfinite(x) && x >= 0, (impact, voluntary)) && voluntary <= impact && 0 <= discount <= 1, "voluntary within impact, discount in [0, 1]")
    @lccall(sym(:bf_counted_impact), Float64, (Float64, Float64, Float64), impact, voluntary, discount)
end

"Capped delegation (L114): a delegate accepts each further weight only while its total is under the cap."
function accumulate_capped(cap::Real, current::Real, weights)
    check(all(isfinite, (cap, current)) && all(w -> isfinite(w) && w >= 0, weights), "finite cap and non-negative weights")
    @lccall(sym(:bf_accumulate_capped), Float64, (Float64, Float64, Ptr{Cvoid}), cap, current, floatarray(weights))
end

"Domain-relative expertise ([R] 8.22.1; L113): reputations as shares of the domain's total (summing to 1), for vote weights only (8.48)."
function relative_reputation(reps)
    check(all(r -> isfinite(r) && r >= 0, reps), "reputations must be non-negative")
    lean_floats(@lccall(sym(:bf_relative_reputation), Ptr{Cvoid}, (Ptr{Cvoid},), floatarray(reps)))
end

"The reputation a vote earns once its outcome is apparent (Lean `vote_reputation_ref`; 8.29, 8.48)."
function vote_reputation(right::Bool, value::Real, scale::Real, voters::Integer, held::Real, total::Real)
    check(all(isfinite, (value, scale, held, total)) && total > 0 && voters >= 1 && held >= 0, "finite inputs, positive total and voters")
    @lccall(sym(:bf_vote_reputation), Float64, (UInt8, Float64, Float64, Float64, Float64, Float64), right, value, scale, voters, held, total)
end

"Whether a delegate is audited out (Lean `audited_out_ref`; L114)."
function audited_out(rights::Integer, records::Integer; min_records::Integer, threshold::Real)
    check(0 <= rights <= records && min_records >= 1 && 0 <= threshold <= 1, "rights within records, positive minimum, threshold in [0, 1]")
    @lccall(sym(:bf_audited_out), UInt8, (Float64, Float64, Float64, Float64), rights, records, min_records, threshold) == 1
end

"A source's weight in deliberation from its record's rolling net (Lean `source_weight_ref`; 8.43)."
function source_weight(rights::Real, wrongs::Real)
    check(isfinite(rights) && isfinite(wrongs) && rights >= 0 && wrongs >= 0, "rights and wrongs non-negative")
    @lccall(sym(:bf_source_weight), Float64, (Float64, Float64), rights, wrongs)
end

"A source's weight as heard by a listener (Lean `heard_ref`; 8.44): down and across, up only for novel input."
heard(source::Real, own::Real, novel::Bool) = @lccall(sym(:bf_heard), Float64, (Float64, Float64, UInt8), source, own, novel)

"Heard weights over many sources at once (Lean `heard_weights_ref`; 8.44): full at or above one's own, the novelty chance below."
function heard_weights(sources, own::Real, p_novel::Real)
    check(all(isfinite, sources) && isfinite(own) && 0 <= p_novel <= 1, "finite weights, novelty chance in [0, 1]")
    isempty(sources) && return Float64[]
    lean_floats(@lccall(sym(:bf_heard_weights), Ptr{Cvoid}, (Ptr{Cvoid}, Float64, Float64), floatarray(sources), own, p_novel))
end

"The ledgers' negative share (Lean `neg_share_ref`; 8.42.1)."
function neg_share(gains::Real, losses::Real)
    check(isfinite(gains) && isfinite(losses) && gains >= 0 && losses >= 0, "gains and losses non-negative")
    @lccall(sym(:bf_neg_share), Float64, (Float64, Float64), gains, losses)
end

"One record's credence score, unclipped (Lean `credence_score_ref`; 8.36)."
function credence_score(credence::Real, outcome::Real)
    check(0 <= credence <= 1 && 0 <= outcome <= 1, "credence and outcome in [0, 1]")
    @lccall(sym(:bf_credence_score), Float64, (Float64, Float64), credence, outcome)
end

# Source tags (L134 IH; author ruling on 8.45): `BenefutureReference.Sources`.
side_ok(x) = x == -1 || x == 0 || x == 1
function check_tags(ids, ws)
    check(length(ids) == length(ws), "one weight per tag")
    check(all(isfinite, ids) && all(w -> isfinite(w) && w >= 0, ws), "finite origin ids and non-negative weights")
end

"Count once by origin (Lean `count_once_ref`; 8.45): each weight at its origin's first occurrence, zero at repeats."
function count_once(ids, ws)
    check_tags(ids, ws)
    lean_floats(@lccall(sym(:bf_count_once), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(ids), floatarray(ws)))
end

"""
    tagged_reading(self, own, own_side, ids, sides, ws) -> Float64

A reading with source tags (Lean `tagged_reading_ref`; 8.45): own weight × own side plus each distinct
origin's weight × its side; repeats and echoes of `self` add nothing.
"""
function tagged_reading(self::Real, own::Real, own_side::Real, ids, sides, ws)
    check_tags(ids, ws)
    check(length(sides) == length(ids) && side_ok(own_side) && all(side_ok, sides), "sides are -1, 0 or 1, one per tag")
    check(isfinite(self) && isfinite(own) && own >= 0, "finite self id, non-negative own weight")
    @lccall(sym(:bf_tagged_reading), Float64, (Float64, Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          self, own, own_side, floatarray(ids), floatarray(sides), floatarray(ws))
end

"Tags whose claimed side differs from the origin's logged output (Lean `tags_falsified_ref`; L160)."
function tags_falsified(claimed, logged)
    check(length(claimed) == length(logged) && all(side_ok, claimed) && all(side_ok, logged), "one logged side per claimed side, each -1, 0 or 1")
    Int(@lccall(sym(:bf_tags_falsified), Csize_t, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(claimed), floatarray(logged)))
end

"Whether outputs presented as one's own echo what was heard (Lean `undisclosed_echo_ref`; L160, 8.45)."
function undisclosed_echo(agree::Real, n::Real, a_self::Real, a_src::Real; margin::Real, z::Real)
    check(0 <= agree <= n && isfinite(n), "agreements within outputs")
    check(0 <= a_self <= 1 && 0 <= a_src <= 1 && 0 <= margin < 1 && isfinite(z), "accuracies in [0, 1], margin in [0, 1), finite z")
    @lccall(sym(:bf_undisclosed_echo), UInt8, (Float64, Float64, Float64, Float64, Float64, Float64), agree, n, a_self, a_src, margin, z) == 1
end

"""
    contention_map(reputations; self = 0) -> Vector{Int}

ContentionMap (`L134` IH: SourceVerify by Re(Dn), 8.45; Lean `contention_map_ref`): returns
1-based source indices ordered descending by domain reputation (breaking ties by smaller index),
optionally omitting `self` (`self = 0` keeps all sources).
"""
function contention_map(reputations; self::Integer = 0)
    check(all(isfinite, reputations) && 0 <= self <= length(reputations),
          "finite reputations and valid 1-based self index (or 0)")
    isempty(reputations) && return Int[]
    Int.(lean_floats(@lccall(sym(:bf_contention_map), Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t),
                           floatarray(reputations), self)))
end
