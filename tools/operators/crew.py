"""The two operators of Sector 08, where night magic and yard machinery share the same shift.

EL FOGONERO (damage) -- the stoker became the stove. His head is a pot-bellied iron stove: two
round vents burn as eyes, the hinged door is his mouth and a flame plume flickers from the flue on
top of his head like a candle. Short and heavy, in a leather apron; his near arm is an iron
prosthesis worked by leather bellows, and it ends in a nozzle. That arm is the flamethrower.

EL SERENO (support) -- the old night watchman carries his own rain. It falls only around him,
from the brim of his hat; the hem of his coat comes apart into water and he stands on his own
puddle. His face stays in shadow but for a monocle's glint. His lantern floats at his side with an
ánima inside, a small rain spirit he sends after the machines.

Run:  python3 tools/operators/crew.py [concept]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from pixel import Canvas, hexc, sheet  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "materials", "operators")
CX, GROUND = 64, 122


def P(x, y, bob=0):
    return (CX + x, GROUND + y + bob)


# --- El Fogonero ---------------------------------------------------------------------------------
G = {
    "iron_d": hexc("1d1e22"), "iron": hexc("383b42"), "iron_l": hexc("5d636c"), "iron_h": hexc("9aa3ab"),
    "brass_d": hexc("6b4216"), "brass": hexc("b07a2e"), "brass_l": hexc("e0aa52"),
    "apron_d": hexc("4f2a19"), "apron": hexc("7c4426"), "apron_l": hexc("a8633a"),
    "shirt_d": hexc("1e2830"), "shirt": hexc("2f3e49"), "shirt_l": hexc("47606e"),
    "skin_d": hexc("7a4a36"), "skin": hexc("a96a4c"),
    "bellows_d": hexc("5a2f1d"), "bellows": hexc("8f4f2c"), "bellows_l": hexc("c07842"),
    "boot": hexc("18151a"), "boot_l": hexc("33303a"), "pants": hexc("262229"), "pants_l": hexc("3a3440"),
    "soot": hexc("121014"),
    "red": hexc("a3260f"), "orange": hexc("f0601a"), "ember": hexc("ffa13a"), "gold": hexc("ffd56e"), "white": hexc("fff6dc"),
}
HOT = [G["red"], G["orange"], G["ember"], G["gold"], G["white"]]
GLOW_G = {color[:3] for color in HOT}


def _hot(level):
    return HOT[max(0, min(4, int(round(level))))]


def _warm(c, cx, cy, radius, color, strength, keep):
    """Light on surfaces: opaque pixels near a source lean toward its colour."""
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            here = c.get(x, y)
            d = math.hypot(x - cx, (y - cy) * 1.15)
            if here[3] == 0 or d > radius or here[:3] in keep:
                continue
            t = strength * (1.0 - d / radius) ** 1.4
            c.px(x, y, (int(here[0] + (color[0] - here[0]) * t), int(here[1] + (color[1] - here[1]) * t), int(here[2] + (color[2] - here[2]) * t), 255))


def fogonero(pose):
    """pose: bob, back_foot, front_foot (x, lift), flick (0..5 flame phase), act (0..1 arm up and
    firing), blink, puff (bellows squeezed)."""
    c = Canvas()
    b = pose.get("bob", 0)
    act = pose.get("act", 0.0)
    flick = pose.get("flick", 0)
    back, front = pose.get("back_foot", (-4, 0)), pose.get("front_foot", (5, 0))
    # Legs: short and planted, heavy boots with iron toe caps.
    for (fx, lift), dark in ((back, True), (front, False)):
        hip = -4 if dark else 3
        c.poly([P(hip - 3, -18, b), P(hip + 3, -18, b), P(fx + 3, -6 - lift), P(fx - 3, -6 - lift)], G["pants"] if not dark else G["soot"])
        if not dark:
            c.line(*P(hip + 2, -17, b), *P(fx + 2, -7 - lift), G["pants_l"])
        y = -lift
        c.poly([P(fx - 4, y), P(fx + 6, y), P(fx + 6, y - 3), P(fx + 3, y - 7), P(fx - 4, y - 7)], G["boot"] if not dark else G["soot"])
        c.poly([P(fx + 3, y), P(fx + 6, y), P(fx + 6, y - 3), P(fx + 4, y - 4)], G["iron_l"] if not dark else G["iron"])
        c.line(*P(fx - 3, y - 6), *P(fx + 2, y - 6), G["boot_l"])
    # The body: stocky, a dark shirt under a broad leather apron, a tool belt.
    c.poly([P(-11, -42, b), P(11, -42, b), P(13, -30, b), P(11, -17, b), P(-11, -17, b), P(-13, -30, b)], G["shirt"])
    c.poly([P(-11, -42, b), P(-5, -42, b), P(-7, -17, b), P(-11, -17, b), P(-13, -30, b)], G["shirt_d"])
    c.poly([P(-5, -40, b), P(8, -40, b), P(10, -28, b), P(11, -13, b), P(-6, -13, b), P(-7, -28, b)], G["apron"])
    c.poly([P(-5, -40, b), P(-1, -40, b), P(-3, -13, b), P(-6, -13, b), P(-7, -28, b)], G["apron_d"])
    c.poly([P(5, -40, b), P(8, -40, b), P(10, -28, b), P(11, -15, b), P(8, -15, b)], G["apron_l"])
    c.rect(*P(-13, -27, b), *P(12, -25, b), G["iron_d"])
    c.rect(*P(1, -27, b), *P(3, -25, b), G["brass_l"])
    # Tongs and a coal scoop hanging off the belt.
    c.line(*P(-11, -25, b), *P(-13, -14, b), G["iron_l"])
    c.line(*P(-9, -25, b), *P(-12, -14, b), G["iron"])
    c.rect(*P(9, -24, b), *P(12, -19, b), G["iron"])
    c.line(*P(9, -24, b), *P(12, -24, b), G["iron_h"])
    # Scorch marks and a glowing coal in the apron pocket.
    for sx, sy in ((2, -18), (6, -21), (-2, -22), (8, -16)):
        c.px(*P(sx, sy, b), G["apron_d"])
    c.rect(*P(-1, -22, b), *P(4, -19, b), G["apron_d"])
    c.px(*P(1, -22, b), _hot(1 + (flick % 3 == 0)))
    # Far arm: a plain sleeve and a big glove, hanging, holding the shovel's short haft.
    c.poly([P(-12, -41, b), P(-8, -41, b), P(-9, -26, b), P(-13, -27, b)], G["shirt_d"])
    c.rect(*P(-14, -27, b), *P(-9, -22, b), G["apron_d"])
    # Head: a pot-bellied stove sitting straight on the shoulders.
    hb = b + pose.get("nod", 0)
    stove = [P(-11, -48, hb), P(-9, -62, hb), P(-4, -66, hb), P(6, -66, hb), P(11, -62, hb), P(13, -50, hb), P(10, -42, hb), P(-8, -42, hb)]
    c.poly(stove, G["iron"])
    c.poly([P(-11, -48, hb), P(-9, -62, hb), P(-4, -66, hb), P(-2, -66, hb), P(-4, -42, hb), P(-8, -42, hb)], G["iron_d"])
    c.poly([P(4, -66, hb), P(6, -66, hb), P(11, -62, hb), P(12, -55, hb), P(9, -58, hb)], G["iron_l"])
    c.line(*P(-3, -65, hb), *P(5, -65, hb), G["iron_h"])
    # Brass bands round the belly of the stove, and its feet on his shoulders.
    c.line(*P(-10, -55, hb), *P(12, -55, hb), G["brass"])
    c.line(*P(-9, -54, hb), *P(12, -54, hb), G["brass_d"])
    for rx in (-6, 0, 6, 10):
        c.px(*P(rx, -55, hb), G["brass_l"])
    c.rect(*P(-9, -43, hb), *P(-6, -41, hb), G["iron_d"])
    c.rect(*P(6, -43, hb), *P(9, -41, hb), G["iron_d"])
    # The flue on top, and the flame plume that is his hair.
    c.rect(*P(-1, -71, hb), *P(3, -66, hb), G["iron"])
    c.line(*P(-1, -71, hb), *P(-1, -66, hb), G["iron_l"])
    c.rect(*P(-2, -72, hb), *P(4, -71, hb), G["brass"])
    plume = 9 + (0, 2, 3, 1, -1, 1)[flick % 6] + int(act * 4)
    lean = (0, 1, 1, 0, -1, -1)[flick % 6] - int(act * 2)
    for k in range(plume):
        t = k / max(1, plume - 1)
        half = 2.6 * (1 - t) ** 0.7 + 0.3
        cx = 1 + lean * t * 2 + math.sin(t * 5 + flick) * t
        for dx in range(-3, 4):
            if abs(dx) > half:
                continue
            level = 3.4 - t * 3.2 - abs(dx) / max(0.6, half) * 1.4
            c.px(round(CX + cx + dx), GROUND - 73 - k + hb, _hot(level))
    # Face through the stove: two round vents for eyes, the hinged door for a mouth.
    blink = pose.get("blink", False)
    for ex in (4, 9):
        if blink:
            c.line(*P(ex - 1, -58, hb), *P(ex + 1, -58, hb), _hot(2))
        else:
            c.rect(*P(ex - 1, -60, hb), *P(ex + 1, -57, hb), _hot(2 + act))
            c.px(*P(ex, -59, hb), _hot(3.6 + act))
        c.line(*P(ex - 2, -61, hb), *P(ex + 2, -61, hb), G["iron_d"])  # brow of the vent
    mouth = 2 + int(act * 3)
    c.rect(*P(2, -51, hb), *P(11, -51 + mouth, hb), G["soot"])
    for mx in range(3, 11):
        c.px(*P(mx, -50 + mouth // 2, hb), _hot(1.6 + (mx % 3 == flick % 3) + act * 1.5))
        if mouth > 2:
            c.px(*P(mx, -50, hb), _hot(2.6 + act))
    c.line(*P(2, -52, hb), *P(11, -52, hb), G["iron_l"])  # the door, hinged up
    c.line(*P(2, -53, hb), *P(10, -53, hb), G["iron_h"])
    c.px(*P(12, -52, hb), G["brass_l"])
    # Glowing seams where the iron is cracked.
    c.line(*P(-6, -60, hb), *P(-4, -57, hb), _hot(1))
    c.px(*P(-3, -57, hb), _hot(2))
    # The near arm: a riveted iron prosthesis worked by leather bellows, ending in a nozzle.
    raise_y = int(act * 6)
    shoulder = (8, -40)
    elbow = (12, -30 - raise_y // 2)
    wrist = (24, -30 - raise_y)
    c.poly([P(shoulder[0] - 2, shoulder[1], b), P(shoulder[0] + 4, shoulder[1] - 1, b), P(elbow[0] + 3, elbow[1], b), P(elbow[0] - 3, elbow[1] + 1, b)], G["iron"])
    c.line(*P(shoulder[0] + 3, shoulder[1], b), *P(elbow[0] + 2, elbow[1], b), G["iron_l"])
    c.ellipse(*P(elbow[0], elbow[1], b), 3, 3, G["brass"])
    c.px(*P(elbow[0] - 1, elbow[1] - 1, b), G["brass_l"])
    # Bellows along the forearm: leather pleats, squeezed when he fires.
    squeeze = 1 if pose.get("puff") else 0
    for k in range(4):
        x0 = elbow[0] + 2 + k * (3 - squeeze)
        y0 = elbow[1] + (wrist[1] - elbow[1]) * (k / 4)
        c.poly([P(x0, y0 - 4, b), P(x0 + 3, y0 - 3, b), P(x0 + 3, y0 + 3, b), P(x0, y0 + 4, b)], G["bellows"])
        c.line(*P(x0, y0 - 4, b), *P(x0, y0 + 4, b), G["bellows_d"])
        c.line(*P(x0 + 1, y0 - 3, b), *P(x0 + 2, y0 - 3, b), G["bellows_l"])
    end = elbow[0] + 2 + 4 * (3 - squeeze)
    # Nozzle: iron barrel, brass collar, a flared mouth that is always faintly red.
    ny = wrist[1]
    c.rect(*P(end, ny - 2, b), *P(end + 7, ny + 2, b), G["iron"])
    c.line(*P(end, ny - 2, b), *P(end + 7, ny - 2, b), G["iron_h"])
    c.rect(*P(end, ny - 3, b), *P(end + 1, ny + 3, b), G["brass"])
    c.poly([P(end + 8, ny - 3, b), P(end + 11, ny - 4, b), P(end + 11, ny + 4, b), P(end + 8, ny + 3, b)], G["iron_l"])
    c.line(*P(end + 11, ny - 3, b), *P(end + 11, ny + 3, b), _hot(1 + act * 2))
    if act > 0.5:
        for k in range(10):
            spread = k * 0.45
            for dy in range(-int(spread), int(spread) + 1):
                if (k + dy + flick) % 3 == 0 and abs(dy) > spread - 1:
                    continue
                c.px(*P(end + 12 + k, ny + dy, b), _hot(4 - k * 0.32 - abs(dy) * 0.3))
    c.finish(outline=(12, 8, 8), rim=(255, 170, 90), rim_strength=0.28, rim_side=1, glow_keep=GLOW_G)
    # His own fire lights him: the face, the shoulders, the apron's bib.
    _warm(c, *P(7, -55, hb), 14, (255, 150, 70), 0.55, GLOW_G)
    _warm(c, *P(1, -72, hb), 12, (255, 170, 80), 0.5, GLOW_G)
    if act > 0.5:
        _warm(c, *P(end + 12, ny, b), 16, (255, 180, 90), 0.6, GLOW_G)
    return c.image


# --- El Sereno -----------------------------------------------------------------------------------
S = {
    "coat_d": hexc("0e2a33"), "coat": hexc("1a4552"), "coat_l": hexc("2b6a78"), "sheen": hexc("7ccad0"),
    "hat_d": hexc("0b1a20"), "hat": hexc("173039"), "hat_l": hexc("2d5360"), "band": hexc("c49a52"),
    "shadow": hexc("071216"), "skin": hexc("8a6a5c"),
    "stache": hexc("d9d4c6"), "stache_d": hexc("9d968a"),
    "glove": hexc("1c2226"), "glove_l": hexc("39464d"),
    "brass_d": hexc("6b4a1c"), "brass": hexc("b98b3e"), "brass_l": hexc("ecc274"),
    "boot": hexc("101b1f"), "boot_l": hexc("2a4048"),
    "water_d": hexc("2a7fa0"), "water": hexc("6cc7e3"), "water_l": hexc("bdf0fb"),
    "orb_o": hexc("2fa6c4"), "orb": hexc("8fefff"), "orb_c": hexc("f0feff"),
    "puddle": hexc("17485a"), "puddle_l": hexc("4fb2cf"),
}
GLOW_S = {S[k][:3] for k in ("water", "water_l", "orb_o", "orb", "orb_c", "puddle_l", "sheen")}


def sereno(pose):
    """pose: bob, rain (0..7 phase of the falling drops), float (lantern bob), reach (0..1 hand
    raised toward the lantern), flare (lantern brighter), glint, blink."""
    c = Canvas()
    b = pose.get("bob", 0)
    rain = pose.get("rain", 0)
    reach = pose.get("reach", 0.0)
    # His puddle: always under him, rippling.
    c.ellipse(*P(1, 0), 17, 3, S["puddle"])
    ring = 6 + (rain % 4) * 3
    c.ellipse(*P(1, 0), ring, max(1, ring * 0.18), None, outline=S["puddle_l"])
    # Boots barely there, standing in the water.
    for fx in (-4, 4):
        c.rect(*P(fx - 3, -4), *P(fx + 3, -1), S["boot"])
        c.line(*P(fx - 2, -4), *P(fx + 2, -4), S["boot_l"])
    # The coat: tall and narrow, collar up; below the knee it comes apart into falling water.
    coat = [P(-8, -60, b), P(6, -60, b), P(10, -48, b), P(13, -28, b), P(15, -14, b), P(-14, -14, b), P(-13, -30, b), P(-10, -50, b)]
    c.poly(coat, S["coat"])
    c.poly([P(-8, -60, b), P(-3, -60, b), P(-6, -14, b), P(-14, -14, b), P(-13, -30, b), P(-10, -50, b)], S["coat_d"])
    c.poly([P(3, -60, b), P(6, -60, b), P(10, -48, b), P(13, -28, b), P(15, -15, b), P(9, -16, b), P(6, -44, b)], S["coat_l"])
    for fx in (-9, 5, 10):
        c.line(*P(fx, -40, b), *P(fx + (1 if fx > 0 else -1), -15, b), S["coat_d"])
    c.line(*P(1, -50, b), *P(1, -14, b), S["coat_d"])  # front opening
    for by in (-46, -39, -32):
        c.px(*P(2, by, b), S["brass_l"])
    for k, sx in enumerate((-6, 8)):
        y = -48 + ((rain * 2 + k * 7) % 26)
        c.line(*P(sx, y, b), *P(sx, y + 4, b), S["sheen"])
    # The hem dissolving: ragged columns that thin into drops toward the ground.
    # Each column of the hem runs into its own drip: cloth, then dark water, then a bright tip.
    for x in range(-14, 16):
        length = (0, 3, 1, 5, 2, 4, 1, 6)[(x * 3 + 5) % 8]
        shade = S["coat_d"] if x < -5 else (S["coat_l"] if x > 9 else S["coat"])
        for k in range(length):
            y = -14 + k
            c.px(*P(x, y, b), shade if k == 0 else (S["water_d"] if k < length - 1 else S["water"]))
        if length >= 4:
            drop_y = -14 + length + 1 + (rain + x) % 6
            if drop_y < -1:
                c.px(*P(x, drop_y), S["water"])
    # Belt, and a ring of brass keys whose bits glow faintly.
    c.rect(*P(-11, -31, b), *P(11, -30, b), S["glove"])
    c.ellipse(*P(-6, -27, b), 2, 2, None, outline=S["brass"])
    for kx, ky in ((-8, -24), (-6, -23), (-4, -24)):
        c.line(*P(kx, -26, b), *P(kx, ky, b), S["brass_l"])
        c.px(*P(kx, ky + 1, b), S["orb_o"])
    # Far arm folded behind; the near arm reaches to the lantern, palm open.
    c.poly([P(-10, -56, b), P(-6, -57, b), P(-6, -40, b), P(-10, -41, b)], S["coat_d"])
    hand_y = -40 - int(reach * 12)
    c.poly([P(4, -57, b), P(9, -56, b), P(16, hand_y + 2, b), P(13, hand_y + 5, b)], S["coat"])
    c.line(*P(8, -56, b), *P(15, hand_y + 2, b), S["coat_l"])
    c.rect(*P(15, hand_y, b), *P(18, hand_y + 3, b), S["glove"])
    c.px(*P(18, hand_y, b), S["glove_l"])
    c.px(*P(19, hand_y + 1, b), S["glove_l"])
    # Collar up, the face lost in shadow: a moustache and one monocle glint.
    c.poly([P(-7, -66, b), P(6, -66, b), P(8, -59, b), P(-8, -59, b)], S["coat_d"])
    c.poly([P(-4, -71, b), P(6, -71, b), P(7, -64, b), P(-4, -63, b)], S["shadow"])
    c.poly([P(1, -66, b), P(8, -66, b), P(9, -63, b), P(6, -62, b), P(2, -63, b)], S["stache"])
    c.px(*P(9, -62, b), S["stache_d"])
    c.px(*P(1, -64, b), S["stache_d"])
    c.px(*P(7, -68, b), S["skin"])  # the tip of the nose catching the lantern
    if not pose.get("blink", False):
        c.px(*P(4, -69, b), S["orb_c"] if pose.get("glint") else S["orb"])
        c.px(*P(5, -69, b), S["orb"])
    # Hat: tall crown, a brim wide enough to rain from.
    c.poly([P(-5, -82, b), P(5, -83, b), P(6, -73, b), P(-6, -73, b)], S["hat"])
    c.poly([P(-5, -82, b), P(-2, -82, b), P(-3, -73, b), P(-6, -73, b)], S["hat_d"])
    c.line(*P(-1, -83, b), *P(4, -83, b), S["hat_l"])
    c.rect(*P(-6, -75, b), *P(6, -74, b), S["band"])
    c.poly([P(-17, -71, b), P(-12, -74, b), P(14, -74, b), P(19, -71, b), P(16, -69, b), P(-14, -69, b)], S["hat"])
    c.line(*P(-12, -73, b), *P(14, -73, b), S["hat_l"])
    c.line(*P(-14, -69, b), *P(16, -69, b), S["hat_d"])
    # His rain: strands of drops falling from the rim of the brim, only around him.
    for k, rx in enumerate((-16, -13, 15, 18)):
        for j in range(4):
            y = -66 + ((rain * 3 + k * 5 + j * 16) % 64)
            if y < -2:
                c.px(*P(rx + (j % 2), y), S["water"])
                c.px(*P(rx + (j % 2), y + 1), S["water_d"])
    c.finish(outline=(5, 12, 16), rim=(140, 235, 250), rim_strength=0.34, rim_side=1, glow_keep=GLOW_S)
    # The lantern floats ahead of him at shoulder height, an ánima inside.
    lx, ly = 22, -50 - pose.get("float", 0) - int(reach * 6)
    flare = pose.get("flare", 0)
    _warm(c, *P(lx, ly, b), 18 + flare * 4, (130, 235, 250), 0.45 + flare * 0.15, GLOW_S)
    c.rect(*P(lx - 4, ly - 6, b), *P(lx + 4, ly + 6, b), S["orb_o"])
    c.rect(*P(lx - 3, ly - 5, b), *P(lx + 3, ly + 5, b), S["orb"])
    c.rect(*P(lx - 1, ly - 3, b), *P(lx + 1, ly + 2, b), S["orb_c"])
    c.px(*P(lx - 1, ly - 1, b), S["orb_o"])  # the ánima's eyes
    c.px(*P(lx + 1, ly - 1, b), S["orb_o"])
    for x in (lx - 4, lx, lx + 4):
        c.line(*P(x, ly - 6, b), *P(x, ly + 6, b), S["brass"])
    c.line(*P(lx - 5, ly - 7, b), *P(lx + 5, ly - 7, b), S["brass_l"])
    c.line(*P(lx - 5, ly + 7, b), *P(lx + 5, ly + 7, b), S["brass_d"])
    c.rect(*P(lx - 1, ly - 10, b), *P(lx + 1, ly - 8, b), S["brass"])
    c.px(*P(lx, ly - 11, b), S["brass_l"])
    c.px(*P(lx, ly + 9, b), S["water"])
    return c.image


# --- Sheets ------------------------------------------------------------------------------------

def concept(path):
    board = Image.new("RGB", (1400, 880), (20, 27, 31))
    d = ImageDraw.Draw(board)
    try:
        title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 34)
        body = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 17)
        small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    except OSError:
        title = body = small = ImageFont.load_default()
    pieces = [
        (fogonero({"flick": 1}), fogonero({"act": 1.0, "flick": 2, "puff": True}), "El Fogonero",
         ["El fogonero se volvió estufa: dos rejillas por ojos, la puerta", "por boca y una llama que le sale del tubo como pelo.", "Su brazo es una prótesis de hierro con fuelle de cuero:", "ese brazo es el lanzallamas."]),
        (sereno({"rain": 2, "float": 1}), sereno({"rain": 5, "reach": 1.0, "flare": 2, "glint": True}), "El Sereno",
         ["El vigilante lleva su propia lluvia: cae solo a su alrededor,", "el abrigo se deshace en agua y pisa su propio charco.", "Su farol flota a su lado con un ánima dentro;", "con la mano la manda tras las máquinas."]),
    ]
    for index, (idle_art, act_art, name, lines) in enumerate(pieces):
        ox = 50 + index * 690
        d.text((ox, 30), name, font=title, fill=(228, 225, 208))
        for li, line in enumerate(lines):
            d.text((ox, 82 + li * 24), line, font=body, fill=(200, 205, 195))
        big = idle_art.resize((640, 640), Image.NEAREST).crop((60, 120, 520, 630))
        board.paste(big, (ox - 30, 200), big)
        d.text((ox + 440, 200), "en juego", font=small, fill=(150, 170, 165))
        small_idle = idle_art.resize((256, 256), Image.NEAREST)
        board.paste(small_idle, (ox + 390, 210), small_idle)
        d.text((ox + 440, 490), "atacando", font=small, fill=(150, 170, 165))
        small_act = act_art.resize((256, 256), Image.NEAREST)
        board.paste(small_act, (ox + 390, 500), small_act)
    board.save(path)


if __name__ == "__main__":
    if "concept" in sys.argv:
        concept(os.path.join(ROOT, "authored", "survivor_20261016", "crew_concept.png"))
