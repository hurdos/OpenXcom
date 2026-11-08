#!/usr/bin/env bash
#
# Cross-compile OpenXcom's macOS dependencies inside the Linux build image.
# Everything is installed into /opt/macos and linked with @rpath.
#
set -euo pipefail

PREFIX="${PREFIX:-/opt/macos}"
DEPS="${DEPS:-/tmp/openxcom-deps}"
JOBS="${JOBS:-$(nproc)}"
TRIPLE="${TRIPLE:-$(oa64-clang -dumpmachine)}"
# GNU canonical triple: the old config.sub in SDL_gfx 2.0.25 knows aarch64
# but not arm64. The compiler wrapper still targets arm64 Apple Darwin.
AUTOTOOLS_HOST="${AUTOTOOLS_HOST:-aarch64-apple-darwin}"
TOOLCHAIN="${CMAKE_TOOLCHAIN_FILE:-/usr/local/share/darwin-arm64.toolchain.cmake}"

export CC=oa64-clang
export CXX=oa64-clang++
export OBJC=oa64-clang
export AR="${TRIPLE}-ar"
export RANLIB="${TRIPLE}-ranlib"
export STRIP="${TRIPLE}-strip"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="/"
export MACOSX_DEPLOYMENT_TARGET=11.0
export CMAKE_PREFIX_PATH="$PREFIX"
export PATH="$PREFIX/bin:$PATH"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fetch() { log "fetch $2"; curl -fsSL --retry 3 --retry-delay 2 "$1" -o "$2"; }

cmake_build() {
	local src="$1"; shift
	local bld="$src/build"
	log "cmake: $src"
	cmake -S "$src" -B "$bld" -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_PREFIX_PATH="$PREFIX" \
		-DCMAKE_INSTALL_NAME_DIR=@rpath \
		-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
		"$@"
	cmake --build "$bld" -j "$JOBS"
	cmake --install "$bld"
}

autotools_build() {
	local dir="$1"; shift
	log "autotools: $dir"
	(
		cd "$dir"
		./configure --prefix="$PREFIX" --host="$AUTOTOOLS_HOST" \
			CC="$CC" CXX="$CXX" \
			CFLAGS="-O2 -I$PREFIX/include" \
			CXXFLAGS="-O2 -I$PREFIX/include" \
			LDFLAGS="-L$PREFIX/lib" \
			PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
			PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" \
			SDL_CONFIG="$PREFIX/bin/sdl-config" \
			"$@"
		make -j "$JOBS"
		make install
	)
}

mkdir -p "$PREFIX" "$DEPS"
cd "$DEPS"

# ---------------------------------------------------------------------------
# zlib
# ---------------------------------------------------------------------------
if [ ! -d zlib-1.3.1 ]; then
	fetch "https://zlib.net/fossils/zlib-1.3.1.tar.gz" zlib.tar.gz
	tar -xzf zlib.tar.gz
fi
cmake_build zlib-1.3.1 \
	-DBUILD_SHARED_LIBS=ON \
	-DZLIB_BUILD_EXAMPLES=OFF

# ---------------------------------------------------------------------------
# libpng (PNG loading for SDL_image)
# ---------------------------------------------------------------------------
if [ ! -d libpng-1.6.44 ]; then
	fetch "https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.44.tar.gz" libpng.tar.gz
	tar -xzf libpng.tar.gz
fi
cmake_build libpng-1.6.44 \
	-DPNG_SHARED=ON \
	-DPNG_STATIC=OFF \
	-DPNG_TESTS=OFF \
	-DPNG_TOOLS=OFF \
	-DZLIB_LIBRARY="$PREFIX/lib/libz.dylib" \
	-DZLIB_INCLUDE_DIR="$PREFIX/include"
# Some configure scripts look for the unversioned pkg-config name.
if [ -f "$PREFIX/lib/pkgconfig/libpng16.pc" ] && [ ! -e "$PREFIX/lib/pkgconfig/libpng.pc" ]; then
	ln -s libpng16.pc "$PREFIX/lib/pkgconfig/libpng.pc"
fi

# ---------------------------------------------------------------------------
# libogg / libvorbis (OGG music for SDL_mixer)
# ---------------------------------------------------------------------------
if [ ! -d libogg-1.3.5 ]; then
	fetch "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz" libogg.tar.gz
	tar -xzf libogg.tar.gz
fi
cmake_build libogg-1.3.5 \
	-DBUILD_SHARED_LIBS=ON \
	-DINSTALL_DOCS=OFF \
	-DBUILD_TESTING=OFF

if [ ! -d libvorbis-1.3.7 ]; then
	fetch "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz" libvorbis.tar.gz
	tar -xzf libvorbis.tar.gz
fi
cmake_build libvorbis-1.3.7 \
	-DBUILD_SHARED_LIBS=ON \
	-DBUILD_TESTING=OFF \
	-DOGG_INCLUDE_DIR="$PREFIX/include" \
	-DOGG_LIBRARY="$PREFIX/lib/libogg.dylib"

# ---------------------------------------------------------------------------
# SDL2 (backend used by sdl12-compat)
# ---------------------------------------------------------------------------
if [ ! -d SDL-release-2.32.10 ]; then
	fetch "https://github.com/libsdl-org/SDL/archive/refs/tags/release-2.32.10.tar.gz" SDL2.tar.gz
	tar -xzf SDL2.tar.gz
fi
cmake_build SDL-release-2.32.10 \
	-DSDL_SHARED=ON \
	-DSDL_STATIC=OFF \
	-DSDL_TEST_LIBRARY=OFF \
	-DSDL_TESTS=OFF \
	-DSDL_INSTALL_TESTS=OFF

# ---------------------------------------------------------------------------
# sdl12-compat (SDL 1.2 API on top of SDL2)
# ---------------------------------------------------------------------------
if [ ! -d sdl12-compat-release-1.2.78 ]; then
	fetch "https://github.com/libsdl-org/sdl12-compat/archive/refs/tags/release-1.2.78.tar.gz" sdl12-compat.tar.gz
	tar -xzf sdl12-compat.tar.gz
fi
cmake_build sdl12-compat-release-1.2.78 \
	-DSDL12TESTS=OFF \
	-DSDL12DEVEL=ON \
	-DSDL2_PATH="$PREFIX"

# ---------------------------------------------------------------------------
# SDL_image 1.2 (PNG only; keep the dependency tree small)
# ---------------------------------------------------------------------------
if [ ! -d SDL_image-633dc522f5114f6d473c910dace62e8ca27a1f7d ]; then
	fetch "https://github.com/libsdl-org/SDL_image/archive/633dc522f5114f6d473c910dace62e8ca27a1f7d.tar.gz" SDL_image.tar.gz
	tar -xzf SDL_image.tar.gz
fi
autotools_build SDL_image-633dc522f5114f6d473c910dace62e8ca27a1f7d \
	--disable-sdltest \
	--enable-shared --disable-static \
	--enable-png --disable-png-shared \
	--disable-jpg --disable-tif --disable-webp --disable-imageio

# ---------------------------------------------------------------------------
# SDL_mixer 1.2 (WAV + OGG only)
# ---------------------------------------------------------------------------
if [ ! -d SDL_mixer-3a4cdce6dca7413fc37bf5f6d81cd53d3b54e9d7 ]; then
	fetch "https://github.com/libsdl-org/SDL_mixer/archive/3a4cdce6dca7413fc37bf5f6d81cd53d3b54e9d7.tar.gz" SDL_mixer.tar.gz
	tar -xzf SDL_mixer.tar.gz
fi
autotools_build SDL_mixer-3a4cdce6dca7413fc37bf5f6d81cd53d3b54e9d7 \
	--disable-sdltest \
	--enable-shared --disable-static \
	--disable-music-mod \
	--disable-music-midi \
	--disable-music-flac \
	--disable-music-mp3 \
	--disable-music-cmd \
	--enable-music-wave \
	--enable-music-ogg --disable-music-ogg-shared

# ---------------------------------------------------------------------------
# SDL_gfx (primitives + rotozoom)
# ---------------------------------------------------------------------------
if [ ! -d sdlgfx-2.0.25 ]; then
	fetch "http://deb.debian.org/debian/pool/main/s/sdlgfx/sdlgfx_2.0.25.orig.tar.gz" sdlgfx.tar.gz
	tar -xzf sdlgfx.tar.gz
fi
autotools_build sdlgfx-2.0.25 \
	--disable-mmx \
	--disable-sdltest \
	--enable-shared --disable-static

# ---------------------------------------------------------------------------
# yaml-cpp
# ---------------------------------------------------------------------------
if [ ! -d yaml-cpp-0.8.0 ]; then
	fetch "https://github.com/jbeder/yaml-cpp/archive/refs/tags/0.8.0.tar.gz" yaml-cpp.tar.gz
	tar -xzf yaml-cpp.tar.gz
fi
cmake_build yaml-cpp-0.8.0 \
	-DBUILD_SHARED_LIBS=ON \
	-DYAML_CPP_BUILD_TESTS=OFF \
	-DYAML_CPP_BUILD_TOOLS=OFF \
	-DYAML_CPP_INSTALL=ON

# ---------------------------------------------------------------------------
# Normalize install names of libraries built by autotools (SDL_image,
# SDL_mixer, SDL_gfx) so the final app can bundle everything under @rpath.
# ---------------------------------------------------------------------------
log "normalizing dylib install names"
for lib in $(find "$PREFIX/lib" -maxdepth 1 -type f -name '*.dylib'); do
	install_name_tool -id "@rpath/$(basename "$lib")" "$lib"
	otool -L "$lib" | awk 'NR > 1 { print $1 }' | while read -r dep; do
		case "$dep" in
			"$PREFIX"/lib/*)
				install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$lib"
				;;
		esac
	done
done

log "installed macOS libraries:"
find "$PREFIX/lib" -maxdepth 1 -name '*.dylib' -printf '%f\n' | sort

# Keep the final image small: sources and build trees are not needed at
# application build time. Removing them in the same RUN layer avoids storing
# them in the image.
log "cleaning dependency sources"
rm -rf "$DEPS"
