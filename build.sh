#!/usr/bin/env bash
set -euo pipefail

# Builds the CrosshairApp SPM executable in release and assembles a self-contained,
# ad-hoc-signed Crosshair.app menu-bar agent bundle. The bundle's Info.plist is the
# source of truth for LSUIElement (Dock-less) behavior when run as an .app.

readonly APP_NAME="Crosshair"
readonly BUNDLE_ID="com.millsymills.crosshair"
readonly EXECUTABLE="CrosshairApp"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BUILT_BINARY="$BIN_DIR/$EXECUTABLE"

if [[ ! -x "$BUILT_BINARY" ]]; then
  echo "error: built binary not found at $BUILT_BINARY" >&2
  exit 1
fi

APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/$APP_NAME"

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

codesign -s - --force "$APP_BUNDLE"

echo "built $APP_BUNDLE"
