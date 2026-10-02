# Backfill prompt

Paste this into a coding agent that can run shell commands on your Mac (Claude Code,
Codex, Cursor's agent, …). It fills `~/.config/shortcutty/shortcuts.txt` from what's
actually configured on your machine, instead of from memory.

---

Fill my shortcut cheat sheet at `~/.config/shortcutty/shortcuts.txt`. Read the
comment block at the top of that file first: it defines the format. If the file
doesn't exist, copy `shortcuts.example.txt` from the shortcutty repo there.

Rules:

- **Evidence over memory.** Every row must come from something you read on this
  machine (a config file, a prefs domain, an app's menu bar) or be a well-known
  built-in default of an app I actually have installed. Note the source in a
  `#` comment under each section header.
- **Skip what's already live.** Hotkeys bound with `shortcutty.bind` in
  `~/.hammerspoon/init.lua`, and Ghostty keybinds, are read live. Don't copy them.
  Only add a `[Ghostty]` row to rename a binding whose auto-generated description
  is cryptic (check with `ghostty +list-keybinds`).
- **Curate.** For apps with big menus, keep the 10–40 shortcuts worth remembering,
  not every menu item. Anything I've customised always goes in.
- **Ask before** adding apps I didn't mention if the list is getting long.

Where to look:

1. Installed apps: `ls /Applications`.
2. App menu bars, for any running app. Hammerspoon prints them in flat-file format:
   `hs -c 'return require("shortcutty").dumpMenu("Google Chrome")'`
   (needs `require("hs.ipc")` in init.lua; or run the same line in the Hammerspoon console).
3. Prefs domains, for menu-bar utilities and window managers, e.g.
   `defaults read com.knollsoft.Rectangle`. Shortcuts usually appear as
   `keyCode` + `modifierFlags` (Cocoa flags: ⇧ 0x20000, ⌃ 0x40000, ⌥ 0x80000,
   ⌘ 0x100000) or `carbonKeyCode` + `carbonModifiers` (⌘ 256, ⇧ 512, ⌥ 2048, ⌃ 4096).
   Many apps only store shortcuts you changed, so if the app has a status-bar
   menu, read its live shortcuts from there too.
4. Config files: Karabiner (`~/.config/karabiner/karabiner.json`), VS Code
   (`~/Library/Application Support/Code/User/keybindings.json`), nvim keymaps,
   tmux (`~/.tmux.conf`), zsh `bindkey`s, Claude Code (`~/.claude/keybindings.json`).
5. macOS: custom App Shortcuts (`defaults find NSUserKeyEquivalents`) and which
   system shortcuts are on or off (`defaults export com.apple.symbolichotkeys -`).

When done, check the popup can read the file:
`hs -c 'return #require("shortcutty").rows()'`. Then show me a per-section row count
and anything that looked like a conflict (the same keys bound by two apps).
