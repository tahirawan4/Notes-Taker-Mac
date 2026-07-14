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
ICON_FILE="$ROOT_DIR/Resources/NotesTaker.icns"
INSTALL_TO_APPLICATIONS=false
SIGNING_IDENTITY="NotesTaker Local Developer"

if [[ "${1:-}" == "--applications" ]]; then
  INSTALL_TO_APPLICATIONS=true
fi

cd "$ROOT_DIR"

ensure_signing_identity() {
  if security find-certificate -c "$SIGNING_IDENTITY" >/dev/null 2>&1; then
    return
  fi

  echo "Creating local signing identity: $SIGNING_IDENTITY"
  CERT_DIR="$(mktemp -d)"
  KEY_PATH="$CERT_DIR/notestaker.key"
  CERT_PATH="$CERT_DIR/notestaker.crt"
  P12_PATH="$CERT_DIR/notestaker.p12"
  P12_PASSWORD="notestaker-local"

  openssl req \
    -newkey rsa:2048 \
    -nodes \
    -keyout "$KEY_PATH" \
    -x509 \
    -days 3650 \
    -out "$CERT_PATH" \
    -subj "/CN=$SIGNING_IDENTITY/" \
    -addext "keyUsage=digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1

  openssl pkcs12 \
    -legacy \
    -export \
    -inkey "$KEY_PATH" \
    -in "$CERT_PATH" \
    -name "$SIGNING_IDENTITY" \
    -out "$P12_PATH" \
    -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

  security import "$P12_PATH" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign >/dev/null

  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "" \
    "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1 || true
}

echo "Building $APP_NAME in release mode..."
swift build -c release
ensure_signing_identity

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Generating app icon..."
  swift scripts/generate_icon.swift
fi

echo "Creating $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
cp "$ICON_FILE" "$RESOURCES_DIR/NotesTaker.icns"

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
  <key>CFBundleIconFile</key>
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
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>NotesTaker needs Speech Recognition access to transcribe saved meeting recordings into notes and action items.</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>NotesTaker needs screen recording access to save meeting video from Zoom, Chrome, or your selected screen.</string>
</dict>
</plist>
PLIST

# Bind Info.plist into the signature so TCC tracks a stable app identity.
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
echo "Signed $APP_DIR with $SIGNING_IDENTITY"

echo "Created $APP_DIR"

if [[ "$INSTALL_TO_APPLICATIONS" == "true" ]]; then
  /usr/bin/ditto "$APP_DIR" "/Applications/$APP_NAME.app"
  codesign --force --deep --sign "$SIGNING_IDENTITY" "/Applications/$APP_NAME.app"
  echo "Installed to /Applications/$APP_NAME.app"
else
  read -r -p "Copy $APP_NAME.app to /Applications? [y/N] " answer
  case "$answer" in
    [yY][eE][sS]|[yY])
      /usr/bin/ditto "$APP_DIR" "/Applications/$APP_NAME.app"
      codesign --force --deep --sign "$SIGNING_IDENTITY" "/Applications/$APP_NAME.app"
      echo "Installed to /Applications/$APP_NAME.app"
      ;;
    *)
      echo "Skipped /Applications copy. You can open $APP_DIR directly."
      ;;
  esac
fi

echo "Done."
echo "Permission note: after installing an updated build, macOS may keep a stale NotesTaker permission row."
echo "If capture says permission is missing: System Settings → Privacy & Security → Screen & System Audio Recording → remove NotesTaker (−), add /Applications/NotesTaker.app (+), then quit and reopen NotesTaker."
