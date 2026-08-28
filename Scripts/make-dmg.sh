#!/bin/bash
# Package dist/Humi.app into a compressed drag-to-install DMG. No Xcode / no deps
# beyond hdiutil. Run Scripts/build-app.sh first.
# Usage: Scripts/make-dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Humi"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
VOL="$APP_NAME $VERSION"
STAGE="$(mktemp -d)"

[ -d "$APP" ] || { echo "✗ $APP not found — run Scripts/build-app.sh release first" >&2; exit 1; }

echo "▸ Staging $VOL"
cp -R "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

echo "▸ hdiutil create $DMG"
rm -f "$DMG"
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 \
  -ov "$DMG" >/dev/null

rm -rf "$STAGE"

# Ad-hoc sign the image itself so Gatekeeper sees a stable signature.
codesign --force --sign - "$DMG" 2>/dev/null || true

echo "✓ Built $DMG  (v$VERSION)"
