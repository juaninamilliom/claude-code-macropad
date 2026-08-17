# Troubleshooting

## Holding Space just types spaces

Voice is off. `voiceEnabled: true` in `settings.json` is **not** the switch —
it records that you have decided about voice, and its presence suppresses the
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

## Nothing happens when I press a chord key

In order:

1. **Is `~/.claude/keybindings.json` installed?** `cat ~/.claude/keybindings.json`
2. **Does *that* file validate?** From a clone of this repo, point the checker at
   your installed file — give it the path, or it checks the repo's own copy,
   which always passes in a clean clone and tells you nothing about yours:

   ```bash
   bash tests/test-keybindings.sh ~/.claude/keybindings.json
   ```

   It checks every context against a complete snapshot, and every action against
   a hand-kept 21-action subset of the 137 actions in 2.1.233 — enough to catch a
   typo, not a full list. If it rejects a binding you know is real (`strip:jump6`
   through `strip:jump9`, for instance), extend `VALID_ACTIONS` in the script.
   To see the loader's own output, start Claude Code **interactively** with
   `claude --debug-file /tmp/cc-debug.log`, quit, then
   `grep -i keybindings /tmp/cc-debug.log`. That is the place to look. Do not
   pipe `claude --debug` into `grep` — the pipe switches Claude Code to
   `--print` mode, which exits complaining that no prompt was given, and `grep`
   hides the error and prints nothing. `-p` does not help: a headless run logs
   no keybinding lines at all.
3. **Is the pad sending a sequence, not a simultaneous combo?** If the chord types
   raw characters, the two keystrokes are firing together. Rebuild as two ordered
   steps.
4. **Is something else eating `ctrl+x`?** tmux and screen use their own prefixes.
   If you have rebound either to `ctrl+x`, change the prefix in
   `config/keybindings.json` and your device config — the two must match.

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

## Notifications appear but do not say which project

You are running an older `notify-ready.sh`. Copy the current one from `hooks/`.

## The pad's LEDs do not react to Claude Code

They cannot. There is no host-to-device channel — the configuration software is
closed-source with no documented API. Nothing in this repo can light up a key.
