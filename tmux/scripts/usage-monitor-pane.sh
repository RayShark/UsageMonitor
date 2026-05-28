#!/usr/bin/env bash
set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'usage-monitor: missing %s\n' "$1"
    exit 0
  fi
}

numeric_or_default() {
  local value="$1"
  local fallback="$2"
  case "$value" in
    ''|*[!0-9]*)
      printf '%s' "$fallback"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

shell_quote() {
  printf '%q' "$1"
}

require_command tmux

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
renderer="$plugin_dir/scripts/usage-monitor-render.sh"

height="$(numeric_or_default "${USAGE_MONITOR_TMUX_HEIGHT:-2}" 2)"
interval="$(numeric_or_default "${USAGE_MONITOR_TMUX_INTERVAL:-60}" 60)"
model="${USAGE_MONITOR_TMUX_MODEL:-gpt-5.5}"
config="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
title="usage-monitor"

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
if [[ -z "$current_pane" ]]; then
  printf 'usage-monitor: no active tmux pane\n'
  exit 0
fi

existing_pane="$(
  tmux list-panes -F '#{pane_id} #{pane_title}' |
    awk -v title="$title" '$2 == title { print $1; exit }'
)"

if [[ -n "$existing_pane" ]]; then
  tmux kill-pane -t "$existing_pane"
  exit 0
fi

loop_command="while :; do $(shell_quote "$renderer") --config $(shell_quote "$config") --model $(shell_quote "$model") --interval $(shell_quote "$interval") --no-color; sleep $(shell_quote "$interval"); done"
new_pane="$(
  tmux split-window \
    -P \
    -F '#{pane_id}' \
    -v \
    -l "$height" \
    -t "$current_pane" \
    "bash -lc $(shell_quote "$loop_command")"
)"

tmux select-pane -t "$new_pane" -T "$title"
tmux select-pane -t "$current_pane"
