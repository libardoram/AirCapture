#!/bin/bash
set -e

# Build Release version of AirCapture
# This script builds the app with proper code signing for distribution

echo "Building AirCapture Release..."

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
PROJECT_DIR="$REPO_DIR/AirCapture"
BUILD_DIR="$REPO_DIR/build"
SCHEME="AirCapture"
CONFIGURATION="Release"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Set Xcode developer directory
export DEVELOPER_DIR="/Applications/Xcode v3.app/Contents/Developer"

# Regenerate Xcode project
echo "Regenerating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate --spec project.yml

# Build
echo "Building Release configuration..."
xcodebuild \
    -project "$PROJECT_DIR/AirCapture.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    clean build

# Copy app to build directory
echo "Copying app bundle..."
cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/AirCapture.app" "$BUILD_DIR/"

# Verify code signing
echo "Verifying code signature..."
codesign -vvv --deep --strict "$BUILD_DIR/AirCapture.app"

echo ""
echo "Build complete!"
echo "App location: $BUILD_DIR/AirCapture.app"
echo ""
echo "Next steps:"
echo "  1. Run ./create-dmg.sh to create a DMG"
echo "  2. Run ./notarize.sh to sign and notarize the DMG"
