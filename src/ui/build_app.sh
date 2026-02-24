#!/bin/bash

# Exit on error
set -e

# Navigate to the script's directory so paths resolve correctly
cd "$(dirname "$0")"

echo "🐆 Building Whisper Puma UI..."

# Define paths
APP_NAME="WhisperPuma"
APP_DIR="${APP_NAME}.app"
PLIST_FILE="Info.plist"

# Clean up existing build
if [ -d "$APP_DIR" ]; then
    echo "🧹 Cleaning up old build..."
    rm -rf "$APP_DIR"
fi

# Create app bundle structure
echo "📁 Creating App bundle structure..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy Backend Scripts
echo "🐍 Bundling Python Backend..."
cp -r "../backend/"* "$APP_DIR/Contents/Resources/"

# Compile Swift code (compile all .swift files in the src/ui directory)
echo "🔨 Compiling Swift source..."
xcrun -sdk macosx swiftc *.swift -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
    -module-cache-path $(mktemp -d) \
    -framework Cocoa -framework AVFoundation

# Copy Info.plist
echo "📄 Copying Info.plist..."
cp "$PLIST_FILE" "$APP_DIR/Contents/Info.plist"

# Sign the App Bundle to prevent macOS permission resets
echo "🔐 Signing App Bundle..."
codesign --force --deep -s - "$APP_DIR"

echo "✅ Build complete! You can find the app at: src/ui/$APP_DIR"
echo "👉 To run it: open src/ui/$APP_DIR"
echo "⚠️  Note: The first time you run it, macOS will ask for Microphone and Accessibility permissions."
