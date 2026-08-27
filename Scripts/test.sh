#!/bin/bash
# Run the HumiKit self-test suite (no XCTest/swift-testing dependency).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Isolate persistence: the suite writes and deletes sessions.json / notes.md, so
# point it at a throwaway dir instead of the real ~/Library/Application Support/Humi.
HUMI_SUPPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/humi-selftest.XXXXXX")"
export HUMI_SUPPORT_DIR
trap 'rm -rf "$HUMI_SUPPORT_DIR"' EXIT

swift build --product HumiTests -c debug
"$ROOT/.build/debug/HumiTests"
