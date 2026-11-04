#!/usr/bin/env python3
"""
Merge shard CSV artifacts from a sharded battery workflow run into
canonical results files (CSV and Markdown) in sim/battery/results/.
"""
import sys
import os
import glob
import re
import math
import subprocess

def parse_cli_args():
    import argparse
    parser = argparse.ArgumentParser(description="Merge sharded battery results.")
    parser.add_argument("--battery", required=True, help="Battery name (e.g. convergence, long_horizon)")
    parser.add_argument("--results-dir", default="results", help="Directory containing shard CSVs")
    parser.add_argument("--out-dir", default="sim/battery/results", help="Destination results directory")
    parser.add_argument("--commit", default="", help="Commit hash to tag in markdown/csv")
    return parser.parse_args()

def get_current_commit():
    try:
        res = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except Exception:
        return "unknown"

def pool_stats(records):
    # records: list of dicts with n_seeds, mean, se, rel_hw_pct, z, settle_med, settle_max
    total_n = sum(r['n_seeds'] for r in records)
    if total_n == 0:
        return records[0]
    
    # Weighted mean
    weighted_mean = sum(r['n_seeds'] * r['mean'] for r in records) / total_n

    # Pooled variance
    # SS = sum [ (n_i - 1)*s_i^2 + n_i*(m_i - M)^2 ]
    # where s_i^2 = n_i * se_i^2
    total_ss = 0.0
    for r in records:
        n_i = r['n_seeds']
        s_i_sq = n_i * (r['se'] ** 2)
        total_ss += (n_i - 1) * s_i_sq + n_i * ((r['mean'] - weighted_mean) ** 2)

    if total_n > 1:
        pooled_var = total_ss / (total_n - 1)
        pooled_se = math.sqrt(max(0.0, pooled_var) / total_n)
    else:
        pooled_se = records[0]['se']

    if pooled_se > 1e-12:
        z = weighted_mean / pooled_se
    else:
        z = float('inf')

    if abs(weighted_mean) > 1e-12:
        rel_hw = 100.0 * (1.96 * pooled_se) / abs(weighted_mean)
    else:
        rel_hw = float('inf')

    # Median: weighted average of medians
    settle_meds = [r['settle_med'] for r in records if not math.isnan(r['settle_med'])]
    settle_med = (sum(r['n_seeds'] * r['settle_med'] for r in records if not math.isnan(r['settle_med'])) / total_n) if settle_meds else float('nan')
    settle_maxes = [r['settle_max'] for r in records if not math.isnan(r['settle_max'])]
    settle_max = max(settle_maxes) if settle_maxes else float('nan')

    return {
        'n_seeds': total_n,
        'mean': weighted_mean,
        'se': pooled_se,
        'rel_hw_pct': rel_hw,
        'z': z,
        'settle_med': settle_med,
        'settle_max': settle_max
    }

def merge_convergence(shard_files, out_csv, out_md, commit):
    from collections import OrderedDict
    groups = OrderedDict() # key -> list of shard record dicts

    for fpath in shard_files:
        with open(fpath, 'r') as f:
            lines = [l.strip() for l in f if l.strip()]
        if not lines:
            continue
        header = lines[0].split(',')
        for l in lines[1:]:
            parts = l.split(',')
            if len(parts) < 12:
                continue
            rung, axis = parts[0], parts[1]
            param, steps = int(parts[2]), int(parts[3])
            n_seeds = int(parts[4])
            metric = parts[5]
            mean_v, se_v = float(parts[6]), float(parts[7])
            rhw, z_val = float(parts[8]), float(parts[9])
            s_med, s_max = float(parts[10]), float(parts[11])
            key = (rung, axis, param, steps, metric)
            if key not in groups:
                groups[key] = []
            groups[key].append({
                'n_seeds': n_seeds, 'mean': mean_v, 'se': se_v,
                'rel_hw_pct': rhw, 'z': z_val,
                'settle_med': s_med, 'settle_max': s_max
            })

    # Write merged CSV
    merged_rows = []
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    with open(out_csv, 'w') as f:
        f.write("rung,axis,param,steps,n_seeds,metric,mean,se,rel_hw_pct,z,settle_med,settle_max\n")
        for (rung, axis, param, steps, metric), records in groups.items():
            pooled = pool_stats(records)
            f.write(f"{rung},{axis},{param},{steps},{pooled['n_seeds']},{metric},{pooled['mean']:.6f},{pooled['se']:.6f},{pooled['rel_hw_pct']:.3f},{pooled['z']:.3f},{pooled['settle_med']:.1f},{pooled['settle_max']:.1f}\n")
            merged_rows.append({
                'rung': rung, 'axis': axis, 'param': param, 'steps': steps,
                'n_seeds': pooled['n_seeds'], 'metric': metric,
                'mean': pooled['mean'], 'se': pooled['se'],
                'rel_hw_pct': pooled['rel_hw_pct'], 'z': pooled['z'],
                'settle_med': pooled['settle_med'], 'settle_max': pooled['settle_max']
            })

    # Write merged Markdown
    write_convergence_md(merged_rows, out_md, commit)

def write_convergence_md(rows, out_md, commit):
    # Lookup helper
    by_rapm = {}
    for r in rows:
        by_rapm[(r['rung'], r['axis'], r['param'], r['steps'], r['metric'])] = r

    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, 'w') as f:
        f.write("# Convergence & Population-Diversity Sizing Report\n\n")
        f.write(f"- **Commit**: `{commit}`\n")
        f.write(f"- **Sharded Execution**: Consolidated across parallel shards\n")
        f.write(f"- **Convergence Criteria**: Running-mean settling within `10%` (`3%` for M5 accuracy), between-seed relative 95% CI half-width `<= 10%`, and signal-to-noise `z = mean / se >= 3.0`.\n\n")

        # 1. M1
        f.write("## 1. M1 Metric Competition & Distributed Choice\n")
        f.write("| Horizon (`steps`, `n = 200`) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |\n")
        f.write("|---|---|---|---|---|\n")
        for st in [50, 100, 200, 300, 500, 1000]:
            u = by_rapm.get(("M1", "steps", 200, st, "floor_u_gain"))
            h = by_rapm.get(("M1", "steps", 200, st, "floor_h_gain"))
            if u and h:
                f.write(f"| `{st}` | {u['mean']:.2f} ± {u['se']:.2f} | {u['rel_hw_pct']:.1f}% | {u['z']:.1f} | {h['rel_hw_pct']:.1f}% |\n")
        f.write("\n")

        f.write("| Diverse Population (`n`, distributed G, `150` steps) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |\n")
        f.write("|---|---|---|---|---|\n")
        for npop in [20, 50, 100, 200, 500, 1000]:
            u = by_rapm.get(("M1_central", "population_n", npop, 150, "floor_u_gain"))
            if u:
                f.write(f"| `{npop}` | {u['mean']:.2f} ± {u['se']:.2f} | {u['rel_hw_pct']:.1f}% | {u['z']:.1f} | {u['settle_med']:.0f} / {u['settle_max']:.0f} |\n")
        f.write("\n")

        # 2. M3c
        f.write("## 2. M3c Calibrated Realistic Economy (Log-Normal Agent Skills)\n")
        f.write("| Total Steps (`50` init + active, `n = 80`, `8` agents) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |\n")
        f.write("|---|---|---|---|---|\n")
        for st in [100, 150, 250, 350, 400]:
            u = by_rapm.get(("M3c_calibrated", "steps", 80, st, "post_init_floor_u_gain"))
            h = by_rapm.get(("M3c_calibrated", "steps", 80, st, "post_init_floor_h_gain"))
            if u and h:
                f.write(f"| `{st}` (`{st-50}` active) | {u['mean']:.2f} ± {u['se']:.2f} | {u['rel_hw_pct']:.1f}% | {u['z']:.1f} | {h['rel_hw_pct']:.1f}% |\n")
        f.write("\n")

        f.write("| Diverse Population (`n` beings, `n_agents` log-normal, `150` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being | Gain / Plan |\n")
        f.write("|---|---|---|---|---|---|\n")
        m3c_pop_configs = [(20, 4, 10), (40, 6, 10), (80, 8, 10), (160, 12, 20), (240, 16, 30)]
        for nb, na, np in m3c_pop_configs:
            u = by_rapm.get(("M3c_calibrated", "diverse_pop_n_agents", nb, 150, "post_init_floor_u_gain"))
            if u:
                per_b = u['mean'] / nb
                per_p = u['mean'] / np
                f.write(f"| `n = {nb}`, `agents = {na}`, `plans = {np}` | {u['mean']:.2f} ± {u['se']:.2f} | {u['rel_hw_pct']:.1f}% | {u['z']:.1f} | {per_b:.3f} | {per_p:.2f} |\n")
        f.write("\n")

        # 3. M5
        f.write("## 3. M5 Governance with Diverse Voter Skills & Ability Caps\n")
        f.write("| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |\n")
        f.write("|---|---|---|---|---|\n")
        for ndec in [50, 100, 200, 300, 500, 800]:
            acc = by_rapm.get(("M5_governance", "decisions", 60, ndec, "decision_accuracy"))
            gain = by_rapm.get(("M5_governance", "decisions", 60, ndec, "paired_wisdom_gain_vs_equal"))
            if acc and gain:
                f.write(f"| `{ndec}` | {acc['mean']:.4f} ± {acc['se']:.4f} | {acc['rel_hw_pct']:.2f}% | {gain['mean']:+.4f} ± {gain['se']:.4f} | {gain['z']:+.2f} |\n")
        f.write("\n")

        f.write("| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |\n")
        f.write("|---|---|---|---|---|\n")
        for nv in [12, 24, 48, 80, 140, 240]:
            acc = by_rapm.get(("M5_governance", "diverse_voters", nv, 300, "late_accuracy"))
            gain = by_rapm.get(("M5_governance", "diverse_voters", nv, 300, "late_paired_wisdom_gain"))
            if acc and gain:
                f.write(f"| `{nv}` voters | {acc['mean']:.4f} ± {acc['se']:.4f} | {acc['rel_hw_pct']:.2f}% | {gain['mean']:+.4f} ± {gain['se']:.4f} | {gain['z']:+.2f} |\n")
        f.write("\n")

        # 4. M7
        f.write("## 4. M7 Population with Diverse Teachers, Learners & Novelty (Distributed G)\n")
        f.write("| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |\n")
        f.write("|---|---|---|---|---|\n")
        for st in [25, 50, 80, 120, 150]:
            fu = by_rapm.get(("M7_diverse_pop", "steps", 100, st, "floor_u_gain"))
            mu = by_rapm.get(("M7_diverse_pop", "steps", 100, st, "median_u_gain"))
            if fu and mu:
                f.write(f"| `{st}` | {fu['mean']:.2f} ± {fu['se']:.2f} | {fu['rel_hw_pct']:.1f}% | {fu['z']:.1f} | {mu['rel_hw_pct']:.1f}% |\n")
        f.write("\n")

        f.write("| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `80` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being |\n")
        f.write("|---|---|---|---|---|\n")
        for nb in [20, 40, 80, 150, 300, 500]:
            fu = by_rapm.get(("M7_diverse_pop", "diverse_beings_n", nb, 80, "floor_u_gain"))
            if fu:
                per_b = fu['mean'] / nb
                f.write(f"| `n = {nb}` | {fu['mean']:.2f} ± {fu['se']:.2f} | {fu['rel_hw_pct']:.1f}% | {fu['z']:.1f} | {per_b:.3f} |\n")
        f.write("\n")

def merge_generic(shard_files, out_csv, out_md, commit):
    # Simply concatenate rows, preserving header from first shard
    header = None
    all_data_lines = []
    seen = set()

    for fpath in shard_files:
        with open(fpath, 'r') as f:
            lines = [l.strip() for l in f if l.strip()]
        if not lines:
            continue
        if header is None:
            header = lines[0]
        for l in lines[1:]:
            if l not in seen:
                all_data_lines.append(l)
                seen.add(l)

    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    with open(out_csv, 'w') as f:
        if header:
            f.write(header + "\n")
        for l in all_data_lines:
            f.write(l + "\n")

    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, 'w') as f:
        f.write(f"# Battery Results: {os.path.basename(out_csv)}\n\n")
        f.write(f"- **Commit**: `{commit}`\n")
        f.write(f"- **Rows**: {len(all_data_lines)}\n")

def main():
    args = parse_cli_args()
    battery = args.battery.replace(".jl", "")
    commit = args.commit or get_current_commit()

    # Locate shard CSVs
    pattern = os.path.join(args.results_dir, f"{battery}.*.csv")
    shard_files = sorted(glob.glob(pattern), key=lambda x: int(re.search(r'\.(\d+)\.csv$', x).group(1)) if re.search(r'\.(\d+)\.csv$', x) else 0)

    if not shard_files:
        # Fallback: check if single unsharded file exists in results_dir or sim/battery/results
        direct = os.path.join(args.results_dir, f"{battery}.csv")
        if os.path.exists(direct):
            shard_files = [direct]
        else:
            print(f"Error: no shard files found matching {pattern} or {direct}", file=sys.stderr)
            sys.exit(1)

    print(f"Merging {len(shard_files)} shards for battery '{battery}':")
    for s in shard_files:
        print(f"  - {s}")

    out_csv = os.path.join(args.out_dir, f"{battery}.csv")
    out_md = os.path.join(args.out_dir, f"{battery}.md")

    if battery == "convergence":
        merge_convergence(shard_files, out_csv, out_md, commit)
    else:
        merge_generic(shard_files, out_csv, out_md, commit)

    with open(out_csv, 'r') as f:
        row_count = sum(1 for line in f if line.strip())
    print(f"Wrote merged CSV: {out_csv} ({row_count} lines including header)")
    print(f"Wrote merged Markdown: {out_md}")

if __name__ == "__main__":
    main()
