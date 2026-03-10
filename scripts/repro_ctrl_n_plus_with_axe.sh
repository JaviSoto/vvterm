#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRIMARY_TEXT=n \
PRIMARY_KEYCODE=17 \
FOLLOWUP_TEXT=+ \
CTRL_SEQUENCE_METHOD="${CTRL_SEQUENCE_METHOD:-toolbar_inserttext_auto}" \
FOLLOWUP_INPUT_METHOD="${FOLLOWUP_INPUT_METHOD:-symbol_tap}" \
HARNESS_PROFILE=resize-plus-new-tab \
VERIFY_NEW_TAB=1 \
"$SCRIPT_DIR/repro_ctrl_t_n_with_axe.sh"
