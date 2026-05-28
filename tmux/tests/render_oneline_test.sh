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

fixture_output="$(
  "$RENDER" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-main.json" \
    --usage-json "$ROOT_DIR/tmux/tests/fixtures/usage-backup.json" \
    --status-json "$ROOT_DIR/tmux/tests/fixtures/status.json" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"

fixture_expected='总额度 [███████████████░░░] 84.0% $672.22/$800.00 余额 $127.78 渠道 2/2 OK gpt-5.5 ○◐○●○ 首T 2.3s ↻60s'
assert_equals "$fixture_expected" "$fixture_output" "render oneline fixtures"

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

config_output="$(
  PATH="$fake_bin:$PATH" "$RENDER" \
    --config "$config" \
    --model "gpt-5.5" \
    --interval 60 \
    --no-color
)"

config_expected='总额度 [███████████████░░░] 82.1% $246.33/$300.00 余额 $53.67 渠道 2/2 OK gpt-5.5 ○◐○●○ 首T 2.3s ↻60s'
assert_equals "$config_expected" "$config_output" "render inherited config"

if ! rg -q 'https://api.example.test/v1/usage' "$CURL_LOG"; then
  printf 'not ok inherited config uses defaultBaseURL\n' >&2
  cat "$CURL_LOG" >&2
  exit 1
fi

printf 'ok inherited config uses defaultBaseURL\n'
