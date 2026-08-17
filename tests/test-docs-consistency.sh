#!/bin/bash
# Checks that every key this repo documents is documented as doing the same
# thing everywhere it appears.
#
# Each guide writes the same keystroke in its own native syntax — a markdown
# table cell, a Stream Deck hotkey table, a QMK keycode, a Karabiner
# manipulator — so a plain text diff across files catches nothing. This parses
# each syntax and compares (key, meaning) *pairs*.
#
# Pairs, not key sets, is the point. Comparing sets only proves the same five
# keys are named in every file; it passes happily when a guide teaches `alt+k`
# as "Next chat", which is a working key that does the opposite of what the
# reader was told. So this catches a dropped character, a swapped character,
# and a swapped label, in either the key column or the meaning column.
#
# Two sources of truth:
#   - config/keybindings.json for which keystroke runs which action.
#   - The tables below for the English meaning of an action, and for the
#     pass-through keys, which no config file in this repo defines. Claude Code
#     binds those itself; they were read out of the 2.1.233 binary by hand.
# A pass here means the docs agree with each other and with the config. It
# cannot mean the config agrees with Claude Code.
#
# Every syntax is parsed, including the Karabiner manipulator in
# docs/stream-deck.md, whose fifth spelling ("key_code": "k" carrying the
# "left_option" modifier) is checked as the one binding it documents by
# example: a single event, the Option modifier, and a key the config binds.
#
# docs/qmk-via.md needs section scoping where the others do not. Its bindings
# and its pass-through keys are both `LALT(KC_x)`-shaped rows in two-column
# tables, so shape alone cannot tell them apart. Each extractor reads only its
# own "## " section; rename a heading and the extractor yields nothing, which
# check_pairs reports as a failure rather than passing quietly.
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

# QMK writes this repo's own bindings as keycodes too. Unlike the pass-through
# table these are not a fixed list, so they are parsed rather than looked up:
# LALT(KC_A) becomes alt+a. Anything else is returned verbatim, so a regression
# to LCTL(...) or LGUI(...) names itself in the failure.
key_for_binding_keycode() {
  local kc="$1" inner
  case "$kc" in
    "LALT(KC_"?")")
      inner="${kc#LALT(KC_}"; inner="${inner%)}"
      printf 'alt+%s\n' "$(printf '%s' "$inner" | tr 'A-Z' 'a-z')" ;;
    *) printf '%s\n' "$kc" ;;
  esac
}

# Prints one "## " section of a markdown file, heading line excluded. Used
# where two tables in the same file share a row shape.
md_section() {
  awk -v h="$2" '$0 == h { s = 1; next } /^## / { if (s) exit } s' "$1"
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

BINDING_TRUTH=""
while IFS="$TAB" read -r key action; do
  [ -n "$key" ] || continue
  # One keystroke, modifier included. A space would mean a two-keystroke
  # sequence, which no device app in these guides can send.
  case "$key" in
    *" "*)    fail "config/keybindings.json: \"$key\" is a two-keystroke sequence"; continue ;;
    "alt+"?*) ;;
    *)        fail "config/keybindings.json: \"$key\" is not an alt+ keystroke"; continue ;;
  esac
  if ! m=$(meaning_for_action "$action"); then
    fail "config/keybindings.json: action $action has no meaning in this script's table — add one"
    continue
  fi
  BINDING_TRUTH="${BINDING_TRUTH}${key}${TAB}${m}
"
done < <(jq -r '.bindings[].bindings | to_entries[] | "\(.key)\t\(.value)"' "$KEYBINDINGS")
BINDING_TRUTH=$(printf '%s' "$BINDING_TRUTH" | grep -v '^$' | sort)

if [ -z "$BINDING_TRUTH" ]; then
  fail "config/keybindings.json: no alt+ bindings found"
  echo "RESULT: FAILED"; exit 1
fi
pass "config/keybindings.json defines $(printf '%s\n' "$BINDING_TRUTH" | wc -l | tr -d ' ') bindings"

# ----------------------------------------------------------- extractors ----
# Every extractor emits sorted "<key><TAB><meaning>" lines.
#
# All of them require the line to be a table row, so running prose that names a
# binding (the README says "`alt+k` is Option held with K" under "Which one are
# you?") is skipped rather than parsed: prose has no meaning column to compare
# against.
#
# A binding cell is a backticked alt+<key>. That shape is what separates these
# rows from the pass-through rows in the same tables, which this repo spells
# opt+... throughout. Keep the two spellings distinct or the extractors below
# start crossing over.
BINDING_CELL='`alt[+][A-Za-z0-9]+`'

# README.md bindings: | `alt+a` | `action` | Context | Does |
readme_bindings() {
  awk -F'|' -v t="$TAB" -v re="$BINDING_CELL" '/^\|/ && NF==6 && $2 ~ re {
    k=$2; m=$5
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$README" | sort
}

# docs/work-louder-input.md carries bindings in two tables of different widths:
# the key grid  | Row | Column | Type | `alt+a` | Does |
# and the dial  | Dial, clockwise | `alt+j` | Next chat |
#
# So rather than hardcode a column index, find whichever cell holds the binding
# and take the cell after it as the meaning. Shape-agnostic, which means adding
# a third table later does not silently drop out of coverage.
work_louder_bindings() {
  awk -F'|' -v t="$TAB" -v re="$BINDING_CELL" '/^\|/ {
    for (i = 2; i < NF; i++) {
      if ($i ~ re) {
        k = $i; m = $(i + 1)
        gsub(/^[ \t]*`|`[ \t]*$/, "", k)
        gsub(/^[ \t]+|[ \t]+$/, "", m)
        print k t m
        break
      }
    }
  }' "$WORK_LOUDER" | sort
}

# docs/stream-deck.md bindings: | Does | `alt+a` |
stream_deck_bindings() {
  awk -F'|' -v t="$TAB" -v re="$BINDING_CELL" '/^\|/ && NF==4 && $3 ~ re {
    m=$2; k=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$STREAM_DECK" | sort
}

# docs/qmk-via.md bindings: | `LALT(KC_A)` | Does |, under "## Keycodes" only.
# The pass-through table two sections down has the identical shape, so the
# section boundary is what keeps them apart.
qmk_via_bindings_raw() {
  md_section "$QMK_VIA" "## Keycodes" \
  | awk -F'|' -v t="$TAB" '/^\|/ && NF==4 && $2 ~ /`[A-Z]+[(]KC_[A-Z0-9_]+[)]`/ {
      k=$2; m=$3
      gsub(/^[ \t]*`|`[ \t]*$/,"",k)
      gsub(/^[ \t]+|[ \t]+$/,"",m)
      print k t m
    }'
}

qmk_via_bindings() {
  local kc m
  while IFS="$TAB" read -r kc m; do
    [ -n "$kc" ] || continue
    printf '%s%s%s\n' "$(key_for_binding_keycode "$kc")" "$TAB" "$m"
  done < <(qmk_via_bindings_raw) | sort
}

# Pass-through rows are recognised by a backticked keystroke that carries a
# modifier. Matching the shape rather than the expected list is deliberate: a
# regression to `cmd+p` still gets extracted, and so gets reported as wrong
# rather than silently skipped.
MODIFIED_KEY_SHAPE='`(shift|ctrl|opt|alt|cmd|meta|super|gui)[+][A-Za-z0-9]+`'

# README.md pass-through: | `opt+p` | Model picker |
readme_passthrough() {
  awk -F'|' -v t="$TAB" -v re="$MODIFIED_KEY_SHAPE" '/^\|/ && NF==4 && $2 ~ re {
    k=$2; m=$3
    gsub(/^[ \t]*`|`[ \t]*$/,"",k)
    gsub(/^[ \t]+|[ \t]+$/,"",m)
    print k t m
  }' "$README" | sort
}

# docs/work-louder-input.md holds pass-through keys in two tables now: the
# 5-column layout table for the two that earned a pad key, and a 2-column table
# for the five deliberately left on the keyboard. Gather both.
#
# Then keep only keys the truth set names. The layout table also carries
# pad-specific keys — Escape, ctrl+c, Space, Enter — which are not pass-through
# bindings at all, and ctrl+c matches the modified-keystroke shape, so filtering
# by the truth keys rather than by shape is what keeps this exact.
work_louder_passthrough() {
  truth_keys=$(printf '%s\n' "$PASSTHROUGH_TRUTH" | cut -f1 | tr '\n' ' ')
  {
    awk -F'|' -v t="$TAB" '
    /^\|/ && NF==7 {
      type=$4; gsub(/^[ \t]+|[ \t]+$/,"",type)
      if (type != "Key") next
      k=$5; m=$6
      gsub(/^[ \t]*`|`[ \t]*$/,"",k)
      gsub(/^[ \t]+|[ \t]+$/,"",m)
      print k t m
    }' "$WORK_LOUDER"
    awk -F'|' -v t="$TAB" '
    /^\|/ && NF==4 {
      k=$2; m=$3
      gsub(/^[ \t]*`|`[ \t]*$/,"",k)
      gsub(/^[ \t]+|[ \t]+$/,"",m)
      print k t m
    }' "$WORK_LOUDER"
  } | awk -F"$TAB" -v keys="$truth_keys" '
      BEGIN { n = split(keys, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1 }
      $1 in want { print }
    ' | sort -u
}

# docs/qmk-via.md pass-through: | `LALT(KC_P)` | Model picker |, scoped to its
# own section for the same reason the bindings extractor above is.
qmk_via_passthrough_raw() {
  md_section "$QMK_VIA" "## Pass-through keys" \
  | awk -F'|' -v t="$TAB" '/^\|/ && NF==4 && $2 ~ /`[A-Z]+[(]KC_[A-Z0-9_]+[)]`/ {
      k=$2; m=$3
      gsub(/^[ \t]*`|`[ \t]*$/,"",k)
      gsub(/^[ \t]+|[ \t]+$/,"",m)
      print k t m
    }'
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

echo "-- bindings"
check_pairs "README.md bindings"                 "$(readme_bindings)"      "$BINDING_TRUTH"
check_pairs "docs/work-louder-input.md bindings" "$(work_louder_bindings)" "$BINDING_TRUTH"
check_pairs "docs/stream-deck.md bindings"       "$(stream_deck_bindings)" "$BINDING_TRUTH"
check_pairs "docs/qmk-via.md bindings"           "$(qmk_via_bindings)"     "$BINDING_TRUTH"

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

  if printf '%s\n' "$BINDING_TRUTH" | cut -f1 | grep -qxF -- "alt+$K_CODE"; then
    pass "docs/stream-deck.md: Karabiner key \"$K_CODE\" is the binding \"alt+$K_CODE\""
  else
    fail "docs/stream-deck.md: Karabiner key \"$K_CODE\" is not one of the documented bindings"
  fi
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
