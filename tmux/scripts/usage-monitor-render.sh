#!/usr/bin/env bash
set -euo pipefail

usage_json_files=()
status_json=""
model="gpt-5.5"
interval="60"
config_path="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
status_endpoint=""
cache_dir=""
fetch_to=""
mode="oneline"
theme="${USAGE_MONITOR_TMUX_THEME:-classic}"
color_enabled=1
progress_width=10
status_cell_count=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --usage-json)
      usage_json_files+=("$2")
      shift 2
      ;;
    --status-json)
      status_json="$2"
      shift 2
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    --interval)
      interval="$2"
      shift 2
      ;;
    --config)
      config_path="$2"
      shift 2
      ;;
    --status-endpoint)
      status_endpoint="$2"
      shift 2
      ;;
    --cache-dir)
      cache_dir="$2"
      shift 2
      ;;
    --fetch-to)
      fetch_to="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --theme)
      theme="$2"
      shift 2
      ;;
    --no-color)
      color_enabled=0
      shift
      ;;
    *)
      printf 'usage-monitor: unknown option %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'usage-monitor: missing %s\n' "$1"
    exit 0
  fi
}

resolve_curl() {
  if [[ -n "${USAGE_MONITOR_CURL_BIN:-}" ]]; then
    printf '%s' "$USAGE_MONITOR_CURL_BIN"
    return
  fi
  if [[ -x /usr/bin/curl ]]; then
    printf '%s' /usr/bin/curl
    return
  fi
  command -v curl 2>/dev/null || true
}

curl_json() {
  local output_file="$1"
  shift

  local curl_bin
  curl_bin="$(resolve_curl)"
  if [[ -z "$curl_bin" || ! -x "$curl_bin" ]]; then
    printf 'usage-monitor: missing curl\n'
    exit 0
  fi

  "$curl_bin" \
    --http1.1 \
    --retry 2 \
    --retry-all-errors \
    --retry-delay 1 \
    -fsS \
    --connect-timeout 10 \
    --max-time 20 \
    "$@" >"$output_file"
}

money() {
  awk -v value="$1" 'BEGIN { printf "$%.2f", value }'
}

percent() {
  awk -v used="$1" -v limit="$2" 'BEGIN {
    if (limit <= 0) {
      printf "不限量"
    } else {
      printf "%.1f%%", used / limit * 100
    }
  }'
}

ansi_code() {
  local kind="$1"

  case "$theme:$kind" in
    mono:*) printf '0' ;;
    dracula:green) printf '38;5;84' ;;
    dracula:yellow) printf '38;5;228' ;;
    dracula:red) printf '38;5;203' ;;
    dracula:gray) printf '38;5;245' ;;
    dracula:bar) printf '38;5;141' ;;
    catppuccin:green) printf '38;5;108' ;;
    catppuccin:yellow) printf '38;5;222' ;;
    catppuccin:red) printf '38;5;210' ;;
    catppuccin:gray) printf '38;5;245' ;;
    catppuccin:bar) printf '38;5;109' ;;
    tokyonight:green) printf '38;5;114' ;;
    tokyonight:yellow) printf '38;5;221' ;;
    tokyonight:red) printf '38;5;203' ;;
    tokyonight:gray) printf '38;5;244' ;;
    tokyonight:bar) printf '38;5;111' ;;
    nord:green) printf '38;5;109' ;;
    nord:yellow) printf '38;5;222' ;;
    nord:red) printf '38;5;203' ;;
    nord:gray) printf '38;5;245' ;;
    nord:bar) printf '38;5;110' ;;
    gruvbox:green) printf '38;5;142' ;;
    gruvbox:yellow) printf '38;5;214' ;;
    gruvbox:red) printf '38;5;167' ;;
    gruvbox:gray) printf '38;5;245' ;;
    gruvbox:bar) printf '38;5;208' ;;
    *:green) printf '32' ;;
    *:yellow) printf '33' ;;
    *:red) printf '31' ;;
    *:gray) printf '90' ;;
    *:bar) printf '36' ;;
  esac
}

color_text() {
  local kind="$1"
  local text="$2"

  if [[ "$color_enabled" -eq 0 || "$theme" == "mono" ]]; then
    printf '%s' "$text"
    return
  fi

  printf '\033[%sm%s\033[0m' "$(ansi_code "$kind")" "$text"
}

usage_kind() {
  awk -v used="$1" -v limit="$2" 'BEGIN {
    if (limit <= 0) {
      printf "bar"
    } else if (used / limit >= 0.95) {
      printf "red"
    } else if (used / limit >= 0.80) {
      printf "yellow"
    } else {
      printf "green"
    }
  }'
}

raw_progress_bar() {
  awk -v used="$1" -v limit="$2" -v width="$progress_width" 'BEGIN {
    filled = 0
    if (limit > 0) {
      filled = int(used / limit * width + 0.5)
      if (filled < 0) filled = 0
      if (filled > width) filled = width
    }
    printf "["
    for (i = 0; i < filled; i++) printf "█"
    for (i = filled; i < width; i++) printf "░"
    printf "]"
  }'
}

progress_bar() {
  local raw
  raw="$(raw_progress_bar "$1" "$2")"
  color_text "$(usage_kind "$1" "$2")" "$raw"
}

fit_label() {
  local value="$1"
  local width="$2"

  awk -v value="$value" -v width="$width" 'BEGIN {
    if (length(value) > width) {
      printf "%s~", substr(value, 1, width - 1)
    } else {
      printf "%s", value
    }
  }'
}

quota_header() {
  printf '%-13s  %-12s  %6s  %8s  %8s  %8s' \
    "NAME" "BAR" "USE%" "USED" "LIMIT" "LEFT"
}

quota_row() {
  local label="$1"
  local used_value="$2"
  local limit_value="$3"
  local remaining_value="$4"

  label="$(fit_label "$label" 13)"

  printf '%-13s  %s  %6s  %8s  %8s  %8s' \
    "$label" \
    "$(progress_bar "$used_value" "$limit_value")" \
    "$(percent "$used_value" "$limit_value")" \
    "$(money "$used_value")" \
    "$(money "$limit_value")" \
    "$(money "$remaining_value")"
}

separator_line() {
  printf '────────────────────────────────────────────────────────'
}

latency_text() {
  local latency="$1"
  if [[ "$latency" == "null" || -z "$latency" ]]; then
    printf '首T --'
    return
  fi
  awk -v ms="$latency" 'BEGIN { printf "首T %.1fs", ms / 1000 }'
}

cell_symbol() {
  local ok="$1"
  local latency="$2"

  if [[ "$ok" == "null" ]]; then
    color_text gray '·'
  elif [[ "$ok" != "true" ]]; then
    color_text red '●'
  elif [[ "$latency" == "null" || -z "$latency" ]]; then
    color_text gray '·'
  elif [[ "$latency" -ge 3000 ]]; then
    color_text yellow '◐'
  else
    color_text green '○'
  fi
}

fetch_usage_from_config() {
  local output_dir="$1"

  if [[ ! -f "$config_path" ]]; then
    printf 'usage-monitor: config not found %s\n' "$config_path"
    exit 0
  fi

  local default_base
  default_base="$(jq -r '.defaultBaseURL // empty' "$config_path")"
  mapfile -t key_payloads < <(jq -c '.keys[]?' "$config_path")

  if [[ "${#key_payloads[@]}" -eq 0 ]]; then
    printf 'usage-monitor: no keys configured\n'
    exit 0
  fi

  local index=0
  for key_payload in "${key_payloads[@]}"; do
    local api_key base_url key_name
    api_key="$(jq -r '.apiKey // empty' <<<"$key_payload")"
    key_name="$(jq -r '.name // .id // "Key"' <<<"$key_payload")"
    base_url="$(
      jq -r --arg default "$default_base" '
        (.baseURL // "") as $base |
        (.baseURLOverride // "") as $override |
        if $base != "" then
          $base
        elif $override != "" then
          $override
        else
          $default
        end
      ' <<<"$key_payload"
    )"

    if [[ -z "$api_key" || -z "$base_url" || "$base_url" == "null" ]]; then
      continue
    fi

    if ! curl_json "$output_dir/usage-$index.json" -H "Authorization: Bearer $api_key" "${base_url%/}/v1/usage"; then
      printf 'usage-monitor: usage request failed\n'
      exit 0
    fi
    printf '%s\t%s\n' "$output_dir/usage-$index.json" "$key_name" >>"$output_dir/usage-meta.tsv"
    index=$((index + 1))
  done

  if [[ "$index" -eq 0 ]]; then
    printf 'usage-monitor: no usable keys configured\n'
    exit 0
  fi
}

fetch_status_from_config() {
  local output_file="$1"

  local endpoint="$status_endpoint"
  if [[ -z "$endpoint" && -f "$config_path" ]]; then
    endpoint="$(jq -r '.statusEndpoint // empty' "$config_path")"
  fi
  if [[ -z "$endpoint" || "$endpoint" == "null" ]]; then
    endpoint="https://status.input.im/api/status"
  fi

  if ! curl_json "$output_file" "$endpoint"; then
    printf 'usage-monitor: status request failed\n'
    exit 0
  fi
}

require_command jq

cleanup_tmp=1
if [[ -n "$fetch_to" ]]; then
  mkdir -p "$fetch_to"
  rm -f "$fetch_to"/usage-*.json "$fetch_to/usage-meta.tsv" "$fetch_to/status.json"
  tmp_dir="$fetch_to"
  cleanup_tmp=0
elif [[ -n "$cache_dir" ]]; then
  tmp_dir="$cache_dir"
  cleanup_tmp=0
else
  tmp_dir="$(mktemp -d)"
fi

if [[ "$cleanup_tmp" -eq 1 ]]; then
  trap 'rm -rf "$tmp_dir"' EXIT
fi

if [[ -n "$fetch_to" ]]; then
  fetch_usage_from_config "$tmp_dir"
  fetch_status_from_config "$tmp_dir/status.json"
  exit 0
fi

if [[ -n "$cache_dir" ]]; then
  if [[ ! -f "$tmp_dir/status.json" || ! -f "$tmp_dir/usage-meta.tsv" ]]; then
    printf 'usage-monitor: cache not ready\n'
    exit 0
  fi
elif [[ "${#usage_json_files[@]}" -eq 0 ]]; then
  fetch_usage_from_config "$tmp_dir"
else
  index=0
  for file in "${usage_json_files[@]}"; do
    cp "$file" "$tmp_dir/usage-$index.json"
    name="$(basename "$file" .json)"
    printf '%s\t%s\n' "$tmp_dir/usage-$index.json" "$name" >>"$tmp_dir/usage-meta.tsv"
    index=$((index + 1))
  done
fi

if [[ -n "$cache_dir" ]]; then
  :
elif [[ -z "$status_json" ]]; then
  fetch_status_from_config "$tmp_dir/status.json"
else
  cp "$status_json" "$tmp_dir/status.json"
fi

mapfile -t usage_files < <(find "$tmp_dir" -maxdepth 1 -name 'usage-*.json' | sort)
if [[ "${#usage_files[@]}" -eq 0 ]]; then
  printf 'usage-monitor: no usage data\n'
  exit 0
fi

usage_summary="$(
  jq -s '
    {
      used: (map(.subscription.daily_usage_usd // 0) | add // 0),
      limit: (map(.subscription.daily_limit_usd // 0) | add // 0),
      remaining: (map(.remaining // 0) | add // 0)
    }
  ' "${usage_files[@]}"
)"

used="$(jq -r '.used' <<<"$usage_summary")"
limit="$(jq -r '.limit' <<<"$usage_summary")"
remaining="$(jq -r '.remaining' <<<"$usage_summary")"

status_summary="$(
  jq --arg model "$model" --argjson count "$status_cell_count" '
    .services as $services |
    ($services | length) as $total |
    (
      $services
      | map(select((.last.ok // false) == true and (.last.latency_ms != null)))
      | length
    ) as $ok |
    (($services | map(select(.model == $model)) | first) // ($services[0] // {})) as $target |
    {
      ok: $ok,
      total: $total,
      model: ($target.model // $model),
      latency: ($target.last.latency_ms // null),
      cells: (
        ($target.history // [])[-$count:]
        | ([range(0; ($count - length)) | { ok: null, latency: null }] + map({
            ok: (if has("ok") then .ok else null end),
            latency: (.latency_ms // null)
          }))
      )
    }
  ' "$tmp_dir/status.json"
)"

render_cells() {
  jq -c '.cells[]?' <<<"$status_summary" | while read -r cell; do
    ok="$(jq -r '.ok' <<<"$cell")"
    latency="$(jq -r '.latency' <<<"$cell")"
    cell_symbol "$ok" "$latency"
  done
}

channel_state() {
  local ok="$1"
  local total="$2"

  if [[ "$total" == "0" ]]; then
    printf 'NO DATA'
  elif [[ "$ok" == "$total" ]]; then
    printf 'OK'
  else
    printf 'WARN'
  fi
}

channel_line() {
  local ok
  local total

  ok="$(jq -r '.ok' <<<"$status_summary")"
  total="$(jq -r '.total' <<<"$status_summary")"

  printf '%s/%s %s  %s  %s  %s' \
    "$ok" \
    "$total" \
    "$(channel_state "$ok" "$total")" \
    "$(jq -r '.model' <<<"$status_summary")" \
    "$(render_cells)" \
    "$(latency_text "$(jq -r '.latency' <<<"$status_summary")")"
}

oneline_health_text() {
  printf 'CHANNEL %s' "$(channel_line)"
}

usage_lines() {
  while IFS=$'\t' read -r file name; do
    [[ -n "$file" ]] || continue
    row_used="$(jq -r '.subscription.daily_usage_usd // 0' "$file")"
    row_limit="$(jq -r '.subscription.daily_limit_usd // 0' "$file")"
    row_remaining="$(jq -r '.remaining // 0' "$file")"
    quota_row "$name" "$row_used" "$row_limit" "$row_remaining"
    printf '\n'
  done <"$tmp_dir/usage-meta.tsv"
}

detail_usage_lines() {
  while IFS=$'\t' read -r file name; do
    [[ -n "$file" ]] || continue
    row_used="$(jq -r '.subscription.daily_usage_usd // 0' "$file")"
    row_limit="$(jq -r '.subscription.daily_limit_usd // 0' "$file")"
    row_remaining="$(jq -r '.remaining // 0' "$file")"
    plan="$(jq -r '.plan_name // .planName // "--"' "$file")"
    weekly="$(jq -r '.subscription.weekly_usage_usd // 0' "$file")"
    weekly_limit="$(jq -r '.subscription.weekly_limit_usd // 0' "$file")"
    monthly="$(jq -r '.subscription.monthly_usage_usd // 0' "$file")"
    monthly_limit="$(jq -r '.subscription.monthly_limit_usd // 0' "$file")"
    quota_row "$name" "$row_used" "$row_limit" "$row_remaining"
    printf '\n'
    printf '  plan %s\n' "$plan"
    printf '        week %s/%s  month %s/%s\n' \
      "$(money "$weekly")" \
      "$(money "$weekly_limit")" \
      "$(money "$monthly")" \
      "$(money "$monthly_limit")"
  done <"$tmp_dir/usage-meta.tsv"
}

service_detail_lines() {
  jq -r '
    .services[]? |
    [
      (.model // "--"),
      (if ((.last.ok // false) == false) then "DOWN" elif ((.last.latency_ms // 0) >= 3000) then "SLOW" else "OK" end),
      (.last.latency_ms // null),
      (.uptime_pct // null)
    ] | @tsv
  ' "$tmp_dir/status.json" | while IFS=$'\t' read -r service_model status latency uptime; do
    uptime_text="--"
    if [[ "$uptime" != "null" && -n "$uptime" ]]; then
      uptime_text="$(awk -v value="$uptime" 'BEGIN { printf "%.2f%%", value }')"
    fi
    printf '%-12s  %-6s  %-8s  %7s\n' \
      "$(fit_label "$service_model" 12)" \
      "$status" \
      "$(latency_text "$latency")" \
      "$uptime_text"
  done
}

case "$mode" in
  oneline)
    printf 'USAGE %s  %6s  %s/%s  left %s  |  %s  ↻%ss\n' \
      "$(progress_bar "$used" "$limit")" \
      "$(percent "$used" "$limit")" \
      "$(money "$used")" \
      "$(money "$limit")" \
      "$(money "$remaining")" \
      "$(oneline_health_text)" \
      "$interval"
    ;;
  lite)
    printf 'USAGE\n'
    quota_header
    printf '\n'
    quota_row "Total" "$used" "$limit" "$remaining"
    printf '\n'
    usage_lines
    printf '\nCHANNEL\n'
    channel_line
    printf '  ↻%ss' "$interval"
    printf '\n'
    ;;
  detail)
    printf 'USAGE DETAIL\n'
    separator_line
    printf '\n'
    quota_header
    printf '\n'
    quota_row "Total" "$used" "$limit" "$remaining"
    printf '\n'
    detail_usage_lines
    separator_line
    printf '\nSERVICE STATUS\n'
    separator_line
    printf '\n'
    printf '%-12s  %-6s  %-8s  %7s\n' "MODEL" "STATE" "LATENCY" "UPTIME"
    service_detail_lines
    separator_line
    printf '\n'
    printf 'SUMMARY       %s  ↻%ss' "$(channel_line)" "$interval"
    printf '\n'
    ;;
  *)
    printf 'usage-monitor: unknown mode %s\n' "$mode"
    ;;
esac
