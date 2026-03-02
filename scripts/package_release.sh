#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WhisperPuma"
BUILD_APP="$ROOT_DIR/build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"

VERSION="${1:-$(date +%Y.%m.%d)}"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS.dmg"

echo "🐆 Packaging $APP_NAME release ($VERSION)..."

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH"

(
    cd "$ROOT_DIR"
    WHISPER_PUMA_BUNDLE_PYTHON=1 ./scripts/build_app.sh
)

echo "🗜️ Creating zip artifact..."
ditto -c -k --sequesterRsrc --keepParent "$BUILD_APP" "$ZIP_PATH"

echo "💿 Creating dmg artifact..."
hdiutil create -volname "$APP_NAME" -srcfolder "$BUILD_APP" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "✅ Release artifacts ready:"
echo "   - $ZIP_PATH"
echo "   - $DMG_PATH"
