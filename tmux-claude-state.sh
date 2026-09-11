#!/usr/bin/env bash
# Claude Code hook: publish this session's state as a tmux pane option.
#   tmux-claude-state.sh working|waiting|idle|end
# The status bar reads #{@claude_state} directly, so there is no poller,
# no state file, and the option dies with the pane.
#
# A Claude nested under another Claude in the same pane (a headless `claude -p`
# spawned by a hook or a tool) reports "post" instead of "working"/"waiting" and
# never overwrites the outer session's state on idle/end. Nesting is detected by
# counting `claude` processes between this hook and the pane's shell, so no
# spawner has to opt in. This assumes the native install, where the process is
# named `claude`; an npm install runs as `node` and is not detected.
# CLAUDE_STATUS_STATE=<state> overrides the detection if set.
#
# Claude Code awaits PreToolUse/UserPromptSubmit hooks, so the work is detached:
# the caller returns in ~2ms and the ~80ms of tmux/ps forks run in the background.
# "end" stays synchronous: the exiting Claude must still be alive for the walk.

[ -n "$TMUX_PANE" ] || exit 0
state="$1"
[ -n "$state" ] || exit 0

main() {
  local pane_pid depth p ppid comm hops cur
  pane_pid=$(tmux display -p -t "$TMUX_PANE" '#{pane_pid}' 2>/dev/null) || return 0

  depth=0 hops=0 p=$PPID
  while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$p" != "$pane_pid" ] && [ "$hops" -lt 16 ]; do
    read -r ppid comm < <(ps -o ppid=,comm= -p "$p" 2>/dev/null) || break
    case "${comm##*/}" in claude) depth=$((depth + 1)) ;; esac
    p=$ppid hops=$((hops + 1))
  done

  if [ -n "$CLAUDE_STATUS_STATE" ]; then
    state="$CLAUDE_STATUS_STATE"
  elif [ "$depth" -ge 2 ]; then
    case "$state" in
      working|waiting) state=post ;;
      idle) return 0 ;;                       # outer session owns idle
      end)  cur=$(tmux show -pv -t "$TMUX_PANE" @claude_state 2>/dev/null)
            [ "$cur" = post ] || return 0 ;;  # only clear what we set
    esac
  elif [ "$state" = end ]; then
    # SessionEnd hooks run in parallel: a nested child may already have
    # published "post". Leave it; the child clears it when it exits.
    cur=$(tmux show -pv -t "$TMUX_PANE" @claude_state 2>/dev/null)
    [ "$cur" = post ] && return 0
  fi

  if [ "$state" = end ]; then
    tmux set -pu -t "$TMUX_PANE" @claude_state 2>/dev/null
  else
    tmux set -p -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null
  fi
}

if [ "$state" = end ]; then
  main
else
  main >/dev/null 2>&1 </dev/null &
fi
exit 0
