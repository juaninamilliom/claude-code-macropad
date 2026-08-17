#!/bin/bash
# Focus the Claude Code session that has been waiting on you longest.
#
# This is the thing Claude Code itself cannot do. Its action list contains
# chat:attentionDown, chat:attentionUp and thirteen strip:* actions that sound
# exactly like this feature — and all sixteen are declared without an
# implementation, so binding a key to one is silently a no-op. Session switching
# has to happen at the window-manager level, which is what this does.
#
# hooks/notify-ready.sh drops an attention marker whenever a session finishes a
# turn or asks for input. This reads them oldest-first, focuses that terminal
# window, and clears its marker — so pressing the key repeatedly walks you
# through everything that wants you, longest-waiting first, and stops when the
# queue is empty.
#
# Usage:
#   jump-to-attention.sh            focus the longest-waiting session
#   jump-to-attention.sh --list     print the queue, change nothing
#
# Environment seams, used by tests/test-attention.sh:
#   CLAUDE_MACROPAD_STATE_DIR=DIR   read markers under DIR
#   CLAUDE_MACROPAD_DRY_RUN=1       print "<project>\t<uuid>" for the session it
#                                   would focus, focus nothing, clear nothing

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# The library lives beside the hooks. In a clone that is ../hooks; once
# installed it is alongside this script in ~/.claude/hooks. Try both so the
# script works from either place.
for candidate in "$HERE/../hooks/lib-attention.sh" "$HERE/lib-attention.sh"; do
    if [ -f "$candidate" ]; then
        # shellcheck source=../hooks/lib-attention.sh
        . "$candidate"
        LIB_FOUND=1
        break
    fi
done
if [ "${LIB_FOUND:-0}" != "1" ]; then
    echo "jump-to-attention: cannot find lib-attention.sh next to this script or in ../hooks" >&2
    exit 2
fi

ATTENTION_DIR=$(macropad_attention_dir)
DRY_RUN="${CLAUDE_MACROPAD_DRY_RUN:-0}"

notify() {
    [ "$DRY_RUN" = "1" ] && return 0
    osascript \
        -e 'on run {msg, ttl}' \
        -e 'display notification msg with title ttl' \
        -e 'end run' \
        "$1" "Claude Code" 2>/dev/null
}

# Every marker, longest-waiting first, as "epoch<TAB>project<TAB>uuid<TAB>tty".
# A marker with no epoch is corrupt and is dropped rather than sorted to the
# front, where it would jam the queue on every press.
queue() {
    [ -d "$ATTENTION_DIR" ] || return 0
    for f in "$ATTENTION_DIR"/*; do
        [ -f "$f" ] || continue
        IFS=$'\t' read -r epoch project uuid tty < "$f" || continue
        case "$epoch" in
            ''|*[!0-9]*) rm -f "$f" 2>/dev/null; continue ;;
        esac
        printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "${project:-Claude Code}" "$uuid" "$tty" "$f"
    done | sort -n
}

if [ "${1:-}" = "--list" ]; then
    n=0
    while IFS=$'\t' read -r epoch project uuid tty _; do
        [ -n "$epoch" ] || continue
        n=$((n + 1))
        printf '%s  waiting %ss  %s\n' "$project" "$(( $(date +%s) - epoch ))" "${uuid:-${tty:-?}}"
    done < <(queue)
    [ "$n" -eq 0 ] && echo "nothing waiting"
    exit 0
fi

# Focus an iTerm2 session by its id. Returns "ok" or "notfound"; anything else
# means iTerm2 was not reachable at all.
focus_iterm() {
    osascript \
        -e 'on run {sid}' \
        -e 'tell application "iTerm2"' \
        -e '  repeat with w in windows' \
        -e '    repeat with t in tabs of w' \
        -e '      repeat with s in sessions of t' \
        -e '        if (id of s) is sid then' \
        -e '          select w' \
        -e '          select t' \
        -e '          select s' \
        -e '          activate' \
        -e '          return "ok"' \
        -e '        end if' \
        -e '      end repeat' \
        -e '    end repeat' \
        -e '  end repeat' \
        -e 'end tell' \
        -e 'return "notfound"' \
        -e 'end run' \
        "$1" 2>/dev/null
}

# Walk the queue oldest-first. A marker whose window has since been closed is
# stale: drop it and move on rather than making the key look broken.
FOUND=0
while IFS=$'\t' read -r epoch project uuid tty file; do
    [ -n "$epoch" ] || continue

    if [ -z "$uuid" ]; then
        # A terminal that exposed no iTerm2 session id. Nothing to focus by, so
        # the marker is useless — say so once and drop it.
        echo "jump-to-attention: $project has no iTerm2 session id; skipping" >&2
        rm -f "$file" 2>/dev/null
        continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s\t%s\n' "$project" "$uuid"
        FOUND=1
        break
    fi

    case "$(focus_iterm "$uuid")" in
        ok)
            rm -f "$file" 2>/dev/null
            FOUND=1
            break
            ;;
        notfound)
            rm -f "$file" 2>/dev/null   # window is gone
            ;;
        *)
            echo "jump-to-attention: could not talk to iTerm2" >&2
            exit 1
            ;;
    esac
done < <(queue)

if [ "$FOUND" -eq 0 ]; then
    notify "Nothing waiting"
    [ "$DRY_RUN" = "1" ] && echo "nothing waiting"
fi

exit 0
