# tmux Usage Monitor Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a TPM-style tmux plugin that shows UsageMonitor balance and channel health without requiring Swift at runtime.

**Architecture:** The plugin is a tmux-native shell integration. `usage-monitor.tmux` reads tmux options and binds keys, `scripts/usage-monitor-pane.sh` owns pane lifecycle, and `scripts/usage-monitor-render.sh` fetches `/v1/usage` plus `https://status.input.im/api/status` with `curl` and parses JSON with `jq`. The Swift app and CLI remain reference implementations but are not required by the plugin.

**Tech Stack:** tmux, POSIX-compatible shell with bash allowed for test scripts, curl, jq, fixture-based shell tests, existing UsageMonitor docs.

---

## Scope

This plan creates a reusable TPM-style plugin inside this repository first. A later extraction to a standalone `tmux-usage-monitor` repository can copy the `tmux/` directory and docs unchanged.

The plugin must not add a `bat` command alias. The user confirmed `bat` was a typo; public documentation should use `bar` only when referring to the existing Swift CLI.

Runtime requirements:

- `tmux`
- `curl`
- `jq`
- a config file at `~/.config/tmux-usage-monitor/config.json` or an explicit config path through `@usage_monitor_config`

Runtime non-requirements:

- no Swift toolchain
- no `usage-monitor` binary
- no Python or Node.js

## File Structure

- Create `tmux/usage-monitor.tmux`: TPM entrypoint sourced by tmux. Defines default options and key bindings.
- Create `tmux/scripts/usage-monitor-pane.sh`: Creates, reuses, or closes the monitor pane.
- Create `tmux/scripts/usage-monitor-render.sh`: Validates dependencies, loads config, fetches usage/status JSON, and prints one compact line.
- Create `tmux/tests/fixtures/usage-main.json`: Stable usage response fixture.
- Create `tmux/tests/fixtures/usage-backup.json`: Second usage response fixture for aggregate totals.
- Create `tmux/tests/fixtures/status.json`: Stable service-status response fixture.
- Create `tmux/tests/render_oneline_test.sh`: Shell test for rendering with fixtures.
- Create `docs/tmux-plugin.md`: User-facing TPM installation, config, options, and troubleshooting docs.
- Modify `docs/linux-cli.md`: Link from the current tmux pane recipe to the new plugin docs.
- Modify `README.md` and `README.zh-CN.md`: Mention the tmux plugin as a shell-native option separate from the Swift CLI.

## Config Contract

The plugin reads this JSON shape:

```json
{
  "defaultBaseURL": "https://example.com",
  "refreshIntervalSeconds": 60,
  "statusEndpoint": "https://status.input.im/api/status",
  "model": "gpt-5.5",
  "keys": [
    {
      "id": "main",
      "name": "Main",
      "apiKey": "sk-test-main",
      "baseURL": "https://example.com"
    },
    {
      "id": "backup",
      "name": "Backup",
      "apiKey": "sk-test-backup"
    }
  ]
}
```

`baseURL` on a key overrides `defaultBaseURL`. API keys stay in this file, not in `.tmux.conf`. Documentation must tell users to set file permissions with:

```bash
chmod 600 ~/.config/tmux-usage-monitor/config.json
```

## Task 1: Add Renderer Test Fixtures

**Files:**
- Create: `tmux/tests/fixtures/usage-main.json`
- Create: `tmux/tests/fixtures/usage-backup.json`
- Create: `tmux/tests/fixtures/status.json`

- [ ] **Step 1: Create `usage-main.json` fixture**

```json
{
  "isValid": true,
  "mode": "normal",
  "model_stats": [],
  "plan_name": "Pro",
  "remaining": 53.67,
  "subscription": {
    "daily_usage_usd": 246.33,
    "daily_limit_usd": 300,
    "weekly_usage_usd": 620.12,
    "weekly_limit_usd": 2100,
    "monthly_usage_usd": 1880.22,
    "monthly_limit_usd": 9000,
    "expires_at": "2027-05-18T00:00:00Z"
  },
  "unit": "USD",
  "usage": {
    "today": {
      "request_count": 42,
      "input_tokens": 1200,
      "output_tokens": 900,
      "total_tokens": 2100,
      "input_cost_usd": 1.23,
      "output_cost_usd": 2.01,
      "total_cost_usd": 3.24
    },
    "total": {
      "request_count": 420,
      "input_tokens": 12000,
      "output_tokens": 9000,
      "total_tokens": 21000,
      "input_cost_usd": 12.3,
      "output_cost_usd": 20.1,
      "total_cost_usd": 32.4
    },
    "average_duration_ms": 1200,
    "rpm": 0.7,
    "tpm": 35
  }
}
```

- [ ] **Step 2: Create `usage-backup.json` fixture**

```json
{
  "isValid": true,
  "mode": "normal",
  "model_stats": [],
  "plan_name": "Team",
  "remaining": 74.11,
  "subscription": {
    "daily_usage_usd": 425.89,
    "daily_limit_usd": 500,
    "weekly_usage_usd": 980.4,
    "weekly_limit_usd": 3500,
    "monthly_usage_usd": 2880.22,
    "monthly_limit_usd": 15000,
    "expires_at": "2027-05-18T00:00:00Z"
  },
  "unit": "USD",
  "usage": {
    "today": {
      "request_count": 88,
      "input_tokens": 2200,
      "output_tokens": 1900,
      "total_tokens": 4100,
      "input_cost_usd": 2.23,
      "output_cost_usd": 3.01,
      "total_cost_usd": 5.24
    },
    "total": {
      "request_count": 880,
      "input_tokens": 22000,
      "output_tokens": 19000,
      "total_tokens": 41000,
      "input_cost_usd": 22.3,
      "output_cost_usd": 30.1,
      "total_cost_usd": 52.4
    },
    "average_duration_ms": 900,
    "rpm": 1.2,
    "tpm": 68
  }
}
```

- [ ] **Step 3: Create `status.json` fixture**

```json
{
  "all_ok": true,
  "generated_at": 1780000000,
  "services": [
    {
      "model": "gpt-5.5",
      "uptime_pct": 100,
      "last": {
        "ts": 1780000000,
        "ok": true,
        "latency_ms": 2300,
        "error": null
      },
      "history": [
        { "ts": 1779999700, "ok": true, "latency_ms": 1200, "error": null },
        { "ts": 1779999760, "ok": true, "latency_ms": 3200, "error": null },
        { "ts": 1779999820, "ok": true, "latency_ms": 2100, "error": null },
        { "ts": 1779999880, "ok": false, "latency_ms": null, "error": "timeout" },
        { "ts": 1779999940, "ok": true, "latency_ms": 2300, "error": null }
      ]
    },
    {
      "model": "gpt-5.4",
      "uptime_pct": 98,
      "last": {
        "ts": 1780000000,
        "ok": true,
        "latency_ms": 4200,
        "error": null
      },
      "history": []
    }
  ]
}
```

- [ ] **Step 4: Commit fixtures**

```bash
git add tmux/tests/fixtures/usage-main.json tmux/tests/fixtures/usage-backup.json tmux/tests/fixtures/status.json
git commit -m "test: add tmux usage monitor fixtures"
```

## Task 2: Add Failing Renderer Test

**Files:**
- Create: `tmux/tests/render_oneline_test.sh`
- Depends on future implementation: `tmux/scripts/usage-monitor-render.sh`

- [ ] **Step 1: Write the failing shell test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RENDER="$ROOT_DIR/tmux/scripts/usage-monitor-render.sh"

output="$(
  "$RENDER" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-main.json" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-backup.json" \
    --status-json "$ROOT_DIR/tmux/tests/fixtures/status.json" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"

expected="总额度 [███████████████░░░] 84.0% $672.22/$800.00 余额 $127.78 渠道 2/2 OK gpt-5.5 ○◐○●○ 首T 2.3s ↻60s"

if [[ "$output" != "$expected" ]]; then
  printf 'not ok render oneline\n' >&2
  printf 'expected: %s\n' "$expected" >&2
  printf 'actual:   %s\n' "$output" >&2
  exit 1
fi

printf 'ok render oneline\n'
```

- [ ] **Step 2: Make the test executable**

```bash
chmod +x tmux/tests/render_oneline_test.sh
```

- [ ] **Step 3: Run the test and verify it fails before implementation**

Run:

```bash
bash tmux/tests/render_oneline_test.sh
```

Expected:

```text
tmux/scripts/usage-monitor-render.sh: No such file or directory
```

- [ ] **Step 4: Commit failing test**

```bash
git add tmux/tests/render_oneline_test.sh
git commit -m "test: cover tmux oneline renderer"
```

## Task 3: Implement Shell Renderer

**Files:**
- Create: `tmux/scripts/usage-monitor-render.sh`
- Test: `tmux/tests/render_oneline_test.sh`

- [ ] **Step 1: Create renderer script**

```bash
#!/usr/bin/env bash
set -euo pipefail

usage_json_files=()
status_json=""
model="gpt-5.5"
interval="60"
color="1"
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
      color="0"
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

require_command jq

money() {
  jq -nr --argjson value "$1" '"$" + ($value | tostring | split(".") as $parts | if ($parts | length) == 1 then $parts[0] + ".00" else $parts[0] + "." + (($parts[1] + "00")[:2]) end)'
}

percent() {
  jq -nr --argjson used "$1" --argjson limit "$2" 'if $limit <= 0 then "--" else (($used / $limit * 1000 | round) / 10 | tostring) + "%" end'
}

bar() {
  jq -nr --argjson used "$1" --argjson limit "$2" '
    18 as $width |
    (if $limit <= 0 then 0 else (($used / $limit) * $width | floor) end) as $filled |
    "[" + ("█" * $filled) + ("░" * ($width - $filled)) + "]"
  '
}

latency_text() {
  local latency="$1"
  if [[ "$latency" == "null" || -z "$latency" ]]; then
    printf '首T --'
    return
  fi
  jq -nr --argjson ms "$latency" '"首T " + (($ms / 1000 * 10 | round) / 10 | tostring) + "s"'
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

read_usage_from_config() {
  require_command curl
  [[ -f "$config_path" ]] || {
    printf 'usage-monitor: config not found %s\n' "$config_path"
    exit 0
  }

  local default_base
  default_base="$(jq -r '.defaultBaseURL // empty' "$config_path")"
  mapfile -t key_payloads < <(jq -c '.keys[]?' "$config_path")
  for key_payload in "${key_payloads[@]}"; do
    local api_key base_url
    api_key="$(jq -r '.apiKey // empty' <<<"$key_payload")"
    base_url="$(jq -r --arg default "$default_base" '.baseURL // $default' <<<"$key_payload")"
    [[ -n "$api_key" && -n "$base_url" ]] || continue
    curl -fsS --max-time 20 -H "Authorization: Bearer $api_key" "${base_url%/}/v1/usage"
    printf '\n'
  done
}

read_status_from_config() {
  require_command curl
  local endpoint="$status_endpoint"
  if [[ -z "$endpoint" && -f "$config_path" ]]; then
    endpoint="$(jq -r '.statusEndpoint // empty' "$config_path")"
  fi
  [[ -n "$endpoint" ]] || endpoint="https://status.input.im/api/status"
  curl -fsS --max-time 20 "$endpoint"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ "${#usage_json_files[@]}" -eq 0 ]]; then
  read_usage_from_config >"$tmp_dir/usage-stream.jsonl"
else
  : >"$tmp_dir/usage-stream.jsonl"
  for file in "${usage_json_files[@]}"; do
    cat "$file" >>"$tmp_dir/usage-stream.jsonl"
    printf '\n' >>"$tmp_dir/usage-stream.jsonl"
  done
fi

if [[ -z "$status_json" ]]; then
  read_status_from_config >"$tmp_dir/status.json"
else
  cp "$status_json" "$tmp_dir/status.json"
fi

usage_summary="$(
  jq -s '
    {
      used: (map(.subscription.daily_usage_usd // 0) | add // 0),
      limit: (map(.subscription.daily_limit_usd // 0) | add // 0),
      remaining: (map(.remaining // 0) | add // 0)
    }
  ' "$tmp_dir/usage-stream.jsonl"
)"

used="$(jq -r '.used' <<<"$usage_summary")"
limit="$(jq -r '.limit' <<<"$usage_summary")"
remaining="$(jq -r '.remaining' <<<"$usage_summary")"

status_summary="$(
  jq --arg model "$model" '
    .services as $services |
    ($services | length) as $total |
    ($services | map(select((.last.ok // false) == true)) | length) as $ok |
    (($services | map(select(.model == $model)) | first) // ($services[0] // {})) as $target |
    {
      ok: $ok,
      total: $total,
      model: ($target.model // $model),
      latency: ($target.last.latency_ms // null),
      cells: (($target.history // [])[-5:] | map({ ok: (.ok // null), latency: (.latency_ms // null) }))
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
  "$(bar "$used" "$limit")" \
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
```

- [ ] **Step 2: Make renderer executable**

```bash
chmod +x tmux/scripts/usage-monitor-render.sh
```

- [ ] **Step 3: Run syntax check**

Run:

```bash
bash -n tmux/scripts/usage-monitor-render.sh
```

Expected: no output and exit code 0.

- [ ] **Step 4: Run renderer test**

Run:

```bash
bash tmux/tests/render_oneline_test.sh
```

Expected:

```text
ok render oneline
```

- [ ] **Step 5: Commit renderer**

```bash
git add tmux/scripts/usage-monitor-render.sh tmux/tests/render_oneline_test.sh
git commit -m "feat: add shell renderer for tmux usage monitor"
```

## Task 4: Add tmux Pane Lifecycle Script

**Files:**
- Create: `tmux/scripts/usage-monitor-pane.sh`

- [ ] **Step 1: Create pane script**

```bash
#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
renderer="$plugin_dir/scripts/usage-monitor-render.sh"

height="${USAGE_MONITOR_TMUX_HEIGHT:-2}"
interval="${USAGE_MONITOR_TMUX_INTERVAL:-60}"
model="${USAGE_MONITOR_TMUX_MODEL:-gpt-5.5}"
config="${USAGE_MONITOR_TMUX_CONFIG:-$HOME/.config/tmux-usage-monitor/config.json}"
title="usage-monitor"

current_pane="$(tmux display-message -p '#{pane_id}')"
existing_pane="$(
  tmux list-panes -a -F '#{pane_id} #{pane_title}' |
    awk -v title="$title" '$2 == title { print $1; exit }'
)"

if [[ -n "$existing_pane" ]]; then
  tmux kill-pane -t "$existing_pane"
  exit 0
fi

command="while :; do \"$renderer\" --config \"$config\" --model \"$model\" --interval \"$interval\" --no-color; sleep \"$interval\"; done"

tmux split-window -v -l "$height" -t "$current_pane" "bash -lc '$command'"
tmux select-pane -T "$title"
tmux select-pane -t "$current_pane"
```

- [ ] **Step 2: Make pane script executable**

```bash
chmod +x tmux/scripts/usage-monitor-pane.sh
```

- [ ] **Step 3: Run syntax check**

Run:

```bash
bash -n tmux/scripts/usage-monitor-pane.sh
```

Expected: no output and exit code 0.

- [ ] **Step 4: Commit pane lifecycle script**

```bash
git add tmux/scripts/usage-monitor-pane.sh
git commit -m "feat: add tmux usage monitor pane toggle"
```

## Task 5: Add TPM Entrypoint

**Files:**
- Create: `tmux/usage-monitor.tmux`

- [ ] **Step 1: Create TPM entrypoint**

```tmux
# usage-monitor.tmux

set -gq @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
set -gq @usage_monitor_interval "60"
set -gq @usage_monitor_height "2"
set -gq @usage_monitor_model "gpt-5.5"
set -gq @usage_monitor_key "u"

run-shell -b 'tmux bind-key "$(tmux show-option -gqv @usage_monitor_key)" run-shell -b "USAGE_MONITOR_TMUX_CONFIG=\"$(tmux show-option -gqv @usage_monitor_config)\" USAGE_MONITOR_TMUX_INTERVAL=\"$(tmux show-option -gqv @usage_monitor_interval)\" USAGE_MONITOR_TMUX_HEIGHT=\"$(tmux show-option -gqv @usage_monitor_height)\" USAGE_MONITOR_TMUX_MODEL=\"$(tmux show-option -gqv @usage_monitor_model)\" \"#{d:current_file}/scripts/usage-monitor-pane.sh\""' 
```

- [ ] **Step 2: Run entrypoint in a live tmux server**

Run:

```bash
tmux run-shell "$PWD/tmux/usage-monitor.tmux"
```

Expected: no output and exit code 0.

- [ ] **Step 3: Verify binding exists**

Run:

```bash
tmux list-keys | rg 'usage-monitor-pane|@usage_monitor_key|run-shell'
```

Expected output contains `usage-monitor-pane.sh`.

- [ ] **Step 4: Commit TPM entrypoint**

```bash
git add tmux/usage-monitor.tmux
git commit -m "feat: add TPM entrypoint for usage monitor"
```

## Task 6: Add Local tmux Smoke Test

**Files:**
- No repository file changes required for the manual smoke test.

- [ ] **Step 1: Create local config with current credentials outside git**

Create `~/.config/tmux-usage-monitor/config.json` using the current machine's real Base URL and API keys. Do not commit this file.

Run:

```bash
chmod 600 ~/.config/tmux-usage-monitor/config.json
```

Expected: no output and exit code 0.

- [ ] **Step 2: Run one-shot render against live endpoints**

Run:

```bash
tmux/scripts/usage-monitor-render.sh --config ~/.config/tmux-usage-monitor/config.json --model gpt-5.5 --interval 60 --no-color
```

Expected output shape:

```text
总额度 [████...░░] NN.N% $N.NN/$N.NN 余额 $N.NN 渠道 N/N OK gpt-5.5 ... 首T N.Ns ↻60s
```

- [ ] **Step 3: Test pane toggle in current tmux**

Run:

```bash
tmux run-shell "$PWD/tmux/usage-monitor.tmux"
```

Then press the configured tmux prefix and `u`.

Expected:

- a bottom pane opens with title `usage-monitor`
- the pane prints one line and refreshes every configured interval
- pressing prefix `u` again closes that pane

## Task 7: Add User Documentation

**Files:**
- Create: `docs/tmux-plugin.md`
- Modify: `docs/linux-cli.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Write plugin docs**

```markdown
# tmux Plugin

`tmux-usage-monitor` is a TPM-style plugin for showing balance and channel health in a tmux pane. It does not require Swift or the `usage-monitor` CLI at runtime.

## Requirements

- tmux
- curl
- jq

## Install With TPM

```tmux
set -g @plugin 'xiazhourui/tmux-usage-monitor'
set -g @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
set -g @usage_monitor_interval "60"
set -g @usage_monitor_height "2"
set -g @usage_monitor_model "gpt-5.5"
set -g @usage_monitor_key "u"
```

Reload tmux and install TPM plugins with your TPM install binding.

## Config

Create `~/.config/tmux-usage-monitor/config.json`:

```json
{
  "defaultBaseURL": "https://example.com",
  "refreshIntervalSeconds": 60,
  "statusEndpoint": "https://status.input.im/api/status",
  "model": "gpt-5.5",
  "keys": [
    {
      "id": "main",
      "name": "Main",
      "apiKey": "sk-...",
      "baseURL": "https://example.com"
    }
  ]
}
```

Protect the config file:

```bash
chmod 600 ~/.config/tmux-usage-monitor/config.json
```

## Usage

Press your tmux prefix and `u` to toggle the monitor pane.

The pane renders:

```text
总额度 [███████████████░░░] 84.0% $672.22/$800.00 余额 $127.78 渠道 2/2 OK gpt-5.5 ○◐○●○ 首T 2.3s ↻60s
```

## Troubleshooting

`usage-monitor: missing jq` means `jq` is not installed.

`usage-monitor: config not found` means the config path does not exist or `@usage_monitor_config` points to the wrong file.

HTTP 401 or 403 responses mean the API key is invalid or not accepted by the configured Base URL.
```

- [ ] **Step 2: Link from `docs/linux-cli.md`**

Add this paragraph under `## tmux Bar Pane`:

```markdown
For a TPM-style plugin that does not require Swift at runtime, see [tmux Plugin](tmux-plugin.md). The plugin uses `curl` and `jq` directly and is better suited for shared tmux setups.
```

- [ ] **Step 3: Update `README.md`**

Add this bullet under the feature list:

```markdown
- Provides a TPM-style tmux plugin path for users who want a shell-native pane without installing Swift.
```

- [ ] **Step 4: Update `README.zh-CN.md`**

Add this bullet under the CLI/tmux section:

```markdown
- 提供 TPM 风格 tmux 插件方案，插件运行时只依赖 `tmux`、`curl` 和 `jq`，不要求安装 Swift。
```

- [ ] **Step 5: Commit docs**

```bash
git add docs/tmux-plugin.md docs/linux-cli.md README.md README.zh-CN.md
git commit -m "docs: add tmux plugin usage guide"
```

## Task 8: Final Verification

**Files:**
- Verify all files touched by this plan.

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
bash -n tmux/scripts/usage-monitor-render.sh
bash -n tmux/scripts/usage-monitor-pane.sh
bash -n tmux/tests/render_oneline_test.sh
```

Expected: no output and exit code 0 for each command.

- [ ] **Step 2: Run renderer test**

Run:

```bash
bash tmux/tests/render_oneline_test.sh
```

Expected:

```text
ok render oneline
```

- [ ] **Step 3: Run tmux plugin entrypoint**

Run:

```bash
tmux run-shell "$PWD/tmux/usage-monitor.tmux"
```

Expected: no output and exit code 0.

- [ ] **Step 4: Confirm no Swift dependency in plugin scripts**

Run:

```bash
rg -n 'swift|usage-monitor bar|usage-monitor bat' tmux docs/tmux-plugin.md
```

Expected:

```text
docs/tmux-plugin.md:3:`tmux-usage-monitor` is a TPM-style plugin for showing balance and channel health in a tmux pane. It does not require Swift or the `usage-monitor` CLI at runtime.
```

- [ ] **Step 5: Check whitespace**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 6: Review intended diff**

Run:

```bash
git status --short
git diff --stat
```

Expected:

- tracked changes are limited to `tmux/`, `docs/tmux-plugin.md`, `docs/linux-cli.md`, `README.md`, and `README.zh-CN.md`
- `.codegraph/` may remain untracked and must not be staged

## Execution Notes

- Do not store real API keys in repository fixtures, docs, commits, or final replies.
- Keep the Swift CLI untouched unless a later task explicitly asks to align text between the CLI and the plugin.
- Keep the renderer intentionally compact. The first plugin release targets a persistent tmux pane, not `status-right`.
- The plugin should fail visibly but quietly inside tmux. Missing dependency and config errors should print one short line instead of exiting with a stack trace.
