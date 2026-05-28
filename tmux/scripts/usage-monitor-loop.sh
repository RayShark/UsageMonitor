#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
renderer="${USAGE_MONITOR_TMUX_RENDERER:-$plugin_dir/scripts/usage-monitor-render.sh}"

config="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
interval="${USAGE_MONITOR_TMUX_INTERVAL:-60}"
model="${USAGE_MONITOR_TMUX_MODEL:-gpt-5.5}"
mode="${USAGE_MONITOR_TMUX_MODE:-oneline}"
theme="${USAGE_MONITOR_TMUX_THEME:-classic}"
themes=(classic mono dracula catppuccin tokyonight nord gruvbox)

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

theme_index() {
  local index=0
  local candidate
  for candidate in "${themes[@]}"; do
    if [[ "$candidate" == "$theme" ]]; then
      printf '%s' "$index"
      return
    fi
    index=$((index + 1))
  done
  printf '0'
}

next_theme() {
  local index
  index="$(theme_index)"
  index=$(((index + 1) % ${#themes[@]}))
  theme="${themes[$index]}"
}

desired_height_for() {
  local output="$1"
  local max_height=30
  local lines
  lines="$(printf '%s\n' "$output" | wc -l)"
  lines=$((lines + 1))

  if [[ -n "${TMUX_PANE:-}" ]]; then
    max_height="$(tmux display-message -pt "$TMUX_PANE" '#{window_height}' 2>/dev/null || printf '30')"
    max_height=$((max_height - 3))
    if [[ "$max_height" -lt 2 ]]; then
      max_height=2
    fi
  fi

  if [[ "$lines" -lt 2 ]]; then
    lines=2
  elif [[ "$lines" -gt "$max_height" ]]; then
    lines="$max_height"
  fi
  printf '%s' "$lines"
}

render_once() {
  local cache
  cache="$(active_cache_dir)"

  if [[ -n "$cache" && -d "$cache" ]]; then
    "$renderer" \
      --cache-dir "$cache" \
      --model "$model" \
      --interval "$interval" \
      --mode "$mode" \
      --theme "$theme" 2>&1 || true
    return
  fi

  placeholder_output
}

placeholder_output() {
  local error_text=""
  if [[ -s "$error_file" ]]; then
    error_text="  $(tail -n1 "$error_file")"
  fi

  case "$mode" in
    oneline)
      printf 'USAGE loading...  |  CHANNEL loading...  ↻%ss%s\n' "$interval" "$error_text"
      ;;
    lite)
      printf 'USAGE\nloading quota data...\n\nCHANNEL\nloading channel health...  ↻%ss%s\n' "$interval" "$error_text"
      ;;
    detail)
      printf 'USAGE DETAIL\n'
      printf '────────────────────────────────────────────────────────\n'
      printf 'loading quota data...\n'
      printf '────────────────────────────────────────────────────────\n'
      printf 'SERVICE STATUS\n'
      printf '────────────────────────────────────────────────────────\n'
      printf 'loading channel health...  ↻%ss%s\n' "$interval" "$error_text"
      ;;
    *)
      printf 'usage-monitor: unknown mode %s\n' "$mode"
      ;;
  esac
}

active_cache_dir() {
  if [[ -L "$active_link" ]]; then
    readlink -f "$active_link" 2>/dev/null || true
  fi
}

refresh_in_flight() {
  [[ -n "${refresh_pid:-}" ]] && kill -0 "$refresh_pid" 2>/dev/null
}

start_refresh() {
  local target

  if refresh_in_flight; then
    return
  fi

  target="$state_dir/fetch-$(date +%s)-$$-$RANDOM"
  (
    rm -rf "$target"
    mkdir -p "$target"
    if "$renderer" \
      --config "$config" \
      --model "$model" \
      --interval "$interval" \
      --fetch-to "$target" >"$state_dir/fetch.out" 2>"$state_dir/fetch.err"; then
      ln -sfn "$target" "$active_link"
      rm -f "$error_file"
    else
      {
        printf 'refresh failed'
        if [[ -s "$state_dir/fetch.err" ]]; then
          printf ': %s' "$(tail -n1 "$state_dir/fetch.err")"
        fi
        printf '\n'
      } >"$error_file"
      rm -rf "$target"
    fi
  ) &
  refresh_pid=$!
  next_refresh_at=$((SECONDS + interval))
}

check_refresh_complete() {
  if [[ -n "${refresh_pid:-}" ]] && ! kill -0 "$refresh_pid" 2>/dev/null; then
    wait "$refresh_pid" 2>/dev/null || true
    refresh_pid=""
    return 0
  fi
  return 1
}

maybe_start_refresh() {
  if [[ ! -L "$active_link" || "$SECONDS" -ge "$next_refresh_at" ]]; then
    start_refresh
  fi
}

read_key() {
  local timeout="${1:-0.2}"

  IFS= read -rsn1 -t "$timeout" key
}

drain_pending_keys() {
  local discarded=""

  while true; do
    IFS= read -rsn1 -t 0.01 discarded || break
  done
}

read_latest_key() {
  local latest

  if ! read_key 0.2; then
    return 1
  fi

  latest="$key"
  while read_key 0.01; do
    latest="$key"
    :
  done
  key="$latest"
  return 0
}

interval="$(numeric_or_default "$interval" 60)"
state_dir="$(mktemp -d "${TMPDIR:-/tmp}/usage-monitor-tmux.XXXXXX")"
active_link="$state_dir/current"
error_file="$state_dir/error"
refresh_pid=""
next_refresh_at=0

old_stty="$(stty -g 2>/dev/null || true)"
if [[ -n "$old_stty" ]]; then
  stty -icanon -echo min 1 time 0 2>/dev/null || true
fi

cleanup() {
  printf "\033[?25h"
  if [[ -n "${refresh_pid:-}" ]] && kill -0 "$refresh_pid" 2>/dev/null; then
    kill "$refresh_pid" 2>/dev/null || true
    wait "$refresh_pid" 2>/dev/null || true
  fi
  if [[ -n "${old_stty:-}" ]]; then
    stty "$old_stty" 2>/dev/null || true
  fi
  rm -rf "$state_dir"
}

trap cleanup EXIT

drain_pending_keys
start_refresh

while true; do
  maybe_start_refresh
  output="$(render_once)"
  if [[ -n "${TMUX_PANE:-}" ]]; then
    tmux resize-pane -t "$TMUX_PANE" -y "$(desired_height_for "$output")" 2>/dev/null || true
    tmux clear-history -t "$TMUX_PANE" 2>/dev/null || true
  fi
  printf '\033[?25l\033[H\033[2J\033[3J%s\n' "$output"

  key=""
  deadline=$((SECONDS + interval))
  while (( SECONDS < deadline )); do
    if read_latest_key; then
      break
    fi
    if check_refresh_complete; then
      break
    fi
  done

  if [[ -z "$key" && "$SECONDS" -ge "$deadline" ]]; then
    start_refresh
  fi

  case "$key" in
    1)
      mode="oneline"
      ;;
    2)
      mode="lite"
      ;;
    3)
      mode="detail"
      ;;
    c|C)
      next_theme
      ;;
  esac
done
