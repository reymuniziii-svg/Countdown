#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Countdown"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ICON_BUILD_DIR="$DIST_DIR/icon-build"
ICONSET_DIR="$ICON_BUILD_DIR/AppIcon.iconset"
ICON_SOURCE_PNG="$ICON_BUILD_DIR/AppIcon-1024.png"
ICNS_PATH="$ICON_BUILD_DIR/AppIcon.icns"

echo "Building $APP_NAME..."
cd "$ROOT_DIR"
swift build -c release

rm -rf "$ICON_BUILD_DIR"
mkdir -p "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICON_SOURCE_PNG" 1024

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Countdown/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICNS_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Built app bundle at:"
echo "$APP_DIR"
