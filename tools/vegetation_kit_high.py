"""High-preset vegetation kit for the campus (roadmap item #5).

Run inside Blender 4.3 (numpy bundled):
  blender -b --factory-startup --python tools/vegetation_kit_high.py -- [--lookdev]

Writes assets/vegetation_high/:
  leaf_atlas_albedo.png / leaf_atlas_normal.png  1024 px RGBA atlas
      quadrant 0 olive cluster A, 1 olive cluster B, 2 shrub cluster, 3 fan-palm blade
  bark_albedo/normal.png, palm_trunk_albedo/normal.png   512 px tileable
  vegetation_high.glb   SM_VEG_ShadeTree_A/B, SM_VEG_Shrub, SM_VEG_FanPalm, SM_VEG_SmallPalm
                        material slots VEG_Foliage / VEG_Bark / VEG_PalmTrunk (no images;
                        Godot builds the real materials from the PNGs)
  manifest.json         template sizes used by scripts/vegetation_high.gd

Everything is procedural with fixed seeds: no external images.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'vegetation_high'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
Q = 512  # atlas quadrant size

# ---------------------------------------------------------------- textures

def smooth_noise(cells_x, cells_y, seed, n_x, n_y):
    """Tileable value noise (smoothstep bilinear on a wrapped random grid)."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y, cells_x))
    y = np.arange(n_y) * cells_y / n_y
    x = np.arange(n_x) * cells_x / n_x
    y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
    fy = y - y0; fx = x - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells_y; x1 = (x0 + 1) % cells_x
    a = grid[y0][:, x0]; b = grid[y0][:, x1]; c = grid[y1][:, x0]; d = grid[y1][:, x1]
    fx = fx[None, :]; fy = fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(cx, cy, seed, n_x, n_y, octaves=4):
    out = np.zeros((n_y, n_x)); amp = 1.0; total = 0.0
    for o in range(octaves):
        out += amp * smooth_noise(cx * 2 ** o, cy * 2 ** o, seed + o * 17, n_x, n_y)
        total += amp; amp *= 0.5
    return out / total


def normal_from_height(h, strength, wrap=True):
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        dx = np.gradient(h, axis=1); dy = np.gradient(h, axis=0)
    nx = -dx * strength; ny = dy * strength  # OpenGL / green-up (image rows run downward)
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], -1)


def blur(img, radius):
    out = img.astype(np.float64)
    for _ in range(2):
        acc = np.zeros_like(out)
        for d in range(-radius, radius + 1):
            acc += np.roll(out, d, 0)
        out = acc / (2 * radius + 1)
        acc = np.zeros_like(out)
        for d in range(-radius, radius + 1):
            acc += np.roll(out, d, 1)
        out = acc / (2 * radius + 1)
    return out


def bleed(rgb, alpha):
    """Fill transparent texels with nearby leaf colour so mipmaps keep no dark fringe."""
    out = rgb.copy()
    weight = alpha[..., None]
    filled = alpha > 0.5
    for radius in (2, 6, 18, 48):
        num = blur(rgb * weight, radius)
        den = blur(weight, radius)
        guess = num / np.maximum(den, 1e-4)
        take = (~filled) & (den[..., 0] > 1e-3)
        out[take] = guess[take]
        filled = filled | take
    out[~filled] = (rgb * weight).sum((0, 1)) / max(weight.sum(), 1)
    return out


def draw_segment(canvas_mask, x0, y0, x1, y1, width):
    h, w = canvas_mask.shape
    pad = width + 2
    xa, xb = int(max(0, min(x0, x1) - pad)), int(min(w, max(x0, x1) + pad))
    ya, yb = int(max(0, min(y0, y1) - pad)), int(min(h, max(y0, y1) + pad))
    if xa >= xb or ya >= yb:
        return None
    yy, xx = np.mgrid[ya:yb, xa:xb] + 0.5
    vx, vy = x1 - x0, y1 - y0
    t = np.clip(((xx - x0) * vx + (yy - y0) * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
    d = np.hypot(xx - (x0 + t * vx), yy - (y0 + t * vy))
    cover = np.clip(width * 0.5 - d + 0.5, 0, 1)
    return (slice(ya, yb), slice(xa, xb)), cover


def leaf_cluster(seed, twigs, leaves_per_twig, leaf_len, leaf_w, dark, light, silver, silver_rate, twig_rgb):
    rng = np.random.default_rng(seed)
    rgb = np.zeros((Q, Q, 3)); alpha = np.zeros((Q, Q)); height = np.zeros((Q, Q))
    base = np.array([Q * 0.5, Q * 0.97])
    leaf_jobs = []
    for i in range(twigs):
        ang = math.radians(-78 + 156 * (i + rng.uniform(0.2, 0.8)) / twigs)
        direction = np.array([math.sin(ang), -math.cos(ang)])
        # Fill the square: long upright twigs, shorter sideways ones.
        reach = min(0.86 * Q / max(abs(direction[1]), 1e-3), 0.46 * Q / max(abs(direction[0]), 1e-3))
        length = (reach - leaf_len * 0.8) * rng.uniform(0.72, 0.95)
        bend = np.array([-direction[1], direction[0]]) * rng.uniform(-0.12, 0.12)
        start = base + np.array([rng.uniform(-10, 10), 0])
        pts = [start + (direction + bend * t) * length * t for t in np.linspace(0, 1, 6)]
        for a, b in zip(pts[:-1], pts[1:]):
            res = draw_segment(alpha, a[0], a[1], b[0], b[1], 4.5)
            if res:
                sl, cover = res
                c3 = np.where(alpha[sl] > 0.01, cover, 1.0)[..., None]  # no blend toward empty black
                rgb[sl] = rgb[sl] * (1 - c3) + np.array(twig_rgb) * c3
                alpha[sl] = np.maximum(alpha[sl], cover)
                height[sl] = np.maximum(height[sl], cover * 0.3)
        for j in range(leaves_per_twig):
            t = 0.18 + 0.82 * (j + rng.uniform(0, 0.6)) / leaves_per_twig
            p = start + (direction + bend * t) * length * t
            side = 1 if j % 2 else -1
            spread = math.radians(rng.uniform(25, 62)) * side
            ca, sa = math.cos(spread), math.sin(spread)
            d = np.array([direction[0] * ca - direction[1] * sa, direction[0] * sa + direction[1] * ca])
            leaf_jobs.append((rng.random(), p, d, leaf_len * rng.uniform(0.75, 1.15), leaf_w * rng.uniform(0.8, 1.2)))
        leaf_jobs.append((rng.random(), pts[-1], direction, leaf_len * 0.9, leaf_w))
    leaf_jobs.sort(key=lambda job: job[0])  # random overlap order
    for order, p, d, length, width in leaf_jobs:
        n = np.array([-d[1], d[0]])
        corners = [p, p + d * length, p + n * width, p - n * width, p + d * length + n * width, p + d * length - n * width]
        xa = int(max(0, min(c[0] for c in corners) - 2)); xb = int(min(Q, max(c[0] for c in corners) + 2))
        ya = int(max(0, min(c[1] for c in corners) - 2)); yb = int(min(Q, max(c[1] for c in corners) + 2))
        if xa >= xb or ya >= yb:
            continue
        yy, xx = np.mgrid[ya:yb, xa:xb] + 0.5
        u = ((xx - p[0]) * d[0] + (yy - p[1]) * d[1]) / length
        v = ((xx - p[0]) * n[0] + (yy - p[1]) * n[1])
        half = 0.5 * width * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 0.75
        cover = np.clip(half - np.abs(v) + 0.5, 0, 1) * (u > 0) * (u < 1)
        if cover.max() <= 0:
            continue
        across = np.abs(v) / np.maximum(half, 0.5)
        is_silver = rng.random() < silver_rate
        col = np.array(silver if is_silver else (dark if rng.random() < 0.5 else light), float)
        col = col * rng.uniform(0.95, 1.3)
        shade = (0.86 + 0.18 * (1 - across) + 0.08 * u)[..., None]
        midrib = np.clip(1 - np.abs(v) / 1.2, 0, 1)[..., None] * 0.12
        leaf_rgb = np.clip(col * shade + midrib, 0, 1)
        dome = (1 - np.clip(across, 0, 1) ** 2) * 0.6 + 0.4 * order - 0.25 * np.clip(1 - np.abs(v) / 1.5, 0, 1)
        sl = (slice(ya, yb), slice(xa, xb))
        c3 = np.where((alpha[sl] > 0.01) | (cover > 0), np.where(alpha[sl] > 0.01, cover, 1.0), 0.0)[..., None]
        rgb[sl] = rgb[sl] * (1 - c3) + leaf_rgb * c3
        height[sl] = height[sl] * (1 - cover) + dome * cover
        alpha[sl] = np.maximum(alpha[sl], cover)
    return rgb, alpha, height


def palm_blade(seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:Q, 0:Q] + 0.5
    cx, cy, radius = Q * 0.5, Q * 0.9, Q * 0.47
    dx, dy = xx - cx, yy - cy
    r = np.hypot(dx, dy) / radius
    theta = np.degrees(np.arctan2(dx, -dy))
    span, segs = 82.0, 36
    k = (theta + span) / (2 * span) * segs
    seg = np.clip(np.floor(k).astype(int), 0, segs - 1)
    f = k - np.floor(k)
    tip_len = 0.86 + 0.14 * rng.random(segs)
    tip = tip_len[seg]
    split = np.clip((r - 0.5) / (tip - 0.5), 0, 1)
    half = 0.5 * (1 - 0.55 * split ** 1.4) * np.clip((tip - r) / 0.18, 0, 1) ** 0.5
    inside = (np.abs(theta) < span) & (r > 0.035) & (r < tip)
    cover = np.clip((half - np.abs(f - 0.5)) * 28, 0, 1) * inside
    hastula = np.clip(1 - np.hypot(dx, dy) / (radius * 0.07), 0, 1) > 0.0
    cover = np.maximum(cover, hastula * 1.0)
    fold = 1 - np.abs(f - 0.5) * 2  # plicate ridges
    dry = rng.random(segs) < 0.12
    green = np.array([0.30, 0.42, 0.20]); pale = np.array([0.46, 0.56, 0.30]); dry_rgb = np.array([0.55, 0.47, 0.30])
    col = green * (0.80 + 0.30 * fold[..., None]) + (pale - green) * (r[..., None] * 0.35)
    tipmix = (np.clip((r - 0.75) / 0.25, 0, 1) * dry[seg])[..., None]
    col = col * (1 - tipmix) + dry_rgb * tipmix
    col = col * (0.92 + 0.16 * smooth_noise(16, 16, seed + 3, Q, Q))[..., None]
    height = fold * 0.8 + 0.2 * smooth_noise(64, 64, seed + 5, Q, Q)
    petiole = (np.abs(dx) < 7) & (dy > 0)
    col[petiole] = np.array([0.40, 0.42, 0.24]); cover = np.where(petiole, 1.0, cover)
    return np.clip(col, 0, 1), np.clip(cover, 0, 1), height


def build_atlas():
    quads = [
        leaf_cluster(11, 9, 11, 46, 9, (0.24, 0.30, 0.15), (0.34, 0.39, 0.20), (0.40, 0.45, 0.35), 0.18, (0.30, 0.25, 0.19)),
        leaf_cluster(23, 10, 12, 42, 9, (0.21, 0.28, 0.14), (0.30, 0.37, 0.18), (0.38, 0.43, 0.34), 0.14, (0.28, 0.23, 0.18)),
        leaf_cluster(37, 11, 9, 54, 17, (0.20, 0.31, 0.13), (0.29, 0.40, 0.17), (0.38, 0.47, 0.26), 0.10, (0.27, 0.22, 0.16)),
        palm_blade(51),
    ]
    rgb = np.zeros((2 * Q, 2 * Q, 3)); alpha = np.zeros((2 * Q, 2 * Q)); height = np.zeros((2 * Q, 2 * Q))
    for i, (c, a, h) in enumerate(quads):
        oy, ox = (i // 2) * Q, (i % 2) * Q
        c = bleed(c, a)
        rgb[oy:oy + Q, ox:ox + Q] = c; alpha[oy:oy + Q, ox:ox + Q] = a; height[oy:oy + Q, ox:ox + Q] = h
    return rgb, alpha, normal_from_height(blur(height[..., None], 1)[..., 0], 6.0, wrap=False)


def bark():
    n = 512
    fiss = fbm(20, 3, 101, n, n, 4)
    fine = fbm(48, 48, 103, n, n, 3)
    h = np.clip((fiss - 0.35) * 2.2, 0, 1) * 0.75 + fine * 0.25
    base = np.array([0.40, 0.37, 0.32])
    col = base * (0.55 + 0.55 * h)[..., None] * (0.9 + 0.2 * fbm(6, 6, 107, n, n, 2))[..., None]
    return np.clip(col, 0, 1), normal_from_height(h, 9.0)


def palm_trunk():
    n = 512
    v = (np.arange(n) / n)[:, None] * np.ones((1, n))
    rings = np.abs(np.sin(np.pi * (v * 7 + 0.05 * smooth_noise(8, 1, 201, n, n)))) ** 0.6
    fibre = fbm(64, 6, 203, n, n, 3)
    h = rings * 0.7 + fibre * 0.3
    base = np.array([0.42, 0.37, 0.30])
    col = base * (0.55 + 0.5 * h)[..., None] * (0.92 + 0.16 * fbm(4, 4, 207, n, n, 2))[..., None]
    return np.clip(col, 0, 1), normal_from_height(h, 7.0)


def save_png(path, rgb, colorspace, alpha=None):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(path.stem, w, h, alpha=alpha is not None)
    img.colorspace_settings.name = colorspace
    a = np.ones((h, w, 1)) if alpha is None else alpha[..., None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), a], -1)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)

# ---------------------------------------------------------------- meshes

FOLIAGE, BARK, PALM = 0, 1, 2
ATLAS = [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5), (0.5, 0.5)]  # quadrant origin in image (top-left) space


def atlas_uv(quadrant, s, t):
    """s,t in 0..1 inside quadrant (t=0 top of image) -> Blender UV (v up)."""
    ox, oy = ATLAS[quadrant]
    return (ox + s * 0.5, 1.0 - (oy + t * 0.5))


class Builder:
    def __init__(self):
        self.verts, self.faces, self.uvs, self.normals, self.colors, self.mats = [], [], [], [], [], []

    def face(self, pts, uvs, normals, colors, mat):
        base = len(self.verts)
        self.verts.extend(tuple(p) for p in pts)
        self.faces.append(tuple(range(base, base + len(pts))))
        self.uvs.append(uvs); self.normals.append([tuple(Vector(n).normalized()) for n in normals])
        self.colors.append(colors); self.mats.append(mat)

    def tube(self, path, radii, sides, mat, u_repeat=1.0, v_scale=1.0, color=(1, 1, 1, 1)):
        rings = []
        length = 0.0
        prev = None
        for i, (p, r) in enumerate(zip(path, radii)):
            p = Vector(p)
            if i + 1 < len(path):
                tangent = (Vector(path[i + 1]) - p).normalized()
            else:
                tangent = (p - Vector(path[i - 1])).normalized()
            side = tangent.cross(Vector((0, 0, 1)))
            if side.length < 1e-3:
                side = Vector((1, 0, 0))
            side.normalize(); up = side.cross(tangent).normalized()
            if prev is not None:
                length += (p - prev).length
            prev = p
            ring = []
            for k in range(sides + 1):
                a = 2 * math.pi * k / sides
                n = side * math.cos(a) + up * math.sin(a)
                ring.append((p + n * r, n, (k / sides * u_repeat, length * v_scale)))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(sides):
                a, b, c, d = rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]
                self.face([a[0], b[0], c[0], d[0]], [a[2], b[2], c[2], d[2]], [a[1], b[1], c[1], d[1]], [color] * 4, mat)

    def card(self, center, normal, size, quadrant, crown_center, radii, rng, down_hint):
        normal = Vector(normal).normalized()
        down = Vector(down_hint)
        down = (down - normal * down.dot(normal))
        if down.length < 1e-3:
            down = normal.orthogonal()
        down.normalize()
        down = Matrix.Rotation(rng.uniform(-0.7, 0.7), 3, normal) @ down
        right = down.cross(normal).normalized()
        half = size * 0.5
        # Shift so the twig base (bottom of the texture) sits toward the branch.
        c = Vector(center) - down * (-half * 0.6)
        corners = [c - right * half - down * half, c + right * half - down * half,
                   c + right * half + down * half, c - right * half + down * half]
        st = [(0, 0), (1, 0), (1, 1), (0, 1)]
        uvs = [atlas_uv(quadrant, s, t) for s, t in st]
        normals, colors = [], []
        for p in corners:
            rel = Vector(((p.x - crown_center.x) / radii.x, (p.y - crown_center.y) / radii.y, (p.z - crown_center.z) / radii.z))
            r = min(rel.length, 1.2)
            out = rel.normalized() if rel.length > 1e-4 else normal
            normals.append((out * 0.8 + normal * 0.2).normalized())
            lift = (p.z - (crown_center.z - radii.z)) / (2 * radii.z)
            ao = max(0.55, min(1.0, (0.62 + 0.38 * r) * (0.85 + 0.15 * lift)))
            colors.append((ao, ao, ao, 1.0))
        self.face(corners, uvs, normals, colors, FOLIAGE)

    def to_object(self, name, materials):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        for m in materials:
            mesh.materials.append(m)
        mesh.uv_layers.new(name='UVMap')
        mesh.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        mesh.color_attributes.active_color_name = 'Col'
        # Faces were added with fresh vertices in order, so loop order == our corner order.
        flat_uv = [c for uvs in self.uvs for uv in uvs for c in uv]
        flat_col = [c for cs in self.colors for col in cs for c in col]
        mesh.polygons.foreach_set('material_index', self.mats)
        # Fetch attribute data only after every layer exists (adding layers reallocates).
        mesh.uv_layers['UVMap'].data.foreach_set('uv', flat_uv)
        mesh.color_attributes['Col'].data.foreach_set('color', flat_col)
        mesh.update()
        mesh.normals_split_custom_set([n for ns in self.normals for n in ns])
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def shade_tree(name, seed, height, crown_h, crown_r, cards, trunk_h, lean):
    rng = np.random.default_rng(seed)
    b = Builder()
    crown_c = Vector((lean * 0.5, 0, height - crown_h * 0.5))
    radii = Vector((crown_r, crown_r * rng.uniform(0.9, 1.05), crown_h * 0.5))
    trunk_top = Vector((lean * 0.35, 0, trunk_h))
    trunk = [Vector((0, 0, -0.15)), Vector((0.02, 0.01, trunk_h * 0.45)), trunk_top]
    b.tube(trunk, [0.16, 0.12, 0.10], 8, BARK, u_repeat=1.0, v_scale=1.0)
    branch_tips = []
    for i in range(5):
        a = 2 * math.pi * (i / 5 + rng.uniform(-0.06, 0.06))
        reach = rng.uniform(0.45, 0.7)
        tip = crown_c + Vector((math.cos(a) * radii.x * reach, math.sin(a) * radii.y * reach, rng.uniform(-0.1, 0.35) * radii.z))
        mid = trunk_top.lerp(tip, 0.45) + Vector((0, 0, 0.15))
        b.tube([trunk_top - Vector((0, 0, 0.12)), mid, tip], [0.075, 0.05, 0.025], 6, BARK, u_repeat=0.5, v_scale=1.0)
        branch_tips.append(tip)
    for i in range(cards):
        while True:
            d = Vector(rng.normal(size=3)).normalized()
            r = rng.uniform(0.5, 1.0) ** 0.6
            if d.z > -0.75 or r < 0.7:
                break
        p = crown_c + Vector((d.x * radii.x * r, d.y * radii.y * r, d.z * radii.z * r))
        normal = (d + Vector(rng.normal(size=3)) * 0.45).normalized()
        quadrant = 0 if rng.random() < 0.55 else 1
        b.card(p, normal, rng.uniform(0.9, 1.25), quadrant, crown_c, radii, rng, (crown_c - p) * 0.4 + Vector((0, 0, -1)))
    return b, {"height": height, "width": 2 * crown_r, "kind": "tree"}


def shrub(name, seed, height, radius, cards):
    rng = np.random.default_rng(seed)
    b = Builder()
    center = Vector((0, 0, height * 0.42))
    radii = Vector((radius, radius, height * 0.58))
    for i in range(cards):
        d = Vector(rng.normal(size=3)).normalized()
        if d.z < -0.25:
            d.z = -d.z * 0.3
        r = rng.uniform(0.55, 1.0) ** 0.5
        p = center + Vector((d.x * radii.x * r, d.y * radii.y * r, d.z * radii.z * r))
        b.card(p, (d + Vector(rng.normal(size=3)) * 0.4).normalized(), rng.uniform(0.6, 0.8), 2, center, radii, rng,
               (center - p) * 0.5 + Vector((0, 0, -1)))
    return b, {"height": height, "width": 2 * radius, "kind": "shrub"}


def palm(name, seed, trunk_h, fronds, petiole_len, blade_r, base_r, top_r):
    rng = np.random.default_rng(seed)
    b = Builder()
    path = []; radii = []
    curve = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * trunk_h * 0.045
    for i in range(9):
        t = i / 8
        path.append(Vector((0, 0, -0.1 + trunk_h * t)) + curve * (t * t))
        radii.append(base_r * (1 - t) + top_r * t + (0.05 if t < 0.1 else 0))
    b.tube(path, radii, 10, PALM, u_repeat=2.0, v_scale=1.0)
    top = path[-1]
    # Leaf-base boot under the crown.
    b.tube([top - Vector((0, 0, 0.05)), top + Vector((0, 0, 0.35)), top + Vector((0, 0, 0.55))],
           [top_r * 1.25, top_r * 1.05, top_r * 0.5], 10, PALM, u_repeat=2.0, v_scale=1.0, color=(0.75, 0.68, 0.55, 1))
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(fronds):
        frac = i / max(1, fronds - 1)
        dead = i >= fronds - 4
        azim = i * golden + rng.uniform(-0.15, 0.15)
        elev = math.radians(62 - 85 * frac + rng.uniform(-6, 6)) if not dead else math.radians(rng.uniform(-78, -62))
        d = Vector((math.cos(azim) * math.cos(elev), math.sin(azim) * math.cos(elev), math.sin(elev)))
        start = top + Vector((0, 0, 0.35)) + Vector((d.x, d.y, 0)) * top_r * 0.8
        plen = petiole_len * rng.uniform(0.85, 1.1) * (0.8 if dead else 1)
        mid = start + d * plen * 0.5 + Vector((0, 0, 0.06 if not dead else 0))
        end = start + d * plen - Vector((0, 0, 0.12 * plen * (1 - abs(d.z))))
        tint = (1, 1, 1, 1) if not dead else (0.95, 0.72, 0.42, 1)
        b.tube([start, mid, end], [0.045, 0.035, 0.025], 4, PALM, u_repeat=0.25, v_scale=0.5, color=tint)
        # Fan blade: hastula at `end`, fan axis continues along d, folded, tips droop.
        axis = (end - mid).normalized()
        side = axis.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize(); face_n = side.cross(axis).normalized()
        if face_n.z < 0:
            face_n = -face_n
        rad = blade_r * rng.uniform(0.85, 1.1) * (0.85 if dead else 1)
        spokes = 9
        rings = [0.0, 0.45, 1.0]
        grid = []
        for ri, rr in enumerate(rings):
            row = []
            for k in range(spokes):
                ang = math.radians(-82 + 164 * k / (spokes - 1))
                if ri == 0:
                    p = end.copy()
                else:
                    p = end + (axis * math.cos(ang) + side * math.sin(ang)) * rad * rr
                    fold = (0.06 if k % 2 else -0.06) * rr * rad
                    p += face_n * fold
                    p -= Vector((0, 0, 1)) * (rr ** 2) * rad * (0.38 + 0.25 * abs(math.sin(ang)))
                s, t = 0.5 + 0.47 * rr * math.sin(ang), 0.9 - 0.47 * rr * math.cos(ang)
                row.append((p, atlas_uv(3, s, t)))
            grid.append(row)
        for ri in range(len(rings) - 1):
            for k in range(spokes - 1):
                a, bb, c, dd = grid[ri][k], grid[ri][k + 1], grid[ri + 1][k + 1], grid[ri + 1][k]
                n = face_n
                if ri == 0:
                    b.face([a[0], c[0], dd[0]], [a[1], c[1], dd[1]], [n, n, n], [tint] * 3, FOLIAGE)
                else:
                    b.face([a[0], bb[0], c[0], dd[0]], [a[1], bb[1], c[1], dd[1]], [n] * 4, [tint] * 4, FOLIAGE)
    spread = 2 * (petiole_len + blade_r * 0.9)
    return b, {"height": trunk_h + 0.6 + blade_r * 0.6, "trunk_height": trunk_h, "width": spread, "kind": "palm"}


def make_materials():
    mats = []
    for name, rgb in (("VEG_Foliage", (0.3, 0.4, 0.2, 1)), ("VEG_Bark", (0.4, 0.37, 0.32, 1)), ("VEG_PalmTrunk", (0.42, 0.37, 0.3, 1))):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = rgb
        mats.append(m)
    return mats


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    rgb, alpha, normal = build_atlas()
    save_png(OUT / 'leaf_atlas_albedo.png', rgb, 'sRGB', alpha)
    save_png(OUT / 'leaf_atlas_normal.png', normal, 'Non-Color')
    c, n = bark(); save_png(OUT / 'bark_albedo.png', c, 'sRGB'); save_png(OUT / 'bark_normal.png', n, 'Non-Color')
    c, n = palm_trunk(); save_png(OUT / 'palm_trunk_albedo.png', c, 'sRGB'); save_png(OUT / 'palm_trunk_normal.png', n, 'Non-Color')

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    specs = {
        'SM_VEG_ShadeTree_A': shade_tree('A', 7, 4.6, 3.0, 1.8, 250, 1.7, 0.15),
        'SM_VEG_ShadeTree_B': shade_tree('B', 19, 4.9, 3.4, 1.55, 230, 1.8, -0.12),
        'SM_VEG_Shrub': shrub('S', 29, 1.0, 0.75, 60),
        'SM_VEG_FanPalm': palm('P', 41, 5.2, 24, 0.9, 1.25, 0.26, 0.2),
        'SM_VEG_SmallPalm': palm('p', 43, 2.0, 16, 0.55, 0.85, 0.17, 0.13),
    }
    manifest = {"version": 1, "templates": {}}
    for x, (name, (builder, info)) in enumerate(specs.items()):
        obj = builder.to_object(name, mats)
        info["triangles"] = sum(len(f) - 2 for f in builder.faces)
        manifest["templates"][name] = info
        print(f"{name}: {info}")
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'vegetation_high.glb'), export_format='GLB', export_apply=True,
                              export_normals=True, export_tangents=True, export_vertex_color='ACTIVE',
                              export_materials='EXPORT', export_image_format='NONE', export_yup=True)
    manifest["textures"] = {
        "foliage": ["leaf_atlas_albedo.png", "leaf_atlas_normal.png"],
        "bark": ["bark_albedo.png", "bark_normal.png"],
        "palm": ["palm_trunk_albedo.png", "palm_trunk_normal.png"],
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    return manifest


def lookdev(manifest):
    """Eevee preview of every template with the generated textures."""
    scene = bpy.context.scene
    def img(name, colorspace):
        i = bpy.data.images.load(str(OUT / name)); i.colorspace_settings.name = colorspace; return i
    textures = {"VEG_Foliage": ("leaf_atlas_albedo.png", "leaf_atlas_normal.png", True),
                "VEG_Bark": ("bark_albedo.png", "bark_normal.png", False),
                "VEG_PalmTrunk": ("palm_trunk_albedo.png", "palm_trunk_normal.png", False)}
    for m in bpy.data.materials:
        if m.name not in textures:
            continue
        alb, nor, cut = textures[m.name]
        nt = m.node_tree; bsdf = nt.nodes['Principled BSDF']
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = img(alb, 'sRGB')
        vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
        mul = nt.nodes.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1
        nt.links.new(t.outputs['Color'], mul.inputs[6]); nt.links.new(vc.outputs['Color'], mul.inputs[7])
        nt.links.new(mul.outputs[2], bsdf.inputs['Base Color'])
        nm = nt.nodes.new('ShaderNodeTexImage'); nm.image = img(nor, 'Non-Color')
        nmap = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(nm.outputs['Color'], nmap.inputs['Color'])
        nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
        bsdf.inputs['Roughness'].default_value = 0.7
        if cut:
            gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.5
            nt.links.new(t.outputs['Alpha'], gt.inputs[0]); nt.links.new(gt.outputs[0], bsdf.inputs['Alpha'])
            m.use_backface_culling = False
    xs = {'SM_VEG_ShadeTree_A': -9, 'SM_VEG_ShadeTree_B': -4.5, 'SM_VEG_Shrub': -1, 'SM_VEG_FanPalm': 3.5, 'SM_VEG_SmallPalm': 8.5}
    for name, x in xs.items():
        bpy.data.objects[name].location.x = x
    bpy.ops.mesh.primitive_plane_add(size=60)
    ground = bpy.context.object
    gm = bpy.data.materials.new('ground'); gm.use_nodes = True
    gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.55, 0.5, 0.42, 1)
    ground.data.materials.append(gm)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); scene.collection.objects.link(sun)
    sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.world = bpy.data.worlds.new('w'); scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.7, 0.9, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); scene.collection.objects.link(cam)
    cam.location = (0, -21, 4.2); cam.rotation_euler = (math.radians(84), 0, 0); cam.data.lens = 30
    scene.camera = cam
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = 1600, 700
    out = ROOT / 'art_audit' / 'work' / '05_vegetation' / 'lookdev_vegetation_high.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print('LOOKDEV', out)


if __name__ == '__main__':
    manifest = build()
    if '--lookdev' in ARGS:
        lookdev(manifest)
    print('VEGETATION_KIT_DONE')
