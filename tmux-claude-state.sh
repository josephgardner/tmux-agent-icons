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
# spawner has to opt in. CLAUDE_STATUS_STATE=<state> overrides that if set.

[ -n "$TMUX_PANE" ] || exit 0
state="$1"
[ -n "$state" ] || exit 0

pane_pid=$(tmux display -p -t "$TMUX_PANE" '#{pane_pid}' 2>/dev/null) || exit 0

depth=0
p=$PPID
while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$p" != "$pane_pid" ]; do
  read -r ppid comm < <(ps -o ppid=,comm= -p "$p" 2>/dev/null) || break
  case "${comm##*/}" in claude) depth=$((depth + 1)) ;; esac
  p="${ppid// /}"
done
nested=0; [ "$depth" -ge 2 ] && nested=1

if [ -n "$CLAUDE_STATUS_STATE" ]; then
  state="$CLAUDE_STATUS_STATE"
elif [ "$nested" = 1 ]; then
  case "$state" in
    working|waiting) state=post ;;
    idle)  exit 0 ;;   # outer session owns the idle transition
    end)   cur=$(tmux show -pv -t "$TMUX_PANE" @claude_state 2>/dev/null)
           [ "$cur" = post ] || exit 0 ;;
  esac
fi

if [ "$state" = end ]; then
  tmux set -pu -t "$TMUX_PANE" @claude_state 2>/dev/null
else
  tmux set -p -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null
fi
exit 0
