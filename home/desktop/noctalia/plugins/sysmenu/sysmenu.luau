-- gavos System menu (`/sys`). Rows come from ~/.config/sysmenu/menu.json, made
-- from home/desktop/menu-entries.nix. Sections drill in; rows run `sysmenu run <id>`;
-- list rows (fonts, themes) come from `<cmd> rows` and run `<cmd> <name>`.

local entries, byId, children = {}, {}, {}
local hidden = {} -- ids whose `when` test fails right now
local hasWhen = false
local lists = {} -- cmd -> rows from `<cmd> rows`
local last = ""

local function index(list)
  entries, byId, children, hasWhen = list, {}, {}, false
  for _, e in ipairs(list) do
    byId[e.id] = e
    local p = e.parent or ""
    children[p] = children[p] or {}
    table.insert(children[p], e)
    hasWhen = hasWhen or e.when == true
  end
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

local function entryRow(e, subtitle)
  local row = { id = e.id, title = e.title, subtitle = subtitle or e.sub, glyph = e.glyph }
  if e.menu then
    row.query = e.id .. " "
  end
  return row
end

local function render(text)
  last = text
  local out = {}
  local head, rest = string.match(text, "^(%S+)%s(.*)$")
  local e = head and byId[head]
  if e and e.list then
    for _, r in ipairs(lists[e.list] or {}) do
      local row = { id = "list\t" .. e.list .. "\t" .. r.name, title = r.name, subtitle = r.sub, glyph = e.glyph }
      if r.icon ~= "" then
        row.icon = r.icon
      end
      add(out, rest, row)
    end
    launcher.setResults(text, out)
    return
  elseif e and e.menu then
    for _, c in ipairs(children[e.id] or {}) do
      if not hidden[c.id] then
        add(out, rest, entryRow(c))
      end
    end
    launcher.setResults(text, out)
    return
  end

  local filter = string.match(text, "^%s*(.-)%s*$")
  add(out, filter, { id = "apps", title = "Apps", subtitle = "Search installed apps", glyph = "apps" })
  for _, c in ipairs(children[""] or {}) do
    if not hidden[c.id] then
      add(out, filter, entryRow(c))
    end
  end
  -- Typing at the top level also finds rows inside sections.
  if filter ~= "" then
    for _, c in ipairs(entries) do
      if (c.parent or "") ~= "" and not hidden[c.id] then
        local p = byId[c.parent]
        add(out, filter, entryRow(c, p and p.title))
      end
    end
  end
  launcher.setResults(text, out)
end

local function loadMenu()
  noctalia.readFileAsync(noctalia.expandPath("~/.config/sysmenu/menu.json"), function(contents)
    local ok, list = pcall(noctalia.json.decode, contents or "")
    if ok and type(list) == "table" then
      index(list)
      render(last)
    end
  end)
end

local function loadList(cmd)
  noctalia.runAsync({ cmd, "rows" }, function(res)
    if res.exitCode ~= 0 then
      return
    end
    local rows = {}
    for line in string.gmatch(res.stdout or "", "[^\n]+") do
      local name, sub, icon = string.match(line, "^([^\t]*)\t?([^\t]*)\t?([^\t]*)$")
      if name and name ~= "" then
        table.insert(rows, { name = name, sub = sub ~= "" and sub or nil, icon = icon })
      end
    end
    lists[cmd] = rows
    render(last)
  end)
end

local function loadHidden()
  noctalia.runAsync({ "sysmenu", "hidden" }, function(res)
    local now = {}
    for id in string.gmatch(res.stdout or "", "[^\n]+") do
      now[id] = true
    end
    hidden = now
    render(last)
  end)
end

pcall(loadMenu)

function onQuery(text)
  if text == "" or #entries == 0 then
    loadMenu()
  end
  render(text)
  local head = string.match(text, "^(%S+)%s")
  local e = head and byId[head]
  -- Refresh a list on the way in (so "Current" is right), or if it never loaded.
  if e and e.list and (text == head .. " " or not lists[e.list]) then
    loadList(e.list)
  end
  if hasWhen then
    loadHidden()
  end
end

function onActivate(id)
  if id == "apps" then
    -- setQuery("") only returns to /sys; reopen the plain launcher once this one closes.
    noctalia.runAsync({ "sh", "-c", "sleep 0.2; noctalia msg panel-open launcher" })
    return
  end
  -- Own scope, so apps it starts survive a Noctalia restart.
  local argv = { "systemd-run", "--user", "--scope", "--collect", "--quiet" }
  local cmd, name = string.match(id, "^list\t([^\t]+)\t(.*)$")
  if cmd then
    table.insert(argv, cmd)
    table.insert(argv, name)
  elseif byId[id] and not byId[id].menu then
    table.insert(argv, "sysmenu")
    table.insert(argv, "run")
    table.insert(argv, id)
  else
    return
  end
  noctalia.runAsync(argv)
end
