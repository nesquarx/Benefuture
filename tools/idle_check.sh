#!/bin/bash
# Idle check for the working agent (author, 2026-11-08): reports what is running and the plan's next items, so a
# scheduled prompt can tell whether to continue. Exit 0 = nothing blocking (continue); 1 = work in flight (re-check later).
cd "$(dirname "$0")/.." || exit 2
busy=$(pgrep -af "julia .*(Pkg.test|replay|probe|tools/e5|sim/test)" | grep -v "sim/battery" | head)
batteries=$(pgrep -af "^julia .*sim/battery/" | sed 's/.*sim\/battery\///' | tr '\n' ' ')
echo "foreground jobs: ${busy:-none}"
echo "background batteries (never block): ${batteries:-none}"
echo "uncommitted changes: $(git status --short | wc -l)"
echo "plan queue:"; grep -E "^- \*\*(Queue|Prospective|Measurement domain|Understanding as its equation|Credence voting)" docs/PLAN.md | cut -c1-220
[ -z "$busy" ] && exit 0 || exit 1
