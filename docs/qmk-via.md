# QMK / VIA macropads

Any VIA-compatible board can send these bindings. Each is one modified
keystroke, so they are plain keycodes — the **Macros** tab is not involved.

## Keycodes

Assign these in the **Keymap** tab, one key each:

| Keycode | Does |
| --- | --- |
| `LALT(KC_A)` | Jump to session needing you |
| `LALT(KC_K)` | Previous chat |
| `LALT(KC_J)` | Next chat |
| `LALT(KC_N)` | New chat |
| `LALT(KC_S)` | Toggle chat strip |

`LALT` is Option on macOS, which is what Claude Code means by `alt+a` and the
rest. `LGUI` sends Command instead, and your terminal acts on most Command
keystrokes itself.

## The voice key

Assign a key to plain `KC_SPACE` — **not** a macro. Hold-to-talk needs the key
held down, and a macro completes immediately. A plain keycode passes the hold
through.

## Pass-through keys

Claude Code binds these itself, so they need no entry in `keybindings.json`:

| Keycode | Does |
| --- | --- |
| `LSFT(KC_TAB)` | Cycle permission mode |
| `LALT(KC_P)` | Model picker |
| `LALT(KC_T)` | Thinking toggle |
| `LALT(KC_O)` | Fast mode |
| `LCTL(KC_O)` | Transcript |
| `LCTL(KC_T)` | Todo list |
| `LCTL(KC_G)` | External editor |

Those three are `LALT`, not `LGUI`. Claude Code binds them to `alt+p`, `alt+o`
and `alt+t`, which is Option on macOS. `LGUI` sends Command, which most
terminals either swallow or act on themselves — in iTerm2, Command-T opens a
tab.

## Encoder

`KC_UP` / `KC_DOWN` / `KC_ENTER`.
