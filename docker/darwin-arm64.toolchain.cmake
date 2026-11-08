# CMake toolchain for cross-compiling macOS arm64 binaries from Linux.
# The toolchain itself (osxcross + macOS SDK) lives in the image at /osxcross.

set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_SYSROOT "/osxcross/SDK/MacOSX26.1.sdk")
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")

set(OSXCROSS_TRIPLE "arm64-apple-darwin25.1")

set(CMAKE_C_COMPILER "/osxcross/bin/oa64-clang")
set(CMAKE_CXX_COMPILER "/osxcross/bin/oa64-clang++")
set(CMAKE_OBJC_COMPILER "/osxcross/bin/oa64-clang")
set(CMAKE_OBJCXX_COMPILER "/osxcross/bin/oa64-clang++")

set(CMAKE_AR "/osxcross/bin/${OSXCROSS_TRIPLE}-ar")
set(CMAKE_RANLIB "/osxcross/bin/${OSXCROSS_TRIPLE}-ranlib")
set(CMAKE_STRIP "/osxcross/bin/${OSXCROSS_TRIPLE}-strip")
set(CMAKE_INSTALL_NAME_TOOL "/osxcross/bin/${OSXCROSS_TRIPLE}-install_name_tool")

# Look for target headers/libraries in the cross prefix and in the SDK only.
set(CMAKE_FIND_ROOT_PATH "/opt/macos" "/osxcross/SDK/MacOSX26.1.sdk")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
