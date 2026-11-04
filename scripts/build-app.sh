#!/usr/bin/env bash
# Builds SideTouchBar and assembles build/SideTouchBar.app
# Usage: scripts/build-app.sh [debug|release]
# Set UNIVERSAL=1 to build for both Apple silicon and Intel (used for releases).
# Signs with $SIGN_IDENTITY, else the local identity from create-signing-identity.sh
# (so permissions survive rebuilds), else ad hoc.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
LOCAL_IDENTITY="SideTouchBar Local Signing"
if [ -z "${SIGN_IDENTITY:-}" ]; then
    if security find-identity -p codesigning 2>/dev/null | grep -q "$LOCAL_IDENTITY"; then
        SIGN_IDENTITY="$LOCAL_IDENTITY"
    else
        SIGN_IDENTITY="-"
    fi
fi
APP="build/SideTouchBar.app"

ARCH_FLAGS=()
CLANG_ARCHS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
    CLANG_ARCHS=(-arch arm64 -arch x86_64)
fi

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SideTouchBar" "$APP/Contents/MacOS/SideTouchBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Localized Info.plist strings (permission prompts).
cp -R Resources/*.lproj "$APP/Contents/Resources/" 2>/dev/null || true

# Now Playing helper, loaded by /usr/bin/perl at runtime (see Helpers/NowPlayingHelper.m).
HELPER="$APP/Contents/Resources/libNowPlayingHelper.dylib"
clang -dynamiclib -fobjc-arc -O2 ${CLANG_ARCHS[@]+"${CLANG_ARCHS[@]}"} -framework Foundation Helpers/NowPlayingHelper.m -o "$HELPER"
codesign --force --sign "$SIGN_IDENTITY" "$HELPER"

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP (signed: $SIGN_IDENTITY)"
