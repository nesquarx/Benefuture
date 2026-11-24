# Per-probe wall time (author: "make sure probes are fast"): every top-level probe prints its name and
# seconds, so CI logs show where the time goes. Shared by probe_tests.jl (fast tier) and
# probe_heavy_tests.jl (full tier).
const PROBE_TIMES = Tuple{String,Float64}[]
macro timed_testset(name, body)
    ts = Expr(:macrocall, Symbol("@testset"), __source__, name, body)
    esc(quote
        local __pt0 = time()
        local __pr = $ts
        local __pdt = time() - __pt0
        push!(PROBE_TIMES, ($name, __pdt))
        println("PROBE-TIME ", round(__pdt; digits = 1), " s  ", $name); flush(stdout)
        __pr
    end)
end
probe_total(label) = println("PROBE-TIME total ", label, " ", round(sum(last, PROBE_TIMES; init = 0.0); digits = 1), " s over ", length(PROBE_TIMES), " probes")
