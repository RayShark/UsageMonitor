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

expected='总额度 [███████████████░░░] 84.0% $672.22/$800.00 余额 $127.78 渠道 2/2 OK gpt-5.5 ○◐○●○ 首T 2.3s ↻60s'

if [[ "$output" != "$expected" ]]; then
  printf 'not ok render oneline\n' >&2
  printf 'expected: %s\n' "$expected" >&2
  printf 'actual:   %s\n' "$output" >&2
  exit 1
fi

printf 'ok render oneline\n'
