#!/usr/bin/env bash
set -euo pipefail

# tools/wait_check.sh
# Automated watcher for GitHub Actions CI and remote coordination changes.
# Runs silently in the background, waking the agent reactively without burning tokens.

MODE="${1:-ci_and_remote}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Fetch GitHub Token from git credentials helper
get_token() {
    git credential fill <<< "protocol=https
host=github.com" 2>/dev/null | grep password | cut -d= -f2 || true
}

TOKEN=$(get_token)
AUTH_HEADER=()
if [ -n "$TOKEN" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer $TOKEN")
fi

check_ci() {
    local run_id="$1"
    local res
    res=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/nesquarx/Benefuture/actions/runs/$run_id" 2>/dev/null || true)
    local status
    local conclusion
    status=$(echo "$res" | jq -r '.status // empty')
    conclusion=$(echo "$res" | jq -r '.conclusion // empty')
    echo "$status:$conclusion"
}

get_failed_job_log() {
    local run_id="$1"
    local jobs_json
    jobs_json=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/nesquarx/Benefuture/actions/runs/$run_id/jobs" 2>/dev/null || true)
    local failed_job_id
    failed_job_id=$(echo "$jobs_json" | jq -r '.jobs[] | select(.conclusion=="failure") | .id' | head -n 1)
    if [ -n "$failed_job_id" ]; then
        echo "=== Failed Job ID: $failed_job_id ==="
        curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/nesquarx/Benefuture/actions/jobs/$failed_job_id/logs" 2>/dev/null | grep -A 35 -B 5 "Test Failed" | tail -n 50 || true
    fi
}

check_remote() {
    git fetch origin main --quiet 2>/dev/null || true
    local local_head
    local remote_head
    local_head=$(git rev-parse HEAD)
    remote_head=$(git rev-parse origin/main)
    if [ "$local_head" != "$remote_head" ]; then
        echo "REMOTE_CHANGED"
    else
        echo "SYNCED"
    fi
}

case "$MODE" in
    ci)
        RUN_ID="${2:-}"
        if [ -z "$RUN_ID" ]; then
            echo "Usage: $0 ci <run_id>"
            exit 1
        fi
        echo "[wait_check] Watching CI run $RUN_ID..."
        while true; do
            res=$(check_ci "$RUN_ID")
            status="${res%%:*}"
            conclusion="${res##*:}"
            if [ "$status" = "completed" ]; then
                echo "[wait_check] CI run $RUN_ID completed with conclusion: $conclusion"
                if [ "$conclusion" = "success" ]; then
                    exit 0
                else
                    get_failed_job_log "$RUN_ID"
                    exit 1
                fi
            fi
            sleep 25
        done
        ;;

    remote)
        TIMEOUT="${2:-600}"
        INTERVAL=25
        ELAPSED=0
        echo "[wait_check] Watching origin/main for up to ${TIMEOUT}s..."
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            state=$(check_remote)
            if [ "$state" = "REMOTE_CHANGED" ]; then
                echo "[wait_check] Remote change detected on origin/main!"
                git log HEAD..origin/main --oneline
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$((ELAPSED + INTERVAL))
        done
        echo "[wait_check] Timeout (${TIMEOUT}s) reached without remote change."
        exit 0
        ;;

    ci_and_remote)
        RUN_ID="${2:-}"
        TIMEOUT="${3:-600}"
        if [ -z "$RUN_ID" ]; then
            # auto-detect latest run on current HEAD
            HEAD_SHA=$(git rev-parse HEAD)
            RUN_ID=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/nesquarx/Benefuture/actions/runs?head_sha=$HEAD_SHA&per_page=1" | jq -r '.workflow_runs[0].id // empty')
            if [ -z "$RUN_ID" ]; then
                echo "[wait_check] No CI run found for HEAD ($HEAD_SHA). Exiting."
                exit 0
            fi
        fi
        echo "[wait_check] Watching CI run $RUN_ID and origin/main (max ${TIMEOUT}s)..."
        INTERVAL=25
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            # 1. Check remote
            state=$(check_remote)
            if [ "$state" = "REMOTE_CHANGED" ]; then
                echo "[wait_check] Remote change detected on origin/main!"
                git log HEAD..origin/main --oneline
                exit 0
            fi

            # 2. Check CI
            res=$(check_ci "$RUN_ID")
            status="${res%%:*}"
            conclusion="${res##*:}"
            if [ "$status" = "completed" ]; then
                echo "[wait_check] CI run $RUN_ID completed with conclusion: $conclusion"
                if [ "$conclusion" = "success" ]; then
                    exit 0
                else
                    get_failed_job_log "$RUN_ID"
                    exit 1
                fi
            fi

            sleep "$INTERVAL"
            ELAPSED=$((ELAPSED + INTERVAL))
        done
        echo "[wait_check] Timeout (${TIMEOUT}s) reached."
        exit 0
        ;;

    *)
        echo "Unknown mode: $MODE"
        echo "Usage: $0 [ci <run_id> | remote <timeout_sec> | ci_and_remote <run_id> <timeout_sec>]"
        exit 1
        ;;
esac
