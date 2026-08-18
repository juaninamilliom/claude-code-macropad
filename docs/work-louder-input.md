# Work Louder Creator Micro 2

The Creator Micro 2 has **12 physical keys across 13 matrix slots**, one encoder,
and a radial joystick. The matrix is 2 / 4 / 4 / 3, but the bottom-left key is
double-width and occupies **both** of row 3's first two slots. Twelve keys, not
thirteen — a distinction that matters when you are assigning them.

Input numbers layers from 1 in its interface, while the stored configuration
counts from 0. "Layer 1" in the app is layer id 0 on disk.

## Before you start

**Set your terminal's Option key to send `Esc+`.** In iTerm2 that is Profiles →
Keys → General → Left Option key → `Esc+`. Nothing on the bottom two rows of this
layout works without it, and the failure is silent: on the default `Normal`
setting, macOS composes Option-P into `π` and Claude Code receives a character
rather than a shortcut.

Claude Code compensates for exactly three of these by hand — it carries a
lookup mapping `π`, `ø` and `†` back to `opt+p`, `opt+o` and `opt+t` — which is
worth knowing because it makes the symptom confusing. Those three shortcuts work
on the default setting and every other Option key silently does not. Change the
setting; do not conclude from `opt+p` working that Option is fine.

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
| 0 | 1 | Smart Action | Launch `JumpToAttention.app` | Go to the session waiting on you |
| 0 | 2 | Smart Action | Launch `NextSession.app` | Switch chat — next session |
| 1 | 0 | Smart Action | Launch `NewSession.app` | New chat, in a new window |
| 1 | 1 | Key | `ctrl+o` | Transcript |
| 1 | 2 | Key | `shift+tab` | Cycle permission mode |
| 1 | 3 | Key | `ctrl+c` | Interrupt |
| 2 | 0 | Key | `opt+p` | Model picker |
| 2 | 1 | Key | `ctrl+t` | Todo list |
| 2 | 2 | Key | `ctrl+r` | Search prompt history |
| 2 | 3 | Key | `ctrl+b` | Background the task |
| 3 | **1 and 2** | Key | `Space` | Voice dictation, held — the fat key |
| 3 | 3 | Key | `Enter` | Submit |

**Three of the twelve are Smart Actions, not keystrokes.** New chat, switch
chat, and jump-to-attention are the three things Claude Code cannot do — every
action that named them (`strip:new`, `strip:next`, `strip:previous`,
`strip:toggle`, `chat:attentionUp`, `chat:attentionDown`) is declared without an
implementation. They are windows this repo opens and focuses, so they are apps
you launch rather than keys you send. [Building them](#the-session-keys) is
three one-line commands.

**Every keystroke above is one Claude Code already binds itself.** Nothing on
this pad depends on `config/keybindings.json`, which is why the layout is worth
trusting: there is no configuration between your keypress and the action.

`opt` is the Option key — the button labelled `opt` in Input's modifier palette.
There is no `alt` button; it is the same key under a different name. Claude Code
spells that modifier `alt` in `keybindings.json` and `meta` in its internal
defaults. Three names, one physical key, and only `opt` is one you ever click.

The bottom row is the core loop: hold the fat key and talk, release, press
`Enter` beside it. Dictate and send, two adjacent keys.

**Assign `Space` to both (3,1) and (3,2).** The double-width key reports through
one of the two and the stored keymap does not reveal which. Setting both is
harmless and guarantees it works either way.

### The session keys

Three keys — jump, switch, new — are the ones that made this repo necessary.
Claude Code names all three and implements none of them, so each is a small
script driving iTerm2, wrapped in an app because Smart Actions launch
applications and cannot run a script directly.

Build all three with `osacompile`, which ships with macOS:

```bash
for spec in "JumpToAttention:" "NextSession:--next" "NewSession:--new"; do
  osacompile -o ~/Applications/"${spec%%:*}".app \
    -e "do shell script \"\$HOME/.claude/hooks/jump-to-attention.sh ${spec##*:}\""
done
```

Then point three **Smart Actions** at them, exactly as you would for launching
any other app.

| App | Does | When there is nowhere to go |
| --- | --- | --- |
| `JumpToAttention` | Focuses the session waiting longest | Falls back to the next session |
| `NextSession` | Next session, in order, always | Plays a sound |
| `NewSession` | New window running `claude` | — |

**Jump and switch are different keys on purpose.** Jump prioritises by wait
time and has to go quiet when nothing is waiting; switch has to move on every
press or it is not a switch key. One key cannot do both without compromising
one of them.

`NewSession` starts in the same directory as the session you pressed it from,
so one window per worktree stays one window per worktree.

**The first press will not move anything.** macOS asks permission the first time
the app tries to control iTerm2, and the script sits waiting until you answer.
Approve it, then press again. If you missed the prompt it is in System Settings →
Privacy & Security → Automation, under `JumpToAttention`.

**A press with nothing waiting plays a short sound and does nothing else.** That
is the design — but it is worth knowing, because the first time you test this
there will usually be nothing waiting, and a key that does nothing looks exactly
like a key that is not wired up. Same for pressing it *in* the session that is
waiting: there is nowhere to go, so you get the sound. The marker is cleared
either way.

To be sure the key works, you need **two** sessions: start Claude Code in a
second window, give it a long task, come back to the first, and press when the
notification arrives.

The queue empties as you work: arriving at a session clears it, typing into one
clears it, and pressing the key while you are already in a waiting session
clears that one and moves you to the next. To see the queue without moving:

```bash
~/.claude/hooks/jump-to-attention.sh --list
```

If that prints `nothing waiting`, the key has nothing to do and the fault is not
in your pad.

This needs iTerm2. It finds windows through iTerm2's scripting interface, and
there is no equivalent path for Terminal.app in this repo — the marker is still
written, and the jump reports that it cannot use it.

### The dial and the joystick

Both are configured separately from the keys — they are not rows in the keymap,
so they get their own sections in Input.

| Input | Assignment | Why |
| --- | --- | --- |
| Dial, counter-clockwise | `Up` | Previous option, previous prompt, scroll back a line |
| Dial, clockwise | `Down` | Next option, next prompt, scroll forward a line |
| Dial, press | `Escape` | Cancel, or decline a permission prompt |
| Joystick, up | `PageUp` | Scroll back a page |
| Joystick, down | `PageDown` | Scroll forward a page |
| Joystick, left | `Left` | Move the cursor, or move within a dialog |
| Joystick, right | `Right` | Move the cursor, or move within a dialog |

**Put `Up`/`Down` on the dial, not `PageUp`/`PageDown`.** They are not two
speeds of the same thing, and the difference is the single easiest mistake to
make here:

| Sends | In the chat input | In an option list | In the transcript |
| --- | --- | --- | --- |
| `Up` / `Down` | prompt history | **moves the selection** | scrolls a line |
| `PageUp` / `PageDown` | nothing | **nothing** | scrolls a page |

Claude Code binds `up` and `down` in every context that has a list —
`confirm:previous`/`next` for permission prompts, `select:previous`/`next` for
the model picker and settings, `autocomplete:previous`/`next` for the command
menu. It binds `pageup` and `pagedown` only in its scrolling contexts. So a dial
set to `PageUp` scrolls output perfectly well and can never choose an option,
which is a confusing thing to debug: the dial obviously works, and yet the one
moment you need it — a permission prompt with three choices — it does nothing.

Rotating is therefore for choosing, and pointing is for reading. Putting the
page keys on the joystick's vertical axis gets you both without giving anything
up.

Arrow keys matter more than they look: permission prompts, the model picker, and
every select list are driven by arrows, so without them a pad-only workflow
stalls at the first dialog.

**This costs Mission Control**, which is the other reasonable use for the
joystick's vertical axis: `ctrl+Up` and `ctrl+Down` show all windows and all
windows of the front app, and macOS intercepts both before any application sees
them. That was worth a key back when moving between session windows meant
finding them by eye. The jump key does that job now, without looking, so the
page keys are the better tenant. If you would rather have Mission Control, swap
them back — just leave `Up`/`Down` on the dial.

The joystick is radial, defined by angle ranges rather than named directions.
Assign the four directional sectors to the arrows that match what Input shows for
each direction. If your device already has a narrow sector set to `KI_X`, leave
it — it appears in untouched layers too and is not something you set.

### Shortcuts deliberately left off the pad

Twelve keys does not cover everything. These stay on the keyboard, being single
keystrokes you rarely want mid-flow:

| Key | Does |
| --- | --- |
| `opt+t` | Thinking toggle |
| `opt+o` | Fast mode |
| `ctrl+g` | External editor |
| `ctrl+s` | Stash the prompt |
| `ctrl+shift+b` | Toggle the brief |
| `opt+k` | Kill running agents |
| `opt+z` | Undo |

Thinking and fast mode are settings you change now and then rather than every
turn, which is what lost them their keys to the three session actions. They
still work from the keyboard.

The last two are the only entries in this repo's `config/keybindings.json`.
Claude Code binds those actions to `ctrl+x ctrl+k` and `ctrl+_` — a two-key chord
and an awkward combination — and a chord is precisely what Input cannot send. If
you want either on a pad key, install that config and assign `opt+k` or `opt+z`
like any other combination.

## The voice key is different

Row 3's fat key must be a **plain `Space` key assignment, not a macro and not a
Multi Action.** Hold-to-talk is defined by its release: you hold the key, speak,
and release to end. A macro fires and completes; it cannot be held. Assign
`Space` as an ordinary key so the physical hold passes straight through.

Held keys do work on this pad — a modifier such as `KC_LSFT` assigned to a pad
key behaves as a real held modifier, which is the same mechanism voice relies on.

`Space` needs no configuration on the Claude Code side either: `voice:pushToTalk`
is bound to it by default in the `Chat` context. You do have to switch voice on
once, with `/voice hold` in a terminal.

## Steps in Input

1. Open Input with the Creator Micro 2 connected (see
   [Getting the Input app](#getting-the-input-app) if you do not have it).
2. Select the **Default** profile. Add a new layer and name it `Claude Code`.
3. For each **Key** row: click the key in the layout, choose the keyboard shortcut
   assignment on the **Basic** tab, and press the combination with the modifier
   held.
4. Build `JumpToAttention.app` with the `osacompile` command above, then set row
   0, column 1 to a Smart Action pointing at it.
5. Row 3's fat key: assign `Space` to both of its slots.
6. Set the encoder's three actions and the joystick's four sectors.
7. Sync to the device.
8. Optional: under linked apps, link this layer to iTerm, so the keys only fire
   where they mean something.

## Verifying

Open Claude Code in a terminal and press each key once, top to bottom, against
the table above.

If a key types a bare character — `®` for `opt+r`, `π` for `opt+p` — Option
reached the terminal as a compose key rather than a modifier, and the `Esc+`
setting at the top of this page is not applied. If it types nothing at all, Input
recorded the key without its modifier: re-record it with Option held.

**Test the jump key with two sessions.** Start Claude Code in two windows, give
one a long task, switch to the other, and press the key when the notification
arrives. One session waiting is not much of a test of a queue.

**None of this works in the Claude desktop app.** The keystrokes above are
terminal shortcuts, and the desktop app does not act on them. Use a terminal.
