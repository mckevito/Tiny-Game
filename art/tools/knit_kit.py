# Shared Blender helpers for knitted and felt models built from code (the method is in art/RECIPE.md). A build
# script imports this, adds its parts to the one mesh BM with the shapes below, and ends with finish(name):
#   blender --background --factory-startup --python art/<kind>/<name>/build_<name>.py -- OUT.glb [--pose=t]
# Every vertex carries UV.x the weave (data/art.json "weaves"), UV.y its slot (an index into the model's file_slots in
# data/models.json), a second UV map "Stitch" (column and row for knit; ply and twist for yarn) and, from finish(),
# a baked shade in its colour. Blender: +Z up, +Y is the front (glTF turns that into +Y up, -Z front). Metres, origin
# at the ground centre. Original work, CC BY 4.0 (CREDITS.md).
import bpy, bmesh, json, math, os, sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else ""
T_POSE = "--pose=t" in ARGS   # arms straight out, for comparing with a turnaround sheet

with open(os.path.join(ROOT, "data", "art.json")) as _f:
    _WEAVES = json.load(_f)["weaves"]
FELT, KNIT_MAP, RIB_MAP, YARN, BEAD = (_WEAVES[k] for k in ("felt", "knit_map", "rib_map", "yarn", "bead"))
KNIT_ROW = 0.42  # a knit row's height in column widths: the sheet knits short rows, each V's legs leaning out
OCCLUSION = (24, 0.06, 0.55)    # rays per vertex, how far they look (metres), and how dark a fully closed-in spot goes

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
    """Copies a Blender mesh (from fused(), say) into the model, painted with one slot."""
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


def smoothstep(e0, e1, x):
    x = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return x * x * (3 - 2 * x)


def ribbed(P, ribs, per, row_h, depth_of, weights_of=None):
    """Ribs on a knitted part: rings P of `ribs` columns with `per` vertices each get ridges pushed out along the
    surface by depth_of(j); weights_of(j) blends in decreases (half, then a quarter of the ribs), as on a hat's crown.
    Returns the rings and their stitch map, rows `row_h` metres apart."""
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


def bake_occlusion(bm, occlusion=OCCLUSION):
    """Ambient occlusion per vertex: how much of the model lies close round it (under a hat's cuff, between curls,
    in folds and armpits), as a grey the game multiplies into each swatch, like the soft shade in a photo."""
    rays, reach, strength = occlusion
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


def finish(name, occlusion=OCCLUSION):
    """Bakes the shade into the vertex colour, prints the vertex budget per part, and writes OUT as a GLB with both UV
    maps and the colour (no materials: the game paints it from the palette)."""
    BM.normal_update()
    shade = bake_occlusion(BM, occlusion)
    me = bpy.data.meshes.new(name)
    BM.to_mesh(me)
    BM.free()
    me.use_auto_smooth = True
    me.auto_smooth_angle = math.pi
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for k, g in enumerate(shade):
        col.data[k].color = (g, g, g, 1.0)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("%s verts %d tris %d" % (name, len(me.vertices), tris))
    for k, v in sorted(COUNT.items(), key=lambda kv: -kv[1]):
        print("  %-14s %6d verts" % (k, v))
    zs = [v.co.z for v in me.vertices]
    print("height %.3f (bottom %.3f)" % (max(zs), min(zs)))
    print("shade: darkest %.2f, mean %.2f" % (min(shade), sum(shade) / len(shade)))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_texcoords=True,
            export_normals=True, export_colors=True, export_yup=True, export_apply=True)
