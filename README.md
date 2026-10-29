# Peekaboo

Your MacBook notch, saying "I'm done!"

Peekaboo is a tiny macOS app that lives in the notch. When a Claude Code session finishes or needs you, the notch springs open with a little buddy and tells you which one. Click it and you land in the right terminal tab or editor window. Running several Claudes at once? Hover the notch to see them all.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amirjf/peekaboo/main/install.sh | bash
```

That downloads the latest build into `/Applications`, starts it, and sets it to open at login. Peekaboo hooks itself into Claude Code automatically, so restart any Claude sessions that were already running and you're done.

Requires macOS 14 or later. Works best on a Mac with a notch; on other screens it appears at the top center only when it has something to say.

## What it shows

| State | What you see |
| --- | --- |
| Nothing running | A normal notch |
| Working | Small "wings" either side of the camera: your buddy on the left, a spinner and session count on the right |
| Done | The notch springs open: "Boo! All done", the task, and how long it took. Tucks away after 6 seconds |
| Needs you | Opens with Claude's question (like a permission prompt) and stays until you look |
| Several sessions | One list, sorted: needs you, done, working |

Hover to peek at every session. Click to jump to it. The menu bar icon (👀) lets you pick a buddy, turn sounds off, and play a demo.

## Buddies

- **Boo**: a soft pastel ghost (default)
- **Tofu**: a sticker cat with its paws on the notch
- **Bit**: an 8-bit pet
- **Edith**: pixel Edith with her hand-to-temple pose

Each Claude session gets its own buddy color so you can tell them apart.

## How it works

Peekaboo adds a small hook to `~/.claude/settings.json` (a backup of your original is saved next to it as `settings.json.peekaboo-backup`). On session events Claude Code runs `peekaboo-hook`, which writes the session's state to `~/.peekaboo/sessions/`. The app watches that folder and animates the notch.

Clicking a session uses AppleScript to select the exact Terminal or iTerm tab (macOS asks for permission the first time). VS Code, Cursor and other editors are focused on the session's folder; other terminals are brought to the front.

## Build from source

```bash
scripts/build-app.sh      # needs Xcode 15+ command line tools
open build/Peekaboo.app
```

Every push to `main` builds a release on GitHub Actions, which is what the install script downloads.

## License

MIT
