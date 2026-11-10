-- gavos System menu (`/sys`): sections drill in, items run `sysmenu <section> <item>`.
-- Keep the labels in step with the case arms in home/menu.nix.
local PREFIX = "/sys "

local sections = {
  { id = "learn", title = "Learn", glyph = "school", sub = "Keybindings and docs", items = {
    { "Keybindings", "keyboard" },
    { "Hyprland wiki", "world" },
    { "NixOS options", "book" },
    { "Home Manager options", "book-2" },
    { "Noctalia docs", "sparkles" },
  } },
  { id = "capture", title = "Capture", glyph = "camera", sub = "Screenshots, recording, QR codes", items = {
    { "Region", "screenshot" },
    { "Window", "app-window" },
    { "Screen", "device-desktop" },
    { "Draw on screen", "pencil" },
    { "Region to clipboard", "clipboard" },
    { "Scan QR code", "qrcode" },
    { "Record region", "player-record" },
    { "Record screen", "screen-share" },
    { "Color picker", "color-picker" },
  } },
  { id = "tools", title = "Tools", glyph = "tools", sub = "btop, lazygit, dua, wiremix", items = {
    { "System monitor (btop)", "cpu" },
    { "Git (lazygit)", "git-branch" },
    { "Disk usage (dua)", "chart-pie" },
    { "Audio mixer (wiremix)", "volume" },
  } },
  { id = "toggle", title = "Toggle", glyph = "toggle-left", sub = "Night light, do not disturb, stay awake", items = {
    { "Night light", "moon-stars" },
    { "Do not disturb", "bell-off" },
    { "Stay awake", "coffee" },
    { "Bar", "layout-navbar" },
    { "Bluetooth", "bluetooth" },
  } },
  { id = "style", title = "Style", glyph = "palette", sub = "Theme, wallpaper, light/dark", items = {
    { "Theme", "brush" },
    { "Wallpaper", "photo" },
    { "Random wallpaper", "arrows-shuffle" },
    { "Light/dark", "sun-moon" },
    { "Noctalia settings", "settings" },
  } },
  { id = "setup", title = "Setup", glyph = "adjustments", sub = "Audio, configs, restarts", items = {
    { "Audio", "volume" },
    { "Edit nixos-config", "folder-cog" },
    { "Edit dotfiles", "brand-git" },
    { "Restart Noctalia", "reload" },
    { "Reload Hyprland", "refresh" },
  } },
  { id = "update", title = "Update", glyph = "package", sub = "apply, update", items = {
    { "Apply config", "wand" },
    { "Update inputs", "cloud-download" },
  } },
  { id = "system", title = "System", glyph = "power", sub = "Lock, suspend, reboot, shut down", items = {
    { "Screensaver", "device-tv" },
    { "Lock", "lock" },
    { "Suspend", "zzz" },
    { "Log out", "logout" },
    { "Reboot", "rotate-clockwise" },
    { "Reboot to UEFI", "settings" },
    { "Shut down", "power" },
  } },
}

local recording = false
local extras = {} -- { label, glyph } from ~/.config/sysmenu/extra
local last = ""

local function itemsOf(s)
  if s.id ~= "capture" or not recording then
    return s.items
  end
  local list = { { "Stop recording", "player-stop" } }
  for _, it in ipairs(s.items) do
    table.insert(list, it)
  end
  return list
end

-- Unfiltered rows keep menu order; filtered rows are ranked by fuzzy score.
local function add(out, filter, row)
  if filter == "" then
    table.insert(out, row)
    return
  end
  local sc = noctalia.fuzzyScore(filter, row.title)
  if sc then
    row.score = sc
    table.insert(out, row)
  end
end

local function render(text)
  last = text
  local out = {}
  local head, rest = string.match(text, "^(%S+)%s(.*)$")
  for _, s in ipairs(sections) do
    if head == s.id then
      for _, it in ipairs(itemsOf(s)) do
        add(out, rest, { id = s.id .. "\t" .. it[1], title = it[1], glyph = it[2] })
      end
      launcher.setResults(text, out)
      return
    end
  end

  local filter = string.match(text, "^%s*(.-)%s*$")
  add(out, filter, { id = "apps", title = "Apps", subtitle = "Search installed apps", glyph = "apps" })
  for _, e in ipairs(extras) do
    add(out, filter, { id = "extra\t" .. e[1], title = e[1], glyph = e[2] })
  end
  for _, s in ipairs(sections) do
    add(out, filter, { id = s.id, title = s.title, subtitle = s.sub, glyph = s.glyph, query = PREFIX .. s.id .. " " })
  end
  -- Typing at the top level also finds items inside sections.
  if filter ~= "" then
    for _, s in ipairs(sections) do
      for _, it in ipairs(itemsOf(s)) do
        add(out, filter, { id = s.id .. "\t" .. it[1], title = it[1], subtitle = s.title, glyph = it[2] })
      end
    end
  end
  launcher.setResults(text, out)
end

local function loadExtras()
  noctalia.readFileAsync(noctalia.expandPath("~/.config/sysmenu/extra"), function(contents)
    local list = {}
    for line in string.gmatch(contents or "", "[^\n]+") do
      local label, _, glyph = string.match(line, "^([^\t]+)\t([^\t]*)\t?([^\t]*)$")
      if label then
        table.insert(list, { label, glyph ~= "" and glyph or "star" })
      end
    end
    extras = list
    render(last)
  end)
end

local function checkRecording()
  noctalia.runAsync({ "pgrep", "-f", "gpu-screen-recorder -w" }, function(res)
    local now = res.exitCode == 0
    if now ~= recording then
      recording = now
      render(last)
    end
  end)
end

function onQuery(text)
  render(text)
  checkRecording()
  if text == "" then
    loadExtras()
  end
end

function onActivate(id)
  if id == "apps" then
    launcher.setQuery("")
    return
  end
  local argv = { "systemd-run", "--user", "--scope", "--collect", "--quiet", "sysmenu" }
  local section, item = string.match(id, "^([^\t]+)\t(.*)$")
  if section == "extra" then
    table.insert(argv, item)
  elseif section then
    table.insert(argv, section)
    table.insert(argv, item)
  else
    return
  end
  -- Own scope, so apps it starts survive a Noctalia restart.
  noctalia.runAsync(argv)
end
