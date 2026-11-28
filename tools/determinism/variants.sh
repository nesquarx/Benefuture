#!/usr/bin/env bash
# Runs the determinism probes under environment variants and checks every hash equals the baseline.
#   tools/determinism/variants.sh [seeds=4]
# Variants: native; fresh compile cache (new first JULIA_DEPOT_PATH entry, so BenefutureSim and its
# dependencies are precompiled from scratch); -C generic / znver4 / icelake-server; JULIA_NUM_THREADS 1 and 4;
# OPENBLAS_NUM_THREADS 1 and 4. Julia only emulates the CPU target's code generation (the host must run it).
set -euo pipefail
cd "$(dirname "$0")/../.."
SEEDS="${1:-4}"
OUT="${TMPDIR:-/tmp}/determinism-variants"; mkdir -p "$OUT"
run() {  # label, env-assignments..., -- julia flags
  local label="$1"; shift
  local envs=(); while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  local a b
  a=$(env "${envs[@]}" julia "$@" --project=sim tools/determinism/trace_probe.jl "$OUT/$label.json" "$SEEDS" 2>/dev/null | grep '^probe_hash' | awk '{print $2 "/" $4}')
  b=$(env "${envs[@]}" julia "$@" --project=sim tools/determinism/gp_probe.jl 2>/dev/null | grep '^gp_hash' | awk '{print $2}')
  echo "$label trace=$a gp=$b"
}
BASE=$(run native X=1 --)
echo "$BASE"
rc=0
check() { local r; r=$(run "$@"); echo "$r"; [ "${r#* }" = "${BASE#* }" ] || { echo "  DIFFERS from native"; rc=1; }; }
check generic X=1 -- -C generic
check znver4 X=1 -- -C znver4
check icelake X=1 -- -C icelake-server
check threads4 JULIA_NUM_THREADS=4 --  -t 4
check blas1 OPENBLAS_NUM_THREADS=1 --
check blas4 OPENBLAS_NUM_THREADS=4 --
# fresh precompile: empty depot first; shared depots after it supply packages/artifacts (their compile caches are not reused
# because the first depot's compiled/ directory is searched first and the package image there does not yet exist).
FRESH=$(mktemp -d)
check freshcompile JULIA_DEPOT_PATH="$FRESH:$HOME/.julia" --
rm -rf "$FRESH"
exit $rc
