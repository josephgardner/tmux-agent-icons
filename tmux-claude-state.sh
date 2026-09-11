#!/usr/bin/env bash
# Claude Code hook: publish this session's state as a tmux pane option.
#   tmux-claude-state.sh working|waiting|idle|end
#
# Interactive sessions write @claude_state; headless ones (`claude -p`, the SDK)
# write @claude_post, which the status bar renders as "post-processing". Claude
# Code sets CLAUDE_CODE_ENTRYPOINT to "cli" only for interactive sessions, so a
# hook-spawned `claude -p` sharing this pane never touches the outer session's
# key and there is nothing to race or reconcile. Options die with the pane.
[ -n "$TMUX_PANE" ] || exit 0
opt=@claude_state
[ "${CLAUDE_CODE_ENTRYPOINT:-cli}" = cli ] || opt=@claude_post
if [ "$1" = end ]; then
  tmux set -pu -t "$TMUX_PANE" "$opt" 2>/dev/null
else
  tmux set -p -t "$TMUX_PANE" "$opt" "$1" 2>/dev/null
fi
exit 0
