#!/bin/bash
# One command that answers "why isn't my macropad working" without a debugging
# session. Checks the whole chain, hardware to Claude Code, and names the next
# action for whatever is broken.
#
# Read-only. Changes nothing.

set -uo pipefail

PASS=0
FAIL=0
WARN=0

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; printf '        → %s\n' "$2"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; printf '        → %s\n' "$2"; WARN=$((WARN + 1)); }

echo
echo "Hardware"

# A macropad is a keyboard. If macOS cannot see it, nothing downstream matters.
HID=$(ioreg -c IOHIDDevice -r 2>/dev/null | grep -E '"Product" =' | grep -icE "creator|work ?louder" || true)
if [ "${HID:-0}" -gt 0 ]; then
    ok "macropad present on the HID bus"
else
    bad "no macropad on the HID bus" \
        "Plug it directly into the computer, not through a dock or hub, and use a data cable. Hub chains are the usual cause of dropouts across sleep and undock."

    # An empty USB root controller means nothing is electrically present —
    # which distinguishes a cable/port fault from a driver or config problem.
    EMPTY=$(ioreg -p IOUSB 2>/dev/null | grep -c "XHCI" || true)
    if [ "${EMPTY:-0}" -gt 0 ]; then
        printf '        %s\n' "USB controllers seen: ${EMPTY}. If one has no child device, the port or cable is at fault, not software."
    fi
fi

echo
echo "Claude Code configuration"

KB="$HOME/.claude/keybindings.json"
if [ -f "$KB" ]; then
    if command -v jq >/dev/null 2>&1 && jq empty "$KB" 2>/dev/null; then
        COUNT=$(jq '[.bindings[].bindings | to_entries[]] | length' "$KB" 2>/dev/null)
        if [ "${COUNT:-0}" -gt 0 ]; then
            ok "keybindings.json installed and valid (${COUNT} bindings)"
        else
            bad "keybindings.json has no bindings" "Copy config/keybindings.json over it, or merge the five chords by hand."
        fi
    else
        bad "keybindings.json is not valid JSON" "Run: bash tests/test-keybindings.sh $KB"
    fi
else
    bad "no ~/.claude/keybindings.json" "Copy config/keybindings.json there. Chords will not fire without it."
fi

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    EVENTS=$(jq -r '.hooks // {} | keys | join(", ")' "$SETTINGS" 2>/dev/null)
    if [ -n "${EVENTS:-}" ] && [ "$EVENTS" != "" ]; then
        ok "hooks wired: ${EVENTS}"
        # A hook pointing at a missing script fails silently, which is the
        # partial-install state the README warns about.
        while IFS= read -r cmd; do
            [ -z "$cmd" ] && continue
            resolved="${cmd/\$HOME/$HOME}"
            if [ -x "$resolved" ]; then
                ok "hook script present and executable: $(basename "$resolved")"
            else
                bad "hook registered but script missing or not executable: $cmd" \
                    "Copy hooks/*.sh to ~/.claude/hooks/ and chmod +x them."
            fi
        done < <(jq -r '.hooks // {} | .[][].hooks[].command' "$SETTINGS" 2>/dev/null | sort -u)
    else
        warn "no hooks configured" "You will get no notification when a session is ready. Merge config/hooks.snippet.json into settings.json."
    fi
else
    bad "no ~/.claude/settings.json, or jq is missing" "Run Claude Code once to create it; install jq with: brew install jq"
fi

if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    MODE=$(jq -r '.voice.enabled // false | if . then "on" else "off" end' "$SETTINGS" 2>/dev/null)
    VMODE=$(jq -r '.voice.mode // "unset"' "$SETTINGS" 2>/dev/null)
    if [ "$MODE" = "on" ]; then
        ok "voice enabled (mode: ${VMODE})"
    else
        warn "voice is off" "Run /voice hold inside Claude Code, in a terminal. Until then, holding Space types spaces and nothing says why."
    fi
fi

echo
echo "Vendor software"
if pgrep -qf "input.app" 2>/dev/null; then
    ok "Work Louder Input is running"
else
    warn "Work Louder Input is not running" "Only needed to reprogram keys. Chords work without it."
fi

echo
printf 'passed %d   failed %d   warnings %d\n' "$PASS" "$FAIL" "$WARN"
echo

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
