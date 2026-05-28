#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RENDER="$ROOT_DIR/tmux/scripts/usage-monitor-render.sh"

assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok %s\n' "$label" >&2
    printf 'expected: %s\n' "$expected" >&2
    printf 'actual:   %s\n' "$actual" >&2
    exit 1
  fi

  printf 'ok %s\n' "$label"
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'not ok %s\n' "$label" >&2
    printf 'missing: %s\n' "$needle" >&2
    printf 'actual:\n%s\n' "$haystack" >&2
    exit 1
  fi

  printf 'ok %s\n' "$label"
}

fixture_output="$(
  "$RENDER" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-main.json" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-backup.json" \
    --status-json "$ROOT_DIR/tmux/tests/fixtures/status.json" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"

fixture_expected='USAGE [████████░░]   84.0%  $672.22/$800.00  left $127.78  |  CHANNEL 2/2 OK  gpt-5.5  ·····○◐○●○  首T 2.3s  ↻60s'
assert_equals "$fixture_expected" "$fixture_output" "render oneline fixtures"

lite_output="$(
  "$RENDER" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-main.json" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-backup.json" \
    --status-json "$ROOT_DIR/tmux/tests/fixtures/status.json" \
    --model "gpt-5.5" \
    --interval 60 \
    --mode lite \
    --no-color
)"

lite_expected='USAGE
NAME           BAR             USE%      USED     LIMIT      LEFT
Total          [████████░░]   84.0%   $672.22   $800.00   $127.78
usage-main     [████████░░]   82.1%   $246.33   $300.00    $53.67
usage-backup   [█████████░]   85.2%   $425.89   $500.00    $74.11

CHANNEL
2/2 OK  gpt-5.5  ·····○◐○●○  首T 2.3s  ↻60s'
assert_equals "$lite_expected" "$lite_output" "render lite fixtures"

detail_output="$(
  "$RENDER" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-main.json" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-backup.json" \
    --status-json "$ROOT_DIR/tmux/tests/fixtures/status.json" \
    --model "gpt-5.5" \
    --interval 60 \
    --mode detail \
    --no-color
)"

assert_contains 'SERVICE STATUS' "$detail_output" "render detail service header"
assert_contains 'gpt-5.4       SLOW    首T 4.2s' "$detail_output" "render detail service row"
assert_contains 'USAGE DETAIL' "$detail_output" "render detail usage header"
assert_contains '────────────────────────────────────────────────────────' "$detail_output" "render detail separators"
assert_contains $'  plan Pro\n        week $620.12/$2100.00  month $1880.22/$9000.00' "$detail_output" "render detail plan columns"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
export CURL_LOG="$tmp_dir/curl.log"
export ROOT_DIR

cat >"$fake_bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$CURL_LOG"
last_arg="${@: -1}"

case "$last_arg" in
  */v1/usage)
    cat "$ROOT_DIR/tmux/tests/fixtures/usage-main.json"
    ;;
  https://status.input.im/api/status)
    cat "$ROOT_DIR/tmux/tests/fixtures/status.json"
    ;;
  *)
    printf 'unexpected curl URL: %s\n' "$last_arg" >&2
    exit 22
    ;;
esac
SH
chmod +x "$fake_bin/curl"

config="$tmp_dir/config.json"
cat >"$config" <<'JSON'
{
  "defaultBaseURL": "https://api.example.test",
  "keys": [
    {
      "id": "main",
      "name": "Main",
      "apiKey": "sk-test-main",
      "baseURLMode": "inherited",
      "baseURLOverride": ""
    }
  ]
}
JSON

config_expected='USAGE [████████░░]   82.1%  $246.33/$300.00  left $53.67  |  CHANNEL 2/2 OK  gpt-5.5  ·····○◐○●○  首T 2.3s  ↻60s'

config_output="$(
  USAGE_MONITOR_CURL_BIN="$fake_bin/curl" PATH="$fake_bin:$PATH" "$RENDER" \
    --config "$config" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"

assert_equals "$config_expected" "$config_output" "render inherited config"

fetch_dir="$tmp_dir/fetch"
mkdir -p "$fetch_dir"
USAGE_MONITOR_CURL_BIN="$fake_bin/curl" PATH="$fake_bin:$PATH" "$RENDER" \
  --config "$config" \
  --fetch-to "$fetch_dir" \
  --no-color

cache_output="$(
  "$RENDER" \
    --cache-dir "$fetch_dir" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"
assert_equals "$config_expected" "$cache_output" "render cache dir"

if ! grep -q 'https://api.example.test/v1/usage' "$CURL_LOG"; then
  printf 'not ok inherited config uses defaultBaseURL\n' >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

printf 'ok inherited config uses defaultBaseURL\n'
