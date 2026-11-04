#!/usr/bin/env bash
# Builds SideTouchBar and assembles build/SideTouchBar.app
# Usage: scripts/build-app.sh [debug|release]
# Set SIGN_IDENTITY to a real certificate to keep Accessibility permission across rebuilds.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/SideTouchBar.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SideTouchBar" "$APP/Contents/MacOS/SideTouchBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Now Playing helper, loaded by /usr/bin/perl at runtime (see Helpers/NowPlayingHelper.m).
HELPER="$APP/Contents/Resources/libNowPlayingHelper.dylib"
clang -dynamiclib -fobjc-arc -O2 -framework Foundation Helpers/NowPlayingHelper.m -o "$HELPER"
codesign --force --sign "$SIGN_IDENTITY" "$HELPER"

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
