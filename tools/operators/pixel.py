"""Small pixel-art toolkit: aliased shapes on an RGBA canvas, plus the finishing passes a pixel
artist does by hand -- selective outline and a rim of the yard's cyan light on the far edge."""
from PIL import Image, ImageDraw


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


class Canvas:
    def __init__(self, width=128, height=128):
        self.image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)
        self.width = width
        self.height = height

    def px(self, x, y, color):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), color)

    def rect(self, x0, y0, x1, y1, color):
        self.draw.rectangle([int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))], fill=color)

    def poly(self, points, color):
        self.draw.polygon([(int(round(x)), int(round(y))) for x, y in points], fill=color)

    def line(self, x0, y0, x1, y1, color, width=1):
        self.draw.line([int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))], fill=color, width=width)

    def ellipse(self, cx, cy, rx, ry, color, outline=None):
        box = [int(round(cx - rx)), int(round(cy - ry)), int(round(cx + rx)), int(round(cy + ry))]
        if outline is None:
            self.draw.ellipse(box, fill=color)
        else:
            self.draw.ellipse(box, outline=outline)

    def get(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.image.getpixel((x, y))
        return (0, 0, 0, 0)

    def finish(self, outline=(10, 12, 18), rim=(134, 228, 249), rim_strength=0.42, rim_side=1, glow_keep=()):
        """Selective outline (a darker cousin of the colour it borders) and a cyan rim on the
        side facing the yard's spine light. Pixels whose colour is in `glow_keep` stay as drawn."""
        src = self.image.copy()
        w, h = self.width, self.height
        out = src.copy()
        load = src.load()
        dst = out.load()
        for y in range(h):
            for x in range(w):
                if load[x, y][3] != 0:
                    continue
                neighbours = [load[nx, ny] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                              if 0 <= nx < w and 0 <= ny < h and load[nx, ny][3] > 0]
                if neighbours:
                    r = sum(n[0] for n in neighbours) / len(neighbours)
                    g = sum(n[1] for n in neighbours) / len(neighbours)
                    b = sum(n[2] for n in neighbours) / len(neighbours)
                    dst[x, y] = (int(outline[0] * 0.75 + r * 0.12), int(outline[1] * 0.75 + g * 0.12), int(outline[2] * 0.75 + b * 0.14), 255)
        # Rim: opaque pixels whose neighbour on the rim side is empty in the source.
        for y in range(h):
            for x in range(w):
                p = load[x, y]
                if p[3] == 0 or p[:3] in glow_keep:
                    continue
                nx = x + rim_side
                if 0 <= nx < w and load[nx, y][3] == 0:
                    t = rim_strength * (1.0 - 0.45 * (y / h))
                    dst[x, y] = (int(p[0] + (rim[0] - p[0]) * t), int(p[1] + (rim[1] - p[1]) * t), int(p[2] + (rim[2] - p[2]) * t), 255)
        self.image = out
        self.draw = ImageDraw.Draw(self.image)
        return self


def sheet(frames, size=128):
    strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.paste(frame, (index * size, 0))
    return strip
