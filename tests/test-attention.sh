#!/bin/bash
# Exercises the attention pipeline: the hooks that write and clear markers, and
# the script that consumes them.
#
# ITERM_SESSION_ID is set explicitly by every case below rather than inherited.
# The marker key falls back to the tty and then to the payload's session_id when
# that variable is absent, so a test that let it come from the environment would
# key markers differently under iTerm2, under CI, and under a different
# terminal — and would pass or fail accordingly. Setting it pins the key.
#
# Nothing here touches a real ~/.claude: CLAUDE_MACROPAD_STATE_DIR redirects
# every read and write into a temp directory, and CLAUDE_MACROPAD_DRY_RUN keeps
# the scripts from sending notifications or focusing windows.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }
pass() { echo "PASS: $*"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_MACROPAD_STATE_DIR="$TMP/state"
ATT="$CLAUDE_MACROPAD_STATE_DIR/attention"

UUID_A="AAAAAAAA-0000-0000-0000-000000000001"
UUID_B="BBBBBBBB-0000-0000-0000-000000000002"

payload() {
  printf '{"cwd":"%s","hook_event_name":"%s","session_id":"%s"}' \
    "${1:-/tmp/demo-project}" "${2:-Stop}" "${3:-sess-1}"
}

# --- 1. Stop writes a marker, keyed by the iTerm2 session uuid ---------------
rm -rf "$ATT"
payload /tmp/alpha Stop sess-1 \
  | ITERM_SESSION_ID="w0t0p0:$UUID_A" CLAUDE_MACROPAD_DRY_RUN=1 \
    bash "$ROOT/hooks/notify-ready.sh" >/dev/null

if [ -f "$ATT/$UUID_A" ]; then
  pass "Stop writes a marker named for the iTerm2 session uuid"
else
  fail "Stop did not write $ATT/$UUID_A"
fi

# Shape: epoch <TAB> project <TAB> uuid <TAB> tty
IFS=$'\t' read -r m_epoch m_project m_uuid _ < "$ATT/$UUID_A" 2>/dev/null
if [[ "$m_epoch" =~ ^[0-9]+$ ]]; then pass "marker records a numeric epoch"
else fail "marker epoch is not numeric: \"$m_epoch\""; fi
if [ "$m_project" = "alpha" ]; then pass "marker names the project from cwd"
else fail "marker project is \"$m_project\", expected \"alpha\""; fi
if [ "$m_uuid" = "$UUID_A" ]; then pass "marker records the session uuid"
else fail "marker uuid is \"$m_uuid\", expected \"$UUID_A\""; fi

# --- 2. A second turn in the same window replaces, never accumulates ---------
payload /tmp/alpha Notification sess-1 \
  | ITERM_SESSION_ID="w0t0p0:$UUID_A" CLAUDE_MACROPAD_DRY_RUN=1 \
    bash "$ROOT/hooks/notify-ready.sh" >/dev/null
COUNT=$(find "$ATT" -type f | wc -l | tr -d ' ')
if [ "$COUNT" = "1" ]; then pass "a second event in the same window leaves one marker"
else fail "expected 1 marker after two events in one window, found $COUNT"; fi

# --- 3. UserPromptSubmit clears the marker for its own window ----------------
payload /tmp/alpha UserPromptSubmit sess-1 \
  | ITERM_SESSION_ID="w0t0p0:$UUID_A" bash "$ROOT/hooks/clear-attention.sh"
if [ -f "$ATT/$UUID_A" ]; then
  fail "clear-attention.sh left $ATT/$UUID_A in place"
else
  pass "UserPromptSubmit clears this window's marker"
fi

# --- 4. The jump picks the session that has waited longest ------------------
# Written directly rather than through the hook, because the hook stamps
# `date +%s` and two calls inside one second would not be ordered.
mkdir -p "$ATT"
printf '2000\tnewer\t%s\t/dev/ttys002\n' "$UUID_B" > "$ATT/$UUID_B"
printf '1000\tolder\t%s\t/dev/ttys001\n' "$UUID_A" > "$ATT/$UUID_A"
OUT=$(CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'older\t%s' "$UUID_A")" ]; then
  pass "jump targets the longest-waiting session"
else
  fail "jump targeted \"$OUT\", expected older/$UUID_A"
fi

# --- 5. --list reports every waiting session and changes nothing -------------
LIST=$(bash "$ROOT/scripts/jump-to-attention.sh" --list)
if [ "$(printf '%s\n' "$LIST" | wc -l | tr -d ' ')" = "2" ] \
   && printf '%s' "$LIST" | grep -q older && printf '%s' "$LIST" | grep -q newer; then
  pass "--list reports both waiting sessions"
else
  fail "--list output unexpected: $LIST"
fi
if [ "$(find "$ATT" -type f | wc -l | tr -d ' ')" = "2" ]; then
  pass "--list leaves the queue intact"
else
  fail "--list modified the queue"
fi

# --- 6. A corrupt marker is discarded rather than jamming the queue ----------
printf 'no-epoch-here\n' > "$ATT/CORRUPT"
bash "$ROOT/scripts/jump-to-attention.sh" --list >/dev/null
if [ -f "$ATT/CORRUPT" ]; then
  fail "a marker with no epoch survived; it would sort to the front every time"
else
  pass "a corrupt marker is discarded"
fi

# --- 7. The window you are already looking at is skipped, not re-focused ----
# Pressing the key in a waiting session should take you to the *next* thing
# that wants you. Re-focusing the window already under your nose looks exactly
# like a key that is not wired up, which is how this was first reported.
rm -rf "$ATT"; mkdir -p "$ATT"
printf '1000\there\t%s\t/dev/ttys001\n'  "$UUID_A" > "$ATT/$UUID_A"
printf '2000\tthere\t%s\t/dev/ttys002\n' "$UUID_B" > "$ATT/$UUID_B"
OUT=$(CLAUDE_MACROPAD_CURRENT_SESSION="$UUID_A" CLAUDE_MACROPAD_DRY_RUN=1 \
      bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'there\t%s' "$UUID_B")" ]; then
  pass "the session you are already in is skipped in favour of the next one"
else
  fail "expected to skip $UUID_A and target there/$UUID_B, got \"$OUT\""
fi
if [ -f "$ATT/$UUID_A" ]; then
  fail "the skipped session's marker was left behind; it would be skipped forever"
else
  pass "the skipped session's marker is cleared — you have seen it"
fi

# And when it is the only one waiting, that is an empty queue, not a jump.
rm -rf "$ATT"; mkdir -p "$ATT"
printf '1000\there\t%s\t/dev/ttys001\n' "$UUID_A" > "$ATT/$UUID_A"
OUT=$(CLAUDE_MACROPAD_CURRENT_SESSION="$UUID_A" CLAUDE_MACROPAD_DRY_RUN=1 \
      bash "$ROOT/scripts/jump-to-attention.sh")
if printf '%s' "$OUT" | grep -q "nothing waiting"; then
  pass "the only waiting session being the current one reports nothing waiting"
else
  fail "expected \"nothing waiting\", got \"$OUT\""
fi

# --- 8. With nothing waiting, cycle to the next session ---------------------
# The queue drains by design, so after you have visited everything the key has
# nothing to jump to. Stopping dead there reads as a broken key — four
# "nothing waiting" sounds in a row was the original report — so it falls back
# to moving between sessions.
SESSIONS=$'AAA\t/dev/ttys001\nBBB\t/dev/ttys002\nCCC\t/dev/ttys003'
rm -rf "$ATT"

OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'cycle\tBBB')" ]; then
  pass "an empty queue cycles to the next session"
else
  fail "expected cycle to BBB, got \"$OUT\""
fi

OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" CLAUDE_MACROPAD_CURRENT_SESSION=CCC \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'cycle\tAAA')" ]; then
  pass "cycling wraps from the last session to the first"
else
  fail "expected wrap to AAA, got \"$OUT\""
fi

# A waiting session must still win. Cycling is the fallback, not the behaviour.
mkdir -p "$ATT"
printf '1000\turgent\tBBB\t/dev/ttys002\n' > "$ATT/BBB"
OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'urgent\tBBB')" ]; then
  pass "a waiting session takes priority over cycling"
else
  fail "expected the waiting session to win, got \"$OUT\""
fi

# One session, and you are in it: nowhere to go, and cycling to yourself is
# exactly the do-nothing this was meant to remove.
rm -rf "$ATT"
OUT=$(CLAUDE_MACROPAD_SESSIONS=$'AAA\t/dev/ttys001' CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if printf '%s' "$OUT" | grep -q "nothing waiting"; then
  pass "a lone session does not cycle to itself"
else
  fail "expected \"nothing waiting\", got \"$OUT\""
fi

# --- 9. --next always moves; --new always opens ------------------------------
# These are the "switch chat" and "new chat" keys. Claude Code implements
# neither: strip:next and strip:new are both on the unimplemented list, so both
# are window management rather than shortcuts.
#
# --next differs from the plain jump in that it ignores the queue entirely. A
# switch key that sometimes went somewhere else because a different session was
# waiting would not be a switch key.
rm -rf "$ATT"; mkdir -p "$ATT"
printf '1000\turgent\tCCC\t/dev/ttys003\n' > "$ATT/CCC"
SESSIONS=$'AAA\t/dev/ttys001\nBBB\t/dev/ttys002\nCCC\t/dev/ttys003'

OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh" --next)
if [ "$OUT" = "$(printf 'cycle\tBBB')" ]; then
  pass "--next moves by position, ignoring the waiting session"
else
  fail "--next should have gone to BBB regardless of CCC waiting, got \"$OUT\""
fi

# Same state, plain jump: the waiting session wins. Both behaviours from one
# script, which is the point of having two keys.
OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh")
if [ "$OUT" = "$(printf 'urgent\tCCC')" ]; then
  pass "the plain jump still prioritises the waiting session"
else
  fail "the plain jump should have gone to CCC, got \"$OUT\""
fi

OUT=$(CLAUDE_MACROPAD_SESSIONS=$'AAA\t/dev/ttys001' CLAUDE_MACROPAD_CURRENT_SESSION=AAA \
      CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh" --next)
if printf '%s' "$OUT" | grep -q "no other session"; then
  pass "--next with nowhere to go says so"
else
  fail "expected \"no other session\", got \"$OUT\""
fi

# --new reports the directory it would start in. It must be a real one: the
# fallback to $HOME exists so this can never be empty.
OUT=$(CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh" --new)
NEWDIR=${OUT#*$'\t'}
if [ "${OUT%%$'\t'*}" = "new" ] && [ -d "$NEWDIR" ]; then
  pass "--new resolves a real starting directory ($NEWDIR)"
else
  fail "--new produced no usable directory: \"$OUT\""
fi


# --- 10a. --sessions lists what the cycling modes can see -------------------
# A diagnostic rather than a behaviour, and it earns its place: when this list
# comes back empty, --next does nothing and reports "no other session", which
# looks exactly like an unwired key. It was empty once because `tab` inside
# `tell application "iTerm2"` is iTerm2's tab class, not the tab character, so
# every line parsed to nothing while still being a well-formed string.
OUT=$(CLAUDE_MACROPAD_SESSIONS="$SESSIONS" bash "$ROOT/scripts/jump-to-attention.sh" --sessions)
if [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = "3" ] \
   && printf '%s' "$OUT" | grep -q '/dev/ttys002  BBB'; then
  pass "--sessions lists every visible session with its tty"
else
  fail "--sessions output unexpected: $OUT"
fi

# --- 10. An empty queue reports itself instead of failing -------------------
rm -rf "$ATT"
OUT=$(CLAUDE_MACROPAD_DRY_RUN=1 bash "$ROOT/scripts/jump-to-attention.sh"); RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "nothing waiting"; then
  pass "an empty queue exits 0 and says so"
else
  fail "empty queue: rc=$RC out=\"$OUT\""
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
