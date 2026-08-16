# Stream Deck, Karabiner, and other software pads

## Stream Deck

Use the built-in **Hotkey** action, one button per row of the table.

For the five chords, a single Hotkey action cannot send two keystrokes in
sequence. Use **Multi Action** instead, with two Hotkey steps: `ctrl+x`, then the
second key alone.

| Button | Step 1 | Step 2 |
| --- | --- | --- |
| Jump to session needing you | `ctrl+x` | `a` |
| Previous chat | `ctrl+x` | `[` |
| Next chat | `ctrl+x` | `]` |
| New chat | `ctrl+x` | `n` |
| Toggle chat strip | `ctrl+x` | `s` |

Pass-through buttons are plain Hotkey actions: `shift+tab`, `opt+p`, `opt+t`,
`opt+o`, `ctrl+o`, `ctrl+t`, `ctrl+g`.

`opt` is Option. Claude Code binds the model picker, thinking toggle and fast
mode to `alt+p`, `alt+t` and `alt+o`, and `alt` is Option on macOS — not
Command. A Hotkey configured with Command sends a chord your terminal handles
itself.

**The voice key does not work on a Stream Deck.** Stream Deck sends discrete
press-and-release events and cannot hold a key for as long as you hold the
button, which is what hold-to-talk requires. Use `Space` on your keyboard, or
switch to tap mode with `/voice tap` — tap mode is press-to-start and
press-to-stop, which a Stream Deck button *can* drive.

## Karabiner-Elements

Map any key to a chord with a `to` array of two events. This is one manipulator
object, not a whole config file — in `~/.config/karabiner/karabiner.json` it
nests under `profiles[]` → `complex_modifications` → `rules[]` → `manipulators[]`,
where each rule also carries its own `description`:

```json
{
  "type": "basic",
  "from": { "key_code": "f13" },
  "to": [
    { "key_code": "x", "modifiers": ["left_control"] },
    { "key_code": "open_bracket" }
  ]
}
```

That example is Previous chat. For the other four, keep the first `to` event and
change the second `key_code`: `close_bracket`, `n`, `s`, `a`.
