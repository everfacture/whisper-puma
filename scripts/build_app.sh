#!/bin/bash
set -e

# Whisper Puma Build Script (v1.0.9)
# Professionalized for clean-code standards.


# Configuration
APP_NAME="WhisperPuma"
BUILD_DIR="build"
SRC_UI="src/ui"
SRC_BACKEND="src/backend"
LOG_DIR="logs"

echo "🐆 Preparing Whisper Puma build..."

# 1. Environment Check
if ! command -v swiftc &> /dev/null; then
    echo "❌ Error: Swift compiler (swiftc) not found."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 not found."
    exit 1
fi

# 2. Cleanup
echo "🧹 Cleaning up old build artifacts..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$LOG_DIR"

# 3. Compile Swift
echo "🔨 Compiling Swift source..."
# Find all swift files recursively or list them
SWIFT_FILES=$(find "$SRC_UI" -name "*.swift")
swiftc $SWIFT_FILES \
    -o "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -target arm64-apple-macosx14.0

# 4. Bundle Backend
echo "🐍 Bundling Python Backend..."
cp -r "$SRC_BACKEND/"* "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"

# 5. Metadata & Assets
echo "📄 Copying Info.plist..."
if [ -f "$SRC_UI/Info.plist" ]; then
    cp "$SRC_UI/Info.plist" "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist"
else
    # Minimal Info.plist if missing
    cat <<EOF > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.everfacture.whisperpuma</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.9</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
fi

# 6. Signing (Ad-hoc)
echo "🔐 Signing App Bundle..."
codesign --force --deep --sign - "$BUILD_DIR/$APP_NAME.app"

echo "✅ Build complete! You can find the app at: $BUILD_DIR/$APP_NAME.app"
echo "👉 To run it: open $BUILD_DIR/$APP_NAME.app"
