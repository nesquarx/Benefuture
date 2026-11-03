#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."
STATE_DIR="sim/battery/state"
mkdir -p "$STATE_DIR"

LAST_MAIN=$(git rev-parse origin/main 2>/dev/null || git rev-parse HEAD)
LAST_COORD=$(git rev-parse origin/main:COORDINATION.md 2>/dev/null || git hash-object COORDINATION.md)
LAST_PHASE=$(grep -E "^--- Phase|^=== Overnight Suite Completed" sim/battery/cache/overnight.log 2>/dev/null | tail -n 1 || true)

while true; do
    git fetch origin main --quiet 2>/dev/null || true
    CUR_MAIN=$(git rev-parse origin/main 2>/dev/null || echo "$LAST_MAIN")
    CUR_COORD=$(git rev-parse origin/main:COORDINATION.md 2>/dev/null || echo "$LAST_COORD")
    CUR_PHASE=$(grep -E "^--- Phase|^=== Overnight Suite Completed" sim/battery/cache/overnight.log 2>/dev/null | tail -n 1 || true)

    if [ "$CUR_MAIN" != "$LAST_MAIN" ] || [ "$CUR_COORD" != "$LAST_COORD" ]; then
        echo "CHANGE DETECTED: origin/main ($LAST_MAIN -> $CUR_MAIN) or COORDINATION.md ($LAST_COORD -> $CUR_COORD)"
        echo "{}" | tools/battery/hook.sh prompt || true
        exit 0
    fi

    if [ "$CUR_PHASE" != "$LAST_PHASE" ] && [ -n "$CUR_PHASE" ]; then
        echo "OVERNIGHT PHASE CHANGE: $LAST_PHASE -> $CUR_PHASE"
        tools/battery/overnight.sh status | tail -n 15
        exit 0
    fi

    sleep 600
done
