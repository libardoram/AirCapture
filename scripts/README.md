# AirCapture Distribution Scripts

This directory contains scripts for building, packaging, and distributing AirCapture.

## Prerequisites

Before using these scripts, ensure you have:

1. **Apple Developer Account** with a Developer ID Application certificate installed
2. **App-Specific Password** for notarization — create one at https://appleid.apple.com/account/manage
3. **Xcode Command Line Tools** installed

## Configuration

All identity configuration lives in one place: the top of `distribute.sh`.

Open `distribute.sh` and fill in your credentials:

```bash
APPLE_ID=your@apple.id
TEAM_ID=YOURTEAMID
```

That's it. `distribute.sh` exports these as environment variables and all other scripts read them from the environment — you never need to edit `notarize.sh` or `setup-notarization.sh`.

## One-Time Setup

Store your notarization credentials in the macOS keychain once before your first build:

```bash
APPLE_ID=your@apple.id TEAM_ID=YOURTEAMID bash setup-notarization.sh
```

Or just run it via `distribute.sh` — it will pick up the values you set at the top.

## Usage

### Option 1: Complete Distribution (Recommended)

After setting `APPLE_ID` and `TEAM_ID` in `distribute.sh`, run:

```bash
bash distribute.sh
```

This will:
1. Build the Release version
2. Create a DMG
3. Sign and notarize the DMG

### Option 2: Individual Steps

Each script can also be run standalone by exporting the environment variables first:

```bash
export APPLE_ID=your@apple.id
export TEAM_ID=YOURTEAMID

# Step 1: Build Release version (no credentials needed)
bash build-release.sh

# Step 2: Create DMG (no credentials needed)
bash create-dmg.sh

# Step 3: Sign and notarize
bash notarize.sh
```

## Output

All build artifacts are placed in the `build/` directory at the repo root.

The final notarized DMG will be named: `AirCapture-{version}.dmg`

## Distribution

After successful notarization, you can:

1. **Upload to your website** — users can download directly
2. **Share via cloud storage** — Dropbox, Google Drive, etc.
3. **Distribute via email** — for beta testers

The notarized DMG will:
- Open without warnings on macOS
- Install by drag-and-drop to Applications
- Run without Gatekeeper issues

## Troubleshooting

### Build Fails

- Ensure Xcode project is up to date: `xcodegen generate`
- Check that UxPlay vendor libraries are built
- Verify Developer ID certificate is installed in Keychain

### Notarization Fails

- Check credentials: `xcrun notarytool history --keychain-profile "notarytool-password"`
- View detailed logs in the `notarize.sh` output
- Ensure the app is properly code-signed
- Check hardened runtime entitlements

### DMG Issues

- Verify the app exists in `build/` before creating the DMG
- Check Finder permissions if the layout script fails
- Ensure sufficient disk space for temporary files

## Version Management

The DMG filename includes the version from `Info.plist`. To update the version:

1. Edit `AirCapture/Sources/Info.plist`
2. Update `CFBundleShortVersionString`
3. Rebuild using `bash distribute.sh`

## Code Signing Details

- **Debug builds**: Signed with "Apple Development"
- **Release builds**: Signed with "Developer ID Application"
- **Hardened runtime**: Enabled for notarization
- **Entitlements**: Minimal (no sandbox for GPL compliance)

## Support

- Apple notarization docs: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Xcode code signing guide: https://developer.apple.com/support/code-signing/
