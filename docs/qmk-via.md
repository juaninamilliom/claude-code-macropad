# QMK / VIA macropads

Any VIA-compatible board can send this layout. Every entry is one keystroke, so
they are plain keycodes — the **Macros** tab is not involved.

## Before you start

Set your terminal's Option key to send `Esc+` — in iTerm2, Profiles → Keys →
General → Left Option key. Without it macOS composes `LALT(KC_P)` into `π` and
Claude Code sees a character instead of a shortcut. See
[troubleshooting](troubleshooting.md).

## Keycodes

Assign these in the **Keymap** tab, one key each:

| Keycode | Does |
| --- | --- |
| `LCTL(KC_R)` | Search prompt history |
| `LCTL(KC_T)` | Todo list |
| `LCTL(KC_O)` | Transcript |
| `LSFT(KC_TAB)` | Cycle permission mode |
| `LCTL(KC_C)` | Interrupt |
| `LALT(KC_P)` | Model picker |
| `LALT(KC_T)` | Thinking toggle |
| `LALT(KC_O)` | Fast mode |
| `LCTL(KC_B)` | Background the task |
| `KC_SPACE` | Voice dictation, held |
| `KC_ENTER` | Submit |

Claude Code binds every one of these itself, so none of them needs an entry in
`keybindings.json`.

`LALT` is Option on macOS, which is what this repo means by `opt+p`. `LGUI` sends
Command instead, and your terminal acts on most Command keystrokes itself — in
iTerm2, Command-T opens a tab.

## The voice key

Assign a key to plain `KC_SPACE` — **not** a macro. Hold-to-talk needs the key
held down, and a macro completes immediately. A plain keycode passes the hold
through. Run `/voice hold` once in a terminal to switch voice on.

## Encoder and any spare keys

`KC_UP` / `KC_DOWN` for the encoder's rotation, `KC_ESCAPE` for its press.
`KC_LEFT` and `KC_RIGHT` are worth a key each if you have them spare: permission
prompts and the model picker are driven by arrows.

## Jumping to the session that wants you

This one is not a keycode. Claude Code has no working action for "go to the
session that needs me" — see [the README](../README.md#what-this-repo-does-not-do)
— so it is a shell script the notification hook feeds.

VIA cannot run a script, so route it through Karabiner-Elements: pick a keycode
no application uses, send it from the pad, and have Karabiner run
`$HOME/.claude/hooks/jump-to-attention.sh`. `docs/stream-deck.md` has [a working
manipulator](stream-deck.md#running-the-jump-script-from-a-key) you can paste.

## Not the desktop app

These are terminal shortcuts. The Claude desktop app does not act on them.
