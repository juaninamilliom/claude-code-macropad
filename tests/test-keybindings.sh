#!/bin/bash
# Validates a keybindings file against Claude Code's contexts and actions.
#
#   bash tests/test-keybindings.sh                              # config/keybindings.json
#   bash tests/test-keybindings.sh ~/.claude/keybindings.json   # your installed file
#
# Check 7 is the one that matters, and it is the reason this file was rewritten.
#
# Claude Code 2.1.234 declares 137 action names. Seventeen of them have no
# implementation behind the name: the validator accepts them, the loader binds
# them, the keystroke is matched, and then nothing happens. There is no error
# anywhere in that chain. This repo shipped five such bindings for weeks and the
# only symptom was keys that did nothing, which is indistinguishable from a
# hardware problem, a terminal problem, or a modifier problem — all of which got
# blamed first.
#
# So "the action name is spelled correctly" is not the property worth testing.
# "The action does something" is. Check 6 covers the former; check 7 covers the
# latter, and it is the one that would have caught it.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-$ROOT/config/keybindings.json}"
IS_REPO_CONFIG=0
[ "$FILE" = "$ROOT/config/keybindings.json" ] && IS_REPO_CONFIG=1
FAILED=0

fail() { echo "FAIL: $*"; FAILED=1; }
pass() { echo "PASS: $*"; }

# Complete for 2.1.234.
VALID_CONTEXTS="Global Chat Autocomplete Confirmation Help Transcript
HistorySearch Task ThemePicker Settings Tabs Attachments Footer
MessageSelector DiffDialog DiffPanel ModelPicker Select Plugin Scroll"

# A hand-kept subset: what this repo binds, plus the near neighbours you are
# most likely to reach for. A legitimate binding outside this list is reported
# as unknown — extend the list rather than assuming the binding is wrong.
VALID_ACTIONS="chat:killAgents chat:undo chat:cycleMode chat:submit chat:cancel
chat:externalEditor chat:stash chat:clearInput chat:clearScreen chat:newline
chat:modelPicker chat:fastMode chat:thinkingToggle chat:workflowKeywordToggle
chat:imagePaste voice:pushToTalk history:search history:previous history:next
app:toggleTodos app:toggleTranscript app:toggleBrief app:interrupt app:exit
app:toggleTerminal app:openArtifact task:background tabs:next tabs:previous"

# Declared in 2.1.234 but with no implementation behind the name. Binding any of
# these produces a key that does nothing, silently and permanently.
#
# Derived by extracting the canonical action list from the binary and checking
# each name for a dispatch site outside the list itself and the
# documentation-table filter. These seventeen had none. The same binary also
# excludes strip:* and chat:attention* from its own generated shortcut table,
# which is corroboration from upstream that they are not meant to work yet.
#
# **This list is version-specific.** 2.1.233 had eighteen; `selection:clear`
# gained an implementation in 2.1.234 and was removed from here. None of the
# fifteen session actions — thirteen strip:* and two chat:attention* — changed,
# which is why this repo still drives session switching through iTerm2.
#
# Re-derive after an upgrade rather than trusting this list. If a release
# implements one, delete it from here; do not add a special case. And if a
# binding you were relying on stops working after an upgrade, re-derive before
# blaming your terminal.
UNIMPLEMENTED_ACTIONS="strip:jump1 strip:jump2 strip:jump3 strip:jump4
strip:jump5 strip:jump6 strip:jump7 strip:jump8 strip:jump9
strip:next strip:previous strip:toggle strip:new
chat:cycleProactivity chat:attentionUp chat:attentionDown
permission:toggleDebug"

in_list() { echo "$2" | tr ' \n' '\n\n' | grep -qx "$1"; }

echo "checking: $FILE"

# 1. File exists
if [ ! -f "$FILE" ]; then
  fail "$FILE does not exist"
  echo "RESULT: FAILED"; exit 1
fi
pass "file exists"

# 2. Valid JSON
if ! jq empty "$FILE" 2>/dev/null; then
  fail "not valid JSON"
  echo "RESULT: FAILED"; exit 1
fi
pass "valid JSON"

# 3. Has a bindings array. Everything below reads through it, so a wrong shape
#    here has to stop the run — a jq error on stderr is not a test result.
if [ "$(jq -r '.bindings | type' "$FILE" 2>/dev/null)" != "array" ]; then
  fail '"bindings" must be an array'
  echo "RESULT: FAILED"; exit 1
fi
pass "bindings is an array"

# 4. Every entry in that array maps keystrokes to actions with an object. A
#    string or an array here makes every `to_entries` and `keys` below fail,
#    and a failed jq feeding a `while` loop is an empty loop, not a failure.
BAD_SHAPE=$(jq -r '[.bindings[] | select((.bindings | type) != "object")
                   | (.context // "<no context>")] | join(", ")' "$FILE" 2>/dev/null)
if [ -n "$BAD_SHAPE" ]; then
  fail "context entries whose \"bindings\" value is not an object: $BAD_SHAPE"
  echo "RESULT: FAILED"; exit 1
fi
pass "every context entry maps keystrokes to actions"

# 5. Every context is known
while IFS= read -r ctx; do
  if in_list "$ctx" "$VALID_CONTEXTS"; then pass "context $ctx"
  else fail "unknown context: $ctx"; fi
done < <(jq -r '.bindings[].context' "$FILE")

# 6. Every action is a name Claude Code recognises
while IFS= read -r action; do
  if in_list "$action" "$VALID_ACTIONS"; then pass "action $action"
  else fail "unknown action: $action"; fi
done < <(jq -r '.bindings[].bindings | to_entries[] | .value | select(. != null)' "$FILE")

# 7. No action is one of the seventeen that do nothing. See the header.
SEEN=0
while IFS= read -r action; do
  SEEN=$((SEEN + 1))
  if in_list "$action" "$UNIMPLEMENTED_ACTIONS"; then
    fail "action \"$action\" is declared by Claude Code but has no implementation — this binding would silently do nothing"
  fi
done < <(jq -r '.bindings[].bindings | to_entries[] | .value | select(. != null)' "$FILE")
if [ "$SEEN" -eq 0 ]; then
  fail "no actions to check against the unimplemented list"
else
  pass "no binding uses an unimplemented action"
fi

# 8. No binding uses a bare lowercase letter as its first keystroke.
#    Claude Code warns this "prints into the input during warmup".
SEEN=0
while IFS= read -r key; do
  SEEN=$((SEEN + 1))
  first="${key%% *}"
  if [[ "$first" =~ ^[a-z]$ ]]; then
    fail "binding \"$key\" starts with a bare letter"
  fi
done < <(jq -r '.bindings[].bindings | keys[]' "$FILE")
if [ "$SEEN" -eq 0 ]; then
  fail "no keystrokes to check for bare-letter prefixes"
else
  pass "no bare-letter keystrokes"
fi

# 9. Every binding is one alt+<key> keystroke. Two things at once, both needed.
#    The alt+ prefix, because valid, whitelisted bindings under any other
#    modifier would otherwise pass the whole suite. And the absence of a space,
#    because a space means a two-keystroke chord — which Claude Code accepts and
#    no macropad configurator in docs/ can send, so it must not creep back in.
#    Giving chord-only actions a single keystroke is this file's entire job.
SEEN=0
while IFS= read -r key; do
  SEEN=$((SEEN + 1))
  case "$key" in
    *" "*) fail "binding \"$key\" is a two-keystroke chord; device apps cannot send one" ;;
    "alt+"?*) ;;
    *) fail "binding \"$key\" is not under the alt+ prefix" ;;
  esac
done < <(jq -r '.bindings[].bindings | keys[]' "$FILE")
if [ "$SEEN" -eq 0 ]; then
  fail "no keystrokes to check for the alt+ prefix"
else
  pass "all bindings are single alt+ keystrokes"
fi

# 10. This repo's own config has a known size. Skipped for an installed file,
#     which legitimately carries the reader's own bindings too.
if [ "$IS_REPO_CONFIG" -eq 1 ]; then
  COUNT=$(jq '[.bindings[].bindings | to_entries[]] | length' "$FILE" 2>/dev/null)
  if [[ ! "$COUNT" =~ ^[0-9]+$ ]]; then
    fail "could not count bindings (got \"$COUNT\")"
  elif [ "$COUNT" -ne 2 ]; then
    fail "expected 2 bindings in the repo config, found $COUNT"
  else
    pass "binding count is 2"
  fi
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
