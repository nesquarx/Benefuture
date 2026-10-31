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
alive() { [[ -n $1 && $(cat /proc/$1/comm 2>/dev/null) == julia ]] && grep -qa "sim/battery/$2.jl" /proc/$1/cmdline; }
state=sim/battery/state
[[ -d $state ]] || exit 0
mode=$1; lines=(); finished=()
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
      reason="Battery finished: ${finished[*]}. Record its results tagged with its commit (sim/README.md Latest readings), commit and push, and relaunch with tools/battery/run.sh if the code changed since."
      printf '{"decision":"block","reason":"%s"}\n' "$reason"
    fi ;;
esac
exit 0
