# tmux Agent Icons

See what your coding agents are doing without leaving tmux.

![tmux status bar showing agent state icons](screenshot.png)

| Icon | State |
| --- | --- |
| 🧠 | working |
| ✋ | waiting for you |
| 💤 | idle |
| 🔄 | headless Claude work |

Claude Code, Codex, and OpenCode publish lifecycle events directly to the tmux pane. No polling, daemon, or state files.

## Install

### tmux

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'josephgardner/tmux-agent-icons'
```

Reload tmux, then press `prefix + I`. The plugin prepends the icons to your existing window format. Requires tmux 3.2+.

### Claude Code

```sh
claude plugin marketplace add josephgardner/tmux-agent-icons
claude plugin install tmux-agent-icons@tmux-agent-icons
```

### Codex

Codex removed plugin-provided hooks, so this integration installs a config hooks file plus a helper:

```sh
raw=https://raw.githubusercontent.com/josephgardner/tmux-agent-icons/main
mkdir -p ~/.local/bin ~/.codex
curl -fsSL "$raw/tmux-agent-state.sh" -o ~/.local/bin/tmux-agent-state
chmod +x ~/.local/bin/tmux-agent-state
curl -fsSL "$raw/codex-hooks.json" -o ~/.codex/hooks.json
```

Run `/hooks` once to review and trust the hooks.

### OpenCode

Requires OpenCode v2+ (the `plugin add` command, the `::path:` git selector, and the `@opencode/plugin` API).

```sh
opencode plugin add 'github:josephgardner/tmux-agent-icons#main::path:opencode'
```

## How it works

Each integration writes a pane-local tmux option (`@claude_state`, `@codex_state`, or `@opencode_state`). The tmux plugin turns those values into icons in the window list, including multiple agent panes in one window.

Claude's non-interactive `-p`/SDK sessions use `@claude_post`, so background work cannot overwrite the interactive session's state.
