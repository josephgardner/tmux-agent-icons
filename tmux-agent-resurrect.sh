#!/usr/bin/env bash
# tmux-resurrect post-save-layout hook: save each Claude pane as
# `claude --resume <id>` from its @claude_session option, so a restore reopens
# that conversation instead of starting a new one.
#   tmux-agent-resurrect.sh <resurrect save file>
file=$1
[ -f "$file" ] || exit 0

t=$'\t'
tmp="$file.agent.$$"
# First input: live panes and their session ids. Second: the save file.
# FILENAME, not NR == FNR: if tmux prints nothing, the save file must still pass through.
# No transcript yet means nobody typed, and `claude --resume` fails on it: save plain `claude`.
# Headless `claude -p` panes never set the id, so a stale one must not rewrite them.
awk -F'\t' -v OFS='\t' '
  FILENAME == ARGV[1] {
    if ($4 == "") next
    cmd = "claude --resume " $4
    if ($5 != "") { if ((getline line < $5) < 0) cmd = "claude"; else close($5) }
    run[$1, $2, $3] = cmd
    next
  }
  $1 == "pane" && $11 ~ /^:claude( |$)/ && $11 !~ / (-p|--print)( |$)/ && (($2, $3, $6) in run) {
    $11 = ":" run[$2, $3, $6]
  }
  { print }
' <(tmux list-panes -a -F "#{session_name}$t#{window_index}$t#{pane_index}$t#{@claude_session}$t#{@claude_transcript}") \
  "$file" > "$tmp" && mv "$tmp" "$file"
rm -f "$tmp"
