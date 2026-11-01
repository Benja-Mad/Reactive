"""Reactive's two operators, drawn for a rainy neon yard where the matter answers to code.

El Sereno -- the night watchman of Sector 08. A tall shape in a wet trench coat and a watchman's
capelet, hat brim low; under it, one ocular implant and a circuit line down the cheek. His staff
carries a lantern with an ánima inside: rain-light he can send after the machines.

Brasa -- a burner from the foundries. Oversized black bomber, silver hair, a respirator that
glows where it breathes, and a combustion prosthetic for a right arm: plated, vented, hot.
"""
import math
import os
import sys

import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from neon import Figure, Shape, hexc, mix, ramp  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

CYAN = {"dim": hexc("#1d6f80"), "mid": hexc("#36c8e0"), "hi": hexc("#93f3ff"), "core": hexc("#effeff")}
ORANGE = {"dim": hexc("#7c2a12"), "mid": hexc("#ff6a24"), "hi": hexc("#ffad4a"), "core": hexc("#fff0c8")}
MAGENTA = {"dim": hexc("#7a1848"), "mid": hexc("#ff3d8b"), "hi": hexc("#ff9ccb")}
VIOLET = {"dim": hexc("#4b3590"), "mid": hexc("#8d68f0"), "hi": hexc("#c9b4ff")}

# --- El Sereno --------------------------------------------------------------------------------
COAT = ramp("#04060b", "#080c14", "#0c121c", "#111a26", "#172333", "#203044", "#2d4258")
CAPE = ramp("#05070d", "#0a0f18", "#0f1622", "#151f2e", "#1d2a3d", "#283a52", "#38506b")
HAT = ramp("#080c11", "#0f171d", "#172329", "#213239", "#2f454c", "#43626a")
INNER = ramp("#06080c", "#0b0e14", "#12161e", "#1b202b")
BOOT = ramp("#07070b", "#101016", "#1b1b23", "#2b2b36", "#43434f")
SHADE = ramp("#101219", "#181a23", "#22242f", "#30323e")
LITSKIN = ramp("#161c28", "#24303f", "#3a5062", "#5c8292", "#8cbcc6")
STAFF = ramp("#0d0f12", "#1d2127", "#323840", "#4f5964", "#7a8895", "#b1c0cb")
SCARF = ramp("#0b0a16", "#141226", "#1e1a38", "#2b254d", "#3c3466", "#544a86")
PAPER = ramp("#5c6a6c", "#8a9a99", "#b9c7c3", "#dce6e0")


def knee(hip, foot, l1=15.2, l2=15.2):
    """Two-bone leg: where the knee sits for this hip and ankle, bending forward (+x)."""
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    d = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    ux, uy = dx / d, dy / d
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    px, py = -uy, ux
    if px < 0:
        px, py = -px, -py
    return (hip[0] + ux * a + px * h, hip[1] + uy * a + py * h)


FLAT_BOOT = [(-2.6, -1.4), (2.6, -1.4), (3, 4.4), (4.8, 7), (4.8, 9), (-3.4, 9), (-3.2, 3)]
TIP_BOOT = [(-2.4, -1.4), (2.2, -1.2), (2.8, 3.8), (6, 7.8), (5.6, 10), (1.8, 10), (-2.2, 6)]
HEAVY_BOOT = [(-3, -1.5), (3, -1.5), (3.6, 4), (5, 6.6), (5, 9), (-3.8, 9), (-3.8, 3)]


def boot(ankle, outline):
    return Shape().poly([(ankle[0] + dx, ankle[1] + dy) for dx, dy in outline]).pixels()


def soles(f, pixels, colors, mark):
    """Darken the sole's last row and run a light strip just above it, wherever the boot is."""
    if not pixels:
        return
    bottom = max(y for _, y in pixels)
    for x, y in pixels:
        if y == bottom:
            f.px(x, y, colors[0])
        elif y == bottom - 1 and mark(x):
            mark(x)(f, x, y)


def walk_pose(frame, frames=8):
    p = math.tau * frame / frames
    lift_near = 3.6 * max(0.0, -math.sin(p))
    lift_far = 3.6 * max(0.0, math.sin(p))
    return {"near_foot": (61 + 6 * math.cos(p), 115 - lift_near), "far_foot": (67 + 6 * math.cos(p + math.pi), 115 - lift_far),
            "bob": 1 if abs(math.cos(p)) > 0.7 else 0, "swing": -2.4 * math.cos(p), "wind": 1.6 + 0.9 * math.sin(2 * p),
            "spin": frame * 0.25, "walk": True}


def trace(f, points, color, clip=None, glow=True):
    """A neon line through `points`, kept inside `clip` when given."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5))
        for k in range(steps + 1):
            x = int(round(x0 + (x1 - x0) * k / steps))
            y = int(round(y0 + (y1 - y0) * k / steps))
            if clip is None or (x, y) in clip:
                f.px(x, y, color, glow=glow)


def sigil(f, cx, cy, spin=0.0, size=1.0, bright=1.0):
    """The ward the Sereno draws in the air: a tilted ring of light, runes on it, an ánima inside."""
    rx, ry = 6.4 * size, 5.4 * size
    tri = [(cx + math.cos(spin + k * math.tau / 3) * rx * 0.78, cy + math.sin(spin + k * math.tau / 3) * ry * 0.78) for k in range(4)]
    trace(f, tri, MAGENTA["mid"])
    tri = [(cx + math.cos(spin + math.pi + k * math.tau / 3) * rx * 0.78, cy + math.sin(spin + math.pi + k * math.tau / 3) * ry * 0.78) for k in range(4)]
    trace(f, tri, VIOLET["mid"])
    for k in range(64):
        a = k / 64.0 * math.tau
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        rune = (k + int(spin * 10)) % 16 == 0
        color = CYAN["core"] if rune else CYAN["hi"] if k % 2 else CYAN["mid"]
        f.px(x, y, color, glow=True)
    for k in range(4):
        a = spin * 0.6 + k * math.tau / 4 + 0.4
        x, y = cx + math.cos(a) * (rx + 2.4), cy + math.sin(a) * (ry + 1.4) - 1.5
        f.px(x, y, CYAN["mid"], glow=True)
        f.px(x, y - 1, CYAN["dim"], glow=True)
    lift = 0
    for dx, dy, c in ((0, 0, "core"), (1, 0, "hi"), (0, -1, "hi"), (-1, 0, "mid"), (0, 1, "mid"), (1, -1, "mid")):
        f.px(cx + dx, cy + lift + dy, CYAN[c], glow=True)


def sereno(pose=None):
    pose = pose or {}
    b = pose.get("bob", 0)
    wind = pose.get("wind", 0.0)
    f = Figure(light=(-0.5, 0.35, 0.78))

    # The coat's back tail, thrown behind by the wind -- drawn first, behind the legs.
    tail = Shape().poly([(56.4, 76 + b), (63, 79 + b), (64, 103), (56, 104.6), (45 - wind, 108.4 + wind * 0.4),
                         (41 - wind, 106.4 + wind * 0.3), (47.6, 93), (53.6, 82 + b)]).pixels()
    f.paint(tail, COAT, axis="h", lift=-0.06, fall=0.1)
    trace(f, [(53.4, 84 + b), (49, 94), (44 - wind, 105.6 + wind * 0.3)], CYAN["dim"], tail, glow=False)
    trace(f, [(43 - wind, 106.8 + wind * 0.3), (50, 105.8), (56, 103.8), (62, 102.4)], CYAN["mid"], tail)
    f.px(49, 99, MAGENTA["mid"], glow=True) if (49, 99) in tail else None

    # Legs: weight on the near leg, the far one easy and set forward.
    nf = pose.get("near_foot", (59, 115))
    ff = pose.get("far_foot", (72.6, 114))
    nh, fh = (61, 85 + b), (66.4, 85 + b)
    nk, fk = knee(nh, nf), knee(fh, ff)
    near_leg = Shape().limb(nh, nk, 3.1, 2.3).limb(nk, nf, 2.3, 1.8).pixels()
    far_leg = Shape().limb(fh, fk, 2.9, 2.2).limb(fk, ff, 2.2, 1.7).pixels()
    f.paint(far_leg, INNER, axis="h", lift=0.02)
    f.paint(near_leg, INNER, axis="h", lift=0.08)
    near_boot = boot(nf, FLAT_BOOT)
    far_boot = boot(ff, FLAT_BOOT if pose.get("walk") else TIP_BOOT)
    f.paint(far_boot, BOOT, axis="h", gloss=0.25, lift=-0.04)
    f.paint(near_boot, BOOT, axis="h", gloss=0.3)
    for pixels in (far_boot, near_boot):
        soles(f, pixels, BOOT, lambda x: (lambda f, x, y: f.px(x, y, CYAN["dim"])) if x % 4 == 1 else None)

    # Near arm hangs loose; the fingers still carry the last of a spell.
    sw = pose.get("swing", 0.0)
    near_arm = Shape().limb((57.4, 65 + b), (53.6 + sw * 0.5, 74.6 + b), 2.7, 2.6).limb((53.6 + sw * 0.5, 74.6 + b), (52.6 + sw, 83.6 + b), 2.6, 3.2).pixels()
    hand = Shape().ellipse(52.6 + sw, 87.2 + b, 1.9, 2.2).pixels()
    f.paint(hand, SHADE, axis="h", lift=0.3)
    f.px(52 + sw, 89 + b, MAGENTA["hi"], glow=True)
    f.px(53 + sw, 90 + b, MAGENTA["mid"], glow=True)
    f.px(51 + sw, 91 + b, MAGENTA["dim"], glow=True)

    # The coat over the torso, open at the front over a fitted dark top.
    torso = Shape().poly([(55.4, 64.4 + b), (58.8, 60.6 + b), (70.2, 60 + b), (73.4, 62.2 + b), (73.8, 70 + b), (72, 81.4 + b),
                          (56.6, 81.8 + b), (55, 72 + b)]).pixels()
    f.paint(torso, COAT, axis="h", lift=0.04)
    top = Shape().poly([(67, 61.6 + b), (71.6, 62 + b), (71.2, 81.4 + b), (67.6, 81.4 + b)]).pixels() & torso
    f.paint(top, INNER, axis="h", lift=0.06)
    trace(f, [(69.4, 66 + b), (69.4, 70 + b), (68.4, 72 + b), (69.4, 74 + b)], CYAN["mid"], top)
    f.px(69, 70 + b, CYAN["core"], glow=True)
    # Circuit-work across the chest, the way the wards are stitched into the cloth.
    trace(f, [(58, 64 + b), (61, 67.6 + b), (61, 73 + b), (64.6, 76.6 + b), (66, 76.6 + b)], CYAN["mid"], torso)
    trace(f, [(63, 62 + b), (64.6, 64.4 + b), (64.6, 69 + b)], CYAN["dim"], torso, glow=False)
    f.px(64, 69 + b, MAGENTA["mid"], glow=True)
    for y in range(62, 81):
        f.px(66, y + b, COAT[5]) if (66, y + b) in torso else None
    # A sash knotted at the waist; its ends fly with the coat.
    sash = Shape().poly([(56.4, 78.6 + b), (72.2, 78.4 + b), (72, 81.6 + b), (56.6, 82 + b)]).pixels()
    f.paint(sash, SCARF, axis="h", lift=0.12)
    ends = Shape().poly([(57.4, 80.6 + b), (59.6, 81 + b), (55.6, 89 + b), (51.6 - wind, 94 + wind * 0.5), (50.8 - wind, 92 + wind * 0.5)]).pixels()
    f.paint(ends, SCARF, axis="h", lift=0.06)
    f.px(51 - int(wind), 93 + b + int(wind * 0.5), MAGENTA["mid"], glow=True)

    # Front flap of the coat, in front of the far leg.
    flap = Shape().poly([(68.4, 80 + b), (72.4, 80 + b), (73.6, 91), (76.6, 103.4), (71.2, 104.2), (68.8, 93)]).pixels()
    f.paint(flap, COAT, axis="h", lift=0.06)
    trace(f, [(72.6, 81 + b), (73.8, 91.4), (76, 102.6)], CYAN["mid"], flap)
    trace(f, [(71.6, 103.6), (75.6, 103)], CYAN["hi"], flap)

    f.paint(near_arm, COAT, axis="h", lift=0.1)
    cuff = Shape().ellipse(52.6 + sw, 83.6 + b, 3.0, 1.6).pixels() & near_arm
    for x, y in cuff:
        f.px(x, y, CYAN["mid"] if y == max(yy for _, yy in cuff) else COAT[4], glow=y == max(yy for _, yy in cuff))
    trace(f, [(55.6, 66 + b), (52.4, 74 + b)], MAGENTA["dim"], near_arm, glow=False)

    # Casting arm: elbow low, palm up, the ward turning over it.
    reach = pose.get("reach", 0.0)
    elbow = (75.4 + reach * 3, 73.6 + b - reach * 3)
    wrist = (80.4 + reach * 5, 70.4 + b - reach * 3)
    cast_arm = Shape().limb((71.6, 64 + b), elbow, 2.6, 2.3).limb(elbow, wrist, 2.3, 2.6).pixels()
    f.paint(cast_arm, COAT, axis="v", lift=0.08)
    trace(f, [(elbow[0], elbow[1] + 1.8), (wrist[0] - 0.6, wrist[1] + 2.2)], CYAN["dim"], cast_arm, glow=False)
    palm = Shape().ellipse(wrist[0] + 1.6, wrist[1] - 0.4, 1.8, 1.4).pixels()
    f.paint(palm, SHADE, axis="v", lift=0.35)
    f.px(wrist[0] + 2.8, wrist[1] - 1.6, SHADE[3])

    # Hood: up and deep, a cyan rim around its mouth, the face behind a visor of light.
    hood = Shape().poly([(60.4, 54 + b), (60.8, 49.4 + b), (63.4, 46 + b), (67.6, 45.2 + b), (71.6, 46.4 + b), (74.0, 49 + b),
                         (75.2, 51.4 + b), (73.6, 55.6 + b), (72.0, 60 + b), (62.8, 61.2 + b), (60.2, 58.4 + b)]).pixels()
    f.paint(hood, CAPE, axis="h", lift=0.06)
    opening = Shape().poly([(68.4, 49.6 + b), (74.0, 50.6 + b), (73.6, 55.4 + b), (71.8, 59 + b), (68.4, 59 + b), (67.4, 54 + b)]).pixels() & hood
    f.paint(opening, SHADE, axis="h", lift=-0.25)
    # Lower face caught by the ward's light from below; above it only the visor.
    chin = {(x, y) for x, y in opening if y >= 55 + b and x >= 69}
    f.paint(chin, LITSKIN, axis="h", lift=0.15, light=(0.5, -0.8, 0.4))
    f.px(71, 57 + b, LITSKIN[0])
    f.px(72, 57 + b, LITSKIN[1])
    for x in range(69, 75):
        if (x, 53 + b) in opening:
            f.px(x, 53 + b, CYAN["core"] if x in (72, 73) else CYAN["hi"], glow=True)
    f.px(68, 53 + b, CYAN["mid"], glow=True)
    top_rim = [(x, y) for x, y in opening if (x, y - 1) not in opening and y < 52 + b]
    for x, y in top_rim:
        f.px(x, y - 1, CYAN["dim"]) if (x, y - 1) in hood else None
    # Folds of the hood, and a seam of the ward running over its crown.
    trace(f, [(62.6, 47.6 + b), (64.8, 50 + b), (65.0, 57 + b)], CAPE[1], hood, glow=False)
    trace(f, [(61.4, 52 + b), (61.4, 57 + b)], CAPE[4], hood, glow=False)
    trace(f, [(63.6, 46.6 + b), (68.0, 46 + b), (72.0, 47.6 + b)], CYAN["dim"], hood, glow=False)

    sigil(f, wrist[0] + 2.4, wrist[1] - 6.4 - reach * 2, spin=pose.get("spin", 0.0), size=1.0 + reach * 0.5)
    f.glow(wrist[0] + 2.4, wrist[1] - 6.4, 12, CYAN["mid"], 0.6 + reach * 0.3)
    f.glow(71, 53 + b, 5, CYAN["mid"], 0.45)
    f.glow(52.5 + sw, 89 + b, 5, MAGENTA["mid"], 0.4)
    f.finish(rim=((92, 228, 255), (255, 70, 150)), rim_strength=(0.5, 0.36))
    sigil(f, wrist[0] + 2.4, wrist[1] - 6.4 - reach * 2, spin=pose.get("spin", 0.0), size=1.0 + reach * 0.5)
    return f.image


# --- Brasa ------------------------------------------------------------------------------------
JACKET = ramp("#07070b", "#0d0c12", "#14131b", "#1d1b26", "#282533", "#373244", "#4b4459")
LINING = ramp("#3a0f0c", "#6e1e10", "#b53a16", "#ff6a24")
TOP = ramp("#0a0b0f", "#121319", "#1b1d25", "#262934")
HAIR = ramp("#3f4058", "#5b5d78", "#7f819c", "#a5a7c0", "#cbcde0", "#eff0f8")
SKIN = ramp("#5a3838", "#86554e", "#b07a6b", "#d6a490", "#efc9b5")
MASK = ramp("#0e0f14", "#1a1c24", "#2a2d38", "#3e4250", "#5d6274", "#8a90a3")
PANTS = ramp("#08090d", "#0e1016", "#15181f", "#1e222b", "#2a2f3a", "#3a4050")
CHROME = ramp("#050508", "#0d0d12", "#181922", "#262834", "#3c3f4f", "#5f6377", "#9a9eb3", "#dde0ee")
FUR = ramp("#3e404e", "#6c6f80", "#9b9eae", "#c8cad6", "#ebecf2")
SPOT = ramp("#1e1e26", "#34343f")
STRAP = ramp("#0b0b0e", "#16161b", "#232329", "#34343c")


def brasa(pose=None):
    pose = pose or {}
    b = pose.get("bob", 0)
    heat = pose.get("heat", 0)
    f = Figure(light=(-0.6, 0.35, 0.72))

    # Legs: the near one planted under the hip, the far one set forward. Slim techwear.
    nf = pose.get("near_foot", (58.8, 115))
    ff = pose.get("far_foot", (71.6, 115))
    nh, fh = (61.4, 86 + b), (67, 86 + b)
    nk, fk = knee(nh, nf, 14.8, 14.8), knee(fh, ff, 14.8, 14.8)
    far_leg = Shape().limb(fh, fk, 3.0, 2.3).limb(fk, ff, 2.3, 1.8).pixels()
    f.paint(far_leg, PANTS, axis="h", lift=-0.08)
    near_leg = Shape().limb(nh, nk, 3.3, 2.4).limb(nk, nf, 2.4, 1.9).pixels()
    f.paint(near_leg, PANTS, axis="h")
    seat = Shape().poly([(57.6, 84 + b), (71, 84 + b), (70.6, 90 + b), (66.4, 93.4 + b), (63.4, 93 + b), (58.4, 90 + b)]).pixels()
    f.paint(seat, PANTS, axis="h", lift=0.02)
    for y in range(89, 94):
        f.px(65 if y < 92 else 64, y + b, PANTS[0]) if (65, y + b) in seat else None
    # Knee seams and a strap with a hot buckle on the near thigh.
    for x in range(int(nk[0]) - 3, int(nk[0]) + 4):
        if (x, int(nk[1]) + 1) in near_leg:
            f.px(x, int(nk[1]) + 1, PANTS[1])
    for x in range(58, 65):
        if (x, 92 + b) in near_leg:
            f.px(x, 92 + b, STRAP[2])
            f.px(x, 93 + b, STRAP[0])
    f.px(62, 92 + b, ORANGE["mid"], glow=True)
    for x in range(int(fk[0]) - 3, int(fk[0]) + 4):
        if (x, int(fk[1]) + 2) in far_leg:
            f.px(x, int(fk[1]) + 2, PANTS[1])
    # Cargo pocket on the far thigh.
    pocket = Shape().poly([(fk[0] - 2.6, 92 + b), (fk[0] + 1.2, 92.6 + b), (fk[0] + 1.3, 98), (fk[0] - 2.2, 98)]).pixels() & far_leg
    f.paint(pocket, PANTS, axis="h", lift=0.06)
    # Boots: chunky soles that glow where they meet the ground.
    near_boot = boot(nf, HEAVY_BOOT)
    far_boot = boot(ff, HEAVY_BOOT)
    f.paint(far_boot, STRAP, axis="h", gloss=0.2, lift=-0.04)
    f.paint(near_boot, STRAP, axis="h", gloss=0.25)
    hot_sole = lambda f, x, y: f.px(x, y, ORANGE["mid"] if x % 3 == 0 else ORANGE["dim"], glow=x % 3 == 0)
    for pixels in (far_boot, near_boot):
        soles(f, pixels, STRAP, lambda x: hot_sole)
    for x in range(int(nf[0]) - 2, int(nf[0]) + 5):
        f.px(x, int(nf[1]) + 1, STRAP[3]) if (x, int(nf[1]) + 1) in near_boot else None

    # Cyber arm, far side: plated shoulder, a jointed elbow, and the combustion gauntlet.
    # Hanging at rest; with `aim` it comes up level and the palm opens as a nozzle.
    aim = pose.get("aim", 0.0)
    shoulder = (75, 66 + b)
    sw = pose.get("swing", 0.0) * (1.0 - aim)
    elbow_at = (77.2 + aim * 3.6 + sw * 0.4, 77.4 + b - aim * 6.4)
    wrist = (78 + aim * 12 + sw, 89.6 + b - aim * 18.4)
    upper = Shape().limb(shoulder, elbow_at, 2.7, 2.4).pixels()
    f.paint(upper, CHROME, axis="h" if aim < 0.5 else "v", gloss=0.3, lift=-0.05)
    elbow = Shape().ellipse(elbow_at[0], elbow_at[1], 2.5, 2.2).pixels()
    f.paint(elbow, CHROME, axis="h", gloss=0.3)
    f.px(elbow_at[0], elbow_at[1], ORANGE["hi"], glow=True)
    ax, ay = wrist[0] - elbow_at[0], wrist[1] - elbow_at[1]
    length = math.hypot(ax, ay)
    ux, uy = ax / length, ay / length
    start = (elbow_at[0] + ux * 2.0, elbow_at[1] + uy * 2.0)
    gauntlet = Shape().limb(start, wrist, 3.4, 4.3).pixels()
    f.paint(gauntlet, CHROME, axis="h" if aim < 0.5 else "v", gloss=0.4)
    # Vents across the forearm: they glow brighter as the arm heats.
    for i, t in enumerate((0.3, 0.56, 0.82)):
        hot = ORANGE["core"] if heat > 1 else ORANGE["hi"] if heat or i == 1 else ORANGE["mid"]
        for x, y in gauntlet:
            along = (x + 0.5 - start[0]) * ux + (y + 0.5 - start[1]) * uy
            across = -(x + 0.5 - start[0]) * uy + (y + 0.5 - start[1]) * ux
            if abs(along - t * (length - 2)) < 0.5 and -1.8 < across < 2.6:
                f.px(x, y, hot if across < 1.6 else ORANGE["mid"], glow=True)
            elif abs(along - t * (length - 2) - 1) < 0.5 and -1.8 < across < 2.6:
                f.px(x, y, CHROME[0])
    hx, hy = wrist[0] + ux * 3.2, wrist[1] + uy * 3.2
    hand = Shape().limb((wrist[0] + ux, wrist[1] + uy), (hx, hy), 2.8, 2.2).pixels()
    f.paint(hand, CHROME, axis="h" if aim < 0.5 else "v", gloss=0.2, lift=-0.06)
    for k in (-1, 1):
        for d in (1.6, 2.6, 3.6):
            f.px(wrist[0] + ux * d - uy * k, wrist[1] + uy * d + ux * k, CHROME[0])
    f.px(hx + ux * 1.4, hy + uy * 1.4, ORANGE["core"] if aim else ORANGE["mid"], glow=True)
    if aim:
        f.px(hx + ux * 0.6 - uy, hy + uy * 0.6 + ux, ORANGE["hi"], glow=True)
        f.px(hx + ux * 0.6 + uy, hy + uy * 0.6 - ux, ORANGE["hi"], glow=True)

    # Near arm: the jacket sleeve, hand pushed into the pocket.
    sleeve = Shape().limb((56.4, 66 + b), (53.6, 76 + b), 3.8, 3.4).limb((53.6, 76 + b), (57.6, 82.6 + b), 3.3, 2.8).pixels()

    # The bomber: oversized, cropped at the waist, open over a dark top.
    body = Shape().poly([(55, 61.6 + b), (72.6, 61.6 + b), (76, 65.4 + b), (75, 74 + b), (72.8, 84.6 + b), (57.4, 85 + b),
                         (55.6, 76 + b), (53, 65.6 + b)]).pixels()
    f.paint(body, JACKET, axis="h", fall=0.1, lift=0.04)
    top = Shape().poly([(67.6, 62 + b), (72, 62 + b), (72.4, 84.6 + b), (68.2, 84.6 + b)]).pixels() & body
    f.paint(top, TOP, axis="h")
    # A heat-sink line down the sternum.
    for y in range(66, 75):
        f.px(70, y + b, ORANGE["mid"] if 68 < y < 73 else ORANGE["dim"], glow=68 < y < 73)
    f.px(70, 70 + b, ORANGE["core"], glow=True)
    # Jacket front edges and the ribbed hem.
    for y in range(63, 84):
        f.px(67, y + b, JACKET[5]) if (67, y + b) in body else None
        f.px(66, y + b, JACKET[2]) if (66, y + b) in body else None
        f.px(73, y + b, JACKET[1]) if (73, y + b) in body else None
    for x in range(55, 75):
        for y in (83, 84):
            if (x, y + b) in body and (x, y + b) not in top:
                f.px(x, y + b, JACKET[3] if (x + y) % 2 else JACKET[1])
    # Folds where the puffed body creases.
    for x, y in ((58, 72), (59, 73), (60, 74), (61, 78), (62, 79), (64, 70), (64, 71)):
        f.px(x, y + b, JACKET[1]) if (x, y + b) in body else None
    f.paint(sleeve, JACKET, axis="h", lift=0.08)
    for x, y in ((54, 71), (53, 72), (52, 74), (55, 79), (56, 80)):
        f.px(x, y + b, JACKET[2]) if (x, y + b) in sleeve else None
    # Magenta piping down the sleeve -- the crew's mark.
    for y in range(66, 77):
        x = int(round(52.6 + (y - 66) * -0.08)) if y < 74 else 51
        if (x + 1, y + b) in sleeve:
            f.px(x + 1, y + b, MAGENTA["mid"], glow=True)
    cuff = Shape().ellipse(57.6, 82.6 + b, 2.4, 2.0).pixels() & sleeve
    f.paint(cuff, JACKET, axis="h", lift=-0.1)
    # Shoulder patch: a ring with a flame cut through it.
    for x, y in ((57, 66), (58, 66), (59, 67), (59, 68), (58, 69), (57, 69), (56, 68), (56, 67)):
        f.px(x, y + b, ORANGE["dim"])
    f.px(57, 67 + b, ORANGE["mid"], glow=True)
    f.px(58, 68 + b, ORANGE["mid"], glow=True)
    # The pauldron, in front of the jacket on the far shoulder.
    pauldron = Shape().ellipse(75, 65.4 + b, 4.0, 3.2).cut([(70, 69 + b), (80, 69 + b), (80, 72 + b), (70, 72 + b)]).pixels()
    # The neck, bare above the top.
    neck = Shape().poly([(63.6, 57 + b), (68, 57 + b), (68.4, 62 + b), (63.4, 62 + b)]).pixels()
    f.paint(neck, SKIN, axis="h", lift=-0.12)

    # Head: pale skin, eyes that run hot, black streaks under them like burnt mascara.
    face = Shape().poly([(62, 48.6 + b), (70.2, 49.4 + b), (71, 54.6 + b), (69.6, 58 + b), (67, 59.6 + b), (64.6, 59.4 + b), (62.4, 56 + b)]).pixels()
    f.paint(face, SKIN, axis="h", lift=0.12)
    for x in (63, 64, 65):
        f.px(x, 52 + b, SKIN[0])
    f.px(64, 53 + b, ORANGE["core"], glow=True)
    f.px(65, 53 + b, ORANGE["hi"], glow=True)
    f.px(63, 53 + b, SKIN[1])
    f.px(64, 54 + b, MASK[0])
    f.px(64, 55 + b, MASK[1])
    f.px(65, 56 + b, MASK[2])
    for x in (68, 69):
        f.px(x, 52 + b, SKIN[0])
    f.px(69, 53 + b, ORANGE["mid"], glow=True)
    f.px(69, 54 + b, MASK[1])
    f.px(70, 55 + b, SKIN[2])
    f.px(70, 53 + b, SKIN[3])
    f.px(67, 57 + b, hexc("#3a1622"))
    f.px(68, 57 + b, hexc("#52202e"))
    f.px(66, 55 + b, SKIN[2])
    # A blunt bob: silver on top, black underneath, the fringe cut straight across.
    hair = Shape().poly([(58.6, 52 + b), (59.4, 47 + b), (62.4, 44.6 + b), (67.4, 44.2 + b), (70.8, 45.6 + b), (72.4, 49 + b),
                         (73.2, 56 + b), (73.8, 58 + b), (70.8, 57.4 + b), (70.6, 51.4 + b), (69, 50.8 + b), (67, 51.6 + b),
                         (65, 50.8 + b), (62.6, 51.4 + b), (62.2, 58.4 + b), (57.4, 59.4 + b), (58.2, 56 + b)])
    s_hair = hair.pixels()
    f.paint(s_hair, HAIR, axis="h", lift=0.14, fall=0.1)
    for x, y in s_hair:
        if y >= 55 + b or (x < 61 and y >= 53 + b):
            f.px(x, y, JACKET[3] if (x + y) % 5 else JACKET[5])
    for x in range(60, 72):
        y = 46 + b
        if (x, y) in s_hair:
            f.px(x, y, HAIR[5] if 61 < x < 67 else HAIR[4])
    for x in range(63, 71):
        if (x, 50 + b) in s_hair:
            f.px(x, 50 + b, HAIR[2] if x % 2 else HAIR[1])
    for x0, y0, n in ((61, 48, 4), (64, 47, 3), (67, 47, 3), (70, 48, 6), (60, 50, 3)):
        for y in range(y0, y0 + n):
            f.px(x0, y + b, HAIR[1]) if (x0, y + b) in s_hair and y < 55 + b else None
    for x in (63, 65, 67, 69):
        f.px(x, 51 + b, HAIR[2]) if (x, 50 + b) in s_hair else None
    f.px(72, 52 + b, ORANGE["mid"], glow=True)

    # Snow-leopard fur collar heaped on the shoulders.
    fur = Shape().poly([(53.8, 63 + b), (58.4, 59.6 + b), (62.6, 60.4 + b), (66, 62.6 + b), (69.6, 60.2 + b), (74.4, 61 + b),
                        (75.8, 64.4 + b), (72.6, 67.4 + b), (67.4, 66 + b), (63, 67.8 + b), (58, 67.4 + b), (53.6, 66 + b)])
    for x0, y0 in ((55.6, 66.6), (59.6, 67.6), (64.4, 67.8), (70.4, 67), (73.8, 66.2), (57.4, 59.8), (71.6, 60)):
        fur.ellipse(x0, y0 + b, 1.5, 1.3)
    s_fur = fur.pixels()
    f.paint(s_fur, FUR, axis="h", lift=0.1)
    for x, y in s_fur:
        if (x * 7 + y * 13) % 23 == 0 and (x, y - 1) in s_fur:
            f.px(x, y, SPOT[0])
            if (x + 1, y) in s_fur:
                f.px(x + 1, y, SPOT[1])
    for x, y in s_fur:
        if (x, y - 1) not in s_fur and x % 2 == 0:
            f.px(x, y, FUR[4])
    f.paint(pauldron, CHROME, axis="h", gloss=0.45)
    for x in range(71, 79):
        if (x, 67 + b) in pauldron:
            f.px(x, 67 + b, ORANGE["mid"] if x % 2 else ORANGE["dim"], glow=x % 2 == 1)

    # Heat on the cloth around the gauntlet and the respirator; embers drifting off the arm.
    f.glow((elbow_at[0] + wrist[0]) / 2 + 1, (elbow_at[1] + wrist[1]) / 2, 9, ORANGE["mid"], 0.55 + 0.25 * heat)
    f.glow(64.5, 53 + b, 3, ORANGE["mid"], 0.4)
    f.glow(70, 70 + b, 4, ORANGE["mid"], 0.35)
    f.finish(rim=((92, 228, 255), (255, 70, 150)), rim_strength=(0.5, 0.34))
    for x, y, c in pose.get("embers", ((80, 78, "hi"), (82, 72, "mid"), (79, 66, "dim"))):
        f.px(x, y, ORANGE[c], glow=True)
    return f.image


def show(images, path, scale=5, bg=(16, 20, 28)):
    board = Image.new("RGB", (len(images) * 128 * scale, 128 * scale), bg)
    for i, image in enumerate(images):
        big = image.resize((128 * scale, 128 * scale), Image.NEAREST)
        board.paste(big, (i * 128 * scale, 0), big)
    board.save(path)


def embers(frame, frames=6):
    """Sparks shed by the gauntlet, rising and fading over the loop."""
    out = []
    for k, (x0, y0) in enumerate(((80, 84), (82, 78), (79, 72))):
        t = ((frame / frames) + k / 3.0) % 1.0
        y = y0 - t * 16
        x = x0 + math.sin(t * 6 + k) * 1.5
        out.append((int(round(x)), int(round(y)), "hi" if t < 0.35 else "mid" if t < 0.7 else "dim"))
    return tuple(out)


def strips():
    """Idle, Walk and Fire strips for both operators, written into materials/operators."""
    folder = os.path.join(ROOT, "materials", "operators")
    breathe = [0, 0, 1, 1, 1, 0]
    sets = {
        "sereno_idle": [sereno({"bob": breathe[i], "spin": i * 0.5, "wind": 0.6 + 0.6 * math.sin(i / 6 * math.tau)}) for i in range(6)],
        "sereno_walk": [sereno(walk_pose(i)) for i in range(8)],
        "sereno_fire": [sereno({"reach": r, "spin": 1 + i * 0.6, "wind": 2}) for i, r in enumerate((0.5, 1.0, 1.0, 0.7))],
        "brasa_idle": [brasa({"bob": breathe[i], "embers": embers(i)}) for i in range(6)],
        "brasa_walk": [brasa(dict(walk_pose(i), embers=embers(i % 6))) for i in range(8)],
        "brasa_fire": [brasa({"aim": a, "heat": h, "embers": ()}) for a, h in ((0.7, 1), (1.0, 2), (1.0, 2), (0.85, 2))],
    }
    for name, frames in sets.items():
        strip = Image.new("RGBA", (128 * len(frames), 128), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            strip.paste(frame, (i * 128, 0))
        strip.save(os.path.join(folder, name + ".png"))
        print(name, len(frames))


def flame(width, height, nozzle, reach, seed=3):
    """Brasa's jet as pixels: white at the palm, orange through the body, smoke where it dies."""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    put = layer.load()
    nx, ny = nozzle
    stops = [(0.0, ORANGE["core"]), (0.18, hexc("#ffe28a")), (0.4, ORANGE["hi"]), (0.66, ORANGE["mid"]), (0.86, hexc("#b8341a")), (1.0, hexc("#3a1a1c"))]
    for x in range(int(nx), int(nx + reach)):
        t = (x - nx) / reach
        half = 1.2 + t * 9.0 + math.sin(t * 9) * 1.2
        for y in range(int(ny - half - 2), int(ny + half + 2)):
            d = abs(y + 0.5 - ny + t * 3.0) / max(0.5, half)
            jitter = rng.random() * 0.35
            if d + jitter > 1.05 or (t > 0.7 and rng.random() < (t - 0.7) * 1.6):
                continue
            heat = min(1.0, t * 0.9 + d * 0.45 + jitter * 0.3)
            for (a, ca), (b2, cb) in zip(stops, stops[1:]):
                if a <= heat <= b2:
                    put[x, y] = ca if heat - a < b2 - heat else cb
                    break
    return layer


def animas(width, height, origin, seed=5):
    """Three rain-spirits leaving the ward, each dragging a tail of light."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    put = layer.load()
    ox, oy = origin
    for k, (dx, dy, bend) in enumerate(((44, -14, 6), (52, 4, -4), (36, 16, 5))):
        for i in range(40):
            t = i / 39.0
            x = ox + dx * t
            y = oy + dy * t + math.sin(t * math.pi) * bend
            if not (0 <= x < width and 0 <= y < height):
                continue
            if t > 0.9:
                c = CYAN["core"]
            elif t > 0.75:
                c = CYAN["hi"]
            elif t > 0.45:
                c = CYAN["mid"] if i % 2 else VIOLET["mid"]
            elif i % 3 == 0:
                c = VIOLET["dim"]
            else:
                continue
            put[int(x), int(y)] = c
        hx, hy = ox + dx, oy + dy
        for ddx, ddy in ((1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)):
            if 0 <= hx + ddx < width and 0 <= hy + ddy < height:
                put[int(hx + ddx), int(hy + ddy)] = CYAN["hi"] if (ddx, ddy) != (1, 1) else CYAN["core"]
    return layer


def backdrop(size):
    w, h = size
    board = Image.new("RGB", size)
    d = ImageDraw.Draw(board)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=(int(9 + 14 * t), int(11 + 4 * t), int(22 + 26 * t)))
    glow = Image.new("RGB", size, (0, 0, 0))
    g = ImageDraw.Draw(glow)
    rng = random.Random(8)
    for _ in range(26):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.05), int(h * 0.7))
        c = rng.choice([(40, 190, 230), (230, 50, 140), (240, 120, 40), (120, 90, 230)])
        bw, bh = rng.randrange(20, 90), rng.randrange(6, 40)
        g.rectangle([x, y, x + bw, y + bh], fill=tuple(int(v * 0.5) for v in c))
    glow = glow.filter(ImageFilter.GaussianBlur(26))
    board = Image.blend(board, Image.composite(glow, board, Image.new("L", size, 255)), 0.0)
    board = Image.fromarray(None) if False else board
    from PIL import ImageChops
    board = ImageChops.add(board, glow)
    d = ImageDraw.Draw(board)
    for _ in range(260):
        x, y = rng.randrange(w), rng.randrange(h)
        n = rng.randrange(10, 34)
        d.line([(x, y), (x - n * 0.18, y + n)], fill=(52, 66, 94), width=1)
    # Wet floor: a darker band with the street's colours smeared into it.
    floor = int(h * 0.86)
    for y in range(floor, h):
        d.line([(0, y), (w, y)], fill=(12, 13, 24))
    return board


def concept(path):
    board = backdrop((1600, 900))
    d = ImageDraw.Draw(board)
    try:
        title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 40, index=1)
        tag = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 18)
        body = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 17)
        small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    except OSError:
        title = tag = body = small = ImageFont.load_default()

    def place(image, scale, x, y):
        big = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
        board.paste(big, (x, y), big)

    floor = int(900 * 0.86)
    columns = [
        ("EL SERENO", "vigía de la lluvia · apoyo", (93, 228, 255),
         ["Hechicero del Sector 08. La capucha esconde un visor; los", "sellos van cosidos en el abrigo como circuitos.",
          "Ataque: dibuja un sello en el aire y suelta ánimas que", "persiguen a las máquinas, las empapan y las empujan."],
         sereno(), sereno({"reach": 1.0, "wind": 2, "spin": 0.6}), "sereno"),
        ("BRASA", "quemadora · daño cercano", (255, 140, 60),
         ["Salió de las fundiciones con el brazo derecho cambiado", "por una prótesis de combustión. Cuello de piel robado.",
          "Ataque: abre la palma y escupe un chorro corto de fuego", "que derrite lo que tiene delante."],
         brasa(), brasa({"aim": 1.0, "heat": 2, "embers": ()}), "brasa"),
    ]
    for index, (name, tagline, accent, lines, idle, act, key) in enumerate(columns):
        ox = 60 + index * 790
        d.text((ox, 34), name, font=title, fill=accent)
        d.text((ox, 86), tagline, font=tag, fill=(200, 205, 220))
        for li, line in enumerate(lines):
            d.text((ox, 124 + li * 23 + (8 if li > 1 else 0)), line, font=body, fill=(176, 184, 204))
        # Idle at 4x: the figure stands on the floor line.
        place(idle.crop((32, 36, 100, 124)), 5, ox - 30, floor - 88 * 5 + 10)
        # Attacking at 3x with its effect.
        wide = Image.new("RGBA", (190, 128), (0, 0, 0, 0))
        if key == "sereno":
            fx = animas(190, 128, (90, 59))
            wide.paste(act, (0, 0), act)
            wide.alpha_composite(fx)
        else:
            wide.paste(act, (0, 0), act)
            fx = flame(190, 128, (95, 70), 50)
            wide.alpha_composite(fx)
        place(wide.crop((36, 30, 160, 124)), 3, ox + 330, floor - 94 * 3 + 8)
        d.text((ox + 360, floor + 14), "atacando", font=small, fill=(150, 160, 185))
        d.text((ox + 10, floor + 14), "reposo", font=small, fill=(150, 160, 185))
        # At play size: 2x, as the yard draws it on a 2304-wide window.
        place(idle.crop((36, 36, 96, 124)), 2, ox + 590, 250)
        d.text((ox + 594, 230), "en juego (2x)", font=small, fill=(150, 160, 185))
    board.save(path)


if __name__ == "__main__":
    if "strips" in sys.argv:
        strips()
        sys.exit()
    if "concept" in sys.argv:
        concept(os.path.join(ROOT, "authored", "survivor_20261016", "crew_concept.png"))
        sys.exit()
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/cast.png"
    show([sereno(), brasa(), sereno({"reach": 1.0, "wind": 2}), brasa({"aim": 1.0, "heat": 2, "embers": ()})], out)
