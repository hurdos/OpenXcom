# Building for MacOS

## Dependencies

To successfully build an OpenXcom macOS bundle you will need relevant dependencies installed:

The dependencies you require are following:
- cmake, version 3.12.0 or later
- SDL (libsdl1.2)
- SDL_mixer (libsdl-mixer1.2)
- SDL_gfx (libsdl-gfx1.2), version 2.0.22 or later
- SDL_image (libsdl-image1.2)
- yaml-cpp, version 0.5 or later

CMake is used to configure the project. Download it [manually](https://cmake.org/download/) or install it with [Homebrew](https://brew.sh) (`brew install cmake`).

The easiest way of getting library dependencies is [MacPorts](https://www.macports.org/):
```sh
port -N install libsdl -compat +legacy libsdl_gfx libsdl_image libsdl_mixer yaml-cpp
```

Following instructions assume MacPorts is installed in default prefix `/opt/local`. If you installed ports into different location, replace it.

## Building
This project has two ways to build: one with make and the other with Xcode.  The make way is typically used for CI builds and produces a similar artifact as the Linux build.  If you're just looking to get a quick build, this is a good way to do so.  The Xcode way is useful if you're developing features (or bug fixes) and require the need for a debugger or an IDE experience.

### Make
1. In the root of the repository, generate the Makefile with cmake (Release is also a valid build type):
    ```
    cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=/opt/local -B build .
    ```
1. Copy the vanilla game assets (UFO/TFTD) into the build's `bin/` directory. If the game is next to the repo, cd into game and run:
    ```sh
    cp  -r GEODATA GEOGRAPH MAPS ROUTES SOUND TERRAIN UFOGRAPH UFOINTRO* UNITS ../OpenXcom/bin/UFO/
    ```
1. Build the project (2 being the number of threads to run):
    ```sh
    cmake --build build -j2
    ```
1. Make sure that you set up your [Data directory](https://github.com/OpenXcom/OpenXcom#directory-locations) properly.
1. Your artifact will be named `openxcom.app` in the build target directory.


### Xcode
1. In the root of the repository, generate the XCode project file with cmake (Release is also a valid build type):
    ```sh
    cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=/opt/local -G Xcode -B build .
    ```
1. Open the `OpenXcom.xcodeproj` in Xcode.
1. Copy the vanilla game assets (UFO/TFTD) into the build's `bin/` directory.
1. Build with cmd-B
1. Your artifact will be named `openxcom.app` in the build target directory (Debug or Release).

## Building with Docker (no local dependencies)

This is the easiest way to get a native Apple Silicon build without installing
a C++ compiler, CMake, SDL or any other library on the Mac. Docker is used
only as a Linux-based cross-compilation environment: the resulting application
runs natively on macOS.

Requirements:

- Docker Desktop (Docker Compose v2);
- original UFO/TFTD data placed into `bin/UFO` and `bin/TFTD` (the folders are
  git-ignored; see the README files inside them).

Build:

```sh
./scripts/build-macos-docker.sh
open dist/OpenXcom.app
```

Build, create a DMG/zip and install the app into `Applications` in one go:

```sh
./scripts/build-macos-docker.sh --package --install --open
```

The package step produces `dist/OpenXcom-macos-arm64.dmg` (drag `OpenXcom.app`
to the `Applications` shortcut) and `dist/OpenXcom-macos-arm64.zip`. The install
step copies the built app to `/Applications/OpenXcom.app`, or to
`~/Applications/OpenXcom.app` when `/Applications` is not writable. The app can
also be installed separately from an existing build:

```sh
./scripts/install-macos-app.sh          # or: ./scripts/install-macos-app.sh --open
./scripts/package-macos-app.sh          # only DMG + zip
```

The first run builds the cross toolchain and all dependencies (SDL2,
sdl12-compat, SDL_image, SDL_mixer, SDL_gfx, yaml-cpp) and can take
15-30 minutes. Subsequent builds reuse the Docker layer, CMake and ccache
caches and are much faster.

The result is `dist/OpenXcom.app` — an `arm64` bundle with the SDL libraries
inside `Contents/Frameworks` and the game data inside `Contents/Resources`.
The script signs the bundle ad-hoc, which is required for arm64 binaries on
Apple Silicon.

Useful commands:

```sh
# reset the build cache and rebuild from scratch
./scripts/build-macos-docker.sh --clean

# run only the compile step (without the codesign wrapper)
docker compose run --rm build

# open an interactive shell in the build image
docker compose run --rm --entrypoint bash build
```

Notes:

- Only `arm64` is produced by default. A universal build would require a
  second dependency stack and is not enabled.
- The build uses the third-party `crazymax/osxcross:26.1` image, which contains
  the macOS SDK and the osxcross toolchain. It is used locally only; neither
  the SDK nor a signed/notarized application is redistributed.
- SDL2 uses `@available`, so the linker needs `libclang_rt.osx.a` from
  compiler-rt. The wrapper copies it from the installed Xcode / Command Line
  Tools into `docker/vendor/` automatically (that file is git-ignored). No
  extra installation is required when Xcode is already present.
- The application is not signed with a Developer ID and is not notarized.
  A local ad-hoc signature is enough to run it on the machine where it was
  built; distributing it to other Macs needs a proper signing/notarization
  setup.

## Graphics profiles (macOS)

Ready-to-use video profiles for the macOS build (fullscreen/windowed,
OpenGL shaders, Retina and external displays) are documented in
[docs/macos-graphics/README.md](docs/macos-graphics/README.md).

```sh
./scripts/apply-graphics-profile.sh --list
./scripts/apply-graphics-profile.sh balanced-fullscreen --launch
```

## Additional Help
Should you require any further assistance regarding the macOS build - feel free to ask around on the official forums - https://openxcom.org/forum/ or contact us directly on GitHub - [@rcreasey](http://github.com/rcreasey)
