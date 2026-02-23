#!/usr/bin/env bash
set -euo pipefail

# Repro loop for iOS hardware-key handling using AXe on Simulator.
# Runs VVTerm input harness against a real zellij session and flags leaked pane input.

SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"
BUNDLE_ID="${BUNDLE_ID:-}"
DERIVED_DATA="${DERIVED_DATA:-/Volumes/RunnerCache/DerivedData/javi}"
ZELLIJ_BIN="${ZELLIJ_BIN:-/opt/homebrew/bin/zellij}"
ZELLIJ_PROXY_SCRIPT="${ZELLIJ_PROXY_SCRIPT:-$PWD/scripts/zellij_harness_proxy.py}"
KEY_SEQUENCE_REPETITIONS="${KEY_SEQUENCE_REPETITIONS:-1}"
CTRL_SEQUENCE_METHOD="${CTRL_SEQUENCE_METHOD:-hardware}"
FOLLOWUP_INPUT_METHOD="${FOLLOWUP_INPUT_METHOD:-key}"
FOLLOWUP_TEXT="${FOLLOWUP_TEXT:-n}"
CTRL_T_TO_FOLLOWUP_DELAY="${CTRL_T_TO_FOLLOWUP_DELAY:-0.2}"
VERIFY_NEW_TAB="${VERIFY_NEW_TAB:-1}"
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

if [[ ! -x "$ZELLIJ_BIN" ]]; then
  echo "zellij binary not executable at '$ZELLIJ_BIN'" >&2
  exit 1
fi

if [[ ! -x "$ZELLIJ_PROXY_SCRIPT" ]]; then
  echo "zellij proxy script not executable at '$ZELLIJ_PROXY_SCRIPT'" >&2
  exit 1
fi

PORT_FILE="$LOG_DIR/harness-port.txt"
SUMMARY_FILE="$LOG_DIR/harness-summary.json"
PROXY_LOG="$LOG_DIR/harness-proxy.log"
python3 "$ZELLIJ_PROXY_SCRIPT" \
  --log-dir "$LOG_DIR" \
  --port-file "$PORT_FILE" \
  --summary-file "$SUMMARY_FILE" \
  --zellij-bin "$ZELLIJ_BIN" \
  >"$PROXY_LOG" 2>&1 &
PROXY_PID=$!

cleanup() {
  if kill -0 "$PROXY_PID" >/dev/null 2>&1; then
    kill "$PROXY_PID" >/dev/null 2>&1 || true
    wait "$PROXY_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in {1..200}; do
  if [[ -s "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -s "$PORT_FILE" ]]; then
  echo "Timed out waiting for zellij harness proxy port" >&2
  tail -n 120 "$PROXY_LOG" >&2 || true
  exit 1
fi
HARNESS_PORT="$(tr -d '\r\n' <"$PORT_FILE")"
if [[ -z "$HARNESS_PORT" ]]; then
  echo "Harness proxy did not provide a port" >&2
  exit 1
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
DETECTED_BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true
)"
if [[ -z "$DETECTED_BUNDLE_ID" ]]; then
  echo "Could not resolve CFBundleIdentifier from $APP_PATH/Info.plist" >&2
  exit 1
fi
if [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != "$DETECTED_BUNDLE_ID" ]]; then
  echo "Provided BUNDLE_ID '$BUNDLE_ID' does not match built app bundle '$DETECTED_BUNDLE_ID'; using built app bundle."
fi
BUNDLE_ID="$DETECTED_BUNDLE_ID"
echo "Using bundle identifier: $BUNDLE_ID"

echo "Installing and launching VVTerm with input tracing..."
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

APP_STDOUT="$LOG_DIR/app-stdout.log"
APP_STDERR="$LOG_DIR/app-stderr.log"
export SIMCTL_CHILD_VVTERM_INPUT_HARNESS=1
export SIMCTL_CHILD_VVTERM_INPUT_TRACE=1
export SIMCTL_CHILD_VVTERM_INPUT_HARNESS_TCP_HOST=127.0.0.1
export SIMCTL_CHILD_VVTERM_INPUT_HARNESS_TCP_PORT="$HARNESS_PORT"
xcrun simctl launch \
  --terminate-running-process \
  --stdout="$APP_STDOUT" \
  --stderr="$APP_STDERR" \
  "$UDID" \
  "$BUNDLE_ID" \
  --vvterm-input-harness \
  --vvterm-input-trace \
  --vvterm-input-harness-tcp-host 127.0.0.1 \
  --vvterm-input-harness-tcp-port "$HARNESS_PORT" >"$LOG_DIR/launch.log" 2>&1

sleep 2
xcrun simctl io "$UDID" screenshot "$LOG_DIR/pre-keys.png" >/dev/null 2>&1 || true

# Focus terminal area (best effort) then inject the key sequence under investigation.
axe tap -x 200 -y 450 --udid "$UDID" || true
sleep 0.4
for _ in $(seq 1 "$KEY_SEQUENCE_REPETITIONS"); do
  case "$CTRL_SEQUENCE_METHOD" in
    hardware)
      axe key-combo --modifiers 224 --key 23 --udid "$UDID"  # Ctrl+T
      ;;
    softkey)
      axe tap --label "Ctrl" --udid "$UDID"
      sleep 0.1
      axe tap --label "t" --udid "$UDID"
      ;;
    softkey_type)
      axe tap --label "Ctrl" --udid "$UDID"
      sleep 0.1
      axe type "t" --udid "$UDID"
      ;;
    *)
      echo "Unsupported CTRL_SEQUENCE_METHOD='$CTRL_SEQUENCE_METHOD' (expected 'hardware', 'softkey', or 'softkey_type')" >&2
      exit 1
      ;;
  esac
  sleep "$CTRL_T_TO_FOLLOWUP_DELAY"
  case "$FOLLOWUP_INPUT_METHOD" in
    key)
      axe key 17 --udid "$UDID"                           # N
      ;;
    type)
      axe type "$FOLLOWUP_TEXT" --udid "$UDID"
      ;;
    tap)
      axe tap --label "$FOLLOWUP_TEXT" --udid "$UDID"
      ;;
    *)
      echo "Unsupported FOLLOWUP_INPUT_METHOD='$FOLLOWUP_INPUT_METHOD' (expected 'key', 'type', or 'tap')" >&2
      exit 1
      ;;
  esac
  sleep 0.3
done
sleep 0.8
xcrun simctl io "$UDID" screenshot "$LOG_DIR/post-keys.png" >/dev/null 2>&1 || true

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

for _ in {1..80}; do
  if ! kill -0 "$PROXY_PID" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if kill -0 "$PROXY_PID" >/dev/null 2>&1; then
  kill "$PROXY_PID" >/dev/null 2>&1 || true
  wait "$PROXY_PID" >/dev/null 2>&1 || true
fi

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
echo "Harness summary:"
if [[ -s "$SUMMARY_FILE" ]]; then
  cat "$SUMMARY_FILE"
else
  echo "FAIL: no summary file captured; zellij verification did not run."
  exit 3
fi

if ! python3 - "$SUMMARY_FILE" <<'PY'
import json
import sys
summary_path = sys.argv[1]
summary = json.load(open(summary_path, "r", encoding="utf-8"))
if not summary.get("connection_opened"):
    raise SystemExit("Harness proxy never accepted a client connection.")
PY
then
  echo "FAIL: invalid harness summary."
  exit 4
fi

SESSION_NAME="$(python3 - "$SUMMARY_FILE" <<'PY'
import json
import sys
summary = json.load(open(sys.argv[1], "r", encoding="utf-8"))
print(summary.get("session_name", ""))
PY
)"
if [[ -z "$SESSION_NAME" ]]; then
  echo "FAIL: harness summary did not include a zellij session name."
  exit 5
fi

TAB_NAMES_FILE="$LOG_DIR/tab-names.txt"
"$ZELLIJ_BIN" --session "$SESSION_NAME" action query-tab-names >"$TAB_NAMES_FILE" 2>&1 || true
echo
echo "Tab names after key sequence:"
cat "$TAB_NAMES_FILE"

PANE_INPUT_FILE="$LOG_DIR/pane-input.bin"
if [[ -s "$PANE_INPUT_FILE" ]]; then
  echo
  echo "FAIL: detected leaked pane input bytes from Ctrl+T then N sequence."
  echo "Hex dump of leaked bytes:"
  xxd -g 1 "$PANE_INPUT_FILE" | head -n 40
  exit 2
fi

if [[ "$VERIFY_NEW_TAB" == "1" ]]; then
  if ! grep -q "Tab #2" "$TAB_NAMES_FILE"; then
    echo
    echo "FAIL: Ctrl+T then N did not create a new zellij tab."
    exit 6
  fi
fi

echo
echo "PASS: Ctrl+T then N created a new zellij tab with no pane-input leak."

echo
echo "Artifacts:"
echo "  $LOG_DIR"
