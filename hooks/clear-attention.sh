#!/bin/bash
# Claude Code hook — this session no longer wants your attention.
#
# Wire to UserPromptSubmit. Once you have typed into a session it is not waiting
# on you any more, whether you got there with scripts/jump-to-attention.sh or
# just clicked the window.
#
# Without this, markers are only ever cleared by the jump script, so any session
# you walk to by hand stays queued forever and the jump key eventually cycles
# through windows with nothing waiting in them.
#
# Environment seam, used by tests/test-attention.sh:
#   CLAUDE_MACROPAD_STATE_DIR=DIR read markers under DIR instead of
#                                 ~/.claude/macropad.

set -uo pipefail

# shellcheck source=lib-attention.sh
. "$(dirname "$0")/lib-attention.sh"

PAYLOAD=$(cat 2>/dev/null || true)

session_id() {
    command -v jq >/dev/null 2>&1 || return 0
    printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null
}

ATTENTION_DIR=$(macropad_attention_dir)
KEY=$(macropad_key "$(session_id)")

[ -n "$KEY" ] && rm -f "$ATTENTION_DIR/$KEY" 2>/dev/null

exit 0
