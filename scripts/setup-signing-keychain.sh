#!/usr/bin/env bash
set -euo pipefail

# Expected env vars:
# APPLE_DEVELOPER_ID_APP_CERT_BASE64
# APPLE_DEVELOPER_ID_APP_CERT_PASSWORD
# SIGNING_KEYCHAIN_PASSWORD (optional, auto-generated fallback)

if [[ -z "${APPLE_DEVELOPER_ID_APP_CERT_BASE64:-}" || -z "${APPLE_DEVELOPER_ID_APP_CERT_PASSWORD:-}" ]]; then
  echo "Signing certificate variables are missing; skipping keychain setup." >&2
  exit 0
fi

KEYCHAIN_NAME="build-signing.keychain-db"
KEYCHAIN_PATH="$HOME/Library/Keychains/$KEYCHAIN_NAME"
KEYCHAIN_PASSWORD="${SIGNING_KEYCHAIN_PASSWORD:-$(uuidgen)}"
CERT_PATH="$RUNNER_TEMP/developer_id_app.p12"

printf '%s' "$APPLE_DEVELOPER_ID_APP_CERT_BASE64" | base64 --decode > "$CERT_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$APPLE_DEVELOPER_ID_APP_CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcrun
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security list-keychain -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/[\"]//g')

echo "SIGNING_KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
echo "SIGNING_KEYCHAIN_PASSWORD=$KEYCHAIN_PASSWORD" >> "$GITHUB_ENV"
