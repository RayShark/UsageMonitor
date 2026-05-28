#!/usr/bin/env bash
set -euo pipefail

current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pane_script="$current_dir/scripts/usage-monitor-pane.sh"

shell_quote() {
  printf '%q' "$1"
}

tmux_option() {
  local name="$1"
  local fallback="$2"
  local value

  value="$(tmux show-option -gqv "$name" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$value"
  fi
}

set_default_tmux_option() {
  local name="$1"
  local fallback="$2"
  local value

  value="$(tmux show-option -gqv "$name" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    tmux set-option -gq "$name" "$fallback"
  fi
}

set_default_tmux_option "@usage_monitor_config" "$HOME/.config/tmux-usage-monitor/config.json"
set_default_tmux_option "@usage_monitor_interval" "60"
set_default_tmux_option "@usage_monitor_height" "2"
set_default_tmux_option "@usage_monitor_model" "gpt-5.5"
set_default_tmux_option "@usage_monitor_key" "u"

config="$(tmux_option "@usage_monitor_config" "$HOME/.config/tmux-usage-monitor/config.json")"
interval="$(tmux_option "@usage_monitor_interval" "60")"
height="$(tmux_option "@usage_monitor_height" "2")"
model="$(tmux_option "@usage_monitor_model" "gpt-5.5")"
key="$(tmux_option "@usage_monitor_key" "u")"

command="USAGE_MONITOR_TMUX_CONFIG=$(shell_quote "$config") USAGE_MONITOR_TMUX_INTERVAL=$(shell_quote "$interval") USAGE_MONITOR_TMUX_HEIGHT=$(shell_quote "$height") USAGE_MONITOR_TMUX_MODEL=$(shell_quote "$model") $(shell_quote "$pane_script")"

tmux bind-key "$key" run-shell -b "$command"
