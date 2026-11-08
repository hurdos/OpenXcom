#!/usr/bin/env bash
#
# Build a native macOS arm64 OpenXcom.app without installing a C++ toolchain
# or SDL on the host. Docker is only used as the cross-compilation environment.
#
# Usage:
#   ./scripts/build-macos-docker.sh [--clean] [--package] [--install] [--open]
#
set -euo pipefail

cd "$(dirname "$0")/.."

CLEAN=0
PACKAGE=0
INSTALL=0
OPEN=0

usage() {
	cat <<'EOF'
Usage: scripts/build-macos-docker.sh [options]

Options:
  --clean       remove build volumes and dist/, then rebuild from scratch
  --package     create dist/OpenXcom-macos-arm64.dmg and .zip after the build
  --install     install OpenXcom.app into /Applications (or ~/Applications)
  --open        open the app after building/installing
  -h, --help    show this help

Without options the app is built and signed into dist/OpenXcom.app.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--clean)
			CLEAN=1
			shift
			;;
		--package|--dmg)
			PACKAGE=1
			shift
			;;
		--install)
			INSTALL=1
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
		*)
			echo "ERROR: unknown option: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

if ! command -v docker >/dev/null 2>&1; then
	echo "ERROR: docker is not installed or not in PATH" >&2
	exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
	echo "ERROR: docker compose (v2) is required" >&2
	exit 1
fi

# compiler-rt is needed by SDL2 (@available / __isPlatformVersionAtLeast).
# It ships with Xcode but is not present in the Linux cross-toolchain image.
prepare_compiler_rt() {
	local dst="docker/vendor/libclang_rt.osx.a"
	if [ -f "$dst" ]; then
		return
	fi

	local src
	src="$(find \
		/Applications/Xcode.app/Contents/Developer/Toolchains \
		/Library/Developer/CommandLineTools \
		-name 'libclang_rt.osx.a' 2>/dev/null | sort -V | tail -n 1)"

	if [ -z "$src" ]; then
		echo "ERROR: libclang_rt.osx.a not found." >&2
		echo "Install Xcode or Xcode Command Line Tools, or put the file into docker/vendor/." >&2
		exit 1
	fi

	mkdir -p docker/vendor
	cp "$src" "$dst"
	echo "==> using compiler-rt: $src"
}

prepare_compiler_rt

if [ "$CLEAN" -eq 1 ]; then
	echo "==> cleaning build volumes and dist"
	docker compose down -v --remove-orphans 2>/dev/null || true
	rm -rf dist
fi

echo "==> building the macOS cross-compilation image"
docker compose build build

echo "==> building OpenXcom.app"
docker compose run --rm build

APP="dist/OpenXcom.app"
if [ ! -d "$APP" ]; then
	echo "ERROR: $APP was not produced" >&2
	exit 1
fi

# install_name_tool invalidates the linker signature; arm64 binaries must be
# signed again before macOS will execute them.
if command -v codesign >/dev/null 2>&1; then
	echo "==> ad-hoc codesign"
	codesign --force --deep --sign - "$APP"
	codesign --verify --deep --strict "$APP"
else
	echo "WARNING: codesign not found; the app may not launch on Apple Silicon" >&2
fi

echo
echo "==> ready: $APP"
file "$APP/Contents/MacOS/openxcom"

if [ "$PACKAGE" -eq 1 ]; then
	./scripts/package-macos-app.sh "$APP"
fi

if [ "$INSTALL" -eq 1 ]; then
	if [ "$OPEN" -eq 1 ]; then
		./scripts/install-macos-app.sh --open "$APP"
	else
		./scripts/install-macos-app.sh "$APP"
	fi
elif [ "$OPEN" -eq 1 ]; then
	open "$APP"
fi

echo "run: open \"$APP\""
