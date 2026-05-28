#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="usage-monitor-layout-$$"
TMUX=(tmux -L "$SERVER" -f /dev/null)

cleanup() {
  tmux -L "$SERVER" kill-server 2>/dev/null || true
}
trap cleanup EXIT

"${TMUX[@]}" new-session -d -s "$SERVER" -x 120 -y 30 'sleep 3600'

top_pane="$("${TMUX[@]}" list-panes -t "$SERVER:0" -F '#{pane_id}' | head -n1)"
bottom_pane="$("${TMUX[@]}" split-window -P -F '#{pane_id}' -v -l 10 -t "$top_pane" 'sleep 3600')"

"${TMUX[@]}" run-shell \
  "USAGE_MONITOR_TMUX_SCOPE=pane \
USAGE_MONITOR_TMUX_TARGET_PANE=$top_pane \
USAGE_MONITOR_TMUX_TARGET_SESSION=$SERVER \
USAGE_MONITOR_TMUX_HEIGHT=2 \
USAGE_MONITOR_TMUX_INTERVAL=60 \
USAGE_MONITOR_TMUX_CONFIG=/tmp/usage-monitor-layout-test-missing.json \
$ROOT_DIR/tmux/scripts/usage-monitor-pane.sh"

sleep 0.5

layout="$("${TMUX[@]}" list-panes -t "$SERVER:0" -F '#{pane_id} #{pane_title} #{pane_top} #{pane_height} #{pane_current_command}')"
monitor_top="$(awk '$2 == "usage-monitor" { print $3; exit }' <<<"$layout")"
bottom_top="$(awk -v pane="$bottom_pane" '$1 == pane { print $3; exit }' <<<"$layout")"

if [[ -z "$monitor_top" ]]; then
  printf 'not ok monitor pane was created\n' >&2
  printf '%s\n' "$layout" >&2
  exit 1
fi

if [[ "$monitor_top" -le "$bottom_top" ]]; then
  printf 'not ok monitor pane should be below existing content panes\n' >&2
  printf 'bottom pane top: %s\nmonitor pane top: %s\n' "$bottom_top" "$monitor_top" >&2
  printf '%s\n' "$layout" >&2
  exit 1
fi

printf 'ok monitor pane is placed at the bottom\n'
