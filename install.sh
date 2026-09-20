#!/usr/bin/env bash
# Install tmux Agent Icons for Claude Code, Codex, opencode, and/or tmux.
#
#   curl -fsSL https://raw.githubusercontent.com/josephgardner/tmux-agent-icons/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/josephgardner/tmux-agent-icons/main/install.sh | TARGET=claude bash
#   ./install.sh codex opencode
#
# With no target it prompts (when a terminal is available); otherwise it
# installs everything. Targets: all, tmux, claude, codex, opencode.
set -euo pipefail

REPO="josephgardner/tmux-agent-icons"
BRANCH="main"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# When run from a checkout, install from the local files and skip the network.
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$d/tmux-agent-state.sh" ] && SRC_DIR="$d"
fi

fetch() { # fetch <file> <dest>
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$1" ]; then
    cp "$SRC_DIR/$1" "$2"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RAW/$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$RAW/$1"
  else
    die "curl or wget is required to download $1"
  fi
}

backup() { [ -e "$1" ] && cp "$1" "$1.bak.$(date +%Y%m%d%H%M%S)"; return 0; }

has_jq() { command -v jq >/dev/null 2>&1; }

install_tmux() {
  local conf="$HOME/.tmux.conf"
  local block='# Agent pane-state icons (Claude Code, Codex, opencode) — github.com/josephgardner/tmux-agent-icons'
  local line1="set -g window-status-format         '#{P:#{?#{@claude_state},#{?#{==:#{@claude_state},waiting},✋,#{?#{==:#{@claude_state},working},🧠,💤}},#{?#{@claude_post},🔄,}}}}#{P:#{?#{@codex_state},#{?#{==:#{@codex_state},waiting},✋,#{?#{==:#{@codex_state},working},🧠,💤}},}}#{P:#{?#{@opencode_state},#{?#{==:#{@opencode_state},waiting},✋,#{?#{==:#{@opencode_state},working},🧠,💤}},}}#{?#{P:#{@claude_state}#{@claude_post}#{@codex_state}#{@opencode_state}}, ,}#I:#W#{?window_flags,#{window_flags}, }'"
  local line2="set -g window-status-current-format '#{P:#{?#{@claude_state},#{?#{==:#{@claude_state},waiting},✋,#{?#{==:#{@claude_state},working},🧠,💤}},#{?#{@claude_post},🔄,}}}}#{P:#{?#{@codex_state},#{?#{==:#{@codex_state},waiting},✋,#{?#{==:#{@codex_state},working},🧠,💤}},}}#{P:#{?#{@opencode_state},#{?#{==:#{@opencode_state},waiting},✋,#{?#{==:#{@opencode_state},working},🧠,💤}},}}#{?#{P:#{@claude_state}#{@claude_post}#{@codex_state}#{@opencode_state}}, ,}#I:#W#{?window_flags,#{window_flags}, }'"

  if [ -f "$conf" ] && grep -q '@claude_state' "$conf"; then
    say "tmux: already configured in $conf"
  elif [ -f "$conf" ] && grep -q 'window-status-format' "$conf"; then
    warn "tmux: $conf already sets window-status-format; not touching it."
    warn "      Merge the block from the README's tmux section by hand."
  else
    backup "$conf"
    { [ -f "$conf" ] && printf '\n'; printf '%s\n%s\n%s\n' "$block" "$line1" "$line2"; } >> "$conf"
    say "tmux: appended the status-bar format to $conf"
  fi
}

install_claude() {
  local hooks="$HOME/.claude/hooks" settings="$HOME/.claude/settings.json"
  mkdir -p "$hooks"
  fetch tmux-claude-state.sh "$hooks/tmux-claude-state.sh"
  chmod +x "$hooks/tmux-claude-state.sh"
  say "claude: installed $hooks/tmux-claude-state.sh"

  local add; add="$(mktemp)"
  fetch claude-tmux-hooks.json "$add"

  if ! has_jq; then
    cp "$add" "$HOME/.claude/claude-tmux-hooks.json"
    rm -f "$add"
    warn "claude: jq not found. Merge ~/.claude/claude-tmux-hooks.json into"
    warn "        $settings yourself (see the README)."
    return 0
  fi

  local created=0
  if [ ! -f "$settings" ]; then
    printf '{}\n' > "$settings"
    created=1
  fi
  if [ "$created" -eq 0 ]; then
    backup "$settings"
  fi
  local tmp; tmp="$(mktemp)"
  jq --slurpfile add "$add" '
    .hooks = ((.hooks // {}) as $h
      | reduce ($add[0].hooks | keys[]) as $k ($h;
          .[$k] = ((.[$k] // []) + $add[0].hooks[$k] | unique)))
  ' "$settings" > "$tmp" && mv "$tmp" "$settings"
  rm -f "$add"
  say "claude: merged hook entries into $settings"
}

install_codex() {
  mkdir -p "$HOME/.local/bin" "$HOME/.codex"
  fetch tmux-agent-state.sh "$HOME/.local/bin/tmux-agent-state"
  chmod +x "$HOME/.local/bin/tmux-agent-state"
  backup "$HOME/.codex/hooks.json"
  fetch codex-hooks.json "$HOME/.codex/hooks.json"
  say "codex: installed ~/.local/bin/tmux-agent-state and ~/.codex/hooks.json"
  say "codex: start Codex and run /hooks to trust the new hooks."
}

install_opencode() {
  local dir="$HOME/.config/opencode/plugin" cfg="$HOME/.config/opencode/opencode.jsonc"
  mkdir -p "$dir"
  fetch opencode-tmux-agent-state.ts "$dir/tmux-agent-state.ts"
  say "opencode: installed $dir/tmux-agent-state.ts"

  local entry='./plugin/tmux-agent-state.ts'
  if [ ! -f "$cfg" ]; then
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "plugin": ["%s"]\n}\n' "$entry" > "$cfg"
    say "opencode: wrote $cfg"
  elif has_jq && jq -e . "$cfg" >/dev/null 2>&1; then
    backup "$cfg"
    local tmp; tmp="$(mktemp)"
    jq --arg e "$entry" '.plugin = ((.plugin // []) + [$e] | unique)' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    say "opencode: added the plugin to $cfg"
  else
    warn "opencode: could not parse $cfg (comments?). Add \"$entry\""
    warn "          to its \"plugin\" array by hand (see the README)."
  fi
  say "opencode: restart it to load the plugin."
}

# Map a menu answer ("3", "4 5", "", …) on stdin to target names on stdout.
parse_selection() {
  local reply tok seen=""
  IFS= read -r reply || true
  [ -n "$reply" ] || { printf 'all\n'; return; }
  for tok in $(printf '%s' "$reply" | tr ',' ' '); do
    case "$tok" in
      1|all|everything) printf 'all\n'; return ;;
      2|tmux)     tok=tmux ;;
      3|claude)   tok=claude ;;
      4|codex)    tok=codex ;;
      5|opencode) tok=opencode ;;
      *) warn "ignoring unknown selection: $tok"; continue ;;
    esac
    case " $seen " in
      *" $tok "*) ;;
      *) seen="$seen $tok"; printf '%s\n' "$tok" ;;
    esac
  done
}

# No target given: ask, unless there is no terminal (then install everything).
prompt_menu() {
  local tty=/dev/tty
  {
    printf '\n  tmux Agent Icons — what should I install?\n\n'
    printf '    1) everything    tmux + Claude Code + Codex + opencode\n'
    printf '    2) tmux          status-bar format\n'
    printf '    3) Claude Code   hook + settings.json entries\n'
    printf '    4) Codex         hooks.json + helper\n'
    printf '    5) opencode      plugin + config entry\n\n'
    printf '  Numbers separated by spaces, or Enter for everything: '
  } > "$tty"
  parse_selection < "$tty"
}

collect_targets() {
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$*" | tr ',' ' ' | tr ' ' '\n'
  elif [ -n "${TARGET:-}" ]; then
    printf '%s\n' "$TARGET" | tr ',' ' ' | tr ' ' '\n'
  elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
    prompt_menu
  else
    printf 'all\n'
  fi
}

targets=()
while IFS= read -r t; do
  [ -n "$t" ] && targets+=("$t")
done < <(collect_targets "$@")
[ "${#targets[@]}" -eq 0 ] && targets=(all)

for t in "${targets[@]}"; do
  case "$t" in
    all)      install_tmux; install_claude; install_codex; install_opencode ;;
    tmux)     install_tmux ;;
    claude)   install_claude ;;
    codex)    install_codex ;;
    opencode) install_opencode ;;
    *)        die "unknown target: $t (use tmux, claude, codex, opencode, or all)" ;;
  esac
done

say "Done. Reload tmux with: tmux source-file ~/.tmux.conf"
