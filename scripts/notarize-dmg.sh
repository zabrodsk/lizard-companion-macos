#!/usr/bin/env bash
set -euo pipefail

DMG_PATH="${1:-}"
if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "Usage: $0 /path/to/file.dmg" >&2
  exit 1
fi

# Option A: keychain profile (preferred)
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  exit 0
fi

# Option B: Apple ID + app-specific password + team id
if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  exit 0
fi

echo "Notarization credentials are not set; skipping notarization." >&2
