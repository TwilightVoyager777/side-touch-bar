#!/usr/bin/env bash
# Runs the translation table check and the Swift Testing suite.
#
# With only the Command Line Tools, SwiftPM's default build system sometimes
# fails to load the Testing macro plugin ("plugin for module 'TestingMacros'
# not found"). The native build system with explicit paths is reliable.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/check-l10n.py

DEVELOPER_DIR="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
PLUGINS="$DEVELOPER_DIR/usr/lib/swift/host/plugins/testing"

swift test --build-system native \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xswiftc -plugin-path -Xswiftc "$PLUGINS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    "$@"
