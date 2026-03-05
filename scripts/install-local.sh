#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Menu bar Companion app"
DERIVED="$ROOT_DIR/build-local"
APP_NAME="Menu bar Companion app.app"
APP_SRC="$DERIVED/Build/Products/Release/$APP_NAME"
APP_DST="/Applications/$APP_NAME"

echo "==> Building unsigned Release app..."
xcodebuild \
  -project "$ROOT_DIR/Menu bar Companion app.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  clean build

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build did not produce app bundle at: $APP_SRC" >&2
  exit 1
fi

echo "==> Installing to /Applications..."
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

echo "==> Cleaning extended attributes..."
xattr -cr "$APP_DST"
dot_clean "$APP_DST" || true

echo "==> Applying ad-hoc signature..."
codesign --force --deep --sign - "$APP_DST"

echo "==> Clearing quarantine attributes..."
xattr -cr "$APP_DST"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_DST"

echo "==> Launching app..."
open "$APP_DST"

echo "Done. App installed at: $APP_DST"
