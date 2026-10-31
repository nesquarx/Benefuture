#!/bin/bash
# Launch failure-boundary batteries detached, recording their state in sim/battery/state/ so the
# session hooks (tools/battery/hook.sh) can report them and relaunch any a container restart cut
# short. Evaluations are cached on disk (`cached`, sim/src/battery.jl), so a relaunch resumes.
# Usage: tools/battery/run.sh [economy|governance|attack ...]   (default: economy governance)
cd "$(dirname "$0")/../.." || exit 1
export PATH="$HOME/.local/bin:$PATH"
# A battery is alive when its recorded pid is a julia process running its file (a shell wrapper
# whose command line mentions the file does not count).
alive() { [[ -n $1 && $(cat /proc/$1/comm 2>/dev/null) == julia ]] && grep -qa "sim/battery/$2.jl" /proc/$1/cmdline; }
state=sim/battery/state; mkdir -p "$state"
for b in "${@:-economy governance}"; do
  for name in $b; do
    if [[ -f $state/$name.pid ]] && alive "$(cat $state/$name.pid 2>/dev/null)" "$name"; then
      echo "$name: already running"; continue
    fi
    rm -f "$state/$name.exit" "$state/$name.acked"
    git rev-parse --short HEAD > "$state/$name.commit"
    date -u +%FT%TZ > "$state/$name.start"
    setsid nohup bash -c "julia --project=sim sim/battery/$name.jl > $state/$name.log 2>&1; echo \$? > $state/$name.exit" \
      > /dev/null 2>&1 < /dev/null &
    # the julia child's pid: the cmdline check above looks for the battery file in it
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pid=$(pgrep -f "^julia --project=sim sim/battery/$name.jl" | head -1); [[ -n $pid ]] && break; sleep 0.5
    done
    echo "$pid" > "$state/$name.pid"
    echo "$name: launched (pid $pid, commit $(cat $state/$name.commit))"
  done
done
