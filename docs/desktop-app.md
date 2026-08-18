# The Claude desktop app

**This repo is a terminal tool.** Almost nothing in it reaches the Claude
desktop app, and the parts that cannot are structural rather than unfinished.

This page records what was measured, so nobody has to rediscover it. Everything
below was read out of `/Applications/Claude.app` and its live Accessibility
tree, not inferred.

## What does not work, and why

| | Reason |
| --- | --- |
| All nine layout keystrokes | `Claude.app`'s `app.asar` contains **zero** references to `keybindings.json`. The app never reads it, and has no menu equivalents for transcript, todos, model picker, permission mode, interrupt, or history search. |
| Voice on the fat key | `voice:pushToTalk` is a Claude Code binding on `Space`. The desktop app does not read it, and its microphone is a button with no keyboard shortcut. A pad key cannot hold a mouse button at a screen position. |
| Jump to attention | `Claude.app` has no AppleScript dictionary — no `.sdef`, `NSAppleScriptEnabled` undeclared — so a specific conversation cannot be addressed from outside. It is also a **single window** whose conversations are tabs, so there is nothing per-conversation to focus. The best any script could do is bring the app forward, which `cmd+tab` already does. |
| Hooks | Unconfirmed. No attention marker was observed from a desktop session, but that test was never completed. Treat as unknown rather than as working. |

Voice is the one worth spelling out, because it looks like a bug and is not: in
a terminal you hold `Space`, and in the desktop app you must hold the on-screen
microphone. Those are different mechanisms, not one mechanism failing.

## What does work

The desktop app exposes real menu shortcuts, and a macropad can send those. Two
of them are the actions people most want:

| Action | Key |
| --- | --- |
| New conversation | `cmd+N` |
| Previous tab | `cmd+opt+Left` |
| Next tab | `cmd+opt+Right` |
| Find / next / previous | `cmd+F` / `cmd+G` / `cmd+shift+G` |
| Reload | `cmd+R` |
| Close tab / close all | `cmd+W` / `cmd+opt+W` |
| Settings | `cmd+,` |
| Full screen | `cmd+ctrl+F` |
| Zoom reset / in / out | `cmd+0` / `cmd++` / `cmd+-` |

So "new chat" and "switch chat" — the two things the dead `strip:new` and
`strip:next` actions promised — are reachable on the desktop after all, just
through the app's own menus rather than through Claude Code.

## Use a second layer, not a compromise

Do not fold these into the terminal layout. The two sets overlap in intent and
share no keys, and the terminal layout is the one that does real work.

Input can **link a layer to an application**, so the pad switches automatically
when you focus Claude rather than iTerm, and you never press the layer key.
Build a second layer, assign the table above, and link it to `Claude.app`.

The terminal layer stays exactly as it is.

## If you pick this up again

The open question is whether `Stop` and `Notification` hooks fire for desktop
sessions. Desktop sessions run the same binary as the CLI
(`~/.local/share/claude/ClaudeCode.app/Contents/MacOS/claude`, the same inode as
the versioned executable) and read the same `settings.json`, so they plausibly
do.

To find out: clear `~/.claude/macropad/attention/`, send a prompt in the desktop
app, let it finish, and look for a new marker. If one appears, desktop sessions
can at least raise a notification naming the project — worth having even though
the jump itself has nowhere to go.
