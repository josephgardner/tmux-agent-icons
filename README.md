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

Reload tmux, then press `prefix + I`. Requires tmux 3.2+.

### Claude Code

```sh
claude plugin marketplace add josephgardner/tmux-agent-icons
claude plugin install tmux-agent-icons@tmux-agent-icons
```

### Codex

```sh
codex plugin marketplace add josephgardner/tmux-agent-icons
codex plugin add tmux-agent-icons@tmux-agent-icons
```

Run `/hooks` once to review and trust the plugin hooks.

### OpenCode

```sh
opencode plugin add 'github:josephgardner/tmux-agent-icons#main::path:opencode'
```

## How it works

Each integration writes a pane-local tmux option (`@claude_state`, `@codex_state`, or `@opencode_state`). The tmux plugin turns those values into icons in the window list, including multiple agent panes in one window.

Claude's non-interactive `-p`/SDK sessions use `@claude_post`, so background work cannot overwrite the interactive session's state.
