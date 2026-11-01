"""Authors the two operators of Sector 08 as pixel art, frame by frame.

LA FUNDIDORA (damage) -- a foundry hand of the containment unit. Hi-vis rubber cape with a
reflective band, a welding visor pushed up on her forehead with its amber slit still lit, a brass
fuel tank on her back feeding a thermal lance she carries low and forward. Her bolts boil water.

EL SERENO (support) -- the yard's night watchman. Oilskin brim hat dripping, a long petrol-teal
poncho, a coil of conduit cable over the shoulder and a lantern staff whose cyan light is the
same light he heals with. Stooped, patient, never hurried.

Run:  python3 tools/operators/generate_operators.py
Writes materials/operators/<name>_<animation>.png strips of 128x128 frames, plus a preview.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel import Canvas, hexc, sheet  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "materials", "operators")
CX, GROUND = 64, 124

# --- La Fundidora palette ------------------------------------------------------------------------
F = {
    "cape_d": hexc("7a3317"), "cape": hexc("bd5722"), "cape_l": hexc("e4803a"), "cape_h": hexc("f4a75c"),
    "band": hexc("8f989e"), "band_l": hexc("e3eaec"),
    "rubber": hexc("1c1b1f"), "rubber_l": hexc("34323a"),
    "leather": hexc("2b1e19"), "leather_l": hexc("4a3329"), "stitch": hexc("7a5539"),
    "cloth": hexc("21252c"), "cloth_l": hexc("323943"),
    "boot": hexc("161519"), "boot_l": hexc("2b292f"), "toe": hexc("a94c1c"),
    "skin_d": hexc("8a5a44"), "skin": hexc("b98163"), "skin_l": hexc("d9a07c"),
    "hair": hexc("1a1515"), "hair_l": hexc("33292a"),
    "steel_d": hexc("2b3036"), "steel": hexc("4a535b"), "steel_l": hexc("7d8891"), "steel_h": hexc("b4bec5"),
    "lens": hexc("ffb347"), "lens_h": hexc("ffe6ad"),
    "brass_d": hexc("57391c"), "brass": hexc("94652f"), "brass_l": hexc("cc9752"), "brass_h": hexc("f1c77f"),
    "rust": hexc("753313"),
    "tip_o": hexc("ff6a1a"), "tip": hexc("ffb347"), "tip_c": hexc("fff4cf"),
}
GLOW_F = {F["lens"][:3], F["lens_h"][:3], F["tip_o"][:3], F["tip"][:3], F["tip_c"][:3]}

# --- El Sereno palette ---------------------------------------------------------------------------
S = {
    "pon_d": hexc("0f2428"), "pon": hexc("1c4348"), "pon_l": hexc("2b6267"), "sheen": hexc("5c9fa3"),
    "hat_d": hexc("101c1f"), "hat": hexc("1c3236"), "hat_l": hexc("2c4b50"), "hatband": hexc("8a6634"),
    "face_d": hexc("3e302a"), "face": hexc("6d5547"),
    "beard_d": hexc("878177"), "beard": hexc("c3bdaf"),
    "lens": hexc("86e4f9"), "lens_h": hexc("e6fbff"),
    "boot": hexc("12221f"), "boot_l": hexc("214039"), "cloth": hexc("1e2228"),
    "coil_d": hexc("5e4322"), "coil": hexc("a87e42"), "coil_l": hexc("d8ad69"),
    "pole_d": hexc("2c2523"), "pole": hexc("53463d"), "pole_l": hexc("75655a"),
    "cage_d": hexc("6a4d26"), "cage": hexc("b88a49"), "cage_l": hexc("e3b46e"),
    "orb_o": hexc("2f8fa3"), "orb": hexc("86e4f9"), "orb_c": hexc("eafcff"),
    "glove": hexc("1a1a1d"), "drop": hexc("9fe8f7"),
}
GLOW_S = {S["lens"][:3], S["lens_h"][:3], S["orb"][:3], S["orb_c"][:3], S["drop"][:3], S["orb_o"][:3]}


def P(x, y, bob=0):
    return (CX + x, GROUND + y + bob)


def leg(c, hip, foot, lift, colors, boot, knee_push=2, width=5):
    """Thigh and shin as one tapered polygon, then a boot. hip/foot are relative x; y fixed."""
    hx, hy = hip
    fx = foot
    ky = (hy + (-5 - lift)) / 2.0
    kx = (hx + fx) / 2.0 + knee_push
    dark, light = colors
    c.poly([P(hx - width / 2, hy), P(hx + width / 2, hy), P(kx + width / 2, ky), P(fx + 2, -5 - lift), P(fx - 2, -5 - lift), P(kx - width / 2 + 0.5, ky)], dark)
    c.poly([P(hx + 0.5, hy), P(hx + width / 2, hy), P(kx + width / 2, ky), P(kx + 1, ky)], light)
    b_d, b_l, toe = boot
    y0 = -lift
    c.poly([P(fx - 3, y0), P(fx + 5, y0), P(fx + 5, y0 - 3), P(fx + 2, y0 - 6), P(fx - 3, y0 - 6)], b_d)
    c.line(*P(fx - 2, y0 - 5), *P(fx + 1, y0 - 5), b_l)
    if toe is not None:
        c.poly([P(fx + 2, y0), P(fx + 5, y0), P(fx + 5, y0 - 3), P(fx + 3, y0 - 3)], toe)
    c.line(*P(fx - 3, y0), *P(fx + 5, y0), hexc("0a0a0c"))


def fundidora(pose):
    c = Canvas()
    b = pose.get("bob", 0)
    sway = pose.get("sway", 0)
    act = pose.get("act", 0.0)
    flick = pose.get("flicker", 0)
    # Back tank, behind everything: brass cylinder with a rust bloom and a valve.
    tx = -19
    # Tall enough to clear the shoulder: the tank is half her silhouette from behind.
    c.rect(*P(tx, -61, b), *P(tx + 6, -33, b), F["brass"])
    c.rect(*P(tx + 1, -60, b), *P(tx + 2, -34, b), F["brass_l"])
    for y in (-59, -58, -50):
        c.px(*P(tx + 1, y, b), F["brass_h"])
    c.rect(*P(tx + 5, -60, b), *P(tx + 6, -34, b), F["brass_d"])
    for y in (-55, -40):
        c.line(*P(tx, y, b), *P(tx + 6, y, b), F["brass_d"])
    c.px(*P(tx + 4, -37, b), F["rust"])
    c.px(*P(tx + 3, -36, b), F["rust"])
    c.px(*P(tx + 4, -35, b), F["rust"])
    c.ellipse(*P(tx + 3, -62, b), 3, 1, F["brass_d"])
    c.rect(*P(tx + 2, -65, b), *P(tx + 4, -63, b), F["steel"])
    c.line(*P(tx + 1, -66, b), *P(tx + 5, -66, b), F["steel_l"])
    # Pressure gauge on the tank's flank.
    c.ellipse(*P(tx + 3, -47, b), 2, 2, F["steel_h"])
    c.px(*P(tx + 3, -47, b), F["tip_o"])
    c.px(*P(tx + 4, -48, b), F["steel_d"])
    # Hose from the tank's foot, sagging under the cape to the lance grip.
    hose = [(-13, -31), (-12, -27), (-8, -24), (-2, -23), (4, -26), (8, -31)]
    for (x0, y0), (x1, y1) in zip(hose, hose[1:]):
        c.line(*P(x0, y0, b), *P(x1, y1, b), F["rubber"], 2)
    # Legs: the far one darker.
    back, front = pose["back_foot"], pose["front_foot"]
    leg(c, (-2, -27 + b), back[0], back[1], (hexc("181b20"), F["cloth"]), (F["boot"], F["boot"], hexc("7a3615")))
    leg(c, (3, -27 + b), front[0], front[1], (F["cloth"], F["cloth_l"]), (F["boot"], F["boot_l"], F["toe"]))
    c.rect(*P(4 + front[0] * 0.5, -17 + b - front[1] * 0.5), *P(6 + front[0] * 0.5, -15 + b - front[1] * 0.5), F["brass"])
    # Leather apron over the hips.
    c.poly([P(-5, -35, b), P(9, -35, b), P(10 + sway * 0.3, -17, b), P(-3 + sway * 0.3, -16, b)], F["leather"])
    c.line(*P(7, -34, b), *P(8 + sway * 0.3, -18, b), F["leather_l"])
    for y in range(-32, -18, 3):
        c.px(*P(-2, y, b), F["stitch"])
    # The cape: hi-vis rubber, broad at the shoulders, heavy at the hem.
    hem = sway
    # Torso glimpsed through the open front of the cape.
    c.poly([P(2, -46, b), P(8, -46, b), P(8, -30, b), P(3, -30, b)], F["leather"])
    c.line(*P(7, -45, b), *P(7, -31, b), F["leather_l"])
    cape = [P(-12, -50, b), P(-8, -54, b), P(4, -55, b), P(9, -52, b), P(11, -45, b), P(9, -40, b), P(6 + hem * 0.5, -29, b),
            P(1 + hem * 0.5, -27, b), P(-4 + hem * 0.4, -26, b), P(-10 + hem * 0.6, -23, b), P(-15 + hem * 0.5, -27, b), P(-15, -43, b)]
    c.poly(cape, F["cape"])
    # The front panel falls over the near shoulder, and away from the body below the lance.
    c.poly([P(4, -55, b), P(9, -52, b), P(12, -45, b), P(14 + hem, -31, b), P(10 + hem, -28, b), P(7, -36, b), P(5, -46, b)], F["cape"])
    c.poly([P(-12, -50, b), P(-8, -54, b), P(4, -55, b), P(9, -52, b), P(4, -49, b), P(-6, -48, b)], F["cape_l"])
    c.line(*P(-8, -53, b), *P(3, -54, b), F["cape_h"])
    c.line(*P(9, -51, b), *P(11, -46, b), F["cape_h"])
    c.poly([P(-15, -43, b), P(-10, -46, b), P(-8, -25, b), P(-10 + hem * 0.6, -23, b), P(-15 + hem * 0.5, -27, b)], F["cape_d"])
    c.poly([P(11, -44, b), P(12, -45, b), P(14 + hem, -31, b), P(11 + hem, -29, b)], F["cape_d"])
    c.line(*P(-3, -47, b), *P(-4 + hem * 0.4, -27, b), F["cape_d"])
    c.line(*P(6, -38, b), *P(9 + hem, -30, b), F["cape_d"])
    # Hood bunched behind the neck.
    c.poly([P(-10, -57, b), P(-3, -59, b), P(-2, -54, b), P(-9, -51, b), P(-12, -53, b)], F["cape_d"])
    c.line(*P(-9, -57, b), *P(-4, -58, b), F["cape"])
    # Reflective band, broken by the folds.
    for x in range(-13, 14):
        for y, color in ((-37, F["band_l"]), (-36, F["band"])):
            px = P(x, y, b)
            if c.get(*px)[:3] in (F["cape"][:3], F["cape_d"][:3], F["cape_l"][:3]) and x not in (2, -3):
                c.px(*px, color)
    # Strap across the chest to the tank, with a brass buckle.
    c.line(*P(-9, -51, b), *P(5, -40, b), F["rubber"])
    c.px(*P(0, -44, b), F["brass_l"])
    c.px(*P(1, -44, b), F["brass"])
    # Collar.
    c.poly([P(-5, -57, b), P(5, -57, b), P(6, -52, b), P(-6, -52, b)], F["rubber_l"])
    c.line(*P(-5, -52, b), *P(6, -52, b), F["rubber"])
    # Head: dark cropped hair, face in profile toward the right, soot on the cheek.
    hb = b + pose.get("head", 0)
    c.ellipse(*P(0, -62, hb), 5, 5.5, F["hair"])
    c.poly([P(0, -66, hb), P(5, -66, hb), P(6, -63, hb), P(7, -61, hb), P(6, -60, hb), P(6, -58, hb), P(4, -56, hb), P(1, -56, hb), P(0, -59, hb)], F["skin"])
    c.line(*P(1, -66, hb), *P(5, -66, hb), F["skin_l"])
    c.px(*P(6, -62, hb), F["skin_l"])
    c.line(*P(1, -57, hb), *P(4, -57, hb), F["skin_d"])
    c.px(*P(4, -62, hb), hexc("120d0c"))
    c.px(*P(3, -62, hb), F["skin_d"])
    c.px(*P(2, -60, hb), hexc("3a2a24"))
    c.px(*P(3, -60, hb), hexc("4d382f"))
    c.px(*P(5, -58, hb), F["skin_d"])
    c.px(*P(0, -61, hb), F["skin_d"])
    c.px(*P(-1, -60, hb), F["skin_d"])
    c.px(*P(-3, -59, hb), F["hair_l"])
    # A short braid, tied in brass, falling over the hood.
    for k in range(6):
        c.px(*P(-4 - k * 0.4, -59 + k, hb), F["hair"] if k % 2 else F["hair_l"])
        c.px(*P(-5 - k * 0.4, -59 + k, hb), F["hair"])
    c.px(*P(-6, -53, hb), F["brass_l"])
    # The visor, pushed up, its slit still burning.
    c.poly([P(-3, -70, hb), P(5, -71, hb), P(7, -68, hb), P(6, -66, hb), P(-2, -66, hb)], F["steel"])
    c.line(*P(-2, -70, hb), *P(4, -71, hb), F["steel_l"])
    c.line(*P(-2, -66, hb), *P(6, -66, hb), F["steel_d"])
    lens = F["lens_h"] if pose.get("glint") else F["lens"]
    for x in range(0, 6):
        c.px(*P(x, -68, hb), lens)
    c.px(*P(-3, -67, hb), F["brass_l"])
    c.px(*P(-4, -66, hb), F["brass"])
    # Lance: carried low and forward, or levelled and thrust when firing.
    grip = (9 + act * 3, -33 + b - act * 3)
    angle = math.radians(18 - act * 16)
    direction = (math.cos(angle), math.sin(angle))
    butt = (grip[0] - direction[0] * 14, grip[1] - direction[1] * 14)
    tip = (grip[0] + direction[0] * (25 + act * 4), grip[1] + direction[1] * (25 + act * 4))
    c.line(CX + butt[0], GROUND + butt[1], CX + tip[0], GROUND + tip[1], F["steel"], 2)
    c.line(CX + butt[0], GROUND + butt[1] - 1, CX + tip[0], GROUND + tip[1] - 1, F["steel_l"])
    for t in (0.62, 0.7, 0.78):
        rx = grip[0] + direction[0] * 25 * t
        ry = grip[1] + direction[1] * 25 * t
        c.line(CX + rx, GROUND + ry - 2, CX + rx, GROUND + ry + 1, F["brass_l"])
    # Nozzle and its heat.
    nx, ny = CX + tip[0], GROUND + tip[1]
    c.rect(nx - 2, ny - 2, nx + 1, ny + 1, F["steel_d"])
    heat = [F["tip_o"], F["tip"], F["tip_c"]]
    size = 1 + act * 2 + (flick % 2) * 0.5
    c.ellipse(nx + 2 + act, ny, size + 0.6, size * 0.7 + 0.4, heat[0])
    c.ellipse(nx + 2 + act, ny, size * 0.6, size * 0.4, heat[1])
    c.px(nx + 2 + act, ny, heat[2])
    ember = pose.get("ember", -1)
    if ember >= 0:
        c.px(nx + 2 + (ember % 2), ny - 3 - ember * 2, (255, 150, 60, 200 - ember * 40))
    if act > 0.5:
        for k in range(3):
            c.px(nx + 6 + k * 2, ny + (k % 2) - 1, heat[k % 2])
    # Arms: the far hand under the lance, the near gauntlet over it, rivets in brass.
    c.rect(CX + grip[0] - 7, GROUND + grip[1] - 1, CX + grip[0] - 4, GROUND + grip[1] + 2, F["leather"])
    sleeve_top = (6, -48 + b)
    c.poly([(CX + sleeve_top[0], GROUND + sleeve_top[1]), (CX + sleeve_top[0] + 4, GROUND + sleeve_top[1] + 1),
            (CX + grip[0] + 2, GROUND + grip[1] - 2), (CX + grip[0] - 2, GROUND + grip[1] - 1)], F["cape_d"])
    c.rect(CX + grip[0] - 2, GROUND + grip[1] - 3, CX + grip[0] + 2, GROUND + grip[1] + 1, F["leather_l"])
    c.px(CX + grip[0] - 1, GROUND + grip[1] - 2, F["brass_l"])
    c.px(CX + grip[0] + 1, GROUND + grip[1] - 2, F["brass_l"])
    c.px(CX + grip[0] + 2, GROUND + grip[1], F["skin"])
    c.finish(rim_strength=0.38, glow_keep=GLOW_F)
    return c.image


def sereno(pose):
    c = Canvas()
    b = pose.get("bob", 0)
    sway = pose.get("sway", 0)
    swing = pose.get("swing", 0)
    pulse = pose.get("pulse", 0)
    back, front = pose["back_foot"], pose["front_foot"]
    # Legs show only below the poncho: short shins and rubber galoshes.
    leg(c, (-3, -16 + b), back[0], back[1], (hexc("15181d"), S["cloth"]), (S["boot"], S["boot"], None), 1, 4)
    leg(c, (2, -16 + b), front[0], front[1], (S["cloth"], hexc("2c323a")), (S["boot"], S["boot_l"], None), 1, 4)
    # Cable coil slung across the back.
    for k, (ox, oy) in enumerate(((-12, -45), (-11, -43), (-13, -41))):
        c.ellipse(*P(ox, oy, b), 4, 6, None, outline=S["coil"] if k != 1 else S["coil_d"])
    c.px(*P(-15, -47, b), S["coil_l"])
    c.px(*P(-14, -50, b), S["coil_l"])
    # The poncho: long, A-line, heavy with rain.
    hem = sway
    poncho = [P(-8, -57, b), P(7, -57, b), P(11, -48, b), P(13 + hem, -30, b), P(14 + hem, -15, b), P(7 + hem, -12, b), P(0 + hem * 0.6, -14, b), P(-6 + hem * 0.4, -12, b), P(-12 + hem * 0.3, -14, b), P(-13, -32, b), P(-11, -48, b)]
    c.poly(poncho, S["pon"])
    c.poly([P(-8, -57, b), P(7, -57, b), P(10, -51, b), P(-2, -50, b), P(-10, -50, b)], S["pon_l"])
    c.poly([P(-13, -32, b), P(-9, -46, b), P(-6, -13, b), P(-12 + hem * 0.3, -14, b)], S["pon_d"])
    c.poly([P(9, -46, b), P(11, -48, b), P(14 + hem, -15, b), P(10 + hem, -13, b)], S["pon_d"])
    for fx, top in ((-3, -48), (3, -47), (7, -44)):
        c.line(*P(fx, top, b), *P(fx + hem * 0.5, -15, b), S["pon_d"])
    # Wet sheen: short streaks that slide down over the cycle.
    for k, fx in enumerate((-6, 1, 5)):
        y = -46 + ((pose.get("sheen", 0) + k * 5) % 22)
        c.line(*P(fx, y, b), *P(fx, y + 3, b), S["sheen"])
    # Ragged hem.
    for x in range(-11, 14, 3):
        c.px(*P(x + hem * 0.5, -13 + (x % 2), b), S["pon_d"])
    # Hood shadow and face under the brim: grey beard, one cyan lens.
    hb = b
    c.poly([P(-6, -62, hb), P(6, -62, hb), P(8, -55, hb), P(-5, -55, hb)], S["pon_d"])
    c.poly([P(1, -61, hb), P(7, -61, hb), P(8, -57, hb), P(2, -56, hb)], S["face_d"])
    c.px(*P(6, -59, hb), S["face"])
    c.px(*P(7, -58, hb), S["face"])
    c.poly([P(2, -57, hb), P(8, -57, hb), P(9, -53, hb), P(6, -49, hb), P(3, -51, hb)], S["beard_d"])
    c.line(*P(4, -56, hb), *P(8, -55, hb), S["beard"])
    c.px(*P(5, -53, hb), S["beard"])
    c.px(*P(7, -51, hb), S["beard"])
    c.px(*P(5, -59, hb), S["lens"])
    c.px(*P(6, -59, hb), S["lens_h"] if pose.get("glint") else S["lens"])
    c.px(*P(4, -59, hb), S["cage"])
    # Hat: wide oilskin brim, low crown, a brass band.
    c.ellipse(*P(1, -62, hb), 11, 2, S["hat"])
    c.line(*P(-9, -61, hb), *P(11, -61, hb), S["hat_d"])
    c.line(*P(-7, -63, hb), *P(9, -63, hb), S["hat_l"])
    c.poly([P(-4, -70, hb), P(5, -70, hb), P(6, -63, hb), P(-5, -63, hb)], S["hat"])
    c.line(*P(-3, -70, hb), *P(4, -70, hb), S["hat_l"])
    c.line(*P(-5, -64, hb), *P(6, -64, hb), S["hatband"])
    # Rain off the brim, one drop at a time.
    drop = pose.get("drop", 0)
    if drop >= 0:
        c.px(*P(12, -60 + drop * 2, hb), S["drop"])
        if drop > 1:
            c.px(*P(-10, -61 + (drop - 2) * 2, hb), S["drop"])
    # The staff: planted ahead of him, with the lantern on its hook.
    staff_x = 15 + pose.get("staff", 0)
    foot_y = -pose.get("staff_lift", 0)
    c.line(*P(staff_x, foot_y), *P(staff_x - 1, -82, b), S["pole"], 2)
    c.line(*P(staff_x, foot_y), *P(staff_x - 1, -82, b), S["pole_d"])
    c.line(*P(staff_x - 1, -82, b), *P(staff_x + 3, -84, b), S["cage"])
    c.line(*P(staff_x + 3, -84, b), *P(staff_x + 5, -81, b), S["cage"])
    lx = staff_x + 5 + swing
    c.line(*P(staff_x + 5, -81, b), *P(lx, -78, b), S["cage_d"])
    # Lantern: brass cage, cyan heart, a soft halo.
    halo = 4 + pulse
    for r, alpha in ((halo + 2, 40), (halo, 90)):
        c.ellipse(*P(lx, -72, b), r, r, (134, 228, 249, alpha))
    c.rect(*P(lx - 3, -77, b), *P(lx + 3, -67, b), S["orb_o"])
    c.ellipse(*P(lx, -72, b), 2 + (pulse > 0), 2 + (pulse > 0), S["orb"])
    c.px(*P(lx, -72, b), S["orb_c"])
    c.px(*P(lx - 1, -73, b), S["orb_c"])
    for x in (lx - 3, lx, lx + 3):
        c.line(*P(x, -77, b), *P(x, -67, b), S["cage"])
    c.line(*P(lx - 3, -77, b), *P(lx + 3, -77, b), S["cage_l"])
    c.line(*P(lx - 3, -67, b), *P(lx + 3, -67, b), S["cage_d"])
    c.rect(*P(lx - 1, -79, b), *P(lx + 1, -78, b), S["cage"])
    # The arm reaching to the staff, a dark glove on the pole.
    c.poly([P(5, -55, b), P(9, -54, b), P(staff_x - 1, -42, b), P(staff_x - 4, -40, b)], S["pon_d"])
    c.rect(*P(staff_x - 2, -43, b), *P(staff_x + 1, -40, b), S["glove"])
    c.finish(rim_strength=0.45, glow_keep=GLOW_S)
    return c.image


# --- El Fogonero ---------------------------------------------------------------------------------
# The stoker who feeds the yard's boilers. Nobody has seen his face: his head is a cast-iron stove
# helmet and the only light on him comes through its grate, as if he burned inside. A charred coat,
# a flue on his back that trails embers, and a long iron lance whose tip is always red.
G = {
    "coat_d": hexc("120d0c"), "coat": hexc("261c19"), "coat_l": hexc("3d2e28"), "coat_h": hexc("5a443a"),
    "char": hexc("0a0807"),
    "iron_d": hexc("17181a"), "iron": hexc("2e3034"), "iron_l": hexc("4c5056"), "iron_h": hexc("7e858c"),
    "rust": hexc("5c2c16"), "rust_l": hexc("8a4220"),
    "glove_d": hexc("24160f"), "glove": hexc("432a1d"), "glove_l": hexc("654030"),
    "strap": hexc("1c1411"), "buckle": hexc("9a6a34"),
    "boot": hexc("100e0d"), "boot_l": hexc("26211f"), "cloth": hexc("1b1716"),
    "smoke": hexc("47403d", 150), "smoke_l": hexc("6a615c", 110),
    "red": hexc("8c2410"), "orange": hexc("e2581a"), "ember": hexc("ff9a3a"), "ember_c": hexc("ffd27a"), "white": hexc("fff3d2"),
}
GLOW_G = {G[k][:3] for k in ("red", "orange", "ember", "ember_c", "white")}


def fogonero(pose):
    c = Canvas()
    b = pose.get("bob", 0)
    sway = pose.get("sway", 0)
    act = pose.get("act", 0.0)
    flick = pose.get("flicker", 0)
    heat = pose.get("heat", 0)  # 0..2: how bright the grate burns this frame
    back, front = pose["back_foot"], pose["front_foot"]
    # The flue: an iron pipe out of the hump on his back, smoke and one ember leaving it.
    c.rect(*P(-12, -72, b), *P(-10, -60, b), G["iron"])
    c.line(*P(-12, -72, b), *P(-12, -60, b), G["iron_l"])
    c.rect(*P(-13, -74, b), *P(-8, -73, b), G["iron_d"])
    c.line(*P(-13, -75, b), *P(-8, -75, b), G["iron_l"])
    c.px(*P(-10, -66, b), G["rust_l"])
    # The boiler itself: a riveted iron dome riding high on his back, the flue rising out of it.
    c.poly([P(-19, -46, b), P(-19, -58, b), P(-15, -63, b), P(-9, -63, b), P(-6, -58, b), P(-6, -46, b)], G["iron"])
    c.poly([P(-19, -46, b), P(-19, -58, b), P(-16, -62, b), P(-15, -46, b)], G["iron_d"])
    c.line(*P(-14, -63, b), *P(-9, -63, b), G["iron_l"])
    c.line(*P(-19, -52, b), *P(-6, -52, b), G["iron_d"])
    for rx in (-17, -13, -9):
        c.px(*P(rx, -53, b), G["iron_h"])
    c.rect(*P(-17, -50, b), *P(-14, -48, b), G["red"] if heat < 2 else G["orange"])  # its own small grate
    c.line(*P(-17, -49, b), *P(-14, -49, b), G["iron_d"])
    # Legs: short shins under the coat, heavy boots, the far one darker.
    leg(c, (-3, -16 + b), back[0], back[1], (hexc("0f0d0d"), G["cloth"]), (G["boot"], G["boot"], None), 1, 5)
    leg(c, (2, -16 + b), front[0], front[1], (G["cloth"], hexc("2a2422")), (G["boot"], G["boot_l"], G["iron_l"]), 1, 5)
    # The coat: heavy, hunched over the hump of the boiler on his back, burnt along the hem.
    hem = sway
    coat = [P(-16, -48, b), P(-12, -57, b), P(-4, -59, b), P(5, -56, b), P(10, -50, b), P(12, -40, b), P(13 + hem, -26, b),
            P(15 + hem, -14, b), P(8 + hem, -12, b), P(1 + hem * 0.6, -14, b), P(-6 + hem * 0.4, -12, b), P(-14 + hem * 0.3, -14, b),
            P(-17, -30, b)]
    c.poly(coat, G["coat"])
    c.poly([P(-12, -57, b), P(-4, -59, b), P(5, -56, b), P(9, -51, b), P(0, -51, b), P(-10, -50, b), P(-15, -48, b)], G["coat_l"])
    c.line(*P(-11, -57, b), *P(-4, -58, b), G["coat_h"])
    c.poly([P(-17, -30, b), P(-16, -48, b), P(-11, -46, b), P(-8, -13, b), P(-14 + hem * 0.3, -14, b)], G["coat_d"])
    c.poly([P(10, -46, b), P(12, -40, b), P(15 + hem, -14, b), P(11 + hem, -13, b)], G["coat_d"])
    for fx, top in ((-3, -46), (3, -44), (8, -40)):
        c.line(*P(fx, top, b), *P(fx + hem * 0.5, -15, b), G["coat_d"])
    # Charred, ragged hem with a few sparks still alive in it.
    for x in range(-14, 16):
        y = -13 + (x * 7 % 3 == 0)
        c.px(*P(x + hem * 0.5, y, b), G["char"])
        if x % 5 == (flick % 5):
            c.px(*P(x + hem * 0.5, y - 1, b), G["red"])
    c.px(*P(4 + hem * 0.5, -15, b), G["orange"] if flick % 2 else G["red"])
    # Straps of the boiler across the chest, rusted buckles.
    c.line(*P(-12, -54, b), *P(8, -38, b), G["strap"], 2)
    c.line(*P(-14, -40, b), *P(9, -46, b), G["strap"])
    c.rect(*P(0, -47, b), *P(2, -45, b), G["buckle"])
    c.px(*P(-3, -42, b), G["buckle"])
    # Head: a cast-iron stove helmet, domed, riveted, a hood of the coat over its crown.
    hb = b + pose.get("head", 0)
    c.poly([P(-4, -66, hb), P(4, -68, hb), P(8, -65, hb), P(9, -55, hb), P(-4, -54, hb), P(-6, -60, hb)], G["iron"])
    c.poly([P(-6, -60, hb), P(-4, -66, hb), P(-1, -67, hb), P(-2, -54, hb), P(-4, -54, hb)], G["iron_d"])
    c.line(*P(-1, -67, hb), *P(4, -68, hb), G["iron_h"])
    c.line(*P(5, -67, hb), *P(8, -65, hb), G["iron_l"])
    for rx, ry in ((0, -64), (0, -57), (7, -64)):
        c.px(*P(rx, ry, hb), G["iron_h"])
    # The grate: three slots of fire, brighter at the core. This is his face.
    glow = [G["red"], G["orange"], G["ember"], G["ember_c"], G["white"]]
    halo = 4 + heat
    for k, gy in enumerate((-62, -60, -58)):
        for gx in range(3, 9):
            core = 2 - abs(gx - 6) * 0.6 - abs(k - 1) * 0.8 + heat * 0.7
            c.px(*P(gx, gy, hb), glow[max(0, min(4, int(round(core + 1))))])
        c.line(*P(3, gy + 1, hb), *P(8, gy + 1, hb), G["iron_d"])
    c.line(*P(2, -63, hb), *P(2, -57, hb), G["iron_d"])
    # Hood over the back and crown of the helmet.
    c.poly([P(-8, -62, hb), P(-5, -68, hb), P(1, -70, hb), P(4, -69, hb), P(0, -66, hb), P(-3, -60, hb), P(-4, -54, hb), P(-9, -53, hb)], G["coat"])
    c.line(*P(-5, -68, hb), *P(1, -70, hb), G["coat_h"])
    c.poly([P(-9, -53, hb), P(-8, -62, hb), P(-6, -61, hb), P(-6, -53, hb)], G["coat_d"])
    # The lance: a long iron pipe held low across the body, a hose from the boiler at its butt.
    grip = (10 + act * 3, -32 + b - act * 2)
    angle = math.radians(12 - act * 12)
    direction = (math.cos(angle), math.sin(angle))
    butt = (grip[0] - direction[0] * 16, grip[1] - direction[1] * 16)
    length = 27 + act * 4
    tip = (grip[0] + direction[0] * length, grip[1] + direction[1] * length)
    hose = [(-14, -30), (-12, -26), (-7, -24), (butt[0], butt[1] + 1)]
    for (x0, y0), (x1, y1) in zip(hose, hose[1:]):
        c.line(*P(x0, y0, b), *P(x1, y1), G["iron_d"], 2)
    c.line(CX + butt[0], GROUND + butt[1], CX + tip[0], GROUND + tip[1], G["iron"], 2)
    c.line(CX + butt[0], GROUND + butt[1] - 1, CX + tip[0], GROUND + tip[1] - 1, G["iron_l"])
    for t in (0.35, 0.55):
        rx, ry = grip[0] + direction[0] * length * t, grip[1] + direction[1] * length * t
        c.line(CX + rx, GROUND + ry - 2, CX + rx, GROUND + ry + 1, G["rust_l"])
    # The last hand-span of the lance is red-hot, white at the muzzle when he fires.
    for k in range(7):
        t = (length - 7 + k) / length
        hx, hy = grip[0] + direction[0] * length * t, grip[1] + direction[1] * length * t
        level = int(k / 7 * (3 + act * 2))
        c.px(CX + hx, GROUND + hy, glow[min(4, level)])
        c.px(CX + hx, GROUND + hy - 1, glow[max(0, min(4, level - 1))])
    nx, ny = CX + tip[0], GROUND + tip[1]
    c.poly([(nx, ny - 2), (nx + 3, ny - 3), (nx + 3, ny + 2), (nx, ny + 1)], G["iron_d"])
    c.px(nx + 3, ny - 1, glow[2 + int(act > 0.5)])
    c.px(nx + 3, ny, glow[2 + int(act > 0.5)])
    if act > 0.5:
        for k in range(4):
            c.px(nx + 6 + k * 2, ny - 1 + (k + flick) % 3 - 1, glow[3 - k % 2])
    # Arms: the far gauntlet on the butt, the near sleeve and a huge gauntlet on the grip.
    c.rect(CX + butt[0] + 3, GROUND + butt[1] - 2, CX + butt[0] + 7, GROUND + butt[1] + 2, G["glove_d"])
    c.poly([P(5, -53, b), P(10, -51, b), (CX + grip[0] + 3, GROUND + grip[1] - 3), (CX + grip[0] - 2, GROUND + grip[1] - 2)], G["coat_d"])
    c.line(*P(6, -52, b), *P(9, -50, b), G["coat_l"])
    c.rect(CX + grip[0] - 3, GROUND + grip[1] - 4, CX + grip[0] + 3, GROUND + grip[1] + 2, G["glove"])
    c.line(CX + grip[0] - 3, GROUND + grip[1] - 4, CX + grip[0] + 3, GROUND + grip[1] - 4, G["glove_l"])
    c.px(CX + grip[0] - 1, GROUND + grip[1] - 2, G["buckle"])
    c.px(CX + grip[0] + 1, GROUND + grip[1] - 2, G["buckle"])
    # The grate lights his own chest from above, warm on the coat just under the helmet.
    for x in range(-2, 11):
        for y in range(-53, -47):
            here = c.get(*P(x, y, b))
            if here[3] and here[:3] in (G["coat"][:3], G["coat_l"][:3], G["coat_d"][:3], G["strap"][:3]):
                t = max(0.0, 0.55 - (abs(x - 6) * 0.05 + (y + 53) * 0.09))
                c.px(*P(x, y, b), (int(here[0] + (200 - here[0]) * t), int(here[1] + (90 - here[1]) * t), int(here[2] + (40 - here[2]) * t), 255))
    c.finish(rim=(255, 150, 80), rim_strength=0.22, rim_side=1, glow_keep=GLOW_G)
    # Light and smoke go on after the outline: they have no edge. Light tints what it falls on.
    _warm(c, *P(6, -60, hb), halo + 4, (255, 140, 60), 0.5)
    _warm(c, nx + 3, ny, 4 + act * 3, (255, 160, 70), 0.6)
    rise = pose.get("smoke", 0)
    for k, (ox, oy) in enumerate(((-11, -78), (-12, -82), (-13, -86))):
        dy = -((rise + k * 2) % 6)
        x, y = P(ox, oy + dy, b)
        shade = (78, 72, 69, 255) if k < 2 else (62, 58, 56, 255)
        c.rect(x, y, x + 1 + (k > 0), y + 1, shade)
    ember = pose.get("ember", -1)
    if ember >= 0:
        c.px(*P(-10 + (ember % 2), -77 - ember * 3, b), G["ember"] if ember < 2 else G["orange"])
    return c.image


def _warm(c, cx, cy, radius, color, strength):
    """Glow as light on surfaces: opaque pixels near the source lean toward its colour."""
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            here = c.get(x, y)
            d = math.hypot(x - cx, (y - cy) * 1.2)
            if here[3] == 0 or d > radius or here[:3] in GLOW_G:
                continue
            t = strength * (1.0 - d / radius) ** 1.5
            c.px(x, y, (int(here[0] + (color[0] - here[0]) * t), int(here[1] + (color[1] - here[1]) * t), int(here[2] + (color[2] - here[2]) * t), 255))


def anima(image, x, y):
    """A rain spirit leaving the lantern: a bright cyan core, a soft body and a dripping tail."""
    px = image.load()
    def put(ax, ay, color):
        if 0 <= ax < image.width and 0 <= ay < image.height:
            px[ax, ay] = color
    for k in range(1, 9):
        put(x - k, y + (k // 3), S["orb_o"] if k > 3 else S["orb"])
        if k % 3 == 0:
            put(x - k, y + 2 + k // 3, S["drop"])
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            put(x + dx, y + dy, S["orb"])
    put(x, y, S["orb_c"])
    put(x + 2, y, S["orb_o"])
    put(x, y - 2, S["orb_o"])
    put(x, y + 2, S["orb_o"])


def concept(path):
    """The two of them side by side, big and at in-game size, idle and attacking."""
    from PIL import Image, ImageDraw, ImageFont
    board = Image.new("RGB", (1400, 860), (22, 30, 34))
    d = ImageDraw.Draw(board)
    try:
        title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 34)
        body = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 17)
        small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    except OSError:
        title = body = small = ImageFont.load_default()
    pieces = [
        (fogonero({"back_foot": (-4, 0), "front_foot": (5, 0), "heat": 1, "smoke": 2, "ember": 1}),
         fogonero({"back_foot": (-5, 0), "front_foot": (6, 0), "act": 1.0, "heat": 2, "smoke": 4, "flicker": 1}),
         "El Fogonero", ["Alimenta las calderas del patio. Nadie le ha visto la cara:", "su cabeza es una estufa de hierro y la única luz que tiene", "sale por la rejilla, como si ardiera por dentro.", "Lanza de hierro al rojo; el humo de la caldera a su espalda."]),
        (sereno({"back_foot": (-3, 0), "front_foot": (4, 0), "drop": 1, "sheen": 3}),
         sereno({"back_foot": (-3, 0), "front_foot": (4, 0), "pulse": 1, "drop": -1, "staff": 3, "staff_lift": 2}),
         "El Sereno", ["El vigilante de siempre: la cara perdida bajo el ala y una luz cian.", "Ataque nuevo, ánimas: alza el farol y suelta luces de lluvia que", "persiguen a las máquinas, revientan en aguacero, las empapan,", "las empujan y dejan un charco para tus rutinas."]),
    ]
    for index, (idle_art, act_art, name, lines) in enumerate(pieces):
        ox = 50 + index * 690
        d.text((ox, 30), name, font=title, fill=(228, 225, 208))
        for li, line in enumerate(lines):
            d.text((ox, 82 + li * 24), line, font=body, fill=(200, 205, 195))
        big = idle_art.resize((640, 640), Image.NEAREST).crop((80, 130, 500, 630))
        board.paste(big, (ox - 30, 200), big)
        d.text((ox + 430, 200), "en juego", font=small, fill=(150, 170, 165))
        board.paste(idle_art.resize((256, 256), Image.NEAREST), (ox + 380, 210), idle_art.resize((256, 256), Image.NEAREST))
        d.text((ox + 430, 480), "atacando", font=small, fill=(150, 170, 165))
        if index == 1:
            act_art = act_art.copy()
            anima(act_art, 99, 47)
        board.paste(act_art.resize((256, 256), Image.NEAREST), (ox + 380, 490), act_art.resize((256, 256), Image.NEAREST))
    board.save(path)


WALK = [  # (back foot x, lift), (front foot x, lift), bob, sway
    ((-6, 0), (6, 0), 1, -1), ((-4, 0), (4, 1), 0, -1), ((-1, 0), (1, 3), -1, 0), ((2, 1), (-2, 1), 0, 1),
    ((5, 0), (-5, 0), 1, 1), ((3, 1), (-3, 0), 0, 1), ((1, 3), (-1, 0), -1, 0), ((-2, 1), (2, 0), 0, -1),
]


def build():
    os.makedirs(OUT, exist_ok=True)
    made = {}
    idle_f = [fundidora({"back_foot": (-4, 0), "front_foot": (5, 0), "bob": (1 if i in (2, 3) else 0), "sway": (1 if i >= 3 else 0),
                         "flicker": i, "glint": i == 4, "head": (1 if i == 3 else 0), "ember": (i % 3) if i < 5 else -1}) for i in range(6)]
    walk_f = [fundidora({"back_foot": w[0], "front_foot": w[1], "bob": w[2], "sway": -w[3], "flicker": i}) for i, w in enumerate(WALK)]
    fire_f = [fundidora({"back_foot": (-5, 0), "front_foot": (6, 0), "act": a, "flicker": i, "sway": -1}) for i, a in enumerate((0.5, 1.0, 0.8, 0.3))]
    idle_s = [sereno({"back_foot": (-3, 0), "front_foot": (4, 0), "bob": (1 if i in (2, 3) else 0), "sway": (1 if i in (3, 4) else 0),
                      "swing": (0, 1, 1, 0, -1, -1)[i], "pulse": (0, 1, 1, 0, 0, 0)[i], "drop": i - 1, "sheen": i * 3, "glint": i == 2}) for i in range(6)]
    walk_s = [sereno({"back_foot": w[0], "front_foot": w[1], "bob": w[2], "sway": -w[3], "swing": -w[3] * 2, "pulse": i % 4 == 0,
                      "drop": -1, "sheen": i * 2, "staff": (0, 1, 2, 3, 2, 1, 0, -1)[i], "staff_lift": (0, 0, 0, 2, 3, 2, 0, 0)[i]}) for i, w in enumerate(WALK)]
    for name, frames in (("fundidora_idle", idle_f), ("fundidora_walk", walk_f), ("fundidora_fire", fire_f),
                         ("sereno_idle", idle_s), ("sereno_walk", walk_s)):
        strip = sheet(frames)
        strip.save(os.path.join(OUT, name + ".png"))
        made[name] = frames
    return made


if __name__ == "__main__":
    if "concept" in sys.argv:
        concept(os.path.join(ROOT, "authored", "survivor_20261016", "crew_concept.png"))
        sys.exit(0)
    frames = build()
    if len(sys.argv) > 1:
        from PIL import Image
        preview = Image.new("RGBA", (128 * 8, 128 * 5), (30, 36, 44, 255))
        for row, name in enumerate(("fundidora_idle", "fundidora_walk", "fundidora_fire", "sereno_idle", "sereno_walk")):
            for col, frame in enumerate(frames[name]):
                preview.paste(frame, (col * 128, row * 128), frame)
        preview = preview.resize((preview.width * 2, preview.height * 2), Image.NEAREST)
        preview.save(sys.argv[1])
        print("preview", sys.argv[1])
