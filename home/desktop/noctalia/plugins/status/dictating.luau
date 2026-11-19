-- Shows a mic while voxtype is listening or transcribing; hidden otherwise.
local stateFile = nil
local shown = nil

local function show(state)
  local on = state == "recording" or state == "transcribing"
  if on == shown then
    return
  end
  shown = on
  barWidget.setGlyph(state == "transcribing" and "loader" or "microphone")
  barWidget.setGlyphColor("error")
  barWidget.setTooltip(on and ("Dictation: " .. state) or "")
  barWidget.setVisible(on)
end

noctalia.runAsync({ "sh", "-c", 'printf %s "$XDG_RUNTIME_DIR/voxtype/state"' }, function(res)
  stateFile = res.stdout
end)

function update()
  noctalia.setUpdateInterval(400)
  if not stateFile then
    show("idle")
    return
  end
  noctalia.readFileAsync(stateFile, function(contents)
    show(string.match(contents or "", "%a+") or "idle")
  end)
end
