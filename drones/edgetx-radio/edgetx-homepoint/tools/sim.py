"""
Desktop harness for homept.lua: runs the script in Lua 5.2 (same major version
as EdgeTX) against an emulated EdgeTX API and the pixel-accurate 128x64 LCD
from lcd128.py.

  python tools/sim.py            # run logic tests + render screenshots/*.png
"""
import math
import os
import sys

from lupa import lua52

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lcd128  # noqa: E402
from lcd128 import LCD, LCD_W, LCD_H  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "SCRIPTS", "TELEMETRY", "homept.lua")

EVT_VIRTUAL_ENTER = 0x6000 + 2  # any distinct number works for the harness
UNIT = {"RxBt": 1, "VFAS": 1, "A4": 1, "Hdg": 20, "Yaw": 21, "Sats": 0,
        "GPS": 41, "Cels": 38, "FM": 43}
M_PER_DEG = 111320


class Radio:
    """Emulated radio: telemetry sensors, clock and LCD."""

    def __init__(self, sensors=()):
        self.lua = lua52.LuaRuntime(unpack_returned_tuples=True)
        self.lcd = LCD()
        self.time = 0            # 10 ms ticks
        self.rssi = 0
        self.values = {}
        self.sensors = {}
        self.tones = 0
        self.warnings = []
        for name in sensors:
            self.add_sensor(name)
        self._install_api()
        with open(SCRIPT, "r", encoding="utf-8") as f:
            src = f.read()
        # test seam: expose script locals without touching the shipped file
        tail = src.rindex("return {")
        probe = ("__probe = function() return { home = home, cells = cells, "
                 "armed = armed, cellV = cellV, heading = heading, "
                 "bearing = bearing, dist = dist, linked = linked, "
                 "hasGps = hasGps } end\n")
        self.script = self.lua.execute(src[:tail] + probe + src[tail:])
        self.script.init()

    # ---- telemetry model ---------------------------------------------------
    def add_sensor(self, name, unit=None):
        self.sensors[name] = {"id": 200 + len(self.sensors), "unit":
                              UNIT.get(name, 0) if unit is None else unit}

    def set(self, **kw):
        for k, v in kw.items():
            self.values[k] = v

    # ---- API ---------------------------------------------------------------
    def _check_int(self, fn, *vals):
        for v in vals:
            if isinstance(v, float) and not v.is_integer():
                self.warnings.append(f"{fn}: non-integer coordinate {v}")

    def _install_api(self):
        lua, lcd = self.lua, self.lcd
        g = lua.globals()
        L = lua.table()
        radio = self

        def clear(*_):
            lcd.clear()

        def drawLine(x1, y1, x2, y2, pat, flags):
            radio._check_int("drawLine", x1, y1, x2, y2)
            x1, y1, x2, y2 = (int(round(v)) for v in (x1, y1, x2, y2))
            if min(x1, y1, x2, y2) < 0:
                radio.warnings.append(f"drawLine: negative coord {x1,y1,x2,y2}")
                return
            if x1 > LCD_W or y1 > LCD_H or x2 > LCD_W or y2 > LCD_H:
                radio.warnings.append(f"drawLine: off-screen {x1,y1,x2,y2}")
                return
            pat, flags = int(pat), int(flags)
            if pat == lcd128.SOLID and x1 == x2:
                lcd.vline(x1, min(y1, y2), abs(y2 - y1) + 1, 0xFF, flags)
            elif pat == lcd128.SOLID and y1 == y2:
                lcd.hline(min(x1, x2), y1, abs(x2 - x1) + 1, 0xFF, flags)
            else:
                lcd.line(x1, y1, x2, y2, pat, flags)

        def drawPoint(x, y, flags=0):
            radio._check_int("drawPoint", x, y)
            lcd.point(int(x), int(y), int(flags or 0))

        def drawRectangle(x, y, w, h, flags=0):
            radio._check_int("drawRectangle", x, y, w, h)
            x, y, w, h, flags = int(x), int(y), int(w), int(h), int(flags or 0)
            lcd.vline(x, y, h, 0xFF, flags)
            lcd.vline(x + w - 1, y, h, 0xFF, flags)
            lcd.hline(x + 1, y + h - 1, w - 2, 0xFF, flags)
            lcd.hline(x + 1, y, w - 2, 0xFF, flags)

        def drawFilledRectangle(x, y, w, h, flags=0):
            radio._check_int("drawFilledRectangle", x, y, w, h)
            x, y, w, h, flags = int(x), int(y), int(w), int(h), int(flags or 0)
            for i in range(y, y + h):
                lcd.hline(x, i, w, 0xFF, flags)

        def drawText(x, y, s, flags=0):
            radio._check_int("drawText", x, y)
            lcd.draw_text(int(x), int(y), str(s), int(flags or 0))

        def getLastRightPos():
            return lcd.last_right

        for name, fn in [("clear", clear), ("drawLine", drawLine),
                         ("drawPoint", drawPoint),
                         ("drawRectangle", drawRectangle),
                         ("drawFilledRectangle", drawFilledRectangle),
                         ("drawText", drawText),
                         ("getLastRightPos", getLastRightPos),
                         ("getLastPos", getLastRightPos)]:
            L[name] = fn
        g.lcd = L

        def getTime():
            return radio.time

        def getRSSI():
            return radio.rssi, 45, 42

        def getFieldInfo(name):
            s = radio.sensors.get(name)
            if not s:
                return None
            return lua.table_from({"id": s["id"], "name": name, "desc": name,
                                   "unit": s["unit"]})

        def getValue(src):
            name = None
            for n, s in radio.sensors.items():
                if s["id"] == src or n == src:
                    name = n
            if name is None:
                return 0
            if radio.rssi == 0 or name not in radio.values:
                return 0     # EdgeTX: telemetry not streaming / unavailable
            v = radio.values[name]
            if isinstance(v, dict):
                return lua.table_from(v)
            if isinstance(v, (list, tuple)):
                return lua.table_from(list(v))
            return v

        def playTone(*_):
            radio.tones += 1

        g.getTime = getTime
        g.getRSSI = getRSSI
        g.getFieldInfo = getFieldInfo
        g.getValue = getValue
        g.playTone = playTone
        consts = dict(FORCE=lcd128.FORCE, ERASE=lcd128.ERASE,
                      SOLID=lcd128.SOLID, DOTTED=lcd128.DOTTED,
                      INVERS=lcd128.INVERS, BLINK=lcd128.BLINK,
                      RIGHT=lcd128.RIGHT, CENTER=lcd128.CENTERED,
                      BOLD=lcd128.BOLD, SMLSIZE=lcd128.SMLSIZE,
                      MIDSIZE=lcd128.MIDSIZE, DBLSIZE=lcd128.DBLSIZE,
                      XXLSIZE=lcd128.XXLSIZE,
                      EVT_VIRTUAL_ENTER=EVT_VIRTUAL_ENTER)
        for k, v in consts.items():
            g[k] = v

    # ---- driving -----------------------------------------------------------
    def tick(self, seconds=0.05, visible=True, event=0):
        """Advance time and call the script like the EdgeTX Lua task does:
        background() every cycle, run() when the screen is shown."""
        self.time += int(round(seconds * 100))
        self.script.background()
        if visible:
            self.script.run(event)

    def state(self):
        t = self.lua.globals()["__probe"]()
        out = {}
        for k in ("home", "cells", "armed", "cellV", "heading", "bearing",
                  "dist", "linked", "hasGps"):
            v = t[k]
            if k == "home" and v is not None:
                v = (v["lat"], v["lon"])
            out[k] = v
        return out

    def screenshot(self, path, scale=5):
        img = self.lcd.to_image(scale)
        img.save(path)
        return path


def offset(lat, lon, north_m, east_m):
    """Point north_m / east_m metres away from lat/lon."""
    dlat = north_m / M_PER_DEG
    dlon = east_m / (M_PER_DEG * math.cos(math.radians(lat)))
    return {"lat": lat + dlat, "lon": lon + dlon}
