"""Pixel figures painted the way a sprite artist blocks them: each part is a smooth shape drawn
four times larger and reduced to whole pixels, then lit as a volume (a cylinder across its width
or down its length) and snapped to a short hue-shifted ramp. Neon is painted last, at pixel
size, and leaks a tint onto the cloth around it. The finish adds a dark outline and the two
city rims -- cyan on one side, magenta on the other -- that every street in Sector 08 throws."""
import math
from PIL import Image, ImageDraw

S = 4
W = H = 128


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def ramp(*values):
    return [hexc(v) for v in values]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


class Shape:
    """A region painted at four times the size; `pixels()` keeps whatever covers half a pixel."""

    def __init__(self):
        self.im = Image.new("L", (W * S, H * S), 0)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, points, value=255):
        self.d.polygon([(x * S, y * S) for x, y in points], fill=value)
        return self

    def ellipse(self, cx, cy, rx, ry, value=255):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=value)
        return self

    def limb(self, a, b, ra, rb, value=255):
        """A tapered capsule from point a (radius ra) to point b (radius rb)."""
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        self.poly([(x0 + nx * ra, y0 + ny * ra), (x1 + nx * rb, y1 + ny * rb),
                   (x1 - nx * rb, y1 - ny * rb), (x0 - nx * ra, y0 - ny * ra)], value)
        self.ellipse(x0, y0, ra, ra, value)
        self.ellipse(x1, y1, rb, rb, value)
        return self

    def cut(self, points):
        return self.poly(points, 0)

    def pixels(self):
        small = self.im.resize((W, H), Image.BOX).load()
        return {(x, y) for y in range(H) for x in range(W) if small[x, y] >= 128}


class Figure:
    def __init__(self, light=(-0.55, 0.3, 0.78), key=0.62, ambient=0.08):
        self.image = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.load = self.image.load()
        length = math.sqrt(sum(c * c for c in light))
        self.light = tuple(c / length for c in light)
        self.emissive = set()
        self.key = key
        self.ambient = ambient

    def px(self, x, y, color, glow=False):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.load[x, y] = color
            if glow:
                self.emissive.add((x, y))
            else:
                self.emissive.discard((x, y))

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.load[x, y]
        return (0, 0, 0, 0)

    def fill(self, pixels, color):
        for x, y in pixels:
            self.px(x, y, color)

    def paint(self, pixels, colors, axis="h", lift=0.0, fall=0.0, gloss=0.0, light=None):
        """Lit as a cylinder: across each row (axis 'h') or down each column ('v').
        `lift` brightens the whole part, `fall` darkens it toward the bottom, `gloss` adds a
        hard specular band where the surface faces the light (leather, rain, chrome)."""
        lx, ly, lz = light or self.light
        if not pixels:
            return
        ys = [p[1] for p in pixels]
        top, bottom = min(ys), max(ys)
        lines = {}
        for x, y in pixels:
            lines.setdefault(y if axis == "h" else x, []).append(x if axis == "h" else y)
        for key, values in lines.items():
            values.sort()
            spans = []
            start = prev = values[0]
            for v in values[1:]:
                if v != prev + 1:
                    spans.append((start, prev))
                    start = v
                prev = v
            spans.append((start, prev))
            for a, b in spans:
                for v in range(a, b + 1):
                    u = ((v + 0.5 - a) / (b - a + 1)) * 2.0 - 1.0
                    n0 = u
                    nz = math.sqrt(max(0.0, 1.0 - u * u))
                    if axis == "h":
                        x, y = v, key
                        diffuse = n0 * lx + nz * lz
                    else:
                        x, y = key, v
                        diffuse = n0 * ly + nz * lz
                    value = self.ambient + self.key * max(0.0, diffuse) + lift
                    if bottom > top:
                        value -= fall * (y - top) / (bottom - top)
                    if gloss and diffuse > 0.93:
                        value += gloss
                    index = int(round(max(0.0, min(1.0, value)) * (len(colors) - 1)))
                    self.px(x, y, colors[index])

    def flat(self, pixels, colors, index):
        self.fill(pixels, colors[index])

    def shadow(self, pixels, steps=1, colors=None):
        """Darken painted pixels by moving them down their own ramp (or simply dimming)."""
        for x, y in pixels:
            c = self.get(x, y)
            if c[3] == 0 or (x, y) in self.emissive:
                continue
            if colors and c in colors:
                i = colors.index(c)
                self.px(x, y, colors[max(0, i - steps)])
            else:
                self.px(x, y, mix(c, (0, 0, 0), 0.22 * steps))

    def light_up(self, pixels, steps=1, colors=None):
        for x, y in pixels:
            c = self.get(x, y)
            if c[3] == 0 or (x, y) in self.emissive:
                continue
            if colors and c in colors:
                i = colors.index(c)
                self.px(x, y, colors[min(len(colors) - 1, i + steps)])
            else:
                self.px(x, y, mix(c, (255, 255, 255), 0.18 * steps))

    def glow(self, cx, cy, radius, color, strength):
        """Light from a neon source washing over the cloth (opaque pixels only)."""
        for y in range(int(cy - radius), int(cy + radius) + 1):
            for x in range(int(cx - radius), int(cx + radius) + 1):
                c = self.get(x, y)
                if c[3] == 0 or (x, y) in self.emissive:
                    continue
                d = math.hypot(x - cx, y - cy)
                if d > radius:
                    continue
                t = strength * (1.0 - d / radius) ** 1.6
                lum = (c[0] + c[1] + c[2]) / 765.0
                # Additive on the dark cloth, so a lit edge reads as light and not as paint.
                self.load[x, y] = tuple(min(255, int(c[i] + color[i] * t * (0.6 + lum))) for i in range(3)) + (255,)

    def finish(self, outline=(6, 7, 12), rim=((92, 228, 255), (255, 70, 150)), rim_strength=(0.55, 0.32)):
        src = self.image.copy()
        s = src.load()
        out = self.image
        o = self.load
        # Rims first, read from the clean silhouette: the right edge takes the cyan of the street,
        # the left edge a fainter magenta. Two pixels deep where the edge is long and vertical.
        for y in range(H):
            for x in range(W):
                p = s[x, y]
                if p[3] == 0 or (x, y) in self.emissive:
                    continue
                for side, color, strength in ((1, rim[0], rim_strength[0]), (-1, rim[1], rim_strength[1])):
                    nx = x + side
                    if 0 <= nx < W and s[nx, y][3] == 0:
                        t = strength * (1.0 - 0.35 * (y / H))
                        o[x, y] = mix(o[x, y], color, t)
                    elif 0 <= nx + side < W and s[nx + side, y][3] == 0 and s[x, y - 1][3] and s[x, min(H - 1, y + 1)][3]:
                        t = strength * 0.35
                        o[x, y] = mix(o[x, y], color, t)
        # Outline: a near-black that leans toward what it borders. Emissive edges get a dark
        # coloured line instead, so neon never touches the void directly.
        for y in range(H):
            for x in range(W):
                if s[x, y][3] != 0:
                    continue
                around = [(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                          if 0 <= nx < W and 0 <= ny < H and s[nx, ny][3] > 0]
                if not around:
                    continue
                r = sum(s[n][0] for n in around) / len(around)
                g = sum(s[n][1] for n in around) / len(around)
                b = sum(s[n][2] for n in around) / len(around)
                o[x, y] = (int(outline[0] + r * 0.14), int(outline[1] + g * 0.14), int(outline[2] + b * 0.16), 255)
        return self
