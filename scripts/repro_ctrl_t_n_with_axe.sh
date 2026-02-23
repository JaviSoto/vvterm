#!/usr/bin/env bash
set -euo pipefail

# Repro loop for iOS hardware-key handling using AXe on Simulator.
# Runs VVTerm with input tracing enabled, injects Ctrl+T then N, and captures logs.

SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"
BUNDLE_ID="${BUNDLE_ID:-es.javisoto.vvterm}"
DERIVED_DATA="${DERIVED_DATA:-/Volumes/RunnerCache/DerivedData/javi}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${LOG_DIR:-$PWD/build/input-trace-$STAMP}"

mkdir -p "$LOG_DIR"

if ! command -v axe >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/axe ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  else
    echo "axe is required (brew install cameroncooke/axe/axe)" >&2
    exit 1
  fi
fi

UDID="$(
  xcrun simctl list devices available |
    awk -F '[()]' -v target="$SIM_NAME" '$0 ~ target" \\(" { print $2; exit }'
)"

if [[ -z "$UDID" ]]; then
  echo "Could not find simulator named '$SIM_NAME'" >&2
  exit 1
fi

echo "Using simulator: $SIM_NAME ($UDID)"

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b

echo "Building VVTerm (Debug simulator)..."
xcodebuild \
  -project VVTerm.xcodeproj \
  -scheme VVTerm \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  build >"$LOG_DIR/build.log" 2>&1

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name 'VVTerm.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate built VVTerm.app" >&2
  exit 1
fi

echo "Installing and launching VVTerm with input tracing..."
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

APP_STDOUT="$LOG_DIR/app-stdout.log"
APP_STDERR="$LOG_DIR/app-stderr.log"
xcrun simctl launch \
  --terminate-running-process \
  --stdout="$APP_STDOUT" \
  --stderr="$APP_STDERR" \
  "$UDID" \
  "$BUNDLE_ID" \
  --vvterm-input-harness \
  --vvterm-input-trace >"$LOG_DIR/launch.log" 2>&1

sleep 2

# Focus terminal area (best effort) then inject the key sequence under investigation.
axe tap -x 200 -y 450 --udid "$UDID" || true
sleep 0.4
axe key-combo --modifiers 224 --key 23 --udid "$UDID"  # Ctrl+T
sleep 0.2
axe key 17 --udid "$UDID"                               # N
sleep 1

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo
echo "Captured traces:"
TRACE_LOG="$LOG_DIR/inputtrace.log"
cat "$APP_STDERR" "$APP_STDOUT" 2>/dev/null | grep -E "InputTrace|HarnessWrite" >"$TRACE_LOG" || true
if [[ -s "$TRACE_LOG" ]]; then
  cat "$TRACE_LOG"
elif [[ -s "$APP_STDERR" ]]; then
  echo "(no InputTrace lines captured; tail of app stderr follows)"
  tail -n 80 "$APP_STDERR"
elif [[ -s "$APP_STDOUT" ]]; then
  echo "(no InputTrace lines captured; tail of app stdout follows)"
  tail -n 80 "$APP_STDOUT"
else
  echo "(no InputTrace lines captured)"
fi

echo
echo "Artifacts:"
echo "  $LOG_DIR"
