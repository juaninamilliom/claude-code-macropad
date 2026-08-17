#!/bin/bash
# Claude Code hook — signal that a session wants your attention.
#
# Reads the hook payload on stdin so the notification can name the project.
# Wire to Stop (Claude finished its turn) and Notification (Claude needs input).
#
# CLAUDE_MACROPAD_DRY_RUN=1 prints "<project>\t<message>" and exits without
# side effects. That is how tests/test-notify-ready.sh drives it.

set -uo pipefail

PAYLOAD=$(cat 2>/dev/null || true)

json_field() {
    # $1 = field name. Empty string if jq is absent or the field is missing.
    command -v jq >/dev/null 2>&1 || return 0
    printf '%s' "$PAYLOAD" | jq -r --arg f "$1" '.[$f] // empty' 2>/dev/null
}

CWD=$(json_field cwd)
EVENT=$(json_field hook_event_name)

if [ -n "$CWD" ]; then
    PROJECT=$(basename "$CWD")
else
    PROJECT="Claude Code"
fi

case "$EVENT" in
    Notification) MESSAGE="Needs your input" ;;
    *)            MESSAGE="Ready for input" ;;
esac

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
