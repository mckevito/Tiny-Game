# Builds the knitted camper (art/characters/knit_camper/knit_camper.glb) in Blender, from code only.
#   blender --background --factory-startup --python art/characters/knit_camper/build_knit_camper.py -- OUT.glb
# Add --pose=t to hold the arms straight out like the owner's turnaround (for review); by default they hang down.
# It follows the owner's "Beanie Camper" T-pose turnaround (25 Oct 2026). Knitted parts are grids whose columns are
# the knit's own columns: ribs are real ridges with creased grooves, and every vertex carries its stitch position
# (column, row) in a second UV map, so the felt shader draws each V stitch along its column (data/art.json "weaves"
# knit_map and rib_map). Felt parts are overlapping shapes fused by a voxel remesh, with stitched seams on top.
# The game paints the camper: UV.x is the weave and UV.y the slot index (data/models.json "knit_camper" file_slots).
# Blender: +Z up, +Y is the front (glTF turns that into +Y up, -Z front). Metres, origin at the ground centre.
# Original work, CC BY 4.0 (CREDITS.md).
import bpy, bmesh, math, random, sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
T_POSE = "--pose=t" in ARGS

FELT, KNIT_MAP, RIB_MAP, YARN, BEAD = 0, 5, 6, 7, 8
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE, THREAD, HAIR_SHADE = range(12)
KNIT_ROW = 0.42  # a knit row's height in column widths: the sheet knits short rows, each V's legs leaning out

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
BM = bmesh.new()
UV = BM.loops.layers.uv.new("UVMap")
ST = BM.loops.layers.uv.new("Stitch")
COUNT = {}


def face(verts, weave, slot, stitch=None):
    f = BM.faces.new(verts)
    f.smooth = True
    for k, loop in enumerate(f.loops):
        loop[UV].uv = (weave, slot)
        s = stitch[k] if stitch else (0.0, 0.0)
        loop[ST].uv = (s[0], 1.0 - s[1])  # glTF flips V, so the game reads the row as written
    return f


def counted(name, n):
    COUNT[name] = COUNT.get(name, 0) + n


# ---------------------------------------------------------------------------------------------------------------
# Grids: ring j runs along a part, column i around it (anticlockwise seen from the tip of the part's axis), so
# faces point out. A closed grid joins its last column to its first and reads that column's stitch u as u + period.

def grid(name, P, S, weave, slot, closed=True, period=0.0, sharp=None):
    vs = [[BM.verts.new(p) for p in ring] for ring in P]
    n = len(P[0])
    wf = weave if callable(weave) else (lambda j: weave)
    faces = []
    for j in range(len(P) - 1):
        for i in range(n if closed else n - 1):
            i2 = (i + 1) % n
            q = [vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i]]
            s = [S[j][i], S[j][i2], S[j + 1][i2], S[j + 1][i]]
            if closed and i2 == 0:
                s[1] = (s[1][0] + period, s[1][1])
                s[2] = (s[2][0] + period, s[2][1])
            faces.append(face(q, wf(j), slot, s))
    if sharp:
        for j in range(len(P) - 1):
            for i in sharp(j):
                e = BM.edges.get([vs[j][i], vs[j + 1][i]])
                if e:
                    e.smooth = False
    counted(name, sum(len(r) for r in P))
    return vs, faces


def cap(name, ring, ring_st, apex, apex_v, weave, slot, period, at_start=False):
    """Closes a ring with a fan to one apex vertex (a pole)."""
    a = BM.verts.new(apex)
    n = len(ring)
    for i in range(n):
        i2 = (i + 1) % n
        s1, s2 = ring_st[i], ring_st[i2]
        if i2 == 0:
            s2 = (s2[0] + period, s2[1])
        tri, st = [ring[i], ring[i2], a], [s1, s2, ((s1[0] + s2[0]) * 0.5, apex_v)]
        if at_start:
            tri.reverse()
            st.reverse()
        face(tri, weave, slot, st)
    counted(name, 1)


def ring_points(a, b, count, n_exp=2.0):
    """`count` points spaced evenly by length round a superellipse with half-axes a (x) and b (y), starting at the
    back (0, -b) and going anticlockwise seen from above."""
    dense = []
    m = 720
    for k in range(m + 1):
        t = -math.pi / 2 + math.tau * k / m
        c, s = math.cos(t), math.sin(t)
        dense.append((a * math.copysign(abs(c) ** (2.0 / n_exp), c), b * math.copysign(abs(s) ** (2.0 / n_exp), s)))
    lens = [0.0]
    for k in range(1, len(dense)):
        lens.append(lens[-1] + math.dist(dense[k], dense[k - 1]))
    total = lens[-1]
    out, k = [], 0
    for i in range(count):
        want = total * i / count
        while lens[k + 1] < want:
            k += 1
        f = (want - lens[k]) / max(lens[k + 1] - lens[k], 1e-9)
        out.append((dense[k][0] + (dense[k + 1][0] - dense[k][0]) * f, dense[k][1] + (dense[k + 1][1] - dense[k][1]) * f))
    return out


def rib(f, sharpness=0.5):
    """Rib height 0..1 across one column (f = 0..1): a round cord with a narrow groove at f = 0."""
    return math.sin(math.pi * (f % 1.0)) ** sharpness


def normals_of(P, closed=True):
    """Surface normals of a grid by finite differences (rings along, columns around)."""
    out = []
    n, rows = len(P[0]), len(P)
    for j in range(rows):
        row = []
        for i in range(n):
            a = P[j][(i + 1) % n] if closed else P[j][min(i + 1, n - 1)]
            b = P[j][(i - 1) % n] if closed else P[j][max(i - 1, 0)]
            c = P[min(j + 1, rows - 1)][i]
            d = P[max(j - 1, 0)][i]
            nrm = (a - b).cross(c - d)
            row.append(nrm.normalized() if nrm.length > 1e-12 else Vector((0, 0, 0)))
        out.append(row)
    return out


def lathe(profile, cols, per_col, row_h, n_exp=2.0, ribs=None, v_from_end=False):
    """A knitted tube round local +Z. profile: [(z, a, b)], half-axes a (x) and b (y) of each ring. `cols` knit
    columns with `per_col` vertices each; stitch u counts columns, v counts rows of `row_h` up each column (or down
    from the far end with v_from_end). ribs(j) -> depth in metres for ring j (0 for plain stockinette)."""
    n = cols * per_col
    P = []
    for z, a, b in profile:
        P.append([Vector((x, y, z)) for x, y in ring_points(a, b, n, n_exp)])
    N = normals_of(P)
    S = [[(0.0, 0.0)] * n for _ in P]
    for i in range(n):
        acc = 0.0
        for j in range(len(P)):
            if j:
                acc += (P[j][i] - P[j - 1][i]).length
            S[j][i] = (i / per_col, acc / row_h)
    if v_from_end:
        for i in range(n):
            top = S[-1][i][1]
            for j in range(len(P)):
                S[j][i] = (S[j][i][0], top - S[j][i][1])
    if ribs:
        for j in range(len(P)):
            depth = ribs(j)
            if depth <= 0.0:
                continue
            for i in range(n):
                P[j][i] = P[j][i] + N[j][i] * depth * (rib(i / per_col) - 1.0)
    return P, S


def transformed(P, m):
    return [[m @ p for p in ring] for ring in P]


def ellipsoid_grid(centre, radii, cols=32, rings=20, basis=None):
    """Positions of an ellipsoid as rings from the bottom pole to the top (poles left out)."""
    basis = basis or Matrix.Identity(3)
    P = []
    for j in range(1, rings):
        phi = -math.pi / 2 + math.pi * j / rings
        P.append([Vector(centre) + basis @ Vector((radii[0] * math.cos(phi) * math.cos(t), radii[1] * math.cos(phi)
                * math.sin(t), radii[2] * math.sin(phi))) for t in [math.tau * i / cols for i in range(cols)]])
    return P


def ellipsoid(name, centre, radii, slot, cols=32, rings=20, basis=None, weave=FELT):
    basis = basis or Matrix.Identity(3)
    P = ellipsoid_grid(centre, radii, cols, rings, basis)
    S = [[(0.0, 0.0)] * cols for _ in P]
    vs, _ = grid(name, P, S, weave, slot)
    cap(name, vs[0], S[0], Vector(centre) + basis @ Vector((0, 0, -radii[2])), 0, weave, slot, 0, at_start=True)
    cap(name, vs[-1], S[-1], Vector(centre) + basis @ Vector((0, 0, radii[2])), 0, weave, slot, 0)


def tube(name, points, radius, slot, sides=8, lobes=0, twist=0.0, lobe_depth=0.0, taper=None, weave=FELT, yarn=None):
    """A tube along a polyline with rounded ends. lobes > 0 twists that many plies round it (`twist` turns per
    metre); taper(s) scales the radius along its length (s 0..1). yarn = (plies, pitch) makes a twisted strand
    instead: the stitch map counts plies round it and twists (one every `pitch` metres) along it, for the yarn weave,
    and each ply bulges where the shader draws it."""
    pts = [Vector(p) for p in points]
    lengths = [0.0]
    for k in range(1, len(pts)):
        lengths.append(lengths[-1] + (pts[k] - pts[k - 1]).length)
    total = max(lengths[-1], 1e-6)
    P = []
    prev_side = None
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        if prev_side is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            side = t.cross(ref).normalized()
        else:
            side = (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        up = t.cross(side).normalized()
        s = lengths[k] / total
        r0 = radius * (taper(s) if taper else 1.0)
        ring = []
        for i in range(sides):
            a = math.tau * i / sides
            if yarn:
                r = r0 * (1.0 - lobe_depth * math.cos(yarn[0] * a + math.tau * lengths[k] / yarn[1]))
            else:
                r = r0 * (1.0 + lobe_depth * math.cos(lobes * (a - twist * lengths[k]))) if lobes else r0
            ring.append(p + (side * math.cos(a) + up * math.sin(a)) * r)
        P.append(ring)
    if yarn:
        S = [[(yarn[0] * i / sides, lengths[k] / yarn[1]) for i in range(sides)] for k in range(len(P))]
    else:
        S = [[(0.0, 0.0)] * sides for _ in P]
    period = yarn[0] if yarn else 0.0
    vs, _ = grid(name, P, S, weave, slot, period=period)
    t0 = (pts[1] - pts[0]).normalized()
    t1 = (pts[-1] - pts[-2]).normalized()
    r_start = radius * (taper(0.0) if taper else 1.0)
    r_end = radius * (taper(1.0) if taper else 1.0)
    cap(name, vs[0], S[0], pts[0] - t0 * r_start * 0.8, S[0][0][1], weave, slot, period, at_start=True)
    cap(name, vs[-1], S[-1], pts[-1] + t1 * r_end * 0.8, S[-1][0][1], weave, slot, period)


def append_mesh(name, me, slot, weave=FELT):
    """Copies a Blender mesh into the camper, painted with one slot."""
    base = len(BM.verts)
    vs = [BM.verts.new(v.co) for v in me.vertices]
    for poly in me.polygons:
        try:
            face([vs[k] for k in poly.vertices], weave, slot)
        except ValueError:
            pass
    counted(name, len(vs))


def fused(name, blobs, voxel=0.008, smooth=0.6, repeat=6, decimate=0.25, after=None):
    """Overlapping ellipsoids [(centre, radii, basis)] fused by a voxel remesh, softened and thinned."""
    bm = bmesh.new()
    for centre, radii, basis in blobs:
        m = Matrix.Translation(Vector(centre)) @ (basis or Matrix.Identity(3)).to_4x4() @ Matrix.Diagonal(
                (radii[0], radii[1], radii[2], 1.0))
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=1.0, matrix=m)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    mod = ob.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.factor = smooth
    sm.iterations = repeat
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    if after:
        for v in out.vertices:
            v.co = after(v.co.copy())
    ob = bpy.data.objects.new(name, out)
    scene.collection.objects.link(ob)
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = decimate
    dg = bpy.context.evaluated_depsgraph_get()
    final = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return final


def basis_from(normal, up=Vector((0, 0, 1))):
    """A rotation whose z axis is `normal` and whose y axis leans toward `up`."""
    n = Vector(normal).normalized()
    y = (up - n * up.dot(n)).normalized()
    x = y.cross(n)
    return Matrix((x, y, n)).transposed()


# ---------------------------------------------------------------------------------------------------------------
# Proportions, measured off the owner's turnaround (25 Oct 2026) for a camper 1.45 m tall: the head and beanie are
# half the height; the beanie is wider than the head (0.81 m), tilted back about 20 degrees on a thick folded cuff,
# with curls filling the gap round the head; a boxy sweater with ribbed hem, cuffs and mock neck; felt mitten hands;
# chunky brown felt trousers with stitched side seams and rolled cuffs; round felt boots with a stitched welt.

HEAD_C = Vector((0.0, 0.035, 1.0))
HEAD_R = (0.295, 0.27, 0.24)


def head_y(x, z):
    """Where the face's surface is (y) at a given x and z."""
    k = 1.0 - (x / HEAD_R[0]) ** 2 - ((z - HEAD_C.z) / HEAD_R[2]) ** 2
    return HEAD_C.y + HEAD_R[1] * math.sqrt(max(k, 0.0))


def head_normal(p):
    d = p - HEAD_C
    return Vector((d.x / HEAD_R[0] ** 2, d.y / HEAD_R[1] ** 2, d.z / HEAD_R[2] ** 2)).normalized()


def head_radius(theta, z):
    """The head's horizontal radius at azimuth theta (0 = front, + toward the camper's right) and height z."""
    k = math.sqrt(max(1.0 - ((z - HEAD_C.z) / HEAD_R[2]) ** 2, 0.0))
    return k / math.sqrt((math.sin(theta) / HEAD_R[0]) ** 2 + (math.cos(theta) / HEAD_R[1]) ** 2)


def smoothstep(e0, e1, x):
    x = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return x * x * (3 - 2 * x)


# --- Head, ears and face -----------------------------------------------------------------------------------------
ellipsoid("head", HEAD_C, HEAD_R, SKIN, cols=48, rings=30)
for sx in (-1, 1):
    ear_c = Vector((sx * 0.262, HEAD_C.y - 0.08, 0.918))
    ellipsoid("ears", ear_c, (0.034, 0.044, 0.022), SKIN, cols=16, rings=10,
            basis=basis_from(Vector((sx, 0.25, 0.0))))
    # the ear's inner fold: a small rim on its front half
    rim = [ear_c + Vector((sx * 0.02, 0.008 + 0.022 * math.cos(a), 0.033 * math.sin(a))) for a in
            [math.radians(d) for d in range(-110, 111, 22)]]
    tube("ears", rim, 0.008, SKIN, sides=6)

for sx in (-1, 1):
    x, z = sx * 0.117, 0.972
    c = Vector((x, head_y(x, z), z))
    n = head_normal(c)
    b = basis_from(n)
    ellipsoid("eyes", c + n * 0.003, (0.029, 0.039, 0.016), INK, cols=16, rings=10, basis=b, weave=BEAD)
    # a small sheen on each button, up and toward the light
    ellipsoid("eyes", c + n * 0.016 + b @ Vector((-0.009, 0.017, 0.0)), (0.007, 0.009, 0.004), SHINE, cols=8,
            rings=6, basis=b, weave=BEAD)

smile = []
for k in range(17):
    a = math.radians(215 + 110 * k / 16)
    x, z = 0.086 * math.cos(a), 0.951 + 0.086 * math.sin(a)
    smile.append(Vector((x, head_y(x, z) + 0.002, z)))
tube("smile", smile, 0.0135, INK, sides=8, weave=BEAD)


# --- Beanie: a folded, ribbed cuff tipped back on the head, and an upright ribbed dome on it ---------------------
# Measured off the turnaround's outlines: the cuff tips back about 22 degrees (brow 1.16 m, nape 0.88 m) on a thick
# fold. The crown is a round dome standing upright over the head, its top a little behind the head's middle: it rises
# from just inside the fold, so the fold reads as a rolled lip in front, and swells out over the cuff at the back.
HAT_TILT = math.radians(22.0)
HAT_M = Matrix.Translation((0.0, -0.005, 1.02)) @ Matrix.Rotation(HAT_TILT, 4, "X")
CUFF_RIBS, CUFF_H, CUFF_THICK = 40, 0.15, 0.05
CUFF_RX, CUFF_RY = 0.395, 0.37     # the cuff's outside: a little wider than deep
CROWN_RIBS = 36
CROWN_TOP = Vector((0.0, -0.03, 1.47))    # where the crown's ribs meet
CROWN_R = (0.35, 0.29, 0.37)     # how far the dome swells out from under its top: to the sides, the front, the back
CROWN_EQ = (1.15, 1.28, 1.12)    # the height of that widest point there (it tips back like the cuff, but less)


def hat_ring(r, t, n):
    """n points round the hat's oval at local height t; r is the radius on a round 0.385 m cuff."""
    out = []
    for i in range(n):
        a = -math.pi / 2 + math.tau * i / n
        out.append(Vector((r * (CUFF_RX / 0.385) * math.cos(a), r * (CUFF_RY / 0.385) * math.sin(a), t)))
    return out


def cuff_profile():
    """The cuff's cross-section in (radius, height): up the inside, round the bottom fold, up the outside and over
    the top fold. Each point also carries how deep its ribs go (full on the outside, none deep inside)."""
    rho = CUFF_THICK * 0.5
    r_out = 0.385
    r_in = r_out - CUFF_THICK
    pts = [(r_in + 0.004, 0.035, 0.0)]
    for d in range(180, 361, 30):
        a = math.radians(d)
        pts.append((r_in + rho + rho * math.cos(a), rho + rho * math.sin(a), 0.4 if d < 270 else 1.0))
    for k in range(1, 5):
        t = rho + (CUFF_H - 2 * rho) * k / 5
        pts.append((r_out + 0.01 * t / CUFF_H, t, 1.0))
    for d in range(0, 181, 30):
        a = math.radians(d)
        pts.append((r_in + 0.01 + rho + rho * math.cos(a), CUFF_H - rho + rho * math.sin(a), 1.0 if d < 120 else 0.5))
    pts.append((r_in + 0.008, CUFF_H - 0.04, 0.0))
    return pts


def ribbed(P, ribs, per, row_h, depth_of, weights_of=None):
    """Ribs on a hat part: rings P of `ribs` columns with `per` vertices each get ridges pushed out along the surface
    by depth_of(j); weights_of(j) blends in the crown's decreases (half, then a quarter of the ribs)."""
    n = ribs * per
    N = normals_of(P)
    S = [[(0.0, 0.0)] * n for _ in P]
    for i in range(n):
        acc = 0.0
        for j in range(len(P)):
            if j:
                acc += (P[j][i] - P[j - 1][i]).length
            S[j][i] = (i / per, acc / row_h)
    out = [list(ring) for ring in P]
    for j in range(len(P)):
        d = depth_of(j)
        if d <= 0.0:
            continue
        w1, w2 = weights_of(j) if weights_of else (0.0, 0.0)
        for i in range(n):
            u = i / per
            g = rib(u) * (1 - w1) + rib(u / 2) * (w1 - w2) + rib(u / 4) * w2
            out[j][i] = P[j][i] + N[j][i] * d * (g - 1.0)
    return out, S


def cuff():
    prof = cuff_profile()
    per = 4
    n = CUFF_RIBS * per
    pitch = math.tau * 0.385 / CUFF_RIBS
    P, S = ribbed([hat_ring(r, t, n) for r, t, _ in prof], CUFF_RIBS, per, pitch * KNIT_ROW,
            lambda j: 0.017 * prof[j][2])
    grid("beanie cuff", transformed(P, HAT_M), S, RIB_MAP, HAT, period=CUFF_RIBS,
            sharp=lambda j: range(0, n, per) if prof[j][2] >= 0.5 and prof[min(j + 1, len(prof) - 1)][2] >= 0.5 else [])


def around_top(ring):
    """A tipped hat ring as seen from above round the crown's top: sorted (angle, horizontal distance, height)."""
    out = []
    for p in ring:
        q = HAT_M @ p
        dx, dy = q.x - CROWN_TOP.x, q.y - CROWN_TOP.y
        out.append((math.atan2(dy, dx), math.hypot(dx, dy), q.z))
    out.sort()
    return out


def at_angle(table, a):
    """(distance, height) of a ring from around_top() at angle a, read between its samples."""
    a = (a + math.pi) % math.tau - math.pi
    for k in range(len(table)):
        a0, r0, z0 = table[k - 1]
        a1, r1, z1 = table[k]
        if k == 0:
            a0 -= math.tau
        if a0 <= a <= a1:
            f = (a - a0) / max(a1 - a0, 1e-9)
            return r0 + (r1 - r0) * f, z0 + (z1 - z0) * f
    a0, r0, z0 = table[-1]
    a1, r1, z1 = table[0]
    f = (a - a0) / max(a1 + math.tau - a0, 1e-9)
    return r0 + (r1 - r0) * f, z0 + (z1 - z0) * f


def crown():
    """An upright dome whose ribs meet at its top in two decreases (36 -> 18 -> 9), as a knitted hat's do. Each rib
    column climbs from hidden inside the cuff's fold, out over the fold's inner edge with a crease, swells to the
    dome's widest point and curves over to the top."""
    per = 4
    n = CROWN_RIBS * per
    r_in = 0.385 - CUFF_THICK
    # the fold's inside, seen round the crown's top: hidden, at its lip, and the crease just above it
    folds = [around_top(hat_ring(r, t, 720)) for r, t in
             [(r_in + 0.004, CUFF_H - 0.035), (r_in + 0.004, CUFF_H - 0.01), (r_in - 0.002, CUFF_H + 0.01)]]
    steps = 16
    cols, phis = [], []
    for i in range(n):
        a = -math.pi / 2 + math.tau * i / n
        c, s_ = math.cos(a), math.sin(a)
        # the widest point along this column: an egg round the top, wider to the back than to the front
        ry = CROWN_R[1] if s_ > 0 else CROWN_R[2]
        r_eq = 1.0 / math.sqrt((c / CROWN_R[0]) ** 2 + (s_ / ry) ** 2)
        z_eq = CROWN_EQ[0] + (CROWN_EQ[1] - CROWN_EQ[0]) * max(s_, 0.0) ** 2 \
            - (CROWN_EQ[0] - CROWN_EQ[2]) * max(-s_, 0.0) ** 2
        h = CROWN_TOP.z - z_eq
        col = [at_angle(t, a) for t in folds]
        r_c, z_c = col[-1]
        # The column swells from the crease onto the dome (a quarter ellipse up to the top), meeting it at its widest
        # point, or just above the crease where the fold sits higher than that.
        ph0 = math.asin(min(max((z_c + 0.015 - z_eq) / h, 0.0), 0.9))
        r_j, z_j = r_eq * math.cos(ph0), z_eq + h * math.sin(ph0)
        for f in (0.35, 0.7):
            col.append((r_c + (r_j - r_c) * math.sin(f * math.pi / 2), z_c + (z_j - z_c) * f))
        for k in range(steps):
            ph = ph0 + (math.pi / 2 - ph0) * k / steps
            col.append((r_eq * math.cos(ph), z_eq + h * math.sin(ph)))
        cols.append([Vector((CROWN_TOP.x + r * c, CROWN_TOP.y + r * s_, z)) for r, z in col])
    rows = len(cols[0])
    dome_from = rows - steps  # the widest ring
    P = [[cols[i][j] for i in range(n)] for j in range(rows)]

    def dome(j):
        """How far over the dome ring j is, 0 at the widest ring to 1 at the top."""
        return max(j - dome_from, 0) / steps

    def weights(j):
        d = dome(j)
        return smoothstep(0.45, 0.55, d), smoothstep(0.72, 0.8, d)

    def count_at(d):
        return CROWN_RIBS if d < 0.5 else (CROWN_RIBS // 2 if d < 0.76 else CROWN_RIBS // 4)

    pitch = math.tau * 0.33 / CROWN_RIBS
    P, S = ribbed(P, CROWN_RIBS, per, pitch * KNIT_ROW,
            lambda j: 0.021 * (1.0 if j >= 2 else 0.4) * min(1.0, 1.25 * math.cos(math.radians(90.0 * dome(j)))),
            weights_of=weights)

    # Each band's stitch columns follow the rib count there, so V stitches stay on their ribs after a decrease.
    def band_count(j):
        return count_at((dome(j) + dome(j + 1)) * 0.5)

    vs = [[BM.verts.new(p) for p in ring] for ring in P]
    for j in range(len(P) - 1):
        k = band_count(j) / CROWN_RIBS
        for i in range(n):
            i2 = (i + 1) % n
            q = [vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i]]
            s = [S[j][i], S[j][i2], S[j + 1][i2], S[j + 1][i]]
            if i2 == 0:
                s[1] = (s[1][0] + CROWN_RIBS, s[1][1])
                s[2] = (s[2][0] + CROWN_RIBS, s[2][1])
            face(q, RIB_MAP, HAT, [(a * k, b) for a, b in s])
        step = per * CROWN_RIBS // band_count(j)
        for i in range(0, n, step):
            e = BM.edges.get([vs[j][i], vs[j + 1][i]])
            if e:
                e.smooth = False
    counted("beanie crown", n * len(P))
    apex = CROWN_TOP + Vector((0, 0, 0.003))
    ring_st = [(s[0] * (CROWN_RIBS // 4) / CROWN_RIBS, s[1]) for s in S[-1]]
    cap("beanie crown", vs[-1], ring_st, apex, S[-1][0][1] + 0.3, RIB_MAP, HAT, CROWN_RIBS // 4)
    # a little knot where the ribs meet
    ellipsoid("beanie crown", apex + Vector((0, 0, -0.006)), (0.024, 0.024, 0.014), HAT, cols=12, rings=8)


cuff()
crown()


# --- Hair: a felt mass under the beanie, filling the gap to the cuff, with twisted yarn curls over it ----------------
def cuff_inner(theta):
    """The cuff's lower inside edge at azimuth theta round the head: (horizontal distance from the head's axis,
    height)."""
    r_in = 0.385 - CUFF_THICK + 0.01
    best = None
    # the hat is tipped, so find the point on its inner edge that lies in the direction theta from the head's axis
    for k in range(360):
        a = math.tau * k / 360
        p = HAT_M @ Vector((r_in * (CUFF_RX / 0.385) * math.cos(a), r_in * (CUFF_RY / 0.385) * math.sin(a), 0.02))
        d = Vector((p.x - HEAD_C.x, p.y - HEAD_C.y))
        ang = math.atan2(d.x, d.y)
        err = abs((ang - theta + math.pi) % math.tau - math.pi)
        if best is None or err < best[0]:
            best = (err, d.length, p.z)
    return best[1], best[2]


HAIRLINE = [(0, 1.07), (25, 1.06), (45, 1.03), (62, 0.97), (75, 0.93), (88, 0.975), (100, 0.985), (112, 0.98),
            (125, 0.9), (140, 0.85), (160, 0.825), (180, 0.82)]


def hairline(theta):
    """Lowest point of the hair at azimuth theta: a fringe on the brow, curls down in front of the ears, the hair
    lifting over them, then down to the nape."""
    a = abs(math.degrees(theta))
    for (a0, z0), (a1, z1) in zip(HAIRLINE, HAIRLINE[1:]):
        if a <= a1:
            return z0 + (z1 - z0) * smoothstep(0.0, 1.0, (a - a0) / (a1 - a0))
    return HAIRLINE[-1][1]


def hair_at(theta, f, lift=0.0):
    """A point on the hair's outside: f 0 at the hairline, 1 tucked under the cuff, beyond 1 up into the hat."""
    low = hairline(theta)
    reach, top = cuff_inner(theta)
    if f <= 1.0:
        # From close on the skin at the hairline out to just inside the cuff, so curls never poke through it.
        z = low + (top + 0.015 - low) * f
        r_head = head_radius(theta, min(z, HEAD_C.z + HEAD_R[2] * 0.99))
        r = r_head + 0.012 + max(reach - r_head - 0.05, 0.0) * smoothstep(0.0, 1.0, f) ** 0.8
    else:
        z = top + 0.015 + (HEAD_C.z + HEAD_R[2] * 0.9 - top - 0.015) * min(f - 1.0, 1.0)
        r = head_radius(theta, z) + 0.02
    r += lift
    return Vector((HEAD_C.x + r * math.sin(theta), HEAD_C.y + r * math.cos(theta), z))


def hair_mass():
    cols, rows = 72, 10
    P = []
    for j in range(rows):
        f = -0.05 + 1.7 * j / (rows - 1)
        P.append([hair_at(math.pi - math.tau * i / cols, f, -0.002) for i in range(cols)])
    S = [[(0.0, 0.0)] * cols for _ in P]
    grid("hair", P, S, FELT, HAIR_SHADE)


# The curls: fat two-ply yarn locks coming out from under the cuff and ending in a curl, as on the turnaround: the
# fringe sweeps out to the sides, curls fall in front of the ears (which show) and down to the nape.
# (azimuth in degrees, + toward the camper's right; the height where the lock ends; how far it sweeps sideways as it
# falls, in degrees, + away from the middle of the face). Each is mirrored on the left.
LOCKS = [(0, 1.06, 6), (12, 1.055, 12), (25, 1.045, 18), (39, 1.025, 20), (54, 0.975, 10), (67, 0.925, 4),
         (81, 0.89, 0), (95, 0.975, 0), (109, 0.985, 0), (123, 0.88, 0), (137, 0.85, 0), (151, 0.83, 0),
         (166, 0.82, 0), (180, 0.815, 0)]
LOCK_WAVE = (0.6, 0.075)   # how far a lock waves from side to side (in lock radii), and the length of one wave
LOCK_R = (0.021, 0.025)    # a lock's radius, smallest to largest
LOCK_PLY = (2, 0.06)       # plies, and metres per full twist


def lock_path(theta, end_z, sweep, lock_r, phase=0.0):
    """From hidden under the cuff, out past its edge and down the head to end_z, then a curl turning outward (and
    the way the lock sweeps)."""
    reach, top = cuff_inner(theta)
    pts = []
    steps = max(int((top + 0.03 - end_z) / 0.008), 6)
    for k in range(steps + 1):
        z = top + 0.03 - (top + 0.03 - end_z) * k / steps
        f = smoothstep(top, end_z, z)
        th = theta + sweep * f
        r_head = head_radius(th, min(z, HEAD_C.z + HEAD_R[2] * 0.97))
        # a gentle S-wave once it is out from under the cuff
        th += LOCK_WAVE[0] * lock_r * f * math.sin(math.tau * (top - z) / LOCK_WAVE[1] + phase) / max(r_head, 0.1)
        inside = reach - lock_r - 0.008
        hug = r_head + lock_r + 0.012
        r = max(inside + (hug - inside) * f ** 0.7, r_head + lock_r * 0.85)
        pts.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
    last, prev = pts[-1], pts[-2]
    down = (last - prev).normalized()
    th = theta + sweep
    out = Vector((math.sin(th), math.cos(th), 0.0))
    if sweep:
        out = (out * 0.6 + Vector((math.cos(th), -math.sin(th), 0.0)) * math.copysign(0.8, sweep)).normalized()
    out = (out - down * out.dot(down)).normalized()
    side = down.cross(out).normalized()
    radius = lock_r * 0.95
    for k in range(1, 9):
        a = math.radians(36.0 * k)
        rr = radius * (1.0 - 0.3 * k / 8)
        pts.append(last + down * rr * math.sin(a) + out * rr * (1 - math.cos(a)) + side * 0.004 * k)
    return pts


def curls():
    rnd = random.Random(7)
    for a, end_z, sweep in LOCKS:
        for sx in ((1,) if a in (0, 180) else (1, -1)):
            if a == 0:
                sx = 1
            th = math.radians(sx * (a + rnd.uniform(-2.0, 2.0)))
            lock_r = rnd.uniform(*LOCK_R)
            pts = lock_path(th, end_z + rnd.uniform(-0.01, 0.01), math.radians(sx * sweep), lock_r,
                    rnd.uniform(0.0, math.tau))
            tube("hair", pts, lock_r, HAIR, sides=8, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                    taper=lambda s: 1.0 - 0.45 * max(0.0, s - 0.7) / 0.3)


hair_mass()
curls()


# --- Sweater: body with a ribbed hem, a ribbed mock neck, sleeves with ribbed cuffs --------------------------------
TORSO = [(0.392, 0.232, 0.192), (0.398, 0.252, 0.21), (0.41, 0.261, 0.219), (0.425, 0.263, 0.221),
         (0.44, 0.263, 0.221), (0.455, 0.262, 0.22), (0.466, 0.259, 0.217), (0.476, 0.252, 0.211),
         (0.50, 0.251, 0.209), (0.53, 0.25, 0.207), (0.56, 0.247, 0.204), (0.59, 0.243, 0.2), (0.62, 0.238, 0.196),
         (0.645, 0.232, 0.191), (0.665, 0.226, 0.186), (0.685, 0.218, 0.181), (0.70, 0.21, 0.175),
         (0.713, 0.2, 0.168), (0.725, 0.19, 0.16), (0.735, 0.18, 0.155), (0.742, 0.17, 0.15), (0.748, 0.158, 0.143),
         (0.752, 0.145, 0.135)]
SWEATER_COLS = 28


def torso():
    hem = lambda j: 0.007 if 0.395 < TORSO[j][0] < 0.47 else 0.003
    P, S = lathe(TORSO, SWEATER_COLS, 4, 1.46 / SWEATER_COLS * KNIT_ROW, n_exp=2.4, ribs=hem)
    vs, _ = grid("sweater", P, S, lambda j: RIB_MAP if TORSO[j + 1][0] <= 0.47 else KNIT_MAP, SHIRT,
            period=SWEATER_COLS, sharp=lambda j: range(0, len(P[0]), 4) if TORSO[j + 1][0] <= 0.47 else [])
    cap("sweater", vs[0], S[0], Vector((0, 0, 0.388)), S[0][0][1] - 0.5, RIB_MAP, SHIRT, SWEATER_COLS, at_start=True)
    cap("sweater", vs[-1], S[-1], Vector((0, 0, 0.756)), S[-1][0][1] + 0.5, KNIT_MAP, SHIRT, SWEATER_COLS)


COLLAR = [(0.70, 0.17, 0.156), (0.712, 0.177, 0.163), (0.725, 0.178, 0.164), (0.74, 0.175, 0.161),
          (0.755, 0.171, 0.157), (0.77, 0.167, 0.153), (0.782, 0.163, 0.15), (0.791, 0.157, 0.145),
          (0.796, 0.148, 0.137), (0.797, 0.138, 0.128), (0.79, 0.13, 0.12)]


def collar():
    P, S = lathe(COLLAR, 24, 4, 0.0445 * KNIT_ROW, ribs=lambda j: 0.009 if 0 < j < len(COLLAR) - 1 else 0.0)
    grid("collar", P, S, RIB_MAP, SHIRT, period=24, sharp=lambda j: range(0, len(P[0]), 4))


SLEEVE = [(-0.105, 0.03, 0.03), (-0.095, 0.052, 0.052), (-0.08, 0.067, 0.067), (-0.06, 0.079, 0.079),
          (-0.035, 0.086, 0.086), (0.0, 0.089, 0.089), (0.04, 0.089, 0.089), (0.08, 0.087, 0.087),
          (0.12, 0.085, 0.085), (0.16, 0.082, 0.082), (0.19, 0.08, 0.08), (0.203, 0.077, 0.077),
          (0.209, 0.08, 0.08), (0.222, 0.083, 0.083), (0.238, 0.084, 0.084), (0.254, 0.084, 0.084),
          (0.266, 0.082, 0.082), (0.274, 0.076, 0.076), (0.278, 0.066, 0.066), (0.275, 0.056, 0.056)]
SLEEVE_COLS = 12
SHOULDER = Vector((0.205, 0.0, 0.652))
HAND_AT = 0.345          # from the shoulder pivot to the mitten's middle, along the arm
ARM_DROP = math.radians(58.0)   # how far the arms hang below level in the game pose
ARM_FORWARD = math.radians(8.0)


def arm_matrix(sx):
    """Local +Z runs out along the arm from the shoulder pivot; the game pose lowers it and swings it forward."""
    out = Matrix.Rotation(sx * math.radians(90.0), 4, "Y")  # local z -> world +x (right arm) or -x (left arm)
    pose = Matrix.Identity(4)
    if not T_POSE:
        pose = Matrix.Rotation(sx * ARM_FORWARD, 4, "Z") @ Matrix.Rotation(sx * ARM_DROP, 4, "Y")
    return Matrix.Translation(SHOULDER * Vector((sx, 1, 1))) @ pose @ out


def arms():
    cuff_from = 0.205
    for sx in (-1, 1):
        P, S = lathe(SLEEVE, SLEEVE_COLS, 4, 0.0445 * KNIT_ROW, v_from_end=True,
                ribs=lambda j: 0.0065 if cuff_from < SLEEVE[j][0] < 0.275 else 0.002)
        m = arm_matrix(sx)
        vs, _ = grid("sleeves", transformed(P, m), S, lambda j: RIB_MAP if SLEEVE[j][0] >= cuff_from else KNIT_MAP,
                SHIRT, period=SLEEVE_COLS, sharp=lambda j: range(0, len(P[0]), 4) if SLEEVE[j][0] >= cuff_from else [])
        cap("sleeves", vs[0], S[0], m @ Vector((0, 0, SLEEVE[0][0] - 0.012)), S[0][0][1] + 0.3, KNIT_MAP, SHIRT,
                SLEEVE_COLS, at_start=True)
        cap("sleeves", vs[-1], S[-1], m @ Vector((0, 0, SLEEVE[-1][0] - 0.01)), 0.0, RIB_MAP, SHIRT, SLEEVE_COLS)
        ellipsoid("hands", m @ Vector((0, 0, HAND_AT)), (0.061, 0.06, 0.068), MITTEN, cols=24, rings=14,
                basis=m.to_3x3())
    hand = arm_matrix(1) @ Vector((0, 0, HAND_AT))
    print("mitten centre (Blender x, y, z): %.3f %.3f %.3f" % tuple(hand))


torso()
collar()
arms()


# --- Trousers, rolled cuffs, boots and their stitches ---------------------------------------------------------------
LEG_TOP, LEG_BOTTOM = Vector((0.117, 0.0, 0.38)), Vector((0.142, 0.005, 0.16))


def leg_at(f):
    return LEG_TOP.lerp(LEG_BOTTOM, f)


def trousers():
    blobs = [((0, 0, 0.405), (0.222, 0.172, 0.1), None)]
    for sx in (-1, 1):
        for k in range(13):
            f = k / 12
            c = leg_at(f)
            blobs.append(((sx * c.x, c.y, c.z), (0.12 - 0.008 * f, 0.146 - 0.01 * f, 0.05), None))
    return fused("trousers", blobs, voxel=0.008, decimate=0.22)


TROUSERS = trousers()
append_mesh("trousers", TROUSERS, PANTS)


def rolled_cuffs():
    for sx in (-1, 1):
        c = leg_at(1.0)
        centre = Vector((sx * c.x, c.y, 0.148))
        a, b, r = 0.116, 0.14, 0.027
        P = []
        n_major, n_minor = 36, 10
        for i in range(n_major):
            t = math.tau * i / n_major
            d = Vector((math.cos(t), math.sin(t), 0))
            ring = []
            for k in range(n_minor):
                ph = math.tau * k / n_minor
                ring.append(centre + Vector((a * math.cos(t), b * math.sin(t), 0)) + d * r * math.cos(ph)
                        + Vector((0, 0, r * 0.95 * math.sin(ph))))
            P.append(ring)
        S = [[(0.0, 0.0)] * n_minor for _ in P]
        # rings run round the leg (i), columns round the tube (k): close both ways
        vs = [[BM.verts.new(p) for p in ring] for ring in P]
        for i in range(n_major):
            for k in range(n_minor):
                q = [vs[i][k], vs[(i + 1) % n_major][k], vs[(i + 1) % n_major][(k + 1) % n_minor],
                        vs[i][(k + 1) % n_minor]]
                face(q, FELT, PANTS)
        counted("trouser cuffs", n_major * n_minor)


rolled_cuffs()


def boots():
    blobs = []
    for sx in (-1, 1):
        turn = Matrix.Rotation(sx * math.radians(-7.0), 3, "Z")
        blobs.append(((sx * 0.162, 0.035, 0.062), (0.118, 0.18, 0.066), turn))
        blobs.append(((sx * 0.152, -0.005, 0.108), (0.104, 0.128, 0.06), turn))
    return fused("boots", blobs, voxel=0.007, decimate=0.25,
            after=lambda co: Vector((co.x, co.y, max(co.z, 0.0))))


BOOTS_ME = boots()
append_mesh("boots", BOOTS_ME, BOOTS)


def surface_tree(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def hit(tree, origin, direction):
    loc, nrm, _, _ = tree.ray_cast(Vector(origin), Vector(direction).normalized())
    return (loc, nrm) if loc is not None else (None, None)


def running_stitch(name, path, slot, dash=0.022, gap=0.011, thick=0.0042, lift=0.0015):
    """Rice-grain stitches along a path of (point, normal) on a surface."""
    lengths = [0.0]
    for k in range(1, len(path)):
        lengths.append(lengths[-1] + (path[k][0] - path[k - 1][0]).length)
    d = gap * 0.5
    while d + dash <= lengths[-1]:
        mid = d + dash * 0.5
        k = 1
        while k < len(path) - 1 and lengths[k] < mid:
            k += 1
        f = (mid - lengths[k - 1]) / max(lengths[k] - lengths[k - 1], 1e-9)
        p = path[k - 1][0].lerp(path[k][0], f)
        n = path[k - 1][1].lerp(path[k][1], f).normalized()
        t = (path[k][0] - path[k - 1][0]).normalized()
        y = t
        x = y.cross(n).normalized()
        basis = Matrix((x, y, n)).transposed()
        ellipsoid(name, p + n * (lift + thick * 0.4), (thick, dash * 0.5, thick * 0.75), slot, cols=6, rings=4,
                basis=basis)
        d += dash + gap


def stitches():
    pants = surface_tree(TROUSERS)
    for sx in (-1, 1):
        path = []
        for k in range(16):
            f = 0.04 + 0.86 * k / 15
            c = leg_at(f)
            loc, nrm = hit(pants, (sx * c.x, c.y, c.z), (sx, 0, 0))
            if loc is not None:
                path.append((loc, nrm))
        running_stitch("seams", path, THREAD)
    # the fly and back seam: a thin dark cord down the middle to the crotch
    for sy in (-1, 1):
        path = []
        for k in range(8):
            z = 0.395 - 0.08 * k / 7
            loc, nrm = hit(pants, (0, 0, z), (0, sy, 0))
            if loc is not None:
                path.append(loc + nrm * 0.002)
        if len(path) > 1:
            tube("seams", path, 0.0035, BOOTS, sides=5)
    boot = surface_tree(BOOTS_ME)
    for sx in (-1, 1):
        centre = Vector((sx * 0.158, 0.03, 0.022))
        path = []
        for k in range(73):
            a = math.tau * k / 72
            loc, nrm = hit(boot, centre, (math.cos(a), math.sin(a), 0))
            if loc is not None:
                path.append((loc, nrm))
        running_stitch("welts", path, THREAD, dash=0.017, gap=0.01, thick=0.0036)


stitches()


# --- One mesh: UV.x weave, UV.y slot; UV2 the stitch map; vertex colour a baked shade ---------------------------------
OCCLUSION = (24, 0.06, 0.55)    # rays per vertex, how far they look (metres), and how dark a fully closed-in spot goes


def bake_occlusion(bm):
    """Ambient occlusion per vertex: how much of the camper lies close round it (under the cuff, between curls, in
    the fold and the armpits), as a grey the game multiplies into each swatch, like the soft shade in a photo."""
    rays, reach, strength = OCCLUSION
    tree = BVHTree.FromBMesh(bm)
    golden = math.pi * (3.0 - math.sqrt(5.0))
    dirs = []
    for k in range(rays):
        z = math.sqrt(1.0 - (k + 0.5) / rays)   # cosine-weighted over the hemisphere
        r = math.sqrt(1.0 - z * z)
        dirs.append(Vector((r * math.cos(golden * k), r * math.sin(golden * k), z)))
    out = []
    for v in bm.verts:
        n = v.normal
        if n.length < 0.5:
            out.append(1.0)
            continue
        basis = basis_from(n, Vector((0, 0, 1)) if abs(n.z) < 0.95 else Vector((1, 0, 0)))
        origin = v.co + n * 0.002
        closed = 0.0
        for d in dirs:
            loc, _, _, dist = tree.ray_cast(origin, basis @ d, reach)
            if loc is not None:
                closed += 1.0 - dist / reach
        out.append(1.0 - strength * closed / rays)
    return out


BM.normal_update()
SHADE = bake_occlusion(BM)
me = bpy.data.meshes.new("knit_camper")
BM.to_mesh(me)
BM.free()
me.use_auto_smooth = True
me.auto_smooth_angle = math.pi
col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
for k, g in enumerate(SHADE):
    col.data[k].color = (g, g, g, 1.0)
ob = bpy.data.objects.new("knit_camper", me)
scene.collection.objects.link(ob)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("knit_camper verts %d tris %d" % (len(me.vertices), tris))
for k, v in sorted(COUNT.items(), key=lambda kv: -kv[1]):
    print("  %-14s %6d verts" % (k, v))
zs = [v.co.z for v in me.vertices]
print("height %.3f (bottom %.3f)" % (max(zs), min(zs)))
print("shade: darkest %.2f, mean %.2f" % (min(SHADE), sum(SHADE) / len(SHADE)))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_texcoords=True,
        export_normals=True, export_colors=True, export_yup=True, export_apply=True)
