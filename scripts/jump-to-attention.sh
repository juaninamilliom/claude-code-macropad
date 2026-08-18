#!/bin/bash
# Focus the Claude Code session that has been waiting on you longest.
#
# This is the thing Claude Code itself cannot do. Its action list contains
# chat:attentionDown, chat:attentionUp and thirteen strip:* actions that sound
# exactly like this feature — and all fifteen are declared without an
# implementation, so binding a key to one is silently a no-op. Session switching
# has to happen at the window-manager level, which is what this does.
#
# hooks/notify-ready.sh drops an attention marker whenever a session finishes a
# turn or asks for input. This reads them oldest-first, focuses that terminal
# window, and clears its marker — so pressing the key repeatedly walks you
# through everything that wants you, longest-waiting first.
#
# When nothing is waiting it does nothing but sound, and that restraint is the
# point: this key answers "who needs me?", and if the answer is nobody it must
# say so. An earlier version fell back to cycling, on the theory that a silent
# key reads as broken. With --next now carrying that job, the fallback only made
# the two keys behave identically — pressing "jump to what needs me" walked
# through idle sessions exactly like the switch key, so it no longer told you
# anything.
#
# "Needs you" is not inferred from the session. It is recorded by the hooks:
# Stop fires when Claude finishes a turn, Notification when it wants input, and
# UserPromptSubmit clears the marker because typing is responding.
#
# Usage:
#   jump-to-attention.sh            focus the session waiting longest, or sound
#                                   if none is waiting
#   jump-to-attention.sh --next     next session, waiting or not
#   jump-to-attention.sh --new      new session in a new window
#   jump-to-attention.sh --list     print the queue, change nothing
#   jump-to-attention.sh --sessions print the sessions --next can see
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

# Every run appends what it decided. Append, not overwrite: a macropad press is
# tested by pressing it several times, and a log that keeps only the last run
# erases the comparison that makes the trace readable.
#
# The first line is written before anything that can block, so an empty tail
# means "the app never ran" — a pad or Smart Action problem — while a start line
# with nothing after it means "the app ran and hung", which is almost always an
# Automation permission prompt waiting off-screen. Those two look identical from
# the keyboard and need completely different fixes.
#
# Rebuilding the app to add logging is the thing to avoid: osacompile re-signs
# the bundle, macOS reads that as a different application, and its Automation
# permission for iTerm2 reverts to unasked. The next launch blocks on a dialog a
# keypress gives you no reason to look for. Debugging that way breaks the thing
# it is measuring, which is why this lives in the script instead.
LOG="${CLAUDE_MACROPAD_STATE_DIR:-$HOME/.claude/macropad}/log"
dbg() {
    [ "$DRY_RUN" = "1" ] && return 0
    printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG" 2>/dev/null
}
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$(dirname "$LOG")" 2>/dev/null
    # Keep it bounded rather than letting a key press grow a file forever.
    if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 400 ]; then
        tail -200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null
    fi
    # Who launched us: an app bundle (a pad press) or a shell (me testing it)?
    # The distinction is the first thing worth knowing and the easiest to lose.
    dbg "---- ${*:-<no args>} launched by $(ps -o comm= -p "$PPID" 2>/dev/null | sed 's|.*/||')"
fi

# osascript with a deadline. Without one, an Automation permission prompt blocks
# the script forever and the key just never does anything — no error, no exit,
# nothing in the log after the start line. With one, that state names itself.
run_osa() {
    local secs="$1"; shift
    local out tmp rc
    tmp=$(mktemp 2>/dev/null) || { osascript "$@" 2>/dev/null; return $?; }
    osascript "$@" > "$tmp" 2>/dev/null &
    local pid=$! i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -gt $((secs * 10)) ] && { kill -9 "$pid" 2>/dev/null; rm -f "$tmp"; return 124; }
        sleep 0.1
    done
    wait "$pid" 2>/dev/null; rc=$?
    out=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"
    printf '%s' "$out"
    return $rc
}

notify() {
    [ "$DRY_RUN" = "1" ] && return 0
    # A notification is the nicer signal but needs this app to be allowed in
    # Notification settings, which it will not be the first time. The beep needs
    # no permission at all, and "the key did something" is the part worth
    # guaranteeing: without it, a press with nothing to jump to is
    # indistinguishable from a key that is not wired up.
    #
    # `beep`, not `afplay`. afplay works, but it is a media player, and macOS
    # asks apps that touch media for media-library access — a dialog naming the
    # bare Claude Code binary ("2.1.234", since the versioned executable carries
    # no Info.plist for TCC to read a name from) is a baffling thing to be shown
    # by a key that switches terminal windows. beep is the system alert sound
    # and asks for nothing. Whether afplay was truly the trigger was never
    # confirmed; this costs nothing and removes the question.
    osascript -e 'beep' >/dev/null 2>&1 &
    osascript \
        -e 'on run {msg, ttl}' \
        -e 'display notification msg with title ttl' \
        -e 'end run' \
        "$1" "Claude Code" 2>/dev/null
}

# The session iTerm2 is showing right now. Used to skip the window you are
# already looking at: pressing a key there should take you to the *next* thing,
# not redraw the window under your nose.
#
# This deliberately does NOT check whether iTerm2 is the frontmost application,
# and that is the whole point. An earlier version did, returning empty unless
# iTerm2 was frontmost — reasoning that from another app you cannot see iTerm2's
# current session anyway. It broke the main path completely.
#
# A macropad triggers this by launching an app. That app is frontmost while it
# runs, so a frontmost check reports "not iTerm2" on **every** press from the
# pad. With no current session, cycling starts from the first entry in the list,
# which is frequently the window you are already in — so the key does nothing,
# every time, while working perfectly when run from a shell. That is exactly how
# it was reported: "new session works, next session does not."
#
# iTerm2 tracks its own current session whether or not it has focus, which is
# the right answer here: a pad user is working in iTerm2 by definition.
current_session() {
    # Tests pin this rather than asking the window server, so the skip logic
    # can be exercised without moving a real window around.
    if [ -n "${CLAUDE_MACROPAD_CURRENT_SESSION:-}" ]; then
        printf '%s' "$CLAUDE_MACROPAD_CURRENT_SESSION"
        return 0
    fi
    [ "$DRY_RUN" = "1" ] && return 0
    local out rc
    # Two readings, because they can disagree and the difference is the bug.
    #
    # `current window` is iTerm2's own pointer, and AppleScript moves it: a
    # script that selects a window sets it, whether or not the user ever looked
    # there. `frontmost of w` is the window macOS actually has in front, which
    # is where the user is. Prefer the OS truth and fall back to iTerm2's
    # pointer when no window is frontmost, which is what happens while another
    # application — such as the app a macropad key launches — holds focus.
    out=$(run_osa 5 -e 'tell application "iTerm2"' \
        -e '  repeat with w in windows' \
        -e '    if frontmost of w then' \
        -e '      return (id of current session of current tab of w)' \
        -e '    end if' \
        -e '  end repeat' \
        -e '  return (id of current session of current tab of current window)' \
        -e 'end tell')
    rc=$?
    if [ "$rc" = "124" ]; then
        dbg "current_session TIMED OUT after 5s — an Automation permission prompt is probably waiting"
        return 0
    fi
    printf '%s' "$out"
}

# A one-line picture of every iTerm2 window: which session it shows and whether
# macOS has it in front. Logged before and after focusing so the log answers
# "did the window actually move?" rather than only "did the script think so?",
# which is the question two rounds of this were unable to settle.
window_table() {
    [ "$DRY_RUN" = "1" ] && return 0
    run_osa 5 -e 'tell application "iTerm2"' \
        -e '  set out to ""' \
        -e '  repeat with wi from 1 to (count windows)' \
        -e '    set w to window wi' \
        -e '    repeat with s in sessions of (current tab of w)' \
        -e '      set out to out & (tty of s) & "/" & (frontmost of w) & " "' \
        -e '    end repeat' \
        -e '  end repeat' \
        -e '  return out' \
        -e 'end tell'
}

# Every marker, longest-waiting first, as "epoch<TAB>project<TAB>uuid<TAB>tty".
# A marker with no epoch is corrupt and is dropped rather than sorted to the
# front, where it would jam the queue on every press.
queue() {
    [ -d "$ATTENTION_DIR" ] || return 0
    for f in "$ATTENTION_DIR"/*; do
        [ -f "$f" ] || continue
        # cut, not `IFS=$'\t' read`. Tab is IFS *whitespace*, so read collapses
        # runs of it and an empty field silently disappears: a marker with no
        # session id parses with the tty shifted into the uuid column, the
        # script tries to focus a window whose id is "/dev/ttys000", gets
        # notfound, and deletes a marker for a session that really was waiting.
        # cut treats each tab as one delimiter and keeps empty fields empty.
        local line
        line=$(head -1 "$f" 2>/dev/null) || continue
        epoch=$(printf '%s' "$line" | cut -f1)
        project=$(printf '%s' "$line" | cut -f2)
        uuid=$(printf '%s' "$line" | cut -f3)
        tty=$(printf '%s' "$line" | cut -f4)
        case "$epoch" in
            ''|*[!0-9]*) rm -f "$f" 2>/dev/null; continue ;;
        esac
        # \x1f, not a tab, between the fields this emits. `read` collapses runs
        # of IFS *whitespace*, and a tab is whitespace, so an empty uuid would
        # vanish on the way out and shift every later field left — the same bug
        # this function was just fixed for on the way in. The unit separator is
        # not whitespace, so empty fields survive.
        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$epoch" "${project:-Claude Code}" "$uuid" "$tty" "$f"
    done | sort -n
}

if [ "${1:-}" = "--list" ]; then
    n=0
    while IFS=$'\x1f' read -r epoch project uuid tty _; do
        [ -n "$epoch" ] || continue
        n=$((n + 1))
        printf '%s  waiting %ss  %s\n' "$project" "$(( $(date +%s) - epoch ))" "${uuid:-${tty:-?}}"
    done < <(queue)
    [ "$n" -eq 0 ] && echo "nothing waiting"
    exit 0
fi

# Focus an iTerm2 session by its id. Returns "ok" or "notfound"; anything else
# means iTerm2 was not reachable at all.
#
# `activate` comes FIRST, and the order is the whole fix.
#
# Selecting the window and then activating looks natural and is wrong: activate
# brings iTerm2 forward showing its own key window, which overrides the
# selection that just happened. It only misbehaves when another application is
# frontmost — and a macropad press always runs while the app it launched is
# frontmost, so it failed exactly where it mattered and worked in every shell
# test. Worse, the AppleScript still returns "ok": the selection did happen, it
# was simply undone a moment later.
#
# Reproduced by making Finder frontmost and raising a background iTerm2 window:
# select-then-activate reports ok and moves nothing; activate-then-select moves
# the window. Activating first means nothing re-fronts after the selection.
focus_iterm() {
    local out rc
    out=$(run_osa 8 \
        -e 'on run {sid}' \
        -e 'tell application "iTerm2"' \
        -e '  activate' \
        -e '  delay 0.2' \
        -e '  repeat with w in windows' \
        -e '    repeat with t in tabs of w' \
        -e '      repeat with s in sessions of t' \
        -e '        if (id of s) is sid then' \
        -e '          select w' \
        -e '          select t' \
        -e '          select s' \
        -e '          return "ok"' \
        -e '        end if' \
        -e '      end repeat' \
        -e '    end repeat' \
        -e '  end repeat' \
        -e 'end tell' \
        -e 'return "notfound"' \
        -e 'end run' \
        "$1")
    rc=$?
    if [ "$rc" = "124" ]; then
        dbg "focus_iterm TIMED OUT after 8s — an Automation permission prompt is probably waiting"
        printf 'timeout'
        return 0
    fi
    printf '%s' "$out"
}

# ---------------------------------------------------------------- sessions ---
# Every Claude Code session iTerm2 can see. Used by --next, and to resolve a
# marker that recorded a tty but no session id.
#
# No state is kept: a Claude session is an iTerm2 session whose tty has a claude
# process on it, which is true whether or not this repo's hooks ever ran there.
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
    local raw rc
    raw=$(run_osa 8 \
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
        -e 'end tell')
    rc=$?
    if [ "$rc" = "124" ]; then
        dbg "claude_sessions TIMED OUT after 8s — an Automation permission prompt is probably waiting"
        return 0
    fi
    printf '%s\n' "$raw" \
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
    SESSIONS=$(claude_sessions)
    NEXT=$(cycle_next "$CURRENT" "$SESSIONS")
    dbg "current=${CURRENT:-<none>}"
    dbg "sessions=$(printf '%s' "$SESSIONS" | tr '\n' ' ')"
    dbg "next=${NEXT:-<none>}"

    if [ -n "$NEXT" ] && [ "$NEXT" != "$CURRENT" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            printf 'cycle\t%s\n' "$NEXT"
            exit 0
        fi
        dbg "windows before: $(window_table)"
        RESULT=$(focus_iterm "$NEXT")
        dbg "focus=${RESULT:-<empty: iTerm2 unreachable, or an Automation prompt is waiting>}"
        sleep 1
        dbg "windows after:  $(window_table)"
        if [ "$RESULT" = "ok" ]; then
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
SESSION_LIST=$(claude_sessions)
dbg "jump: current=${CURRENT:-EMPTY} queued=$(queue | grep -c . || true)"
FOUND=0
while IFS=$'\x1f' read -r epoch project uuid tty file; do
    [ -n "$epoch" ] || continue

    # Already looking at it. Clear the marker — you have seen it — and carry on
    # to whatever else is waiting.
    if [ -n "$CURRENT" ] && [ "$uuid" = "$CURRENT" ]; then
        rm -f "$file" 2>/dev/null
        continue
    fi

    # A marker can legitimately carry no iTerm2 session id. The hook reads it
    # from ITERM_SESSION_ID, and that variable is not always inherited — it was
    # observed missing from a running Claude Code session that had it earlier.
    # The tty is always recorded, because it comes from walking the process
    # tree rather than from the environment, so resolve through that instead of
    # discarding a session that really is waiting.
    if [ -z "$uuid" ] && [ -n "$tty" ]; then
        uuid=$(printf '%s\n' "$SESSION_LIST" \
               | awk -F'\t' -v want="$tty" '$2 == want { print $1; exit }')
        dbg "jump: $project had no uuid; resolved $tty -> ${uuid:-NOTHING}"
    fi

    if [ -z "$uuid" ]; then
        # Neither an id nor a tty that matches a live window: the session is
        # gone, so the marker is stale rather than useful.
        dbg "jump: $project cannot be located (tty=${tty:-none}); dropping"
        rm -f "$file" 2>/dev/null
        continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '%s\t%s\n' "$project" "$uuid"
        FOUND=1
        break
    fi

    RESULT=$(focus_iterm "$uuid")
    dbg "jump: focusing $project ($uuid) -> $RESULT"
    case "$RESULT" in
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


    # One session, and it is the one you are in: there is genuinely nowhere to
    # go, and cycling to yourself is the "nothing happened" this was meant to
    # fix.
if [ "$FOUND" -eq 0 ]; then
    dbg "jump: nowhere to go — sounding"
    notify "Nothing waiting"
    [ "$DRY_RUN" = "1" ] && echo "nothing waiting"
else
    dbg "jump: done"
fi

exit 0
