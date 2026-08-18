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
# through everything that wants you, longest-waiting first.
#
# When nothing is waiting it moves to the next Claude Code session instead. The
# queue drains by design, and a key that goes dead once you have caught up reads
# as broken rather than as finished, so the same key does both jobs: what needs
# you first, then just the next session.
#
# Usage:
#   jump-to-attention.sh            focus the longest-waiting session, or the
#                                   next one if nothing is waiting
#   jump-to-attention.sh --list     print the queue, change nothing
#
# Environment seams, used by tests/test-attention.sh:
#   CLAUDE_MACROPAD_STATE_DIR=DIR   read markers under DIR
#   CLAUDE_MACROPAD_DRY_RUN=1       print what it would focus; focus nothing,
#                                   clear nothing
#   CLAUDE_MACROPAD_CURRENT_SESSION pin the "you are here" session
#   CLAUDE_MACROPAD_SESSIONS        pin the session list, as "uuid<TAB>tty" lines

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
    # A notification is the nicer signal but needs this app to be allowed in
    # Notification settings, which it will not be the first time. The sound
    # needs no permission at all, and "the key did something" is the part worth
    # guaranteeing: without it, a press with nothing to jump to is
    # indistinguishable from a key that is not wired up.
    afplay /System/Library/Sounds/Tink.aiff >/dev/null 2>&1 &
    osascript \
        -e 'on run {msg, ttl}' \
        -e 'display notification msg with title ttl' \
        -e 'end run' \
        "$1" "Claude Code" 2>/dev/null
}

# The session iTerm2 is showing right now, or empty when iTerm2 is not the
# frontmost app. Used to skip the window you are already looking at: pressing
# the key there should take you to the *next* thing that wants you, not
# redraw the window under your nose.
#
# Only skip when iTerm2 is actually frontmost. Coming from another application
# you want the waiting session focused even if it happens to be iTerm2's
# current one, because you cannot see it.
current_session() {
    # Tests pin this rather than asking the window server, so the skip logic
    # above can be exercised without moving a real window around.
    if [ -n "${CLAUDE_MACROPAD_CURRENT_SESSION:-}" ]; then
        printf '%s' "$CLAUDE_MACROPAD_CURRENT_SESSION"
        return 0
    fi
    [ "$DRY_RUN" = "1" ] && return 0
    osascript \
        -e 'tell application "System Events" to set f to name of first process whose frontmost is true' \
        -e 'if f is not "iTerm2" then return ""' \
        -e 'tell application "iTerm2" to return id of current session of current tab of current window' \
        2>/dev/null
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

# ------------------------------------------------------------------ cycle ---
# Nothing is waiting. Rather than stop dead, move to the next Claude Code
# session anyway — which is the other half of what a session key is for, and
# what people expect when they press it a second time.
#
# The queue drains by design: it refills only when a session finishes a turn or
# asks for input. Once you have visited everything, further presses had nothing
# to do, and four "nothing waiting" sounds in a row reads as a broken key rather
# than as an empty queue.
#
# No state is kept for this. A Claude session is an iTerm2 session whose tty has
# a claude process on it, which is true whether or not this repo's hooks ever
# ran there.
claude_sessions() {
    if [ -n "${CLAUDE_MACROPAD_SESSIONS:-}" ]; then
        printf '%s\n' "$CLAUDE_MACROPAD_SESSIONS"
        return 0
    fi
    [ "$DRY_RUN" = "1" ] && return 0

    # Space separated, not newline: awk's -v mangles embedded newlines and
    # errors out with "newline in string". A tty name never contains a space.
    #
    # ps prints "??" for a process with no controlling terminal, so filter those
    # out rather than searching iTerm2 for a session on /dev/??.
    local ttys
    ttys=$(ps -A -o tty=,comm= 2>/dev/null \
           | awk '$1 != "??" && $2 ~ /(^|\/)claude$/ { print "/dev/"$1 }' \
           | sort -u | tr '\n' ' ')
    [ -n "${ttys// /}" ] || return 0

    # "\t", not the bare word `tab`. Inside `tell application "iTerm2"` the word
    # tab is iTerm2's own tab class, so it coerces to the literal string "tab"
    # and every line comes out unparseable — silently, since the result is still
    # a well-formed string.
    osascript \
        -e 'tell application "iTerm2"' \
        -e '  set out to ""' \
        -e '  repeat with w in windows' \
        -e '    repeat with t in tabs of w' \
        -e '      repeat with s in sessions of t' \
        -e '        set out to out & (id of s) & "\t" & (tty of s) & linefeed' \
        -e '      end repeat' \
        -e '    end repeat' \
        -e '  end repeat' \
        -e '  return out' \
        -e 'end tell' 2>/dev/null \
    | awk -F'\t' -v list="$ttys" '
        BEGIN { n = split(list, a, " "); for (i = 1; i <= n; i++) if (a[i] != "") want[a[i]] = 1 }
        NF >= 2 && ($2 in want) { print $2 "\t" $1 }' \
    | sort | awk -F'\t' '{ print $2 "\t" $1 }'
}

# The entry after $1 in that list, wrapping. With no current session — iTerm2
# is not frontmost — the first entry is the right answer, because anywhere in
# iTerm2 is a move from where you are.
cycle_next() {
    local current="$1"
    printf '%s\n' "$2" | awk -F'\t' -v cur="$current" '
        { id[NR] = $1 }
        END {
            if (NR == 0) exit
            if (cur == "") { print id[1]; exit }
            for (i = 1; i <= NR; i++) if (id[i] == cur) { print id[i % NR + 1]; exit }
            print id[1]
        }'
}

# --sessions prints what the cycling modes can see. Worth having as a command
# rather than only as internal state: when this list is empty, --next does
# nothing and says "no other session", which is indistinguishable from a key
# that is not wired up. It was empty once for a subtle AppleScript reason and
# nothing surfaced it.
if [ "${1:-}" = "--sessions" ]; then
    n=0
    while IFS=$'\t' read -r uuid tty; do
        [ -n "$uuid" ] || continue
        n=$((n + 1))
        printf '%s  %s\n' "$tty" "$uuid"
    done < <(claude_sessions)
    [ "$n" -eq 0 ] && echo "no Claude Code sessions visible in iTerm2"
    exit 0
fi

# --new starts a Claude Code session in a fresh iTerm2 window.
#
# Claude Code has no action for this either. strip:new was the only candidate
# and it is on the unimplemented list with the rest, so "new chat" is a window
# the script opens, not a shortcut it sends.
#
# The new window starts in the same directory as the session you launched it
# from, which is what makes it useful: one window per worktree stays one window
# per worktree. Falling back to $HOME is deliberate — a new session somewhere
# harmless beats no session at all.
if [ "${1:-}" = "--new" ]; then
    DIR="$HOME"
    CUR_TTY=$(osascript \
        -e 'tell application "iTerm2" to return tty of current session of current tab of current window' \
        2>/dev/null)
    if [ -n "$CUR_TTY" ]; then
        # The claude process on that tty, and then its working directory. Its
        # cwd rather than the shell's, because a session that was started
        # somewhere and then cd'd elsewhere should reopen where it is running.
        CUR_PID=$(ps -t "${CUR_TTY#/dev/}" -o pid=,comm= 2>/dev/null \
                  | awk '$2 ~ /(^|\/)claude$/ { print $1; exit }')
        if [ -n "$CUR_PID" ]; then
            FOUND_DIR=$(lsof -a -p "$CUR_PID" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
            [ -d "${FOUND_DIR:-}" ] && DIR="$FOUND_DIR"
        fi
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf 'new\t%s\n' "$DIR"
        exit 0
    fi

    osascript \
        -e 'on run {c}' \
        -e 'tell application "iTerm2"' \
        -e '  set w to (create window with default profile)' \
        -e '  tell current session of w to write text c' \
        -e '  activate' \
        -e 'end tell' \
        -e 'end run' \
        "cd $(printf '%q' "$DIR") && claude" >/dev/null 2>&1 \
      || { echo "jump-to-attention: could not open a new iTerm2 window" >&2; exit 1; }
    exit 0
fi

# --next is the plain "switch chat" key: always move to the next session,
# whether or not anything is waiting.
#
# Two keys rather than one because they answer different questions. "Take me to
# whatever needs me" has to prioritise by wait time and go quiet when the queue
# is empty. "Take me to the next session" has to move every single press, or it
# is not a switch key. Making one key do both means one of them is always
# compromised.
if [ "${1:-}" = "--next" ]; then
    CURRENT=$(current_session)
    NEXT=$(cycle_next "$CURRENT" "$(claude_sessions)")

    if [ -n "$NEXT" ] && [ "$NEXT" != "$CURRENT" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            printf 'cycle\t%s\n' "$NEXT"
            exit 0
        fi
        if [ "$(focus_iterm "$NEXT")" = "ok" ]; then
            # Arriving counts as having seen it, same as the jump key.
            rm -f "$ATTENTION_DIR/$NEXT" 2>/dev/null
            exit 0
        fi
    fi

    notify "No other session"
    [ "$DRY_RUN" = "1" ] && echo "no other session"
    exit 0
fi

# Walk the queue oldest-first. A marker whose window has since been closed is
# stale: drop it and move on rather than making the key look broken.
CURRENT=$(current_session)
FOUND=0
while IFS=$'\t' read -r epoch project uuid tty file; do
    [ -n "$epoch" ] || continue

    # Already looking at it. Clear the marker — you have seen it — and carry on
    # to whatever else is waiting.
    if [ -n "$CURRENT" ] && [ "$uuid" = "$CURRENT" ]; then
        rm -f "$file" 2>/dev/null
        continue
    fi

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
    SESSIONS=$(claude_sessions)
    NEXT=$(cycle_next "$CURRENT" "$SESSIONS")

    # One session, and it is the one you are in: there is genuinely nowhere to
    # go, and cycling to yourself is the "nothing happened" this was meant to
    # fix.
    if [ -n "$NEXT" ] && [ "$NEXT" != "$CURRENT" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            printf 'cycle\t%s\n' "$NEXT"
            FOUND=1
        elif [ "$(focus_iterm "$NEXT")" = "ok" ]; then
            FOUND=1
        fi
    fi
fi

if [ "$FOUND" -eq 0 ]; then
    notify "Nothing waiting"
    [ "$DRY_RUN" = "1" ] && echo "nothing waiting"
fi

exit 0
