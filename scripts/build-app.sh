#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Flockerwhisper"
BUNDLE_ID="com.flockerwhisper.app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building ${APP_NAME} (release)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/${APP_NAME}"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Error: expected built executable at $EXECUTABLE" >&2
    exit 1
fi

if [[ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    echo "==> Generating AppIcon.icns..."
    swift "$ROOT_DIR/scripts/generate-icon.swift" "$ROOT_DIR/Resources/AppIcon.icns"
fi

echo "==> Assembling ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy any SwiftPM resource bundles emitted alongside the executable.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    cp -R "$bundle" "$RESOURCES_DIR/"
done
shopt -u nullglob

echo "==> Ad-hoc signing ${APP_DIR}..."
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

echo "==> Built: ${APP_DIR}"
