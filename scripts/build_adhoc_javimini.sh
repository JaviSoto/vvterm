#!/usr/bin/env bash
set -euo pipefail

# Headless ad-hoc archive/export flow that works on javimini.
# Requires the project to be on the manual-signing distribution branch.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_ID="${TEAM_ID:-6V6XY979JQ}"
APP_PROFILE="${APP_PROFILE:-VVTerm Codex AdHoc 20260620-174531}"
EXT_PROFILE="${EXT_PROFILE:-VVTerm LiveActivity AdHoc 20260620-174532}"
SIGNING_CERTIFICATE="${SIGNING_CERTIFICATE:-4F5890E9E95A22EB4341488E18BC37B8883227CD}"
FORCE_PRO_TESTING="${FORCE_PRO_TESTING:-1}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"
KEYCHAIN_PASSWORD_FILE="${KEYCHAIN_PASSWORD_FILE:-$HOME/.codex/secrets/javimini-keychain-password}"

if [[ ! -f "$KEYCHAIN_PASSWORD_FILE" ]]; then
  echo "missing keychain password file: $KEYCHAIN_PASSWORD_FILE" >&2
  exit 1
fi

KEYCHAIN_PASSWORD="$(<"$KEYCHAIN_PASSWORD_FILE")"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/build/adhoc-manual-$TS"
ARCHIVE_PATH="$OUT_DIR/VVTerm.xcarchive"
EXPORT_PATH="$OUT_DIR/export"
EXPORT_OPTIONS="$OUT_DIR/ExportOptions.plist"

mkdir -p "$OUT_DIR"

security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
if /usr/bin/xattr -p com.apple.quarantine "$KEYCHAIN_PATH" >/dev/null 2>&1; then
  /usr/bin/xattr -d com.apple.quarantine "$KEYCHAIN_PATH"
fi

XCODE_EXTRA_ARGS=()
if [[ "$FORCE_PRO_TESTING" == "1" ]]; then
  echo "Enabling forced Pro unlock for testing builds"
  XCODE_EXTRA_ARGS+=("SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) VVTERM_FORCE_PRO_FOR_TESTING")
fi

/usr/bin/xcodebuild \
  -project "$PROJECT_ROOT/VVTerm.xcodeproj" \
  -scheme VVTerm \
  -configuration Release \
  -destination generic/platform=iOS \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  "${XCODE_EXTRA_ARGS[@]}" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive | tee "$OUT_DIR/archive.log"

cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>ad-hoc</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>$SIGNING_CERTIFICATE</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>es.javisoto.vvterm</key>
    <string>$APP_PROFILE</string>
    <key>es.javisoto.vvterm.liveactivity</key>
    <string>$EXT_PROFILE</string>
  </dict>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
PLIST

/usr/bin/xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" | tee "$OUT_DIR/export.log"

echo "IPA: $EXPORT_PATH/VVTerm.ipa"
echo "Logs: $OUT_DIR"
