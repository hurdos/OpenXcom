#!/usr/bin/env bash
#
# Package dist/OpenXcom.app as a drag-and-drop DMG and a zip archive.
# Uses only built-in macOS tools (hdiutil, ditto).
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP="${1:-dist/OpenXcom.app}"
NAME="OpenXcom-macos-arm64"
DMG="dist/${NAME}.dmg"
ZIP="dist/${NAME}.zip"

if [ ! -d "$APP" ]; then
	echo "ERROR: $APP not found; build the app first" >&2
	exit 1
fi
if ! command -v hdiutil >/dev/null 2>&1 || ! command -v ditto >/dev/null 2>&1; then
	echo "ERROR: hdiutil and ditto are required (run this on macOS)" >&2
	exit 1
fi

if command -v codesign >/dev/null 2>&1; then
	echo "==> verifying signature"
	codesign --verify --deep --strict "$APP"
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/openxcom-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

echo "==> staging DMG"
ditto "$APP" "$STAGE/OpenXcom.app"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $DMG"
rm -f "$DMG"
hdiutil create \
	-volname "OpenXcom" \
	-srcfolder "$STAGE" \
	-ov \
	-format UDZO \
	-quiet \
	"$DMG"
hdiutil verify -quiet "$DMG"

echo "==> creating $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
ls -lh "$DMG" "$ZIP"
echo "DMG: mount it and drag OpenXcom.app to Applications"
echo "ZIP: unzip and move OpenXcom.app to Applications"
