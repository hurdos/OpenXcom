#!/usr/bin/env bash
#
# Install dist/OpenXcom.app into /Applications (or ~/Applications when
# /Applications is not writable). Only built-in macOS tools are used.
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP="dist/OpenXcom.app"
DEST_ROOT="${DEST_ROOT:-/Applications}"
DEST_EXPLICIT=0
OPEN=0

usage() {
	cat <<'EOF'
Usage: scripts/install-macos-app.sh [options] [path-to-OpenXcom.app]

Options:
  --dest PATH   install into PATH (default: /Applications, fallback ~/Applications)
  --open        open the app after installation
  -h, --help    show this help
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--dest)
			DEST_ROOT="$2"
			DEST_EXPLICIT=1
			shift 2
			;;
		--dest=*)
			DEST_ROOT="${1#*=}"
			DEST_EXPLICIT=1
			shift
			;;
		--open)
			OPEN=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		-*)
			echo "ERROR: unknown option: $1" >&2
			usage >&2
			exit 2
			;;
		*)
			APP="$1"
			shift
			;;
	esac
done

if [ ! -d "$APP" ]; then
	echo "ERROR: $APP not found; build the app first" >&2
	exit 1
fi
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"

if [ ! -w "$DEST_ROOT" ]; then
	if [ "$DEST_EXPLICIT" -eq 1 ]; then
		echo "ERROR: destination is not writable: $DEST_ROOT" >&2
		exit 1
	fi
	DEST_ROOT="$HOME/Applications"
	mkdir -p "$DEST_ROOT"
	echo "==> /Applications is not writable, using $DEST_ROOT"
fi

DEST="$DEST_ROOT/OpenXcom.app"

if pgrep -f "$DEST/Contents/MacOS/openxcom" >/dev/null 2>&1; then
	echo "ERROR: OpenXcom is running from $DEST" >&2
	echo "Quit it before installing the new build." >&2
	exit 1
fi

if [ -d "$DEST" ]; then
	echo "==> replacing $DEST"
	rm -rf "$DEST"
fi

echo "==> installing to $DEST"
ditto "$APP" "$DEST"

# Locally built apps normally have no quarantine attribute, but make sure a
# previously downloaded/copied build does not get blocked.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

if command -v codesign >/dev/null 2>&1; then
	if ! codesign --verify --deep --strict "$DEST" 2>/dev/null; then
		echo "WARNING: code signature verification failed for $DEST" >&2
	fi
fi

echo "==> installed: $DEST"
echo "    run: open \"$DEST\""

if [ "$OPEN" -eq 1 ]; then
	open "$DEST"
fi
