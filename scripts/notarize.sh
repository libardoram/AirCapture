#!/bin/bash
set -e

# Sign and notarize the AirCapture DMG
# This script handles code signing and Apple notarization for distribution
#
# APPLE_ID and TEAM_ID are expected to be set as environment variables.
# The easiest way is to run this via distribute.sh, which sets them for you.
# To run standalone, export them first:
#
#   APPLE_ID=your@apple.id TEAM_ID=YOURTEAMID bash notarize.sh

# Validate required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ]; then
    echo "Error: APPLE_ID and TEAM_ID environment variables must be set."
    echo ""
    echo "Run via distribute.sh (recommended), or export them manually:"
    echo "APPLE_ID=your@apple.id TEAM_ID=YOURTEAMID bash notarize.sh"
    exit 1
fi

echo "Signing and notarizing AirCapture DMG..."
echo "Apple ID : $APPLE_ID"
echo "Team ID  : $TEAM_ID"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(dirname "$SCRIPT_DIR")/build"

# Look up the full Developer ID identity from the keychain by Team ID.
# This avoids hardcoding the developer name — codesign needs the full string.
DEVELOPER_ID=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" \
    | grep "($TEAM_ID)" \
    | head -1 \
    | sed 's/.*"\(Developer ID Application:.*\)"/\1/')

if [ -z "$DEVELOPER_ID" ]; then
    echo "Error: No 'Developer ID Application' certificate found in keychain for Team ID $TEAM_ID"
    echo "Make sure your Developer ID Application certificate is installed in Keychain Access."
    exit 1
fi

echo "Identity: $DEVELOPER_ID"

# Find the DMG file
DMG_FILE=$(ls -t "$BUILD_DIR"/AirCapture*.dmg 2>/dev/null | head -1)

if [ -z "$DMG_FILE" ]; then
    echo "Error: No DMG file found in $BUILD_DIR"
    echo "Run ./create-dmg.sh first"
    exit 1
fi

echo "Found DMG: $(basename "$DMG_FILE")"

# Sign the DMG
echo "Signing DMG..."
codesign --sign "$DEVELOPER_ID" \
    --timestamp \
    --options runtime \
    --force \
    "$DMG_FILE"

# Verify signature
echo "Verifying DMG signature..."
codesign -vvv --deep --strict "$DMG_FILE"

# Submit for notarization
echo "Submitting to Apple for notarization..."
echo "(This may take a few minutes...)"

# Submit and capture the result
NOTARIZE_OUTPUT=$(xcrun notarytool submit "$DMG_FILE" \
    --keychain-profile "notarytool-password" \
    --wait 2>&1)

echo "$NOTARIZE_OUTPUT"

# Check if notarization was accepted
if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    echo ""
    echo "Notarization successful!"
    
    # Staple the notarization ticket to the DMG
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_FILE"
    
    echo ""
    echo "Success! Your DMG is ready for distribution!"
    echo "DMG location: $DMG_FILE"
    echo ""
    echo "You can now distribute this DMG. Users will be able to:"
    echo "• Download and open it without warnings"
    echo "• Install the app by dragging to Applications"
    echo "• Run the app without Gatekeeper issues"
else
    echo ""
    echo "Notarization failed."
    
    # Extract submission ID from output
    SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    
    if [ -n "$SUBMISSION_ID" ]; then
        echo "Checking detailed logs for submission: $SUBMISSION_ID"
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "notarytool-password" \
            /tmp/notarization-log.json
        
        if [ -f /tmp/notarization-log.json ]; then
            echo ""
            echo "Notarization issues:"
            cat /tmp/notarization-log.json | grep -A 5 '"issues"'
        fi
    fi
    exit 1
fi
