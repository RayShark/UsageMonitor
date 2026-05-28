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
loop="$plugin_dir/scripts/usage-monitor-loop.sh"

height="$(numeric_or_default "${USAGE_MONITOR_TMUX_HEIGHT:-2}" 2)"
interval="$(numeric_or_default "${USAGE_MONITOR_TMUX_INTERVAL:-60}" 60)"
model="${USAGE_MONITOR_TMUX_MODEL:-gpt-5.5}"
config="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
mode="${USAGE_MONITOR_TMUX_MODE:-oneline}"
theme="${USAGE_MONITOR_TMUX_THEME:-classic}"
scope="${USAGE_MONITOR_TMUX_SCOPE:-pane}"
target_pane="${USAGE_MONITOR_TMUX_TARGET_PANE:-}"
target_session="${USAGE_MONITOR_TMUX_TARGET_SESSION:-}"
title="usage-monitor"

if [[ -z "$target_pane" ]]; then
  target_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi
if [[ -z "$target_pane" ]]; then
  printf 'usage-monitor: no active tmux pane\n'
  exit 0
fi

if [[ -z "$target_session" ]]; then
  target_session="$(tmux display-message -pt "$target_pane" '#{session_name}' 2>/dev/null || true)"
fi
if [[ -z "$target_session" ]]; then
  printf 'usage-monitor: no target tmux session\n'
  exit 0
fi

largest_content_pane() {
  local target="$1"
  tmux list-panes -t "$target" -F '#{pane_id}|#{pane_width}|#{pane_height}|#{pane_current_command}|#{pane_title}' |
    awk -F '|' '
      $4 != "tmux-agent-sidebar" && $5 != "usage-monitor" {
        area = $2 * $3
        if (area > best_area) {
          best_area = area
          best_pane = $1
        }
      }
      END { print best_pane }
    '
}

bottom_content_pane() {
  local target="$1"
  tmux list-panes -t "$target" -F '#{pane_id}|#{pane_top}|#{pane_width}|#{pane_height}|#{pane_current_command}|#{pane_title}' |
    awk -F '|' '
      $5 != "tmux-agent-sidebar" && $6 != "usage-monitor" {
        bottom = $2 + $4
        area = $3 * $4
        if (bottom > best_bottom || (bottom == best_bottom && area > best_area)) {
          best_bottom = bottom
          best_area = area
          best_pane = $1
        }
      }
      END { print best_pane }
    '
}

monitor_panes_for() {
  local target="$1"
  tmux list-panes -t "$target" -F '#{pane_id} #{pane_title}' |
    awk -v title="$title" '$2 == title { print $1 }'
}

monitor_panes_for_session() {
  local session="$1"
  tmux list-panes -s -t "$session" -F '#{pane_id} #{pane_title}' |
    awk -v title="$title" '$2 == title { print $1 }'
}

kill_monitor_panes_for() {
  local target="$1"
  monitor_panes_for "$target" | while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    tmux kill-pane -t "$pane"
  done
}

kill_monitor_panes_for_session() {
  local session="$1"
  monitor_panes_for_session "$session" | while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    tmux kill-pane -t "$pane"
  done
}

content_target_for_pane() {
  local pane="$1"
  local command
  local window
  local replacement

  command="$(tmux display-message -pt "$pane" '#{pane_current_command}' 2>/dev/null || true)"
  if [[ "$command" != "tmux-agent-sidebar" ]]; then
    printf '%s' "$pane"
    return
  fi

  window="$(tmux display-message -pt "$pane" '#{session_name}:#{window_index}' 2>/dev/null || true)"
  replacement="$(largest_content_pane "$window")"
  if [[ -n "$replacement" ]]; then
    printf '%s' "$replacement"
  else
    printf '%s' "$pane"
  fi
}

create_monitor_pane() {
  local pane="$1"
  local focus="${2:-monitor}"
  local loop_command
  local new_pane
  local split_args

  loop_command="USAGE_MONITOR_TMUX_CONFIG=$(shell_quote "$config") USAGE_MONITOR_TMUX_INTERVAL=$(shell_quote "$interval") USAGE_MONITOR_TMUX_MODEL=$(shell_quote "$model") USAGE_MONITOR_TMUX_MODE=$(shell_quote "$mode") USAGE_MONITOR_TMUX_THEME=$(shell_quote "$theme") $(shell_quote "$loop")"
  split_args=(-P -F '#{pane_id}' -v -l "$height" -t "$pane")
  if [[ "$focus" != "monitor" ]]; then
    split_args=(-d "${split_args[@]}")
  fi

  new_pane="$(
    tmux split-window \
      "${split_args[@]}" \
      "bash -lc $(shell_quote "$loop_command")"
  )"

  tmux select-pane -t "$new_pane" -T "$title"
  if [[ "$focus" == "monitor" ]]; then
    tmux select-pane -t "$new_pane"
  else
    tmux select-pane -t "$pane"
  fi
}

if [[ "$scope" == "session" ]]; then
  if [[ -n "$(monitor_panes_for_session "$target_session")" ]]; then
    kill_monitor_panes_for_session "$target_session"
    exit 0
  fi
else
  target_window="$(tmux display-message -pt "$target_pane" '#{session_name}:#{window_index}' 2>/dev/null || true)"
  if [[ -n "$target_window" && -n "$(monitor_panes_for "$target_window")" ]]; then
    kill_monitor_panes_for "$target_window"
    exit 0
  fi
fi

if [[ "$scope" == "session" ]]; then
  while read -r window; do
    pane="$(bottom_content_pane "$window")"
    if [[ -n "$pane" ]]; then
      create_monitor_pane "$pane" "background"
    fi
  done < <(tmux list-windows -t "$target_session" -F '#{session_name}:#{window_index}')
else
  target_window="$(tmux display-message -pt "$target_pane" '#{session_name}:#{window_index}' 2>/dev/null || true)"
  pane=""
  if [[ -n "$target_window" ]]; then
    pane="$(bottom_content_pane "$target_window")"
  fi
  if [[ -n "$pane" ]]; then
    target_pane="$pane"
  else
    target_pane="$(content_target_for_pane "$target_pane")"
  fi
  create_monitor_pane "$target_pane"
fi
