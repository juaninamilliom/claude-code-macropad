# Work Louder Creator Micro 2

The Creator Micro 2 has 13 keys in rows of 2 / 4 / 4 / 3, one encoder, and a
radial joystick.

## Before you start

The bundled ChatGPT layer cannot be adapted. It is built on vendor firmware
keycodes (`KV_OAI_AG00`, `KV_OAI_ACT06`, …) that are locked in the Input UI and
cannot be pointed at anything else. Build a **new layer** instead; leave that one
alone.

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

Rows top to bottom. "Chord" means a Multi Action that sends two keystrokes in
sequence; "Key" means a single key or combination.

| Row | Position | Type | Sends | Does |
| --- | --- | --- | --- | --- |
| 0 | 1 | Key | `Space` | Voice dictation (hold) |
| 0 | 2 | Chord | `ctrl+x` then `a` | Jump to session needing you |
| 1 | 1 | Chord | `ctrl+x` then `[` | Previous chat |
| 1 | 2 | Chord | `ctrl+x` then `]` | Next chat |
| 1 | 3 | Chord | `ctrl+x` then `n` | New chat |
| 1 | 4 | Chord | `ctrl+x` then `s` | Toggle chat strip |
| 2 | 1 | Key | `shift+tab` | Cycle permission mode |
| 2 | 2 | Key | `opt+p` | Model picker |
| 2 | 3 | Key | `opt+t` | Thinking toggle |
| 2 | 4 | Key | `opt+o` | Fast mode |
| 3 | 1 | Key | `ctrl+o` | Transcript |
| 3 | 2 | Key | `ctrl+t` | Todo list |
| 3 | 3 | Key | `ctrl+g` | External editor |

`opt` is Option, not Command. Claude Code spells those three `alt+…`, which is
the same modifier on macOS. When Input asks you to press the combination, press
Option — pressing Command records a chord that iTerm2 intercepts before Claude
Code ever sees it.

Encoder: counter-clockwise `Up`, clockwise `Down`, press `Enter`. Those need no
binding — `Up`/`Down` already mean prompt history in the chat and scrolling in the
transcript, so one mapping is correct in both places.

Joystick: leave unassigned.

## The voice key is different

Row 0 Key 1 must be a **plain `Space` key assignment, not a macro and not a
chord.** Hold-to-talk is defined by its release: you hold the key, speak, and
release to end. A macro fires and completes; it cannot be held. Assign `Space`
as an ordinary key so the physical hold passes straight through.

## Steps in Input

1. Open Input with the Creator Micro 2 connected (see
   [Getting the Input app](#getting-the-input-app) if you do not have it).
2. Select the **Default** profile. Add a new layer and name it `Claude Code`.
3. For each **Key** row above: click the key in the layout, choose the keyboard
   shortcut assignment, and press the combination.
4. For each **Chord** row: click the key, choose **Multi Action**, and add two
   steps — first `ctrl+x`, then the second key on its own. Order matters.
5. Set the encoder's three actions.
6. Sync to the device.
7. Optional: under linked apps, link this layer to iTerm and Claude, so the
   chords only fire where they mean something.

## Verifying

Open Claude Code and press each key once, top to bottom, against the table above.
If a chord types raw text instead of acting, the Multi Action is sending both
keystrokes simultaneously rather than in sequence — rebuild it as two ordered
steps.
