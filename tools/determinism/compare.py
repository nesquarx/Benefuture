#!/usr/bin/env python3
"""Compare two trace_probe JSON files: first divergent world, quantity, index (step) and Lean call."""
import json, struct, sys

def f(h):
    try: return struct.unpack(">d", bytes.fromhex(h))[0]
    except Exception: return h

def main(a, b):
    A, B = json.load(open(a)), json.load(open(b))
    print("env A:", A["env"]); print("env B:", B["env"])
    bad = 0
    for call_i, (x, y) in enumerate(zip(A["lean_sweep"], B["lean_sweep"])):
        if x != y:
            bad += 1
            if bad <= 3:
                print(f"LEAN/JULIA CALL #{call_i} {x['call']} differs\n  in : {[f(v) for v in x['in']]}\n  outA: {[f(v) for v in x['out']]}\n  outB: {[f(v) for v in y['out']]}")
    print("lean_sweep calls differing:", bad, "of", len(A["lean_sweep"]))
    for w in sorted(A["worlds"]):
        if w not in B["worlds"]: continue
        wa, wb = A["worlds"][w], B["worlds"][w]
        diffs = [k for k in wa if k in wb and wa[k]["hash"] != wb[k]["hash"]]
        if not diffs: print(f"{w}: IDENTICAL ({len(wa)} quantities)"); continue
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
    sys.exit(0)

if __name__ == "__main__": main(sys.argv[1], sys.argv[2])
