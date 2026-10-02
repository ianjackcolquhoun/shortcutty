# Shortcutty

A searchable keyboard-shortcut cheat sheet for macOS, built on
[Hammerspoon](https://www.hammerspoon.org/). Press one hotkey anywhere and a
Spotlight-style popup lists every shortcut you've set up, a bit like lazygit's
`?` menu, for the whole OS.

- **Type** to filter. Every word must match. A word that starts an app's name
  (`chr`, `vs`, `ghost`) narrows the list to that app.
- **Hold** ⌃, ⌥ or ⌘ and the list narrows to shortcuts that use those modifiers.
  Add ⇧ while holding one of them to narrow further.
- **Finish a combo** while holding (e.g. ⇧⌘ then `4`) and the popup closes and
  runs that shortcut in the app you were in.
- **Esc** closes it.

## Where the shortcuts come from

| Source | How |
|---|---|
| Hammerspoon hotkeys | Live. Bind them with `shortcutty.bind(…)` instead of `hs.hotkey.bind(…)` and they show up with a description. |
| [Ghostty](https://ghostty.org) keybinds | Live, from `ghostty +list-keybinds` (your config plus defaults). Skipped if Ghostty isn't installed. |
| Everything else | A plain-text file you fill in: `~/.config/shortcutty/shortcuts.txt`. |

The repo ships **no personal shortcuts**, just an example file with a few macOS
built-ins. You fill in your own, by hand or with a coding agent (see below).

## Install

Requires Hammerspoon with Accessibility permission (System Settings → Privacy &
Security → Accessibility). The popup reads modifier keys while it's open.

```sh
git clone https://github.com/<you>/shortcutty.git ~/shortcutty
ln -s ~/shortcutty/shortcutty.lua ~/.hammerspoon/shortcutty.lua
mkdir -p ~/.config/shortcutty
cp ~/shortcutty/shortcuts.example.txt ~/.config/shortcutty/shortcuts.txt
```

Then in `~/.hammerspoon/init.lua`:

```lua
local shortcutty = require("shortcutty")

-- Your existing hotkeys: swap hs.hotkey.bind for shortcutty.bind and add a
-- description as the third argument. Everything after it is unchanged.
shortcutty.bind({"ctrl", "alt"}, "0", "Clear notifications", clearNotifications)

-- The popup itself.
shortcutty.start({"ctrl", "cmd"}, "/")

-- Optional: lets agents (and you) query it from a shell with `hs -c`.
require("hs.ipc")
```

Reload Hammerspoon and press ⌃⌘/.

Options go in a third argument to `start`:

```lua
shortcutty.start({"ctrl", "cmd"}, "/", {
  flatFile = os.getenv("HOME") .. "/dotfiles/shortcuts.txt", -- default: ~/.config/shortcutty/shortcuts.txt
  ghostty = false,  -- or a path to the ghostty binary; false leaves Ghostty out
})
```

## Filling the flat file

The format is at the top of [`shortcuts.example.txt`](shortcuts.example.txt):

```
[Chrome]
⌘L             | Focus address bar
⌥⌘← / ⌥⌘→      | Previous / next tab
```

Edits show up the next time you open the popup. No reload needed.

### By hand

For any running app, Hammerspoon can print its menu-bar shortcuts already in this
format. Paste in the ones worth remembering:

```sh
hs -c 'return require("shortcutty").dumpMenu("Google Chrome")'
```

(Or run `require("shortcutty").dumpMenu("Google Chrome")` in the Hammerspoon console.)

### With an agent

Paste [`agent/backfill-prompt.md`](agent/backfill-prompt.md) into a coding agent
that can run shell commands (Claude Code, Codex, …). It reads your actual
configs, app prefs and menu bars, and fills the file from evidence instead of
guessing.

### Keeping it current (Claude Code)

[`agent/claude-code-skill/`](agent/claude-code-skill/SKILL.md) is a Claude Code
skill. With it, any time an agent adds or changes a shortcut, it also updates the
cheat sheet:

```sh
mkdir -p ~/.claude/skills
cp -r ~/shortcutty/agent/claude-code-skill ~/.claude/skills/update-shortcutty
```

## Notes

- Only ⌃/⌥/⌘ combos are captured while the popup is open. Plain typing,
  including ⇧ for capitals, goes to the search box. This means ⌘V, ⌘A and
  similar close the popup and go to the app underneath.
- Hammerspoon's own hotkeys are run by calling their handler directly. Other
  shortcuts are replayed as a keystroke to the app you were in, about 0.1s
  after the popup closes.
- The `hs` CLI hangs after `hs.reload()`, because reloading drops its connection.
  Run the reload in the background and kill it after a few seconds.

## License

MIT
