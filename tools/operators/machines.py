"""What hunts the crew in Sector 08, drawn with the operators' engine so both sides share a look.

Anything can be taken by a stolen seal -- the same kind of ward the Sereno draws, but broken and
burning rose instead of cyan: a gargoyle off a facade, a ray from the drowned bay, a city
street-sweeper. Stone, flesh or machine, the rose seal is the eye of every one of them and the
colour of every warning they give.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image  # noqa: E402
from neon import Figure, Shape, hexc, mix, ramp  # noqa: E402
from cast import CYAN, VIOLET, trace  # noqa: E402

ARMOR = ramp("#05060a", "#0b0c13", "#12141d", "#1b1e2a", "#262a39", "#363b4f", "#4d536b", "#757c98")
GUTS = ramp("#040408", "#09090f", "#101018", "#191923")
ROSE = {"dim": hexc("#6e1030"), "mid": hexc("#ff2f62"), "hi": hexc("#ff8aa8"), "core": hexc("#fff0f4")}
AQUA = {"dim": hexc("#0d3e5e"), "mid": hexc("#2a9fe6"), "hi": hexc("#86d6ff"), "core": hexc("#e4f6ff")}
GLASS = ramp("#071420", "#0c2133", "#123049")
PAINT = ramp("#2a1d10", "#4a3216", "#7a5524")
RIM = ((92, 228, 255), (255, 70, 150))


def part(points):
    return Shape().poly(points).pixels()


def seal(f, cx, cy, size=1.0, bright=1.0):
    """The stolen ward: a small broken ring with a bar through it, burning rose."""
    r = 2.4 * size
    for k in range(20):
        a = k / 20 * math.tau
        if 0.7 < a < 1.5:
            continue  # the break in the ring
        f.px(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8, ROSE["mid"] if k % 2 else ROSE["hi"], glow=True)
    f.px(cx, cy, ROSE["core"] if bright > 0.5 else ROSE["hi"], glow=True)
    f.px(cx - 1, cy + 1, ROSE["mid"], glow=True)
    f.px(cx + 1, cy - 1, ROSE["mid"], glow=True)


def seams(f, pixels, lines, color=None):
    for points in lines:
        trace(f, points, color or ARMOR[1], pixels, glow=False)


import random  # noqa: E402

STONE = ramp("#0c0d11", "#15161c", "#1f2027", "#2b2c33", "#3a3a40", "#4e4d4b", "#6a665e", "#8f897c")
MOSS = ramp("#121a12", "#1d2a18", "#2d3f1f", "#44592a")
REBAR = ramp("#1a0f0c", "#3a1f15", "#6b3a22", "#9a5a35")
TAG = {"dim": hexc("#3f6a10"), "mid": hexc("#b6f23a"), "hi": hexc("#e8ff9a")}
EMBER = {"dim": hexc("#5a1020"), "mid": hexc("#ff3d5e"), "hi": hexc("#ffb0a0"), "core": hexc("#fff4e8")}


def grain(f, pixels, colors, seed, amount=0.07, lighter=0.03):
    """Porous stone: knock random pixels one step down (pits) or up (grit) their own ramp."""
    rng = random.Random(seed)
    for x, y in sorted(pixels):
        c = f.get(x, y)
        if c[3] == 0 or (x, y) in f.emissive or c not in colors:
            continue
        r = rng.random()
        i = colors.index(c)
        if r < amount:
            f.px(x, y, colors[max(0, i - 1)])
        elif r > 1.0 - lighter:
            f.px(x, y, colors[min(len(colors) - 1, i + 1)])


def crack(f, start, steps, seed, color, clip, hot=True):
    """A jagged crack that wanders down-ish from `start`, glowing from inside when `hot`."""
    rng = random.Random(seed)
    x, y = start
    for _ in range(steps):
        x += rng.choice((-1, 0, 1))
        y += rng.choice((0, 1, 1))
        if (int(x), int(y)) in clip:
            f.px(x, y, color, glow=hot)


# --- Gárgola (saltador) ------------------------------------------------------------------------
GARGOYLE = {
    "perch": dict(hip=(48, 101), shoulder=(62, 76), head=(78, 74), hand=(73, 114.5), foot=(54, 114.5), wing=0.2, open=0.0),
    "crouch": dict(hip=(46, 105), shoulder=(63, 88), head=(80, 92), hand=(78, 114.5), foot=(50, 114.5), wing=0.45, open=0.0),
    "air": dict(hip=(40, 82), shoulder=(64, 68), head=(82, 64), hand=(96, 80), foot=(24, 92), wing=1.0, open=0.0),
    "open": dict(hip=(44, 104), shoulder=(66, 96), head=(86, 103), hand=(86, 114.5), foot=(40, 114.5), wing=0.7, open=1.0),
}


def gargola(pose=None):
    """A facade gargoyle a stolen seal woke up. Weathered concrete over rebar bones, a neon tag
    somebody sprayed on its thigh, a broken chain still bolted to its neck. It cannot fly on
    those stumps of wings -- it pounces, and the seal burns through its cracks as it gathers."""
    pose = pose or {}
    name = pose.get("pose", "perch")
    k = dict(GARGOYLE[name])
    k.update(pose.get("adjust", {}))
    f = Figure(light=(-0.6, 0.45, 0.66))
    hx, hy = k["hip"]
    sx, sy = k["shoulder"]
    ax, ay = k["head"]
    heat = {"perch": 0.25, "crouch": 1.0, "air": 0.6, "open": 1.0}[name]

    # Far arm and far leg, in shadow.
    far_hand = k.get("far_hand") or (k["hand"][0] - 7, k["hand"][1]) if name != "air" else (k["hand"][0] + 2, k["hand"][1] - 8)
    f.paint(Shape().limb((sx - 2, sy + 3), ((sx + far_hand[0]) / 2 - 3, (sy + far_hand[1]) / 2), 4.2, 3.4)
            .limb(((sx + far_hand[0]) / 2 - 3, (sy + far_hand[1]) / 2), far_hand, 3.4, 3.0).pixels(), STONE, axis="h", lift=-0.24)
    far_foot = k.get("far_foot") or (k["foot"][0] + 8, k["foot"][1]) if name != "air" else (k["foot"][0] + 4, k["foot"][1] + 6)
    f.paint(Shape().limb((hx + 3, hy), far_foot, 5, 3).pixels(), STONE, axis="h", lift=-0.26)

    # Wing stumps: two finger-bones of rebar and a torn stone membrane, flaring in the leap.
    spread = k["wing"]
    root = (sx - 6, sy - 3)
    tips = [(root[0] - 4 - spread * 10, root[1] - 24 - spread * 2), (root[0] - 17 - spread * 8, root[1] - 15 - spread * 4)]
    membrane = part([root, tips[0], (tips[0][0] - 3, tips[0][1] + 6), tips[1], (tips[1][0] + 2, tips[1][1] + 6), (root[0] - 6, root[1] + 7)])
    f.paint(membrane, STONE, axis="v", lift=-0.12)
    grain(f, membrane, STONE, 11, 0.1, 0.0)
    for tip in tips:
        trace(f, [root, tip], REBAR[2], None, glow=False)
        f.px(*tip, REBAR[3])
    # A bite out of the membrane, where the wing broke off the building.
    for x, y in Shape().ellipse(tips[1][0] + 4, tips[1][1] + 2, 3, 2.2).pixels():
        f.px(x, y, (0, 0, 0, 0)) if (x, y) in membrane else None

    # Tail, a stone whip ending in a broken spade.
    tail = Shape().limb((hx - 6, hy + 2), (hx - 15, hy + 8 if name != "air" else hy - 2), 3.2, 2.2) \
        .limb((hx - 15, hy + 8 if name != "air" else hy - 2), (hx - 20, hy + 15 if name != "air" else hy - 8), 2.2, 1.4).pixels()
    f.paint(tail, STONE, axis="h", lift=-0.1)
    tip = (hx - 21, hy + 16 if name != "air" else hy - 9)
    f.paint(part([(tip[0], tip[1] - 3), (tip[0] - 4, tip[1] + 1), (tip[0] + 1, tip[1] + 3)]), STONE, axis="h", lift=0.0)

    # Hunched torso: a heavy back that rises to the shoulders, belly tucked.
    torso = Shape().limb((hx, hy - 1), (sx, sy), 9.0, 11.0).pixels()
    torso |= Shape().ellipse(sx + 2, sy + 4, 9.5, 9.5).pixels()
    f.paint(torso, STONE, axis="v", lift=-0.02, fall=0.3)
    grain(f, torso, STONE, 3)
    # Moss in the hollows of its back, where the rain sat for decades.
    for x, y in torso:
        if (x, y - 1) not in torso and (x * 7 + y * 3) % 5 < 2:
            f.px(x, y, MOSS[3])
            f.px(x, y + 1, MOSS[2]) if (x, y + 1) in torso else None

    # Haunch, folded like a perched bird of prey's, the graffiti tag sprayed across it.
    thigh = Shape().ellipse(hx + 1, hy + 2, 9, 8).pixels()
    f.paint(thigh, STONE, axis="h", gloss=0.1, lift=0.1)
    grain(f, thigh, STONE, 5)
    tag = [(hx - 5, hy + 2), (hx - 3, hy - 1), (hx - 1, hy + 3), (hx + 1, hy - 1), (hx + 3, hy + 2), (hx + 5, hy - 2)]
    trace(f, tag, TAG["mid"], thigh)
    f.px(hx + 6, hy - 3, TAG["hi"], glow=True)
    f.px(hx - 2, hy + 5, TAG["dim"], glow=True)
    foot = k["foot"]
    shin = Shape().limb((hx + 3, hy + 6), foot, 4.6, 3.4).pixels()
    f.paint(shin, STONE, axis="h", lift=0.04)
    grain(f, shin, STONE, 7)
    for n in range(3):
        claw = part([(foot[0] - 3 + n * 3.6, foot[1] - 1.6), (foot[0] + n * 3.6 + 1.4, foot[1] - 1.6), (foot[0] + n * 3.6 + 3.2, foot[1] + 1)])
        f.paint(claw, STONE, axis="h", lift=0.2)

    # Near arm: thick as a column, knuckles of rebar, talons.
    hand = k["hand"]
    elbow = ((sx + hand[0]) / 2 + 3, (sy + hand[1]) / 2 - (2 if name != "air" else 6))
    arm = Shape().limb((sx + 2, sy + 2), elbow, 5.4, 4.2).limb(elbow, hand, 4.2, 3.8).pixels()
    f.paint(arm, STONE, axis="h", gloss=0.1, lift=0.12)
    grain(f, arm, STONE, 9)
    for n in range(3):
        bx = hand[0] - 2 + n * 3
        claw = part([(bx, hand[1] - 2), (bx + 2.6, hand[1] - 2), (bx + 4, hand[1] + 0.6), (bx + 1, hand[1] + 0.6)])
        f.paint(claw, STONE, axis="h", lift=0.25)
    f.px(elbow[0], elbow[1] + 2, REBAR[3])
    f.px(elbow[0] + 1, elbow[1] + 3, REBAR[2])

    # Head: it was carved as a waterspout, so the maw hangs open -- rain still runs out of it --
    # and the seal's fire burns at the back of the throat. Goat horns sweep back off the brow.
    for dx, lift_ in ((-3, 0.0), (1, 0.22)):
        horn = Shape().limb((ax + dx, ay - 6), (ax + dx - 6, ay - 14), 2.2, 1.3) \
            .limb((ax + dx - 6, ay - 14), (ax + dx - 12, ay - 15.4), 1.3, 0.9) \
            .limb((ax + dx - 12, ay - 15.4), (ax + dx - 15, ay - 12), 0.9, 0.4).pixels()
        f.paint(horn, STONE, axis="v", gloss=0.3, lift=lift_ + 0.2)
        for n in range(3):
            t = 0.25 + n * 0.22
            f.px(ax + dx - 7 * t * 1.6, ay - 6 - 9 * t * 1.6, STONE[2])
    ear = part([(ax - 4, ay - 3), (ax - 12, ay - 6), (ax - 3, ay)])
    f.paint(ear, STONE, axis="h", lift=0.06)
    skull = part([(ax - 7, ay - 3), (ax - 3, ay - 7.4), (ax + 5, ay - 7), (ax + 10, ay - 3), (ax + 11, ay + 1), (ax + 2, ay + 1.4), (ax - 6, ay + 3)])
    jaw = part([(ax - 4, ay + 2.4), (ax + 9, ay + 6), (ax + 9.6, ay + 8.6), (ax + 1, ay + 9), (ax - 5, ay + 6)])
    maw = part([(ax - 2, ay + 1.4), (ax + 11, ay + 1.4), (ax + 9, ay + 6), (ax - 2, ay + 3)])
    for x, y in maw:
        deep = x < ax + 3
        f.px(x, y, EMBER["hi"] if deep and y < ay + 3 else EMBER["mid"] if deep else GUTS[1], glow=deep)
    f.paint(jaw, STONE, axis="v", lift=0.12)
    f.paint(skull, STONE, axis="v", gloss=0.12, lift=0.26)
    grain(f, skull | jaw, STONE, 13)
    # Fangs: two down from the snout, one up from the jaw.
    for fx_, fy_, dy in ((ax + 4, ay + 1.4, 1), (ax + 8, ay + 1.4, 1), (ax + 7, ay + 5.4, -1)):
        f.px(fx_, fy_, STONE[7])
        f.px(fx_, fy_ + dy, STONE[6])
    brow = part([(ax - 5, ay - 5), (ax + 3, ay - 8), (ax + 11, ay - 3), (ax + 4, ay - 2.6)])
    f.paint(brow, STONE, axis="v", gloss=0.25, lift=0.36)
    f.px(ax + 4, ay - 1.6, GUTS[0])
    f.px(ax + 5, ay - 1.6, EMBER["hi"], glow=True)
    f.px(ax + 6, ay - 1.6, EMBER["mid"], glow=True)
    # Rainwater spilling over the lip.
    if name != "air":
        for n, y in enumerate(range(int(ay + 9), int(ay + 9) + 7)):
            if n % 3 != 2:
                f.px(ax + 9 + (n > 3), y, hexc("#9fc6d8") if n < 3 else hexc("#5f8aa0"))
    # The broken chain from its old mounting, swinging from the collar.
    for n in range(4):
        cx_, cy_ = ax - 6 - n * 0.6, ay + 8 + n * 2.6
        f.px(cx_, cy_, STONE[6] if n % 2 else STONE[4])
        f.px(cx_ + 1, cy_ + 1, STONE[3])

    # The seal's fire showing through cracks; on landing the chest splits open.
    crack(f, (sx - 4, sy - 6), 14, 21, EMBER["mid"] if heat > 0.5 else EMBER["dim"], torso, heat > 0.3)
    crack(f, (hx + 2, hy - 7), 9, 23, EMBER["mid"] if heat > 0.5 else EMBER["dim"], torso, heat > 0.3)
    crack(f, (elbow[0] - 1, elbow[1] - 6), 7, 29, EMBER["dim"], arm, heat > 0.7)
    if k["open"]:
        chest = Shape().ellipse(sx + 3, sy + 4, 5.2, 5.8).pixels()
        for x, y in chest:
            d = math.hypot(x - sx - 3, y - sy - 4)
            f.px(x, y, EMBER["core"] if d < 2 else EMBER["hi"] if d < 3.4 else EMBER["mid"], glow=True)
        # Chips of its own stone, knocked off by the landing.
        for x, y in ((sx - 10, 112), (sx + 14, 110), (sx + 20, 113), (hx - 8, 111), (sx + 6, 106)):
            f.px(x, y, STONE[5])
            f.px(x + 1, y, STONE[3])
    f.glow(sx + 2, sy + 2, 10 + heat * 4, EMBER["mid"], 0.04 + heat * 0.12 + k["open"] * 0.3)
    f.glow(ax + 5, ay + 2, 6, EMBER["mid"], 0.4)
    f.glow(hx, hy + 1, 6, TAG["mid"], 0.25)
    f.finish(rim=RIM, rim_strength=(0.42, 0.3))
    if k["open"]:
        seal(f, sx + 3, sy + 4, 1.1)
    if name == "crouch":
        # Grit shaken loose as it gathers.
        for x, y in ((sx - 2, sy - 16), (sx + 6, sy - 13), (hx - 2, hy - 14)):
            f.px(x, y, STONE[5])
    return f.image


# --- Raya de lluvia (picado) -------------------------------------------------------------------
SKIN = ramp("#06070d", "#0b0f1c", "#111829", "#18223a", "#212f4c", "#2c3f60", "#3b5476", "#4f6b8c")
CHROMEB = ramp("#0b0b10", "#1a1b24", "#30323f", "#4f5366", "#7f849b", "#c3c8da")


def raya(pose=None):
    """A ray from the drowned bay that learned to swim in the rain. Modelled in 3D and seen
    through the game's 38-degree camera, three-quarters toward the viewer. Someone branded a
    stolen seal into its back and bolted a chrome rig along its spine; its spots glow like the
    bay's plankton, and every one of them turns rose when it picks its line."""
    import solid
    pose = pose or {}
    fold = pose.get("fold", 0.0)
    flap = pose.get("flap", 0.45)
    curl = pose.get("curl", 0.0)
    lock = pose.get("lock", 0.0)
    pitch = pose.get("pitch", 0.0)
    yaw = pose.get("yaw", -1.15)
    grounded = pose.get("grounded", False)
    origin = pose.get("origin", (70, 104 if grounded else 62))
    cam = solid.Camera(origin=origin)
    r = solid.Raster(cam)
    lift = 6.5 if grounded else 0.0

    def place(p):
        sc = pose.get("scale", 1.7)
        p = (p[0] * sc, p[1] * sc, p[2] * sc)
        p = solid.rot_z(p, -pitch)
        p = solid.rot_y(p, yaw)
        return (p[0], p[1] + lift, p[2])

    span = 27 * (1 - 0.5 * fold)

    def wing(u, v):
        s_ = u * 2 - 1
        a = abs(s_)
        # A crescent: the leading edge holds forward then sweeps back to a hooked tip.
        x_le = 15 - 27 * a ** 2.2 - fold * 10 * a
        x_te = -11 + 12 * a ** 0.8 - 13 * a ** 4 - fold * 8 * a
        x = x_te + (x_le - x_te) * v
        y = 6.2 * (1 - a) ** 2.4 * math.sin(math.pi * v) ** 0.7 + 1.0 * math.sin(math.pi * v) * (1 - a)
        y += flap * a * a * 12 + curl * max(0.0, a - 0.5) ** 2 * 34
        if grounded:
            y = max(-lift, y - a * a * 6)
        return place((x, y, s_ * span))
    r.grid(wing, 36, 14, "skin")

    # Tail: a long whip trailing behind, a chrome barb at the end.
    tail = []
    for n in range(10):
        t = n / 9
        sway = 0 if fold > 0.5 or grounded else math.sin(t * 4 + curl * 2) * 3 * t
        tail.append(place((-10 - t * 36, 0.6 - (lift if grounded else 0) * t * 0.9, sway)))
    r.tube(tail, [1.5 - 1.0 * n / 9 for n in range(10)], "skin_dark", sides=6)
    end = tail[-1]
    back = tail[-2]
    tip = tuple(end[i] + (end[i] - back[i]) * 1.5 for i in range(3))
    r.tube([end, tip], [1.0, 0.2], "chrome", sides=5)

    # Cephalic fins curled forward like horns.
    for side in (-1, 1):
        lobe = [place((12, 1.6, side * 3.6)), place((17, 2.6 + curl, side * 4.6)), place((20, 2.0 + curl, side * 3.0))]
        r.tube(lobe, [1.4, 1.0, 0.5], "fin", sides=6)
    # The chrome rig bolted down the spine.
    for n in range(5):
        x = -6 + n * 4
        r.ball(place((x, 6.6 if x < 8 else 5.6, 0)), 1.5, "chrome", stretch=(1.3, 0.6, 1))

    px = r.pixels()
    f = Figure()
    L = solid.norm(cam.view(solid.norm((-0.45, 0.8, 0.45))))
    spot_color = ROSE if lock else AQUA
    for (x, y), (part_, n, uv) in px.items():
        diffuse = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
        if part_ == "chrome":
            v = 0.1 + 0.75 * diffuse + (0.35 if diffuse > 0.9 else 0)
            f.px(x, y, CHROMEB[int(round(min(1, v) * (len(CHROMEB) - 1)))])
            continue
        lift_ = {"skin": 0.0, "skin_dark": -0.08, "fin": 0.08}[part_]
        v = 0.1 + 0.8 * diffuse + lift_
        color = SKIN[int(round(max(0, min(1, v)) * (len(SKIN) - 1)))]
        if part_ == "skin":
            su, cv = uv[0] * 2 - 1, uv[1]
            a = abs(su)
            # The thin outer margin is translucent: it takes the light.
            if a > 0.9 or cv < 0.07:
                color = SKIN[min(len(SKIN) - 1, SKIN.index(color) + 2)]
            # Faint ribs fanning out across the wing.
            elif (a * 9) % 1 < 0.1 and cv < 0.8:
                color = SKIN[max(0, SKIN.index(color) - 1)]
            # Plankton spots in two staggered rows; a dark ring around each.
            for vc, offset in ((0.36, 0.0), (0.62, 0.09)):
                ac = round((a - 0.22 - offset) / 0.2) * 0.2 + 0.22 + offset
                if not 0.2 < ac < 0.86:
                    continue
                d = math.hypot((a - ac) / 0.055, (cv - vc) / 0.085)
                if d < 1.0 and (not grounded or int(ac * 10 + vc * 10) % 2):
                    color = spot_color["hi"] if d < 0.45 else spot_color["mid"]
                    break
                if d < 1.6:
                    color = SKIN[0]
            if color in (spot_color["hi"], spot_color["mid"]):
                f.px(x, y, color, glow=True)
                continue
        f.px(x, y, color)
    f.finish(rim=RIM, rim_strength=(0.42, 0.3))
    brand = cam.project(place((1, 7.0, 0)))
    seal(f, brand[0], brand[1], 1.0, 1.0 if not grounded else 0.3)
    for side in (-1, 1):
        eye = cam.project(place((12, 3.4, side * 5.0)))
        f.px(eye[0], eye[1], ROSE["hi"] if not grounded else ROSE["dim"], glow=True)
    if pitch > 0.3:
        # Speed streaks trailing back the way it came, along its own spine.
        c = cam.project(place((0, 0, 0)))
        b = cam.project(place((-10, 0, 0)))
        dx, dy = b[0] - c[0], b[1] - c[1]
        n = math.hypot(dx, dy) or 1.0
        dx, dy = dx / n, dy / n
        for off, start, length in ((-24, 6, 10), (-13, 14, 14), (13, 14, 12), (24, 6, 9), (0, 30, 8)):
            x0, y0 = c[0] - dy * off + dx * start, c[1] + dx * off + dy * start
            trace(f, [(x0, y0), (x0 + dx * length, y0 + dy * length)], hexc("#9fc6d8") if length > 11 else hexc("#3f5a80"), None)
    elif grounded:
        for x in range(origin[0] - 44, origin[0] + 34):
            if (x * 5) % 7 < 3:
                f.px(x, origin[1], AQUA["dim"])
    return f.image


# --- La Llorona (absorbedora) ------------------------------------------------------------------
DRESS = ramp("#040509", "#07080e", "#0b0d15", "#11141f", "#191d2b")
PALE = ramp("#262b36", "#3f4656", "#616a7d", "#8d96a8", "#bcc3cf", "#dfe3ea")
HAIR = ramp("#020203", "#05060a", "#0a0c12", "#12151d", "#1d2130", "#2c3246")
TAPE = (196, 204, 214, 255)
DEEP = (10, 52, 92, 255)
WAIST = (65.0, 72.0)


def llorona(pose=None):
    """A drowned woman's ghost in a clear raincoat with reflective tape. Wet black hair hangs out
    of the hood over a face that is only the seal burning behind it; bare feet hang under the hem,
    never touching the street. She drinks the crew's puddles through her hair -- the water climbs
    the strands and fills the raincoat from the hem up -- then lurches forward and wails it back."""
    pose = pose or {}
    name = pose.get("pose", "wander")
    charge = pose.get("charge", 0)
    lean = {"wander": 0.08, "drink": 0.82, "full": 0.0, "aim": -0.24, "wail": 0.32}[name]
    swell = 0.0

    def at(x, y):
        """Bend the upper body forward about the waist; let the skirt belly out with water."""
        dx, dy = x - WAIST[0], y - WAIST[1]
        if dy < 0:
            t = lean * min(1.0, -dy / 9.0)
            c, s_ = math.cos(t), math.sin(t)
            return (WAIST[0] + dx * c - dy * s_, WAIST[1] + dx * s_ + dy * c)
        return (WAIST[0] + dx * (1 + swell * dy / 28.0), y + swell * dy * 0.12)

    def pts(seq):
        return [at(x, y) for x, y in seq]

    f = Figure(light=(-0.55, 0.4, 0.72))
    head = at(73, 43)

    # Far arm, mostly hidden: a pale hand out of the back of the coat.
    far = Shape().limb(at(61, 58), at(59, 74), 1.6, 1.4).limb(at(59, 74), at(58, 87), 1.4, 1.1).pixels()
    f.paint(far, PALE[:4], axis="h", lift=-0.15)

    # The dress and the body inside it: thin, dark, barely there.
    body = Shape().poly(pts([(59, 72), (72, 72), (76, 99), (56, 99)])).limb(at(65, 72), at(67, 57), 5.0, 5.8)
    body = body.limb(at(67, 57), at(71, 50), 3.4, 2.0).pixels()
    f.paint(body, DRESS, axis="h", lift=0.06)
    # Bare feet hanging toes-down.
    for knee, toe in (((62, 98), (61, 107)), ((69, 98), (70, 109))):
        k = at(*knee)
        leg = Shape().limb(k, (toe[0], toe[1] - 4), 1.7, 1.2).limb((toe[0], toe[1] - 4), toe, 1.4, 0.9).pixels()
        f.paint(leg, PALE, axis="h", lift=-0.1 if knee[0] < 65 else 0.0)

    # Raincoat: hood, slumped shoulders, cinched waist, flared ragged hem; open down the front.
    coat_outline = pts([(67, 31), (74, 31), (79, 35), (82, 42), (81, 50), (77, 55), (74, 62), (72, 72),
                        (77, 86), (81, 100), (77, 102), (73, 99), (69, 103), (64, 99), (59, 103), (54, 99), (50, 101),
                        (52, 90), (56, 79), (57, 72), (55, 63), (56, 54), (59, 46), (62, 36)])
    coat = part(coat_outline)
    gap = part(pts([(74, 62), (72, 72), (77, 86), (81, 100), (75, 100), (70, 84), (70, 66)]))  # open front
    cavity = Shape().ellipse(head[0] + 2.5, head[1] + 1, 4.0, 6.5).pixels()
    coat -= cavity
    shell = coat - gap

    ys = sorted({y for _, y in coat})
    hem = max(ys)
    level = None
    clear = set()
    for x, y in sorted(coat):
        under = f.get(x, y)
        base = under if under[3] else (16, 19, 28, 255)
        if not under[3] and (x, y) in shell and (level is None or y < level):
            clear.add((x, y))
        if level is not None and y >= level and (x, y) in shell:
            depth = min(1.0, (y - level) / 22.0)
            water = mix(AQUA["mid"], DEEP, depth)
            f.px(x, y, mix(base, water, 0.62 if under[3] else 0.82))
        elif (x, y) in shell:
            f.px(x, y, mix(base, (170, 192, 214, 255), 0.13 if under[3] else 0.1))
    if level is not None:
        # The waterline, slopping against the plastic, and bubbles rising through it.
        for x, y in sorted(shell):
            if level <= y < level + 1 or (level <= y < level + 2 and (x * 5) % 7 == 0):
                f.px(x, y, AQUA["hi"] if (x + y) % 3 else AQUA["core"], glow=True)
        for n in range(3 + charge * 2):
            bx = WAIST[0] - 7 + (n * 37) % 16
            by = level + 4 + (n * 23) % max(4, int(hem - level - 6))
            if (int(bx), int(by)) in shell:
                f.px(bx, by, AQUA["hi"], glow=True)
        f.glow(WAIST[0] + 1, (level + hem) / 2, 15, AQUA["mid"], 0.12 + 0.05 * charge)
    # Glossy creases down the plastic.
    for gx, top, bottom in ((58.5, 74, 98), (62, 80, 100), (64, 50, 66)):
        for y in range(top, bottom):
            q = at(gx + (y - top) * 0.1, y)
            if (int(q[0]), int(q[1])) in shell and y % 5 != 4:
                f.px(q[0], q[1], mix(f.get(int(q[0]), int(q[1])), (225, 236, 248, 255), 0.3))
    # Reflective tape: around the hem, and the hood's face opening.
    for x, y in shell:
        if y >= hem - 2 and (x, y + 3) not in coat and (x, y + 1) not in coat or (x, y + 2) not in coat and y > hem - 6:
            f.px(x, y, TAPE if (x // 2) % 2 else mix(TAPE, (0, 0, 0, 255), 0.25))
    for x, y in cavity:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) in shell:
                f.px(x + dx, y + dy, mix(TAPE, AQUA["hi"], 0.2))
    f.fill(cavity, (4, 4, 7, 255))

    # Near arm: a clear sleeve to the elbow, then a long pale forearm and long fingers.
    hand = {"wander": (77, 90), "drink": None, "full": (79, 88), "aim": (75, 88), "wail": (60, 93)}[name]
    shoulder = at(70, 57)
    if name == "drink":
        elbow, hand = (shoulder[0] + 5, shoulder[1] + 12), (shoulder[0] + 8, 110)
    elif name == "wail":
        elbow, hand = (shoulder[0] - 6, shoulder[1] + 14), (shoulder[0] - 12, shoulder[1] + 28)
    else:
        elbow = (shoulder[0] + 3, shoulder[1] + 16)
    umbrella = pose.get("umbrella") and name != "drink"
    if umbrella:
        elbow, hand = (shoulder[0] + 8, shoulder[1] + 7), (shoulder[0] + 14, shoulder[1] + 1)
    sleeve = Shape().limb(shoulder, elbow, 3.2, 2.8).pixels()
    cuff = (elbow[0] + (hand[0] - elbow[0]) * 0.18, elbow[1] + (hand[1] - elbow[1]) * 0.18)
    arm = Shape().limb(elbow, hand, 1.5, 1.2).pixels()
    f.paint(arm, PALE, axis="h", lift=0.05)
    for x, y in sleeve:
        under = f.get(x, y)
        f.px(x, y, mix(under if under[3] else (16, 19, 28, 255), (170, 192, 214, 255), 0.22))
    f.paint(Shape().ellipse(cuff[0], cuff[1], 2.4, 1.0).pixels(), [mix(TAPE, (0, 0, 0, 255), 0.4), TAPE], axis="h")
    for n in (-1, 0, 1):
        trace(f, [hand, (hand[0] + n * 1.2 + 0.6, hand[1] + 5)], PALE[3], None, glow=False)

    # Hair: out of the hood, straight down over the face and chest; into the puddle when she
    # drinks; thrown back when she wails.
    strands = []
    for n in range(8):
        root = (head[0] + n * 0.8, head[1] - 4 + abs(n - 4) * 0.5)
        if name == "drink":
            tip = (root[0] + 1.5, 113 - abs(n - 4) * 0.4)
        elif name == "wail":
            tip = (root[0] - 24 - n * 1.5, root[1] + 3 + n * 1.6)
        else:
            tip = (root[0] - 7 - n * 0.9, root[1] + 20 + (n % 3) * 2) if name == "aim" else (root[0] + 0.6 + n * 0.3, root[1] + 22 + (n % 3) * 3)
        mid = ((root[0] + tip[0]) / 2 + (n - 4) * 0.25 + (2.0 if name == "wail" else 0), (root[1] + tip[1]) / 2 + (-3 if name == "wail" else 0))
        strands.append((root, mid, tip))
        trace(f, [root, mid, tip], HAIR[1 + n % 4], None, glow=False)
    f.paint(Shape().ellipse(head[0] + 1, head[1] - 3.5, 5.0, 3.6).pixels(), HAIR, axis="h", gloss=0.6, lift=0.1)
    if name in ("wail", "aim"):
        # Face bared: a pale drowned jaw hanging open, the water coming out of it.
        face = Shape().ellipse(head[0] + 3, head[1] + 2.5, 3.0, 5.0).pixels()
        f.paint(face, PALE, axis="h", lift=-0.05)
        f.fill(Shape().ellipse(head[0] + 4.2, head[1] + 4.5, 1.8, 2.6).pixels(), (3, 6, 12, 255))
    if name == "drink":
        for root, mid, tip in strands[1:7]:
            for t in (0.45, 0.6, 0.72, 0.84, 0.95):
                x = mid[0] + (tip[0] - mid[0]) * t
                y = mid[1] + (tip[1] - mid[1]) * t
                f.px(x, y, AQUA["hi"] if t > 0.8 else AQUA["mid"], glow=t > 0.6)
    canopy = set()
    if umbrella:
        # A street umbrella with a light-tube shaft, one rib snapped; it never stops raining on her.
        tilt = 0.18 + (0.35 if name == "wail" else 0.0)
        top = (hand[0] - 2 - (6 if name == "wail" else 0), hand[1] - 38 * math.cos(tilt))
        cx, cy = top[0] + 1, top[1] + 6
        dome = {(x, y) for x, y in Shape().ellipse(cx, cy + 3, 24, 13).pixels() if y <= cy + 1}
        canopy = dome | Shape().ellipse(cx, cy + 1, 24, 3.2).pixels()
        canopy -= part([(cx - 25, cy + 5), (cx - 16, cy - 1), (cx - 12, cy + 5)])  # the torn panel
        for x, y in canopy:
            under = f.get(x, y)
            f.px(x, y, mix(under if under[3] else (40, 52, 70, 255), (190, 214, 236, 255), 0.3 - 0.12 * (cy + 1 - y) / 12))
        for k in (-3, -2, -1, 0, 1, 2, 3):
            rim_pt = (cx + k * 7.6, cy + 1 + (1 - abs(k) / 3) * 2.6)
            trace(f, [(top[0], top[1] + 1), rim_pt], (64, 74, 92, 255), None, glow=False)
        trace(f, [(cx - 16, cy - 1), (cx - 21, cy + 9), (cx - 22, cy + 13)], (64, 74, 92, 255), None, glow=False)
        for t in range(0, 41):
            q = (hand[0] + (top[0] - hand[0]) * t / 40, hand[1] + 3 + (top[1] - hand[1] - 3) * t / 40)
            f.px(q[0], q[1], AQUA["core"] if t % 4 else AQUA["hi"], glow=True)
        f.paint(Shape().limb((hand[0], hand[1] + 3), (hand[0] + 0.5, hand[1] + 7), 1.0, 1.0).pixels(), PALE[:3], axis="h")
        f.glow(cx, cy + 4, 20, AQUA["mid"], 0.22)
    if charge and name != "drink":
        # Carrying water: a few bright drops gathering at the ends of her hair.
        for root, mid, tip in strands[1::2]:
            f.px(tip[0], tip[1] + 1, AQUA["hi"], glow=True)
            f.px(tip[0], tip[1] + 3, AQUA["mid"], glow=True)
    f.glow(head[0] + 3, head[1], 8 if name != "aim" else 11, ROSE["mid"], 0.35 if name != "aim" else 0.6)
    f.finish(rim=RIM, rim_strength=(0.45, 0.32))
    for x, y in canopy:
        if all((x + dx, y + dy) in canopy for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and (x, y) not in f.emissive:
            c = f.get(x, y)
            f.px(x, y, c[:3] + (120,))
    # Where the plastic covers nothing, the street shows through it.
    for x, y in clear:
        c = f.get(x, y)
        inner = all((x + dx, y + dy) in shell for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)))
        if inner and (x, y) not in f.emissive:
            f.px(x, y, mix(c, (150, 175, 200, 255), 0.25)[:3] + (105,))

    # The seal is her face, burning through the hair.
    seal(f, head[0] + 3.4, head[1] - 0.6, 0.85)
    if name == "wail":
        jaw = (head[0] + 5.5, head[1] + 4.5)
        # The jet: a widening cone of water out of the open jaw, to the edge of the sprite.
        for n in range(0, int(127 - jaw[0])):
            half = 0.8 + n * 0.16
            for k in range(-int(half), int(half) + 1):
                edge = abs(k) / max(half, 1)
                c = AQUA["core"] if edge < 0.25 and n < 26 else AQUA["hi"] if edge < 0.55 else AQUA["mid"]
                if edge > 0.8 and (n + k) % 3 == 0:
                    continue
                f.px(jaw[0] + n, jaw[1] + k + n * 0.08, c, glow=True)
        for n in range(9):
            f.px(jaw[0] + 8 + (n * 13) % 30, jaw[1] + (-1) ** n * (4 + (n * 7) % 5), AQUA["hi"], glow=True)
    # Drips off the hem and the fingers, rings where they land.
    for n, x in enumerate(range(int(at(52, 100)[0]), int(at(80, 100)[0]), 5)):
        f.px(x, hem + 3 + n % 3 * 2, (122, 168, 196, 255))
    for x in range(int(WAIST[0] - 14), int(WAIST[0] + 16)):
        if abs(x - WAIST[0] - 1) in (13, 14) or abs(x - WAIST[0] - 1) in (7,) or (x + 1) % 6 == 0 and abs(x - WAIST[0]) < 13:
            f.px(x, 118, (40, 70, 92, 255))
    if name == "drink":
        for x in range(int(strands[4][2][0]) - 11, int(strands[4][2][0]) + 11):
            for y in (114, 115):
                if abs(x - strands[4][2][0]) < (10 if y == 115 else 6):
                    f.px(x, y, AQUA["mid"] if (x * 7 + y) % 4 == 0 else AQUA["dim"], glow=y == 114 and x % 3 == 0)
    return f.image


GOWN = ramp("#090c13", "#10141e", "#181e2b", "#222a39", "#2e3849", "#3e4a5e", "#56647b", "#7b889e", "#a6b1c3")
VEIL = (150, 200, 230)
COLDSKIN = ramp("#161c28", "#24303f", "#3a4b5c", "#5a7182", "#86a0ad", "#b6c9d0")
DEADFACE = ramp("#2a3342", "#46546a", "#6b7d92", "#98aabb", "#c6d4de", "#e8f0f3")


def novia(pose=None):
    """A bride who went into the canal on her wedding night. Built like the crew: a dark soaked
    gown that only turns white where the light finds it, LED piping on the neckline, waist and hem,
    wet black hair over the face and the seal burning through it for an eye. Her veil is a cheap
    LED mesh: dead while she is dry, and it lights from the hem up with every puddle she drinks."""
    pose = pose or {}
    name = pose.get("pose", "wander")
    charge = pose.get("charge", 0)
    frame = pose.get("frame", 0)
    lean = {"wander": 0.06, "drink": 0.62, "aim": -0.24, "wail": 0.32}[name]
    waist = (66.0, 74.0)

    def at(x, y):
        dx, dy = x - waist[0], y - waist[1]
        if dy < 0:
            t = lean * min(1.0, -dy / 9.0)
            c, s_ = math.cos(t), math.sin(t)
            return (waist[0] + dx * c - dy * s_, waist[1] + dx * s_ + dy * c)
        return (x, y)

    def pts(seq):
        return [at(x, y) for x, y in seq]

    f = Figure(light=(-0.5, 0.35, 0.78))
    hx, hy = at(70, 47)
    tilt = lean

    def hd(dx, dy):
        """A point on the head, in the head's own frame (facing right), turned with the lean."""
        c, s_ = math.cos(tilt), math.sin(tilt)
        return (hx + dx * c - dy * s_, hy + dx * s_ + dy * c)
    wind = {"wander": 0.0, "drink": -0.3, "aim": 0.0, "wail": 0.35}[name]

    # Veil, behind everything: from a band at the crown down to the hip.
    cx, cy = at(66, 42)
    veil = part([(cx + 3, cy - 1), (cx - 4, cy), (cx - 9 - wind * 7, cy + 10 - wind * 5), (cx - 13 - wind * 12, cy + 25 - wind * 9),
                 (cx - 14 - wind * 15, cy + 40 - wind * 12), (cx - 10 - wind * 13, cy + 37 - wind * 12), (cx - 7 - wind * 12, cy + 44 - wind * 12),
                 (cx - 4 - wind * 9, cy + 38 - wind * 10), (cx - 1 - wind * 6, cy + 24 - wind * 5), (cx + 2, cy + 10)])
    f.fill(veil, (12, 15, 22, 255))

    # Far arm and the hair down her back.
    far = Shape().limb(at(62, 58), at(60, 70), 1.6, 1.4).limb(at(60, 70), at(60, 82), 1.4, 1.1).pixels()
    f.paint(far, COLDSKIN[:4], axis="h", lift=-0.1)

    # Gown: an underskirt to below the knee, a torn overskirt trailing back, a laced bodice.
    skirt = part([(61, 74), (71, 74), (75, 86), (79, 100), (80, 108), (76, 105), (72, 109), (68, 105), (64, 109), (60, 105), (56, 108),
                  (52, 104), (54, 92), (57, 82)])
    f.paint(skirt, GOWN, axis="h", lift=0.08, fall=0.2, gloss=0.25)
    over = part([(61, 75), (66, 75), (63, 90), (56, 103), (50, 107), (51, 97), (56, 84)])
    f.paint(over, GOWN, axis="h", lift=0.1, fall=0.1)
    for fx, top, bottom in ((60, 78, 104), (65, 77, 106), (70, 77, 104), (74, 84, 104), (57, 86, 104)):
        trace(f, [(fx, top), (fx + (fx - 66) * 0.25, bottom)], GOWN[1], skirt | over, glow=False)
    trace(f, [(62, 76), (57, 92), (52, 104)], GOWN[6], over, glow=False)
    bodice = part(pts([(62, 56), (73, 56), (74, 61), (72, 67), (71, 74), (61, 74), (60, 66)]))
    f.paint(bodice, GOWN, axis="h", lift=0.04, gloss=0.3)
    for y in range(59, 73, 3):
        trace(f, [at(61, y), at(63, y + 2)], GOWN[1], bodice, glow=False)
        trace(f, [at(63, y), at(61, y + 2)], GOWN[1], bodice, glow=False)
    gown = skirt | over | bodice
    # Piping: neckline, waist seam, hem -- the same one-pixel light the crew wears.
    trace(f, pts([(62, 57), (66, 58.6), (70, 57.6), (73.4, 57)]), AQUA["mid"], bodice)
    trace(f, pts([(61.5, 73), (71, 73)]), AQUA["dim"], bodice, glow=False)
    f.px(*at(66, 73), AQUA["hi"], glow=True)
    hem = max(y for _, y in gown)
    for x, y in gown:
        if (x, y + 1) not in gown and y > 100:
            f.px(x, y, AQUA["mid"] if x % 5 else AQUA["hi"], glow=x % 3 != 0)

    # Bare shoulders and neck, drowned-cold.
    f.paint(Shape().limb(at(62, 57), at(72.5, 56.4), 2.0, 2.0).pixels() - bodice | Shape().limb(at(69.5, 56), (hx - 0.5, hy + 3), 1.7, 1.5).pixels(),
            COLDSKIN, axis="h", lift=0.05)
    f.paint(Shape().ellipse(hx + 0.5, hy, 4.2, 5.0).pixels(), COLDSKIN, axis="h", lift=-0.15)

    # Near arm: long and bare; the hand still holds the bouquet -- fibre-optic flowers, dead.
    shoulder = at(71.5, 58)
    if name == "drink":
        elbow, hand = (shoulder[0] + 5, shoulder[1] + 12), (shoulder[0] + 8, 110)
    elif name == "wail":
        elbow, hand = (shoulder[0] - 6, shoulder[1] + 13), (shoulder[0] - 11, shoulder[1] + 25)
    else:
        elbow, hand = (shoulder[0] + 2.5, shoulder[1] + 13), (shoulder[0] + 4.5, shoulder[1] + 26)
    f.paint(Shape().limb(shoulder, elbow, 1.8, 1.5).limb(elbow, hand, 1.5, 1.3).pixels(), COLDSKIN, axis="h", lift=0.1)
    f.paint(Shape().ellipse(hand[0], hand[1] + 1, 1.7, 1.9).pixels(), COLDSKIN, axis="h", lift=0.2)
    if name != "drink":
        for k, (dx, dy) in enumerate(((-2, 7), (0, 8), (2, 7), (3, 5))):
            tip = (hand[0] + dx, hand[1] + 2 + dy)
            trace(f, [(hand[0], hand[1] + 2), tip], (24, 30, 40, 255), None, glow=False)
            f.px(*tip, AQUA["dim"] if k % 2 else hexc("#3a6a88"))

    # The face, bared: gaunt and drowned-cold, a hollow under the cheekbone, the seal burning in
    # one socket and a thread of canal water running from it like a tear.
    c_, s_ = math.cos(-tilt), math.sin(-tilt)
    skull = Shape().ellipse(*hd(0.6, 0.2), 5.2, 6.2).pixels()

    def local(x, y):
        return ((x - hx) * c_ - (y - hy) * s_, (x - hx) * s_ + (y - hy) * c_)

    # Three-quarters toward the viewer, like the crew: both eyes, the nose on the profile edge.
    jaw_open = {"aim": 1.0, "wail": 2.2}.get(name, 0.0)
    if jaw_open:
        skull |= Shape().ellipse(*hd(2.4, 3.4 + jaw_open * 0.5), 3.2, 2.4 + jaw_open * 0.6).pixels()
    # Lit from the front, by the street and her own seal; it is the palest thing on her.
    f.paint(skull, DEADFACE, axis="h", lift=0.2, light=(0.7, 0.3, 0.65))
    for dx, dy in ((0.2, -1.7), (1.4, -1.7), (3.4, -1.7), (0.0, 1.8), (0.4, 2.6), (3.0, 1.2)):
        f.px(*hd(dx, dy), DEADFACE[1])  # brows, cheek hollow, the shadow beside the nose
    for dx, dy in ((0.2, -0.4), (1.6, -0.4), (3.2, -0.4)):
        f.px(*hd(dx, dy), DEADFACE[0])  # sunken sockets
    f.px(*hd(4.8, 0.8), DEADFACE[5])
    f.px(*hd(4.4, 1.6), DEADFACE[3])
    if jaw_open:
        f.fill(Shape().ellipse(*hd(2.8, 3.8 + jaw_open * 0.6), 1.2 + jaw_open * 0.3, 0.9 + jaw_open * 0.8).pixels(), (4, 6, 12, 255))
    else:
        trace(f, [hd(1.8, 3.8), hd(3.8, 3.6)], (30, 26, 40, 255), None, glow=False)

    # Hair: slick and wet, plastered to the skull, then a few thin heavy ropes down her back --
    # to the puddle when she drinks, only dragged back when she wails.
    cap = {(x, y) for x, y in Shape().ellipse(*hd(-1.0, -1.4), 5.4, 5.6).pixels() if local(x, y)[0] < -1.8 or local(x, y)[1] < -3.6}
    roots = [hd(-4.0, -1.5), hd(-4.4, 1.0), hd(-3.2, 3.0)]
    sway = math.sin(frame * math.pi / 2) * 1.2
    tips = {"wander": [(hx - 5 + sway, hy + 24), (hx - 6.5 + sway * 0.6, hy + 19), (hx - 3.5 + sway, hy + 27)],
            "drink": [(hx + 0.5, 113), (hx + 2, 113), (hx + 3.5, 113)],
            "aim": [(hx - 6, hy + 19), (hx - 8, hy + 15), (hx - 4.5, hy + 22)],
            "wail": [(hx - 14, hy + 8), (hx - 16, hy + 3), (hx - 11, hy + 12)]}[name]
    ropes = set()
    for (rx, ry), (tx, ty) in zip(roots, tips):
        mid = ((rx + tx) / 2 - 1.2, (ry + ty) / 2)
        ropes |= Shape().limb((rx, ry), mid, 1.4, 1.0).limb(mid, (tx, ty), 1.0, 0.6).pixels()
    f.paint(ropes | cap, HAIR, axis="h", lift=0.12, gloss=0.6)
    trace(f, [hd(-4.6, -3.4), hd(-1.4, -5.6), hd(1.8, -5.0)], HAIR[5], cap, glow=False)
    if name == "drink":
        for (tx, ty) in tips[::2]:
            for y in range(int(hy + 10) + (2 - frame % 3), 113, 3):
                f.px(tx + (hx - tx) * (113 - y) / max(1, 113 - hy) * 0.2, y, AQUA["hi"] if y > 100 else AQUA["mid"], glow=y > 94)

    # Whatever is still bare veil now is the part seen behind her.
    veil = {(x, y) for x, y in veil if f.get(x, y) == (12, 15, 22, 255)}
    solid_ = {(x, y) for x in range(128) for y in range(128) if f.get(x, y)[3]}
    f.glow(*hd(1.6, -0.4), 4 if name != "aim" else 7, ROSE["mid"], 0.25 if name != "aim" else 0.45)
    lit = {0: 0.0, 1: 0.35, 2: 0.65, 3: 1.0}[charge]
    if lit:
        f.glow(cx - 6, cy + 30, 16, AQUA["mid"], 0.2 * lit)
    f.finish(rim=RIM, rim_strength=(0.5, 0.36))

    # Veil after the outline: see-through, a crisp LED edge, the mesh lit from the hem up by
    # how much water she carries.
    vys = [y for _, y in veil]
    vtop, vbottom = min(vys), max(vys)
    line = vbottom - (vbottom - vtop) * lit
    for x, y in veil:
        here = f.get(x, y)
        edge = not all((x + dx, y + dy) in solid_ for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        node = x % 3 == 0 and y % 3 == 0
        if edge:
            f.px(x, y, AQUA["mid"] if (x + y) % 5 == 0 else mix(AQUA["dim"], VEIL + (255,), 0.3), glow=(x + y) % 5 == 0)
        elif node and lit and y >= line:
            f.px(x, y, AQUA["core"] if (x * 7 + y) % 5 == 0 else AQUA["hi"], glow=True)
        elif node and (x * 5 + y * 3 + frame * 11) % 29 == 0:
            f.px(x, y, AQUA["hi"], glow=True)  # the odd LED still flickering on a dry veil
        else:
            f.px(x, y, mix(here, VEIL + (255,), 0.34 + (0.14 if lit and y >= line else 0))[:3] + (115,))
    # The band at the crown.
    for k in range(7):
        f.px(cx - 2 + k, cy - 1 - (k % 2), AQUA["core"] if k % 3 else AQUA["hi"], glow=True)

    # The seal sits in her eye socket: at this size, a burning point rather than the full ring.
    eye = hd(0.9, -0.4)
    f.px(*eye, ROSE["core"], glow=True)
    f.px(*hd(1.6, -0.4), ROSE["hi"], glow=True)
    f.px(*hd(3.8, -0.4), ROSE["mid"], glow=True)
    for k in range(1, 6):
        q = hd(0.9 - k * 0.1, -0.4 + k * 1.0)
        f.px(q[0], q[1], AQUA["mid"] if k < 4 else AQUA["dim"], glow=k < 4)
    if name == "wail":
        jaw = hd(4.0, 3.8 + 2.2 * 0.6)
        # In game the jet is its own effect down the whole lane; the frame keeps only the spit.
        for n in range(0, int(127 - jaw[0]) if pose.get("jet", True) else 7 + frame * 2):
            half = 0.8 + n * 0.16
            for k in range(-int(half), int(half) + 1):
                edge = abs(k) / max(half, 1)
                if edge > 0.8 and (n + k) % 3 == 0:
                    continue
                f.px(jaw[0] + n, jaw[1] + k + n * 0.08, AQUA["core"] if edge < 0.25 and n < 26 else AQUA["hi"] if edge < 0.55 else AQUA["mid"], glow=True)
    # She never touches the street: a few threads of water from the hem, rings below.
    for x in (55, 61, 67, 73, 78):
        for d in range(2 + x % 4):
            f.px(x, hem + 2 + d * 2 + (frame + x) % 2, AQUA["dim"] if d else (110, 150, 180, 255))
    for x in range(52, 82):
        if x % 4 == 0:
            f.px(x, 118, (40, 70, 92, 255))
    if name == "drink":
        for x in range(int(hx) - 9, int(hx) + 13):
            for y in (113, 114):
                if abs(x - hx - 2) < (10 if y == 114 else 6):
                    f.px(x, y, AQUA["mid"] if (x * 7 + y) % 4 == 0 else AQUA["dim"], glow=y == 113 and x % 3 == 0)
    return f.image


POSES = {
    "gargola": [("acecha", {}), ("se agacha", {"pose": "crouch"}), ("salta", {"pose": "air"}), ("cae · abierta", {"pose": "open"})],
    "raya": [("nada en la lluvia", {}), ("elige carril", {"lock": 1.0, "curl": 1.0, "flap": 0.0}),
             ("se lanza", {"fold": 0.6, "pitch": 0.7, "lock": 1.0, "flap": -0.15}), ("varada", {"grounded": True, "flap": 0.0})],
    "llorona": [("vaga", {}), ("bebe", {"pose": "drink", "charge": 1}), ("toma aire", {"pose": "aim", "charge": 3}),
                ("aúlla", {"pose": "wail", "charge": 3})],
    "novia": [("vaga", {}), ("bebe", {"pose": "drink", "charge": 1}), ("toma aire", {"pose": "aim", "charge": 3}),
              ("aúlla", {"pose": "wail", "charge": 3})],
    "paraguas": [("vaga", {"umbrella": True}), ("bebe", {"pose": "drink", "charge": 1, "umbrella": True}),
                 ("toma aire", {"pose": "aim", "charge": 3, "umbrella": True}), ("aúlla", {"pose": "wail", "charge": 3, "umbrella": True})],
}


def danger(kind, width=128, height=128):
    """The rose ground warnings drawn under a pose: 'ring' ahead, 'lane' forward, 'lane_down'."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    put = layer.load()
    fill = mix(ROSE["mid"], (0, 0, 0), 0.55)[:3] + (150,)
    if kind in ("ring", "ring_full"):
        cx, cy, rx, ry = 97, 116, 11, 3.0
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, min(width, int(cx + rx) + 2)):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if 0.78 < d <= 1.08:
                    put[x, y] = ROSE["mid"]
                elif d <= 0.78 and (kind == "ring_full" or d < 0.25):
                    put[x, y] = fill
    elif kind == "lane":
        for x in range(40, width):
            put[x, 113] = ROSE["mid"] if x % 3 else ROSE["dim"]
            put[x, 117 if 117 < height else height - 1] = ROSE["mid"] if x % 3 else ROSE["dim"]
            for y in (114, 115, 116):
                put[x, y] = fill
    return layer


def sheet(path):
    from PIL import ImageDraw, ImageFont
    from cast import backdrop
    board = backdrop((1600, 1240)).crop((0, 0, 1600, 1150))
    d = ImageDraw.Draw(board)
    face = "/System/Library/Fonts/HelveticaNeue.ttc"
    title = ImageFont.truetype(face, 40, index=1)
    name = ImageFont.truetype(face, 30, index=1)
    tag = ImageFont.truetype(face, 17)
    body = ImageFont.truetype(face, 15)
    small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    rose = (255, 70, 110)
    d.text((40, 26), "LO QUE CAZA EN EL SECTOR 08", font=title, fill=rose)
    d.text((40, 76), "Cualquier cosa puede caer bajo un sello robado: una gárgola de fachada, una raya de la bahía, una novia ahogada en el canal.",
           font=tag, fill=(200, 205, 220))
    d.text((40, 98), "Piedra, carne o máquina, el sello rosa es su ojo y el color de cada aviso que dan.", font=tag, fill=(200, 205, 220))
    d.text((1300, 112), "todas a la misma escala", font=small, fill=(140, 150, 175))

    rows = [
        ("GÁRGOLA", "saltadora · la despertó un sello", (190, 200, 210), gargola, (14, 40, 107, 119), 260, POSES["gargola"],
         ["Una gárgola de fachada, tallada como desagüe: la boca no", "cierra y todavía le chorrea la lluvia. Alguien le grafiteó el muslo.",
          "No vuela con esos muñones: acecha encaramada y salta por", "encima de los muros. Al agacharse, el sello arde por sus grietas.",
          "Cae donde marcó y el pecho se le parte: ahí es blanda.", "Si cae sobre hielo, lo revienta en fragmentos."],
         [None, "ring", "ring_full", None]),
        ("RAYA DE LLUVIA", "nada en la lluvia · ataca en picado", (110, 200, 255), raya, (18, 2, 110, 120), 354, POSES["raya"],
         ["Una raya de la bahía ahogada que aprendió a nadar en la lluvia.", "Le marcaron el sello en el lomo y le atornillaron un riel de cromo.",
          "Mientras nada no hace daño; su sombra marca dónde está.", "Cuando elige su carril, todas sus manchas se vuelven rosa.",
          "Tras el picado queda varada, ahogándose en el aire.", "El vapor la seca y la tumba; las ánimas la alcanzan en vuelo."],
         [None, "lane", "lane", None]),
        ("LA NOVIA DEL CANAL", "absorbedora · se bebe el agua", (130, 210, 255), novia, (28, 28, 128, 121), 290, POSES["novia"],
         ["Se tiró al canal la noche de su boda y el sello la sacó del agua.", "Cara de ahogada, a la vista: el sello le arde en un ojo y llora canal.",
          "Bebe los charcos de la cuadrilla por el pelo mojado. Mientras bebe", "está quieta y abierta. El velo es una malla LED: se enciende",
          "desde abajo con el agua que carga. Llena, toma aire y la aúlla", "en carril. Calentar el charco la escalda; congelarlo la atrapa."],
         [None, None, "lane", "lane"]),
    ]
    scale = 3
    top = 150
    for title_, tagline, accent, draw, crop, height, poses, lines, warns in rows:
        d.line([(40, top - 12), (1560, top - 12)], fill=(40, 46, 70))
        d.text((40, top), title_, font=name, fill=accent)
        d.text((40, top + 38), tagline, font=tag, fill=(200, 205, 220))
        for i, line in enumerate(lines):
            d.text((40, top + 70 + i * 21 + (6 if i > 1 else 0) + (6 if i > 3 else 0)), line, font=body, fill=(176, 184, 204))
        floor = top + height - 14
        for c, ((label, pose), warn) in enumerate(zip(poses, warns)):
            image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            if warn:
                image.alpha_composite(danger(warn))
            if draw is raya and not pose.get("grounded"):
                # Its shadow on the ground, which is how it reads in play.
                shadow = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
                ImageDraw.Draw(shadow).ellipse([46, 113, 86, 118], fill=(0, 0, 0, 130))
                image.alpha_composite(shadow)
            image.alpha_composite(draw(pose))
            cell = image.crop(crop)
            big = cell.resize((cell.width * scale, cell.height * scale), Image.NEAREST)
            x = 474 + c * 280
            board.paste(big, (x, floor - big.height + 6), big)
            d.text((x + 8, floor + 10), label, font=small, fill=(150, 160, 185))
        top += height + 30
    board.save(path)


if __name__ == "__main__":
    if "sheet" in sys.argv:
        sheet(sys.argv[2])
        sys.exit()
    from cast import show
    which = sys.argv[1] if len(sys.argv) > 1 else "gargola"
    draw = {"gargola": gargola, "raya": raya, "llorona": llorona, "novia": novia, "paraguas": llorona}[which]
    show([draw(p) for _, p in POSES[which]], sys.argv[2] if len(sys.argv) > 2 else "/tmp/m.png", scale=4)
