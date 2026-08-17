# Work Louder Creator Micro 2

The Creator Micro 2 has **12 physical keys across 13 matrix slots**, one encoder,
and a radial joystick. The matrix is 2 / 4 / 4 / 3, but the bottom-left key is
double-width and occupies **both** of row 3's first two slots. Twelve keys, not
thirteen — a distinction that matters when you are assigning them.

Input numbers layers from 1 in its interface, while the stored configuration
counts from 0. "Layer 1" in the app is layer id 0 on disk.

## Before you start

The bundled ChatGPT layer is built on vendor firmware keycodes (`KV_OAI_AG00`,
`KV_OAI_ACT06`, …) that mean nothing outside OpenAI's integration, so there is
nothing in it to repoint at Claude Code. Build a **new layer** rather than
editing that one.

You also cannot script this. Input stores a sha1 checksum for `keymap.json` in
`input_storage.json`, so hand-editing the file desynchronises it, and the layer
still has to be synced to the device by the app. Fifteen minutes of clicking is
the honest cost.

## Getting the Input app

Everything below happens in Work Louder's **Input** configurator, a separate
download that does not ship with the pad. Get it from <https://worklouder.cc/input>
— macOS builds for Apple silicon and Intel, plus Windows and Linux — then
install it and connect the Creator Micro 2 by USB before starting. Without it the
pad still works as an ordinary keyboard; you simply cannot reprogram anything.

## Key assignments

This layout assumes you want to drive Claude Code **without touching the
keyboard**. Three assignment types appear:

- **Key** — a single key or combination, assigned normally. Passes a physical
  hold straight through, which matters for voice.
- **Chord** — a Multi Action sending two keystrokes *in sequence*.
- **Smart Action** — Input's app-launcher type (`APP_STEP`).

### Reading the grid

The face is a **4 × 4 grid**, and three of its sixteen cells are not ordinary
keys. Input shows the layout visually — click a cell and it highlights, so you
never have to count positions.

```
        col 0        col 1        col 2        col 3
row 0   ◉ DIAL       key          key          ✛ JOYSTICK
row 1   key          key          key          key
row 2   key          key          key          key
row 3   ⇄ LAYER      ▒▒▒▒ fat key ▒▒▒▒         key
```

That leaves **12 assignable keys**. The bottom-left cell switches layers and is
left alone; the fat key is double-width and covers both (3,1) and (3,2).

This is also why the stored keymap reads 2 / 4 / 4 / 3: row 0 has two keys
because the dial and joystick take its outer cells, and row 3 has three slots
because the layer key is not part of the keymap.

### The keys

| Row | Column | Type | Sends | Does |
| --- | --- | --- | --- | --- |
| 0 | 1 | Smart Action | Launch `Claude.app` | Open Claude |
| 0 | 2 | Chord | `ctrl+x` then `a` | Jump to session needing you |
| 1 | 0 | Chord | `ctrl+x` then `n` | New chat |
| 1 | 1 | Chord | `ctrl+x` then `s` | Toggle chat strip |
| 1 | 2 | Key | `ctrl+o` | Transcript |
| 1 | 3 | Key | `ctrl+c` | Interrupt a running turn |
| 2 | 0 | Key | `shift+tab` | Cycle permission mode |
| 2 | 1 | Key | `opt+p` | Model picker |
| 2 | 2 | Key | `opt+t` | Thinking toggle |
| 2 | 3 | Key | `opt+o` | Fast mode |
| 3 | **1 and 2** | Key | `Space` | Voice dictation, held — the fat key |
| 3 | 3 | Key | `Enter` | Submit / proceed |

The bottom row is the core loop: hold the fat key and talk, release, press
`Enter` beside it. Dictate and send, two adjacent keys.

**Assign `Space` to both (3,1) and (3,2).** The double-width key reports through
one of the two and the stored keymap does not reveal which. Setting both is
harmless and guarantees it works either way.

### The dial and the joystick

Both are configured separately from the keys — they are not rows in the keymap,
so they get their own sections in Input.

| Input | Assignment | Why |
| --- | --- | --- |
| Dial, counter-clockwise | `ctrl+x` then `[` | Previous chat |
| Dial, clockwise | `ctrl+x` then `]` | Next chat |
| Dial, press | `Escape` | Cancel, or decline a permission prompt |
| Joystick, 4 sectors | `Up` `Down` `Left` `Right` | Navigate dialogs and select lists |

Cycling sessions on the dial is what frees the two keys that would otherwise
hold previous and next — which is how all twelve keys end up carrying something.

Arrow keys on the joystick matter more than they look: permission prompts, the
model picker, and every select list are driven by arrows, so without them a
pad-only workflow stalls at the first dialog.

The joystick is radial, defined by angle ranges rather than named directions.
Assign the four directional sectors to the arrows that match what Input shows for
each direction. If your device already has a narrow sector set to `KI_X`, leave
it — it appears in untouched layers too and is not something you set.

### Shortcuts deliberately left off the pad

Twelve keys does not cover everything. These stay on the keyboard, being single
keystrokes you rarely want mid-flow:

| Key | Does |
| --- | --- |
| `opt+p` | Model picker |
| `opt+t` | Thinking toggle |
| `opt+o` | Fast mode |
| `ctrl+t` | Todo list |
| `ctrl+g` | External editor |

`opt` is Option, not Command. Claude Code spells these `alt+…`, the same modifier
on macOS. If you do put one on a spare pad key, press Option when Input records
it — Command produces a chord iTerm2 intercepts before Claude Code sees it.

## The voice key is different

Row 3's fat key must be a **plain `Space` key assignment, not a macro and not a
chord.** Hold-to-talk is defined by its release: you hold the key, speak, and
release to end. A macro fires and completes; it cannot be held. Assign `Space`
as an ordinary key so the physical hold passes straight through.

Held keys do work on this pad — a modifier such as `KC_LSFT` assigned to a pad
key behaves as a real held modifier, which is the same mechanism voice relies on.

## Steps in Input

1. Open Input with the Creator Micro 2 connected (see
   [Getting the Input app](#getting-the-input-app) if you do not have it).
2. Select the **Default** profile. Add a new layer and name it `Claude Code`.
3. For each **Key** row: click the key in the layout, choose the keyboard shortcut
   assignment, and press the combination.
4. For each **Chord** row: click the key, choose **Multi Action**, and add two
   steps — first `ctrl+x`, then the second key on its own. Order matters.
5. For the **Smart Action** row: choose Smart Action, pick the app type, and point
   it at `/Applications/Claude.app`.
6. Row 3's fat key: assign `Space` to both of its slots.
7. Set the encoder's three actions.
8. Sync to the device.
9. Optional: under linked apps, link this layer to iTerm and Claude, so the chords
   only fire where they mean something.

## Verifying

Open Claude Code and press each key once, top to bottom, against the table above.
If a chord types raw text instead of acting, the Multi Action is sending both
keystrokes simultaneously rather than in sequence — rebuild it as two ordered
steps.
