# QMK / VIA macropads

Any VIA-compatible board can send these chords. VIA's macro editor records
sequences directly.

## Macros

In VIA's **Macros** tab, define five macros. VIA macro syntax uses `{}` for
held-then-released groups:

| Macro | Content | Does |
| --- | --- | --- |
| M0 | `{KC_LCTL,KC_X}a` | Jump to session needing you |
| M1 | `{KC_LCTL,KC_X}[` | Previous chat |
| M2 | `{KC_LCTL,KC_X}]` | Next chat |
| M3 | `{KC_LCTL,KC_X}n` | New chat |
| M4 | `{KC_LCTL,KC_X}s` | Toggle chat strip |

Assign M0–M4 to keys in the **Keymap** tab.

## The voice key

Assign a key to plain `KC_SPACE` — **not** a macro. Hold-to-talk needs the key
held down, and a macro completes immediately. A plain keycode passes the hold
through.

## Pass-through keys

These need no macro and no entry in `keybindings.json`:

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
