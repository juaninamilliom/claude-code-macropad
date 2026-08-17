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

| Row | Slot(s) | Type | Sends | Does |
| --- | --- | --- | --- | --- |
| 0 | 1 | Smart Action | Launch `Claude.app` | Open Claude |
| 0 | 2 | Key | `Escape` | Cancel input, decline a permission prompt |
| 1 | 1 | Chord | `ctrl+x` then `a` | Jump to session needing you |
| 1 | 2 | Chord | `ctrl+x` then `[` | Previous chat |
| 1 | 3 | Chord | `ctrl+x` then `]` | Next chat |
| 1 | 4 | Chord | `ctrl+x` then `n` | New chat |
| 2 | 1 | Key | `ctrl+c` | Interrupt a running turn |
| 2 | 2 | Key | `shift+tab` | Cycle permission mode |
| 2 | 3 | Chord | `ctrl+x` then `s` | Toggle chat strip |
| 2 | 4 | Key | `ctrl+o` | Transcript |
| 3 | **1 and 2** | Key | `Space` | Voice dictation, held — the fat key |
| 3 | 3 | Key | `Enter` | Submit / proceed |

The bottom row is the core loop: hold the fat key and talk, release, press
`Enter`. Two adjacent keys for dictate-and-send.

**Assign `Space` to both slot 1 and slot 2 of row 3.** The double-width key
reports through one of the two, and which one is not visible in the stored
keymap. Setting both is harmless and guarantees the key works either way.

Encoder: counter-clockwise `Up`, clockwise `Down`, press `Enter`. Those need no
binding — `Up`/`Down` already mean prompt history in the chat and scrolling in the
transcript, so one mapping is correct in both places. The press duplicates the
`Enter` key deliberately; whichever your hand reaches first.

Joystick: leave unassigned.

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
