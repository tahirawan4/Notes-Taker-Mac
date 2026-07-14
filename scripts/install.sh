#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NotesTaker"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$ROOT_DIR/.build/release/$APP_NAME"

cd "$ROOT_DIR"

echo "Building $APP_NAME in release mode..."
swift build -c release

echo "Creating $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>NotesTaker</string>
  <key>CFBundleIdentifier</key>
  <string>com.tahirawan.notestaker</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>NotesTaker</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>NotesTaker needs microphone access to capture meeting audio when recording is enabled.</string>
</dict>
</plist>
PLIST

echo "Created $APP_DIR"

read -r -p "Copy $APP_NAME.app to /Applications? [y/N] " answer
case "$answer" in
  [yY][eE][sS]|[yY])
    cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
    echo "Installed to /Applications/$APP_NAME.app"
    ;;
  *)
    echo "Skipped /Applications copy. You can open $APP_DIR directly."
    ;;
esac

echo "Done."
