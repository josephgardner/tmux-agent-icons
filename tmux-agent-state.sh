#!/usr/bin/env bash
# Publish an agent's lifecycle state as a tmux pane option for the status bar.
#   tmux-agent-state <agent> working|waiting|idle|end
#
# Shared by the Claude Code, Codex, and opencode integrations. Each agent writes
# its own @<agent>_state pane option; tmux window-status-format renders the icon.
agent=$1
state=$2
[ -n "$agent" ] || exit 0
opt="@${agent}_state"

# Codex runs sessions under a shared app-server daemon whose TMUX_PANE is frozen
# at daemon-start time, so it points at whichever pane started the daemon rather
# than the pane Codex is running in. Recover the real pane by matching the
# session cwd against panes whose foreground process is codex, falling back to
# TMUX_PANE when the match is missing or ambiguous.
pane="${TMUX_PANE:-}"
if [ "$agent" = codex ]; then
  session_cwd=$(pwd -P 2>/dev/null)
  if [ -n "$session_cwd" ]; then
    matches=$(tmux list-panes -a -F '#{pane_id}|#{pane_current_command}|#{pane_current_path}' 2>/dev/null \
      | awk -F'|' -v cwd="$session_cwd" '$2 == "codex" && $3 == cwd { print $1 }')
    count=$(printf '%s\n' "$matches" | grep -c .)
    [ "$count" -eq 1 ] && pane="$matches"
  fi
fi
[ -n "$pane" ] || exit 0

if [ "$state" = end ]; then
  tmux set -pu -t "$pane" "$opt" 2>/dev/null
else
  tmux set -p -t "$pane" "$opt" "$state" 2>/dev/null
fi
exit 0
