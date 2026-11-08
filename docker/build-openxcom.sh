#!/usr/bin/env bash
#
# Configure/build OpenXcom for macOS arm64 and assemble a self-contained
# OpenXcom.app. Runs inside the Linux build image (osxcross).
#
set -euo pipefail

SRC="${SRC:-/src}"
BUILD="${BUILD:-/build}"
OUT="${OUT:-/out}"
PREFIX="${PREFIX:-/opt/macos}"
JOBS="${JOBS:-$(nproc)}"
BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

APP="$OUT/OpenXcom.app"
TOOLCHAIN=/usr/local/share/darwin-arm64.toolchain.cmake

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

git config --global --add safe.directory "$SRC" 2>/dev/null || true

mkdir -p "$BUILD" "$OUT"
rm -rf "$APP"

log "configure OpenXcom ($BUILD_TYPE, arm64)"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
	-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
	-DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_PREFIX_PATH="$PREFIX" \
	-DCMAKE_INSTALL_NAME_DIR=@rpath \
	-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
	-DCMAKE_EXE_LINKER_FLAGS="-framework Cocoa" \
	-DCREATE_BUNDLE=OFF \
	-DDEV_BUILD=OFF \
	-DBUILD_PACKAGE=OFF \
	-DCHECK_CCACHE=ON \
	-DSDL_INCLUDE_DIR="$PREFIX/include/SDL" \
	-DSDL_LIBRARY="$PREFIX/lib/libSDL.dylib" \
	-DSDLMIXER_INCLUDE_DIR="$PREFIX/include/SDL" \
	-DSDLMIXER_LIBRARY="$PREFIX/lib/libSDL_mixer.dylib" \
	-DSDLIMAGE_INCLUDE_DIR="$PREFIX/include/SDL" \
	-DSDLIMAGE_LIBRARY="$PREFIX/lib/libSDL_image.dylib" \
	-DSDLGFX_INCLUDE_DIR="$PREFIX/include/SDL" \
	-DSDLGFX_LIBRARY="$PREFIX/lib/libSDL_gfx.dylib" \
	-DYAMLCPP_INCLUDE_DIR="$PREFIX/include" \
	-DYAMLCPP_LIBRARY="$PREFIX/lib/libyaml-cpp.dylib"

log "build OpenXcom"
cmake --build "$BUILD" --target openxcom -j "$JOBS"

log "assemble OpenXcom.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
install -m 755 "$BUILD/bin/openxcom" "$APP/Contents/MacOS/openxcom"

cp "$SRC/res/mac/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
if [ -f "$SRC/bin/common/openxcom.png" ]; then
	cp "$SRC/bin/common/openxcom.png" "$APP/Contents/Resources/openxcom.png"
elif [ -f "$SRC/res/linux/icons/openxcom_128x128.png" ]; then
	cp "$SRC/res/linux/icons/openxcom_128x128.png" "$APP/Contents/Resources/openxcom.png"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>openxcom</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>org.openxcom.openxcom</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>OpenXcom</string>
	<key>CFBundleDisplayName</key>
	<string>OpenXcom</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1</string>
	<key>CFBundleVersion</key>
	<string>0.1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.strategy-games</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

for dir in common standard UFO TFTD; do
	if [ -d "$SRC/bin/$dir" ]; then
		cp -a "$SRC/bin/$dir" "$APP/Contents/Resources/$dir"
	fi
done

# Bundle all dependencies. Symlinks (libSDL.dylib -> libSDL-1.2.0.dylib) are
# preserved, actual Mach-O files get @rpath install names below.
cp -a "$PREFIX"/lib/*.dylib "$APP/Contents/Frameworks/"

find "$APP/Contents/Frameworks" -maxdepth 1 -type f -name '*.dylib' -print0 |
while IFS= read -r -d '' lib; do
	install_name_tool -id "@rpath/$(basename "$lib")" "$lib"
done

find "$APP/Contents" -type f \( -name openxcom -o -name '*.dylib' \) -print0 |
while IFS= read -r -d '' bin; do
	otool -L "$bin" | awk 'NR > 1 { print $1 }' | while read -r dep; do
		case "$dep" in
			"$PREFIX"/*)
				install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$bin"
				;;
		esac
	done
	if ! otool -l "$bin" | grep -q '@executable_path/../Frameworks'; then
		install_name_tool -add_rpath '@executable_path/../Frameworks' "$bin" 2>/dev/null || true
	fi
done

log "verify bundle"
file "$APP/Contents/MacOS/openxcom"
otool -L "$APP/Contents/MacOS/openxcom"

bad=0
while IFS= read -r -d '' bin; do
	if otool -L "$bin" | grep -q "$PREFIX"; then
		echo "ERROR: $bin still references $PREFIX" >&2
		bad=1
	fi
done < <(find "$APP/Contents" -type f \( -name openxcom -o -name '*.dylib' \) -print0)
if [ "$bad" -ne 0 ]; then
	echo "ERROR: bundle contains unresolved dependencies" >&2
	exit 1
fi

log "done: $APP"
du -sh "$APP"
