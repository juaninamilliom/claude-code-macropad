#!/bin/bash
# Shared by the attention hooks and by scripts/jump-to-attention.sh.
#
# Sourced, never executed. It exists so the marker key is defined exactly once:
# notify-ready.sh writes a marker, clear-attention.sh deletes one, and
# jump-to-attention.sh reads them all. If those three ever disagreed about how a
# key is spelled, markers would be written and never cleared, and the symptom
# would be a jump key that cycles through windows with nothing waiting in them.

# Where markers live. CLAUDE_MACROPAD_STATE_DIR redirects it, which is how the
# tests avoid touching a real ~/.claude.
macropad_attention_dir() {
    printf '%s/attention' "${CLAUDE_MACROPAD_STATE_DIR:-$HOME/.claude/macropad}"
}

# The name to show for a session's project. $1 is the payload's cwd.
#
# Normally the directory name, which is what you recognise. But a host that
# gives each session a scratch or worktree directory can set
# CLAUDE_CODE_PROJECT_DIR_NAME (added in Claude Code 2.1.234) so the project
# keeps its real name, and there the directory basename is a generated string
# that tells you nothing — exactly the case where "which project wants me?"
# matters most.
#
# The gating below mirrors Claude Code's own, deliberately: it honours the
# variable only when CLAUDE_CONFIG_DIR is also set, requires
# /^[A-Za-z0-9_-]{1,64}$/, and rejects the Windows reserved device names. Using
# looser rules would let this notification disagree with the project name Claude
# Code itself uses, which is worse than falling back to the directory.
macropad_project() {
    local cwd="${1:-}" name="${CLAUDE_CODE_PROJECT_DIR_NAME:-}"
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -n "$name" ] \
       && printf '%s' "$name" | grep -qE '^[A-Za-z0-9_-]{1,64}$' \
       && ! printf '%s' "$name" | grep -qiE '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$'; then
        printf '%s' "$name"
        return 0
    fi
    if [ -n "$cwd" ]; then
        basename "$cwd"
    else
        printf 'Claude Code'
    fi
}

# The iTerm2 session UUID for this terminal window, empty elsewhere.
#
# ITERM_SESSION_ID looks like "w0t0p0:UUID". The prefix is the window/tab/pane
# the session was born in and goes stale as soon as a pane is moved; the UUID
# after the colon is what iTerm2 exposes as a session's `id` property and stays
# put. Only the UUID is worth recording.
macropad_iterm_session() {
    local v="${ITERM_SESSION_ID:-}"
    printf '%s' "${v#*:}"
}

# The tty of the claude process, not of the hook — a hook's stdin is the JSON
# payload, so it has no controlling terminal of its own. Walk up the process
# tree until something reports one.
macropad_tty() {
    local p="${PPID:-}" t i
    for i in 1 2 3 4 5; do
        [ -n "$p" ] && [ "$p" != 0 ] || return 0
        t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
        case "$t" in
            ""|'??') ;;
            *) printf '/dev/%s' "$t"; return 0 ;;
        esac
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
}

# The marker filename for the calling session. $1 is an optional last-resort
# fallback (the payload's session_id) for terminals that expose neither an
# iTerm2 session id nor a tty.
#
# Keyed by terminal window rather than by Claude session, so one window holds
# exactly one marker: resuming a session in the same window replaces its marker
# instead of leaving a second one behind.
macropad_key() {
    local fallback="${1:-}" key
    key=$(macropad_iterm_session)
    if [ -z "$key" ]; then
        key=$(macropad_tty)
        key="${key#/dev/}"
    fi
    [ -n "$key" ] || key="$fallback"
    # Whatever it came from, it has to be a safe filename.
    printf '%s' "$key" | tr -c 'A-Za-z0-9._-' '_'
}
