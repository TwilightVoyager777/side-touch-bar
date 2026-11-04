#!/usr/bin/env bash
# Removes Side Touch Bar: first its agent integrations (restoring your Claude
# Code, OpenCode and Codex settings) and login item, then the app, its
# preferences, data and permissions.
# Usage: scripts/uninstall.sh
set -euo pipefail

BUNDLE_ID="com.dest1ny.SideTouchBar"
APPS=("/Applications/SideTouchBar.app" "$HOME/Applications/SideTouchBar.app")

pkill -x SideTouchBar 2>/dev/null || true

for app in "${APPS[@]}"; do
    if [ -x "$app/Contents/MacOS/SideTouchBar" ]; then
        "$app/Contents/MacOS/SideTouchBar" --prepare-uninstall || {
            echo "Some integrations couldn't be removed; see above. Nothing else was deleted." >&2
            exit 1
        }
        break
    fi
done

for app in "${APPS[@]}"; do
    [ -e "$app" ] && rm -rf "$app" && echo "Removed $app."
done

defaults delete "$BUNDLE_ID" 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/SideTouchBar"
for service in Accessibility Microphone SpeechRecognition ScreenCapture; do
    tccutil reset "$service" "$BUNDLE_ID" >/dev/null 2>&1 || true
done

echo "Side Touch Bar has been removed."
