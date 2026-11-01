"""Writes the UI kit the game loads from res://ui/kit/: the pixel font as a BMFont, every glyph in
every accent as one atlas, property marks, and the 9-slice plates (drawn at 2x, the size one UI
pixel has on the 1152x648 canvas). Run from the project root: python3 tools/ui/export_kit.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from pixelkit import *

OUT = "ui/kit"
ACCENTS = ["when", "do", "then", "tool", "danger", "mute"]
X2 = 2


def save2x(img, name):
    img.resize((img.width * X2, img.height * X2), Image.NEAREST).save(f"{OUT}/{name}.png")


def font():
    chars = sorted(GLYPHS.keys(), key=ord)
    columns = 16
    cell_w = max(GLYPHS[c][0] for c in chars) + 1
    rows = (len(chars) + columns - 1) // columns
    atlas = Image.new("RGBA", (columns * cell_w, rows * ROWS), (0, 0, 0, 0))
    lines = [
        'info face="Reactive Pixel" size=12 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={LINE_HEIGHT} base=10 scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0",
        'page id=0 file="font.png"',
        f"chars count={len(chars)}",
    ]
    px = atlas.load()
    for i, char in enumerate(chars):
        width, cells = GLYPHS[char]
        ox, oy = (i % columns) * cell_w, (i // columns) * ROWS
        for x, y in cells:
            px[ox + x, oy + y] = (255, 255, 255, 255)
        lines.append(f"char id={ord(char)} x={ox} y={oy} width={width} height={ROWS} xoffset=0 yoffset=0 xadvance={width + SPACING} page=0 chnl=15")
    atlas.save(f"{OUT}/font.png")
    with open(f"{OUT}/font.fnt", "w") as f:
        f.write("\n".join(lines) + "\n")


def icons():
    names = list(ICONS.keys())
    atlas = Image.new("RGBA", (len(names) * 12, len(ACCENTS) * 12), (0, 0, 0, 0))
    for r, accent in enumerate(ACCENTS):
        for c, name in enumerate(names):
            icon(atlas, c * 12 + 1, r * 12 + 1, name, accent)
    atlas.save(f"{OUT}/icons.png")
    props = Image.new("RGBA", (len(PROPS) * 7, 7), (0, 0, 0, 0))
    for c, name in enumerate(PROPS):
        prop(props, c * 7 + 1, 1, name)
    props.save(f"{OUT}/props.png")
    with open(f"{OUT}/icons.txt", "w") as f:
        f.write("icons: " + " ".join(names) + "\naccents: " + " ".join(ACCENTS) + "\nprops: " + " ".join(PROPS) + "\n")


def plates():
    for accent in ACCENTS:
        img = Image.new("RGBA", (34, 34), (0, 0, 0, 0))
        panel(img, 1, 1, 32, 32, accent)
        save2x(img, f"panel_{accent}")
        img = Image.new("RGBA", (10, 15), (0, 0, 0, 0))
        tape(img, 1, 1, "", accent)
        save2x(img, f"tape_{accent}")
        img = Image.new("RGBA", (10, 15), (0, 0, 0, 0))
        tape(img, 1, 1, "", accent, dark=True)
        save2x(img, f"tape_{accent}_dark")
        # Chips on the board: a plate with the accent along its top and left.
        for lit in (True, False):
            img = Image.new("RGBA", (20, 14), (0, 0, 0, 0))
            ramp = RAMPS[accent]
            notched(img, 0, 0, 20, 14, FILL_HI if lit else FILL, INK, cut=2)
            hline(img, 2, 1, 16, ramp[1] if lit else ramp[0])
            vline(img, 1, 2, 10, ramp[0])
            save2x(img, f"chip_{accent}" + ("" if lit else "_dim"))
        img = Image.new("RGBA", (20, 14), (0, 0, 0, 0))
        notched(img, 0, 0, 20, 14, FILL_HI, RAMPS[accent][1], cut=2)
        save2x(img, f"chip_{accent}_hot")
    for state in ("normal", "hover", "pressed", "disabled"):
        img = Image.new("RGBA", (50, 15), (0, 0, 0, 0))
        button(img, 10, 0, 40, "", state, "tool")
        save2x(img, f"button_{state}")
    img = Image.new("RGBA", (9, 11), (0, 0, 0, 0))
    keycap(img, 0, 0, "")
    save2x(img, "keycap")
    for name, edge in (("field", LINE), ("field_focus", RAMPS["tool"][1])):
        img = Image.new("RGBA", (16, 15), (0, 0, 0, 0))
        notched(img, 0, 0, 16, 15, hexc("080b12"), edge, cut=2)
        hline(img, 2, 1, 12, INK)
        save2x(img, name)
    # The slot a piece can go in: a socket on the board.
    img = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    notched(img, 0, 0, 14, 14, FILL, INK, cut=2)
    save2x(img, "socket")
    wordmark().save(f"{OUT}/wordmark.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    font()
    icons()
    plates()
    print("kit written to", OUT)
