#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TAG="${1:-}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/release-local.sh [vX.Y.Z]

What it does:
  1) Builds Release app
  2) Creates ZIP + checksum
  3) Optionally uploads assets to GitHub release tag if provided
USAGE
}

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/zip-staging"

echo "==> Building Release app..."
if ! APP_PATH="$("$ROOT_DIR/scripts/build-release-app.sh" | tail -n 1)"; then
  echo "build-release-app.sh failed." >&2
  echo "Check xcode build log: $ROOT_DIR/build-ci/xcodebuild.log" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at: $APP_PATH" >&2
  exit 1
fi

echo "==> Creating ZIP artifact..."
mkdir -p "$DIST_DIR/zip-staging"
cp -R "$APP_PATH" "$DIST_DIR/zip-staging/"
ZIP_PATH="$DIST_DIR/LizardCompanion-macOS.zip"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/zip-staging/Menu bar Companion app.app" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

ls -lah "$DIST_DIR"

if [[ -n "$TAG" ]]; then
  echo "==> Uploading assets to GitHub release: $TAG"
  gh release upload "$TAG" \
    "$ZIP_PATH" "$ZIP_PATH.sha256" \
    --clobber --repo zabrodsk/lizard-companion-macos
  echo "Uploaded assets to release $TAG"
else
  echo "==> No tag provided. Skipping GitHub upload."
fi

echo "Done. Artifacts are in: $DIST_DIR"
