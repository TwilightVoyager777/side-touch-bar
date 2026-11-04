#!/usr/bin/env bash
# Builds a universal release and packages it as a zip and a disk image in dist/.
# Usage: scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
UNIVERSAL=1 scripts/build-app.sh release

rm -rf dist
mkdir -p dist
# ditto keeps the code signature and extended attributes intact.
ditto -c -k --keepParent build/SideTouchBar.app "dist/SideTouchBar-$VERSION.zip"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto build/SideTouchBar.app "$STAGING/SideTouchBar.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "Side Touch Bar" -srcfolder "$STAGING" -format UDZO "dist/SideTouchBar-$VERSION.dmg"

(cd dist && shasum -a 256 SideTouchBar-* > SHA256SUMS.txt)
echo "Packaged:"
ls -lh dist
