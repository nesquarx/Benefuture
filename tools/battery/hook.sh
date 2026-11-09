#!/bin/bash
# Session hooks for the background batteries (.claude/settings.json).
#   session: report each battery; relaunch any that a container restart killed (no exit code,
#            no process), which resumes from its evaluation cache.
#   prompt:  report each battery in one line (context for the turn).
#   stop:    once per finished run, block the stop so its results get recorded (CLAUDE.md, Working).
cat > /dev/null  # the hook's JSON input is not needed
cd "$(dirname "$0")/../.." || exit 0
# A battery is alive when its recorded pid is a julia process running its file (a shell wrapper
# whose command line mentions the file does not count).
alive() {
  [[ -z $1 ]] && return 1
  if [[ -d /proc ]]; then
    [[ $(cat /proc/$1/comm 2>/dev/null) == julia ]] && grep -qa "sim/battery/$2.jl" /proc/$1/cmdline
  else
    ps -p "$1" -o command= 2>/dev/null | grep -q "sim/battery/$2\.jl"
  fi
}
state=sim/battery/state
mkdir -p "$state"
mode=$1; lines=(); finished=()

# Check whether COORDINATION.md on origin/main has changed.
git fetch origin main --quiet 2>/dev/null || true
remote_coord_sha=$(git rev-parse origin/main:COORDINATION.md 2>/dev/null || echo "")
local_coord_sha=$(git rev-parse HEAD:COORDINATION.md 2>/dev/null || echo "")
seen_file="$state/coordination.seen"
acked_file="$state/coordination.acked"
[[ -f $seen_file ]] || echo "${remote_coord_sha:-$local_coord_sha}" > "$seen_file"
[[ -f $acked_file ]] || echo "${remote_coord_sha:-$local_coord_sha}" > "$acked_file"
if [[ -n $remote_coord_sha && $remote_coord_sha != "$(cat "$seen_file" 2>/dev/null)" ]]; then
  echo "$remote_coord_sha" > "$seen_file"
  lines+=("ALERT: COORDINATION.md changed on origin/main ($(git rev-parse --short origin/main 2>/dev/null)); sync and review §2a")
elif [[ -n $remote_coord_sha && $remote_coord_sha != "$local_coord_sha" ]]; then
  lines+=("ALERT: origin/main COORDINATION.md differs from HEAD ($(git rev-parse --short origin/main 2>/dev/null) vs $(git rev-parse --short HEAD 2>/dev/null))")
fi
# COORDINATION.md changes are reported above as a prompt line only; they never block the stop
# (they are not battery results).
for c in "$state"/*.commit; do
  [[ -e $c ]] || continue
  name=$(basename "$c" .commit); commit=$(cat "$c"); start=$(cat "$state/$name.start" 2>/dev/null)
  if [[ -f $state/$name.exit ]]; then
    code=$(cat "$state/$name.exit")
    lines+=("$name: finished (exit $code) on $commit, started $start; results in sim/battery/results/$name.*")
    [[ -f $state/$name.acked ]] || finished+=("$name (exit $code, commit $commit)")
  elif alive "$(cat "$state/$name.pid" 2>/dev/null)" "$name"; then
    lines+=("$name: running on $commit since $start ($(wc -l < "$state/$name.log" 2>/dev/null || echo 0) log lines)")
  elif [[ $mode == session ]]; then
    tools/battery/run.sh "$name" > /dev/null
    lines+=("$name: interrupted (container restart); relaunched on $(cat "$state/$name.commit"), resuming from its cache")
  else
    lines+=("$name: interrupted; the next session start relaunches it (or tools/battery/run.sh $name)")
  fi
done
head=$(git rev-parse --short HEAD 2>/dev/null)
case $mode in
  session|prompt)
    ((${#lines[@]})) && printf 'Batteries (HEAD %s):\n' "$head" && printf '  %s\n' "${lines[@]}" ;;
  stop)
    if ((${#finished[@]})); then
      for f in "${finished[@]}"; do touch "$state/${f%% *}.acked"; done
      reason="Battery finished: ${finished[*]}. Record its results tagged with its commit (sim/README.md Latest readings), commit and push, and relaunch with tools/battery/run.sh only if executable code changed since (sim/src, sim/battery or the Lean reference: the battery's code_hash); commits of docs or results never warrant a rebuild or relaunch."
      printf '{"decision":"block","reason":"%s"}\n' "$reason"
    fi ;;
esac
exit 0
