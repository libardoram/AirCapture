#!/bin/bash
set -e

# Complete AirCapture distribution workflow
# This script builds, packages, signs, and notarizes AirCapture for distribution
#
# ─── CONFIGURATION ────────────────────────────────────────────────────────────
# Fill in your Apple ID and Team ID before running.
APPLE_ID=your@apple.id
TEAM_ID=YOURTEAMID
# ──────────────────────────────────────────────────────────────────────────────

# Validate that the placeholders have been replaced
if [ "$APPLE_ID" = "your@apple.id" ] || [ "$TEAM_ID" = "YOURTEAMID" ]; then
    echo "Error: APPLE_ID and TEAM_ID must be set at the top of distribute.sh before running."
    exit 1
fi

export APPLE_ID
export TEAM_ID

echo "Starting AirCapture distribution build..."
echo "Apple ID : $APPLE_ID"
echo "Team ID  : $TEAM_ID"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Step 1: Build Release
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/3: Building Release version..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/build-release.sh"

# Step 2: Create DMG
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/3: Creating DMG..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/create-dmg.sh"

# Step 3: Sign and Notarize
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/3: Signing and notarizing..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/notarize.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Distribution build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your notarized DMG is ready for distribution!"
echo "Location: $(dirname "$SCRIPT_DIR")/build/"
echo ""
