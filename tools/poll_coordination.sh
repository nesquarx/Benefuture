#!/usr/bin/env bash
set -e

cd "$(git rev-parse --show-toplevel)"

echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Polling origin..."
git fetch origin

LOCAL_MAIN=$(git rev-parse main)
REMOTE_MAIN=$(git rev-parse origin/main)

if [ "$LOCAL_MAIN" != "$REMOTE_MAIN" ]; then
    echo "Notice: origin/main has changed ($LOCAL_MAIN -> $REMOTE_MAIN)."
    AHEAD_BEHIND=$(git rev-list --left-right --count main...origin/main)
    echo "main...origin/main diff count: $AHEAD_BEHIND"
    if [ "$(git branch --show-current)" = "main" ]; then
        if git merge --ff-only origin/main; then
            echo "Successfully fast-forwarded local main to origin/main ($REMOTE_MAIN)."
        else
            echo "Warning: Fast-forward merge failed. Manual conflict check required."
        fi
    else
        echo "Currently on $(git branch --show-current), skipping automatic merge to main."
    fi
else
    echo "Local main is already up to date with origin/main ($REMOTE_MAIN)."
fi

echo ""
echo "=== Remote Branch Status ==="
for b in $(git branch -r | grep -v 'origin/HEAD' | grep -v 'origin/main'); do
    AHEAD_MAIN=$(git rev-list --count origin/main.."$b")
    LAST_COMMIT=$(git log -n 1 --format="%cd (%h) by %an: %s" --date=short "$b")
    if [ "$AHEAD_MAIN" -gt 0 ]; then
        echo "* [ACTIVE] $b ($AHEAD_MAIN commit(s) ahead of main): $LAST_COMMIT"
    else
        echo "  [MERGED] $b: $LAST_COMMIT"
    fi
done
