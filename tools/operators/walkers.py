"""The three walkers of Sector 08, drawn like the crew and the specialists: dark masses, light on
the edges, one-pixel neon, the stolen seal as their eye or their tell. Facing right, ground at 118.

Quiltros: the block's stray dogs, still in the jumpers the neighbours knitted them.
Repartidor: a delivery rider the app never stopped dispatching.
Animita: the roadside shrine from the corner, walking on legs of melted wax.
"""
import math

from neon import Figure, Shape, hexc, mix, ramp
from cast import trace, CHROME
from machines import AQUA, RIM, ROSE, part, seal

GROUND = 118


def limb(f, points, radii, colors, lift=0.0, axis="h"):
    shape = Shape()
    for (a, b), (ra, rb) in zip(zip(points, points[1:]), zip(radii, radii[1:])):
        shape.limb(a, b, ra, rb)
    pixels = shape.pixels()
    f.paint(pixels, colors, axis=axis, lift=lift)
    return pixels


# --- Quiltro -------------------------------------------------------------------------------------
FUR = ramp("#0b0a0a", "#15110f", "#211a15", "#2e241c", "#3f3226", "#544332", "#6c5841")
KNIT = ramp("#0a1416", "#10201f", "#173029", "#1f4034", "#2a5341", "#386650")
YARN = hexc("#d8c79a")


def quiltro(pose=None):
    """A thin mutt in a hand-knitted jumper with a cream zigzag, one ear up and one ear down. The
    seal took both eyes. `run` 0..1 is the gallop phase; `bite` lunges with the jaw open; `shake`
    throws water off; `flee` tucks the tail and flattens the ears."""
    pose = pose or {}
    run = pose.get("run")
    bite = pose.get("bite", 0.0)
    shake = pose.get("shake", 0.0)
    flee = pose.get("flee", 0.0)
    snarl = pose.get("snarl", 0.0)
    f = Figure(light=(-0.55, 0.45, 0.7))
    stride = math.sin(run * math.tau) if run is not None else 0.0
    lift = abs(math.cos(run * math.tau)) * 1.5 if run is not None else 0.0
    lunge = bite * 5 - snarl * 2
    body_y = 100 - lift - bite * 1.0 + flee * 1.5
    rump = (49 + lunge * 0.4, body_y + flee * 1.0)
    chest = (72 + lunge, body_y)
    head = (82 + lunge * 1.3 - flee * 1.0, body_y - 9 + bite * 3 + flee * 6 + snarl * 2)

    # Far legs first, in shadow.
    def leg(hip, swing, near, front):
        knee = (hip[0] + swing * 0.6 + (1.5 if front else -2.5), hip[1] + 7)
        paw = (hip[0] + swing + (0.5 if front else -1.0), GROUND - (max(0.0, (swing if front else -swing)) * 0.5 if run is not None else 0))
        colors = FUR if near else FUR[:5]
        return limb(f, [hip, knee, paw], [2.6 if not front else 2.4, 1.6, 1.3], colors, lift=0.05 if near else -0.2)

    reach = 4.5 * stride
    leg((rump[0] + 2, rump[1] + 3), -reach - lunge * 0.6, False, False)
    leg((chest[0] - 2, chest[1] + 4), reach + lunge * 0.4, False, True)

    # Tail: up and curled, or tucked between the legs.
    if flee:
        tail = [(rump[0] - 3, rump[1] - 1), (rump[0] - 4, rump[1] + 6), (rump[0] - 1, rump[1] + 10)]
    else:
        wag = shake * 4 + pose.get("wag", 0.0) + (math.sin(run * math.tau * 2) * 1.5 if run is not None else 0)
        tail = [(rump[0] - 4, rump[1] - 2), (rump[0] - 9, rump[1] - 8 + wag * 0.3), (rump[0] - 6 + wag, rump[1] - 13)]
    limb(f, tail, [2.0, 1.5, 1.0], FUR, lift=0.1)

    # Body: a lean barrel, ribs showing behind the jumper.
    torso = Shape().ellipse((rump[0] + chest[0]) / 2, body_y + 0.5, (chest[0] - rump[0]) / 2 + 4, 6.0)
    torso.ellipse(*rump, 6.0, 6.0).ellipse(chest[0], chest[1] + 0.5, 6.4, 6.6)
    body = torso.pixels()
    f.paint(body, FUR, axis="v", lift=0.08)
    # The jumper: from the neck to the waist, ribbed, a cream zigzag across it.
    jumper = {(x, y) for x, y in body if rump[0] + 6 <= x <= chest[0] + 5}
    f.paint(jumper, KNIT, axis="v", lift=0.12)
    for x, y in jumper:
        if x % 2 == 0 and (x, y) in jumper:
            f.px(x, y, mix(f.get(x, y), (0, 0, 0, 255), 0.18))
    band = round(body_y) - 1
    for x in range(int(rump[0] + 7), int(chest[0] + 5)):
        y = band + (1 if (x // 2) % 2 else 0)
        if (x, y) in jumper:
            f.px(x, y, YARN)
    for x, y in jumper:
        if (x - 1, y) not in jumper and x > rump[0] + 5:
            f.px(x, y, KNIT[5])  # the jumper's cuffed edge at the waist
    leg((rump[0] + 3, rump[1] + 2), reach * 0.9 - lunge * 0.6, True, False)
    # Near foreleg: a cheap printed prosthesis below the elbow, white plastic and a tiny lamp.
    elbow = (chest[0] + 1 - reach * 0.1, chest[1] + 5)
    knee = (elbow[0] - reach * 0.6 + lunge * 0.3, elbow[1] + 6)
    paw = (elbow[0] - reach + lunge * 0.5, GROUND)
    limb(f, [(chest[0] - 1, chest[1] + 2), elbow], [2.6, 2.0], FUR, lift=0.1)
    limb(f, [elbow, knee, paw], [1.5, 1.3, 1.5], CHROME[3:], lift=0.15)
    f.px(knee[0] + 0.5, knee[1], AQUA["hi"], glow=True)

    # Head: narrow skull, long snout, one ear up, one flopped.
    skull = Shape().ellipse(head[0], head[1], 5.4, 4.6).pixels()
    jaw_drop = max(bite, snarl * 0.6) * 3.5
    bared = max(bite, snarl)
    snout = Shape().limb((head[0] + 3, head[1] + 1), (head[0] + 9, head[1] + 2 + bite), 3.0, 1.8).pixels()
    jaw = Shape().limb((head[0] + 2, head[1] + 3), (head[0] + 8, head[1] + 3.5 + jaw_drop), 1.8, 1.2).pixels()
    neck = Shape().limb((chest[0] + 1, chest[1] - 2), (head[0] - 1, head[1] + 2), 4.0, 3.2).pixels()
    f.paint(neck, FUR, axis="h", lift=0.05)
    ear_back = flee * 4
    f.paint(part([(head[0] - 3, head[1] - 3), (head[0] - 5 - ear_back, head[1] + 2), (head[0] - 1, head[1] - 1)]), FUR[:4], axis="h")
    f.paint(jaw, FUR, axis="h", lift=0.0)
    f.paint(skull | snout, FUR, axis="h", lift=0.15)
    if bared:
        for k in range(3):
            f.px(head[0] + 5 + k * 1.3, head[1] + 3 + jaw_drop * 0.3, (220, 214, 200, 255))  # teeth
        f.fill({(x, y) for x, y in Shape().limb((head[0] + 3, head[1] + 3), (head[0] + 7, head[1] + 3 + jaw_drop * 0.6), 1.0, 0.8).pixels()}, (40, 8, 14, 255))
    f.paint(part([(head[0] - 1, head[1] - 3), (head[0] + 1 - ear_back, head[1] - 10 + ear_back * 1.5), (head[0] + 3, head[1] - 3)]), FUR, axis="h", lift=0.2)
    # The other ear never stood up: it folds over and hangs by the cheek.
    f.paint(part([(head[0] - 2, head[1] - 4), (head[0] + 1, head[1] - 5), (head[0] + 0.5 - ear_back, head[1] + 1.5)]), FUR[1:6], axis="h", lift=0.1)
    # A collar made of a phone-charger cable, with a tag lamp.
    for k in range(-3, 4):
        f.px(head[0] - 3 + k * 0.3, head[1] + 4 + k, CHROME[5])
    f.px(head[0] - 2.4, head[1] + 7.5, AQUA["hi"], glow=True)
    f.px(head[0] + 9.6, head[1] + 1.8 + bite, (6, 5, 6, 255))  # nose
    f.glow(head[0] + 2.5, head[1] - 0.5, 5 + snarl * 2, ROSE["mid"], 0.35 + bared * 0.35)
    f.finish(rim=RIM, rim_strength=(0.45, 0.3))
    f.px(head[0] + 2.4, head[1] - 0.8, ROSE["core"] if bared else ROSE["hi"], glow=True)
    f.px(head[0] + 4.2, head[1] - 0.9, ROSE["mid"], glow=True)
    if shake:
        # Water flung off in an arc either side.
        for k in range(14):
            a = k / 14 * math.pi + 0.2 * shake
            r = 12 + (k % 3) * 3
            f.px((rump[0] + chest[0]) / 2 + math.cos(a) * r * 1.3, body_y - math.sin(a) * r * 0.8, AQUA["hi"] if k % 2 else AQUA["mid"], glow=True)
    return f.image


# --- Repartidor ----------------------------------------------------------------------------------
from cast import knee, boot, soles, FLAT_BOOT, PANTS, STRAP, SKIN, MASK

PONCHO = ramp("#05080a", "#0a1013", "#10191c", "#172427", "#203234", "#2c4544")
CUBE = ramp("#0c0c10", "#16161c", "#22222a", "#30303a", "#42424e", "#5a5a68")
SOLE = ramp("#6d7380", "#a9afba", "#dfe3ea")
VISOR = ramp("#05060a", "#0c0e16", "#1a1e2c", "#3a4058")


def repartidor(pose=None):
    """A delivery rider the app never stopped dispatching: bike helmet and visor, a rain poncho
    pulled over a thermal cube backpack, the phone strapped to his forearm. The order he carries is
    the seal. `run` 0..1 is the stride; `ping` raises the phone (it burns rose); `dash` throws him
    flat out along the lane; `stumble` folds him over with the cube's lid sprung open."""
    pose = pose or {}
    run = pose.get("run")
    ping = pose.get("ping", 0.0)
    dash = pose.get("dash", 0.0)
    stumble = pose.get("stumble", 0.0)
    f = Figure(light=(-0.6, 0.35, 0.72))
    p = run * math.tau if run is not None else 0.0
    b = (1 if abs(math.cos(p)) > 0.7 else 0) if run is not None else 0
    lean = 0.22 if run is not None else 0.05
    lean = lean + dash * 0.45 + stumble * 0.75 - ping * 0.1
    hip = (64 - dash * 4 - stumble * 2, 88 + b + stumble * 4 + dash * 5)

    def up(dx, dy):
        """A point on the torso, `dy` up from the hip, tipped forward by the lean."""
        return (hip[0] + dx * math.cos(lean) + dy * math.sin(lean), hip[1] - dy * math.cos(lean) + dx * math.sin(lean))

    # Legs: a stride while running, a long split in the dash, knees buckled in the stumble.
    if run is not None:
        nf = (hip[0] + 7 * math.cos(p), 115 - 4 * max(0.0, -math.sin(p)))
        ff = (hip[0] + 7 * math.cos(p + math.pi), 115 - 4 * max(0.0, math.sin(p)))
    elif dash:
        nf, ff = (hip[0] + 15, 115), (hip[0] - 14, 112)
    elif stumble:
        nf, ff = (hip[0] + 5, 115), (hip[0] - 4, 115)
    else:
        nf, ff = (hip[0] - 2, 115), (hip[0] + 5, 115)
    nh, fh = (hip[0] - 1, hip[1]), (hip[0] + 2, hip[1])
    nk, fk = knee(nh, nf, 14.0, 14.0), knee(fh, ff, 14.0, 14.0)
    f.paint(Shape().limb(fh, fk, 3.2, 2.5).limb(fk, ff, 2.5, 1.9).pixels(), PANTS, axis="h", lift=-0.1)
    f.paint(boot(ff, FLAT_BOOT), SOLE[:2] + STRAP[:2], axis="h", lift=-0.1)
    near_leg = Shape().limb(nh, nk, 3.5, 2.7).limb(nk, nf, 2.7, 2.0).pixels()
    f.paint(near_leg, PANTS, axis="h")
    # A reflective band around the near calf, the only thing the rain lets drivers see.
    ck = ((nk[0] + nf[0]) / 2, (nk[1] + nf[1]) / 2 + 1)
    for x, y in near_leg:
        if abs(y - ck[1]) < 0.8:
            f.px(x, y, AQUA["mid"], glow=True)
    near_boot = boot(nf, FLAT_BOOT)
    f.paint(near_boot, STRAP, axis="h", gloss=0.2)
    soles(f, near_boot, SOLE, lambda x: (lambda f, x, y: f.px(x, y, SOLE[2])))

    # The cube: a thermal backpack as wide as his back, on its own straps, the app's logo
    # in a neon stripe. Drawn first so the poncho hangs in front of it.
    c0 = up(-6, 10)
    cube_pts = [up(-19, 11), up(-5, 11), up(-5, 32), up(-19, 32)]
    cube = Shape().poly(cube_pts).pixels()
    f.paint(cube, CUBE, axis="h", lift=0.1, gloss=0.15)
    # The lid: shut, or sprung open on the stumble with the order inside burning.
    if stumble:
        hinge = up(-5, 32)
        lid = Shape().poly([hinge, (hinge[0] + 2, hinge[1] - 4), (hinge[0] - 12, hinge[1] - 10), up(-19, 32)]).pixels()
        f.paint(lid, CUBE, axis="v", lift=0.2)
    else:
        lid = Shape().poly([up(-19.5, 31), up(-4.5, 31), up(-4.5, 33), up(-19.5, 33)]).pixels()
        f.paint(lid, CUBE[1:], axis="v", lift=0.25)
    # The logo stripe: three chevrons, the app's colours.
    mid = up(-11, 22)
    trace(f, [up(-16, 19), up(-6, 19)], AQUA["mid"], clip=cube)
    for k in range(3):
        cx, cy = up(-14 + k * 3, 23)
        trace(f, [(cx, cy - 1.5), (cx + 1.5, cy), (cx, cy + 1.5)], AQUA["hi"], clip=cube)

    # Poncho: a dark, wet sheet from the shoulders, hood down, flaring back in the run.
    flare = 3 + (2 if run is not None else 0) + dash * 6
    poncho = Shape().poly([up(-5, 30), up(5, 30), up(9.5, 22), up(9, 4), up(7, -2), up(-6 - flare, -3), up(-7, 14)]).pixels()
    f.paint(poncho, PONCHO, axis="h", fall=0.12, lift=0.06, gloss=0.25)
    for x, y in poncho:  # a seam down the front, wet streaks
        if (x * 7 + y * 3) % 11 == 0:
            f.px(x, y, mix(f.get(x, y), AQUA["dim"], 0.35))
    # Backpack strap over the shoulder.
    trace(f, [up(-4, 29), up(2, 26), up(3, 14)], STRAP[3], clip=poncho, glow=False)

    # Head: a cycling helmet with a smoked visor; the jaw shows below it.
    head = up(1.5, 37)
    jaw = Shape().ellipse(head[0] + 1.5, head[1] + 2.2, 3.2, 3.0).pixels()
    f.paint(jaw, SKIN[:4], axis="h", lift=0.1)
    neck = Shape().limb(up(0, 30), (head[0], head[1] + 3), 2.4, 2.0).pixels()
    f.paint(neck, SKIN[:3], axis="h")
    helmet = Shape().ellipse(head[0] - 0.5, head[1] - 2.2, 6.0, 4.6).poly([(head[0] - 6.5, head[1] - 2), (head[0] - 8, head[1] + 1), (head[0] - 3, head[1] + 0.5)]).pixels()
    helmet = {(x, y) for x, y in helmet if y <= head[1] + 1}
    f.paint(helmet, MASK, axis="h", gloss=0.35, lift=0.1)
    for k in range(-2, 3):  # vents
        f.px(head[0] - 1 + k * 2, head[1] - 5.5 + abs(k) * 0.4, MASK[0])
    visor = Shape().poly([(head[0] + 1, head[1] - 1.5), (head[0] + 6.4, head[1] - 0.8), (head[0] + 5.8, head[1] + 1.6), (head[0] + 1, head[1] + 1.2)]).pixels()
    f.paint(visor, VISOR, axis="v", gloss=0.6)
    # Chin strap.
    trace(f, [(head[0] - 1.5, head[1] + 0.5), (head[0] + 0.5, head[1] + 4.5)], STRAP[2], glow=False)

    # Near arm with the phone on the forearm. Running it pumps; on the ping it comes up to the
    # visor; in the dash it trails back.
    shoulder = up(3, 27)
    if ping:
        elbow, wrist = (shoulder[0] + 4, shoulder[1] + 6), (shoulder[0] + 7, shoulder[1] - 1)
    elif dash:
        elbow, wrist = (shoulder[0] - 5, shoulder[1] + 5), (shoulder[0] - 11, shoulder[1] + 6)
    elif stumble:
        elbow, wrist = (shoulder[0] + 2, shoulder[1] + 7), (shoulder[0] + 4, shoulder[1] + 13)
    else:
        sw = -5 * math.cos(p) if run is not None else 0.5
        elbow, wrist = (shoulder[0] + sw * 0.4, shoulder[1] + 7), (shoulder[0] + sw + 3, shoulder[1] + 11 - abs(sw) * 0.6)
    arm = Shape().limb(shoulder, elbow, 2.6, 2.2).limb(elbow, wrist, 2.2, 1.8).pixels()
    f.paint(arm, PONCHO, axis="h", lift=0.12)
    f.paint(Shape().ellipse(wrist[0] + (wrist[0] - elbow[0]) * 0.15, wrist[1] + (wrist[1] - elbow[1]) * 0.15, 1.6, 1.6).pixels(), SKIN[:4], axis="h")
    # The phone: a slab on a strap across the forearm.
    ph = ((elbow[0] + wrist[0]) / 2, (elbow[1] + wrist[1]) / 2)
    screen = Shape().ellipse(ph[0], ph[1], 1.8, 1.4).pixels()
    f.fill(screen, (10, 12, 18, 255))
    f.finish(rim=RIM, rim_strength=(0.5, 0.3))
    glow = ROSE if ping or dash else AQUA
    f.glow(ph[0], ph[1], 7 if ping else 4, glow["mid"], 0.6 if ping else 0.3)
    for x, y in screen:
        f.px(x, y, glow["hi"], glow=True)
    f.px(ph[0], ph[1], glow["core"] if ping else glow["hi"], glow=True)
    # The visor catches the phone: a rose slit when it is calling him.
    vy = head[1] - 0.2
    trace(f, [(head[0] + 2.5, vy), (head[0] + 5.6, vy + 0.3)], ROSE["hi"] if ping or dash else AQUA["dim"])
    if stumble:
        # The order: the seal, glowing up out of the open cube.
        sx, sy = up(-11, 31)
        f.glow(sx, sy - 2, 9, ROSE["mid"], 0.5)
        seal(f, sx, sy - 1.5, 1.2)
    if dash:
        for k in range(6):
            y = hip[1] - 4 - k * 5
            trace(f, [(hip[0] - 34 + k * 2, y), (hip[0] - 22 + k * 2, y)], ROSE["dim"] if k % 2 else AQUA["dim"], glow=False)
    return f.image


# --- Animita -------------------------------------------------------------------------------------
from cast import ORANGE, VIOLET

TIN = ramp("#07090d", "#0e1218", "#161c25", "#202935", "#2d3949", "#3e4d61", "#55677c")
WAX = ramp("#2a241c", "#4a4033", "#71644f", "#9d8e72", "#c7b896", "#e9dfc4")
SMOKE = ramp("#2a2c34", "#40434e", "#5c5f6b")
PHOTO = ramp("#4c4a46", "#7a776f", "#aaa69a")


def animita(pose=None):
    """The roadside shrine from the corner, walking on the wax of every candle anyone lit in it.
    A tin chapel with a glass door: candles, a faded photo, plastic flowers. The seal sleeps where
    the saint's picture was. `walk` 0..1 waddles; `lit` 0..1 is how hard its candles burn (the
    heat that makes it tough); `doused` opens the door and shows the seal; `sputter` is the
    flicker before it lights itself again."""
    pose = pose or {}
    walk = pose.get("walk")
    doused = pose.get("doused", 0.0)
    sputter = pose.get("sputter", 0.0)
    lit = pose.get("lit", 0.0 if doused and not sputter else 1.0)
    heat = pose.get("heat", 0.0)
    tick = pose.get("frame", 0)
    f = Figure(light=(-0.55, 0.35, 0.75))
    p = walk * math.tau if walk is not None else 0.0
    sway = math.sin(p) * 1.2 if walk is not None else 0.0
    b = (1 if abs(math.cos(p)) > 0.7 else 0) if walk is not None else 0
    x0, y0 = 46 + sway, 62 + b  # top-left of the front face

    # Wax legs: six of them, pale and drippy, each ending in a splat. Far three first.
    def leg(hx, phase, near):
        lift = max(0.0, math.sin(p + phase)) * 3 if walk is not None else 0.0
        step = math.cos(p + phase) * 3 if walk is not None else 0.0
        splay = (hx - (x0 + 17)) * 0.25
        top = (hx, y0 + 31)
        mid = (hx + step * 0.4 + splay * 0.6 + (1.5 if near else -1), y0 + 40 - lift * 0.5)
        foot = (hx + step + splay, GROUND - lift)
        colors = WAX[:5] if near else WAX[:3]
        legpx = limb(f, [top, mid, foot], [1.8, 2.6, 1.5], colors, lift=0.05 if near else -0.25, axis="h")
        # Drips: blobs hanging off the leg.
        for k in range(2):
            t = 0.35 + k * 0.3
            dx, dy = top[0] + (foot[0] - top[0]) * t, top[1] + (foot[1] - top[1]) * t
            f.paint(Shape().limb((dx + (2.2 if k else -2.0), dy), (dx + (2.4 if k else -2.2), dy + 2.5 + k), 0.9, 0.6).pixels(), colors, axis="h", lift=0.1)
        if lift < 0.5:
            f.paint(Shape().ellipse(foot[0] + 0.5, GROUND - 0.5, 3.6, 1.3).pixels(), colors, axis="v", lift=0.15)
        return legpx

    for i, hx in enumerate((51, 63, 75)):
        leg(hx + 3, i * 2.1 + math.pi, False)

    # The chapel: a narrow side wall on the left, the front face toward the light, a gable roof.
    side = Shape().poly([(x0 - 6, y0 + 3), (x0, y0), (x0, y0 + 32), (x0 - 6, y0 + 33)]).pixels()
    f.paint(side, TIN[:5], axis="h", lift=-0.1)
    front = Shape().poly([(x0, y0), (x0 + 34, y0), (x0 + 34, y0 + 32), (x0, y0 + 32)]).pixels()
    f.paint(front, TIN, axis="h", lift=0.05, fall=0.1)
    # Chipped paint: the old white shows in flakes, and rust bleeds from the corners.
    for x, y in front:
        h = (x * 31 + y * 17) % 23
        if h == 0 and (x + y) % 3 == 0:
            f.px(x, y, (96, 104, 114, 255))
        elif h == 1 and (y - y0) > 20:
            f.px(x, y, (74, 40, 26, 255))
    roof = Shape().poly([(x0 - 3, y0 + 1), (x0 + 17, y0 - 13), (x0 + 37, y0 + 1), (x0 + 34, y0 + 2), (x0 + 17, y0 - 10), (x0, y0 + 2)]).pixels()
    gable = Shape().poly([(x0, y0 + 1), (x0 + 17, y0 - 10), (x0 + 34, y0 + 1)]).pixels()
    f.paint(gable, TIN[1:], axis="v", lift=0.0)
    side_roof = Shape().poly([(x0 - 9, y0 + 4), (x0 + 14, y0 - 12), (x0 + 17, y0 - 13), (x0 - 3, y0 + 1)]).pixels()
    f.paint(side_roof, TIN[:5], axis="v", lift=0.1)
    f.paint(roof, TIN, axis="v", lift=0.3, gloss=0.2)
    # The little cross on the apex.
    cx, cy = x0 + 17, y0 - 13
    f.paint(Shape().limb((cx, cy), (cx, cy - 7), 0.8, 0.8).pixels() | Shape().limb((cx - 2.5, cy - 5), (cx + 2.5, cy - 5), 0.7, 0.7).pixels(), CHROME[2:], axis="h", gloss=0.3)

    # The glass door, inset, with what it keeps behind it.
    gx0, gy0, gx1, gy1 = x0 + 6, y0 + 6, x0 + 28, y0 + 28
    niche = Shape().poly([(gx0, gy0 + 3), (gx0 + 11, gy0 - 2), (gx1, gy0 + 3), (gx1, gy1), (gx0, gy1)]).pixels()
    f.fill(niche, (8, 7, 10, 255))
    # Back wall: the photo (the person the shrine was for), plastic flowers, candles.
    photo = Shape().poly([(gx0 + 8, gy0 + 3), (gx0 + 14, gy0 + 3), (gx0 + 14, gy0 + 11), (gx0 + 8, gy0 + 11)]).pixels()
    if doused:
        f.glow(gx0 + 11, gy0 + 7, 10, ROSE["mid"], 0.55)
    else:
        f.paint(photo, PHOTO, axis="v", lift=0.1)
        f.paint(Shape().ellipse(gx0 + 11, gy0 + 6, 1.6, 1.8).pixels(), PHOTO[:2], axis="h")
        f.paint(Shape().ellipse(gx0 + 11, gy0 + 10, 2.6, 1.4).pixels(), PHOTO[:2], axis="h")
    for k, (fx, fy, col) in enumerate([(gx0 + 3, gy0 + 9, VIOLET["mid"]), (gx0 + 4.5, gy0 + 7, (230, 200, 90, 255)), (gx0 + 18, gy0 + 8, VIOLET["hi"]), (gx0 + 19, gy0 + 10, (230, 200, 90, 255))]):
        trace(f, [(fx, fy + 1), (fx + (0.5 if k % 2 else -0.5), gy1 - 4)], (40, 70, 44, 255), glow=False)
        f.px(fx, fy, col)
        f.px(fx + 1, fy, mix(col, (0, 0, 0, 255), 0.3))
    flames = []
    for k, hx in enumerate((gx0 + 4, gx0 + 8, gx0 + 12, gx0 + 16, gx0 + 19)):
        h = 3 + (k * 5) % 3
        f.paint(Shape().poly([(hx - 0.8, gy1 - h), (hx + 0.8, gy1 - h), (hx + 0.8, gy1), (hx - 0.8, gy1)]).pixels(), WAX[2:], axis="h", lift=0.2)
        flames.append((hx, gy1 - h - 1.5))
    # The roof candles: stubs on the ridge, their wax running down the tin.
    for k, (rx, ry) in enumerate([(x0 + 6, y0 - 4), (x0 + 28, y0 - 4), (x0 + 12, y0 - 8)]):
        f.paint(Shape().poly([(rx - 1, ry - 4), (rx + 1, ry - 4), (rx + 1, ry + 1), (rx - 1, ry + 1)]).pixels(), WAX, axis="h", lift=0.2)
        f.paint(Shape().limb((rx, ry + 1), (rx + (1 if k % 2 else -1), ry + 4 + k), 0.8, 0.6).pixels(), WAX[1:], axis="h")
        flames.append((rx, ry - 5.5))
    # Wax running off the eaves and down the front, feeding the legs.
    for k, (dx, length) in enumerate([(1, 6), (31, 8)]):
        f.paint(Shape().limb((x0 + dx, y0 + 1), (x0 + dx + 0.3, y0 + 1 + length), 0.8, 0.6).pixels(), WAX[1:5], axis="h", lift=0.15)
    f.paint(Shape().poly([(x0 - 1, y0 + 30), (x0 + 35, y0 + 30), (x0 + 36, y0 + 34), (x0 - 2, y0 + 34)]).pixels(), WAX, axis="v", lift=0.1)

    # Near three legs over the base.
    for i, hx in enumerate((48, 60, 72)):
        leg(hx + 2, i * 2.1, True)

    if heat:
        ice = Shape().poly([(x0 + 44, GROUND - 22), (x0 + 52, GROUND - 25), (x0 + 55, GROUND), (x0 + 42, GROUND)]).pixels()
        f.paint(ice, ramp("#1b4a5c", "#2f7c92", "#58b4c8", "#9fe2ee"), axis="h", lift=0.2, gloss=0.5)
        # The side facing the heat slumps and runs into a puddle.
        f.paint(Shape().ellipse(x0 + 44, GROUND - 0.5, 7, 1.4).pixels(), ramp("#1b4a5c", "#2f7c92", "#58b4c8"), axis="v", lift=0.3)
        for k in range(3):
            f.paint(Shape().limb((x0 + 43 + k * 0.5, GROUND - 20 + k * 6), (x0 + 42.5 + k * 0.5, GROUND - 16 + k * 6), 0.8, 0.6).pixels(), ramp("#2f7c92", "#9fe2ee"), axis="h")
    # Glass: a frame and a diagonal sheen; on the douse the door swings open on its hinge.
    if doused:
        door = Shape().poly([(gx1, gy0 + 3), (gx1 + 7, gy0 + 1), (gx1 + 7, gy1 + 2), (gx1, gy1)]).pixels()
        f.paint(door, TIN[2:], axis="h", lift=0.1, gloss=0.4)
    f.finish(rim=RIM, rim_strength=(0.45, 0.28))
    frame_px = [(gx0, gy0 + 3), (gx0 + 11, gy0 - 2), (gx1, gy0 + 3), (gx1, gy1), (gx0, gy1), (gx0, gy0 + 3)]
    trace(f, frame_px, AQUA["dim"], glow=False)
    if not doused:
        for k in range(8):
            f.px(gx0 + 4 + k, gy0 + 12 - k, (120, 150, 170, 255))
            f.px(gx0 + 6 + k, gy0 + 15 - k, (70, 90, 110, 255))
    else:
        seal(f, gx0 + 11, gy0 + 7, 1.4)
        # Smoke from every wick.
        for k, (fx, fy) in enumerate(flames):
            for j in range(5):
                f.px(fx + math.sin(j * 1.3 + k + tick * 0.9) * 1.4, fy - j * 1.6 - tick % 2, SMOKE[min(2, j // 2)])
    # Candle flames: steady when lit, small and stuttering on the sputter.
    if lit > 0:
        for k, (fx, fy) in enumerate(flames):
            on = not sputter or (k * 3 + int(sputter * 7)) % 4 != 0
            if not on:
                continue
            tall = 1 if sputter or (k + tick) % 3 == 0 else 2
            f.glow(fx, fy, 6 if not sputter else 3, ORANGE["mid"], 0.35 * lit)
            f.px(fx, fy, ORANGE["core"] if not sputter else ORANGE["hi"], glow=True)
            f.px(fx, fy - 1, ORANGE["hi"], glow=True)
            if tall > 1:
                f.px(fx, fy - 2, ORANGE["mid"], glow=True)
        if not sputter:
            # The heat it walks in: a low amber haze and a few lifting sparks.
            f.glow(x0 + 17, y0 + 16, 26 + heat * 8, ORANGE["dim"], (0.22 + heat * 0.2) * lit)
            if heat:
                # Heat shimmer off the roof, and the ice wall beside it going to water.
                for k in range(4):
                    for j in range(9):
                        f.px(x0 + 4 + k * 9 + math.sin(j * 0.9 + k) * 1.2, y0 - 16 - j * 1.3, mix(ORANGE["mid"], (0, 0, 0, 255), 0.5 + j * 0.05))
            for k in range(7):
                f.px(x0 - 4 + k * 7, y0 - 6 - (k * 5 + tick * 3) % 9, ORANGE["mid"] if k % 2 else ORANGE["hi"], glow=True)
    return f.image


POSES = {
    "quiltro": [("en jauría", {}), ("corre", {"run": 0.3}), ("pela los dientes", {"bite": 1.0}), ("se sacude", {"shake": 1.0}), ("huye", {"flee": 1.0})],
    "repartidor": [("corre", {"run": 0.0}), ("le suena la app", {"ping": 1.0}), ("embiste", {"dash": 1.0}), ("tropieza", {"stumble": 1.0})],
    "animita": [("camina", {"walk": 0.25}), ("derrite el hielo", {"heat": 1.0}), ("apagada", {"doused": 1.0}), ("vuelve a prender", {"doused": 1.0, "sputter": 0.5})],
}


def sheet(path):
    import sys
    from PIL import Image, ImageDraw, ImageFont
    from cast import backdrop
    from machines import danger
    board = backdrop((1600, 1240)).crop((0, 0, 1600, 1060))
    d = ImageDraw.Draw(board)
    face = "/System/Library/Fonts/HelveticaNeue.ttc"
    title = ImageFont.truetype(face, 40, index=1)
    name = ImageFont.truetype(face, 30, index=1)
    tag = ImageFont.truetype(face, 17)
    body = ImageFont.truetype(face, 15)
    small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    rose = (255, 70, 110)
    d.text((40, 26), "LOS QUE CAMINAN", font=title, fill=rose)
    d.text((40, 76), "El grueso de la noche: lo que el sello encontró tirado en la cuadra. Perros, un repartidor, una animita.",
           font=tag, fill=(200, 205, 220))
    d.text((40, 98), "Cada uno tiene un aviso que se lee de lejos y una respuesta distinta al fuego de Brasa y al agua de Sereno.",
           font=tag, fill=(200, 205, 220))
    d.text((1300, 112), "todos a la misma escala", font=small, fill=(140, 150, 175))
    rows = [
        ("QUILTROS", "carne de cañón · cazan en jauría", (214, 196, 150), quiltro, (30, 64, 102, 121), 230, 212, POSES["quiltro"],
         ["Los perros de la cuadra, con los chalecos que les tejieron las vecinas.", "A uno le imprimieron una pata. El sello les tomó los ojos, no las mañas.",
          "Llegan en jauría y rodean. Antes de morder pelan los dientes", "y los ojos se les encienden: ese es el aviso.",
          "Del fuego de Brasa huyen aullando. Mojados por las ánimas se paran", "a sacudirse: una ventana gratis. Y siguen royendo el hielo."],
         [None, None, None, None, None]),
        ("REPARTIDOR", "corredor · la app nunca dejó de mandarlo", (140, 230, 200), repartidor, (18, 34, 108, 125), 290, 280, POSES["repartidor"],
         ["Un repartidor al que la app nunca dejó de asignarle pedidos.", "El pedido va en la mochila térmica, y el pedido es el sello.",
          "Cuando el teléfono le suena en rosa marca un carril corto y,", "medio segundo después, embiste unos seis metros: daño y empujón.",
          "Después tropieza y la tapa se abre: el sello queda a la vista.", "En hielo o agua resbala; si choca contra un muro, queda aturdido."],
         [None, "lane", "lane", None]),
        ("ANIMITA", "tanque · arde mientras le queden velas", (255, 170, 90), animita, (22, 36, 106, 121), 290, 280, POSES["animita"],
         ["La animita de la esquina, caminando sobre la cera de sus velas.", "La foto es de quien murió ahí; el sello duerme donde iba el santo.",
          "Encendida recibe menos daño y su calor derrite los muros de hielo.", "Empuja a quien la toca. El fuego de Brasa la vuelve a prender.",
          "El agua de las ánimas le apaga las velas: la puerta se abre y el sello", "queda expuesto unos segundos, hasta que chisporrotea y se prende."],
         [None, None, None, None]),
    ]
    scale = 3
    top = 150
    for title_, tagline, accent, draw, crop, height, step, poses, lines, warns in rows:
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
            image.alpha_composite(draw(pose))
            cell = image.crop(crop)
            big = cell.resize((cell.width * scale, cell.height * scale), Image.NEAREST)
            x = 510 + c * step
            board.paste(big, (x, floor - big.height + 6), big)
            d.text((x + 8, floor + 10), label, font=small, fill=(150, 160, 185))
        top += height + 30
    board.save(path)


if __name__ == "__main__":
    import sys
    sheet(sys.argv[1] if len(sys.argv) > 1 else "/tmp/caminantes.png")
