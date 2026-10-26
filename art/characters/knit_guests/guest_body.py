# The body every knitted guest shares, at a lighter level of detail than the players' campers (art/RECIPE.md, "A
# sibling or variant"): player one's head, face, sweater, sleeves, mittens, trousers and boots
# (art/characters/knit_camper/build_knit_camper.py), copied so either can change alone, with fewer columns and rings,
# fewer stitches and no boot welts. A guest's build script (knit_guest_<name>/build_knit_guest_<name>.py) imports this,
# calls body() with its own girth, adds its own headwear and hair, then guest_finish(name, scale). Up to three guests
# share the camp with two players on the laptop floor, so each guest stays near 12k vertices (a player is about 30k).
# Original work, CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from knit_kit import *  # the shapes, the mesh BM, OUT, T_POSE and finish()

# slots: indices into data/models.json "knit_guest_*" file_slots (player one's order, then TRIM for stripes, bands and
# buttons)
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE, THREAD, HAIR_SHADE, TRIM = range(13)

SIT = "--pose=sit" in ARGS     # sitting like a plush doll: legs straight out in front, boot toes up (--pose=sit)
HIP = Vector((0.0, 0.0, 0.34))  # the line the legs fold forward about when sitting
HEAD_C = Vector((0.0, 0.035, 1.0))
HEAD_R = (0.295, 0.27, 0.24)
HAIR_OFF = 0.012          # a felt hair cap's distance off the skin (at least 10 mm, art/RECIPE.md)
LOCK_PLY = (2, 0.06)      # plies, and metres per full twist (as the players' curls)


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


def on_head(d, off=0.0):
    """The point on the head's surface in the unit-sphere direction d, pushed off along the surface normal."""
    p = HEAD_C + Vector((HEAD_R[0] * d.x, HEAD_R[1] * d.y, HEAD_R[2] * d.z))
    return p + head_normal(p) * off


def dir_at(theta, z):
    """The unit-sphere direction of the head's surface at azimuth theta (0 = front) and height z."""
    cz = max(min((z - HEAD_C.z) / HEAD_R[2], 0.999), -0.999)
    s = math.sqrt(1.0 - cz * cz)
    return Vector((s * math.sin(theta), s * math.cos(theta), cz))


def slerp(a, b, f):
    w = math.acos(max(min(a.dot(b), 1.0), -1.0))
    if w < 1e-5:
        return a.copy()
    return (a * math.sin((1 - f) * w) + b * math.sin(f * w)) / math.sin(w)


def table_at(table, theta):
    """A value read round the head from [(degrees from the front, value)], the same on both sides."""
    a = abs(math.degrees(theta))
    for (a0, z0), (a1, z1) in zip(table, table[1:]):
        if a <= a1:
            return z0 + (z1 - z0) * smoothstep(0.0, 1.0, (a - a0) / (a1 - a0))
    return table[-1][1]


def hair_cap(hairline, slot=None, cols=48, rows=10, off=HAIR_OFF):
    """A felt cap from a hairline [(degrees, z)] over the crown to a pole on top, `off` off the skin."""
    slot = HAIR_SHADE if slot is None else slot
    P = []
    for j in range(rows):
        f = j / (rows - 1)
        ring = []
        for i in range(cols):
            th = math.pi - math.tau * i / cols
            d0 = dir_at(th, table_at(hairline, th) - 0.006)
            ring.append(on_head(slerp(d0, Vector((0, 0, 1)), f * 0.96), off))
        P.append(ring)
    S = [[(0.0, 0.0)] * cols for _ in P]
    vs, _ = grid("hair", P, S, FELT, slot)
    cap("hair", vs[-1], S[-1], on_head(Vector((0, 0, 1)), off), 0.0, FELT, slot, 0)


def hat_frame(tilt_deg, lift=0.0):
    """A frame on the head's middle, tipped back by tilt_deg (the front rises), `lift` up its axis."""
    return Matrix.Translation(HEAD_C) @ Matrix.Rotation(math.radians(tilt_deg), 4, "X") @ \
        Matrix.Translation((0.0, 0.0, lift))


def knit_lathe(name, profile, cols, slot, frame, weave=KNIT_MAP, ribs=None, rib_weave=None, row_h=None):
    """A knitted (or felt) lathe in a hat frame: profile [(z, half-x, half-y)], `cols` columns of 4 vertices,
    ribs(j) -> depth for ring j; ring bands where ribs(j) > 0 draw `rib_weave` with sharp grooves."""
    row_h = row_h or (math.tau * 0.3 / cols) * KNIT_ROW
    P, S = lathe(profile, cols, 4, row_h, ribs=ribs)
    ribbed_band = lambda j: ribs is not None and ribs(j) > 0.0 and ribs(j + 1) > 0.0
    w = (lambda j: rib_weave if rib_weave is not None and ribbed_band(j) else weave)
    vs, _ = grid(name, transformed(P, frame), S, w, slot, period=cols,
            sharp=lambda j: range(0, len(P[0]), 4) if rib_weave is not None and ribbed_band(j) else [])
    return vs, S


# --- Head, ears and face -----------------------------------------------------------------------------------------
def face_parts(smile=True, cheeks=False):
    ellipsoid("head", HEAD_C, HEAD_R, SKIN, cols=36, rings=22)
    for sx in (-1, 1):
        ear_c = Vector((sx * 0.262, HEAD_C.y - 0.08, 0.918))
        ellipsoid("ears", ear_c, (0.034, 0.044, 0.022), SKIN, cols=12, rings=8,
                basis=basis_from(Vector((sx, 0.25, 0.0))))
    for sx in (-1, 1):
        x, z = sx * 0.117, 0.972
        c = Vector((x, head_y(x, z), z))
        n = head_normal(c)
        b = basis_from(n)
        ellipsoid("eyes", c + n * 0.003, (0.029, 0.039, 0.016), INK, cols=12, rings=8, basis=b, weave=BEAD)
        ellipsoid("eyes", c + n * 0.016 + b @ Vector((-0.009, 0.017, 0.0)), (0.007, 0.009, 0.004), SHINE, cols=6,
                rings=4, basis=b, weave=BEAD)
    if smile:
        pts = []
        for k in range(13):
            a = math.radians(215 + 110 * k / 12)
            x, z = 0.086 * math.cos(a), 0.951 + 0.086 * math.sin(a)
            pts.append(Vector((x, head_y(x, z) + 0.002, z)))
        tube("smile", pts, 0.0135, INK, sides=6, weave=BEAD)
    if cheeks:
        for sx in (-1, 1):
            x, z = sx * 0.168, 0.918
            c = Vector((x, head_y(x, z), z))
            n = head_normal(c)
            ellipsoid("cheeks", c + n * 0.001, (0.036, 0.026, 0.005), BLUSH, cols=10, rings=6, basis=basis_from(n))


# --- Sweater: body with a ribbed hem, a ribbed mock neck, sleeves with ribbed cuffs --------------------------------
TORSO = [(0.392, 0.232, 0.192), (0.398, 0.252, 0.21), (0.41, 0.261, 0.219), (0.425, 0.263, 0.221),
         (0.44, 0.263, 0.221), (0.455, 0.262, 0.22), (0.466, 0.259, 0.217), (0.476, 0.252, 0.211),
         (0.50, 0.251, 0.209), (0.53, 0.25, 0.207), (0.56, 0.247, 0.204), (0.59, 0.243, 0.2), (0.62, 0.238, 0.196),
         (0.645, 0.232, 0.191), (0.665, 0.226, 0.186), (0.685, 0.218, 0.181), (0.70, 0.21, 0.175),
         (0.713, 0.2, 0.168), (0.725, 0.19, 0.16), (0.735, 0.18, 0.155), (0.742, 0.17, 0.15), (0.748, 0.158, 0.143),
         (0.752, 0.145, 0.135)]
SWEATER_COLS = 24
COLLAR = [(0.70, 0.17, 0.156), (0.712, 0.177, 0.163), (0.725, 0.178, 0.164), (0.74, 0.175, 0.161),
          (0.755, 0.171, 0.157), (0.77, 0.167, 0.153), (0.782, 0.163, 0.15), (0.791, 0.157, 0.145),
          (0.796, 0.148, 0.137), (0.797, 0.138, 0.128), (0.79, 0.13, 0.12)]
SLEEVE = [(-0.105, 0.03, 0.03), (-0.08, 0.067, 0.067), (-0.035, 0.086, 0.086), (0.0, 0.089, 0.089),
          (0.06, 0.088, 0.088), (0.12, 0.085, 0.085), (0.19, 0.08, 0.08), (0.203, 0.077, 0.077),
          (0.209, 0.08, 0.08), (0.222, 0.083, 0.083), (0.238, 0.084, 0.084), (0.254, 0.084, 0.084),
          (0.266, 0.082, 0.082), (0.274, 0.076, 0.076), (0.278, 0.066, 0.066), (0.275, 0.056, 0.056)]
SLEEVE_COLS = 10
SHOULDER = Vector((0.205, 0.0, 0.652))
HAND_AT = 0.345
ARM_DROP = math.radians(58.0)
ARM_FORWARD = math.radians(8.0)


def torso(girth):
    prof = [(z, a * girth, b * girth) for z, a, b in TORSO]
    hem = lambda j: 0.007 if 0.395 < TORSO[j][0] < 0.47 else 0.003
    P, S = lathe(prof, SWEATER_COLS, 4, 1.46 * girth / SWEATER_COLS * KNIT_ROW, n_exp=2.4, ribs=hem)
    vs, _ = grid("sweater", P, S, lambda j: RIB_MAP if TORSO[j + 1][0] <= 0.47 else KNIT_MAP, SHIRT,
            period=SWEATER_COLS, sharp=lambda j: range(0, len(P[0]), 4) if TORSO[j + 1][0] <= 0.47 else [])
    cap("sweater", vs[0], S[0], Vector((0, 0, 0.388)), S[0][0][1] - 0.5, RIB_MAP, SHIRT, SWEATER_COLS, at_start=True)
    cap("sweater", vs[-1], S[-1], Vector((0, 0, 0.756)), S[-1][0][1] + 0.5, KNIT_MAP, SHIRT, SWEATER_COLS)


def collar():
    P, S = lathe(COLLAR, 16, 4, 0.0445 * KNIT_ROW, ribs=lambda j: 0.009 if 0 < j < len(COLLAR) - 1 else 0.0)
    grid("collar", P, S, RIB_MAP, SHIRT, period=16, sharp=lambda j: range(0, len(P[0]), 4))


def arm_matrix(sx, girth, pose=None):
    """pose: (drop, forward) in radians for this arm, instead of hanging at the sides."""
    out = Matrix.Rotation(sx * math.radians(90.0), 4, "Y")
    drop, forward = pose or (ARM_DROP, ARM_FORWARD)
    pose = Matrix.Identity(4)
    if not T_POSE:
        pose = Matrix.Rotation(sx * forward, 4, "Z") @ Matrix.Rotation(sx * drop, 4, "Y")
    at = Vector((sx * SHOULDER.x * (1.0 + (girth - 1.0) * 0.8), SHOULDER.y, SHOULDER.z))
    return Matrix.Translation(at) @ pose @ out


def arms(girth, poses=None):
    cuff_from = 0.205
    for sx in (-1, 1):
        P, S = lathe(SLEEVE, SLEEVE_COLS, 4, 0.0445 * KNIT_ROW, v_from_end=True,
                ribs=lambda j: 0.0065 if cuff_from < SLEEVE[j][0] < 0.275 else 0.002)
        m = arm_matrix(sx, girth, (poses or {}).get(sx))
        vs, _ = grid("sleeves", transformed(P, m), S, lambda j: RIB_MAP if SLEEVE[j][0] >= cuff_from else KNIT_MAP,
                SHIRT, period=SLEEVE_COLS, sharp=lambda j: range(0, len(P[0]), 4) if SLEEVE[j][0] >= cuff_from else [])
        cap("sleeves", vs[0], S[0], m @ Vector((0, 0, SLEEVE[0][0] - 0.012)), S[0][0][1] + 0.3, KNIT_MAP, SHIRT,
                SLEEVE_COLS, at_start=True)
        cap("sleeves", vs[-1], S[-1], m @ Vector((0, 0, SLEEVE[-1][0] - 0.01)), 0.0, RIB_MAP, SHIRT, SLEEVE_COLS)
        ellipsoid("hands", m @ Vector((0, 0, HAND_AT)), (0.061, 0.06, 0.068), MITTEN, cols=16, rings=10,
                basis=m.to_3x3())


# --- Trousers, rolled cuffs, boots and the trousers' side seams ------------------------------------------------------
LEG_TOP, LEG_BOTTOM = Vector((0.117, 0.0, 0.38)), Vector((0.142, 0.005, 0.16))


def leg_at(f):
    return LEG_TOP.lerp(LEG_BOTTOM, f)


def trousers(girth):
    blobs = [((0, 0, 0.405), (0.222 * girth, 0.172 * girth, 0.1), None)]
    for sx in (-1, 1):
        for k in range(13):
            f = k / 12
            c = leg_at(f)
            blobs.append(((sx * c.x, c.y, c.z), (0.12 - 0.008 * f, 0.146 - 0.01 * f, 0.05), None))
    return fused("trousers", blobs, voxel=0.009, decimate=0.1)


def rolled_cuffs():
    for sx in (-1, 1):
        c = leg_at(1.0)
        centre = Vector((sx * c.x, c.y, 0.148))
        a, b, r = 0.116, 0.14, 0.027
        n_major, n_minor = 24, 8
        P = []
        for i in range(n_major):
            t = math.tau * i / n_major
            d = Vector((math.cos(t), math.sin(t), 0))
            P.append([centre + Vector((a * math.cos(t), b * math.sin(t), 0)) + d * r * math.cos(math.tau * k / n_minor)
                    + Vector((0, 0, r * 0.95 * math.sin(math.tau * k / n_minor))) for k in range(n_minor)])
        vs = [[BM.verts.new(p) for p in ring] for ring in P]
        for i in range(n_major):
            for k in range(n_minor):
                face([vs[i][k], vs[(i + 1) % n_major][k], vs[(i + 1) % n_major][(k + 1) % n_minor],
                        vs[i][(k + 1) % n_minor]], FELT, PANTS)
        counted("trouser cuffs", n_major * n_minor)


def boots():
    blobs = []
    for sx in (-1, 1):
        turn = Matrix.Rotation(sx * math.radians(-7.0), 3, "Z")
        blobs.append(((sx * 0.162, 0.035, 0.062), (0.118, 0.18, 0.066), turn))
        blobs.append(((sx * 0.152, -0.005, 0.108), (0.104, 0.128, 0.06), turn))
    return fused("boots", blobs, voxel=0.008, decimate=0.11, after=lambda co: Vector((co.x, co.y, max(co.z, 0.0))))


def side_seams(pants):
    tree = surface_tree(pants)
    for sx in (-1, 1):
        path = []
        for k in range(12):
            c = leg_at(0.04 + 0.86 * k / 11)
            loc, nrm = hit(tree, (sx * c.x, c.y, c.z), (sx, 0, 0))
            if loc is not None:
                path.append((loc, nrm))
        running_stitch("seams", path, THREAD, dash=0.026, gap=0.013)


def body(girth=1.0, smile=True, cheeks=False, arm_poses=None):
    """Everything below the hair: head and face, sweater, sleeves and mittens, trousers and boots. arm_poses
    {side: (drop, forward)} lifts an arm (side 1 is the right, -1 the left) out of the hanging pose."""
    face_parts(smile, cheeks)
    torso(girth)
    collar()
    arms(girth, arm_poses)
    first_leg = len(BM.verts)
    pants = trousers(girth)
    append_mesh("trousers", pants, PANTS)
    rolled_cuffs()
    append_mesh("boots", boots(), BOOTS)
    side_seams(pants)
    if SIT:
        sit_legs(first_leg)


def sit_legs(first):
    """Folds every leg vertex from `first` on forward about the hip, a quarter turn below the seat of the trousers and
    easing to none at the waist, so the guest sits with legs straight out (the bottom of the seat ends near 0.2 m)."""
    BM.verts.ensure_lookup_table()
    for v in BM.verts[first:]:
        a = math.radians(90.0) * smoothstep(0.40, 0.28, v.co.z)
        rel = v.co - HIP
        c, s = math.cos(a), math.sin(a)
        v.co = HIP + Vector((rel.x, rel.y * c - rel.z * s, rel.y * s + rel.z * c))


def guest_finish(name, scale=1.0):
    """Scales the whole guest about its feet (a taller or smaller visitor), then bakes and writes it."""
    if abs(scale - 1.0) > 1e-6:
        for v in BM.verts:
            v.co = v.co * scale
    finish(name)
