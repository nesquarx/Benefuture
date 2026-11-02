#!/usr/bin/env bash
# Launch or inspect the overnight long-horizon + failure-boundary battery suite.
# Enforces an allowed local-time operating window: 12:00 AM (00:00) to 9:00 PM (21:00) by default
# (override via BF_SIM_START_HOUR and BF_SIM_END_HOUR). Outside the window, any running Julia job is
# automatically suspended with SIGSTOP and resumed with SIGCONT when the window re-opens at 12:00 AM.
#
# Usage:
#   tools/battery/overnight.sh          # Launch in background if not running, or print status
#   tools/battery/overnight.sh status   # Print status and latest log lines
#   tools/battery/overnight.sh stop     # Stop the running suite and its window governor
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="$HOME/.local/bin:/Users/arko.sen/Desktop/BfTest/.elan/bin:$HOME/.elan/bin:$PATH"
CACHE="$ROOT/sim/battery/cache"
OUT="$ROOT/sim/battery/results"
mkdir -p "$CACHE" "$OUT"

PIDFILE="$CACHE/overnight.pid"
LOGFILE="$CACHE/overnight.log"
START_HOUR="${BF_SIM_START_HOUR:-0}"
END_HOUR="${BF_SIM_END_HOUR:-21}"

alive() {
    [ -f "$PIDFILE" ] || return 1
    local pid
    pid="$(cat "$PIDFILE")"
    kill -0 "$pid" 2>/dev/null || return 1
    if [ -d "/proc/$pid" ]; then
        tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q "overnight\|long_horizon\|battery"
    else
        ps -p "$pid" -o command= 2>/dev/null | grep -q "overnight\|long_horizon\|battery\|bash"
    fi
}

if [ "${1:-}" = "status" ]; then
    if alive; then
        echo "Overnight suite RUNNING (pid $(cat "$PIDFILE"), window ${START_HOUR}:00-${END_HOUR}:00 local)"
    else
        echo "Overnight suite NOT RUNNING"
    fi
    [ -f "$LOGFILE" ] && tail -n 25 "$LOGFILE"
    exit 0
fi

if [ "${1:-}" = "stop" ]; then
    if alive; then
        pid="$(cat "$PIDFILE")"
        pkill -TERM -P "$pid" 2>/dev/null || true
        kill -TERM "$pid" 2>/dev/null || true
        rm -f "$PIDFILE"
        echo "Stopped overnight suite (pid $pid)"
    else
        echo "Overnight suite is not running"
    fi
    exit 0
fi

if alive; then
    echo "Overnight suite already running (pid $(cat "$PIDFILE")); log: $LOGFILE"
    exit 0
fi

nohup bash -c '
    set -eu
    cd "'"$ROOT"'"
    START_HOUR="'"$START_HOUR"'"
    END_HOUR="'"$END_HOUR"'"
    export BF_SIM_START_HOUR="$START_HOUR"
    export BF_SIM_END_HOUR="$END_HOUR"

    in_window() {
        local h
        h=$((10#$(date +%H)))
        if [ "$START_HOUR" -le "$END_HOUR" ]; then
            [ "$h" -ge "$START_HOUR" ] && [ "$h" -lt "$END_HOUR" ]
        else
            [ "$h" -ge "$START_HOUR" ] || [ "$h" -lt "$END_HOUR" ]
        fi
    }

    run_with_window_guard() {
        while ! in_window; do
            echo "[Window Guard] Outside ${START_HOUR}:00-${END_HOUR}:00 local ($(date)); waiting for window..."
            sleep 60
        done
        "$@" &
        local jpid=$!
        local paused=0
        while kill -0 "$jpid" 2>/dev/null; do
            if in_window; then
                if [ "$paused" -eq 1 ]; then
                    echo "[Window Guard] Re-entered ${START_HOUR}:00-${END_HOUR}:00 local ($(date)); sending SIGCONT to pid $jpid"
                    kill -CONT "$jpid" 2>/dev/null || true
                    paused=0
                fi
            else
                if [ "$paused" -eq 0 ]; then
                    echo "[Window Guard] Reached end of ${START_HOUR}:00-${END_HOUR}:00 local window ($(date)); sending SIGSTOP to pid $jpid"
                    kill -STOP "$jpid" 2>/dev/null || true
                    paused=1
                fi
            fi
            sleep 30
        done
        wait "$jpid"
    }

    echo "=== Overnight Suite Started at $(date +"%Y-%m-%dT%H:%M:%S%z") (window ${START_HOUR}:00-${END_HOUR}:00 local) on commit $(git rev-parse --short HEAD) ==="
    echo "--- Phase 1: Long-Horizon & Century Composed Suite (sim/battery/long_horizon.jl) ---"
    run_with_window_guard julia -t auto --project=sim sim/battery/long_horizon.jl
    echo "--- Phase 2: Governance Failure-Boundary Battery (sim/battery/governance.jl) ---"
    run_with_window_guard julia -t auto --project=sim sim/battery/governance.jl
    echo "--- Phase 3: Attack Cross-Entropy Battery (sim/battery/attack.jl) ---"
    run_with_window_guard julia -t auto --project=sim sim/battery/attack.jl
    echo "--- Phase 4: Economy Failure-Boundary Battery (sim/battery/economy.jl) ---"
    run_with_window_guard julia -t auto --project=sim sim/battery/economy.jl
    echo "=== Overnight Suite Completed at $(date +"%Y-%m-%dT%H:%M:%S%z") ==="
' >"$LOGFILE" 2>&1 </dev/null &

echo $! >"$PIDFILE"
echo "Launched overnight suite (pid $(cat "$PIDFILE"), window ${START_HOUR}:00-${END_HOUR}:00 local); log: $LOGFILE"

