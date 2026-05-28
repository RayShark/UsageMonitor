#!/usr/bin/env bash
set -euo pipefail

usage_json_files=()
status_json=""
model="gpt-5.5"
interval="60"
config_path="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
status_endpoint=""

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
    --no-color)
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

progress_bar() {
  awk -v used="$1" -v limit="$2" 'BEGIN {
    width = 18
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
    printf '·'
  elif [[ "$ok" != "true" ]]; then
    printf '●'
  elif [[ "$latency" == "null" || -z "$latency" ]]; then
    printf '·'
  elif [[ "$latency" -ge 3000 ]]; then
    printf '◐'
  else
    printf '○'
  fi
}

fetch_usage_from_config() {
  local output_dir="$1"

  require_command curl
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
    local api_key base_url
    api_key="$(jq -r '.apiKey // empty' <<<"$key_payload")"
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

    if ! curl -fsS --max-time 20 -H "Authorization: Bearer $api_key" "${base_url%/}/v1/usage" >"$output_dir/usage-$index.json"; then
      printf 'usage-monitor: usage request failed\n'
      exit 0
    fi
    index=$((index + 1))
  done

  if [[ "$index" -eq 0 ]]; then
    printf 'usage-monitor: no usable keys configured\n'
    exit 0
  fi
}

fetch_status_from_config() {
  local output_file="$1"

  require_command curl

  local endpoint="$status_endpoint"
  if [[ -z "$endpoint" && -f "$config_path" ]]; then
    endpoint="$(jq -r '.statusEndpoint // empty' "$config_path")"
  fi
  if [[ -z "$endpoint" || "$endpoint" == "null" ]]; then
    endpoint="https://status.input.im/api/status"
  fi

  if ! curl -fsS --max-time 20 "$endpoint" >"$output_file"; then
    printf 'usage-monitor: status request failed\n'
    exit 0
  fi
}

require_command jq

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ "${#usage_json_files[@]}" -eq 0 ]]; then
  fetch_usage_from_config "$tmp_dir"
else
  index=0
  for file in "${usage_json_files[@]}"; do
    cp "$file" "$tmp_dir/usage-$index.json"
    index=$((index + 1))
  done
fi

if [[ -z "$status_json" ]]; then
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
  jq --arg model "$model" '
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
        ($target.history // [])[-5:]
        | map({
            ok: (if has("ok") then .ok else null end),
            latency: (.latency_ms // null)
          })
      )
    }
  ' "$tmp_dir/status.json"
)"

cells="$(
  jq -c '.cells[]?' <<<"$status_summary" | while read -r cell; do
    ok="$(jq -r '.ok' <<<"$cell")"
    latency="$(jq -r '.latency' <<<"$cell")"
    cell_symbol "$ok" "$latency"
  done
)"

printf '总额度 %s %s %s/%s 余额 %s 渠道 %s/%s OK %s %s %s ↻%ss\n' \
  "$(progress_bar "$used" "$limit")" \
  "$(percent "$used" "$limit")" \
  "$(money "$used")" \
  "$(money "$limit")" \
  "$(money "$remaining")" \
  "$(jq -r '.ok' <<<"$status_summary")" \
  "$(jq -r '.total' <<<"$status_summary")" \
  "$(jq -r '.model' <<<"$status_summary")" \
  "$cells" \
  "$(latency_text "$(jq -r '.latency' <<<"$status_summary")")" \
  "$interval"
