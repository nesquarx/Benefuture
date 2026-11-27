#!/usr/bin/env python3
"""Compare two trace_probe JSON files: first divergent world, quantity, index (step) and Lean call."""
import json, struct, sys

def f(h):
    try: return struct.unpack(">d", bytes.fromhex(h))[0]
    except Exception: return h

def main(a, b, check=False):
    A, B = json.load(open(a)), json.load(open(b))
    print("env A:", A["env"]); print("env B:", B["env"])
    bad = 0
    if len(A["lean_sweep"]) != len(B["lean_sweep"]):
        bad += abs(len(A["lean_sweep"]) - len(B["lean_sweep"]))
        print(f"lean_sweep lengths differ: {len(A['lean_sweep'])} vs {len(B['lean_sweep'])}")
    for call_i, (x, y) in enumerate(zip(A["lean_sweep"], B["lean_sweep"])):
        if x != y:
            bad += 1
            if bad <= 3:
                print(f"LEAN/JULIA CALL #{call_i} {x['call']} differs\n  in : {[f(v) for v in x['in']]}\n  outA: {[f(v) for v in x['out']]}\n  outB: {[f(v) for v in y['out']]}")
    print("lean_sweep calls differing:", bad, "of", len(A["lean_sweep"]))
    world_diffs = 0
    if set(A["worlds"]) != set(B["worlds"]):
        world_diffs += 1
        print("world sets differ:", sorted(set(A["worlds"]) ^ set(B["worlds"])))
    for w in sorted(A["worlds"]):
        if w not in B["worlds"]: continue
        wa, wb = A["worlds"][w], B["worlds"][w]
        diffs = [k for k in wa if k in wb and wa[k]["hash"] != wb[k]["hash"]]
        if not diffs: print(f"{w}: IDENTICAL ({len(wa)} quantities)"); continue
        world_diffs += len(diffs)
        best = None
        for k in diffs:
            va, vb = wa[k]["bits"], wb[k]["bits"]
            n = min(len(va), len(vb)); i = next((i for i in range(n) if va[i] != vb[i]), n)
            cols = wa.get(k + "#cols"); step = None
            if cols:
                nc = int(cols["bits"][0]); nr = len(va) // nc; step = i // nr   # column-major: column = step
            elif k.split(".")[-1] in ("bar_trace",): step = i
            key = step if step is not None else i
            if best is None or key < best[0]: best = (key, k, i, step, va[i] if i < len(va) else None, vb[i] if i < len(vb) else None)
        print(f"{w}: {len(diffs)} of {len(wa)} quantities differ; first by index/step: {best[1]} element {best[2]} step {best[3]}: {f(best[4])!r} vs {f(best[5])!r}")
        print("   all differing:", ", ".join(sorted(diffs)[:12]), "..." if len(diffs) > 12 else "")
    sys.exit(1 if (check and (bad > 0 or world_diffs > 0)) else 0)

if __name__ == "__main__":
    args = [x for x in sys.argv[1:] if x != "--check"]
    main(args[0], args[1], check="--check" in sys.argv[1:])
