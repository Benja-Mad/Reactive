"""Sprites for the crew's ability effects, drawn like the cast: dark outline, light on the edges,
one-pixel neon. Written to materials/effects.

    python3 tools/operators/effects.py

The ánima: one of El Sereno's rain-spirits. A small wailing ghost of rain with a long rippling tail, cyan from the ward's light with a violet rim -- never rose, which belongs to the enemy.
"""
import math
import os

from PIL import Image

from neon import Figure, Shape, ramp
from cast import CYAN, VIOLET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "materials", "effects")
WISP = ramp("#0b2c3a", "#155a6b", "#1d6f80", "#2fa9c2", "#36c8e0", "#93f3ff", "#effeff")
SIZE = 32
FRAMES = 6


def anima(frame, frames=FRAMES):
    """A little wailing ghost: round head low and forward, a long tail that streams up and back and
    ripples along its length (the ripple travels down it frame by frame), thinning into loose
    pixels at the tip. The mouth opens and closes as it keens."""
    f = Figure(light=(-0.4, -0.5, 0.75))
    ox, oy = 64 - SIZE // 2, 64 - SIZE // 2
    phase = frame / frames * math.tau
    head = (ox + 10.5, oy + 21.5)
    axis = (17.0, -13.0)
    length = math.hypot(*axis)
    ax, ay = axis[0] / length, axis[1] / length
    nx, ny = -ay, ax
    spine = []
    for i in range(13):
        s = i / 12
        wave = math.sin(s * math.pi * 2.3 - phase) * (0.3 + 2.7 * s)
        spine.append(((head[0] + 1.5 + axis[0] * s + nx * wave, head[1] - 1.0 + axis[1] * s + ny * wave),
                      4.4 * (1.0 - s) ** 0.85 + 0.45))
    shape = Shape().ellipse(head[0], head[1], 6.4, 6.0)
    for (a, ra), (b, rb) in zip(spine, spine[1:]):
        shape.limb(a, b, ra, rb)
    body = shape.pixels()
    # The tip comes apart: past four fifths of the way it is only every other pixel.
    def along(p):
        return ((p[0] - head[0]) * ax + (p[1] - head[1]) * ay) / length
    body = {p for p in body if along(p) < 0.8 or (p[0] + p[1] + frame) % 2 == 0}
    f.paint(body, WISP, axis="h", lift=0.3, gloss=0.35)
    f.glow(head[0] + 0.5, head[1] - 0.5, 4.5, CYAN["core"][:3], 0.35)
    f.finish(rim=(CYAN["hi"][:3], VIOLET["mid"][:3]), rim_strength=(0.6, 0.5))
    # Two loose motes drifting off the tip.
    tip = spine[-1][0]
    for k, (dx, dy) in enumerate(((2.5, -1.0), (1.0, -3.0))):
        if (frame + k) % 3 != 2:
            f.px(tip[0] + dx + math.sin(phase + k) * 0.8, tip[1] + dy, CYAN["hi"], glow=True)
    # The face: big dark eyes set wide, and a mouth that opens as it keens.
    eye = (6, 20, 30, 255)
    for dx in (-2.3, 1.9):
        f.px(head[0] + dx, head[1] - 0.6, eye)
        f.px(head[0] + dx, head[1] + 0.4, eye)
    wide = frame % 3 != 0
    f.px(head[0] - 0.2, head[1] + 2.6, eye)
    if wide:
        f.px(head[0] - 0.2, head[1] + 3.6, eye)
    f.px(head[0] - 3.0, head[1] - 3.8, CYAN["core"], glow=True)
    f.px(head[0] - 1.8, head[1] - 4.6, CYAN["hi"], glow=True)
    return f.image.crop((ox, oy, ox + SIZE, oy + SIZE))


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = FRAMES
    strip = Image.new("RGBA", (SIZE * frames, SIZE), (0, 0, 0, 0))
    for i in range(frames):
        strip.paste(anima(i, frames), (i * SIZE, 0))
    strip.save(os.path.join(OUT, "anima.png"))
    print("anima", frames, "frames")


if __name__ == "__main__":
    main()
