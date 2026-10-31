# Toy model M2: M1 with agents who propose the plans and are paid through escrow.
#
# World (this file): a set of agents proposes each step's plans. An agent's skill is the mean
# effect of its plans on the beings they touch; its sloppiness is execution noise that no model
# predicts. G chooses on the adopted model's predictions (as in M1). The proposer of the chosen
# plan is paid its predicted value split by the model's confidence (escrow), then settled against
# the markers' measurement of what actually happened. Reputation is the agent's measured
# contribution, decaying each step. A model's confidence is its accuracy (Lean accuracy_ref, 1 / (1 + RMSE)), so a
# perfect model pays in full upfront. Rules (Lean): everything in M1, plus escrow split,
# settlement and reputation decay.

"An agent: the mean effect of its plans, and the noise with which it carries them out."
struct Agent
    skill::Float64
    sloppiness::Float64
    function Agent(skill::Real, sloppiness::Real)
        check(isfinite(skill) && isfinite(sloppiness) && sloppiness >= 0, "skill finite, sloppiness non-negative")
        new(skill, sloppiness)
    end
end
Agent(skill::Real) = Agent(skill, SLOPPINESS)  # the calibrated intention-behaviour gap

"M2 parameters: the M1 world, the agents, and the rate at which reputation decays."
struct M2Params
    world::M1Params
    agents::Vector{Agent}
    rep_rate::Float64
    function M2Params(world::M1Params, agents, rep_rate::Real)
        check(!isempty(agents), "there must be at least one agent")
        check(isfinite(rep_rate) && rep_rate >= 0, "reputation decay rate must be non-negative")
        new(world, collect(Agent, agents), rep_rate)
    end
end

"A plan whose effect on each touched being has mean `μ`."
function plan_with_mean(rng::AbstractRNG, μ::Real, t::ToyParams)
    share = t.touch[1] + rand(rng) * (t.touch[2] - t.touch[1])
    mask = rand(rng, t.n) .< share
    ToyPlan(mask .* (μ .+ t.spread .* randn(rng, t.n)), mask .* (μ .+ t.spread .* randn(rng, t.n)))
end

agent_plan(rng::AbstractRNG, a::Agent, t::ToyParams) = plan_with_mean(rng, a.skill, t)

"A plan as carried out: its intended changes plus execution noise of size `sloppiness`."
carried_out(rng::AbstractRNG, sloppiness::Real, plan::ToyPlan) =
    (m = touched(plan); ToyPlan(plan.du .+ m .* sloppiness .* randn(rng, length(m)),
                                plan.dh .+ m .* sloppiness .* randn(rng, length(m))))
carried_out(rng::AbstractRNG, a::Agent, plan::ToyPlan) = carried_out(rng, a.sloppiness, plan)

observed_plan(rng::AbstractRNG, plan::ToyPlan, σ) =
    (m = touched(plan); ToyPlan(m .* observe(rng, plan.du, σ), m .* observe(rng, plan.dh, σ)))

"""
    run_m2(p; seed) -> NamedTuple

Run M2. Per-step series cover every step (zero when G does not act); payment series cover the
steps a plan was chosen; `reputation` and `balance` are final, one per agent.
"""
function run_m2(p::M2Params; seed)
    w, t = p.world, p.world.toy
    rng, mrng = Xoshiro(seed), Xoshiro(hash((seed, :measurement)))
    s = toy_state(t, rng)
    k, na = length(w.models), length(p.agents)
    history = [Float64[] for _ in 1:k]
    rolling() = [isempty(h) ? 0.0 : mean(@view h[max(1, end - w.window + 1):end]) for h in history]
    adopted = mm_adopt(rolling())
    reputation, balance = zeros(na), zeros(na)
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[], adopted = Int[],
          upfronts = Float64[], settlements = Float64[], measured_values = Float64[],
          predicted_floor_u_change = Float64[], realised_floor_u_change = Float64[],
          reputation = reputation, balance = balance)
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
    for _ in 1:t.steps
        proposers = rand(rng, 1:na, t.plans)
        plans = [agent_plan(rng, p.agents[a], t) for a in proposers]
        preds = [[predict(mrng, m, plan) for plan in plans] for m in w.models]
        i = choose(obs, preds[adopted], t)
        reputation .= reputation_decay.(reputation, 1.0; rate = p.rep_rate)
        floor_before = floor_quantile(s.u, t.q)
        if i == 1
            push!(tr.chosen_agent, 0)
            push!(tr.predicted_floor_u_change, 0.0); push!(tr.realised_floor_u_change, 0.0)
        else
            a, plan, pred = proposers[i - 1], plans[i - 1], preds[adopted][i - 1]
            push!(tr.chosen_agent, a)
            push!(tr.predicted_floor_u_change, floor_quantile(obs.u .+ pred.du, t.q) - floor_quantile(obs.u, t.q))
            scores = rolling()
            confidence = accuracy(scores[adopted])
            upfront, _ = escrow_split(plan_value(pred, t), confidence)
            done = carried_out(rng, p.agents[a], plan)
            seen = observed_plan(mrng, done, w.marker_σ)
            measured = plan_value(seen, t)
            settled = settlement(measured, upfront)
            push!(tr.upfronts, upfront); push!(tr.settlements, settled); push!(tr.measured_values, measured)
            balance[a] += upfront + settled
            reputation[a] += measured
            mask = touched(plan)
            realised = [seen.du[mask]; seen.dh[mask]]
            for j in 1:k
                pj = preds[j][i - 1]
                push!(history[j], mm_score([pj.du[mask]; pj.dh[mask]], realised))
            end
            s.u .+= done.du
            s.h .+= done.dh
            push!(tr.realised_floor_u_change, floor_quantile(s.u, t.q) - floor_before)
        end
        adopted = mm_adopt(rolling())
        push!(tr.adopted, adopted)
        obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
        record!()
    end
    tr
end
