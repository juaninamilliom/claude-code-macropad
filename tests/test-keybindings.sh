#!/bin/bash
# Validates a keybindings file against Claude Code's contexts and a hand-kept
# subset of its actions. A typo in either produces a binding that silently
# never fires, which is what this exists to catch.
#
#   bash tests/test-keybindings.sh                          # config/keybindings.json
#   bash tests/test-keybindings.sh ~/.claude/keybindings.json   # your installed file
#
# The context list is complete for 2.1.233. The action list is not: it is 21 of
# the 137 actions that release defines, covering what this repo binds plus the
# near neighbours you are most likely to reach for. A legitimate binding outside
# that 21 will be reported as unknown — extend VALID_ACTIONS rather than
# assuming the binding is wrong. Neither list is read from Claude Code, so this
# catches your typos but not an upstream rename.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-$ROOT/config/keybindings.json}"
FAILED=0

fail() { echo "FAIL: $*"; FAILED=1; }
pass() { echo "PASS: $*"; }

VALID_CONTEXTS="Global Chat Autocomplete Confirmation Help Transcript
HistorySearch Task ThemePicker Settings Tabs Attachments Footer
MessageSelector DiffDialog DiffPanel ModelPicker Select Plugin Scroll"

VALID_ACTIONS="strip:next strip:previous strip:new strip:toggle
strip:jump1 strip:jump2 strip:jump3 strip:jump4 strip:jump5
chat:attentionUp chat:attentionDown chat:cycleMode chat:submit
chat:externalEditor chat:stash chat:clearInput voice:pushToTalk
app:toggleTodos app:toggleTranscript app:interrupt history:search"

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
  if ! echo "$VALID_CONTEXTS" | tr ' \n' '\n\n' | grep -qx "$ctx"; then
    fail "unknown context: $ctx"
  else
    pass "context $ctx"
  fi
done < <(jq -r '.bindings[].context' "$FILE")

# 6. Every action is known
while IFS= read -r action; do
  if ! echo "$VALID_ACTIONS" | tr ' \n' '\n\n' | grep -qx "$action"; then
    fail "unknown action: $action"
  else
    pass "action $action"
  fi
done < <(jq -r '.bindings[].bindings | to_entries[] | .value | select(. != null)' "$FILE")

# 7. Exactly five bindings, per the spec. Guard the value first: an empty
#    COUNT makes `-ne` raise an error, and `if` reads that error as false.
COUNT=$(jq '[.bindings[].bindings | to_entries[]] | length' "$FILE" 2>/dev/null)
if [[ ! "$COUNT" =~ ^[0-9]+$ ]]; then
  fail "could not count bindings (got \"$COUNT\")"
elif [ "$COUNT" -ne 5 ]; then
  fail "expected 5 bindings, found $COUNT"
else
  pass "binding count is 5"
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
  pass "no bare-letter chord prefixes"
fi

# 9. Every binding sits under the mandated ctrl+x chord prefix. Without this,
#    five valid, correctly-counted, whitelisted bindings under any other
#    modifier would pass the whole suite.
SEEN=0
while IFS= read -r key; do
  SEEN=$((SEEN + 1))
  case "$key" in
    "ctrl+x "?*) ;;
    *) fail "binding \"$key\" is not under the ctrl+x prefix" ;;
  esac
done < <(jq -r '.bindings[].bindings | keys[]' "$FILE")
if [ "$SEEN" -eq 0 ]; then
  fail "no keystrokes to check for the ctrl+x prefix"
else
  pass "all bindings use the ctrl+x prefix"
fi

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
