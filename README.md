# Claude Code tmux status icons

Per-window icons in the tmux status bar, one per Claude Code pane, driven by Claude Code hooks:

| Icon | State |
|------|-------|
| 🤖 | Working (thinking, tool use) |
| 🛎️ | Waiting for you (permission or elicitation prompt) |
| 📝 | Post-processing: a nested `claude -p` spawned by a hook or tool |
| 💤 | Idle |

Requires tmux ≥ 3.2 (pane user options and `#{P:…}` format loops).

## Setup

### 1. Install the hook script

```bash
cp tmux-claude-state.sh ~/.claude/hooks/tmux-claude-state.sh
chmod +x ~/.claude/hooks/tmux-claude-state.sh
```

### 2. Add hooks to Claude Code settings

Merge `claude-tmux-hooks.json` into `~/.claude/settings.json`. Each hook is the same script with the state as its only argument.

### 3. Add to tmux.conf

```tmux
set -g window-status-format         '#{P:#{?#{==:#{@claude_state},waiting},🛎️ ,}#{?#{==:#{@claude_state},working},🤖 ,}#{?#{==:#{@claude_state},post},📝 ,}#{?#{==:#{@claude_state},idle},💤 ,}}#I:#W#{?window_flags,#{window_flags}, }'
set -g window-status-current-format '#{P:#{?#{==:#{@claude_state},waiting},🛎️ ,}#{?#{==:#{@claude_state},working},🤖 ,}#{?#{==:#{@claude_state},post},📝 ,}#{?#{==:#{@claude_state},idle},💤 ,}}#I:#W#{?window_flags,#{window_flags}, }'
```

Then `tmux source-file ~/.tmux.conf`. No `status-interval` needed: hooks fire on state changes and tmux redraws the status line on its own.

## How it works

Each hook runs `tmux set -p @claude_state <state>` on its own pane (`$TMUX_PANE`; the hooks are no-ops outside tmux). The window format loops over the window's panes with `#{P:…}` and maps the option to an icon, so a window with two Claude panes shows two icons. There is no state file, no poller and no per-tick process: pane options are freed when the pane closes.

**Latency.** Claude Code waits for `PreToolUse` and `UserPromptSubmit` hooks before proceeding, so the script forks its body into the background and returns in a few milliseconds; the `tmux`/`ps` calls (~80 ms) never sit on the tool-call path. `end` runs synchronously because the exiting Claude has to be alive for the ancestry walk.

**Nested sessions.** A headless `claude -p` launched from a hook (a session journal, say) inherits `$TMUX_PANE`, and its own hooks would otherwise flip the tab to 🤖. The script counts `claude` processes between itself and the pane's shell; two or more means it is nested, so it reports 📝 instead and never clears the outer session's state. No spawner has to opt in. `SessionEnd` hooks run in parallel, so the outer session's `end` leaves a `post` it finds in place and the child clears it on exit. Detection assumes the native install, where the process is named `claude`; an npm install runs as `node` and is not detected. `CLAUDE_STATUS_STATE=<state>` overrides the detection if you need to.

**Why not tmux `monitor-*` flags?** They are close (bell ≈ waiting, activity ≈ working, silence ≈ idle) but they mean "unseen", so tmux clears them when you look at the window, and the bell cannot tell a permission prompt from an idle nudge. Hooks are the only exact source.

**Crash safety.** `SessionEnd` clears the option, but a killed Claude cannot. If you want the icon to vanish whenever the shell gets its prompt back, add to `.zshrc`:

```zsh
precmd() { [[ -n $TMUX_PANE ]] && tmux set -pu -t $TMUX_PANE @claude_state 2>/dev/null }
```
