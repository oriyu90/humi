#!/bin/bash
# Regenerate Assets/AppIcon.icns from Assets/AppIcon-source-1024.png (1024×1024 PNG).
# build-app.sh copies Assets/AppIcon.icns into the bundle and sets CFBundleIconFile.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Assets/AppIcon-source-1024.png"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
[ -f "$SRC" ] || { echo "✗ $SRC not found" >&2; exit 1; }
gen() { sips -z "$2" "$2" "$SRC" --out "$SET/$3" >/dev/null; }
gen x 16   icon_16x16.png
gen x 32   icon_16x16@2x.png
gen x 32   icon_32x32.png
gen x 64   icon_32x32@2x.png
gen x 128  icon_128x128.png
gen x 256  icon_128x128@2x.png
gen x 256  icon_256x256.png
gen x 512  icon_256x256@2x.png
gen x 512  icon_512x512.png
gen x 1024 icon_512x512@2x.png
iconutil -c icns "$SET" -o "$ROOT/Assets/AppIcon.icns"
echo "✓ $ROOT/Assets/AppIcon.icns"
