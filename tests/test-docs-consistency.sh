#!/bin/bash
# Checks that every key this repo documents is documented as doing the same
# thing everywhere it appears.
#
# Each guide writes the same keystroke in its own native syntax — a markdown
# table cell, a Stream Deck hotkey table, a QMK keycode, a Karabiner
# manipulator — so a plain text diff across files catches nothing. This parses
# each syntax and compares (key, meaning) *pairs*.
#
# Pairs, not key sets, is the point. Comparing sets only proves the same keys
# are named in every file; it passes happily when a guide teaches `ctrl+o` as
# "Todo list", which is a working key that does the wrong thing. So this catches
# a dropped character, a swapped character, and a swapped label, in either
# column.
#
# The source of truth is PAD_TRUTH below, and it is a hand-kept table rather
# than something read out of a config file. That is a deliberate change: this
# layout is built entirely from keystrokes Claude Code binds itself, so there is
# no config file left to read it from. config/keybindings.json now carries only
# the two off-pad extras, and tests/test-keybindings.sh checks those.
#
# A pass here means the guides agree with each other. It cannot mean they agree
# with Claude Code — for that, see the unimplemented-action check in
# tests/test-keybindings.sh, which is what the last round of drift needed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/README.md"
WORK_LOUDER="$ROOT/docs/work-louder-input.md"
STREAM_DECK="$ROOT/docs/stream-deck.md"
QMK_VIA="$ROOT/docs/qmk-via.md"
FAILED=0

fail() { echo "FAIL: $*"; FAILED=1; }
pass() { echo "PASS: $*"; }

TAB=$'\t'

# Every keystroke on the pad, and the words every guide must use for it.
# Claude Code 2.1.234 binds all of them itself.
PAD_TRUTH="ctrl+r${TAB}Search prompt history
ctrl+t${TAB}Todo list
ctrl+o${TAB}Transcript
shift+tab${TAB}Cycle permission mode
ctrl+c${TAB}Interrupt
opt+p${TAB}Model picker
ctrl+b${TAB}Background the task
Space${TAB}Voice dictation, held
Enter${TAB}Submit"
PAD_TRUTH=$(printf '%s\n' "$PAD_TRUTH" | sort)

ALL_KEYS=$(printf '%s\n' "$PAD_TRUTH" | cut -f1 | tr '\n' ' ')

# A Stream Deck cannot hold a key, so it cannot drive push-to-talk, and its
# guide says so instead of listing Space. Every other guide carries all eleven.
# Spelling the exception out here means a guide that quietly drops a key still
# fails, which a "compare whatever each file happens to contain" check would
# not.
SD_KEYS=$(printf '%s\n' "$PAD_TRUTH" | cut -f1 | grep -vx 'Space' | tr '\n' ' ')

subset() {
  # $1 = space-separated keys to keep, read from stdin
  awk -F"$TAB" -v keys="$1" '
    BEGIN { n = split(keys, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1 }
    $1 in want { print }'
}

expected_for() { printf '%s\n' "$PAD_TRUTH" | subset "$1"; }

# Guides may add local colour after an em dash — "Voice dictation, held — the
# fat key". The part before it still has to match exactly.
normalise() { sed 's/ — .*$//' ; }

for f in "$README" "$WORK_LOUDER" "$STREAM_DECK" "$QMK_VIA"; do
  if [ ! -f "$f" ]; then
    fail "missing file: $f"
    echo "RESULT: FAILED"; exit 1
  fi
done
pass "all four source files exist"

# ----------------------------------------------------------- extractors ----
# Every extractor emits sorted "<key><TAB><meaning>" lines, filtered to the
# keys the truth table names. Filtering by key set rather than by shape is what
# keeps unrelated tables out: the guides also carry dial assignments, off-pad
# shortcuts, and a joystick table, several of which look identical to a parser.
#
# A key that is *missing* from a guide is still missing after filtering, so the
# comparison below still fails. Only rows belonging to other tables are dropped.

# A backticked keystroke: `ctrl+r`, `opt+p`, `Space`, `Enter`.
KEY_CELL='`(ctrl|opt|shift|alt|cmd|meta)[+][A-Za-z0-9]+`|`(Space|Enter)`'

# README.md and docs/qmk-via.md: | `key` | Does |
two_col() {
  awk -F'|' -v t="$TAB" -v re="$KEY_CELL" '/^\|/ && NF==4 && $2 ~ re {
    k=$2; m=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$1"
}

# docs/work-louder-input.md carries the layout in a 5-column table and other
# keys in 2-column tables. Rather than hardcode a column index, find whichever
# cell holds a keystroke and take the cell after it as the meaning — so adding
# a table later does not silently drop out of coverage.
work_louder() {
  awk -F'|' -v t="$TAB" -v re="$KEY_CELL" '/^\|/ {
    for (i = 2; i < NF; i++) {
      if ($i ~ re) {
        k = $i; m = $(i + 1)
        gsub(/^[ \t]*`|`[ \t]*$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", m)
        print k t m
        break
      }
    }
  }' "$WORK_LOUDER"
}

# docs/stream-deck.md reverses the columns: | Does | `key` |
stream_deck() {
  awk -F'|' -v t="$TAB" -v re="$KEY_CELL" '/^\|/ && NF==4 && $3 ~ re {
    m=$2; k=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$STREAM_DECK"
}

# docs/qmk-via.md writes keystrokes as QMK keycodes. Anything unrecognised is
# returned verbatim so a regression to LGUI(...) names itself in the failure
# rather than vanishing from the comparison.
keycode_to_key() {
  case "$1" in
    "KC_SPACE") echo "Space" ;;
    "KC_ENTER") echo "Enter" ;;
    "LSFT(KC_TAB)") echo "shift+tab" ;;
    "LCTL(KC_"?")") k="${1#LCTL(KC_}"; echo "ctrl+$(echo "${k%)}" | tr 'A-Z' 'a-z')" ;;
    "LALT(KC_"?")") k="${1#LALT(KC_}"; echo "opt+$(echo "${k%)}" | tr 'A-Z' 'a-z')" ;;
    *) echo "$1" ;;
  esac
}

qmk_via() {
  local kc m
  while IFS="$TAB" read -r kc m; do
    [ -n "$kc" ] || continue
    printf '%s%s%s\n' "$(keycode_to_key "$kc")" "$TAB" "$m"
  done < <(awk -F'|' -v t="$TAB" '/^\|/ && NF==4 && $2 ~ /`[A-Z_]+([(]KC_[A-Z0-9_]+[)])?`/ {
      k=$2; m=$3
      gsub(/^[ \t]*`|`[ \t]*$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",m)
      print k t m
    }' "$QMK_VIA")
}

# -------------------------------------------------------------- checks ----

check_pairs() {
  local name="$1" actual="$2" expected="$3" missing extra
  if [ -z "$actual" ]; then
    fail "$name: extracted nothing at all — the table shape changed, or the extractor is broken"
    return
  fi
  missing=$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))
  extra=$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))
  if [ -n "$missing" ] || [ -n "$extra" ]; then
    fail "$name: does not match the source of truth"
    [ -n "$missing" ] && printf '%s\n' "$missing" | sed "s/$TAB/  =  /" | sed 's/^/        expected: /'
    [ -n "$extra" ]   && printf '%s\n' "$extra"   | sed "s/$TAB/  =  /" | sed 's/^/        found:    /'
  else
    pass "$name: $(printf '%s\n' "$actual" | wc -l | tr -d ' ') key/meaning pairs agree"
  fi
}

echo "-- pad layout"
check_pairs "README.md"                 "$(two_col "$README" | normalise | subset "$ALL_KEYS" | sort -u)" "$(expected_for "$ALL_KEYS")"
check_pairs "docs/work-louder-input.md" "$(work_louder   | normalise | subset "$ALL_KEYS" | sort -u)" "$(expected_for "$ALL_KEYS")"
check_pairs "docs/qmk-via.md"           "$(qmk_via       | normalise | subset "$ALL_KEYS" | sort -u)" "$(expected_for "$ALL_KEYS")"
check_pairs "docs/stream-deck.md"       "$(stream_deck   | normalise | subset "$SD_KEYS"  | sort -u)" "$(expected_for "$SD_KEYS")"

echo "-- karabiner example"
KARA=$(awk '/^### Mapping a spare key/{s=1} s' "$STREAM_DECK" \
       | awk '/^```json/{f=1;next} /^```/{if(f)exit} f')
if [ -z "$KARA" ] || ! printf '%s' "$KARA" | jq empty 2>/dev/null; then
  fail "docs/stream-deck.md: could not parse the Karabiner manipulator as JSON"
else
  K_EVENTS=$(printf '%s' "$KARA" | jq -r '.to | length')
  K_CODE=$(printf '%s' "$KARA" | jq -r '.to[0].key_code // "?"')
  K_MODS=$(printf '%s' "$KARA" | jq -r '(.to[0].modifiers // []) | join(",")')

  # One event, not two. The two-event form was this repo's old chord shape, and
  # it is exactly what the device apps cannot send.
  if [ "$K_EVENTS" != "1" ]; then
    fail "docs/stream-deck.md: Karabiner \"to\" sends $K_EVENTS events, not one keystroke"
  elif [ "$K_MODS" != "left_option" ]; then
    fail "docs/stream-deck.md: Karabiner modifier is \"$K_MODS\", not left_option"
  else
    pass "docs/stream-deck.md: Karabiner sends one left_option keystroke"
  fi

  if printf '%s\n' "$PAD_TRUTH" | cut -f1 | grep -qxF -- "opt+$K_CODE"; then
    pass "docs/stream-deck.md: Karabiner key \"$K_CODE\" is the documented \"opt+$K_CODE\""
  else
    fail "docs/stream-deck.md: Karabiner key \"$K_CODE\" is not one of the documented keys"
  fi
fi

# The jump script is referenced by three guides and the README by absolute
# installed path. A rename that updated the script but not its callers would
# leave every one of those instructions pointing at nothing.
echo "-- jump script path"
JUMP_REFS=$(grep -rlF '.claude/hooks/jump-to-attention.sh' \
              "$README" "$WORK_LOUDER" "$STREAM_DECK" "$QMK_VIA" 2>/dev/null | wc -l | tr -d ' ')
if [ ! -f "$ROOT/scripts/jump-to-attention.sh" ]; then
  fail "scripts/jump-to-attention.sh is missing but the docs reference it"
elif [ "$JUMP_REFS" -lt 2 ]; then
  fail "only $JUMP_REFS doc(s) reference the installed jump script path"
else
  pass "jump script exists and $JUMP_REFS docs reference its installed path"
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
