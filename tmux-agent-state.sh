#!/usr/bin/env bash
# Publish an agent's lifecycle state as a tmux pane option for the status bar.
#   tmux-agent-state <agent> working|waiting|idle|end
#
# Shared by the Claude Code, Codex, and opencode integrations. Each agent writes
# its own @<agent>_state pane option; tmux window-status-format renders the icon.
[ -n "$TMUX_PANE" ] || exit 0
agent=$1
state=$2
[ -n "$agent" ] || exit 0
opt="@${agent}_state"
if [ "$state" = end ]; then
  tmux set -pu -t "$TMUX_PANE" "$opt" 2>/dev/null
else
  tmux set -p -t "$TMUX_PANE" "$opt" "$state" 2>/dev/null
fi
exit 0