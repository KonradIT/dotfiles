-- HomePoint telemetry screen for EdgeTX 128x64 B&W radios (RadioMaster Pocket)
--
-- Left:  big arrow pointing home, craft heading in degrees above it.
-- Right: battery icon, average LiPo cell voltage, detected cell count.
--
-- Install: copy to /SCRIPTS/TELEMETRY/homept.lua on the SD card, then
-- Model > Telemetry > Screen N > Script > homept.
-- Press ENTER on the screen to re-lock home here and recount cells.

---------------------------------------------------------------- settings
local MIN_SATS    = 6     -- satellites needed before home is locked
local CELLS       = 0     -- 0 = auto-detect LiPo cell count, or force e.g. 4
local CELL_FULL   = 4.20  -- battery icon full
local CELL_EMPTY  = 3.50  -- battery icon empty, blinks at or below this
local HOME_RADIUS = 10    -- metres; closer than this shows a house, not the arrow
local NEW_PACK    = 5     -- seconds of lost telemetry while disarmed = new pack

local HEADING_SENSORS = { "Yaw", "Hdg" }            -- first one present wins
local VOLTAGE_SENSORS = { "Cels", "VFAS", "RxBt", "A4" }
---------------------------------------------------------------------------

local UNIT_RADIANS = 21   -- EdgeTX TelemetryUnit enum
local LIPO_MAX     = 4.3  -- cell count = ceil(pack voltage / LIPO_MAX)
local M_PER_DEG    = 111320
local ENTER        = EVT_VIRTUAL_ENTER or EVT_ENTER_BREAK
local atan2        = math.atan2 or math.atan

-- sensor ids, re-resolved every second because sensors appear after discovery
local gpsId, satsId, fmId, hdgId, hdgRad, voltId
local nextResolve = 0

-- persistent state
local home            -- { lat, lon } of the launch point
local cells = 0       -- detected cell count, 0 = unknown
local armed           -- true / false from the flight mode sensor, nil = unknown
local lostSince       -- getTime() when telemetry dropped

-- values for drawing, refreshed by update()
local linked, hasGps, sats, heading, bearing, dist, cellV

local function find(names)
  for i = 1, #names do
    local f = getFieldInfo(names[i])
    if f then return f, names[i] end
  end
end

local function resolveSensors()
  local f = getFieldInfo("GPS")
  gpsId = f and f.id
  f = getFieldInfo("Sats")
  satsId = f and f.id
  f = getFieldInfo("FM")
  fmId = f and f.id
  local name
  f, name = find(HEADING_SENSORS)
  hdgId = f and f.id
  -- CRSF sends Yaw in radians; older firmware does not report the unit
  hdgRad = f and (f.unit == UNIT_RADIANS or (f.unit == nil and name == "Yaw"))
  f = find(VOLTAGE_SENSORS)
  voltId = f and f.id
end

-- Betaflight appends '*', '!' or '?' to the mode while disarmed,
-- INAV reports OK / WAIT / !ERR. Failsafe is ambiguous: keep the last state.
local function armedFromMode(fm)
  if type(fm) ~= "string" or fm == "" or fm == "!FS!" then return nil end
  local last = string.sub(fm, -1)
  if last == "*" or last == "!" or last == "?"
      or fm == "OK" or fm == "WAIT" or fm == "!ERR" then
    return false
  end
  return true
end

local function update()
  local now = getTime()
  if now >= nextResolve then
    resolveSensors()
    nextResolve = now + 100
  end

  linked = getRSSI() > 0
  if not linked then
    lostSince = lostSince or now
    -- battery unplugged on the ground: count cells again for the next pack
    if armed == false and now - lostSince > NEW_PACK * 100 then cells = 0 end
    hasGps, heading, bearing, cellV = false, nil, nil, nil
    return
  end
  lostSince = nil

  local a = fmId and armedFromMode(getValue(fmId))
  local justArmed = a and armed == false
  if a ~= nil then armed = a end

  -- position and home
  local pos = gpsId and getValue(gpsId)
  hasGps = type(pos) == "table" and (pos.lat ~= 0 or pos.lon ~= 0)
  sats = satsId and getValue(satsId)
  if hasGps and (not satsId or sats >= MIN_SATS) and (home == nil or justArmed) then
    home = { lat = pos.lat, lon = pos.lon }
  end

  bearing = nil
  if hasGps and home then
    local dy = home.lat - pos.lat
    local dx = (home.lon - pos.lon) * math.cos(math.rad(pos.lat))
    dist = math.sqrt(dx * dx + dy * dy) * M_PER_DEG
    bearing = math.deg(atan2(dx, dy)) % 360
  end

  heading = nil
  if hdgId then
    heading = getValue(hdgId)
    if hdgRad then heading = math.deg(heading) end
    heading = heading % 360
  end

  -- average cell voltage
  cellV = nil
  local v = voltId and getValue(voltId)
  if type(v) == "table" then             -- FLVSS style per-cell table
    if #v > 0 then
      local sum = 0
      for i = 1, #v do sum = sum + v[i] end
      cells, cellV = #v, sum / #v
    end
  elseif v and v > 0.5 then
    if CELLS > 0 then
      cells = CELLS
    elseif armed ~= true or cells == 0 then
      -- count only while disarmed (resting voltage), never count down
      cells = math.max(cells, math.ceil(v / LIPO_MAX))
    end
    cellV = v / cells
  end
end

---------------------------------------------------------------- drawing

local function round(x) return math.floor(x + 0.5) end

local function box(x, y, w, h)
  lcd.drawFilledRectangle(x, y, w, h, FORCE)
end

local function line(x1, y1, x2, y2)
  lcd.drawLine(round(x1), round(y1), round(x2), round(y2), SOLID, FORCE)
end

-- 7-segment digits drawn with rectangles, much bigger than the built-in fonts
local SEGS = {
  ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg",
  ["4"] = "bcfg", ["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc",
  ["8"] = "abcdefg", ["9"] = "abcdfg", ["-"] = "g",
}

local function digit(x, y, w, h, t, segs)
  local m = y + math.floor((h - t) / 2)  -- top of the middle bar
  for s in string.gmatch(segs, ".") do
    if s == "a" then box(x, y, w, t)
    elseif s == "b" then box(x + w - t, y, t, m - y + t)
    elseif s == "c" then box(x + w - t, m, t, y + h - m)
    elseif s == "d" then box(x, y + h - t, w, t)
    elseif s == "e" then box(x, m, t, y + h - m)
    elseif s == "f" then box(x, y, t, m - y + t)
    else box(x, m, w, t) end
  end
end

-- width of a segment string: digits are w wide, '.' is t wide, gap t between
local function bigWidth(s, w, t)
  local n = 0
  for i = 1, #s do
    n = n + (string.sub(s, i, i) == "." and t or w) + t
  end
  return n - t
end

local function bigText(x, y, w, h, t, s)
  for i = 1, #s do
    local c = string.sub(s, i, i)
    if c == "." then
      box(x, y + h - t, t, t)
      x = x + 2 * t
    elseif c == "1" then                   -- centred bar reads better than b+c
      box(x + math.floor((w - t) / 2), y, t, h)
      x = x + w + t
    else
      digit(x, y, w, h, t, SEGS[c])
      x = x + w + t
    end
  end
  return x - t
end

local function degreeSign(x, y)
  line(x + 1, y, x + 2, y)
  line(x + 1, y + 3, x + 2, y + 3)
  line(x, y + 1, x, y + 2)
  line(x + 3, y + 1, x + 3, y + 2)
end

-- scanline fill of a closed polygon, then outline it for clean edges
local xs = {}
local function fillPolygon(px, py)
  local n = #px
  local top, bottom = py[1], py[1]
  for i = 2, n do
    top, bottom = math.min(top, py[i]), math.max(bottom, py[i])
  end
  for y = math.ceil(top), math.floor(bottom) do
    local k, j = 0, n
    for i = 1, n do
      local ya, yb = py[j], py[i]
      if (ya <= y and yb > y) or (yb <= y and ya > y) then
        k = k + 1
        xs[k] = px[j] + (y - ya) * (px[i] - px[j]) / (yb - ya)
      end
      j = i
    end
    for i = k + 1, #xs do xs[i] = nil end
    table.sort(xs)
    for i = 1, k - 1, 2 do
      line(xs[i], y, xs[i + 1], y)
    end
  end
  local j = n
  for i = 1, n do
    line(px[j], py[j], px[i], py[i])
    j = i
  end
end

-- arrow outline (head + shaft), unit size, pointing up (y grows downwards)
local ARROW_X = { 0, 0.66, 0.26, 0.26, -0.26, -0.26, -0.66 }
local ARROW_Y = { -1, -0.05, -0.05, 0.95, 0.95, -0.05, -0.05 }
local ax, ay = {}, {}

local function drawArrow(cx, cy, r, deg)
  local a = math.rad(deg)
  local s, c = math.sin(a), math.cos(a)
  for i = 1, #ARROW_X do
    local x, y = ARROW_X[i] * r, ARROW_Y[i] * r
    ax[i] = cx + x * c - y * s
    ay[i] = cy + x * s + y * c
  end
  fillPolygon(ax, ay)
end

local function drawHouse(cx, cy)
  line(cx - 14, cy - 1, cx, cy - 15)          -- roof
  line(cx, cy - 15, cx + 14, cy - 1)
  lcd.drawRectangle(cx - 10, cy - 4, 21, 18, FORCE)
  box(cx - 3, cy + 4, 7, 10)                  -- door
end

local function message(cx, cy, l1, l2)
  lcd.drawText(cx, cy - 8, l1, CENTER + MIDSIZE)
  if l2 then lcd.drawText(cx, cy + 6, l2, CENTER) end
end

local function drawBattery(x, y, w, h, frac, blink)
  if blink and getTime() % 100 < 50 then return end
  lcd.drawRectangle(x, y, w, h, FORCE)
  box(x + w, y + 3, 3, h - 6)                 -- terminal
  local fill = math.floor((w - 4) * frac + 0.5)
  if fill > 0 then box(x + 2, y + 2, fill, h - 4) end
end

-- left half: heading on top, home arrow below
local function drawHome()
  local cx, cy = 31, 41

  local txt = heading and string.format("%d", round(heading) % 360) or "---"
  local w = bigWidth(txt, 9, 2)
  local x = bigText(cx - math.floor((w + 6) / 2), 0, 9, 16, 2, txt)
  degreeSign(x + 2, 0)

  if not linked then
    message(cx, cy, "NO", "TELEMETRY")
  elseif not hasGps then
    message(cx, cy, "NO GPS")
  elseif not home then
    message(cx, cy, "WAIT", sats and (string.format("%d", sats) .. " / " .. MIN_SATS .. " sats") or "GPS fix")
  elseif dist < HOME_RADIUS then
    drawHouse(cx, cy + 1)
  elseif not heading then
    message(cx, cy, "NO HDG")
  else
    drawArrow(cx, cy, 22, bearing - heading)
  end
end

-- right half: battery icon with cell count, big cell voltage
local function drawBatteryPanel()
  local x0 = 68
  local frac = 0
  if cellV then
    frac = math.min(1, math.max(0, (cellV - CELL_EMPTY) / (CELL_FULL - CELL_EMPTY)))
  end
  drawBattery(x0, 1, 34, 16, frac, cellV and cellV <= CELL_EMPTY)
  if cells > 0 then
    lcd.drawText(127, 3, cells .. "S", RIGHT + MIDSIZE)
  end

  local txt = "-.--"
  if cellV then
    local cv = round(cellV * 100)
    txt = string.format("%d.%02d", math.floor(cv / 100), cv % 100)
  end
  local x = bigText(x0, 24, 12, 30, 3, txt)
  lcd.drawText(x + 3, 47, "V", MIDSIZE)
end

local function init()
  resolveSensors()
end

local function background()
  update()
end

local function run(event)
  if event == ENTER then
    home, cells = nil, 0   -- re-lock home at the next good fix, recount cells
    playTone(1800, 120, 0)
  end
  update()
  lcd.clear()
  lcd.drawLine(64, 0, 64, 63, DOTTED, FORCE)
  drawHome()
  drawBatteryPanel()
  return 0
end

return { init = init, background = background, run = run }
