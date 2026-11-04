#!/usr/bin/env bash
# Builds Side Touch Bar from source and installs it into /Applications
# (or ~/Applications when /Applications isn't writable), then opens it.
# Usage: scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 26 ]; then
    echo "Side Touch Bar needs macOS 26 or later (this Mac runs $(sw_vers -productVersion))." >&2
    exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Install Apple's Command Line Tools first, then run this again:" >&2
    echo "    xcode-select --install" >&2
    exit 1
fi

scripts/build-app.sh release

DEST="${INSTALL_DIR:-/Applications}"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

pkill -x SideTouchBar 2>/dev/null || true
rm -rf "$DEST/SideTouchBar.app"
ditto build/SideTouchBar.app "$DEST/SideTouchBar.app"
open "$DEST/SideTouchBar.app"

echo
echo "Installed $DEST/SideTouchBar.app."
echo "Grant Accessibility permission when asked (System Settings › Privacy & Security › Accessibility)."
