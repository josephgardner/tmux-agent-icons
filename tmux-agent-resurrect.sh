#!/usr/bin/env bash
# tmux-resurrect post-save-layout hook: save each Claude pane as
# `claude --resume <id>` from its @claude_session option, so a restore reopens
# that conversation instead of starting a new one.
#   tmux-agent-resurrect.sh <resurrect save file>
file=$1
[ -f "$file" ] || exit 0

tmp="$file.agent.$$"
# First input: live panes and their session ids. Second: the save file.
awk -F'\t' -v OFS='\t' '
  NR == FNR { if ($4 != "") sid[$1 SUBSEP $2 SUBSEP $3] = $4; next }
  $1 == "pane" && $11 ~ /^:claude( |$)/ && (($2 SUBSEP $3 SUBSEP $6) in sid) {
    $11 = ":claude --resume " sid[$2 SUBSEP $3 SUBSEP $6]
  }
  { print }
' <(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{@claude_session}') \
  "$file" > "$tmp" && mv "$tmp" "$file"
rm -f "$tmp"
