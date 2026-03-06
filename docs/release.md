# Release Guide

This project publishes a macOS `.zip` containing `Menu bar Companion app.app`.

## GitHub Release Flow

Push a tag that starts with `v`, for example:

```bash
git tag v0.1.2
git push origin v0.1.2
```

GitHub Actions will:

- build the Release app
- sign and notarize it when signing secrets are configured
- generate `dist/LizardCompanion-macOS.zip`
- upload the ZIP and checksum to the GitHub release for that tag

Workflow file:

- `.github/workflows/release-zip.yml`

## Required GitHub Secrets For Notarized Releases

Configure these repository secrets to produce a notarized ZIP from GitHub Actions:

- `APPLE_DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_DEVELOPER_ID_APP_CERT_BASE64`
- `APPLE_DEVELOPER_ID_APP_CERT_PASSWORD`

If these secrets are missing, the workflow still builds a ZIP, but it will not be notarized.

## Local Release Flow

Build local artifacts only:

```bash
./scripts/release-local.sh
```

Build and upload local artifacts to an existing GitHub release tag:

```bash
./scripts/release-local.sh v0.1.2
```

To produce a notarized ZIP locally, export:

```bash
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="TEAMID"
```

Alternative local notarization auth:

```bash
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARYTOOL_PROFILE="your-notary-profile"
```

## Verification

After building a notarized app locally, verify it before upload:

```bash
spctl -a -vvv "build-ci/Build/Products/Release/Menu bar Companion app.app"
codesign --verify --deep --strict --verbose=2 "build-ci/Build/Products/Release/Menu bar Companion app.app"
```

After downloading from GitHub Releases, verify the ZIP checksum:

```bash
shasum -a 256 -c LizardCompanion-macOS.zip.sha256
```

## Troubleshooting

If macOS says the app is damaged, the release was almost certainly not notarized or the downloaded app still has quarantine metadata from a non-notarized build.

End-user workaround:

```bash
xattr -dr com.apple.quarantine /Applications/"Menu bar Companion app.app"
open /Applications/"Menu bar Companion app.app"
```
