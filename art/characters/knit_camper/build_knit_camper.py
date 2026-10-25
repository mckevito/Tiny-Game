# Builds the knitted camper (art/characters/knit_camper/knit_camper.glb) in Blender, from code only.
#   blender --background --factory-startup --python art/characters/knit_camper/build_knit_camper.py -- OUT.glb
# Shapes are overlapping primitives fused by a voxel remesh and softened, so the camper reads as one stuffed toy.
# The game paints it: UV.x is the weave (data/art.json "weaves") and UV.y the slot index (data/models.json
# "knit_camper" file_slots), so colours come from the palette and swap per variant. Blender: +Z up, +Y is the front
# (glTF turns that into +Y up, -Z front). Metres, origin at the ground centre. Original work, CC BY 4.0 (CREDITS.md).
import bpy, bmesh, math, sys
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1]
FELT, KNIT = 0, 1
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE, THREAD = range(11)
VOXEL = 0.011

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def ellipsoid(bm, size, loc, rot=(0, 0, 0), segs=32):
    r = (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
            @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))
    m = Matrix.LocRotScale(Vector(loc), r, Vector(size) / 2)
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1.0, matrix=m)


def limb(bm, a, b, r, steps=8):
    a, b = Vector(a), Vector(b)
    for i in range(steps + 1):
        ellipsoid(bm, (r * 2, r * 2, r * 2), a.lerp(b, i / steps), segs=20)


def fused(name, build, smooth=0.6, repeat=8, decimate=0.3, after=None, knit=0.0):
    """Primitives from `build(bm)`, fused by a voxel remesh, smoothed and thinned; `after(v)` shapes each vertex and
    `knit` raises real stitches (metres) along the surface, so a knitted edge is bumpy, not smooth."""
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
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    if after:
        for v in out.vertices:
            v.co = after(v.co.copy())
    if knit > 0.0:
        out.update()
        for v in out.vertices:
            v.co = v.co + v.normal * knit * stitch(v.co)
    ob = bpy.data.objects.new(name, out)
    scene.collection.objects.link(ob)
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = decimate
    dg = bpy.context.evaluated_depsgraph_get()
    final = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return final


def plain(name, build):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(me)
    bm.free()
    return me


def thread(name, points, radius):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (*co, 1.0)
    ob = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return me


def ribs(centre_z, count, depth, z_from, z_to):
    """Knit ribs: pulls the radius in between `count` ribs round the Z axis, between two heights."""
    def shape(co):
        if not (z_from <= co.z <= z_to):
            return co
        a = math.atan2(co.x, co.y)
        # Narrow grooves between wide round ribs, so each rib reads as a chunky cord of yarn.
        k = 1.0 - depth * (0.5 * (1.0 - math.cos(count * a))) ** 3
        return Vector((co.x * k, co.y * k, co.z))
    return shape


def stitch(co):
    """Stockinette in 0..1: columns of V loops round the Z axis, rows up it (about 3.5 cm by 3 cm)."""
    a = math.atan2(co.x, co.y)
    u = a * 0.3 / 0.035
    v = co.z / 0.03
    cu, cv = u - math.floor(u), v - math.floor(v)
    side = 1.0 if cu < 0.5 else -1.0
    qx, qy = (cu * 2.0) % 1.0 - 0.5, cv - 0.5
    rx, ry = 0.82 * qx + side * 0.57 * qy, -side * 0.57 * qx + 0.82 * qy
    d = math.hypot(rx * 2.6, ry * 1.15)
    return max(0.0, min(1.0, (0.62 - d) / 0.44))


# Proportions follow the owner's "Beanie Camper" turnaround (25 Oct 2026): about 1.45 m tall, half of it head
# and hat; a tall ribbed beanie wider than the head with a thick folded cuff low on the brow; curls peeking out
# round the sides and back; a boxy knit sweater with ribbed hem, cuffs and turtleneck; felt hands; straight brown
# felt trousers with stitched side seams; rounded boots with a stitched welt.
HEAD_Z = 0.98
CUFF = 0.94   # bottom of the hat's cuff
parts = []  # (mesh, weave, slot)

def sweater(bm):
    ellipsoid(bm, (0.46, 0.38, 0.46), (0, 0, 0.57))
    ellipsoid(bm, (0.47, 0.37, 0.22), (0, 0, 0.45))
    # ribbed hem band and a short turtleneck
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.235, radius2=0.235, depth=0.07,
            matrix=Matrix.Translation((0, 0, 0.385)) @ Matrix.Diagonal((1, 0.78, 1, 1)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.15, radius2=0.14, depth=0.08,
            matrix=Matrix.Translation((0, -0.01, 0.76)) @ Matrix.Diagonal((1, 0.9, 1, 1)))
def sweater_shape(co):
    co = ribs(0, 36, 0.08, 0.345, 0.42)(co)
    return ribs(0, 24, 0.12, 0.72, 0.81)(co)
parts.append((fused("sweater", sweater, after=sweater_shape, knit=0.006, decimate=0.2), KNIT, SHIRT))

# Sleeves on their own, so they don't web into the body: shoulder to a ribbed cuff above the hand.
def sleeves(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.16, 0.16, 0.16), (sx * 0.24, 0.0, 0.67))
        limb(bm, (sx * 0.27, 0.0, 0.64), (sx * 0.37, 0.03, 0.42), 0.072)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.078, radius2=0.08, depth=0.06,
                matrix=Matrix.Translation((sx * 0.385, 0.035, 0.395)) @ Matrix.Rotation(math.radians(sx * -24), 4, "Y"))
def sleeve_shape(co):
    return co
parts.append((fused("sleeves", sleeves, after=sleeve_shape, knit=0.005, decimate=0.2), KNIT, SHIRT))

def trousers(bm):
    ellipsoid(bm, (0.42, 0.32, 0.16), (0, 0, 0.38))
    for sx in (-1, 1):
        limb(bm, (sx * 0.1, 0.0, 0.37), (sx * 0.1, 0.0, 0.13), 0.088)
parts.append((fused("trousers", trousers, decimate=0.15), FELT, PANTS))

def boots(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.19, 0.29, 0.13), (sx * 0.1, 0.035, 0.065))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.095, radius2=0.1, depth=0.12,
                matrix=Matrix.Translation((sx * 0.1, -0.01, 0.12)))
parts.append((fused("boots", boots, decimate=0.15), FELT, BOOTS))

def hands(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.13, 0.12, 0.14), (sx * 0.41, 0.04, 0.31))
parts.append((fused("hands", hands, decimate=0.2), FELT, MITTEN))

def head(bm):
    ellipsoid(bm, (0.56, 0.52, 0.54), (0, 0, HEAD_Z), segs=48)
    for sx in (-1, 1):
        ellipsoid(bm, (0.15, 0.1, 0.12), (sx * 0.15, 0.19, HEAD_Z - 0.12))
parts.append((fused("head", head, smooth=0.8, repeat=10, decimate=0.15), FELT, SKIN))

# Curls: little balls of brown felt under the cuff, round the sides and the back, none over the face.
def curls(bm):
    import random
    rnd = random.Random(5)
    for row, (z, r) in enumerate([(CUFF - 0.015, 0.29), (CUFF - 0.07, 0.285), (CUFF - 0.125, 0.26)]):
        n = 22
        for i in range(n):
            a = math.radians(-180 + 360 * (i + 0.5 * (row % 2)) / n)
            if abs(a) < math.radians(62 if row == 0 else 78):
                continue
            k = rnd.uniform(0.85, 1.15)
            ellipsoid(bm, (0.085 * k, 0.07 * k, 0.085 * k), (math.sin(a) * r, math.cos(a) * r * 0.95, z), segs=16)
    for sx in (-1, 1):
        ellipsoid(bm, (0.07, 0.06, 0.13), (sx * 0.255, 0.12, CUFF - 0.06), (0, 0, sx * 20), segs=16)
parts.append((fused("curls", curls, smooth=0.3, repeat=3, decimate=0.2), FELT, HAIR))

# Beanie: a tall ribbed dome, wider than the head, and a thick folded cuff.
def beanie(bm):
    ellipsoid(bm, (0.72, 0.68, 0.68), (0, -0.01, CUFF + 0.22), segs=48)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=0.355, radius2=0.365, depth=0.15,
            matrix=Matrix.Translation((0, -0.005, CUFF + 0.075)) @ Matrix.Diagonal((1, 0.95, 1, 1)))
def beanie_shape(co):
    if co.z < CUFF:  # flatten the dome's underside into the cuff
        co.z = CUFF + (co.z - CUFF) * 0.05
    co = ribs(0, 20, 0.2, CUFF + 0.15, 2.0)(co)
    co = ribs(0, 32, 0.16, CUFF - 0.01, CUFF + 0.145)(co)
    # The fold: a groove where the cuff turns back under the dome.
    fold = math.exp(-((co.z - CUFF - 0.15) / 0.012) ** 2) * 0.03
    return Vector((co.x * (1.0 - fold), co.y * (1.0 - fold), co.z))
parts.append((fused("beanie", beanie, smooth=0.5, repeat=4, after=beanie_shape, knit=0.005, decimate=0.25), KNIT, HAT))

# Face: two black oval eyes and a small stitched smile, as in the turnaround.
def eyes(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.052, 0.03, 0.068), (sx * 0.105, 0.248, HEAD_Z - 0.105), segs=16)
parts.append((plain("eyes", eyes), FELT, INK))
smile = [(math.sin(t) * 0.055, 0.0, 0.018 * math.cos(t * 1.5)) for t in [(-1.0 + 0.2 * i) for i in range(11)]]
smile = [(x, 0.236 - abs(x) * 0.25, HEAD_Z - 0.165 - z) for (x, _, z) in smile]
parts.append((thread("smile", smile, 0.007), FELT, INK))

# Stitches: a seam down the outside of each trouser leg and a welt round each boot.
for sx in (-1, 1):
    parts.append((thread("seam", [(sx * 0.186, 0.0, 0.34 - 0.02 * i) for i in range(11)], 0.005), FELT, THREAD))
    ring = [(sx * 0.1 + math.sin(t) * 0.1, 0.035 + math.cos(t) * 0.15, 0.035) for t in [math.tau * i / 40 for i in range(41)]]
    parts.append((thread("welt", ring, 0.005), FELT, THREAD))

# One mesh: every part's vertices carry (weave, slot) in UV.x, UV.y.
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
for me, weave, slot in parts:
    start = len(bm.faces)
    tmp = bmesh.new()
    tmp.from_mesh(me)
    tmp.verts.ensure_lookup_table()
    m2 = bpy.data.meshes.new("tmp")
    tmp.to_mesh(m2)
    tmp.free()
    bm.from_mesh(m2)
    bm.faces.ensure_lookup_table()
    for f in bm.faces[start:]:
        f.smooth = True
        for loop in f.loops:
            loop[uv].uv = (weave, slot)
me = bpy.data.meshes.new("knit_camper")
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new("knit_camper", me)
scene.collection.objects.link(ob)
print("knit_camper faces", len(me.polygons), "verts", len(me.vertices))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_texcoords=True,
        export_normals=True, export_yup=True, export_apply=True)
