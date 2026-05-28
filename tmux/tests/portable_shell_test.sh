#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
status=0

while IFS= read -r file; do
  case "$file" in
    */portable_shell_test.sh)
      continue
      ;;
  esac

  if grep -nE '(^|[[:space:]])mapfile([[:space:]]|$)|xargs[[:space:]].*-r|readlink[[:space:]].*-f|find[[:space:]].*-maxdepth' "$file"; then
    printf 'not ok portable shell check: %s uses a GNU/Linux-only helper\n' "$file" >&2
    status=1
  fi
done < <(find "$ROOT_DIR/tmux" -type f \( -name '*.sh' -o -name '*.tmux' \) | sort)

if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi

printf 'ok portable shell check\n'
