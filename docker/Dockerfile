# syntax=docker/dockerfile:1.7

# osxcross image contains the cross toolchain and the macOS SDK.
ARG OSXCROSS_IMAGE=crazymax/osxcross:26.1
FROM ${OSXCROSS_IMAGE} AS osxcross

FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		build-essential \
		ca-certificates \
		ccache \
		clang \
		cmake \
		curl \
		file \
		git \
		libtool \
		lld \
		m4 \
		make \
		ninja-build \
		patch \
		pkg-config \
		python3 \
		unzip \
		xz-utils \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=osxcross /osxcross /osxcross

ENV PATH="/osxcross/bin:/usr/local/bin:${PATH}"
ENV LD_LIBRARY_PATH="/osxcross/lib"

# Unprefixed versions of the cross tools are convenient for CMake and for
# the bundle post-processing in build-openxcom.sh.
RUN triple="$(oa64-clang -dumpmachine)" && \
	ln -sf "/osxcross/bin/${triple}-otool" /usr/local/bin/otool && \
	ln -sf "/osxcross/bin/${triple}-install_name_tool" /usr/local/bin/install_name_tool && \
	ln -sf "/osxcross/bin/${triple}-lipo" /usr/local/bin/lipo && \
	ln -sf "/osxcross/bin/${triple}-strip" /usr/local/bin/strip-macho

COPY docker/darwin-arm64.toolchain.cmake /usr/local/share/darwin-arm64.toolchain.cmake
COPY docker/build-deps.sh /usr/local/bin/build-deps.sh
RUN chmod +x /usr/local/bin/build-deps.sh

# SDL2's Objective-C code uses @available, which compiles to a call to
# __isPlatformVersionAtLeast from compiler-rt. The osxcross image has no
# Darwin compiler-rt, so the wrapper script copies libclang_rt.osx.a from the
# installed Xcode into docker/vendor/ before building this image.
COPY docker/vendor/ /tmp/compiler-rt/
RUN set -eux; \
	rt_dir="$(clang -print-resource-dir)/lib/darwin"; \
	mkdir -p "$rt_dir"; \
	if [ ! -f /tmp/compiler-rt/libclang_rt.osx.a ]; then \
		echo "ERROR: docker/vendor/libclang_rt.osx.a is missing."; \
		echo "Run the build through scripts/build-macos-docker.sh, or copy"; \
		echo "libclang_rt.osx.a from Xcode into docker/vendor/ manually."; \
		exit 1; \
	fi; \
	cp /tmp/compiler-rt/libclang_rt.osx.a "$rt_dir/"; \
	ls -l "$rt_dir/libclang_rt.osx.a"

ENV CMAKE_TOOLCHAIN_FILE=/usr/local/share/darwin-arm64.toolchain.cmake
ENV MACOSX_DEPLOYMENT_TARGET=11.0
ENV PREFIX=/opt/macos
ENV PKG_CONFIG_PATH=/opt/macos/lib/pkgconfig
ENV PKG_CONFIG_LIBDIR=/opt/macos/lib/pkgconfig
ENV PKG_CONFIG_SYSROOT_DIR=/
ENV CCACHE_DIR=/ccache

# Build the whole macOS dependency stack once; the layer is cached.
RUN /usr/local/bin/build-deps.sh

# Keep the application build script after the dependency layer so changing it
# does not rebuild zlib/SDL/etc.
COPY docker/build-openxcom.sh /usr/local/bin/build-openxcom.sh
RUN chmod +x /usr/local/bin/build-openxcom.sh

WORKDIR /src
CMD ["/usr/local/bin/build-openxcom.sh"]
