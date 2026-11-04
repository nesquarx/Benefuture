#!/usr/bin/env bash
# Durable per-track checkpoints so a track can pause and be resumed (or serialized) by any agent.
# Usage:
#   track_ckpt.sh save <track> <status> "<done>" "<next step>" ["<background task / CI run id>"]
#       status: RUNNING | PAUSED | BLOCKED | DONE
#   track_ckpt.sh show [track]      print checkpoint(s)
#   track_ckpt.sh pending           list tracks not DONE (what to resume)
# Checkpoints live outside git worktrees so all agents share them.
set -euo pipefail
DIR="${TRACKS_DIR:-/Users/arko.sen/Desktop/BfTest/.tracks}"; mkdir -p "$DIR"
case "${1:-}" in
  save)
    t="$2"; f="$DIR/$t.md"
    wt="$(git rev-parse --show-toplevel 2>/dev/null || echo -)"
    cat > "$f" <<EOT
track: $t
status: $2_PLACEHOLDER
EOT
    cat > "$f" <<EOT
track: $t
status: $3
updated: $(date -u +%FT%TZ)
worktree: $wt
branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo -)
head: $(git rev-parse --short HEAD 2>/dev/null || echo -)
dirty_files: $(git status -s 2>/dev/null | wc -l | tr -d ' ')
done: $4
next: $5
background: ${6:-none}
EOT
    echo "[ckpt] saved $f";;
  show) if [ -n "${2:-}" ]; then cat "$DIR/$2.md"; else for f in "$DIR"/*.md; do [ -e "$f" ] && { cat "$f"; echo ---; }; done; fi;;
  pending) grep -L '^status: DONE' "$DIR"/*.md 2>/dev/null | while read -r f; do sed -n '1,2p;8,9p' "$f"; echo ---; done;;
  *) sed -n '2,10p' "$0"; exit 1;;
esac
