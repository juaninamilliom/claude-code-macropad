# Stream Deck, Karabiner, and other software pads

## Before you start

Set your terminal's Option key to send `Esc+` — in iTerm2, Profiles → Keys →
General → Left Option key. Without it, macOS composes Option-P into `π` and
Claude Code sees a character instead of a shortcut.

## Stream Deck

Use the built-in **Hotkey** action, one button per row. Each is a single
keystroke, so no Multi Action and no steps are involved — record the modifier and
the key together.

| Button | Sends |
| --- | --- |
| Search prompt history | `ctrl+r` |
| Todo list | `ctrl+t` |
| Transcript | `ctrl+o` |
| Cycle permission mode | `shift+tab` |
| Interrupt | `ctrl+c` |
| Model picker | `opt+p` |
| Background the task | `ctrl+b` |
| Submit | `Enter` |

Claude Code binds all of these itself, so none needs an entry in
`keybindings.json`.

`opt` is Option; the Hotkey recorder shows it as ⌥. It is **not** Command — a
Hotkey configured with Command sends a keystroke your terminal handles itself,
so `cmd+t` opens an iTerm2 tab instead of reaching Claude Code.

**The voice key does not work on a Stream Deck.** Stream Deck sends discrete
press-and-release events and cannot hold a key for as long as you hold the
button, which is what hold-to-talk requires. Use `Space` on your keyboard, or
switch to tap mode with `/voice tap` — tap mode is press-to-start and
press-to-stop, which a Stream Deck button *can* drive.

For the jump-to-attention button, use a **System → Open** action pointing at
`JumpToAttention.app`; building it is one `osacompile` command, described in
[the Work Louder guide](work-louder-input.md#the-jump-key).

## Karabiner-Elements

### Mapping a spare key to a shortcut

One manipulator object, not a whole config file — in
`~/.config/karabiner/karabiner.json` it nests under `profiles[]` →
`complex_modifications` → `rules[]` → `manipulators[]`, where each rule also
carries its own `description`:

```json
{
  "type": "basic",
  "from": { "key_code": "f13" },
  "to": [
    { "key_code": "p", "modifiers": ["left_option"] }
  ]
}
```

That example is the model picker. For the others, keep `left_option` and change
`key_code` to `t` or `o`, or swap the modifier to `left_control` for `r`, `t`,
`o`, `c` and `b`.

### Running the jump script from a key

Karabiner is the way to put jump-to-attention on a pad that can only send
keystrokes. Send an otherwise-unused key from the pad and have Karabiner run the
script:

```json
{
  "type": "basic",
  "from": { "key_code": "f14" },
  "to": [
    { "shell_command": "$HOME/.claude/hooks/jump-to-attention.sh" }
  ]
}
```

`shell_command` runs without your login shell's environment, which is why the
path is absolute. The script needs nothing else from the environment: it reads
the markers the notification hook wrote and talks to iTerm2 directly.

Pads with a "launch application" action do not need this — point that action at
`JumpToAttention.app` instead.

## Not the desktop app

Everything here sends terminal shortcuts. The Claude desktop app does not act on
them.
