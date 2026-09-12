# Claude Code tmux status icons

Per-window icons in the tmux status bar, one per Claude Code pane, driven by Claude Code hooks. Five lines of shell, one `tmux set` per event, no poller, no state files.

| Icon | State |
|------|-------|
| 🧠 | Working (thinking, tool use) |
| ✋ | Waiting for you (permission or elicitation prompt) |
| ♻️ | Post-processing: a headless `claude -p` running in the pane, e.g. spawned by a hook |
| 💤 | Idle |

Requires tmux ≥ 3.2 (pane user options and `#{P:…}` format loops).

## Setup

1. `cp tmux-claude-state.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/tmux-claude-state.sh`
2. Merge `claude-tmux-hooks.json` into `~/.claude/settings.json`. Every hook is the same script with the state as its only argument. `PostToolUse` matters: `PreToolUse` fires before the permission prompt, so without it an approved tool call would keep showing ✋ until the next event.
3. Add to `~/.tmux.conf` and `tmux source-file ~/.tmux.conf`:

```tmux
set -g window-status-format         '#{P:#{?#{@claude_state},#{?#{==:#{@claude_state},waiting},✋,#{?#{==:#{@claude_state},working},🧠,💤}},#{?#{@claude_post},♻️,}}}#{?#{P:#{@claude_state}#{@claude_post}}, ,}#I:#W#{?window_flags,#{window_flags}, }'
set -g window-status-current-format '#{P:#{?#{@claude_state},#{?#{==:#{@claude_state},waiting},✋,#{?#{==:#{@claude_state},working},🧠,💤}},#{?#{@claude_post},♻️,}}}#{?#{P:#{@claude_state}#{@claude_post}}, ,}#I:#W#{?window_flags,#{window_flags}, }'
```

## How it works

Each hook runs `tmux set -p <option> <state>` on its own pane (`$TMUX_PANE`; the hooks are no-ops outside tmux). The window format loops the window's panes with `#{P:…}` and maps the option to an icon, so a window with two Claude panes shows two icons side by side, followed by a single space. Pane options are freed when the pane closes.

**Headless sessions.** A `claude -p` launched from a hook (a session journal, say) inherits `$TMUX_PANE`, and its own hooks would otherwise flip the tab to 🧠. Claude Code sets `CLAUDE_CODE_ENTRYPOINT=cli` only for interactive sessions (`sdk-cli` for `-p`, `sdk-*` for the SDKs), so the script routes non-interactive sessions to a second option, `@claude_post`. The two sessions never write the same key, which is what makes parallel `SessionEnd` hooks safe without any read-modify-write. The format shows the interactive state when present and ♻️ otherwise. Consequence: a `claude -p` you type by hand also shows ♻️.

**Why not tmux `monitor-*` flags?** They are close (bell ≈ waiting, activity ≈ working, silence ≈ idle) but they mean "unseen", so tmux clears them when you look at the window, and the bell cannot tell a permission prompt from an idle nudge. Hooks are the only exact source.

**Crash safety.** `SessionEnd` clears the option, but a killed Claude cannot. To clear both keys whenever the shell gets its prompt back, add to `.zshrc`:

```zsh
autoload -Uz add-zsh-hook
_claude_tmux_state_clear() { [[ -n $TMUX_PANE ]] && tmux set -pu -t "$TMUX_PANE" @claude_state \; set -pu -t "$TMUX_PANE" @claude_post 2>/dev/null; return 0 }
add-zsh-hook precmd _claude_tmux_state_clear
```

**Alignment.** `♻️` carries a variation selector and renders as one or two cells depending on the terminal. If your tabs jitter, swap the emoji for single-cell glyphs or colour the tab name instead, e.g. `#{?#{==:#{@claude_state},waiting},#[fg=yellow],}`.

## Alternatives

[tmux-tab-pulse](https://github.com/rafaelsales/tmux-tab-pulse) (TPM, spinner, marks any busy process, background daemon), [tmux-agent-indicator](https://github.com/accessd/tmux-agent-indicator) (TPM, Claude + Codex + OpenCode, pane borders), [partner0/tmux-agent-status](https://github.com/partner0/tmux-agent-status) (same mechanism, renames the window). None distinguish a headless child session from the pane's owner.



