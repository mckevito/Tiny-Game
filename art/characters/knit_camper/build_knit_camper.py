# Builds the knitted camper (art/characters/knit_camper/knit_camper.glb) in Blender, from code only.
#   blender --background --factory-startup --python art/characters/knit_camper/build_knit_camper.py -- OUT.glb
# Add --tpose after OUT.glb for arms straight out, to set beside the owner's T-pose turnaround (the game uses the
# arms-down pose, with the hands at data/tuning.json "camper" hand_pos).
# The beanie, sweater and sleeves are knitted surfaces made row by row (a profile turned round an axis), so their ribs
# are real grooves and each vertex knows its stitch column and row: that goes in the second UV map, and the shader's
# "knit_rows" weave draws the stitches along the ribs. Soft parts (head, curls, trousers, boots, hands) are
# overlapping primitives fused by a voxel remesh and smoothed, so they read as stuffed felt.
# The game paints it: UV.x is the weave (data/art.json "weaves") and UV.y the slot index (data/models.json
# "knit_camper" file_slots), so colours come from the palette and swap per variant. Blender: +Z up, +Y is the front
# (glTF turns that into +Y up, -Z front). Metres, origin at the ground centre. Original work, CC BY 4.0 (CREDITS.md).
import bpy, bmesh, math, random, sys
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
TPOSE = "--tpose" in ARGS
FELT, KNIT_ROWS = 0, 5
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE, THREAD = range(11)
VOXEL = 0.011

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
parts = []  # (mesh, weave, slot); a mesh may carry its own "Stitch" UV map


def ellipsoid(bm, size, loc, rot=(0, 0, 0), segs=32):
    r = (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
            @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))
    m = Matrix.LocRotScale(Vector(loc), r, Vector(size) / 2)
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1.0, matrix=m)


def limb(bm, a, b, r, steps=8):
    a, b = Vector(a), Vector(b)
    for i in range(steps + 1):
        ellipsoid(bm, (r * 2, r * 2, r * 2), a.lerp(b, i / steps), segs=20)


def evaluated(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return me


def fused(name, build, smooth=0.6, repeat=8, decimate=0.3, after=None):
    """Primitives from `build(bm)`, fused by a voxel remesh, smoothed and thinned; `after(co)` shapes each vertex."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    mod = ob.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = VOXEL
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.factor = smooth
    sm.iterations = repeat
    out = evaluated(ob)
    if after:
        for v in out.vertices:
            v.co = after(v.co.copy())
    ob = bpy.data.objects.new(name, out)
    scene.collection.objects.link(ob)
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = decimate
    return evaluated(ob)


def stitch_round(me, centre, cols, row):
    """Gives a fused mesh a "Stitch" UV map round a vertical axis through `centre`: `cols` stitch columns round it and
    rows `row` metres tall. Faces that straddle the seam at the back get their columns unwrapped, so no stitch smears."""
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.new("Stitch")
    for f in bm.faces:
        us = [math.atan2(l.vert.co.x - centre.x, l.vert.co.y - centre.y) / math.tau * cols for l in f.loops]
        if max(us) - min(us) > cols / 2:
            us = [u + cols if u < 0 else u for u in us]
        for l, u in zip(f.loops, us):
            l[uvl].uv = (u, -l.vert.co.z / (1.4 * row))
    bm.to_mesh(me)
    bm.free()
    return me


def plain(name, build):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(me)
    bm.free()
    return me


def thread(name, points, radius, sides=6):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = max(0, sides // 2 - 2)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (*co, 1.0)
    ob = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(ob)
    return evaluated(ob)


def running_stitch(bm, points, length=0.026, gap=0.016, radius=0.0055):
    """Short cream dashes along a polyline, each a tiny stretched bead, like a hand-sewn running stitch."""
    pts = [Vector(p) for p in points]
    dist = [0.0]
    for a, b in zip(pts, pts[1:]):
        dist.append(dist[-1] + (b - a).length)
    def at(d):
        for i in range(len(pts) - 1):
            if d <= dist[i + 1] or i == len(pts) - 2:
                t = (d - dist[i]) / max(dist[i + 1] - dist[i], 1e-6)
                return pts[i].lerp(pts[i + 1], min(max(t, 0.0), 1.0)), (pts[i + 1] - pts[i]).normalized()
    d = gap * 0.5
    while d + length <= dist[-1]:
        mid, along = at(d + length * 0.5)
        rot = along.to_track_quat("Z", "Y").to_matrix()
        m = Matrix.LocRotScale(mid, rot, Vector((radius, radius, length * 0.5)))
        bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=3, radius=1.0, matrix=m)
        d += length + gap


def profile(points, count):
    """`count` points spread evenly along a Catmull-Rom curve through `points` ([r, h] pairs), with arc lengths."""
    p = [Vector(q) for q in points]
    dense = []
    for i in range(len(p) - 1):
        a, b = p[max(i - 1, 0)], p[i]
        c, d = p[i + 1], p[min(i + 2, len(p) - 1)]
        for k in range(16):
            t = k / 16
            dense.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                    + (3 * b - a - 3 * c + d) * t * t * t))
    dense.append(p[-1])
    acc = [0.0]
    for a, b in zip(dense, dense[1:]):
        acc.append(acc[-1] + (b - a).length)
    out, j = [], 0
    for i in range(count):
        s = acc[-1] * i / (count - 1)
        while j < len(acc) - 2 and acc[j + 1] < s:
            j += 1
        t = (s - acc[j]) / max(acc[j + 1] - acc[j], 1e-9)
        out.append((dense[j].lerp(dense[j + 1], t), s))
    return out


def rib(phase):
    """0 on top of a rib, 1 at the bottom of the groove between two ribs: round wide ribs, narrow grooves. Stitch
    columns are offset by half a rib (u + 0.5) so the shader's V sits on the rib and its dark gap in the groove."""
    s = 0.5 + 0.5 * math.cos(math.tau * phase)
    return 1.0 - math.sqrt(s)


def knitted(name, rows, cols, place, stitch, cap=None):
    """A knitted tube: `place(row, a)` gives the point of `row` at angle a (0..tau), `stitch(row, a)` its stitch
    column and row for the "Stitch" UV map. Faces point outward; `cap` closes the last row with a centre point."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("Stitch")
    grid = [[bm.verts.new(place(r, math.tau * c / cols)) for c in range(cols)] for r in range(rows)]
    for r in range(rows - 1):
        for c in range(cols):
            c2 = (c + 1) % cols
            quad = (grid[r][c], grid[r + 1][c], grid[r + 1][c2], grid[r][c2])
            f = bm.faces.new(quad)
            for loop, (rr, cc) in zip(f.loops, ((r, c), (r + 1, c), (r + 1, c + 1), (r, c + 1))):
                loop[uvl].uv = stitch(rr, math.tau * cc / cols)
    if cap is not None:
        centre = bm.verts.new(cap)
        r = rows - 1
        for c in range(cols):
            c2 = (c + 1) % cols
            f = bm.faces.new((grid[r][c], centre, grid[r][c2]))
            for loop, (rr, cc) in zip(f.loops, ((r, c), (r, c + 0.5), (r, c + 1))):
                loop[uvl].uv = stitch(rr, math.tau * cc / cols)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


# Proportions follow the owner's "Beanie Camper" turnaround (25 Oct 2026), measured off the sheet for a 1.45 m
# camper: a round head as wide as the sweater with the face low on it; a chunky ribbed beanie much wider than the head,
# tilted back so its thick folded cuff sits on the brow in front and on the nape behind, its crown slouching back;
# curls under the cuff round the sides and back; a boxy sweater with ribbed hem, cuffs and collar; round felt hands;
# brown felt trousers with stitched side seams and rolled cuffs; rounded boots with a stitched welt.
HEAD = Vector((0, 0.045, 1.065))     # head centre
HEAD_SIZE = Vector((0.62, 0.56, 0.6))
HAT_TILT = math.radians(23)          # the beanie leans back by this much
HAT_BASE = Vector((0, 0.0, 0.985))   # centre of the cuff's lower edge
HAT_RIBS = 28
HAT_ROW = 0.036                      # height of one knitted row on the beanie
SHIRT_COLS, SHIRT_ROW = 30, 0.03     # stitch columns round the sweater body, row height


def head_surface(a, z, out=0.0):
    """The point on the head at angle `a` (0 = front, + toward +X) and height z, pushed `out` metres outward."""
    half = HEAD_SIZE / 2
    k = max(0.0, 1.0 - ((z - HEAD.z) / half.z) ** 2) ** 0.5
    p = Vector((HEAD.x + math.sin(a) * half.x * k, HEAD.y + math.cos(a) * half.y * k, z))
    n = Vector(((p.x - HEAD.x) / half.x ** 2, (p.y - HEAD.y) / half.y ** 2, (p.z - HEAD.z) / half.z ** 2)).normalized()
    return p + n * out, n


def hat_frame(r, a, h):
    """Beanie space to model space: radius r and angle a round the beanie's axis, height h above the cuff's edge."""
    local = Vector((math.sin(a) * r, math.cos(a) * r * 0.95, h))
    return HAT_BASE + Matrix.Rotation(HAT_TILT, 3, "X") @ local


def cuff_bottom(a):
    """Height of the beanie's lower edge at angle a round the head (where the curls start)."""
    return hat_frame(0.36, a, 0.0).z


# --- Beanie: a thick folded cuff of square ribs, a groove at the fold, and a round crown of ribs that meet at the top
# and slouch back. The profile runs from a hidden lining (so nothing shows through where the shader frays an edge),
# down the inside of the cuff, round its rolled lower edge, up the outside, over the fold and up the crown to the top.
CUFF_H = 0.15
HAT_PROFILE = [(0.03, 0.43), (0.2, 0.4), (0.3, 0.31), (0.33, 0.2), (0.335, 0.035), (0.35, 0.004), (0.373, -0.006), (0.393, 0.012), (0.402, 0.05),
        (0.406, 0.112), (0.4, 0.143), (0.383, 0.158), (0.362, 0.166), (0.382, 0.188), (0.4, 0.24),
        (0.4, 0.31), (0.365, 0.39), (0.29, 0.455), (0.17, 0.497), (0.03, 0.51)]
hat_rows = profile(HAT_PROFILE, 46)
HAT_TOP = hat_rows[-1][0].y
LINING = next(i for i, ((r, h), s) in enumerate(hat_rows) if h < 0.03)


def hat_place(row, a):
    (r, h), s = hat_rows[row]
    crown = max(0.0, (h - CUFF_H) / (HAT_TOP - CUFF_H))
    depth = 0.024 if h < CUFF_H + 0.005 else 0.022 * min(1.0, r / 0.3)
    if row < LINING:            # the hidden lining inside the hat: no ribs
        depth = 0.0
    r -= depth * rib(a * HAT_RIBS / math.tau)
    p = hat_frame(r, a, h)
    # Slouch: the crown hangs back and a little down behind, more toward the top.
    p += Vector((0, -0.075, -0.02)) * crown ** 1.6
    return p


def hat_stitch(row, a):
    s = hat_rows[row][1]
    return (a * HAT_RIBS / math.tau + 0.5, -s / (1.4 * HAT_ROW))


parts.append((knitted("beanie", len(hat_rows), HAT_RIBS * 4, hat_place, hat_stitch,
        cap=hat_frame(0, 0, HAT_TOP + 0.002) + Vector((0, -0.075, -0.02))),
        KNIT_ROWS, HAT))

# --- Sweater body: a boxy lathe (oval in section), ribbed hem and collar.
SHIRT_PROFILE = [(0.19, 0.45), (0.205, 0.405), (0.225, 0.387), (0.248, 0.39), (0.262, 0.42), (0.262, 0.462),
        (0.252, 0.476), (0.262, 0.495), (0.27, 0.56), (0.266, 0.63), (0.248, 0.685), (0.205, 0.722),
        (0.16, 0.742), (0.136, 0.748), (0.146, 0.765), (0.145, 0.792), (0.128, 0.802), (0.11, 0.785)]
shirt_rows = profile(SHIRT_PROFILE, 32)


def shirt_place(row, a):
    (r, z), s = shirt_rows[row]
    if z < 0.474:                                   # hem: 24 ribs
        r -= 0.012 * rib(a * 24 / math.tau) * (1.0 if r > 0.23 else 0.5)
    elif z > 0.75 or (z > 0.744 and r < 0.15):      # collar: 24 ribs
        r -= 0.01 * rib(a * 24 / math.tau)
    # Boxy: a squarer oval than an ellipse, a little deeper at the chest.
    x, y = math.sin(a), math.cos(a)
    sq = (abs(x) ** 3 + abs(y) ** 3) ** (-1 / 3)
    k = 1.0 + (sq - 1.0) * 0.35
    return Vector((x * r * k, y * r * k * 0.8, z))


def shirt_stitch(row, a):
    (r, z), s = shirt_rows[row]
    cols = 24 if z > 0.744 or z < 0.474 else SHIRT_COLS
    return (a * cols / math.tau + 0.5, -s / (1.4 * SHIRT_ROW))


parts.append((knitted("sweater", len(shirt_rows), 96, shirt_place, shirt_stitch), KNIT_ROWS, SHIRT))

# --- Sleeves: a tube from inside the shoulder to a ribbed cuff, then the hand.
if TPOSE:
    SHOULDER, HAND = Vector((0.19, 0.0, 0.655)), Vector((0.555, 0.0, 0.66))
else:
    SHOULDER, HAND = Vector((0.19, 0.0, 0.645)), Vector((0.41, 0.04, 0.3))  # data/tuning.json camper.hand_pos
SLEEVE_PROFILE_T = [(0.02, 0.0), (0.062, 0.03), (0.08, 0.075), (0.079, 0.2), (0.073, 0.6), (0.068, 0.79),
        (0.066, 0.81), (0.079, 0.83), (0.081, 0.96), (0.07, 1.0), (0.045, 1.01)]


def sleeve(sx):
    hand = Vector((HAND.x * sx, HAND.y, HAND.z))
    start = Vector((SHOULDER.x * sx, SHOULDER.y, SHOULDER.z))
    d = (hand - start)
    length = d.length - 0.055
    d.normalize()
    side = d.cross(Vector((0, 1, 0))).normalized()
    up = side.cross(d).normalized()
    rows = profile([(r, t * length) for r, t in SLEEVE_PROFILE_T], 22)
    def place(row, a):
        (r, t), s = rows[row]
        if t > 0.82 * length and r > 0.07:
            r -= 0.01 * rib(a * 12 / math.tau)
        return start + d * t + (up * math.cos(a) - side * math.sin(a)) * r
    def stitch(row, a):
        return (a * 12 / math.tau + 0.5, -rows[row][1] / (1.4 * 0.028))
    return knitted("sleeve", len(rows), 48, place, stitch), hand


for sx in (-1, 1):
    me, hand = sleeve(sx)
    parts.append((me, KNIT_ROWS, SHIRT))
    parts.append((fused("hand", lambda bm, h=hand: ellipsoid(bm, (0.15, 0.145, 0.155), h), decimate=0.25),
            FELT, MITTEN))

# --- Trousers: hips under the sweater, straight legs and a fat rolled cuff on each.
LEG_X = 0.12


def trousers(bm):
    ellipsoid(bm, (0.44, 0.34, 0.2), (0, 0, 0.41))
    for sx in (-1, 1):
        limb(bm, (sx * 0.11, 0.0, 0.4), (sx * LEG_X, 0.0, 0.15), 0.104)
        for i in range(20):
            a = math.tau * i / 20
            ellipsoid(bm, (0.09, 0.09, 0.084), (sx * LEG_X + math.sin(a) * 0.095, math.cos(a) * 0.095, 0.152),
                    segs=12)


def trouser_shape(co):
    # A crease where the rolled cuff turns back over the leg.
    k = 1.0 - 0.08 * math.exp(-((co.z - 0.198) / 0.01) ** 2)
    cx = LEG_X if co.x > 0 else -LEG_X
    return Vector((cx + (co.x - cx) * k, co.y * k, co.z)) if co.z < 0.3 else co
parts.append((fused("trousers", trousers, smooth=0.5, repeat=6, decimate=0.2, after=trouser_shape), FELT, PANTS))


def boots(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.225, 0.34, 0.165), (sx * LEG_X, 0.04, 0.068))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.088, radius2=0.09, depth=0.09,
                matrix=Matrix.Translation((sx * LEG_X, 0.0, 0.1)))
parts.append((fused("boots", boots, decimate=0.18, after=lambda co: Vector((co.x, co.y, max(co.z, 0.0)))),
        FELT, BOOTS))

# --- Head with small ears, and the face: bead eyes with a glint, a thick stitched smile.
def head(bm):
    ellipsoid(bm, HEAD_SIZE, HEAD, segs=48)
    for sx in (-1, 1):
        ellipsoid(bm, (0.05, 0.075, 0.095), (sx * 0.3, HEAD.y - 0.03, 0.925), segs=16)
def head_shape(co):
    # Tuck the crown of the head in where the beanie covers it, so it never pokes through the fold.
    k = 1.0 - 0.2 * max(0.0, (co.z - 1.12) / 0.25) ** 1.5
    return Vector((co.x * k, HEAD.y + (co.y - HEAD.y) * k, co.z))
parts.append((fused("head", head, smooth=0.8, repeat=10, decimate=0.13, after=head_shape), FELT, SKIN))

EYE_Z, EYE_X = 0.97, 0.112


def on_face(x, z, out):
    a = math.asin(max(-1.0, min(1.0, x / (HEAD_SIZE.x / 2 * max(0.05, 1 - ((z - HEAD.z) / (HEAD_SIZE.z / 2)) ** 2) ** 0.5))))
    return head_surface(a, z, out)


def eyes(bm):
    for sx in (-1, 1):
        p, n = on_face(sx * EYE_X, EYE_Z, -0.004)
        rot = n.to_track_quat("Y", "Z").to_matrix()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1.0,
                matrix=Matrix.LocRotScale(p, rot, Vector((0.029, 0.02, 0.037))))
parts.append((plain("eyes", eyes), FELT, INK))


def glints(bm):
    for sx in (-1, 1):
        p, n = on_face(sx * EYE_X - 0.01, EYE_Z + 0.014, 0.012)
        ellipsoid(bm, (0.012, 0.008, 0.014), p, segs=8)
parts.append((plain("glints", glints), FELT, SHINE))

smile = []
for i in range(13):
    x = -0.07 + 0.14 * i / 12
    smile.append(on_face(x, 0.858 + 0.036 * (x / 0.07) ** 2, 0.004)[0])
parts.append((thread("smile", smile, 0.011, sides=8), FELT, INK))

# --- Curls: a mop of little felt balls packed on the head under the cuff, its lower edge a row of bigger curls:
# a short fringe on the brow, longer locks by the cheeks, the ears left bare, and a full back down to the neck.
def hair_line(a):
    """How far below the cuff's edge the hair reaches at angle a round the head (0 = front)."""
    side = abs(a)
    if side < 0.5:
        return 0.035                                      # fringe
    if side < 1.1:
        return 0.035 + 0.09 * (side - 0.5) / 0.6          # longer toward the cheeks
    if side < 1.35:
        return 0.15                                       # framing the face
    if side < 1.75:
        return 0.0                                        # over the ears, so the ears show
    return 0.1 + 0.12 * min(1.0, (side - 1.75) / 0.6)     # behind the ears and the back, down to the neck


def curls(bm):
    rnd = random.Random(7)
    n = 44
    for i in range(n):
        a = math.tau * (i + 0.5) / n - math.pi
        top = cuff_bottom(a) + 0.05
        reach = hair_line(a + rnd.uniform(-0.04, 0.04)) + 0.05
        rows = max(2, round(reach / 0.04))
        for j in range(rows + 1):
            t = j / rows
            z = top - reach * t
            p, _ = head_surface(a + (0.5 * (j % 2)) * math.tau / n, z, 0.004 + 0.012 * t)
            size = (0.046 + 0.024 * t * t) * rnd.uniform(0.85, 1.15)
            ellipsoid(bm, (size, size, size * 1.1), p, segs=12)
# The mop is drawn with tiny stitches, which read as crinkly curls of yarn.
parts.append((stitch_round(fused("curls", curls, smooth=0.3, repeat=1, decimate=0.2), HEAD, 64, 0.016), KNIT_ROWS, HAIR))

# --- Stitches: a running stitch down the outside of each trouser leg and round each boot's welt.
def stitches(bm):
    for sx in (-1, 1):
        running_stitch(bm, [(sx * (LEG_X + 0.108), 0.0, 0.385), (sx * (LEG_X + 0.11), 0.0, 0.215)], radius=0.0065)
        welt = []
        for i in range(49):
            t = math.tau * i / 48
            welt.append((sx * LEG_X + math.sin(t) * 0.106, 0.04 + math.cos(t) * 0.16, 0.026))
        running_stitch(bm, welt, length=0.024, gap=0.014, radius=0.0062)
parts.append((plain("stitches", stitches), FELT, THREAD))

# One mesh: every part's corners carry (weave, slot) in the first UV map and the stitch grid in the second.
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
st = bm.loops.layers.uv.new("Stitch")
for me, weave, slot in parts:
    print("part", me.name, len(me.vertices))
    src = bmesh.new()
    src.from_mesh(me)
    src_st = src.loops.layers.uv.get("Stitch")
    vmap = {v: bm.verts.new(v.co) for v in src.verts}
    for f in src.faces:
        try:
            nf = bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:   # the decimate can leave a doubled face; one copy is enough
            continue
        nf.smooth = True
        for nl, ol in zip(nf.loops, f.loops):
            nl[uv].uv = (weave, slot)
            nl[st].uv = ol[src_st].uv if src_st else (0.0, 0.0)
    src.free()
me = bpy.data.meshes.new("knit_camper")
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new("knit_camper", me)
scene.collection.objects.link(ob)
lo = min(v.co.z for v in me.vertices)
hi = max(v.co.z for v in me.vertices)
print("knit_camper faces", len(me.polygons), "verts", len(me.vertices), "height %.3f..%.3f" % (lo, hi))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_texcoords=True,
        export_normals=True, export_yup=True, export_apply=True)
