#!/bin/bash
set -e

# Create a DMG for AirCapture distribution
# This script creates a nice DMG with the app and a link to Applications

echo "Creating AirCapture DMG..."

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
BUILD_DIR="$REPO_DIR/build"
APP_PATH="$BUILD_DIR/AirCapture.app"
DMG_NAME="AirCapture"
VOLUME_NAME="AirCapture"
DMG_TEMP="$BUILD_DIR/${DMG_NAME}_temp.dmg"
DMG_FINAL="$BUILD_DIR/${DMG_NAME}.dmg"

# Get version from Info.plist if available
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_FINAL="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: AirCapture.app not found at $APP_PATH"
    echo "Run ./build-release.sh first"
    exit 1
fi

# Clean up any existing DMG files
echo "Cleaning up previous DMG files..."
rm -f "$DMG_TEMP" "$DMG_FINAL"

# Create a temporary directory for DMG contents
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app to staging directory
echo "Copying app to staging area..."
cp -R "$APP_PATH" "$DMG_STAGING/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$DMG_STAGING/Applications"

# Calculate size needed for DMG
echo "Calculating DMG size..."
SIZE=$(du -sm "$DMG_STAGING" | awk '{print $1}')
SIZE=$((SIZE + 50)) # Add 50MB padding

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create \
    -size ${SIZE}m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    "$DMG_TEMP"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify -noautoopen | grep "/Volumes/${VOLUME_NAME}" | awk '{print $3}')

if [ -z "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount DMG"
    exit 1
fi

# Copy contents to mounted DMG
echo "Copying contents to DMG..."
cp -R "$DMG_STAGING/"* "$MOUNT_DIR/"

# Set background and icon positions (optional, requires Finder scripting)
# This can be enhanced later with a custom background image

# Set icon size and arrange icons
echo "Arranging DMG layout..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "AirCapture.app" of container window to {120, 150}
        set position of item "Applications" of container window to {380, 150}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the temporary DMG
echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to final compressed DMG
echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL"

# Clean up
echo "Cleaning up..."
rm -f "$DMG_TEMP"
rm -rf "$DMG_STAGING"

echo ""
echo "DMG created successfully!"
echo "DMG location: $DMG_FINAL"
echo ""
echo "Next step:"
echo "Run ./notarize.sh to sign and notarize the DMG"
