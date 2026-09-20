#!/usr/bin/env bash
set -euo pipefail

icons='#{P:#{?#{@claude_state},#{?#{==:#{@claude_state},waiting},✋,#{?#{==:#{@claude_state},working},🧠,💤}},#{?#{@claude_post},🔄,}}}}#{P:#{?#{@codex_state},#{?#{==:#{@codex_state},waiting},✋,#{?#{==:#{@codex_state},working},🧠,💤}},}}#{P:#{?#{@opencode_state},#{?#{==:#{@opencode_state},waiting},✋,#{?#{==:#{@opencode_state},working},🧠,💤}},}}#{?#{P:#{@claude_state}#{@claude_post}#{@codex_state}#{@opencode_state}}, ,}'
tmux set-option -g @tmux_agent_icons "$icons"

for option in window-status-format window-status-current-format; do
  format="$(tmux show-option -gv "$option")"
  case "$format" in
    *'#{E:@tmux_agent_icons}'*) ;;
    *) tmux set-option -g "$option" "#{E:@tmux_agent_icons}$format" ;;
  esac
done
