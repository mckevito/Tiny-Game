# Builds player two's knitted camper (art/characters/knit_camper_b/knit_camper_b.glb) in Blender, from code only.
#   blender --background --factory-startup --python art/characters/knit_camper_b/build_knit_camper_b.py -- OUT.glb
# Add --pose=t to hold the arms straight out (for review); by default they hang down.
# A sibling of player one's camper (art/characters/knit_camper/): the same body, face, sweater, trousers and boots,
# copied from its script so either can change alone, but no beanie: a bun of coiled yarn with a pin, hair swept up
# into it, a ribbed headband and felt cheeks, so the two players are easy to tell apart. Made by following
# art/RECIPE.md with the shared kit, art/tools/knit_kit.py. The game paints it from the palette (data/models.json
# "knit_camper_b" file_slots). Original work, CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from knit_kit import *  # the shapes, the mesh BM, OUT, T_POSE and finish()

# slots: indices into data/models.json "knit_camper_b" file_slots (the same order as player one's; HAT is the headband)
SKIN, SHIRT, PANTS, HAT, HAIR, MITTEN, BOOTS, INK, BLUSH, SHINE, THREAD, HAIR_SHADE = range(12)

# ---------------------------------------------------------------------------------------------------------------
# Proportions, measured off the owner's turnaround (25 Oct 2026) for a camper 1.48 m tall: the head and beanie are
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


# --- Cheeks: two flat felt blush patches, player two's own touch ----------------------------------------------------
for sx in (-1, 1):
    x, z = sx * 0.168, 0.918
    c = Vector((x, head_y(x, z), z))
    n = head_normal(c)
    ellipsoid("cheeks", c + n * 0.001, (0.036, 0.026, 0.005), BLUSH, cols=14, rings=8, basis=basis_from(n))


# --- Hair: a felt cap over the scalp, yarn locks swept up from the hairline into a coiled bun on top ---------------
# Player one's curls fall from under a beanie; player two wears no hat, so the hair itself is the big silhouette: a
# round bun of coiled yarn on top of the head, a little behind its middle, with a honey pin through it, and a ribbed
# knitted headband tipped back across the brow.
HAIR_OFF = 0.012          # the felt cap's distance off the skin (at least 10 mm, art/RECIPE.md)
BUN_DIR = Vector((0.0, -0.42, 0.91)).normalized()   # where the bun sits, as a direction in the head's unit sphere
BUN_R = (0.118, 0.118, 0.09)   # the bun's felt core: across, across, and out from the head
BUN_BASE = math.radians(21.0)  # how far round the head (as an angle) the locks end, round the bun's foot
LOCK_R2 = (0.017, 0.021)   # a swept lock's radius, smallest to largest
LOCK_PLY = (2, 0.06)       # plies, and metres per full twist (as player one's curls)
HAIRLINE_B = [(0, 1.085), (30, 1.075), (50, 1.04), (65, 0.985), (78, 0.95), (90, 0.985), (110, 0.98),
              (128, 0.9), (145, 0.86), (165, 0.84), (180, 0.835)]


def on_head(d, off=0.0):
    """The point on the head's surface in the unit-sphere direction d, pushed off along the surface normal."""
    p = HEAD_C + Vector((HEAD_R[0] * d.x, HEAD_R[1] * d.y, HEAD_R[2] * d.z))
    return p + head_normal(p) * off


def dir_at(theta, z):
    """The unit-sphere direction of the head's surface at azimuth theta (0 = front) and height z."""
    cz = max(min((z - HEAD_C.z) / HEAD_R[2], 0.999), -0.999)
    s = math.sqrt(1.0 - cz * cz)
    return Vector((s * math.sin(theta), s * math.cos(theta), cz))


def hairline_b(theta):
    a = abs(math.degrees(theta))
    for (a0, z0), (a1, z1) in zip(HAIRLINE_B, HAIRLINE_B[1:]):
        if a <= a1:
            return z0 + (z1 - z0) * smoothstep(0.0, 1.0, (a - a0) / (a1 - a0))
    return HAIRLINE_B[-1][1]


def slerp(a, b, f):
    w = math.acos(max(min(a.dot(b), 1.0), -1.0))
    if w < 1e-5:
        return a.copy()
    return (a * math.sin((1 - f) * w) + b * math.sin(f * w)) / math.sin(w)


def hair_cap():
    """Rings from the hairline up over the crown to a pole on top, HAIR_OFF off the skin."""
    cols, rows = 72, 12
    P = []
    for j in range(rows):
        f = j / (rows - 1)
        ring = []
        for i in range(cols):
            th = math.pi - math.tau * i / cols
            d0 = dir_at(th, hairline_b(th) - 0.006)
            ring.append(on_head(slerp(d0, Vector((0, 0, 1)), f * 0.96), HAIR_OFF))
        P.append(ring)
    S = [[(0.0, 0.0)] * cols for _ in P]
    vs, _ = grid("hair", P, S, FELT, HAIR_SHADE)
    cap("hair", vs[-1], S[-1], on_head(Vector((0, 0, 1)), HAIR_OFF), 0.0, FELT, HAIR_SHADE, 0)


def bun_end(d0):
    """Where a lock starting at d0 ends: on a ring round the bun's foot, on the same side as it started."""
    t = d0 - BUN_DIR * d0.dot(BUN_DIR)
    if t.length < 1e-4:
        t = Vector((0, 1, 0))
    t.normalize()
    return (BUN_DIR * math.cos(BUN_BASE) + t * math.sin(BUN_BASE)).normalized()


def swept_locks():
    """Two-ply yarn locks lying on the cap, from the hairline up and back into the bun's foot, each with a gentle
    sideways wave. They start tucked against the cap, so they read as growing from it."""
    rnd = random.Random(11)
    n = 34
    for k in range(n):
        th = math.pi * (1.0 - 2.0 * (k + 0.5) / n) + rnd.uniform(-0.03, 0.03)
        lock_r = rnd.uniform(*LOCK_R2)
        d0 = dir_at(th, hairline_b(th) + 0.012)
        d1 = bun_end(d0)
        w = math.acos(max(min(d0.dot(d1), 1.0), -1.0))
        steps = max(int(w * 0.26 / 0.014), 6)
        phase = rnd.uniform(0.0, math.tau)
        pts = []
        for s in range(steps + 1):
            f = s / steps
            d = slerp(d0, d1, f)
            # sideways in the surface, across the lock's way
            fwd = (slerp(d0, d1, min(f + 0.02, 1.0)) - slerp(d0, d1, max(f - 0.02, 0.0))).normalized()
            side = d.cross(fwd).normalized()
            wave = 0.55 * lock_r * math.sin(math.tau * f * w * 0.26 / 0.09 + phase) * math.sin(math.pi * f)
            lift = HAIR_OFF + lock_r * (0.35 + 0.55 * smoothstep(0.0, 0.12, f))
            pts.append(on_head(d, lift) + side * wave)
        tube("hair", pts, lock_r, HAIR, sides=8, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 0.7 + 0.3 * smoothstep(0.0, 0.15, s))


def tendrils():
    """A loose curl falling in front of each ear, out from under the headband."""
    for sx in (-1, 1):
        th = sx * math.radians(72.0)
        lock_r = 0.019
        pts = []
        for s in range(15):
            z = 1.03 - 0.12 * s / 14
            r = head_radius(th, z) + HAIR_OFF + lock_r
            t2 = th + sx * 0.06 * math.sin(math.tau * s / 14)
            pts.append(Vector((HEAD_C.x + r * math.sin(t2), HEAD_C.y + r * math.cos(t2), z)))
        last, prev = pts[-1], pts[-2]
        down = (last - prev).normalized()
        out = Vector((math.sin(th), math.cos(th), 0.0))
        out = (out - down * out.dot(down)).normalized()
        side = down.cross(out).normalized()
        for k in range(1, 9):
            a = math.radians(36.0 * k)
            rr = lock_r * 0.95 * (1.0 - 0.3 * k / 8)
            pts.append(last + down * rr * math.sin(a) + out * rr * (1 - math.cos(a)) + side * 0.004 * k)
        tube("hair", pts, lock_r, HAIR, sides=8, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.45 * max(0.0, s - 0.7) / 0.3)


def bun():
    """A felt core on top of the head with one fat yarn wound round it from its foot up to its top, like a cinnamon
    roll, and a honey felt pin pushed through it."""
    foot = on_head(BUN_DIR, HAIR_OFF)
    nrm = head_normal(foot)
    b = basis_from(nrm)
    centre = foot + nrm * (BUN_R[2] * 0.75)
    ellipsoid("bun", centre, BUN_R, HAIR_SHADE, cols=24, rings=14, basis=b)
    coil_r = 0.026
    turns, steps = 3.6, 150
    pts = []
    for s in range(steps + 1):
        f = s / steps
        pol = math.radians(118.0 - 104.0 * f)   # from round the foot to near the top
        az = math.tau * turns * f
        local = Vector((BUN_R[0] * math.sin(pol) * math.cos(az), BUN_R[1] * math.sin(pol) * math.sin(az),
                BUN_R[2] * math.cos(pol)))
        n_l = Vector((local.x / BUN_R[0] ** 2, local.y / BUN_R[1] ** 2, local.z / BUN_R[2] ** 2)).normalized()
        pts.append(centre + b @ (local + n_l * coil_r * 0.55))
    tube("bun", pts, coil_r, HAIR, sides=9, lobe_depth=0.18, weave=YARN, yarn=(2, 0.07),
            taper=lambda s: 0.75 + 0.25 * smoothstep(0.0, 0.08, s) - 0.3 * smoothstep(0.85, 1.0, s))
    # the pin: a felt stick through the bun, tipped across it, with a round bead at one end
    across = b @ Vector((1.0, 0.25, 0.32)).normalized()
    p0, p1 = centre - across * 0.2, centre + across * 0.19
    tube("bun pin", [p0.lerp(p1, k / 6) for k in range(7)], 0.0095, THREAD, sides=8)
    ellipsoid("bun pin", p1 + across * 0.012, (0.021, 0.021, 0.021), THREAD, cols=12, rings=8)


hair_cap()
swept_locks()
tendrils()
bun()


# --- Headband: a ribbed knitted band tipped back over the hair, as a latitude round a tilted axis --------------------
BAND_TILT = math.radians(24.0)     # how far the band's axis leans back from upright
BAND_PSI = (math.radians(58.0), math.radians(78.0))   # from the axis, its top and bottom edges (unit-sphere angle)
BAND_OFF, BAND_THICK = 0.024, 0.032   # the inside's distance off the skin, and how thick it is
BAND_RIBS = 46


def band_profile():
    """The band's cross-section as (angle from the axis, distance off the skin, rib depth weight): up the inside,
    round the bottom edge, up the outside and round the top edge."""
    p0, p1 = BAND_PSI
    rho = BAND_THICK * 0.5
    e = rho / 0.27   # the round edges' size as an angle, on a head about 0.27 m round
    pts = [(p1 - e * 1.6, BAND_OFF + 0.002, 0.0)]
    for d in range(-90, 91, 30):
        a = math.radians(d)
        pts.append((p1 - e + e * math.cos(a), BAND_OFF + rho + rho * math.sin(a), 0.4 if d < 0 else 1.0))
    for k in range(1, 6):
        f = k / 6
        pts.append((p1 - e + (p0 - p1 + 2 * e) * f, BAND_OFF + BAND_THICK + 0.004 * math.sin(math.pi * f), 1.0))
    for d in range(90, 271, 30):
        a = math.radians(d)
        pts.append((p0 + e + e * math.cos(a), BAND_OFF + rho + rho * math.sin(a), 1.0 if d < 180 else 0.4))
    pts.append((p0 + e * 1.6, BAND_OFF + 0.002, 0.0))
    return pts


def headband():
    ez = Vector((0.0, -math.sin(BAND_TILT), math.cos(BAND_TILT)))
    ex = Vector((1.0, 0.0, 0.0))
    ey = ez.cross(ex)
    prof = band_profile()
    per = 4
    n = BAND_RIBS * per
    rings = []
    for psi, off, _ in prof:
        ring = []
        for i in range(n):
            a = -math.pi / 2 + math.tau * i / n
            d = ez * math.cos(psi) + (ex * math.cos(a) + ey * math.sin(a)) * math.sin(psi)
            ring.append(on_head(d.normalized(), off))
        rings.append(ring)
    pitch = math.tau * 0.31 / BAND_RIBS
    P, S = ribbed(rings, BAND_RIBS, per, pitch * KNIT_ROW, lambda j: 0.012 * prof[j][2])
    grid("headband", P, S, RIB_MAP, HAT, period=BAND_RIBS,
            sharp=lambda j: range(0, n, per) if prof[j][2] >= 0.5 and prof[min(j + 1, len(prof) - 1)][2] >= 0.5 else [])


headband()


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

finish("knit_camper_b")
