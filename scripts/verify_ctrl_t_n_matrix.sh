#!/usr/bin/env bash
set -euo pipefail

# Runs a small verification matrix for the zellij Ctrl+T then n flow.
# This covers both software keyboard tap semantics and typed-key semantics.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPRO_SCRIPT="$SCRIPT_DIR/repro_ctrl_t_n_with_axe.sh"

if [[ ! -x "$REPRO_SCRIPT" ]]; then
  echo "Missing executable repro script at $REPRO_SCRIPT" >&2
  exit 1
fi

echo "==> Case 1: softkey + tap"
CTRL_SEQUENCE_METHOD=softkey \
FOLLOWUP_INPUT_METHOD=tap \
FOLLOWUP_TEXT=n \
KEY_SEQUENCE_REPETITIONS="${KEY_SEQUENCE_REPETITIONS:-3}" \
VERIFY_NEW_TAB=1 \
"$REPRO_SCRIPT"

echo
echo "==> Case 2: toolbar_inserttext_auto"
CTRL_SEQUENCE_METHOD=toolbar_inserttext_auto \
KEY_SEQUENCE_REPETITIONS="${KEY_SEQUENCE_REPETITIONS:-1}" \
VERIFY_NEW_TAB=1 \
"$REPRO_SCRIPT"

echo
echo "Verification matrix passed."
