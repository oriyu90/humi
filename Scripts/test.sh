#!/bin/bash
# Run the HumiKit self-test suite (no XCTest/swift-testing dependency).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build --product HumiTests -c debug
exec "$ROOT/.build/debug/HumiTests"
