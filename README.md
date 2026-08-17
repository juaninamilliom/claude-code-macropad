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

## It works without a macropad

Every chord here is typeable. `ctrl+x` then `[` is two keystrokes on any
keyboard. The hooks are shell scripts and do not know what a macropad is.
Install the keybindings and the hooks and you have all of it.

What a pad adds is a labeled key you can hit without looking, for actions that
otherwise have no key at all. That is the entire pitch. If that is worth a key
on your desk, the device guides below tell you how to program one.

Two limits, before you spend fifteen minutes on this: **nothing here can light up
your pad's LEDs**, and **no guide here can program your pad for you** — every
device is configured by hand in its own app. Both are explained under
[Limitations](#limitations).

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

Two things to know before you paste the block.

**Re-running it is safe.** Step 0's backups are timestamped, so a second run
never overwrites the first. Step 2's merge is idempotent: it drops any hook entry
already pointing at our script before appending, so you get one `notify-ready.sh`
per event no matter how many times you run it. Hooks you added yourself are left
alone.

**Step 2 is chained.** Its `cp` and its `jq` merge are joined with `&&`, so a
failed `cp` stops the merge and nothing gets registered that was not installed.
That is what the `mkdir -p` above is for. Verify the script landed anyway:

```bash
ls ~/.claude/hooks/notify-ready.sh
```

Running the block from the wrong directory is a safe failure too: the merge
cannot open `config/hooks.snippet.json`, exits non-zero, and leaves your
settings untouched.

One smaller note. `cp hooks/*.sh ~/.claude/hooks/` overwrites any same-named
script already there, and `chmod +x ~/.claude/hooks/*.sh` marks every script in
that directory executable, not only ours.

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

### Voice is not a chord

Voice dictation is plain `Space`, held. It is not a chord and it needs no entry
in `keybindings.json` — `voice:pushToTalk` is already bound to `Space` in the
`Chat` context.

It is off until you turn it on. Run `/voice hold` inside Claude Code, in a
terminal. Until you do, holding `Space` types spaces and nothing indicates why.

On a pad, the voice key must be an ordinary `Space` key assignment — not a
macro, not a chord. Hold-to-talk is defined by the release, and a macro
completes immediately instead of staying held.

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

## Device guides

| Guide | Covers |
| --- | --- |
| [`docs/work-louder-input.md`](docs/work-louder-input.md) | Work Louder Creator Micro 2, key by key, in the Input app |
| [`docs/qmk-via.md`](docs/qmk-via.md) | Any VIA-compatible board, using VIA's macro editor |
| [`docs/stream-deck.md`](docs/stream-deck.md) | Stream Deck and Karabiner-Elements |

The Stream Deck guide explains why the voice key does not work on that device
and what to do instead.

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
