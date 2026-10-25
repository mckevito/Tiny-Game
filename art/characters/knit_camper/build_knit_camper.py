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
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE = range(10)
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
        k = 1.0 - depth * 0.5 * (1.0 - math.cos(count * a))
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


HEAD_Z = 0.98
parts = []  # (mesh, weave, slot)

# Body: a soft sweater with arms fused in, a rib at the hem and at the neck.
def sweater(bm):
    ellipsoid(bm, (0.58, 0.48, 0.56), (0, 0, 0.47))
    limb(bm, (-0.24, 0.0, 0.66), (-0.4, 0.04, 0.36), 0.085)
    limb(bm, (0.24, 0.0, 0.66), (0.4, 0.04, 0.36), 0.085)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.215, radius2=0.205, depth=0.08,
            matrix=Matrix.Translation((0, 0, 0.27)) @ Matrix.Scale(1.0, 4) @ Matrix.Diagonal((1, 0.85, 1, 1)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.17, radius2=0.15, depth=0.1,
            matrix=Matrix.Translation((0, -0.01, 0.74)) @ Matrix.Diagonal((1, 0.9, 1, 1)))
    for sx in (-1, 1):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.09, radius2=0.09, depth=0.06,
                matrix=Matrix.Translation((sx * 0.39, 0.035, 0.375)) @ Matrix.Rotation(math.radians(sx * -28), 4, "Y"))
def sweater_ribs(co):
    co = ribs(0, 30, 0.06, 0.225, 0.31)(co)
    return ribs(0, 22, 0.12, 0.69, 0.8)(co)
parts.append((fused("sweater", sweater, after=sweater_ribs, knit=0.006, decimate=0.45), KNIT, SHIRT))

def pants(bm):
    ellipsoid(bm, (0.46, 0.4, 0.3), (0, 0, 0.22))
    limb(bm, (-0.11, 0.0, 0.2), (-0.12, 0.0, 0.1), 0.1)
    limb(bm, (0.11, 0.0, 0.2), (0.12, 0.0, 0.1), 0.1)
parts.append((fused("pants", pants), FELT, PANTS))

def boots(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.2, 0.28, 0.15), (sx * 0.12, 0.04, 0.075))
        ellipsoid(bm, (0.18, 0.16, 0.14), (sx * 0.12, -0.02, 0.11))
parts.append((fused("boots", boots), FELT, BOOTS))

def mittens(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.15, 0.13, 0.16), (sx * 0.41, 0.04, 0.3))
        ellipsoid(bm, (0.06, 0.07, 0.08), (sx * 0.38, 0.1, 0.33), (0, 0, sx * 30))
parts.append((fused("mittens", mittens), KNIT, MITTEN))

# Head: round and soft, with a little nose and full cheeks fused in.
def head(bm):
    ellipsoid(bm, (0.62, 0.58, 0.58), (0, 0, HEAD_Z), segs=48)
    ellipsoid(bm, (0.06, 0.05, 0.045), (0, 0.28, HEAD_Z - 0.04))
    for sx in (-1, 1):
        ellipsoid(bm, (0.16, 0.12, 0.13), (sx * 0.17, 0.2, HEAD_Z - 0.08))
parts.append((fused("head", head, smooth=0.8, repeat=10), FELT, SKIN))

# Hair: locks round the back and sides, a fringe of locks under the hat's cuff.
def hair(bm):
    ellipsoid(bm, (0.64, 0.58, 0.5), (0, -0.04, HEAD_Z + 0.06), segs=40)
    for i in range(11):
        a = math.radians(-115 + i * 23)
        x, y = math.sin(a) * 0.3, math.cos(a) * 0.29
        if y > 0.16:
            continue
        ellipsoid(bm, (0.12, 0.1, 0.24), (x, y - 0.02, HEAD_Z - 0.1), (math.degrees(-a) * 0.0, 0, math.degrees(a)))
    for sx in (-1, 1):
        ellipsoid(bm, (0.13, 0.08, 0.2), (sx * 0.26, 0.15, HEAD_Z - 0.02), (0, sx * -15, sx * 25))
    for i in range(6):
        x = -0.2 + i * 0.08
        ellipsoid(bm, (0.1, 0.07, 0.13), (x, 0.235, HEAD_Z + 0.11), (20, 0, x * 60))
parts.append((fused("hair", hair, smooth=0.5, repeat=4), FELT, HAIR))

# Beanie: a ribbed dome and a thick folded cuff.
CUFF = HEAD_Z + 0.13
def beanie(bm):
    ellipsoid(bm, (0.66, 0.64, 0.6), (0, -0.02, CUFF + 0.12), segs=48)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=0.37, radius2=0.36, depth=0.13,
            matrix=Matrix.Translation((0, -0.01, CUFF + 0.03)))
def beanie_shape(co):
    if co.z < CUFF - 0.035:  # cut away the dome below the cuff
        co.z = CUFF - 0.035 + (co.z - CUFF + 0.035) * 0.05
    co = ribs(0, 16, 0.1, CUFF + 0.1, 2.0)(co)
    return ribs(0, 30, 0.1, CUFF - 0.04, CUFF + 0.095)(co)
parts.append((fused("beanie", beanie, smooth=0.5, repeat=4, after=beanie_shape, knit=0.005, decimate=0.5), KNIT, HAT))

# Embroidered face: bead eyes, a stitched smile, felt blush.
def eyes(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.055, 0.03, 0.068), (sx * 0.1, 0.275, HEAD_Z + 0.01), segs=16)
parts.append((plain("eyes", eyes), FELT, INK))
def shine(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.016, 0.01, 0.016), (sx * 0.1 + 0.012, 0.29, HEAD_Z + 0.025), segs=8)
parts.append((plain("shine", shine), FELT, SHINE))
smile = [(math.sin(t) * 0.09, 0.0, 0.025 * math.cos(t * 1.6)) for t in [(-0.9 + 0.15 * i) for i in range(13)]]
smile = [(x, 0.27 - abs(x) * 0.3, HEAD_Z - 0.11 - z) for (x, _, z) in smile]
parts.append((thread("smile", smile, 0.0075), FELT, INK))
def blush(bm):
    for sx in (-1, 1):
        ellipsoid(bm, (0.1, 0.03, 0.055), (sx * 0.17, 0.258, HEAD_Z - 0.07), (0, 0, sx * -28), segs=16)
parts.append((plain("blush", blush), FELT, BLUSH))

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
