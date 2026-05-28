#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
PACKAGE_DIR="$BUILD_DIR/usage-monitor-linux-amd64"
ARCHIVE="$BUILD_DIR/usage-monitor-linux-amd64.tar.gz"
CHECKSUM="$ARCHIVE.sha256"

cd "$ROOT_DIR"

swift build --product usage-monitor -c release -Xswiftc -static-stdlib

rm -rf "$PACKAGE_DIR" "$ARCHIVE" "$CHECKSUM"
mkdir -p "$PACKAGE_DIR"
install -m 0755 ".build/release/usage-monitor" "$PACKAGE_DIR/usage-monitor"

tar -C "$PACKAGE_DIR" -czf "$ARCHIVE" usage-monitor
(
  cd "$BUILD_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

echo "Built $ARCHIVE"
cat "$CHECKSUM"
