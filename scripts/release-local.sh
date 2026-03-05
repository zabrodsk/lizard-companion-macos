#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TAG="${1:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

usage() {
  cat <<USAGE
Usage:
  SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \\
  NOTARYTOOL_PROFILE="your-notary-profile" \\
  ./scripts/release-local.sh [vX.Y.Z]

What it does:
  1) Builds Release app
  2) Signs app + DMG (Developer ID)
  3) Notarizes + staples DMG
  4) Creates ZIP + checksums
  5) Optionally uploads to GitHub release tag if tag is provided
USAGE
}

if [[ -z "$SIGN_IDENTITY" || -z "$NOTARYTOOL_PROFILE" ]]; then
  echo "Missing required env vars." >&2
  usage
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/release-staging" "$DIST_DIR/zip-staging"

export SIGN_IDENTITY
export NOTARYTOOL_PROFILE

echo "==> Building + signing + notarizing DMG..."
DMG_PATH="$("$ROOT_DIR/scripts/make-dmg.sh" | tail -n 1)"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at: $DMG_PATH" >&2
  exit 1
fi

echo "==> Creating ZIP artifact..."
APP_PATH="$("$ROOT_DIR/scripts/build-release-app.sh" | tail -n 1)"
mkdir -p "$DIST_DIR/zip-staging"
cp -R "$APP_PATH" "$DIST_DIR/zip-staging/"
ZIP_PATH="$DIST_DIR/LizardCompanion-macOS.zip"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/zip-staging/Menu bar Companion app.app" "$ZIP_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

ls -lah "$DIST_DIR"

echo "==> Gatekeeper validation..."
spctl -a -vv -t open "$DMG_PATH" || true
xcrun stapler validate "$DMG_PATH" || true

if [[ -n "$TAG" ]]; then
  echo "==> Uploading assets to GitHub release: $TAG"
  gh release upload "$TAG" \
    "$DMG_PATH" "$DMG_PATH.sha256" \
    "$ZIP_PATH" "$ZIP_PATH.sha256" \
    --clobber --repo zabrodsk/lizard-companion-macos
  echo "Uploaded assets to release $TAG"
else
  echo "==> No tag provided. Skipping GitHub upload."
fi

echo "Done. Artifacts are in: $DIST_DIR"
