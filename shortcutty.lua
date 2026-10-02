-- Shortcut cheat sheet: a filterable popup of every keyboard shortcut.
--
-- Rows come from three places, gathered fresh each time the popup opens:
--   1. Hammerspoon  -- hotkeys bound through M.bind (registered live)
--   2. Ghostty      -- `ghostty +list-keybinds` (config + defaults, live;
--                      skipped when Ghostty isn't installed)
--   3. Flat file    -- ~/.config/shortcutty/shortcuts.txt (everything else)
--
-- Usage in init.lua:
--   local shortcutty = require("shortcutty")
--   shortcutty.bind({"ctrl", "alt"}, "0", "Clear notifications", fn)  -- instead of hs.hotkey.bind
--   shortcutty.start({"ctrl", "cmd"}, "/")                             -- the popup hotkey
--   shortcutty.start({"ctrl", "cmd"}, "/", { flatFile = "...", ghostty = false })
--
-- A flat-file row in a live section ([Hammerspoon] / [Ghostty]) with the same
-- keys replaces the live row's description, so cryptic auto-generated text
-- (e.g. Ghostty's `text:\x05`) can be given a human name.
--
-- Enter / click just closes the popup; completing a ⌃⌥⌘ combo closes it and
-- runs that shortcut. Filtering is described in the Popup section below.

local M = {}

local config = {
  flatFile = os.getenv("HOME") .. "/.config/shortcutty/shortcuts.txt",
  -- Path to the ghostty binary, or false to leave Ghostty out.
  ghostty = "/Applications/Ghostty.app/Contents/MacOS/ghostty",
}

local registry = {}

-- Key formatting --------------------------------------------------------------

local MOD_SYMBOLS = {
  cmd = "⌘", command = "⌘", super = "⌘",
  ctrl = "⌃", control = "⌃",
  alt = "⌥", option = "⌥", opt = "⌥",
  shift = "⇧",
}
-- Canonical display order, matching macOS menus.
local MOD_ORDER = { "⌃", "⌥", "⇧", "⌘" }

local KEY_NAMES = {
  right = "→", left = "←", up = "↑", down = "↓",
  arrow_right = "→", arrow_left = "←", arrow_up = "↑", arrow_down = "↓",
  ["return"] = "↩", enter = "↩", escape = "Esc", tab = "⇥",
  space = "Space", delete = "⌫", backspace = "⌫",
  page_up = "PgUp", page_down = "PgDn", home = "Home", ["end"] = "End",
}

local function formatChord(mods, key)
  local present = {}
  for _, m in ipairs(mods) do
    local sym = MOD_SYMBOLS[m:lower()]
    if sym then present[sym] = true end
  end
  local out = ""
  for _, sym in ipairs(MOD_ORDER) do
    if present[sym] then out = out .. sym end
  end
  local name = KEY_NAMES[key:lower()] or (#key == 1 and key:upper()) or key
  return out .. name
end

-- Ghostty trigger, e.g. "super+shift+d" or "ctrl+space>shift+g".
local function formatGhosttyTrigger(trigger)
  local parts = {}
  for step in (trigger .. ">"):gmatch("(.-)>") do
    local mods, key = {}, nil
    -- The key itself may be "+" or "=", so peel modifiers off the front only.
    local rest = step
    while true do
      local m, tail = rest:match("^(%a+)%+(.+)$")
      if m and MOD_SYMBOLS[m:lower()] then
        table.insert(mods, m)
        rest = tail
      else
        break
      end
    end
    key = rest
    table.insert(parts, formatChord(mods, key))
  end
  return table.concat(parts, "  ")
end

-- "new_split:down" -> "New split: down"
local function humanizeAction(action)
  local name, arg = action:match("^([%w_]+):?(.*)$")
  name = (name or action):gsub("_", " ")
  name = name:sub(1, 1):upper() .. name:sub(2)
  if arg and arg ~= "" then
    return name .. ": " .. arg:gsub(",", ", ")
  end
  return name
end

-- Sources ---------------------------------------------------------------------

-- Drop-in for hs.hotkey.bind that also records the binding for the popup.
-- Same argument order as hs.hotkey.bind(mods, key, message, ...), but the
-- description is never shown as an alert on press.
function M.bind(mods, key, desc, pressed, released, repeated)
  table.insert(registry, { keys = formatChord(mods, key), desc = desc, fn = pressed })
  return hs.hotkey.bind(mods, key, pressed, released, repeated)
end

local function hammerspoonRows()
  local rows = {}
  for _, r in ipairs(registry) do
    table.insert(rows, { section = "Hammerspoon", keys = r.keys, desc = r.desc })
  end
  return rows
end

local function ghosttyRows()
  local rows, seen = {}, {}
  if not config.ghostty or not hs.fs.attributes(config.ghostty) then return rows end
  local out = hs.execute(string.format("%q +list-keybinds --plain", config.ghostty))
  for line in (out or ""):gmatch("[^\n]+") do
    -- Greedy trigger so keys like "super+=" keep their "=".
    local trigger, action = line:match("^keybind = (.+)=([%a_][^=]*)$")
    -- chain= lines continue the previous binding; they are not shortcuts.
    -- digit_N duplicates the plain-number binding, and bare copy/paste are
    -- the dedicated hardware keys most Mac keyboards don't have.
    local skip = trigger == "chain" or trigger == "copy" or trigger == "paste"
      or (trigger and trigger:find("digit_", 1, true))
    if trigger and not skip and not seen[trigger] then
      seen[trigger] = true
      table.insert(rows, {
        section = "Ghostty",
        keys = formatGhosttyTrigger(trigger),
        desc = humanizeAction(action),
      })
    end
  end
  return rows
end

-- Format:   [Section]   then   keys | description   ; "#" starts a comment.
local function flatFileRows()
  local rows, section = {}, "Misc"
  local f = io.open(config.flatFile, "r")
  if not f then return rows end
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    local header = line:match("^%[(.+)%]$")
    if header then
      section = header
    elseif line ~= "" and not line:match("^#") then
      local keys, desc = line:match("^(.-)%s*|%s*(.+)$")
      if keys then
        table.insert(rows, { section = section, keys = keys, desc = desc })
      end
    end
  end
  f:close()
  return rows
end

-- Override matching ignores spacing, case and modifier order, so a hand-typed
-- "⌘⇧D" matches the live "⇧⌘D" and "⌃Space o" matches "⌃Space  O".
local function overrideKey(r)
  local chars = {}
  for _, c in utf8.codes((r.keys:gsub("%s", ""):lower())) do
    table.insert(chars, utf8.char(c))
  end
  table.sort(chars)
  return r.section .. "\0" .. table.concat(chars)
end

local function collectRows()
  local flat = flatFileRows()
  local overrides = {}
  for _, r in ipairs(flat) do overrides[overrideKey(r)] = r end

  local rows = {}
  for _, live in ipairs({ hammerspoonRows(), ghosttyRows() }) do
    for _, r in ipairs(live) do
      local o = overrides[overrideKey(r)]
      if o then
        r.desc = o.desc
        o.used = true
      end
      table.insert(rows, r)
    end
  end
  for _, r in ipairs(flat) do
    if not r.used then table.insert(rows, r) end
  end
  return rows
end

-- Exposed for `hs -c` checks: hs -c 'return #require("shortcutty").rows()'
M.rows = collectRows

-- Backfill helper: every shortcut in an app's menu bar, already in flat-file
-- format. The app must be running. Paste the useful lines into the flat file.
--   hs -c 'return require("shortcutty").dumpMenu("Google Chrome")'
function M.dumpMenu(appName)
  local app = hs.application.find(appName)
  if not app then return "not running: " .. appName end
  local MENU_MODS = { ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" }
  -- Menus report some keys as control characters.
  local CONTROL_KEYS = { ["\b"] = "⌫", ["\127"] = "⌫", ["\t"] = "⇥", ["\r"] = "↩", ["\27"] = "Esc" }
  local lines = { "[" .. app:name() .. "]" }
  local seen = {}
  local function walk(items)
    for _, it in ipairs(items or {}) do
      local title = it.AXTitle or ""
      local key = it.AXMenuItemCmdChar
      if key and key ~= "" and title ~= "" then
        local present = {}
        for _, m in ipairs(it.AXMenuItemCmdModifiers or {}) do present[MENU_MODS[m] or ""] = true end
        local mods = ""
        for _, sym in ipairs(MOD_ORDER) do if present[sym] then mods = mods .. sym end end
        local k = CONTROL_KEYS[key] or ((#key == 1 and key:byte() >= 32) and key:upper()) or nil
        local keys = k and (mods .. k)
        if keys and not seen[keys] then
          seen[keys] = true
          local pad = string.rep(" ", math.max(1, 15 - utf8.len(keys)))
          table.insert(lines, keys .. pad .. "| " .. title)
        end
      end
      if it.AXChildren then walk(it.AXChildren[1]) end
    end
  end
  walk(app:getMenuItems())
  return table.concat(lines, "\n")
end

-- Popup -----------------------------------------------------------------------
--
-- Filters, combined:
--   text     every typed word must match. A word that starts a section name
--            ("gh", "nvim") restricts to that section; others match keys/desc.
--   held     holding ⌃⌥⌘ (+⇧) shows only rows whose shortcut uses them.
-- Completing a ⌃⌥⌘ combo closes the popup and runs that shortcut.

local chooser
local allChoices = {}
local sections = {}

local KEYS_COL = 16       -- characters; wider keys just push the description
local POPUP_WIDTH = 1000  -- pixels; chooser:width() is a % of the screen

local MOD_SET = { ["⌃"] = true, ["⌥"] = true, ["⇧"] = true, ["⌘"] = true }

-- "⇧⌘D" -> { mods = {⇧=true, ⌘=true}, key = "d" }
local function parseChord(s)
  local mods, key = {}, ""
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if key == "" and MOD_SET[ch] then mods[ch] = true else key = key .. ch end
  end
  return { mods = mods, key = key:lower() }
end

-- Row keys -> list of alternatives, each a list of chords. " / " separates
-- alternatives ("⇧↑ / ⇧↓"); whitespace separates sequence steps ("⌃Space  O").
local function parseKeys(keys)
  local alts = {}
  for alt in (keys .. " / "):gmatch("(.-) / ") do
    local chords = {}
    for step in alt:gmatch("%S+") do table.insert(chords, parseChord(step)) end
    table.insert(alts, chords)
  end
  return alts
end

local function toChoice(r)
  local pad = math.max(1, KEYS_COL - utf8.len(r.keys))
  local styled = hs.styledtext.new(r.keys .. string.rep(" ", pad), {
    font = { name = "Menlo-Bold", size = 15 },
    color = { hex = "#8aadf4" },
  }) .. hs.styledtext.new(r.desc, {
    font = { size = 15 },
  })
  return {
    text = styled,
    subText = r.section,
    section = r.section:lower(),
    textHay = (r.keys .. " " .. r.desc):lower(),
    alts = parseKeys(r.keys),
  }
end

-- Filter state ------------------------------------------------------------------

local currentQuery = ""
local heldMods = {} -- ⌃⌥⌘ currently held (plus ⇧ when held alongside them)

local function modsString(set)
  local out = ""
  for _, sym in ipairs(MOD_ORDER) do if set[sym] then out = out .. sym end end
  return out
end

-- Rows whose first chord uses every held modifier.
local function matchesHeld(c)
  for _, alt in ipairs(c.alts) do
    local step = alt[1]
    if step then
      local ok = true
      for sym in pairs(heldMods) do
        if not step.mods[sym] then ok = false; break end
      end
      if ok then return true end
    end
  end
  return false
end

local function matchesText(c, words)
  for _, w in ipairs(words) do
    if sections[w] then
      local inSection = false
      for sw in c.section:gmatch("%w+") do
        if sw:sub(1, #w) == w then inSection = true; break end
      end
      if not inSection then return false end
    elseif not c.textHay:find(w, 1, true) then
      return false
    end
  end
  return true
end

local function headerRow()
  return {
    text = hs.styledtext.new("Holding  " .. modsString(heldMods) .. "…", {
      font = { name = "Menlo-Bold", size = 15 },
      color = { hex = "#f5a97f" },
    }),
    subText = "Finish the shortcut to run it",
  }
end

-- Choices are served from a function and recomputed on refreshChoicesCallback.
-- Calling chooser:choices(table) from inside queryChangedCallback re-fires the
-- callback and recurses until the stack overflows.
local function filtered()
  local words = {}
  for w in currentQuery:gmatch("%S+") do table.insert(words, w) end
  local holding = next(heldMods) ~= nil
  local hits = {}
  if holding then table.insert(hits, headerRow()) end
  for _, c in ipairs(allChoices) do
    if matchesText(c, words) and (not holding or matchesHeld(c)) then
      table.insert(hits, c)
    end
  end
  return hits
end

local function refresh() chooser:refreshChoicesCallback() end

-- Key capture -------------------------------------------------------------------
-- Only runs while the popup is open. Plain typing (no ⌃⌥⌘) goes to the search
-- field. Holding ⌃⌥⌘ filters live; completing a combo closes the popup and
-- runs that shortcut in the app that was focused before.

local FLAG_SYMBOLS = { ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" }

local flagsTap, keyTap
local ignoreUntilReleased = false -- the ⌃⌘ still held from the opening hotkey

local function flagSet(flags)
  local s = {}
  for name, sym in pairs(FLAG_SYMBOLS) do if flags[name] then s[sym] = true end end
  return s
end

local function onFlags(e)
  local now = flagSet(e:getFlags())
  if ignoreUntilReleased then
    if next(now) == nil then ignoreUntilReleased = false end
    return false
  end
  -- Shift alone is just typing capitals, so it only counts alongside ⌃⌥⌘.
  heldMods = (now["⌃"] or now["⌥"] or now["⌘"]) and now or {}
  refresh()
  return false
end

local function runShortcut(modNames, key)
  local chord = formatChord(modNames, key)
  -- Hammerspoon's own hotkeys don't reliably fire from synthetic keystrokes,
  -- so call their handler directly. Re-pressing the cheat sheet key just closes.
  for _, r in ipairs(registry) do
    if r.keys == chord then
      if r.fn ~= M.show and r.fn then r.fn() end
      return
    end
  end
  hs.eventtap.keyStroke(modNames, key, 20000)
end

local function onKey(e)
  local flags = e:getFlags()
  if not (flags.ctrl or flags.alt or flags.cmd) then return false end
  local key = hs.keycodes.map[e:getKeyCode()]
  if not key then return false end
  local modNames = {}
  for name in pairs(FLAG_SYMBOLS) do
    if flags[name] then table.insert(modNames, name) end
  end
  chooser:hide()
  -- Give focus a moment to return to the previous app before replaying.
  hs.timer.doAfter(0.12, function() runShortcut(modNames, key) end)
  return true
end

-- Show / start ------------------------------------------------------------------

function M.show(query)
  allChoices, sections = {}, {}
  for _, r in ipairs(collectRows()) do
    local c = toChoice(r)
    table.insert(allChoices, c)
    -- Every prefix (2+ chars) of any word in a section name ("Chrome / Brave"
    -- -> "ch", "bra", ...) acts as a section filter.
    for sw in c.section:gmatch("%w+") do
      for i = 2, #sw do sections[sw:sub(1, i)] = true end
    end
  end
  heldMods = {}
  currentQuery = (query or ""):lower()
  chooser:query(query or "")
  refresh()
  local screenW = hs.screen.mainScreen():frame().w
  chooser:width(math.min(90, POPUP_WIDTH / screenW * 100))
  chooser:show()

  ignoreUntilReleased = next(flagSet(hs.eventtap.checkKeyboardModifiers())) ~= nil
  flagsTap:start()
  keyTap:start()
end

function M.start(mods, key, opts)
  for k, v in pairs(opts or {}) do config[k] = v end
  chooser = hs.chooser.new(function() end) -- show-only
  chooser:placeholderText("Search shortcuts…   (hold ⌃⌥⌘ to filter, finish a combo to run it)")
  chooser:rows(18)
  chooser:choices(filtered)
  chooser:queryChangedCallback(function(q)
    currentQuery = (q or ""):lower()
    refresh()
  end)
  chooser:hideCallback(function()
    flagsTap:stop()
    keyTap:stop()
    heldMods = {}
  end)
  flagsTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, onFlags)
  keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKey)
  M.bind(mods, key, "Shortcut cheat sheet", M.show)
end

return M
