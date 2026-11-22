"""
Pixel-accurate emulation of the EdgeTX 128x64 monochrome LCD Lua API
(lcd.* functions used by telemetry scripts on the RadioMaster Pocket).

Ported from EdgeTX sources:
  radio/src/gui/common/stdlcd/lcd_common.cpp  (getCharPattern, lcdPutPattern,
                                               lcdDrawLine, lcdDrawRect, ...)
  radio/src/gui/128x64/lcd.cpp                (lcdDrawSizedText, lcdMaskPoint,
                                               lcdDrawHorizontalLine, ...)
  tools/encode-font.py                        (font PNG -> glyph columns)
Font PNGs in ./fonts are copied verbatim from radio/src/fonts/std (GPLv2).
"""
import os

from PIL import Image

LCD_W, LCD_H = 128, 64

# lcd flags (radio/src/gui/common/stdlcd/lcd_common.h)
BLINK = 0x01
INVERS = 0x02
RIGHT = 0x04
FIXEDWIDTH = 0x10
CENTERED = 0x20
BOLD = 0x40
FORCE = 0x02
ERASE = 0x04
TINSIZE = 0x0100
SMLSIZE = 0x0200
MIDSIZE = 0x0300
DBLSIZE = 0x0400
XXLSIZE = 0x0500
SOLID = 0xFF
DOTTED = 0x55

FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")

# fontIdx -> (png, cell width, encoder step, pattern height)
_FONT_SPECS = {
    0: ("font_05x07.png", 5, 8, 7),
    2: ("font_04x06.png", 5, 7, 6),
    3: ("font_08x10.png", 8, 12, 12),
    4: ("font_10x14_compressed.png", 10, 16, 16),
    5: ("font_22x38_num.png", 22, 40, 38),
}


def _fontsize(flags):
    return flags & 0x0F00


class _Font:
    """Glyph columns as decoded by EdgeTX: a column whose encoded bytes are
    all 0xff is a 'skip' column (not drawn, not counted in width)."""

    def __init__(self, png, cell_w, step, height):
        img = Image.open(os.path.join(FONT_DIR, png)).convert("L")
        self.cell_w, self.step, self.height = cell_w, step, height
        self.per_row = img.width // cell_w
        self.rows = img.height // step
        self.img = img
        self.special12 = step == 12

    def glyph(self, index):
        row, col = divmod(index, self.per_row)
        if row >= self.rows or index < 0:
            return [None] * self.cell_w
        cols = []
        for cx in range(self.cell_w):
            x = col * self.cell_w + cx
            bits = 0
            all_black = True
            limit = 12 if self.special12 else self.step
            for z in range(limit):
                y = row * self.step + z
                if self.img.getpixel((x, y)) == 0:
                    bits |= 1 << z
                else:
                    all_black = False
            if self.step < 8 and bits == 0x7F:
                all_black = True
            cols.append(None if all_black else bits)
        return cols


_fonts = {k: _Font(*v) for k, v in _FONT_SPECS.items()}


def _char_pattern(c, flags):
    """Return (columns, height, effective flags) like getCharPattern()."""
    fs = _fontsize(flags)
    idx = fs >> 8
    o = ord(c)
    if idx == 4:  # DBLSIZE remap
        if ord(",") <= o <= ord(":"):
            g = o - ord(",") + 1
        elif ord("A") <= o <= ord("Z"):
            g = o - ord("A") + 16
        elif ord("a") <= o <= ord("z"):
            g = o - ord("a") + 42
        elif c == "_":
            g = 4
        else:
            g = 0
    elif idx == 5:  # XXLSIZE: '+'..':' only
        g = o - ord("0") + 5
    else:
        g = o - 32
    if idx not in _fonts:
        idx = 0
        g = o - 32
    f = _fonts[idx]
    return f.glyph(g), f.height


class LCD:
    def __init__(self):
        self.clear()
        self.last_right = 0
        self.last_left = 0
        self.next_pos = 0

    # ---- framebuffer -------------------------------------------------------
    def clear(self):
        self.buf = [[0] * LCD_W for _ in range(LCD_H)]

    def point(self, x, y, att=0):
        if 0 <= x < LCD_W and 0 <= y < LCD_H:
            if att & FORCE:
                self.buf[y][x] = 1
            elif att & ERASE:
                self.buf[y][x] = 0
            else:
                self.buf[y][x] ^= 1

    def hline(self, x, y, w, pat, att):
        if y < 0 or y >= LCD_H or w == 0:
            return
        if w < 0:
            x, w = x + w + 1, -w
        if x + w <= 0 or x >= LCD_W:
            return
        if x < 0:
            w += x
            x = 0
        if x + w > LCD_W:
            w = LCD_W - x
        for i in range(w):
            if pat & 1:
                self.point(x + i, y, att)
                pat = (pat >> 1) | 0x80
            else:
                pat >>= 1

    def vline(self, x, y, h, pat, att):
        if x < 0 or x >= LCD_W or h == 0:
            return
        if h < 0:
            y, h = y + h + 1, -h
        if y + h <= 0 or y >= LCD_H:
            return
        if y < 0:
            h += y
            y = 0
        if y + h > LCD_H:
            h = LCD_H - y
        if pat == DOTTED and not (y % 2):
            pat = (~pat) & 0xFF
        for j in range(h):
            yy = y + j
            if pat & (1 << (yy % 8)):
                self.point(x, yy, att)

    def line(self, x1, y1, x2, y2, pat, att):
        dx, dy = x2 - x1, y2 - y1
        dxabs, dyabs = abs(dx), abs(dy)
        sdx = (dx > 0) - (dx < 0)
        sdy = (dy > 0) - (dy < 0)
        x, y = dyabs >> 1, dxabs >> 1
        px, py = x1, y1
        if dxabs >= dyabs:
            for _ in range(dxabs + 1):
                if (1 << (px % 8)) & pat:
                    self.point(px, py, att)
                y += dyabs
                if y >= dxabs:
                    y -= dxabs
                    py += sdy
                px += sdx
        else:
            for _ in range(dyabs + 1):
                if (1 << (py % 8)) & pat:
                    self.point(px, py, att)
                x += dxabs
                if x >= dyabs:
                    x -= dyabs
                    px += sdx
                py += sdy

    # ---- text ---------------------------------------------------------------
    def char_width(self, c, flags):
        cols, _ = _char_pattern(c, flags)
        return sum(1 for col in cols if col is not None)

    def text_width(self, s, flags):
        return sum(self.char_width(c, flags) + 1 for c in s)

    def _put_pattern(self, x, y, cols, height, flags):
        inv = bool(flags & INVERS)
        fs = _fontsize(flags)
        width = len(cols)
        ci = 0
        for i in range(width + 2):
            if 0 <= x < LCD_W:
                col = 0
                if i == 0:
                    if x == 0 or not inv:
                        self.next_pos += 1
                        continue
                    x -= 1
                elif i <= width:
                    col = cols[ci]
                    ci += 1
                    if col is None:
                        if flags & FIXEDWIDTH:
                            col = 0
                        else:
                            continue
                for j in range(-1, height + 1):
                    if j < 0 or (j == height and fs != SMLSIZE):
                        plot = False
                        if height >= 12:
                            continue
                        if j < 0 and not inv:
                            continue
                        if y + j < 0:
                            continue
                    else:
                        plot = bool(col & (1 << j))
                    if inv:
                        plot = not plot
                    self.point(x, y + j, FORCE if plot else ERASE)
            x += 1
            self.next_pos += 1

    def draw_char(self, x, y, c, flags):
        self.next_pos = x - 1
        cols, height = _char_pattern(c, flags)
        self._put_pattern(x, y, cols, height, flags)

    def draw_text(self, x, y, s, flags=0):
        orig_x = x
        width = 0
        if flags & RIGHT:
            width = self.text_width(s, flags)
            x -= width
        elif flags & CENTERED:
            width = self.text_width(s, flags)
            x -= width // 2
        for c in s:
            self.draw_char(x, y, c, flags)
            x = self.next_pos
        self.last_right = x
        self.next_pos = x
        if _fontsize(flags) == MIDSIZE:
            self.last_right += 1
        if flags & RIGHT:
            self.last_right -= width
            self.next_pos -= width
            self.last_left = self.last_right
            self.last_right = orig_x
        else:
            self.last_left = orig_x

    # ---- output -------------------------------------------------------------
    def to_image(self, scale=6, grid=False):
        on, off = (24, 32, 24), (170, 190, 160)  # STN-ish greenish LCD look
        img = Image.new("RGB", (LCD_W * scale, LCD_H * scale), off)
        px = img.load()
        for y in range(LCD_H):
            for x in range(LCD_W):
                c = on if self.buf[y][x] else off
                for dy in range(scale - (1 if grid else 0)):
                    for dx in range(scale - (1 if grid else 0)):
                        px[x * scale + dx, y * scale + dy] = c
        return img
