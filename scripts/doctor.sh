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
note() { printf '        %s\n' "$1"; }

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
        note "USB controllers seen: ${EMPTY}. If one has no child device, the port or cable is at fault, not software."
    fi
fi

echo
echo "Terminal"

# The single most common cause of "the key does nothing". On the default
# setting macOS composes Option-P into π and Claude Code sees a character.
#
# "Option Key Sends" is the *left* Option key; the right one has its own entry.
# 2 is Esc+. The setting is per profile, so a reader with several profiles can
# fix the one they are not using and see no change at all.
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
if [ -f "$ITERM_PLIST" ]; then
    LEFT_OPT=$(plutil -convert xml1 -o - "$ITERM_PLIST" 2>/dev/null \
        | grep -A1 '<key>Option Key Sends</key>' \
        | grep -oE '<integer>[0-9]+' | grep -oE '[0-9]+' || true)
    TOTAL=$(printf '%s\n' "$LEFT_OPT" | grep -c '[0-9]' || true)
    ESCPLUS=$(printf '%s\n' "$LEFT_OPT" | grep -cx '2' || true)
    if [ "${TOTAL:-0}" -eq 0 ]; then
        warn "could not read iTerm2's Option key setting" \
             "Check Profiles → Keys → General → Left Option key is Esc+."
    elif [ "${ESCPLUS:-0}" -eq 0 ]; then
        bad "iTerm2 sends Option as a compose key in all ${TOTAL} profile(s)" \
            "Profiles → Keys → General → Left Option key → Esc+. Without it, opt+r types ® and Claude Code never sees the shortcut."
        note "opt+p, opt+o and opt+t work anyway — Claude Code maps π/ø/† back by hand — so do not take those working as proof."
    elif [ "$ESCPLUS" -lt "$TOTAL" ]; then
        ok "iTerm2 Left Option is Esc+ in ${ESCPLUS} of ${TOTAL} profiles"
        note "The setting is per profile. Make sure the one you actually use is the one you changed."
    else
        ok "iTerm2 Left Option is Esc+ in all ${TOTAL} profiles"
    fi
else
    note "iTerm2 preferences not found — skipping the Option key check."
fi

echo
echo "Claude Code configuration"

SETTINGS="$HOME/.claude/settings.json"
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

if [ "$HAVE_JQ" -eq 0 ]; then
    bad "jq is not installed" "brew install jq — most checks below need it."
elif [ ! -f "$SETTINGS" ]; then
    bad "no ~/.claude/settings.json" "Run Claude Code once to create it."
else
    EVENTS=$(jq -r '.hooks // {} | keys | join(", ")' "$SETTINGS" 2>/dev/null)
    if [ -n "${EVENTS:-}" ]; then
        ok "hooks wired: ${EVENTS}"

        # Each of the three events this repo installs does a distinct job, and
        # a missing one fails quietly rather than loudly. UserPromptSubmit is
        # the one people skip, and its absence looks like the jump key being
        # broken: sessions you answered by hand never leave the queue.
        for ev in Stop Notification UserPromptSubmit; do
            if jq -e --arg e "$ev" '.hooks[$e] // empty' "$SETTINGS" >/dev/null 2>&1; then
                ok "  $ev registered"
            else
                case "$ev" in
                    UserPromptSubmit)
                        warn "  UserPromptSubmit not registered" \
                             "Sessions you reach by hand will stay in the jump queue. Merge config/hooks.snippet.json again." ;;
                    *)
                        bad "  $ev not registered" \
                            "Merge config/hooks.snippet.json into settings.json." ;;
                esac
            fi
        done

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
        warn "no hooks configured" \
             "No notification when a session is ready, and the jump key will never have anywhere to go. Merge config/hooks.snippet.json into settings.json."
    fi

    MODE=$(jq -r '.voice.enabled // false | if . then "on" else "off" end' "$SETTINGS" 2>/dev/null)
    VMODE=$(jq -r '.voice.mode // "unset"' "$SETTINGS" 2>/dev/null)
    if [ "$MODE" = "on" ]; then
        ok "voice enabled (mode: ${VMODE})"
    else
        warn "voice is off" \
             "Run /voice hold inside Claude Code, in a terminal. Until then, holding Space types spaces and nothing says why."
    fi
fi

echo
echo "Jump to attention"

JUMP="$HOME/.claude/hooks/jump-to-attention.sh"
if [ -x "$JUMP" ]; then
    ok "jump-to-attention.sh installed and executable"
    if [ -f "$HOME/.claude/hooks/lib-attention.sh" ]; then
        ok "lib-attention.sh is beside it"
    else
        bad "lib-attention.sh is missing from ~/.claude/hooks/" \
            "The jump script sources it. Copy hooks/*.sh over."
    fi
    QUEUED=$(find "$HOME/.claude/macropad/attention" -type f 2>/dev/null | wc -l | tr -d ' ')
    note "sessions currently waiting: ${QUEUED:-0}"
elif [ -e "$JUMP" ]; then
    bad "jump-to-attention.sh is not executable" "chmod +x $JUMP"
else
    warn "jump-to-attention.sh is not installed" \
         "Copy scripts/jump-to-attention.sh to ~/.claude/hooks/. Without it there is no key to reach a waiting session."
fi

if [ -d "$HOME/Applications/JumpToAttention.app" ] || [ -d "/Applications/JumpToAttention.app" ]; then
    ok "JumpToAttention.app exists for pads that launch apps"
else
    note "No JumpToAttention.app. Only needed if your pad triggers the jump by launching an app rather than by a hotkey."
fi

echo
echo "Optional keybindings"

# keybindings.json is optional now: every key in the layout is one Claude Code
# binds itself. When it is present, the thing worth checking is not whether the
# action name is spelled right but whether the action does anything — eighteen
# of the 137 names in 2.1.233 are declared with no implementation behind them.
UNIMPLEMENTED="strip:jump1 strip:jump2 strip:jump3 strip:jump4 strip:jump5
strip:jump6 strip:jump7 strip:jump8 strip:jump9 strip:next strip:previous
strip:toggle strip:new chat:cycleProactivity chat:attentionUp
chat:attentionDown permission:toggleDebug selection:clear"

KB="$HOME/.claude/keybindings.json"
if [ ! -f "$KB" ]; then
    note "No ~/.claude/keybindings.json. That is fine — the whole layout uses Claude Code's own defaults."
elif [ "$HAVE_JQ" -eq 0 ]; then
    note "Skipping keybindings checks; jq is not installed."
elif ! jq empty "$KB" 2>/dev/null; then
    bad "keybindings.json is not valid JSON" "Run: bash tests/test-keybindings.sh $KB"
else
    COUNT=$(jq '[.bindings[]?.bindings // {} | to_entries[]] | length' "$KB" 2>/dev/null)
    ok "keybindings.json is valid (${COUNT:-0} bindings)"
    DEAD=""
    while IFS= read -r a; do
        [ -z "$a" ] && continue
        if echo "$UNIMPLEMENTED" | tr ' \n' '\n\n' | grep -qx "$a"; then
            DEAD="$DEAD $a"
        fi
    done < <(jq -r '.bindings[]?.bindings // {} | to_entries[] | .value | select(. != null)' "$KB" 2>/dev/null)
    if [ -n "$DEAD" ]; then
        bad "bindings use actions Claude Code never implemented:$DEAD" \
            "These keys will do nothing, with no error anywhere. Remove them or bind a different action."
    else
        ok "no binding uses an unimplemented action"
    fi
fi

echo
echo "Vendor software"
if pgrep -qf "input.app" 2>/dev/null; then
    ok "Work Louder Input is running"
else
    warn "Work Louder Input is not running" "Only needed to reprogram keys. The pad works without it."
fi

echo
printf 'passed %d   failed %d   warnings %d\n' "$PASS" "$FAIL" "$WARN"
echo

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
