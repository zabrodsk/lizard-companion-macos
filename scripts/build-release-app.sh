#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/Menu bar Companion app.xcodeproj"
SCHEME="Menu bar Companion app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build-ci}"
CONFIGURATION="Release"
APP_NAME="Menu bar Companion app.app"
APP_OUTPUT_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
LOG_PATH="$DERIVED_DATA_PATH/xcodebuild.log"

mkdir -p "$DERIVED_DATA_PATH"

if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  clean build >"$LOG_PATH" 2>&1; then
  echo "xcodebuild failed. See log: $LOG_PATH" >&2
  tail -n 60 "$LOG_PATH" >&2 || true
  exit 1
fi

if [[ ! -d "$APP_OUTPUT_PATH" ]]; then
  echo "App bundle not found at: $APP_OUTPUT_PATH" >&2
  exit 1
fi

# stdout is used by other scripts/workflows.
echo "$APP_OUTPUT_PATH"
