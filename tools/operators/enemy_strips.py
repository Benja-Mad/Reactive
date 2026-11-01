"""Animation strips for the three specialists, written into materials/enemies with a manifest the
Godot side reads (frames, fps, loop and the anchor texel that sits on the machine's origin).

    python3 tools/operators/enemy_strips.py

The Novia's veil is see-through in the concept art; the game's card shader cuts anything under
half alpha, so translucent texels are flattened over the night here and kept opaque.
The Raya is drawn from five headings (away, three-quarters away, across, three-quarters toward,
toward); the game mirrors them for the other three, which gives eight directions.
"""
import json
import math
import os

from PIL import Image

import machines as m
import walkers as w

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "materials", "enemies")
NIGHT = (14, 16, 24)
HEADINGS = (-90, -45, 0, 45, 90)
# Smaller than the concept sheet (1.7) so the across-screen heading, tail and all, fits a frame.
SCALE = 1.45


def opaque(image):
    px = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = px[x, y]
            if 0 < a < 255:
                t = a / 255.0
                px[x, y] = (int(r * t + NIGHT[0] * (1 - t)), int(g * t + NIGHT[1] * (1 - t)), int(b * t + NIGHT[2] * (1 - t)), 255)
    return image


def lerp(a, b, t):
    if isinstance(a, tuple):
        return tuple(lerp(a[i], b[i], t) for i in range(len(a)))
    return a + (b - a) * t


def add(p, dx, dy):
    return (p[0] + dx, p[1] + dy)


def gargola_frames():
    perch, crouch = m.GARGOYLE["perch"], m.GARGOYLE["crouch"]
    prowl = {k: lerp(perch[k], crouch[k], 0.35) for k in perch}
    walk = []
    for i in range(6):
        p = i / 6 * math.tau
        s, c = math.sin(p), math.cos(p)
        k = dict(prowl)
        k["hand"] = add(prowl["hand"], 4 * s, -2.2 * max(0.0, c))
        k["far_hand"] = add(prowl["hand"], -7 - 4 * s, -2.2 * max(0.0, -c))
        k["foot"] = add(prowl["foot"], -4 * s, -2.0 * max(0.0, -c))
        k["far_foot"] = add(prowl["foot"], 8 + 4 * s, -2.0 * max(0.0, c))
        k["shoulder"] = add(prowl["shoulder"], 0, abs(s) * 1.0)
        k["head"] = add(prowl["head"], 0.4 * s, abs(s) * 1.0)
        walk.append(m.gargola({"pose": "perch", "adjust": k}))
    breath = [0, 0.5, 1.0, 0.5]
    idle = [m.gargola({"pose": "perch", "adjust": {"shoulder": add(perch["shoulder"], 0, b), "head": add(perch["head"], 0, b)}}) for b in breath]
    crouching = [m.gargola({"pose": "crouch", "adjust": {"shoulder": add(crouch["shoulder"], 0, b)}}) for b in (0, 0.7)]
    air = [m.gargola({"pose": "air", "adjust": {"wing": w}}) for w in (1.0, 0.8)]
    opened = [m.gargola({"pose": "open", "adjust": {"open": o}}) for o in (1.0, 0.8, 1.0)]
    return {"Idle": (idle, 5, True), "Walk": (walk, 10, True), "Crouch": (crouching, 12, True), "Air": (air, 12, True), "Open": (opened, 8, True)}


def bob(image, rise):
    """Lift a whole frame by `rise` texels: she floats, so the hem drifts up and down."""
    moved = Image.new("RGBA", image.size, (0, 0, 0, 0))
    moved.paste(image, (0, -rise))
    return moved


def novia_frames():
    anims = {}
    for charge in range(4):
        anims["Wander%d" % charge] = ([bob(m.novia({"charge": charge, "frame": i}), (0, 1, 1, 0)[i]) for i in range(4)], 5, True)
    anims["Drink"] = ([m.novia({"pose": "drink", "charge": 1, "frame": i}) for i in range(3)], 9, True)
    anims["Aim"] = ([m.novia({"pose": "aim", "charge": 3, "frame": i}) for i in range(3)], 10, True)
    anims["Wail"] = ([m.novia({"pose": "wail", "charge": 3, "frame": i, "jet": False}) for i in range(3)], 14, True)
    return anims


def raya_frames():
    """Per heading, centred in the frame; the anchor is where the model's origin was drawn."""
    anims = {}
    for d, heading in enumerate(HEADINGS):
        yaw = -math.radians(heading)
        fly = (64, 64)
        for _ in range(3):
            box = m.raya({"yaw": yaw, "origin": fly, "scale": SCALE}).getbbox()
            fly = (int(round(fly[0] + 64 - (box[0] + box[2]) / 2)), int(round(fly[1] + 64 - (box[1] + box[3]) / 2)))
        land = (fly[0], 92)
        for _ in range(3):
            box = m.raya({"yaw": yaw, "origin": land, "grounded": True, "flap": 0.12, "curl": 0.2, "scale": SCALE}).getbbox()
            land = (land[0], int(round(land[1] - max(0, box[3] - 123) + max(0, 4 - box[1]))))
        glide = [m.raya({"yaw": yaw, "origin": fly, "scale": SCALE, "flap": 0.45 + 0.4 * math.sin(i / 4 * math.tau)}) for i in range(4)]
        lock = [m.raya({"yaw": yaw, "origin": fly, "lock": 1.0, "curl": 1.0, "flap": f, "scale": SCALE}) for f in (0.0, 0.1)]
        dive = [m.raya({"yaw": yaw, "origin": fly, "fold": 0.6, "pitch": 0.7, "lock": 1.0, "flap": f, "scale": SCALE}) for f in (-0.15, -0.05)]
        beached = [m.raya({"yaw": yaw, "origin": land, "grounded": True, "flap": f, "curl": c, "scale": SCALE}) for f, c in ((0.0, 0.0), (0.12, 0.2), (0.0, 0.0))]
        anims["Glide%d" % d] = (glide, 8, True, fly)
        anims["Lock%d" % d] = (lock, 10, True, fly)
        anims["Dive%d" % d] = (dive, 12, True, fly)
        anims["Grounded%d" % d] = (beached, 4, True, land)
    return anims


def write(creature, anims, anchor=None):
    folder = os.path.join(OUT, creature)
    os.makedirs(folder, exist_ok=True)
    manifest = {}
    for name, spec in anims.items():
        frames, fps, loop = spec[:3]
        where = spec[3] if len(spec) > 3 else anchor
        strip = Image.new("RGBA", (128 * len(frames), 128), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            strip.paste(opaque(frame), (i * 128, 0))
        path = os.path.join(folder, name.lower() + ".png")
        strip.save(path)
        manifest[name] = {"file": "res://materials/enemies/%s/%s.png" % (creature, name.lower()), "frames": len(frames), "fps": fps,
                          "loop": loop, "anchor": [where[0], where[1]]}
    with open(os.path.join(folder, "manifest.json"), "w") as out:
        json.dump(manifest, out, indent=1, sort_keys=True)
    print(creature, len(anims), "animations")


def quiltro_frames():
    idle = [w.quiltro({"wag": v}) for v in (0.0, 1.5, 0.0, -1.5)]
    run = [w.quiltro({"run": i / 6}) for i in range(6)]
    bare = [w.quiltro({"snarl": v}) for v in (0.8, 1.0)]
    lunge = [w.quiltro({"bite": v}) for v in (0.8, 1.0)]
    shake = [w.quiltro({"shake": v}) for v in (1.0, 2.5, 4.0)]
    flee = [w.quiltro({"flee": 1.0, "run": i / 4}) for i in range(4)]
    return {"Idle": (idle, 6, True), "Run": (run, 12, True), "Bare": (bare, 12, True), "Lunge": (lunge, 12, False),
            "Shake": (shake, 14, True), "Flee": (flee, 12, True)}


def repartidor_frames():
    idle = [w.repartidor({}), w.repartidor({"ping": 0.0, "stumble": 0.0})]
    run = [w.repartidor({"run": i / 6}) for i in range(6)]
    ping = [w.repartidor({"ping": v}) for v in (1.0, 0.6)]
    dash = [w.repartidor({"dash": v}) for v in (1.0, 0.92)]
    stumble = [w.repartidor({"stumble": v}) for v in (1.0, 0.85)]
    return {"Idle": (idle, 3, True), "Run": (run, 12, True), "Ping": (ping, 10, True), "Dash": (dash, 14, True),
            "Stumble": (stumble, 4, True)}


def animita_frames():
    walk = [w.animita({"walk": i / 4, "frame": i}) for i in range(4)]
    doused = [w.animita({"doused": 1.0, "frame": i}) for i in range(3)]
    sputter = [w.animita({"doused": 1.0, "sputter": v, "frame": i}) for i, v in enumerate((0.2, 0.5, 0.8))]
    return {"Walk": (walk, 6, True), "Doused": (doused, 5, True), "Sputter": (sputter, 12, True)}


if __name__ == "__main__":
    g = gargola_frames()
    box = g["Idle"][0][0].getbbox()
    write("gargola", g, ((box[0] + box[2]) // 2, box[3] - 1))
    write("novia", novia_frames(), (66, 118))
    write("raya", raya_frames())
    write("quiltro", quiltro_frames(), (62, 120))
    write("repartidor", repartidor_frames(), (63, 124))
    write("animita", animita_frames(), (63, 120))
