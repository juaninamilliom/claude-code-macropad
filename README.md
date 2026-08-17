# claude-code-macropad

Drive Claude Code from a macropad — or from any keyboard.

## What it is

Claude Code ships several useful actions bound to no key at all: session-strip
navigation, jump-to-the-session-that-wants-attention, new session. This repo
binds five of them to chords, adds desktop notifications that name the project
so you can tell concurrent sessions apart, and documents how to put the result
on a physical key.

| Path | What it is |
| --- | --- |
| `config/keybindings.json` | Complete `~/.claude/keybindings.json`. Five bindings, nothing else. |
| `config/hooks.snippet.json` | Fragment to merge into `~/.claude/settings.json`. |
| `hooks/notify-ready.sh` | macOS notification naming the project, on `Stop` and `Notification`. |
| `docs/` | Per-device setup guides and troubleshooting. |
| `tests/` | `test-keybindings.sh`, `test-notify-ready.sh`, `test-docs-consistency.sh`. |
| `scripts/doctor.sh` | Read-only health check across the whole chain, hardware to config. |

The two config files are shaped differently on purpose. `keybindings.json` is a
complete file you can copy over; `settings.json` holds configuration this repo
must not replace, so the hooks ship as a fragment that gets merged in.

## Which one are you?

Both paths install the same two files. They differ only in what presses the keys.

**A — You have a macropad.** Install below, then program the pad from your
device's guide. You get labeled, eyes-free keys for actions that otherwise have
no key at all. Start here: [with a macropad](#path-a--with-a-macropad).

**B — You do not.** Install below and you are done. Every chord is typeable —
`ctrl+x` then `[` is two keystrokes on any keyboard — and you can also bind them
to spare function keys. See [keyboard only](#path-b--keyboard-only).

Two limits worth knowing before either path: **nothing here can light up a pad's
LEDs**, and **no guide here can program your pad for you** — every device is
configured by hand in its own app. Both are explained under
[Limitations](#limitations).

## Terminal or desktop app?

Claude Code runs in a terminal and as a desktop app. They share `~/.claude/`, so
configuration installed once applies to both. What differs is voice.

| | Terminal | Desktop app |
| --- | --- | --- |
| Keybindings and chords | yes | not yet verified |
| Notification hooks | yes | yes — `settings.json` is shared |
| Turning voice **on** (`/voice hold`) | **yes, only here** | no — the command refuses with *"Run it from the Claude Code terminal instead"* |
| Using voice once enabled | yes | not yet verified |

**Enable voice from a terminal even if you live in the desktop app.** The setting
is written to `settings.json`, which both read. The two "not yet verified" rows
are honest gaps, not hedging — see [what has and has not been
tested](#tested-against).

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
that is in [how the install behaves](#how-the-install-behaves) below; you do not
need it to install.

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

# 1. Keybindings. Overwrites the file — step 0 backed it up.
#    If you already had bindings, merge yours back in from the .bak-* copy.
cp config/keybindings.json ~/.claude/keybindings.json

# 2. Hooks. The merge is idempotent — safe to re-run.
TMP=$(mktemp)
cp hooks/*.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/*.sh && \
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

# 3. Voice (terminal only)
# run inside Claude Code:  /voice hold
```

Then confirm the merge landed. Print the commands rather than the event names —
the names tell you an event exists, not what it runs:

```bash
jq -r '.hooks | to_entries[] | "\(.key): \(.value[].hooks[].command)"' ~/.claude/settings.json
```

After a clean install — no hooks of your own — that is exactly two lines, in
this order. The merge rebuilds `.hooks` with `reduce ($new.hooks | keys[])` and
jq's `keys` sorts, so `Notification` comes first:

```
Notification: $HOME/.claude/hooks/notify-ready.sh
Stop: $HOME/.claude/hooks/notify-ready.sh
```

If you already had hooks you get a line for each of those too, and your existing
event names keep their original position, so that order will not hold — count
the commands rather than matching the listing. If `notify-ready.sh` appears
twice under `Stop`, the merge ran twice — delete the extra entry.

## Path A — with a macropad

Nothing pad-specific gets installed. Your pad sends ordinary keystrokes; the
config above is what makes Claude Code answer them. So the remaining work is
entirely in your device's own app.

| Your device | Guide |
| --- | --- |
| Work Louder Creator Micro 2 | [`docs/work-louder-input.md`](docs/work-louder-input.md) — key by key, in the Input app |
| Any VIA-compatible board | [`docs/qmk-via.md`](docs/qmk-via.md) — VIA's macro editor |
| Stream Deck, Karabiner | [`docs/stream-deck.md`](docs/stream-deck.md) |

Budget about fifteen minutes of clicking. Each guide gives you a table of what
every key sends, and the three assignment types that matter: a plain **Key** for
things like `Space`, a **Multi Action** for the two-keystroke chords, and a
**Smart Action** if your app has one, for launching Claude.

The layout is built so the whole loop works without touching the keyboard: hold
the big key to dictate, release, press the key beside it to send. Escape declines
a permission prompt, `ctrl+c` stops a runaway turn, and the dial cycles sessions.

## Path B — keyboard only

You are already done. The five chords work as typed keystrokes — `ctrl+x`,
release, then the second key. See [Chords](#chords) for what they do.

If you would rather have single keys, map spare function keys to the chords with
Karabiner-Elements. [`docs/stream-deck.md`](docs/stream-deck.md) has a working
manipulator for exactly that, including where it nests in `karabiner.json`.

Voice needs no binding at all: hold `Space` with the input empty, after running
`/voice hold` once in a terminal.

## How the install behaves

Skip this unless something looks wrong or you want to understand the commands.

**Re-running is safe.** Step 0's backups are timestamped with a collision loop,
so a second run never overwrites the first — three runs in the same second
produce three distinct backups. Step 2's merge drops any hook entry already
pointing at our script before appending, so you get one `notify-ready.sh` per
event however many times you run it. Hooks you added yourself are left alone.

**Step 2 is chained.** Its `cp` and its `jq` merge are joined with `&&`, so a
failed `cp` stops the merge and nothing gets registered that was not installed.
That is what the `mkdir -p` is for. Verify the script landed anyway:

```bash
ls ~/.claude/hooks/notify-ready.sh
```

Running the block from the wrong directory is a safe failure too: the merge
cannot open `config/hooks.snippet.json`, exits non-zero, and leaves your settings
untouched.

One smaller note: `cp hooks/*.sh ~/.claude/hooks/` overwrites any same-named
script already there, and `chmod +x ~/.claude/hooks/*.sh` marks every script in
that directory executable, not only ours.

### Why step 2 is not the obvious one-liner

The natural version of that merge is `jq -s '.[0] * .[1]'`, and it is wrong
here. jq's `*` operator recurses into objects but **replaces** arrays outright.
`.hooks.Stop` is an array. So the short command silently discards any `Stop` or
`Notification` hook you already had — no error, no warning, and its output is
still perfectly valid JSON, so every structural check you would think to run
still passes. That is also why step 2's guard is `[ -s … ]` plus
`jq -e '.hooks'` rather than plain `jq empty`: `jq empty` exits 0 on a zero-byte
file, so on its own it does not distinguish a good merge from no merge at all.

The command above concatenates the per-event arrays instead: your existing
entries stay, ours are appended after them. Verified against a settings file
carrying a pre-existing `Stop` hook plus an unrelated `PreToolUse` hook — both
survived the merge, ours was appended, and `permissions` was untouched. Under
the one-liner, the pre-existing `Stop` hook was gone.

If you are tempted to simplify that command, this is the reason not to.

## Chords

A chord is two keystrokes **in sequence**, not a combination held at once:
press `ctrl+x`, release, then press the second key.

| Chord | Action | Context | Does |
| --- | --- | --- | --- |
| `ctrl+x` then `a` | `chat:attentionDown` | Chat | Jump to session needing you |
| `ctrl+x` then `[` | `strip:previous` | Global | Previous chat |
| `ctrl+x` then `]` | `strip:next` | Global | Next chat |
| `ctrl+x` then `n` | `strip:new` | Global | New chat |
| `ctrl+x` then `s` | `strip:toggle` | Global | Toggle chat strip |

That is the whole of `config/keybindings.json`. `tests/test-keybindings.sh`
checks the file against snapshots of contexts and actions that this repo
maintains by hand, because a typo in either produces a binding that fails
silently. The context snapshot is complete — all 20. The action snapshot is
not: it is 21 of the 137 actions in 2.1.233, covering what this repo binds plus
near neighbours, and it does not include `strip:jump6`–`strip:jump9`. If you add
a legitimate binding the check calls unknown, extend `VALID_ACTIONS` in the
script. Neither snapshot is read from Claude Code, so this catches your typos
but not an upstream rename.

If you have rebound tmux's or screen's prefix to `ctrl+x`, change the prefix in
`config/keybindings.json` and in your device configuration. The two must match.

### Voice gets a pad key too

Dictation belongs on the pad like everything else — ideally the biggest key you
have, since you hold it while you talk. It is simply the one key that is **not** a
chord: assign it plain `Space`.

That is a mechanical requirement, not a shortcut. Hold-to-talk is defined by the
*release*: you hold, speak, and let go to end the utterance. A macro or a Multi
Action fires and completes instantly, so it can never be held. A plain `Space`
key assignment passes your physical hold straight through. Nothing goes in
`keybindings.json` — `voice:pushToTalk` is already bound to `Space` in the `Chat`
context.

**Turn it on first.** Run `/voice hold` inside Claude Code, in a terminal. Until
you do, holding the key types spaces and nothing tells you why.

One device limitation: a Stream Deck cannot do this. It sends discrete
press-and-release events and cannot hold a key for as long as you hold the
button. Use `/voice tap` there instead —
[`docs/stream-deck.md`](docs/stream-deck.md) covers it.

## Pass-through keys

Claude Code binds these itself. Nothing in this repo configures them, and
nothing needs to: a pad key that sends the combination works as-is.

| Key | Does |
| --- | --- |
| `shift+tab` | Cycle permission mode |
| `opt+p` | Model picker |
| `opt+t` | Thinking toggle |
| `opt+o` | Fast mode |
| `ctrl+o` | Transcript |
| `ctrl+t` | Todo list |
| `ctrl+g` | External editor |

`opt` is the Option key. Claude Code spells these three `alt+…` internally,
which on macOS is the same modifier; they are **not** Command. Sending `cmd+…`
instead does not simply fail — in iTerm2, `cmd+t` opens a tab and `cmd+o` opens
a file dialog.

## Limitations

### No LED feedback is possible

The pad's LEDs cannot react to Claude Code. There is no host-to-device channel:
the configuration software is closed and exposes no documented API, so a `Stop`
hook has no way to light a key when a turn finishes.

Feedback happens on the macOS side instead: a desktop notification naming the
project that wants you. If what you wanted was a key that glows when a session is
waiting on you, this repo cannot give you that, and no amount of configuration
will.

### The keymap cannot be scripted

You program the pad by hand, in the vendor's GUI. On the Work Louder Creator
Micro 2, the Input app stores a sha1 checksum for `keymap.json`, so editing that
file directly desynchronizes it, and the layer still has to be synced to the
device by the app. There is no supported import path, so this repo ships no
device profile to import.

Budget about fifteen minutes of clicking. The device guides are written as
checklists to keep it short and unambiguous.

## Tested against

Claude Code **2.1.233**, on macOS.

Be precise about what that covers, because no key on this page has been pressed
on a macropad. Verified from software: `config/keybindings.json` validates, the
step 2 merge preserves pre-existing hooks, the hook fires and names the project,
and every context, action, and pass-through chord named here exists in the
2.1.233 binary with the modifier shown. Still unverified, because it needs
hardware: the five chords arriving from a physical pad, and whether `strip:*`
genuinely binds in `Global` rather than only where the chat input has focus. If
you own a pad and find out, an issue would be welcome.

The notification hook is macOS-only: it shells out to `osascript`. The
keybindings themselves have no platform dependency.

`strip:*` and `chat:attention*` have no default bindings. If a chord stops
firing after a Claude Code update, validate your installed file first — not the
repo's copy, which always passes in a clean clone:

```bash
bash tests/test-keybindings.sh ~/.claude/keybindings.json
```

To see what the keybinding loader itself did, start Claude Code **interactively**
with a debug log, then read the log after you quit:

```bash
claude --debug-file /tmp/cc-debug.log
grep -i keybindings /tmp/cc-debug.log
```

That is where to look; it is not a check this repo has run end to end. The
interactive session matters. Piping `claude --debug` into `grep` does not work —
the pipe puts Claude Code into `--print` mode, which exits with
`Input must be provided either through stdin or as a prompt argument`, and `grep`
swallows that error and prints nothing. Empty output there means the command was
wrong, not that your bindings are fine. Adding `-p` does not help either: a
headless run produces a debug log with no keybinding lines in it at all.

## Troubleshooting

Start here:

```bash
bash scripts/doctor.sh
```

It checks the whole chain — pad on the HID bus, keybindings installed and valid,
hooks wired, each hook script actually present and executable, voice enabled —
and names the next action for whatever is broken. Read-only; it changes nothing.
Exit code is non-zero if anything failed, so it also works in a shell alias.

The one distinction it draws that saves the most time: if the pad is missing from
the HID bus, the fault is a cable, a port, or a hub — not configuration. A hub
chain that re-enumerates when you undock is the usual cause. Plug the pad
directly into the computer with a data cable.

[`docs/troubleshooting.md`](docs/troubleshooting.md) covers the rest — the
failures that actually came up building this: holding `Space` types spaces,
`/voice` missing entirely, a chord that types raw characters instead of acting,
hooks that never fire, and notifications that do not say which project they came
from.

## Tests

```bash
bash tests/test-keybindings.sh
bash tests/test-notify-ready.sh
bash tests/test-docs-consistency.sh
```

They validate, in order: that every binding in `config/keybindings.json` uses a
context and an action from the repo's snapshot lists; that the notification hook
names the project from the hook payload and exits 0; and that the chord and
pass-through tables in this README and in all three device guides still agree,
key and meaning, with `config/keybindings.json`.

`test-keybindings.sh` takes an optional path, so it can check your installed
file too:

```bash
bash tests/test-keybindings.sh ~/.claude/keybindings.json
```

All three are read-only outside the repo. `test-notify-ready.sh` drives the hook
through `CLAUDE_MACROPAD_DRY_RUN=1`, so it sends no notifications.

## License

MIT. See [LICENSE](LICENSE).
