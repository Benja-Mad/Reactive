"""Tiny software rasteriser for creatures whose shape depends on the game camera.

Sprites are drawn for a camera pitched down 38 degrees. Things that stand up (people, gargoyles)
read fine drawn in profile, but anything lying along the floor or flying flat -- a ray, a wing,
a puddle -- has to be foreshortened the way that camera sees it. Parts are built as small 3D
surfaces, projected with the game's pitch, depth-tested at four times the sprite resolution,
then reduced to whole pixels; each pixel keeps its part, normal and surface coordinates so the
painter can light it with a ramp and lay patterns in surface space.
"""
import math

PITCH = math.radians(38.0)
S = 4
W = H = 128


def norm(v):
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / length, v[1] / length, v[2] / length)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def rot_y(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def rot_z(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


def rot_x(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


class Camera:
    """World: x to screen-right, y up, z toward the viewer before the pitch. `origin` is where
    world (0, 0, 0) lands on the 128-pixel sprite."""

    def __init__(self, origin=(64, 80), pitch=PITCH):
        self.origin = origin
        self.c = math.cos(pitch)
        self.s = math.sin(pitch)

    def project(self, p):
        x, y, z = p
        return (self.origin[0] + x, self.origin[1] - y * self.c + z * self.s, y * self.s + z * self.c)

    def view(self, n):
        """A world normal turned into the camera frame (z toward the viewer)."""
        x, y, z = n
        return (x, y * self.c - z * self.s, y * self.s + z * self.c)


class Raster:
    def __init__(self, camera):
        self.cam = camera
        self.depth = [[-1e9] * (W * S) for _ in range(H * S)]
        self.data = [[None] * (W * S) for _ in range(H * S)]

    def triangle(self, verts, part):
        """verts: three (world point, world normal, uv) tuples."""
        pts = [self.cam.project(v[0]) for v in verts]
        sx = [p[0] * S for p in pts]
        sy = [p[1] * S for p in pts]
        area = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0])
        if abs(area) < 1e-9:
            return
        x0, x1 = max(0, int(min(sx))), min(W * S - 1, int(max(sx)) + 1)
        y0, y1 = max(0, int(min(sy))), min(H * S - 1, int(max(sy)) + 1)
        for y in range(y0, y1 + 1):
            py = y + 0.5
            for x in range(x0, x1 + 1):
                px = x + 0.5
                w0 = ((sx[1] - px) * (sy[2] - py) - (sx[2] - px) * (sy[1] - py)) / area
                w1 = ((sx[2] - px) * (sy[0] - py) - (sx[0] - px) * (sy[2] - py)) / area
                w2 = 1.0 - w0 - w1
                if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                    continue
                d = w0 * pts[0][2] + w1 * pts[1][2] + w2 * pts[2][2]
                if d <= self.depth[y][x]:
                    continue
                self.depth[y][x] = d
                n = tuple(w0 * verts[0][1][i] + w1 * verts[1][1][i] + w2 * verts[2][1][i] for i in range(3))
                uv = tuple(w0 * verts[0][2][i] + w1 * verts[1][2][i] + w2 * verts[2][2][i] for i in range(2))
                self.data[y][x] = (part, n, uv)

    def grid(self, fn, nu, nv, part):
        """A surface from fn(u, v) -> world point, u and v in 0..1; normals from the grid."""
        pts = [[fn(i / nu, j / nv) for j in range(nv + 1)] for i in range(nu + 1)]

        def normal(i, j):
            a = pts[min(i + 1, nu)][j]
            b = pts[max(i - 1, 0)][j]
            c = pts[i][min(j + 1, nv)]
            d = pts[i][max(j - 1, 0)]
            n = norm(cross((a[0] - b[0], a[1] - b[1], a[2] - b[2]), (c[0] - d[0], c[1] - d[1], c[2] - d[2])))
            return n if n[1] >= 0 else (-n[0], -n[1], -n[2])

        normals = [[normal(i, j) for j in range(nv + 1)] for i in range(nu + 1)]
        for i in range(nu):
            for j in range(nv):
                q = [(pts[a][b], normals[a][b], (a / nu, b / nv)) for a, b in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
                self.triangle([q[0], q[1], q[2]], part)
                self.triangle([q[0], q[2], q[3]], part)

    def tube(self, path, radii, part, sides=8):
        """A tube through `path` (world points) with a radius per point."""
        for k in range(len(path) - 1):
            a, b = path[k], path[k + 1]
            axis = norm((b[0] - a[0], b[1] - a[1], b[2] - a[2]))
            side = norm(cross(axis, (0, 1, 0))) if abs(axis[1]) < 0.9 else norm(cross(axis, (1, 0, 0)))
            up = cross(side, axis)
            ring = []
            for end, r in ((a, radii[k]), (b, radii[k + 1])):
                row = []
                for m in range(sides + 1):
                    t = m / sides * math.tau
                    n = tuple(side[i] * math.cos(t) + up[i] * math.sin(t) for i in range(3))
                    row.append((tuple(end[i] + n[i] * r for i in range(3)), n, (k / (len(path) - 1), m / sides)))
                ring.append(row)
            for m in range(sides):
                self.triangle([ring[0][m], ring[1][m], ring[1][m + 1]], part)
                self.triangle([ring[0][m], ring[1][m + 1], ring[0][m + 1]], part)

    def ball(self, center, radius, part, stretch=(1, 1, 1)):
        def fn(u, v):
            th, ph = u * math.tau, v * math.pi
            n = (math.sin(ph) * math.cos(th), math.cos(ph), math.sin(ph) * math.sin(th))
            return tuple(center[i] + n[i] * radius * stretch[i] for i in range(3))
        self.grid(fn, 10, 6, part)

    def pixels(self, coverage=7):
        """Reduce to sprite pixels: {(x, y): (part, view normal, uv)} where enough is covered."""
        out = {}
        for y in range(H):
            for x in range(W):
                counts = {}
                for dy in range(S):
                    row = self.data[y * S + dy]
                    for dx in range(S):
                        cell = row[x * S + dx]
                        if cell is not None:
                            counts.setdefault(cell[0], []).append(cell)
                total = sum(len(v) for v in counts.values())
                if total < coverage:
                    continue
                part = max(counts, key=lambda k: len(counts[k]))
                cells = counts[part]
                n = norm(tuple(sum(c[1][i] for c in cells) for i in range(3)))
                uv = tuple(sum(c[2][i] for c in cells) / len(cells) for i in range(2))
                out[(x, y)] = (part, self.cam.view(n), uv)
        return out
