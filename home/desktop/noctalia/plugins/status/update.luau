-- A dot once the nixpkgs pin is over 10 days old; hidden otherwise.
local maxAge = 10 * 86400

local function show(days)
  local on = days ~= nil and days * 86400 > maxAge
  barWidget.setGlyph("point-filled")
  barWidget.setGlyphColor("primary")
  barWidget.setTooltip(on and string.format("nixpkgs is %d days old. Click to update.", days) or "")
  barWidget.setVisible(on)
end

function update()
  noctalia.setUpdateInterval(30 * 60 * 1000)
  noctalia.readFileAsync(noctalia.expandPath("~/nixos-config/flake.lock"), function(contents)
    local ok, lock = pcall(noctalia.json.decode, contents or "")
    local node = ok and lock and lock.nodes and lock.nodes[lock.nodes.root.inputs.nixpkgs]
    local stamp = node and node.locked and node.locked.lastModified
    show(stamp and math.floor((os.time() - stamp) / 86400) or nil)
  end)
end
