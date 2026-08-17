# Troubleshooting

## A key does nothing at all

Work down this list. It is ordered by how often each cause was the real one
while building this.

### 1. Is Option composing a character instead of modifying?

This is the most common cause by a wide margin, and its symptom is misleading.

On macOS, Option is a compose key by default: Option-P types `π`, Option-R types
`®`, Option-A types `å`. Claude Code then receives a character, not a shortcut,
and does nothing — silently.

In iTerm2: **Profiles → Keys → General → Left Option key → `Esc+`**.

The reason this is confusing rather than obvious: Claude Code hard-codes a
fallback that maps `π`, `ø` and `†` back to `opt+p`, `opt+o` and `opt+t`. Those
three shortcuts therefore work on the wrong setting, and every other Option key
does not. **`opt+p` working does not mean Option is configured correctly.** Test
with `opt+r` instead — if it types `®`, the setting is wrong.

### 2. Is the key an F-key?

Function keys cannot work in a terminal. Claude Code's escape-sequence parser
decodes exactly four of these sequences — `home`, `end`, `pageup`, `pagedown` —
and no function key is among them. F8 sends `\x1B[19~`, which is never turned
into a key event.

Nothing can be configured to fix this. Choose a different key.

### 3. Is the action one that Claude Code never implemented?

Eighteen of its 137 action names have nothing behind them. A binding to one of
these validates, loads, matches your keypress, and then does nothing — with no
error at any layer.

```
strip:jump1 … strip:jump9   chat:attentionUp        permission:toggleDebug
strip:next  strip:previous  chat:attentionDown      selection:clear
strip:toggle strip:new      chat:cycleProactivity
```

Check your file:

```bash
bash tests/test-keybindings.sh ~/.claude/keybindings.json
```

Give it the path. Without one it checks the repo's own copy, which always passes
in a clean clone and tells you nothing about yours.

### 4. Is the pad sending Option rather than Command?

Command-T and Command-O are menu shortcuts your terminal acts on itself, so a key
recorded with the wrong modifier opens a tab or a file dialog instead of reaching
Claude Code. Re-record it with Option held.

### 5. Are you in the desktop app?

The layout is terminal shortcuts. The Claude desktop app does not act on them.
Use a terminal.

### Confirming the config loads at all

Rebind something with an unmistakable effect and press it:

```json
{ "bindings": [ { "context": "Chat", "bindings": { "alt+m": "chat:modelPicker" } } ] }
```

If `opt+m` opens the model picker, your `keybindings.json` is being read and the
problem is the specific binding, not the file. This one test separates "the
config is ignored" from "that action does nothing", which otherwise look
identical.

To see the loader's own output, start Claude Code **interactively** with
`claude --debug-file /tmp/cc-debug.log`, quit, then
`grep -i keybindings /tmp/cc-debug.log`. Do not pipe `claude --debug` into
`grep` — the pipe switches Claude Code to `--print` mode, which exits
complaining that no prompt was given, and `grep` hides the error and prints
nothing. `-p` does not help: a headless run logs no keybinding lines at all.

## The dial scrolls fine but cannot choose an option

It is set to `PageUp`/`PageDown`. Set it to `Up`/`Down` instead.

Claude Code binds `up` and `down` in every context that holds a list —
`confirm:previous`/`next` for permission prompts, `select:previous`/`next` for
the model picker and settings, `autocomplete:previous`/`next` for the command
menu, `history:previous`/`next` in the chat input. It binds `pageup` and
`pagedown` only in its scrolling contexts.

So the page keys scroll output perfectly and do nothing at all in a dialog,
which is a confusing thing to debug: the dial visibly works right up to the
moment you need it. If you want a page-at-a-time scroll as well, put it on a
second axis — a joystick or a spare pair of keys.

## The jump key does nothing

```bash
~/.claude/hooks/jump-to-attention.sh --list
```

**"nothing waiting"** — no session has asked for you since you last cleared the
queue. Nothing is broken. Give a session a task, let it finish, and try again.

**Sessions are listed but the key does not move you** — the pad's action is not
reaching the script. Run the script by hand; if that works, the fault is in the
Smart Action or the Karabiner rule, not here.

**It says it cannot talk to iTerm2** — grant Automation permission. macOS asks
once, and a denied prompt is remembered: System Settings → Privacy & Security →
Automation.

**Nothing is ever listed, even after a session finishes** — the hooks are not
wired. See below.

The script only knows about iTerm2. Under Terminal.app or another terminal the
marker is written but cannot be used, and the script says so.

## Hooks never fire

Check that `settings.json` actually has them:

```bash
jq '.hooks' ~/.claude/settings.json
```

`null` means the merge did not happen. Note that hook commands are **not**
tilde-expanded — use `$HOME/.claude/hooks/…`, never `~/.claude/hooks/…`.

Test the script directly:

```bash
echo '{"hook_event_name":"Stop","cwd":"/tmp/demo"}' | \
  CLAUDE_MACROPAD_DRY_RUN=1 ~/.claude/hooks/notify-ready.sh
```

Expected: `demo	Ready for input`.

## Sessions stay in the queue after I have dealt with them

`UserPromptSubmit` is not wired, so nothing clears a session you reached by hand.
Confirm all three hooks:

```bash
jq -r '.hooks | to_entries[] | "\(.key): \(.value[].hooks[].command)"' ~/.claude/settings.json
```

You want `Stop` and `Notification` on `notify-ready.sh`, and `UserPromptSubmit`
on `clear-attention.sh`.

## Holding Space just types spaces

Voice is off. `voiceEnabled: true` in `settings.json` is **not** the switch — it
records that you have decided about voice, and its presence suppresses the
startup tip that would otherwise offer to enable it. The real switch is a
separate object:

```jsonc
"voice": { "enabled": true, "mode": "hold" }
```

Do not hand-edit it. Run:

```
/voice hold
```

Modes are `hold` (hold Space, speak, release), `tap` (tap to start, tap to end),
and `off`.

## `/voice` is not available

Two different causes:

- **"isn't available in this environment"** — you are in the desktop app. The
  command is terminal-only. Run it in a terminal; `settings.json` is global, so
  it applies everywhere afterwards.
- **The command does not appear at all** — it is gated on `allow_voice_mode` and
  on `claude-ai` account availability. This is account-level, not configuration.
  No amount of config editing will surface it.

## Voice takes a few seconds to start

Expected on the first press of a session. Claude Code lazily loads its native
audio module, then opens a WebSocket to the transcription service. It logs
`buffering audio while WebSocket connects` — your speech is buffered locally and
flushed once connected, so nothing is lost. Later presses in the same session are
faster.

## Notifications appear but do not say which project

You are running an older `notify-ready.sh`. Copy the current one from `hooks/`.

## The pad's LEDs do not react to Claude Code

They cannot. There is no host-to-device channel — the configuration software is
closed-source with no documented API. Nothing in this repo can light up a key.
