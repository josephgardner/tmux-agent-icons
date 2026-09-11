#!/usr/bin/env bash
# Renders the Claude state icon for a single tmux window.
# Wire from .tmux.conf:
#   set -g window-status-format         '#(~/.claude/tmux-claude-status.sh #{window_id})#I:#W#{?window_flags,#{window_flags}, }'
#   set -g window-status-current-format '#(~/.claude/tmux-claude-status.sh #{window_id})#I:#W#{?window_flags,#{window_flags}, }'
#
# States (written by the Claude Code hooks): waiting > working > post > idle.
# "post" is a helper session spawned by a hook (e.g. the journal summarizer)
# that exported CLAUDE_STATUS_STATE=post before exec'ing claude.

ICON_IDLE="💤"
ICON_WORKING="🤖"
ICON_WAITING="🛎️"
ICON_POST="📝"

win_id="$1"
[ -z "$win_id" ] && exit 0

panes=$(tmux list-panes -t "$win_id" -F '#{pane_id}' 2>/dev/null) || exit 0

best=0
while IFS= read -r pane; do
  [ -n "$pane" ] || continue
  f="/tmp/claude-status/$pane"
  [ -f "$f" ] || continue
  state=$(<"$f")
  case "$state" in
    waiting) [ "$best" -lt 4 ] && best=4 ;;
    working) [ "$best" -lt 3 ] && best=3 ;;
    post)    [ "$best" -lt 2 ] && best=2 ;;
    idle)    [ "$best" -lt 1 ] && best=1 ;;
  esac
done <<< "$panes"

case "$best" in
  4) printf '%s ' "$ICON_WAITING" ;;
  3) printf '%s ' "$ICON_WORKING" ;;
  2) printf '%s ' "$ICON_POST" ;;
  1) printf '%s ' "$ICON_IDLE" ;;
esac
