#!/bin/bash

# Setup notarization credentials
# Run this once before your first distribution build to store your Apple
# credentials securely in the macOS keychain.
#
# APPLE_ID and TEAM_ID are expected to be set as environment variables.
# The easiest way is to run this via distribute.sh, which sets them for you.
# To run standalone, export them first:
#
#   APPLE_ID=your@apple.id TEAM_ID=YOURTEAMID bash setup-notarization.sh

# Validate required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ]; then
    echo "Error: APPLE_ID and TEAM_ID environment variables must be set."
    echo ""
    echo "Run via distribute.sh (recommended), or export them manually:"
    echo "APPLE_ID=your@apple.id TEAM_ID=YOURTEAMID bash setup-notarization.sh"
    exit 1
fi

echo "Setting up notarization credentials..."
echo "Apple ID : $APPLE_ID"
echo "Team ID  : $TEAM_ID"
echo ""
echo "You'll also need an app-specific password."
echo "Create one at: https://appleid.apple.com/account/manage"
echo ""
echo "This will store the credentials securely in your macOS keychain."
echo ""

xcrun notarytool store-credentials "notarytool-password" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID"

echo ""
echo "Credentials stored!"
echo ""
echo "You can now run distribute.sh to build and notarize your app."
