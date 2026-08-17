#!/bin/bash
# Checks that every key this repo documents is documented as doing the same
# thing everywhere it appears.
#
# Each guide writes the same keystroke in its own native syntax — markdown
# chord prose, a Stream Deck two-column step table, a QMK macro, a QMK keycode,
# a Karabiner manipulator — so a plain text diff across files catches nothing.
# This parses each syntax and compares (key, meaning) *pairs*.
#
# Pairs, not key sets, is the point. Comparing sets only proves the same five
# keys are named in every file; it passes happily when a guide teaches `[` as
# "Next chat", which is a working key that does the opposite of what the reader
# was told. So this catches a dropped character, a swapped character, and a
# swapped label, in either the key column or the meaning column.
#
# Two sources of truth:
#   - config/keybindings.json for which chord runs which action.
#   - The tables below for the English meaning of an action, and for the
#     pass-through keys, which no config file in this repo defines. Claude Code
#     binds those itself; they were read out of the 2.1.233 binary by hand.
# A pass here means the docs agree with each other and with the config. It
# cannot mean the config agrees with Claude Code.
#
# Every syntax is parsed, including the Karabiner manipulator in
# docs/stream-deck.md, whose fifth spelling ("key_code": "x" plus
# "open_bracket") went unchecked until now. It documents one chord as an
# example, so it is checked as one: prefix is ctrl+x, second key is a real
# chord.
#
# One gap, and it is in the source rather than here: docs/stream-deck.md lists
# its pass-through keys in a prose sentence with no meanings attached, so only
# the key set can be compared. That assertion says so in its own name. Give
# that list a table and this becomes a pair check like the rest.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYBINDINGS="$ROOT/config/keybindings.json"
README="$ROOT/README.md"
WORK_LOUDER="$ROOT/docs/work-louder-input.md"
STREAM_DECK="$ROOT/docs/stream-deck.md"
QMK_VIA="$ROOT/docs/qmk-via.md"
FAILED=0

fail() { echo "FAIL: $*"; FAILED=1; }
pass() { echo "PASS: $*"; }

TAB=$'\t'

# The English meaning of each action this repo binds. Every guide must use
# these words verbatim, so that agreement is checkable rather than a judgement.
meaning_for_action() {
  case "$1" in
    strip:previous)     echo "Previous chat" ;;
    strip:next)         echo "Next chat" ;;
    strip:new)          echo "New chat" ;;
    strip:toggle)       echo "Toggle chat strip" ;;
    chat:attentionDown) echo "Jump to session needing you" ;;
    *) return 1 ;;
  esac
}

# Keys Claude Code binds itself. Not in any config file here, and therefore the
# thing most likely to drift unnoticed — which is exactly how three of them sat
# documented as cmd+... instead of opt+... through several passes.
PASSTHROUGH_TRUTH="shift+tab${TAB}Cycle permission mode
opt+p${TAB}Model picker
opt+t${TAB}Thinking toggle
opt+o${TAB}Fast mode
ctrl+o${TAB}Transcript
ctrl+t${TAB}Todo list
ctrl+g${TAB}External editor"
PASSTHROUGH_TRUTH=$(printf '%s\n' "$PASSTHROUGH_TRUTH" | sort)

# QMK writes the same pass-through keys as keycodes.
key_for_keycode() {
  case "$1" in
    "LSFT(KC_TAB)") echo "shift+tab" ;;
    "LALT(KC_P)")   echo "opt+p" ;;
    "LALT(KC_T)")   echo "opt+t" ;;
    "LALT(KC_O)")   echo "opt+o" ;;
    "LCTL(KC_O)")   echo "ctrl+o" ;;
    "LCTL(KC_T)")   echo "ctrl+t" ;;
    "LCTL(KC_G)")   echo "ctrl+g" ;;
    # Anything else is reported verbatim so a regression to LGUI(...) names
    # itself in the failure instead of vanishing.
    *) echo "$1" ;;
  esac
}

# Karabiner spells the chord's second key as an HID usage name.
key_for_karabiner() {
  case "$1" in
    open_bracket)  echo "[" ;;
    close_bracket) echo "]" ;;
    *)             echo "$1" ;;
  esac
}

for f in "$KEYBINDINGS" "$README" "$WORK_LOUDER" "$STREAM_DECK" "$QMK_VIA"; do
  if [ ! -f "$f" ]; then
    fail "missing file: $f"
    echo "RESULT: FAILED"; exit 1
  fi
done
pass "all five source files exist"

if ! jq empty "$KEYBINDINGS" 2>/dev/null; then
  fail "config/keybindings.json is not valid JSON"
  echo "RESULT: FAILED"; exit 1
fi

# ---------------------------------------------------------------- truth ----

CHORD_TRUTH=""
while IFS="$TAB" read -r key action; do
  [ -n "$key" ] || continue
  case "$key" in
    "ctrl+x "?*) ;;
    *) fail "config/keybindings.json: \"$key\" is not a ctrl+x chord"; continue ;;
  esac
  if ! m=$(meaning_for_action "$action"); then
    fail "config/keybindings.json: action $action has no meaning in this script's table — add one"
    continue
  fi
  CHORD_TRUTH="${CHORD_TRUTH}${key#ctrl+x }${TAB}${m}
"
done < <(jq -r '.bindings[].bindings | to_entries[] | "\(.key)\t\(.value)"' "$KEYBINDINGS")
CHORD_TRUTH=$(printf '%s' "$CHORD_TRUTH" | grep -v '^$' | sort)

if [ -z "$CHORD_TRUTH" ]; then
  fail "config/keybindings.json: no ctrl+x bindings found"
  echo "RESULT: FAILED"; exit 1
fi
pass "config/keybindings.json defines $(printf '%s\n' "$CHORD_TRUTH" | wc -l | tr -d ' ') chords"

# ----------------------------------------------------------- extractors ----
# Every extractor emits sorted "<key><TAB><meaning>" lines.
#
# All of them require the line to be a table row, so running prose that names a
# chord (the README says "ctrl+x then [ is two keystrokes on any keyboard" in
# the "It works without a macropad" section) is skipped rather than parsed:
# prose has no meaning column to compare against.

# README.md chords: | `ctrl+x` then `a` | `action` | Context | Does |
readme_chords() {
  awk -F'|' -v t="$TAB" '/^\|/ && $2 ~ /`ctrl[+]x` then `/ {
    k=$2; m=$5
    sub(/.*`ctrl[+]x` then `/,"",k); sub(/`.*/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$README" | sort
}

# docs/work-louder-input.md chords: | Row | Pos | Chord | `ctrl+x` then `a` | Does |
work_louder_chords() {
  awk -F'|' -v t="$TAB" '/^\|/ && $5 ~ /`ctrl[+]x` then `/ {
    k=$5; m=$6
    sub(/.*`ctrl[+]x` then `/,"",k); sub(/`.*/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$WORK_LOUDER" | sort
}

# docs/stream-deck.md chords: | Does | `ctrl+x` | `a` |
stream_deck_chords() {
  awk -F'|' -v t="$TAB" '/^\|/ && NF==5 && $3 ~ /`ctrl[+]x`/ {
    m=$2; k=$4
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$STREAM_DECK" | sort
}

# docs/qmk-via.md chords: | M0 | `{KC_LCTL,KC_X}a` | Does |
qmk_via_chords() {
  awk -F'|' -v t="$TAB" '/^\|/ && $3 ~ /KC_LCTL,KC_X}/ {
    k=$3; m=$4
    sub(/.*KC_LCTL,KC_X}/,"",k); sub(/`.*/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$QMK_VIA" | sort
}

# Pass-through rows are recognised by a backticked keystroke that carries a
# modifier. Matching the shape rather than the expected list is deliberate: a
# regression to `cmd+p` still gets extracted, and so gets reported as wrong
# rather than silently skipped.
CHORD_SHAPE='`(shift|ctrl|opt|alt|cmd|meta|super|gui)[+][A-Za-z0-9]+`'

# README.md pass-through: | `opt+p` | Model picker |
readme_passthrough() {
  awk -F'|' -v t="$TAB" -v re="$CHORD_SHAPE" '/^\|/ && NF==4 && $2 ~ re {
    k=$2; m=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$README" | sort
}

# docs/work-louder-input.md pass-through: | 2 | 2 | Key | `opt+p` | Model picker |
# The Type column separates these from the chord rows, which share the row
# shape and whose `ctrl+x` half also looks like a modified keystroke.
work_louder_passthrough() {
  awk -F'|' -v t="$TAB" -v re="$CHORD_SHAPE" '
  /^\|/ && NF==7 && $5 ~ re {
    type=$4; gsub(/^[ \t]+|[ \t]+$/,"",type)
    if (type != "Key") next
    k=$5; m=$6
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$WORK_LOUDER" | sort
}

# docs/qmk-via.md pass-through: | `LALT(KC_P)` | Model picker |
qmk_via_passthrough_raw() {
  awk -F'|' -v t="$TAB" '/^\|/ && NF==4 && $2 ~ /`[A-Z]+[(]KC_[A-Z0-9_]+[)]`/ {
    k=$2; m=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$QMK_VIA"
}

qmk_via_passthrough() {
  local kc m
  while IFS="$TAB" read -r kc m; do
    [ -n "$kc" ] || continue
    printf '%s%s%s\n' "$(key_for_keycode "$kc")" "$TAB" "$m"
  done < <(qmk_via_passthrough_raw) | sort
}

# docs/stream-deck.md pass-through is a prose list with no meanings attached,
# so only the key set is comparable. Noted in the assertion name.
stream_deck_passthrough_keys() {
  awk '/^Pass-through buttons are plain Hotkey actions:/ {p=1}
       p {print; if (/\.[ \t]*$/) exit}' "$STREAM_DECK" \
    | grep -oE '`[^`]+`' | tr -d '`' | sort
}

# ---------------------------------------------------------------- checks ----

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
    if [ -n "$missing" ]; then
      printf '%s\n' "$missing" | sed "s/$TAB/  =  /" | sed 's/^/        expected: /'
    fi
    if [ -n "$extra" ]; then
      printf '%s\n' "$extra" | sed "s/$TAB/  =  /" | sed 's/^/        found:    /'
    fi
  else
    pass "$name: $(printf '%s\n' "$actual" | wc -l | tr -d ' ') key/meaning pairs agree"
  fi
}

check_keyset() {
  local name="$1" actual="$2" expected="$3" diffout
  if [ -z "$actual" ]; then
    fail "$name: extracted nothing at all"
    return
  fi
  diffout=$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))
  if [ -n "$diffout" ]; then
    fail "$name: key set differs from the pass-through table"
    printf '%s\n' "$diffout" | sed 's/^/        /'
  else
    pass "$name: $(printf '%s\n' "$actual" | wc -l | tr -d ' ') keys agree"
  fi
}

echo "-- chords"
check_pairs "README.md chords"                 "$(readme_chords)"      "$CHORD_TRUTH"
check_pairs "docs/work-louder-input.md chords" "$(work_louder_chords)" "$CHORD_TRUTH"
check_pairs "docs/stream-deck.md chords"       "$(stream_deck_chords)" "$CHORD_TRUTH"
check_pairs "docs/qmk-via.md chords"           "$(qmk_via_chords)"     "$CHORD_TRUTH"

echo "-- pass-through keys"
check_pairs "README.md pass-through"                 "$(readme_passthrough)"      "$PASSTHROUGH_TRUTH"
check_pairs "docs/work-louder-input.md pass-through" "$(work_louder_passthrough)" "$PASSTHROUGH_TRUTH"
check_pairs "docs/qmk-via.md pass-through"           "$(qmk_via_passthrough)"     "$PASSTHROUGH_TRUTH"
check_keyset "docs/stream-deck.md pass-through (keys only; the prose list carries no meanings)" \
  "$(stream_deck_passthrough_keys)" \
  "$(printf '%s\n' "$PASSTHROUGH_TRUTH" | cut -f1 | sort)"

echo "-- karabiner example"
KARA=$(awk '/^## Karabiner-Elements/{s=1} s' "$STREAM_DECK" \
       | awk '/^```json/{f=1;next} /^```/{if(f)exit} f')
if [ -z "$KARA" ] || ! printf '%s' "$KARA" | jq empty 2>/dev/null; then
  fail "docs/stream-deck.md: could not parse the Karabiner manipulator as JSON"
else
  K_FIRST=$(printf '%s' "$KARA" | jq -r '.to[0].key_code // "?"')
  K_MODS=$(printf '%s' "$KARA" | jq -r '(.to[0].modifiers // []) | join(",")')
  K_SECOND=$(printf '%s' "$KARA" | jq -r '.to[1].key_code // "?"')

  if [ "$K_FIRST" != "x" ] || [ "$K_MODS" != "left_control" ]; then
    fail "docs/stream-deck.md: Karabiner prefix is \"$K_MODS+$K_FIRST\", not left_control+x"
  else
    pass "docs/stream-deck.md: Karabiner prefix is ctrl+x"
  fi

  K_KEY=$(key_for_karabiner "$K_SECOND")
  if printf '%s\n' "$CHORD_TRUTH" | cut -f1 | grep -qxF -- "$K_KEY"; then
    pass "docs/stream-deck.md: Karabiner second key \"$K_SECOND\" is the chord \"$K_KEY\""
  else
    fail "docs/stream-deck.md: Karabiner second key \"$K_SECOND\" is not one of the documented chords"
  fi
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
