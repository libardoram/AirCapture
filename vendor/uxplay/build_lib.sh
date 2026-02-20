#!/bin/bash
# Build script for UxPlay airplay static library
# Produces: build/libairplay.a, build/libplayfair.a, build/libllhttp.a

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENDOR_DIR="$SCRIPT_DIR"
BUILD_DIR="$VENDOR_DIR/build"

# Use Xcode.app explicitly — override xcode-select via DEVELOPER_DIR
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
XCODE_TOOLCHAIN="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain"
XCODE_SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
CC="$XCODE_TOOLCHAIN/usr/bin/cc"

echo "=== Building UxPlay airplay library ==="
echo "Source:        $VENDOR_DIR"
echo "Build:         $BUILD_DIR"
echo "DEVELOPER_DIR: $DEVELOPER_DIR"
echo "CC:            $CC"
echo "SDK:           $XCODE_SDK"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Configure with CMake
cd "$BUILD_DIR"
/opt/homebrew/bin/cmake "$VENDOR_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_OSX_SYSROOT="$XCODE_SDK"

# Build
/opt/homebrew/bin/cmake --build . --parallel $(sysctl -n hw.ncpu)

echo ""
echo "=== Build complete ==="
echo "Static libraries:"
find "$BUILD_DIR" -name "*.a" -exec echo "  {}" \;

# Create a combined fat library for convenience
echo ""
echo "Creating combined library..."
libtool -static -o "$BUILD_DIR/libuxplay_combined.a" \
    "$BUILD_DIR/libairplay.a" \
    "$BUILD_DIR/libplayfair.a" \
    "$BUILD_DIR/libllhttp.a"
echo "Combined: $BUILD_DIR/libuxplay_combined.a"

# Also copy headers needed for bridging
INCLUDE_DIR="$BUILD_DIR/include"
mkdir -p "$INCLUDE_DIR"
cp "$VENDOR_DIR/lib/raop.h" "$INCLUDE_DIR/"
cp "$VENDOR_DIR/lib/dnssd.h" "$INCLUDE_DIR/"
cp "$VENDOR_DIR/lib/stream.h" "$INCLUDE_DIR/"
cp "$VENDOR_DIR/lib/raop_ntp.h" "$INCLUDE_DIR/"
cp "$VENDOR_DIR/lib/logger.h" "$INCLUDE_DIR/"
cp "$VENDOR_DIR/lib/airplay_video.h" "$INCLUDE_DIR/"
echo "Headers copied to: $INCLUDE_DIR/"

echo ""
echo "=== Done ==="
