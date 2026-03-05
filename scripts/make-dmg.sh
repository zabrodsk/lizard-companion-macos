#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
VOL_NAME="Lizard Companion"
DMG_NAME="LizardCompanion-macOS.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

APP_PATH="$("$ROOT_DIR/scripts/build-release-app.sh" | tail -n 1)"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Normalize metadata before packing
xattr -cr "$STAGING_DIR" || true
dot_clean "$STAGING_DIR" || true

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing DMG with identity: $SIGN_IDENTITY"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "${NOTARYTOOL_PROFILE:-}" || (-n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}") ]]; then
  "$ROOT_DIR/scripts/notarize-dmg.sh" "$DMG_PATH"
fi

# Optional checksum output
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "$DMG_PATH"
