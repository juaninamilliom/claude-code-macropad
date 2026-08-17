# Stream Deck, Karabiner, and other software pads

## Stream Deck

Use the built-in **Hotkey** action, one button per row of the table. Each
binding is a single keystroke, so no Multi Action and no steps are involved —
record the modifier and the key together.

| Button | Sends |
| --- | --- |
| Jump to session needing you | `alt+a` |
| Previous chat | `alt+k` |
| Next chat | `alt+j` |
| New chat | `alt+n` |
| Toggle chat strip | `alt+s` |

`alt` is Option; the Hotkey recorder shows it as ⌥.

Pass-through buttons are plain Hotkey actions: `shift+tab`, `opt+p`, `opt+t`,
`opt+o`, `ctrl+o`, `ctrl+t`, `ctrl+g`.

`opt` is Option. Claude Code binds the model picker, thinking toggle and fast
mode to `alt+p`, `alt+t` and `alt+o`, and `alt` is Option on macOS — not
Command. A Hotkey configured with Command sends a keystroke your terminal
handles itself.

**The voice key does not work on a Stream Deck.** Stream Deck sends discrete
press-and-release events and cannot hold a key for as long as you hold the
button, which is what hold-to-talk requires. Use `Space` on your keyboard, or
switch to tap mode with `/voice tap` — tap mode is press-to-start and
press-to-stop, which a Stream Deck button *can* drive.

## Karabiner-Elements

Map any spare key to a binding with a `to` array holding one event. This is one
manipulator object, not a whole config file — in
`~/.config/karabiner/karabiner.json` it nests under `profiles[]` →
`complex_modifications` → `rules[]` → `manipulators[]`, where each rule also
carries its own `description`:

```json
{
  "type": "basic",
  "from": { "key_code": "f13" },
  "to": [
    { "key_code": "k", "modifiers": ["left_option"] }
  ]
}
```

That example is Previous chat. For the other four, keep `left_option` and change
`key_code`: `j`, `n`, `s`, `a`.
