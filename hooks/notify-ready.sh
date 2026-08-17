#!/bin/bash
# Claude Code hook — signal that a session wants your attention.
#
# Reads the hook payload on stdin so the notification can name the project.
# Wire to Stop (Claude finished its turn) and Notification (Claude needs input).
#
# Two side effects, both wanted:
#   1. A macOS notification naming the project.
#   2. An "attention marker" recording which terminal window this session lives
#      in, so scripts/jump-to-attention.sh can focus it from a single key.
#
# The marker is what makes jump-to-attention possible at all. Claude Code has no
# working action for "go to the session that needs me" — strip:* and
# chat:attention* exist by name but have no implementation behind them — so the
# jump happens at the window-manager level instead, and this is where the
# address for it gets written down.
#
# Environment seams, both used by the tests:
#   CLAUDE_MACROPAD_DRY_RUN=1     print "<project>\t<message>", send no
#                                 notification. The marker is still written.
#   CLAUDE_MACROPAD_STATE_DIR=DIR write markers under DIR instead of
#                                 ~/.claude/macropad.

set -uo pipefail

# shellcheck source=lib-attention.sh
. "$(dirname "$0")/lib-attention.sh"

PAYLOAD=$(cat 2>/dev/null || true)

json_field() {
    # $1 = field name. Empty string if jq is absent or the field is missing.
    command -v jq >/dev/null 2>&1 || return 0
    printf '%s' "$PAYLOAD" | jq -r --arg f "$1" '.[$f] // empty' 2>/dev/null
}

CWD=$(json_field cwd)
EVENT=$(json_field hook_event_name)
SESSION_ID=$(json_field session_id)

if [ -n "$CWD" ]; then
    PROJECT=$(basename "$CWD")
else
    PROJECT="Claude Code"
fi

case "$EVENT" in
    Notification) MESSAGE="Needs your input" ;;
    *)            MESSAGE="Ready for input" ;;
esac

# ------------------------------------------------------------------ marker ---
ATTENTION_DIR=$(macropad_attention_dir)
KEY=$(macropad_key "$SESSION_ID")

if [ -n "$KEY" ] && mkdir -p "$ATTENTION_DIR" 2>/dev/null; then
    # epoch <TAB> project <TAB> iterm session uuid <TAB> tty
    printf '%s\t%s\t%s\t%s\n' \
        "$(date +%s)" "$PROJECT" "$(macropad_iterm_session)" "$(macropad_tty)" \
        > "$ATTENTION_DIR/$KEY" 2>/dev/null
fi

# ------------------------------------------------------------------ notify ---
if [ "${CLAUDE_MACROPAD_DRY_RUN:-0}" = "1" ]; then
    printf '%s\t%s\n' "$PROJECT" "$MESSAGE"
    exit 0
fi

# Arguments, not interpolation — project names come from the filesystem.
osascript \
    -e 'on run {msg, ttl}' \
    -e 'display notification msg with title ttl' \
    -e 'end run' \
    "$MESSAGE" "Claude Code — $PROJECT" 2>/dev/null

exit 0
