---
name: update-shortcutty
description: "Keep the Hammerspoon shortcut cheat sheet in sync. Use whenever a keyboard shortcut, hotkey, keybinding or keymap is added, changed or removed anywhere on this Mac — Hammerspoon, Ghostty, Karabiner, nvim keymaps, zsh bindkey, Claude Code keybindings.json, macOS App Shortcuts, or any app — and when the user asks to add something to / fix the cheat sheet."
---

# Update the shortcut cheat sheet

The popup is built by `~/.hammerspoon/shortcutty.lua` from three sources.
Decide which one a change belongs to; only the flat file is edited by hand.

| Source | How it gets in | What you do |
|---|---|---|
| Hammerspoon hotkeys | live, via `shortcutty.bind(mods, key, "desc", fn, …)` | Bind new hotkeys with `shortcutty.bind`, never bare `hs.hotkey.bind`, and give a clear description. Nothing to add to the flat file. |
| Ghostty keybinds | live, via `ghostty +list-keybinds` | Nothing, unless the auto-generated description is cryptic (e.g. `Text: \x05`) — then add a rename row under `[Ghostty]` with the same keys. |
| Everything else | `~/.config/shortcutty/shortcuts.txt` | Add / edit / delete the row. |

## Flat file format

The comment block at the top of the flat file is the spec. In short:

```
[Section]
keys | description
```

- Reuse an existing section or add a new `[App]` header. Section words are what the user types to filter by app.
- Keys: macOS symbols in the order `⌃⌥⇧⌘`, then the key; letters uppercase; sequences separated by a space (`⌃Space O`); alternatives by ` / `.
- Rows under `[Hammerspoon]`/`[Ghostty]` only rename a live binding (matching ignores spacing, case and modifier order). Delete a rename when its binding is removed.
- Only list shortcuts actually configured, plus hard-to-remember built-ins. Descriptions: short, verb first, no trailing period.

When a shortcut is **removed** or **rebound**, fix or remove its row — stale rows are the main failure mode.

For an app's menu shortcuts, don't guess: `hs -c 'return require("shortcutty").dumpMenu("App Name")'` prints them in flat-file format (the app must be running).

## Verify

Flat-file edits show up the next time the popup opens. `init.lua`/`shortcutty.lua` changes need a Hammerspoon reload. `hs.reload()` drops the IPC connection, so the `hs` CLI hangs afterwards; always wrap it with a kill:

```sh
(hs -c 'hs.reload()' & p=$!; sleep 3; kill $p) >/dev/null 2>&1
hs -c 'local t={} for _,r in ipairs(require("shortcutty").rows()) do t[#t+1]=r.section.." | "..r.keys.." | "..r.desc end return table.concat(t,"\n")' | grep -i '<what you changed>'
```

Confirm the row appears once, with the description you expect.
