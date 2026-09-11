# Claude Code tmux status icons

Shows per-window icons in your tmux status bar based on Claude Code's state:

| Icon | State |
|------|-------|
| 🤖 | Working (thinking, tool use) |
| 🛎️ | Waiting for input |
| 📝 | Post-processing (a helper session spawned by a hook) |
| 💤 | Idle |

## Setup

### 1. Install the status script

```bash
cp tmux-claude-status.sh ~/.claude/tmux-claude-status.sh
chmod +x ~/.claude/tmux-claude-status.sh
```

### 2. Add hooks to Claude Code settings

Merge the contents of `claude-tmux-hooks.json` into your `~/.claude/settings.json` (or your project's `.claude/settings.json`).

### 3. Add to tmux.conf

```tmux
set -g status-interval 2
set -g window-status-format         '#(~/.claude/tmux-claude-status.sh #{window_id})#I:#W#{?window_flags,#{window_flags}, }'
set -g window-status-current-format '#(~/.claude/tmux-claude-status.sh #{window_id})#I:#W#{?window_flags,#{window_flags}, }'
```

Then reload: `tmux source-file ~/.tmux.conf`

## How it works

The Claude Code hooks write the current state (`working`, `waiting`, `idle`) to `/tmp/claude-status/$TMUX_PANE`. The tmux status script reads those files and picks the highest-priority icon across all panes in each window. The `$TMUX_PANE` guard means the hooks are no-ops outside tmux.

## Post-processing sessions

A hook that runs a headless `claude -p` (a journal summarizer, say) inherits `TMUX_PANE`, so the child's own hooks would show 🤖 while it runs. Export `CLAUDE_STATUS_STATE=post` before spawning it and the `working` hooks write `post` instead, which renders as 📝 and ranks below a live working or waiting pane in the same window. It clears when the child session ends.
