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
keyboard**. Two assignment types appear:

- **Key** — a single key or modifier combination, recorded on the Basic tab.
  Passes a physical hold straight through, which matters for voice.
- **Smart Action** — Input's app-launcher type (`APP_STEP`).

Nothing here asks Input for a two-keystroke sequence, because it cannot send
one: the **Multi** tab builds a multi-function key — tap, double-tap, hold,
tap+hold — and the **Actions** tab records a *simultaneous* combination,
modifiers and characters fired together. Every binding below is therefore a
modifier held with one key, which the Basic tab records directly.

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
| 0 | 2 | Key | `opt+a` | Jump to session needing you |
| 1 | 0 | Key | `opt+n` | New chat |
| 1 | 1 | Key | `opt+s` | Toggle chat strip |
| 1 | 2 | Key | `ctrl+o` | Transcript |
| 1 | 3 | Key | `ctrl+c` | Interrupt a running turn |
| 2 | 0 | Key | `shift+tab` | Cycle permission mode |
| 2 | 1 | Key | `opt+p` | Model picker |
| 2 | 2 | Key | `opt+t` | Thinking toggle |
| 2 | 3 | Key | `opt+o` | Fast mode |
| 3 | **1 and 2** | Key | `Space` | Voice dictation, held — the fat key |
| 3 | 3 | Key | `Enter` | Submit / proceed |

Every modifier above is spelled the way Input spells it, so what you read here is
what you click. `opt` is the Option key — the button labelled `opt` in Input's
modifier palette. There is no `alt` button; it is the same key under a different
name.

You will see `alt+…` inside `config/keybindings.json`, because that is the
spelling Claude Code's configuration format requires. Same modifier, same
physical key. Nothing you type into Input ever says `alt`.

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
| Dial, counter-clockwise | `Up` | Scroll the transcript, or step back through prompt history |
| Dial, clockwise | `Down` | Scroll forward, or step forward through prompt history |
| Dial, press | `Escape` | Cancel, or decline a permission prompt |
| Joystick, up | `ctrl+Up` | Mission Control |
| Joystick, down | `ctrl+Down` | Show all windows of the front app |
| Joystick, left | `opt+k` | Previous chat |
| Joystick, right | `opt+j` | Next chat |

Rotating is for reading, pointing is for moving. The dial needs no binding at
all — `Up`/`Down` already mean scroll in the transcript and prompt history in the
chat, so one mapping is right in both places, and long output in a terminal
scrolls under your thumb.

**The joystick's vertical axis targets the operating system, not Claude Code.**
It suits running one terminal window per worktree: `ctrl+Up` is Mission Control
and `ctrl+Down` shows every window of the front app, so up and down get you *to*
the right window while left and right move between sessions once you are there.

macOS intercepts both before any application sees them. Claude Code does bind
`ctrl+up` and `ctrl+down` — `messageSelector:top`/`bottom` and
`app:diffFileListUp`/`Down` — but the system shortcuts win whenever Mission
Control is at its defaults, which is every Mac out of the box. So this costs you
nothing that was reachable anyway. It is worth knowing if you ever wonder why
`messageSelector:top` seems unresponsive: that is macOS, not this repo.

In the Claude desktop app there are no terminal windows to move between, so the
vertical axis does nothing there while the horizontal axis still works.

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
it — Command produces a combination iTerm2 intercepts before Claude Code sees it.

## The voice key is different

Row 3's fat key must be a **plain `Space` key assignment, not a macro and not a
Multi Action.** Hold-to-talk is defined by its release: you hold the key, speak,
and release to end. A macro fires and completes; it cannot be held. Assign
`Space` as an ordinary key so the physical hold passes straight through.

Held keys do work on this pad — a modifier such as `KC_LSFT` assigned to a pad
key behaves as a real held modifier, which is the same mechanism voice relies on.

## Steps in Input

1. Open Input with the Creator Micro 2 connected (see
   [Getting the Input app](#getting-the-input-app) if you do not have it).
2. Select the **Default** profile. Add a new layer and name it `Claude Code`.
3. For each **Key** row: click the key in the layout, choose the keyboard shortcut
   assignment on the **Basic** tab, and press the combination with the modifier
   held.
4. For the **Smart Action** row: choose Smart Action, pick the app type, and point
   it at `/Applications/Claude.app`.
5. Row 3's fat key: assign `Space` to both of its slots.
6. Set the encoder's three actions.
7. Sync to the device.
8. Optional: under linked apps, link this layer to iTerm and Claude, so the keys
   only fire where they mean something.

## Verifying

Open Claude Code and press each key once, top to bottom, against the table above.
If a key types a bare character — `å` for `opt+a` — Option reached the terminal
as a compose key rather than a modifier. Set iTerm2's Profiles → Keys → Left
Option key to `Esc+`. If it types nothing at all, Input recorded the key without
its modifier: re-record it with Option held.
