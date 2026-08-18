#!/bin/bash
# Verifies notify-ready.sh names the project from the hook payload, so that
# three concurrent sessions produce three distinguishable notifications.
#
# The hook also writes an attention marker, which is not what this file tests —
# tests/test-attention.sh covers that. But dry-run mode suppresses the
# notification, not the marker, so without the redirect below every run of this
# suite would deposit files in the reader's real ~/.claude/macropad. Redirect
# first, assert afterwards.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/hooks/notify-ready.sh"
FAILED=0

TMPSTATE=$(mktemp -d)
trap 'rm -rf "$TMPSTATE"' EXIT
export CLAUDE_MACROPAD_STATE_DIR="$TMPSTATE"

# Asserts stdout and the exit status. Claude Code reads a hook's exit code —
# a non-zero exit is a signal, not a detail — so a run that prints the right
# line and then exits 2 is a failure, and has to be reported as one.
run_case() {
  local name="$1" payload="$2" expected="$3" actual status
  actual=$(printf '%s' "$payload" | CLAUDE_MACROPAD_DRY_RUN=1 bash "$SCRIPT" 2>/dev/null)
  status=$?
  if [ "$actual" = "$expected" ] && [ "$status" -eq 0 ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    if [ "$actual" != "$expected" ]; then
      echo "  expected: [$expected]"
      echo "  actual:   [$actual]"
    fi
    if [ "$status" -ne 0 ]; then
      echo "  expected exit 0, got $status"
    fi
    FAILED=1
  fi
}

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: hooks/notify-ready.sh does not exist"
  echo "RESULT: FAILED"; exit 1
fi

run_case "Stop names the project" \
  '{"hook_event_name":"Stop","cwd":"/tmp/demo-project"}' \
  "$(printf 'demo-project\tReady for input')"

run_case "Notification uses its own message" \
  '{"hook_event_name":"Notification","cwd":"/tmp/inbox-sync"}' \
  "$(printf 'inbox-sync\tNeeds your input')"

run_case "missing cwd falls back" \
  '{"hook_event_name":"Stop"}' \
  "$(printf 'Claude Code\tReady for input')"

run_case "directory name containing a space survives" \
  '{"hook_event_name":"Stop","cwd":"/tmp/my app"}' \
  "$(printf 'my app\tReady for input')"

run_case "quotes in the path do not break the payload" \
  '{"hook_event_name":"Stop","cwd":"/tmp/it'"'"'s here"}' \
  "$(printf "it's here\tReady for input")"

run_case "empty stdin does not hang or crash" \
  '' \
  "$(printf 'Claude Code\tReady for input')"


# --- CLAUDE_CODE_PROJECT_DIR_NAME -------------------------------------------
# Added in Claude Code 2.1.234 for hosts that give each session a scratch or
# worktree directory, where the cwd basename is a generated string. The gating
# mirrors Claude Code's own: only honoured alongside CLAUDE_CONFIG_DIR, only
# /^[A-Za-z0-9_-]{1,64}$/, never a Windows reserved device name. Anything looser
# would let this notification name a project differently from Claude Code.

env_case() {
  local name="$1" expected="$2"; shift 2
  local actual status
  actual=$(printf '%s' '{"hook_event_name":"Stop","cwd":"/tmp/scratch-a1b2c3"}' \
           | env "$@" CLAUDE_MACROPAD_DRY_RUN=1 bash "$SCRIPT" 2>/dev/null)
  status=$?
  if [ "$actual" = "$expected" ] && [ "$status" -eq 0 ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "  expected: [$expected]"
    echo "  actual:   [$actual]"
    FAILED=1
  fi
}

env_case "project dir name is used when the config dir is set too" \
  "$(printf 'my-project\tReady for input')" \
  CLAUDE_CONFIG_DIR=/tmp/cfg CLAUDE_CODE_PROJECT_DIR_NAME=my-project

env_case "ignored without CLAUDE_CONFIG_DIR, as Claude Code ignores it" \
  "$(printf 'scratch-a1b2c3\tReady for input')" \
  CLAUDE_CODE_PROJECT_DIR_NAME=my-project

env_case "a name with a slash is rejected, not used as a path" \
  "$(printf 'scratch-a1b2c3\tReady for input')" \
  CLAUDE_CONFIG_DIR=/tmp/cfg CLAUDE_CODE_PROJECT_DIR_NAME=../../etc

env_case "a Windows reserved device name is rejected" \
  "$(printf 'scratch-a1b2c3\tReady for input')" \
  CLAUDE_CONFIG_DIR=/tmp/cfg CLAUDE_CODE_PROJECT_DIR_NAME=NUL

env_case "a name over 64 characters is rejected" \
  "$(printf 'scratch-a1b2c3\tReady for input')" \
  CLAUDE_CONFIG_DIR=/tmp/cfg \
  CLAUDE_CODE_PROJECT_DIR_NAME=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASSED"; exit 0; fi
echo "RESULT: FAILED"; exit 1
