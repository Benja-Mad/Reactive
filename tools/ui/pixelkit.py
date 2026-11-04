"""The crew's UI kit in pixels: a hand-drawn font with Spanish accents, notched panels, button
plates, keycaps and a 10x10 glyph for every routine piece. Everything is drawn on a UI grid where
one UI pixel is two pixels of the world buffer, so the interface sits on the same grain as the yard.
"""
from PIL import Image

# --- Palette ---------------------------------------------------------------------------------------

def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)

INK = hexc("05070b")
FILL = hexc("0d1119")
FILL_HI = hexc("151c2a")
LINE = hexc("263042")
LINE_HI = hexc("3a4660")
TEXT = hexc("e8e4d8")
DIM = hexc("8a90a0")
FAINT = hexc("4a5266")
DANGER = hexc("ff3b6b")

# Darkest to white-hot. WHEN fires (orange), DO shapes matter (cyan), THEN reacts (violet),
# upgrades and tools are amber. Rose stays for the machines.
RAMPS = {
    "when": [hexc("7c2a12"), hexc("ff6a24"), hexc("ffad4a"), hexc("fff0c8")],
    "do": [hexc("1d6f80"), hexc("36c8e0"), hexc("93f3ff"), hexc("effeff")],
    "then": [hexc("352a6e"), hexc("7a66e8"), hexc("b4a6ff"), hexc("f0ecff")],
    "tool": [hexc("6e4614"), hexc("e0a040"), hexc("ffd27a"), hexc("fff4d8")],
    "danger": [hexc("5c1028"), hexc("ff3b6b"), hexc("ff8aa6"), hexc("ffe0e8")],
    "mute": [hexc("1a2130"), LINE_HI, DIM, TEXT],
}

# --- Font -----------------------------------------------------------------------------------------
# Rows in a 12-row cell: 0-2 accents over capitals, 3-9 capitals (baseline under row 9),
# 5-9 lower case, 10-11 descenders. Each glyph is (top row, rows).

CAP, XH, ASC = 3, 5, 3

_G = {
    "A": (CAP, [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"]),
    "B": (CAP, ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."]),
    "C": (CAP, [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."]),
    "D": (CAP, ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."]),
    "E": (CAP, ["#####", "#....", "#....", "####.", "#....", "#....", "#####"]),
    "F": (CAP, ["#####", "#....", "#....", "####.", "#....", "#....", "#...."]),
    "G": (CAP, [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."]),
    "H": (CAP, ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"]),
    "I": (CAP, ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"]),
    "J": (CAP, ["...#", "...#", "...#", "...#", "#..#", "#..#", ".##."]),
    "K": (CAP, ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"]),
    "L": (CAP, ["#...", "#...", "#...", "#...", "#...", "#...", "####"]),
    "M": (CAP, ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"]),
    "N": (CAP, ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"]),
    "O": (CAP, [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."]),
    "P": (CAP, ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."]),
    "Q": (CAP, [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"]),
    "R": (CAP, ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"]),
    "S": (CAP, [".####", "#....", "#....", ".###.", "....#", "....#", "####."]),
    "T": (CAP, ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."]),
    "U": (CAP, ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."]),
    "V": (CAP, ["#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."]),
    "W": (CAP, ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"]),
    "X": (CAP, ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"]),
    "Y": (CAP, ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."]),
    "Z": (CAP, ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"]),
    "0": (CAP, [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."]),
    "1": (CAP, [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"]),
    "2": (CAP, [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"]),
    "3": (CAP, ["####.", "....#", "....#", ".###.", "....#", "....#", "####."]),
    "4": (CAP, ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."]),
    "5": (CAP, ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."]),
    "6": (CAP, [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."]),
    "7": (CAP, ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."]),
    "8": (CAP, [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."]),
    "9": (CAP, [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."]),
    "a": (XH, [".##.", "...#", ".###", "#..#", ".###"]),
    "b": (ASC, ["#...", "#...", "###.", "#..#", "#..#", "#..#", "###."]),
    "c": (XH, [".###", "#...", "#...", "#...", ".###"]),
    "d": (ASC, ["...#", "...#", ".###", "#..#", "#..#", "#..#", ".###"]),
    "e": (XH, [".##.", "#..#", "####", "#...", ".###"]),
    "f": (ASC, [".##", "#..", "###", "#..", "#..", "#..", "#.."]),
    "g": (XH, [".###", "#..#", "#..#", "#..#", ".###", "...#", ".##."]),
    "h": (ASC, ["#...", "#...", "###.", "#..#", "#..#", "#..#", "#..#"]),
    "i": (ASC, ["#", ".", "#", "#", "#", "#", "#"]),
    "j": (ASC, [".#", "..", ".#", ".#", ".#", ".#", ".#", ".#", "#."]),
    "k": (ASC, ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"]),
    "l": (ASC, ["#.", "#.", "#.", "#.", "#.", "#.", ".#"]),
    "m": (XH, ["##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"]),
    "n": (XH, ["###.", "#..#", "#..#", "#..#", "#..#"]),
    "o": (XH, [".##.", "#..#", "#..#", "#..#", ".##."]),
    "p": (XH, ["###.", "#..#", "#..#", "#..#", "###.", "#...", "#..."]),
    "q": (XH, [".###", "#..#", "#..#", "#..#", ".###", "...#", "...#"]),
    "r": (XH, ["#.##", "##..", "#...", "#...", "#..."]),
    "s": (XH, [".###", "#...", ".##.", "...#", "###."]),
    "t": (4, ["#..", "###", "#..", "#..", "#..", ".##"]),
    "u": (XH, ["#..#", "#..#", "#..#", "#..#", ".###"]),
    "v": (XH, ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."]),
    "w": (XH, ["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."]),
    "x": (XH, ["#..#", "#..#", ".##.", "#..#", "#..#"]),
    "y": (XH, ["#..#", "#..#", "#..#", "#..#", ".###", "...#", ".##."]),
    "z": (XH, ["####", "...#", ".##.", "#...", "####"]),
    " ": (CAP, ["..."]),
    " ": (CAP, ["..."]),
    "▲": (6, ["..#..", ".###.", "#####"]),
    ".": (9, ["#"]),
    ",": (9, [".#", "#."]),
    ":": (6, ["#", ".", ".", "#"]),
    ";": (6, [".#", "..", "..", ".#", "#."]),
    "!": (CAP, ["#", "#", "#", "#", "#", ".", "#"]),
    "¡": (XH, ["#", ".", "#", "#", "#", "#", "#"]),
    "?": (CAP, [".##.", "#..#", "...#", "..#.", ".#..", "....", ".#.."]),
    "¿": (XH, ["..#.", "....", "..#.", ".#..", "#...", "#..#", ".##."]),
    "-": (6, ["###"]),
    "_": (10, ["####"]),
    "'": (CAP, ["#", "#"]),
    '"': (CAP, ["#.#", "#.#"]),
    "/": (CAP, ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]),
    "(": (CAP, [".#", "#.", "#.", "#.", "#.", "#.", ".#"]),
    ")": (CAP, ["#.", ".#", ".#", ".#", ".#", ".#", "#."]),
    "%": (CAP, ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"]),
    "+": (5, [".#.", "###", ".#."]),
    "=": (5, ["####", "....", "####"]),
    "<": (4, ["..#", ".#.", "#..", ".#.", "..#"]),
    ">": (4, ["#..", ".#.", "..#", ".#.", "#.."]),
    "«": (5, [".#.#", "#.#.", ".#.#"]),
    "»": (5, ["#.#.", ".#.#", "#.#."]),
    "→": (5, ["...#.", "#####", "...#."]),
    "←": (5, [".#...", "#####", ".#..."]),
    "↑": (CAP, ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#.."]),
    "↓": (CAP, ["..#..", "..#..", "..#..", "..#..", "#.#.#", ".###.", "..#.."]),
    "×": (5, ["#.#", ".#.", "#.#"]),
    "·": (6, ["#"]),
    "…": (9, ["#.#.#"]),
    "›": (5, ["#..", ".#.", "#.."]),
    "‹": (5, ["..#", ".#.", "..#"]),
    "—": (6, ["#####"]),
    "✓": (4, ["....#", "...#.", "#.#..", ".#..."]),
    "!": (CAP, ["#", "#", "#", "#", "#", ".", "#"]),
    "#": (CAP, [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."]),
    "▶": (4, ["#..", "##.", "###", "##.", "#.."]),
    "°": (CAP, [".#.", "#.#", ".#."]),
}

# Accents: (base, marks as {row: pattern}) laid over the base glyph, centred.
_ACUTE_LOW = {2: "..#", 3: ".#."}
_ACUTE_CAP = {0: "..#", 1: ".#."}
_TILDE_LOW = {2: ".#.#", 3: "#.#."}
_TILDE_CAP = {0: ".#.#", 1: "#.#."}
_DIA_LOW = {3: "#..#"}
_DIA_CAP = {1: "#...#"}
_ACCENTED = {
    "á": ("a", _ACUTE_LOW), "é": ("e", _ACUTE_LOW), "ó": ("o", _ACUTE_LOW), "ú": ("u", _ACUTE_LOW),
    "í": ("i", {2: ".#", 3: "#."}), "ñ": ("n", _TILDE_LOW), "ü": ("u", _DIA_LOW),
    "Á": ("A", _ACUTE_CAP), "É": ("E", _ACUTE_CAP), "Í": ("I", _ACUTE_CAP), "Ó": ("O", _ACUTE_CAP),
    "Ú": ("U", _ACUTE_CAP), "Ñ": ("N", _TILDE_CAP), "Ü": ("U", _DIA_CAP),
}

ROWS = 12
LINE_HEIGHT = 13
SPACING = 1


def _build():
    glyphs = {}
    for char, (top, rows) in _G.items():
        width = len(rows[0])
        cells = set()
        for y, row in enumerate(rows):
            for x, mark in enumerate(row):
                if mark == "#":
                    cells.add((x, top + y))
        glyphs[char] = (width, cells)
    for char, (base, marks) in _ACCENTED.items():
        width, cells = glyphs[base]
        cells = set(cells)
        if base == "i":
            cells.discard((0, ASC))
            width = 2
            cells = {(x + 1, y) for x, y in cells}
        for row, pattern in marks.items():
            offset = (width - len(pattern) + 1) // 2
            for x, mark in enumerate(pattern):
                if mark == "#":
                    cells.add((offset + x, row))
        glyphs[char] = (width, cells)
    return glyphs


GLYPHS = _build()


def measure(text, scale=1):
    width = 0
    for char in text:
        glyph = GLYPHS.get(char, GLYPHS["?"])
        width += (glyph[0] + SPACING) * scale
    return max(0, width - SPACING * scale)


def text(img, x, y, string, color, scale=1, shadow=None, align="left"):
    """Draws `string` with its cell top at y. `shadow` drops a 1px ink copy under and right."""
    if align == "center":
        x -= measure(string, scale) // 2
    elif align == "right":
        x -= measure(string, scale)
    if shadow:
        text(img, x + scale, y + scale, string, shadow, scale)
    cursor = x
    px = img.load()
    for char in string:
        width, cells = GLYPHS.get(char, GLYPHS["?"])
        for gx, gy in cells:
            for sx in range(scale):
                for sy in range(scale):
                    X, Y = cursor + gx * scale + sx, y + gy * scale + sy
                    if 0 <= X < img.width and 0 <= Y < img.height:
                        px[X, Y] = color
        cursor += (width + SPACING) * scale
    return cursor


# --- Primitives -----------------------------------------------------------------------------------

def rect(img, x, y, w, h, color):
    px = img.load()
    for Y in range(max(0, y), min(img.height, y + h)):
        for X in range(max(0, x), min(img.width, x + w)):
            px[X, Y] = color


def hline(img, x, y, w, color):
    rect(img, x, y, w, 1, color)


def vline(img, x, y, h, color):
    rect(img, x, y, 1, h, color)


BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def dither_rect(img, x, y, w, h, color, amount_at):
    """Fills where the ordered dither says `amount_at(u, v)` covers, u and v in 0..1."""
    px = img.load()
    for Y in range(max(0, y), min(img.height, y + h)):
        for X in range(max(0, x), min(img.width, x + w)):
            amount = amount_at((X - x) / max(1, w - 1), (Y - y) / max(1, h - 1))
            if (BAYER[(X % 4) + (Y % 4) * 4] + 0.5) / 16 < amount:
                px[X, Y] = color


def notched(img, x, y, w, h, fill, edge, cut=3, inner=None):
    """A plate with its corners cut at 45 degrees, a 1px edge and an optional inner line."""
    px = img.load()
    for Y in range(h):
        for X in range(w):
            dx = min(X, w - 1 - X)
            dy = min(Y, h - 1 - Y)
            if dx + dy < cut:
                continue
            on_edge = X == 0 or Y == 0 or X == w - 1 or Y == h - 1 or dx + dy == cut
            color = edge if on_edge else fill
            if color is None:
                continue
            if 0 <= x + X < img.width and 0 <= y + Y < img.height:
                px[x + X, y + Y] = color
    if inner:
        c = cut
        hline(img, x + c + 1, y + 2, w - 2 * c - 2, inner)
        hline(img, x + c + 1, y + h - 3, w - 2 * c - 2, inner)
        vline(img, x + 2, y + c + 1, h - 2 * c - 2, inner)
        vline(img, x + w - 3, y + c + 1, h - 2 * c - 2, inner)


def panel(img, x, y, w, h, accent="tool", title=None, fill=FILL):
    """A dark notched panel with two lit corners in the accent and a label tape on its top edge."""
    ramp = RAMPS[accent]
    notched(img, x - 1, y - 1, w + 2, h + 2, None, INK, cut=4)
    notched(img, x, y, w, h, fill, LINE, cut=3)
    # Lit corners: the cut and a short run either side.
    for i in range(4):
        img.putpixel((x + 3 - i, y + i), ramp[1])
        img.putpixel((x + w - 4 + i, y + h - 1 - i), ramp[1])
    hline(img, x + 4, y, 6, ramp[1])
    vline(img, x, y + 4, 6, ramp[1])
    hline(img, x + w - 10, y + h - 1, 6, ramp[1])
    vline(img, x + w - 1, y + h - 10, 6, ramp[1])
    if title:
        tape(img, x + 12, y - 6, title, accent)


def tape(img, x, y, label, accent="tool", dark=False):
    """A label on a strip of coloured tape, ink on light: the header of a panel or a tag."""
    ramp = RAMPS[accent]
    w = measure(label) + 8
    fill = ramp[0] if dark else ramp[1]
    ink = ramp[2] if dark else INK
    rect(img, x - 1, y - 1, w + 2, 15, INK)
    rect(img, x, y, w, 13, fill)
    hline(img, x, y, w, ramp[2] if not dark else ramp[1])
    # Torn ends.
    for Y in range(0, 13, 2):
        img.putpixel((x, y + Y), INK)
        img.putpixel((x + w - 1, y + Y + 1), INK)
    text(img, x + 4, y, label, ink)
    return w


def keycap(img, x, y, label, accent=None):
    w = max(9, measure(label) + 6)
    rect(img, x, y, w, 11, INK)
    rect(img, x + 1, y, w - 2, 10, LINE_HI)
    rect(img, x + 1, y, w - 2, 9, FILL_HI)
    hline(img, x + 1, y, w - 2, LINE_HI)
    text(img, x + 3, y - 2, label, RAMPS[accent][2] if accent else TEXT)
    return w


def hints(img, x, y, pairs, align="left"):
    """Keycap + word pairs in a row: [Esc] taller  [Clic] arrastrar."""
    total = 0
    for key, word in pairs:
        total += max(9, measure(key) + 6) + 4 + measure(word) + 10
    total -= 10
    if align == "center":
        x -= total // 2
    elif align == "right":
        x -= total
    for key, word in pairs:
        x += keycap(img, x, y, key) + 4
        x = text(img, x, y - 2, word, DIM) + 10
    return x


def button(img, x, y, w, label, state="normal", accent="tool", index=None):
    """A menu plate. Hover lights a neon underline and a cursor; pressed fills with the accent."""
    ramp = RAMPS[accent]
    h = 15
    fills = {"normal": FILL, "hover": FILL_HI, "pressed": ramp[1], "disabled": FILL}
    notched(img, x, y, w, h, fills[state], INK, cut=2)
    color = {"normal": TEXT, "hover": ramp[3], "pressed": INK, "disabled": FAINT}[state]
    if state == "hover":
        hline(img, x + 2, y + h - 2, w - 4, ramp[1])
        hline(img, x + 2, y + h - 3, w - 4, ramp[0])
        vline(img, x + 1, y + 2, h - 4, ramp[1])
        text(img, x - 8, y + 1, "▶", ramp[2])
    elif state == "normal":
        hline(img, x + 2, y + h - 2, w - 4, LINE)
    elif state == "disabled":
        dither_rect(img, x + 2, y + 2, w - 4, h - 4, INK, lambda u, v: 0.4)
    tx = x + 7
    if index is not None:
        text(img, tx, y + 1, index, ramp[1] if state == "hover" else (INK if state == "pressed" else FAINT))
        tx += measure(index) + 6
    text(img, tx, y + 1, label, color)


def bar(img, x, y, segments, filled, accent, seg_w=4, h=5):
    """A segmented gauge: lit segments in the accent, spent ones as dark sockets."""
    ramp = RAMPS[accent]
    rect(img, x - 1, y - 1, segments * (seg_w + 1) + 1, h + 2, INK)
    for i in range(segments):
        sx = x + i * (seg_w + 1)
        if i < filled:
            rect(img, sx, y, seg_w, h, ramp[1])
            hline(img, sx, y, seg_w, ramp[2])
            hline(img, sx, y + h - 1, seg_w, ramp[0])
        else:
            rect(img, sx, y, seg_w, h, FILL)
            hline(img, sx, y + h - 1, seg_w, LINE)


# --- Piece glyphs ---------------------------------------------------------------------------------
# 10x10, tones 1 (dark) to 4 (white-hot) in the piece's category ramp. An ink outline is added
# round every shape so a glyph reads on any plate.

ICONS = {
    # WHEN: what fires a routine.
    "cerca": [
        "..........",
        "..333333..",
        ".3......3.",
        "3..2222..3",
        "..2....2..",
        ".2..33..2.",
        "...3443...",
        "...3443...",
        "....33....",
        "..........",
    ],
    "cada": [
        "..333333..",
        ".32222223.",
        "3222224223",
        "3222242223",
        "3222442223",
        "3222222223",
        "3222222223",
        "3222222223",
        ".32222223.",
        "..333333..",
    ],
    "rastro": [
        "..........",
        ".....3....",
        ".....43...",
        "3.3.3443..",
        "3.3.34443.",
        "3.3.3443..",
        ".....43...",
        ".....3....",
        "..........",
        "..........",
    ],
    "grupo": [
        "...33.....",
        "..3443....",
        "..3443.33.",
        "...33.3443",
        ".33...3443",
        "3443...33.",
        "3443......",
        ".33...33..",
        ".....3443.",
        "......33..",
    ],
    "herido": [
        ".33333333.",
        "3222222223",
        "32224.2223",
        "322224.223",
        "32224.2223",
        ".322.4223.",
        ".3224.223.",
        "..3224.3..",
        "...3223...",
        "....33....",
    ],
    "eco": [
        "......3...",
        ".......3..",
        "...3....3.",
        "....3...3.",
        "33...3..3.",
        "443..3..3.",
        "33...3..3.",
        "....3...3.",
        "...3....3.",
        "......33..",
    ],
    "derribo": [
        "....33....",
        "....33....",
        "..3....3..",
        ".3.4..4.3.",
        "33..44..33",
        "33..44..33",
        ".3.4..4.3.",
        "..3....3..",
        "....33....",
        "....33....",
    ],
    # DO: what is done to the matter.
    "agua": [
        "....33....",
        "....33....",
        "...3223...",
        "...3222...",
        "..342222..",
        "..342222..",
        ".34222221.",
        ".32222221.",
        "..222211..",
        "...1111...",
    ],
    "fuego": [
        ".....3....",
        "....33....",
        "....323...",
        "..3.3223..",
        "..332223..",
        ".33222223.",
        ".32244223.",
        ".22444422.",
        ".12444421.",
        "..112211..",
    ],
    "frio": [
        "....3.....",
        ".3..3..3..",
        "..3.3.3...",
        "...323....",
        "333242333.",
        "...323....",
        "..3.3.3...",
        ".3..3..3..",
        "....3.....",
        "..........",
    ],
    "arco": [
        ".....3333.",
        "....3443..",
        "...3443...",
        "..3443....",
        ".34444443.",
        ".33334433.",
        "....3443..",
        "...3443...",
        "..343.....",
        "..33......",
    ],
    "alzar": [
        "....33....",
        "...3443...",
        "..344443..",
        "....44....",
        "....44....",
        ".22222222.",
        ".23232323.",
        ".22222222.",
        ".12121212.",
        ".11111111.",
    ],
    "empujar": [
        "..........",
        ".....3....",
        ".....33...",
        "3.3333443.",
        "..33444443",
        "3.3333443.",
        ".....33...",
        ".....3....",
        "..........",
        ".22222222.",
    ],
    "soltar": [
        "...3443...",
        "...3443...",
        "...3443...",
        ".33344333.",
        "..344443..",
        "...3443...",
        "....33....",
        "..........",
        ".22222222.",
        ".11111111.",
    ],
    "pozo": [
        "..333333..",
        ".3......3.",
        "3..2222..3",
        "3.2....2.3",
        "3.2.44.2.3",
        "3.2.4..2.3",
        "3..2..2..3",
        ".3..22..3.",
        "..3....3..",
        "...3333...",
    ],
    "repeler": [
        "....33....",
        "...3333...",
        "....33....",
        ".3..44..3.",
        "333.44.333",
        "333.44.333",
        ".3..44..3.",
        "....33....",
        "...3333...",
        "....33....",
    ],
    "cubrir": [
        ".33....33.",
        "3443..3443",
        ".33.33.33.",
        "...3443...",
        ".33.33.33.",
        "3443..3443",
        ".33.33.33.",
        "...3443...",
        "....33....",
        "..........",
    ],
    # THEN: how it reacts.
    "fragmentos": [
        "3........3",
        ".43....34.",
        ".3.3..3.3.",
        "....44....",
        "...4444...",
        "...4444...",
        "....44....",
        ".3.3..3.3.",
        ".43....34.",
        "3........3",
    ],
    "detonar": [
        "......3.4.",
        ".....3.4.4",
        ".....3..4.",
        "...3333...",
        "..322223..",
        ".32422223.",
        ".32222223.",
        ".32222223.",
        "..322223..",
        "...3333...",
    ],
    "estallar": [
        "....3.....",
        ".3..3..3..",
        "..3.4.3...",
        "...444....",
        "334444433.",
        "...444....",
        "..3.4.3...",
        ".3..3..3..",
        "....3.....",
        "..........",
    ],
    "cadena": [
        "..........",
        ".3333.....",
        "3....3....",
        "3..33333..",
        "3..3.3..3.",
        ".3333...3.",
        "...3....3.",
        "....3333..",
        "..........",
        "..........",
    ],
    "colapso": [
        "3...33...3",
        ".3..33..3.",
        "..3....3..",
        "....44....",
        "33.4..4.33",
        "33.4..4.33",
        "....44....",
        "..3....3..",
        ".3..33..3.",
        "3...33...3",
    ],
    # Tools: the operator's own kit, in amber.
    "valvula": [
        "..333333..",
        ".3..33..3.",
        "3...33...3",
        "3..3443..3",
        "3333443333",
        "3..3443..3",
        "3...33...3",
        ".3..33..3.",
        "..333333..",
        "..........",
    ],
    "doble": [
        "...33...33",
        "..33...33.",
        ".343..343.",
        "34433443..",
        "..33...33.",
        ".33...33..",
        "33...33...",
        "3...3.....",
        "..........",
        "..........",
    ],
    "bocas": [
        "........33",
        ".......343",
        "......33..",
        "3333333...",
        "3444443...",
        "3333333...",
        "......33..",
        ".......343",
        "........33",
        "..........",
    ],
    "botas": [
        "..3333....",
        "..3223....",
        "..3223....",
        "..3223....",
        "..32233...",
        "..3222233.",
        "..32222223",
        "..33333333",
        "..11111111",
        "..........",
    ],
    "parche": [
        "...3333...",
        "...3443...",
        "...3443...",
        "3333443333",
        "3444444443",
        "3333443333",
        "...3443...",
        "...3443...",
        "...3333...",
        "..........",
    ],
    "manometro": [
        "..333333..",
        ".32222223.",
        "3222222423",
        "3222224223",
        "3222242223",
        "3222222223",
        ".32222223.",
        "..333333..",
        "....33....",
        "...3333...",
    ],
    "otra": [
        "3333......",
        "..........",
        "3333......",
        "..........",
        "3333...3..",
        ".......3..",
        ".....33333",
        ".......3..",
        ".......3..",
        "..........",
    ],
    # Late WHEN: a machine's foot coming down in a puddle, the splash rising.
    "charco": [
        "..3....3..",
        "...3..3...",
        ".3..33..3.",
        "....33....",
        "..........",
        "..344443..",
        ".34222243.",
        "3422112243",
        ".34222243.",
        "..344443..",
    ],
    # Source: a heap of scrap, a bent plate and a bolt on top.
    "chatarra": [
        "......3...",
        ".....343..",
        "..3...3...",
        ".343.3....",
        "..3.3223..",
        "...322223.",
        "..32244223",
        ".3224422.3",
        "3222222223",
        "1111111111",
    ],
    # WHEN on cue: the aim the player puts down, four corners round a lit point.
    "mano": [
        "333....333",
        "3........3",
        "3........3",
        "....22....",
        "...2442...",
        "...2442...",
        "....22....",
        "3........3",
        "3........3",
        "333....333",
    ],
}

CATEGORY = {
    "cerca": "when", "cada": "when", "rastro": "when", "grupo": "when", "herido": "when", "eco": "when",
    "derribo": "when",
    "agua": "do", "fuego": "do", "frio": "do", "arco": "do", "alzar": "do", "empujar": "do", "soltar": "do",
    "pozo": "do", "repeler": "do", "cubrir": "do",
    "fragmentos": "then", "detonar": "then", "estallar": "then", "cadena": "then", "colapso": "then",
    "valvula": "tool", "doble": "tool", "bocas": "tool", "botas": "tool", "parche": "tool", "manometro": "tool",
    "otra": "tool", "charco": "when", "chatarra": "do", "mano": "when",
}
for _name, _rows in ICONS.items():
    assert len(_rows) == 10 and all(len(r) == 10 for r in _rows), _name

# 5x5 property marks for under a DO node: what the matter is after the step.
PROPS = {
    "caliente": ("when", ["..3..", ".33..", ".343.", "3443.", ".33.."]),
    "frio": ("do", ["3.3.3", ".333.", "33433", ".333.", "3.3.3"]),
    "mojado": ("do", ["..3..", ".343.", ".343.", "33433", ".333."]),
    "carga": ("then", ["..33.", ".34..", "3443.", "..43.", ".33.."]),
    "pozo": ("then", [".333.", "3...3", "3.4.3", "3...3", ".333."]),
    "repele": ("then", ["3.3.3", ".....", "3.4.3", ".....", "3.3.3"]),
    "vapor": ("mute", [".3.3.", "3.3..", ".3.3.", "..3.3", ".3.3."]),
    "masa": ("mute", ["..3..", ".333.", "3...3", "33333", "33333"]),
}


def icon(img, x, y, name, accent=None, scale=1, outline=True):
    rows = ICONS[name]
    ramp = RAMPS[accent or CATEGORY[name]]
    _sprite(img, x, y, rows, ramp, scale, outline)


def prop(img, x, y, name):
    accent, rows = PROPS[name]
    _sprite(img, x, y, rows, RAMPS[accent], 1, True)


def _sprite(img, x, y, rows, ramp, scale, outline):
    h, w = len(rows), len(rows[0])
    filled = {(cx, cy) for cy, row in enumerate(rows) for cx, mark in enumerate(row) if mark != "."}
    px = img.load()

    def put(cx, cy, color):
        for sx in range(scale):
            for sy in range(scale):
                X, Y = x + cx * scale + sx, y + cy * scale + sy
                if 0 <= X < img.width and 0 <= Y < img.height:
                    px[X, Y] = color

    if outline:
        for cx, cy in filled:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (cx + dx, cy + dy)
                    if n not in filled:
                        put(n[0], n[1], INK)
    for cy, row in enumerate(rows):
        for cx, mark in enumerate(row):
            if mark != ".":
                put(cx, cy, ramp[int(mark) - 1])


def chip(img, x, y, name, label, accent=None, lit=True, w=None):
    """A routine piece as a chip on the board: plate, glyph, word, pins left and right."""
    accent = accent or CATEGORY[name]
    ramp = RAMPS[accent]
    w = w or measure(label) + 22
    h = 14
    notched(img, x, y, w, h, FILL_HI if lit else FILL, INK, cut=2)
    hline(img, x + 2, y + 1, w - 4, ramp[1] if lit else ramp[0])
    vline(img, x + 1, y + 2, h - 4, ramp[0])
    icon(img, x + 3, y + 2, name, accent)
    text(img, x + 16, y, label, ramp[2] if lit else DIM)
    # Pins.
    for py in (y + 4, y + 9):
        img.putpixel((x - 1, py), ramp[0])
        img.putpixel((x + w, py), ramp[0])
    return w


def wordmark(string="REACTIVE", scale=4):
    """The title on its own layer: an ink outline, the crew's two colours split either side, a hot
    core with scanlines, and one slice knocked sideways like a bad signal."""
    w, h = measure(string, scale) + 8, ROWS * scale + 4
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    text(core, 3, 0, string, RAMPS["do"][3], scale)
    mask = core.split()[3]
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (2, 1), (2, 2), (1, 2)]:
        layer.paste(INK, (dx, dy), mask)
    layer.paste(Image.new("RGBA", (w, h), RAMPS["when"][1]), (-1, 0), mask)
    layer.paste(Image.new("RGBA", (w, h), RAMPS["do"][1]), (1, 0), mask)
    layer.paste(core, (0, 0), mask)
    px = layer.load()
    for Y in range(0, h, 3):
        for X in range(w):
            if px[X, Y] == RAMPS["do"][3]:
                px[X, Y] = RAMPS["do"][2]
    top = 6 * scale + 1
    band = layer.crop((0, top, w, top + 3))
    layer.paste(Image.new("RGBA", band.size, (0, 0, 0, 0)), (0, top))
    layer.alpha_composite(band, (3, top))
    return layer.crop(layer.getbbox())
