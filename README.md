# claude-code-macropad

Drive Claude Code from a macropad — or from any keyboard.

## What it is

A twelve-key layout for Claude Code, a notification hook that tells you which
project wants you, and **one key that takes you to the session that has been
waiting longest**.

That last one is the point. If you run several sessions at once, the expensive
part is not typing — it is noticing that one of them finished and finding its
window. This repo makes that a keypress.

| Path | What it is |
| --- | --- |
| `hooks/notify-ready.sh` | macOS notification naming the project, and a record of which window it came from |
| `hooks/clear-attention.sh` | Drops a session from the queue once you type in it |
| `hooks/lib-attention.sh` | Shared by the hooks and the jump script |
| `scripts/jump-to-attention.sh` | Focuses the longest-waiting session |
| `config/hooks.snippet.json` | Fragment to merge into `~/.claude/settings.json` |
| `config/keybindings.json` | Optional. Two shortcuts for actions Claude Code binds only to chords |
| `docs/` | Per-device setup guides and troubleshooting |
| `tests/`, `scripts/doctor.sh` | Test suite and a read-only health check |

The two config files are shaped differently on purpose. `keybindings.json` is a
complete file you can copy over; `settings.json` holds configuration this repo
must not replace, so the hooks ship as a fragment that gets merged in.

## Which one are you?

**A — You have a macropad.** Install below, then program the pad from your
device's guide. Start with [the layout](#the-layout).

**B — You do not.** The hooks and the jump script still work; bind the script to
a hotkey with Karabiner. See [`docs/stream-deck.md`](docs/stream-deck.md#running-the-jump-script-from-a-key).
Every key in the layout is one Claude Code already binds, so there is nothing to
install for those — they work on your keyboard today.

Two limits worth knowing before either path: **nothing here can light up a pad's
LEDs**, and **no guide here can program your pad for you**. Both are explained
under [Limitations](#limitations).

## Terminal only

| | Terminal | Desktop app |
| --- | --- | --- |
| The layout's keystrokes | yes | **no** |
| Jump to the waiting session | yes, iTerm2 | no |
| Notification hooks | yes | yes — `settings.json` is shared |
| Turning voice on (`/voice hold`) | yes | no — the command refuses |

**The Claude desktop app does not act on these keystrokes.** This was tested, not
assumed. Use a terminal. The notification hooks still fire for desktop sessions
because both read the same `settings.json`, but nothing else here applies.

The jump script needs **iTerm2** specifically: it locates windows through
iTerm2's scripting interface. Terminal.app has no equivalent path in this repo.

## Set Option to `Esc+` first

In iTerm2: Profiles → Keys → General → **Left Option key** → `Esc+`.

Do this before anything else. On the default `Normal` setting macOS composes
Option-P into `π`, and Claude Code receives a character rather than a shortcut —
silently, with no error anywhere.

What makes this genuinely confusing is that Claude Code hard-codes a fallback for
exactly three characters, mapping `π`, `ø` and `†` back to `opt+p`, `opt+o` and
`opt+t`. So those three shortcuts work on the wrong setting and every other
Option key does not. **Do not conclude from `opt+p` working that Option is fine.**

## Quickstart

Steps 1 and 2 use paths relative to the repo root, so start from a clone:

```bash
git clone https://github.com/juaninamilliom/claude-code-macropad.git
cd claude-code-macropad
```

You also need `jq`, an existing `~/.claude/settings.json` (Claude Code writes one
on first run), and an existing hooks directory:

```bash
mkdir -p ~/.claude/hooks
```

Paste the whole block. It is safe to re-run — backups are timestamped and the
hook merge is idempotent. If you want to know why it is shaped the way it is,
that is in [how the install behaves](#how-the-install-behaves) below.

```bash
# 0. Back up both files this installs over. Not optional.
#    Never overwrites an existing backup, even two runs in the same second.
#    Skips whichever file you do not have yet.
TS=$(date +%Y%m%d-%H%M%S)
for f in ~/.claude/settings.json ~/.claude/keybindings.json; do
  [ -e "$f" ] || continue
  b="$f.bak-$TS"; i=1
  while [ -e "$b" ]; do b="$f.bak-$TS-$i"; i=$((i + 1)); done
  cp "$f" "$b"
done

# 1. Hooks and the jump script. They live in one directory because
#    jump-to-attention.sh shares lib-attention.sh with the hooks.
cp hooks/*.sh scripts/jump-to-attention.sh ~/.claude/hooks/ && \
chmod +x ~/.claude/hooks/*.sh

# 2. Register the hooks. The merge is idempotent — safe to re-run.
TMP=$(mktemp)
jq -s '.[0] as $cur | .[1] as $new
  | $cur * $new
  | .hooks = (reduce ($new.hooks | keys[]) as $k (($cur.hooks // {});
      ($new.hooks[$k] | [.[].hooks[].command]) as $ours
      | .[$k] = ([(($cur.hooks[$k] // [])[])
                  | select(([.hooks[].command] - $ours) != [])]
                 + $new.hooks[$k])))' \
  ~/.claude/settings.json config/hooks.snippet.json \
  > "$TMP" && [ -s "$TMP" ] && jq -e '.hooks' "$TMP" >/dev/null \
  && mv "$TMP" ~/.claude/settings.json

# 3. Optional: the two off-pad shortcuts. Overwrites the file — step 0 backed
#    it up. If you already had bindings, merge yours back from the .bak-* copy.
cp config/keybindings.json ~/.claude/keybindings.json

# 4. Voice, and the jump app
# run inside Claude Code:  /voice hold
osacompile -o ~/Applications/JumpToAttention.app \
  -e 'do shell script "$HOME/.claude/hooks/jump-to-attention.sh"'
```

Then confirm the merge landed. Print the commands rather than the event names —
the names tell you an event exists, not what it runs:

```bash
jq -r '.hooks | to_entries[] | "\(.key): \(.value[].hooks[].command)"' ~/.claude/settings.json
```

After a clean install — no hooks of your own — that is exactly three lines, in
this order. The merge rebuilds `.hooks` with `reduce ($new.hooks | keys[])` and
jq's `keys` sorts:

```
Notification: $HOME/.claude/hooks/notify-ready.sh
Stop: $HOME/.claude/hooks/notify-ready.sh
UserPromptSubmit: $HOME/.claude/hooks/clear-attention.sh
```

If you already had hooks you get a line for each of those too, and your existing
event names keep their original position, so that order will not hold — count
the commands rather than matching the listing.

## The layout

Twelve keys. Every one sends a keystroke Claude Code binds itself, so the layout
depends on no configuration at all.

| Key | Does |
| --- | --- |
| `ctrl+r` | Search prompt history |
| `ctrl+t` | Todo list |
| `ctrl+o` | Transcript |
| `shift+tab` | Cycle permission mode |
| `ctrl+c` | Interrupt |
| `opt+p` | Model picker |
| `opt+t` | Thinking toggle |
| `opt+o` | Fast mode |
| `ctrl+b` | Background the task |
| `Space` | Voice dictation, held |
| `Enter` | Submit |

The twelfth key is the jump key, which is not a keystroke — see below.

`opt` is the Option key, which is what device configurators label the button.
Claude Code spells the same modifier `alt` in `keybindings.json` and `meta` in
its internal defaults. Three names, one physical key; `opt` is the only one you
ever click.

Per-device instructions:

| Your device | Guide |
| --- | --- |
| Work Louder Creator Micro 2 | [`docs/work-louder-input.md`](docs/work-louder-input.md) |
| Any VIA-compatible board | [`docs/qmk-via.md`](docs/qmk-via.md) |
| Stream Deck, Karabiner | [`docs/stream-deck.md`](docs/stream-deck.md) |

### The jump key

`hooks/notify-ready.sh` fires whenever a session finishes a turn or asks for
input. Besides the notification, it writes down which terminal window that
session is in. `scripts/jump-to-attention.sh` reads those records oldest-first,
focuses that window, and clears it — so pressing the key repeatedly walks you
through everything waiting, longest-waiting first, and stops when the queue is
empty. Typing into a session also clears it, so sessions you reach by hand do not
pile up.

On a pad with an app-launcher action, point it at the `JumpToAttention.app` built
in step 4. Otherwise bind the script to a hotkey with Karabiner —
[`docs/stream-deck.md`](docs/stream-deck.md#running-the-jump-script-from-a-key).

To see the queue without moving:

```bash
~/.claude/hooks/jump-to-attention.sh --list
```

### Voice

Hold `Space` with the input empty. Nothing goes in `keybindings.json` —
`voice:pushToTalk` is bound to `Space` by default in the `Chat` context. **Turn
it on first** with `/voice hold` inside Claude Code, in a terminal. Until you do,
holding the key types spaces and nothing tells you why.

A Stream Deck cannot do this: it sends discrete press-and-release events and
cannot hold a key. Use `/voice tap` there instead.

### Off the pad

`config/keybindings.json` is optional and holds two bindings:

| Key | Does |
| --- | --- |
| `opt+k` | Kill running agents |
| `opt+z` | Undo |

Claude Code binds those actions to `ctrl+x ctrl+k` and `ctrl+_`. The first is a
two-key chord, and **no macropad configurator in these guides can send a chord** —
Work Louder's Multi tab builds tap/double-tap/hold behaviours and its Actions tab
records a simultaneous combination, neither of which is a sequence. Giving those
actions a single keystroke is the entire remaining job of that file.

## What this repo does not do

**It cannot switch Claude Code sessions from inside Claude Code.** That is not a
design choice.

Claude Code 2.1.233 declares 137 keybinding actions. Eighteen of them have no
implementation behind the name:

```
strip:jump1 … strip:jump9   chat:attentionUp        permission:toggleDebug
strip:next  strip:previous  chat:attentionDown      selection:clear
strip:toggle strip:new      chat:cycleProactivity
```

Thirteen of those are session-strip navigation and two more are
jump-to-the-session-that-wants-you — exactly the feature this repo wanted. They
validate, they load, they match your keypress, and then nothing happens. No
error, at any layer. Claude Code's own documentation generator filters `strip:*`
and `chat:attention*` out of its shortcut table, which is corroboration that they
are not meant to work yet.

Earlier versions of this repo bound five keys to those names and shipped them.
The jump key exists because that had to be rebuilt outside Claude Code entirely.

`tests/test-keybindings.sh` now fails on any of the eighteen. If you extend
`config/keybindings.json`, run it.

## How the install behaves

Skip this unless something looks wrong.

**Re-running is safe.** Step 0's backups are timestamped with a collision loop,
so a second run never overwrites the first. Step 2's merge drops any hook entry
already pointing at our scripts before appending, so you get one entry per event
however many times you run it. Hooks you added yourself are left alone.

**Step 1 is chained.** Its `cp` and `chmod` are joined with `&&`, and step 2 will
fail cleanly if run from the wrong directory — the merge cannot open
`config/hooks.snippet.json`, exits non-zero, and leaves your settings untouched.
Verify the scripts landed:

```bash
ls ~/.claude/hooks/
```

One smaller note: `cp hooks/*.sh …` overwrites any same-named script already
there, and `chmod +x ~/.claude/hooks/*.sh` marks every script in that directory
executable, not only ours.

### Why step 2 is not the obvious one-liner

The natural version of that merge is `jq -s '.[0] * .[1]'`, and it is wrong
here. jq's `*` operator recurses into objects but **replaces** arrays outright.
`.hooks.Stop` is an array. So the short command silently discards any `Stop`,
`Notification` or `UserPromptSubmit` hook you already had — no error, no warning,
and its output is still valid JSON, so every structural check you would think to
run still passes. That is also why step 2's guard is `[ -s … ]` plus
`jq -e '.hooks'` rather than plain `jq empty`: `jq empty` exits 0 on a zero-byte
file, so on its own it does not distinguish a good merge from no merge at all.

The command above concatenates the per-event arrays instead. Verified against a
settings file carrying a pre-existing `Stop` hook plus an unrelated `PreToolUse`
hook — both survived, ours was appended, and `permissions` was untouched. Under
the one-liner, the pre-existing `Stop` hook was gone.

## Limitations

### No LED feedback is possible

The pad's LEDs cannot react to Claude Code. There is no host-to-device channel:
the configuration software is closed and exposes no documented API, so a `Stop`
hook has no way to light a key when a turn finishes. Feedback happens on the
macOS side instead — a notification, and the jump key.

### The keymap cannot be scripted

You program the pad by hand, in the vendor's GUI. On the Work Louder Creator
Micro 2, the Input app stores a sha1 checksum for `keymap.json`, so editing that
file directly desynchronizes it, and the layer still has to be synced to the
device by the app. There is no supported import path, so this repo ships no
device profile to import. Budget about fifteen minutes of clicking.

## Tested against

Claude Code **2.1.233**, on macOS, in iTerm2.

Verified by running it: the layout's keystrokes reach Claude Code once Option is
set to `Esc+`; a custom `keybindings.json` binding does fire, confirmed by
rebinding the model picker to a new key and watching it open; the attention
markers are written, cleared, ordered oldest-first, and survive stale and corrupt
entries; iTerm2 focuses a session by the id the hook records; an `osacompile` app
runs the jump script; the step 2 merge preserves pre-existing hooks.

Verified by reading the 2.1.233 binary: the eighteen unimplemented actions; the
`π`/`ø`/`†` fallback map; that no `alt+` default exists to collide with `opt+k`
or `opt+z`; that Claude Code's terminal parser decodes only `home`, `end`,
`pageup` and `pagedown` among the escape-sequence keys — **function keys are not
readable from a terminal at all**, so do not put one in a binding.

Not verified: the keystrokes arriving from a physical Creator Micro 2 rather than
a keyboard, and any terminal other than iTerm2. The notification hook and the
jump script are macOS-only; they shell out to `osascript`.

## Troubleshooting

Start here:

```bash
bash scripts/doctor.sh
```

It checks the whole chain — pad on the HID bus, hooks wired and executable, the
jump script installed, voice enabled — and names the next action for whatever is
broken. Read-only.

The one distinction it draws that saves the most time: if the pad is missing from
the HID bus, the fault is a cable, a port, or a hub — not configuration.

[`docs/troubleshooting.md`](docs/troubleshooting.md) covers the rest.

## Tests

```bash
bash tests/test-keybindings.sh
bash tests/test-notify-ready.sh
bash tests/test-attention.sh
bash tests/test-docs-consistency.sh
```

They check, in order: that every binding uses a known context, a known action,
and **no action from the unimplemented eighteen**; that the notification hook
names the project from the hook payload; that markers are written, replaced,
cleared, ordered, and recovered from corruption; and that the layout tables in
this README and all three device guides still agree, key and meaning.

`test-keybindings.sh` takes an optional path, so it can check your installed file
too:

```bash
bash tests/test-keybindings.sh ~/.claude/keybindings.json
```

All four are read-only outside the repo: they redirect state into a temp
directory and send no notifications.

## License

MIT. See [LICENSE](LICENSE).
