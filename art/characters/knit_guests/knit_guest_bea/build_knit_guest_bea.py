# Builds the first guest's knitted camper (Bea Thistle, the Acorn Club's leader; look guest_a) in Blender, from code:
#   blender --background --factory-startup --python art/characters/knit_guests/knit_guest_bea/build_knit_guest_bea.py -- OUT.glb
# Add --pose=t for the review T-pose. The shared guest body (../guest_body.py, a lighter copy of player one's) with
# Bea's own top: a striped bobble beanie with a big felt pompom, a ginger fringe and two plaits over the shoulders, so
# she reads apart from both players (no pompom on player one's beanie, a bun on player two). Made by following
# art/RECIPE.md. The game paints it from the palette (data/models.json "knit_guest_bea" file_slots). Original work,
# CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from guest_body import *  # the kit, the head helpers, the slots and body()

GIRTH, SCALE = 0.96, 0.97     # a little slimmer and shorter than the players

body(GIRTH, smile=True, cheeks=True)

# --- Hair: a felt cap, a fringe of short locks under the beanie's cuff, and two three-strand plaits ----------------
HAIRLINE = [(0, 1.04), (35, 1.035), (60, 0.98), (80, 0.95), (100, 0.95), (130, 0.9), (160, 0.865), (180, 0.86)]
hair_cap(HAIRLINE)

rnd = random.Random(5)
for k in range(9):
    th = math.radians(-44.0 + 88.0 * k / 8 + rnd.uniform(-2.0, 2.0))
    lock_r = rnd.uniform(0.016, 0.019)
    end_z = 1.035 + rnd.uniform(-0.008, 0.008)
    pts = []
    for s in range(10):
        z = 1.115 - (1.115 - end_z) * s / 9
        r = head_radius(th, z) + HAIR_OFF + lock_r * 0.9
        pts.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
    # a small curl under at the tip
    last, prev = pts[-1], pts[-2]
    down = (last - prev).normalized()
    out = Vector((math.sin(th), math.cos(th), 0.0))
    for j in range(1, 6):
        a = math.radians(40.0 * j)
        pts.append(last + down * lock_r * math.sin(a) + out * lock_r * (1 - math.cos(a)))
    tube("hair", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
            taper=lambda s: 1.0 - 0.4 * max(0.0, s - 0.7) / 0.3)

PLAIT_PATH = [(0.262, -0.035, 0.965), (0.29, -0.005, 0.87), (0.29, 0.06, 0.77), (0.272, 0.165, 0.68),
              (0.262, 0.222, 0.585)]
STRAND_R, PLAIT_W, PLAIT_PITCH = 0.0175, 0.019, 0.075


def spline(pts, n):
    """n points along a Catmull-Rom curve through pts."""
    P = [Vector(p) for p in pts]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for k in range(n):
        u = k / (n - 1) * (len(P) - 3)
        i = min(int(u), len(P) - 4)
        t = u - i
        p0, p1, p2, p3 = P[i:i + 4]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return out


def plait(sx):
    C = spline([(sx * x, y, z) for x, y, z in PLAIT_PATH], 44)
    length = sum((C[k] - C[k - 1]).length for k in range(1, len(C)))
    acc = [0.0]
    for k in range(1, len(C)):
        acc.append(acc[-1] + (C[k] - C[k - 1]).length)
    for strand in range(3):
        pts = []
        for k, c in enumerate(C):
            t = (C[min(k + 1, len(C) - 1)] - C[max(k - 1, 0)]).normalized()
            out = Vector((sx, 0.35, 0.0))
            out = (out - t * out.dot(t)).normalized()
            side = t.cross(out).normalized()
            ph = math.tau * acc[k] / PLAIT_PITCH + math.tau * strand / 3
            taper = 1.0 - 0.35 * smoothstep(0.8, 1.0, acc[k] / length)
            # each strand weaves side to side and dips in and out, crossing over the others
            pts.append(c + side * PLAIT_W * math.sin(ph) * taper + out * PLAIT_W * 0.45 * math.sin(2 * ph) * taper)
        tube("plaits", pts, STRAND_R, HAIR, sides=6, lobe_depth=0.15, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.3 * smoothstep(0.8, 1.0, s))
    end, before = C[-1], C[-3]
    t = (end - before).normalized()
    ellipsoid("plaits", end - t * 0.006, (0.027, 0.027, 0.016), TRIM, cols=12, rings=6, basis=basis_from(t))
    # a soft tuft past the tie
    ellipsoid("plaits", end + t * 0.035, (0.024, 0.024, 0.04), HAIR, cols=10, rings=7, basis=basis_from(t),
            weave=FELT)


plait(-1)
plait(1)

# --- Beanie: a ribbed cuff tipped back off the brow, a striped dome and a big felt pompom ----------------------------
HAT_TILT = 14.0
FRAME = hat_frame(HAT_TILT)
RX, RY, RZ = 0.335, 0.31, 0.315      # the dome's half-widths and its height above the head's middle
CUFF_FROM, CUFF_TO = 0.025, 0.105    # the cuff's height up the hat's axis
CROWN_COLS = 26
CUFF_RIBS = 30
STRIPES = [(0.105, HAT), (0.15, TRIM), (0.185, HAT), (0.225, TRIM), (0.255, HAT)]   # (from height, slot)


def dome(z):
    k = math.sqrt(max(1.0 - (z / RZ) ** 2, 0.0))
    return RX * k, RY * k


def beanie():
    cuff = []
    for k in range(7):
        z = CUFF_FROM + (CUFF_TO - CUFF_FROM) * k / 6
        a, b = dome(CUFF_FROM)
        bulge = 0.012 * math.sin(math.pi * k / 6)
        cuff.append((z, a + bulge + 0.006, b + bulge + 0.006))
    cuff = [(CUFF_FROM + 0.004, cuff[0][1] - 0.02, cuff[0][2] - 0.02)] + cuff
    pitch = math.tau * 0.33 / CUFF_RIBS
    P, S = lathe(cuff, CUFF_RIBS, 4, pitch * KNIT_ROW, ribs=lambda j: 0.012 if j else 0.0)
    grid("beanie", transformed(P, FRAME), S, RIB_MAP, HAT, period=CUFF_RIBS, sharp=lambda j: range(0, CUFF_RIBS * 4, 4))
    # the dome: knitted stripes, each band its own colour, rows continuing up through them
    zs = [CUFF_TO - 0.004 + (RZ * 0.985 - CUFF_TO + 0.004) * k / 15 for k in range(16)]
    prof = [(z,) + dome(z) for z in zs]
    pitch = math.tau * 0.3 / CROWN_COLS
    P, S = lathe(prof, CROWN_COLS, 4, pitch * KNIT_ROW)
    P = transformed(P, FRAME)
    bands = []
    for j in range(len(zs) - 1):
        mid = (zs[j] + zs[j + 1]) * 0.5
        slot = [s for z0, s in STRIPES if mid >= z0][-1]
        if bands and bands[-1][1] == slot:
            bands[-1][2] = j + 1
        else:
            bands.append([j, slot, j + 1])
    for j0, slot, j1 in bands:
        vs, _ = grid("beanie", P[j0:j1 + 1], S[j0:j1 + 1], KNIT_MAP, slot, period=CROWN_COLS)
        if j1 == len(zs) - 1:
            cap("beanie", vs[-1], S[-1], FRAME @ Vector((0, 0, RZ)), S[-1][0][1] + 0.3, KNIT_MAP, slot, CROWN_COLS)


def pompom():
    rnd = random.Random(3)
    centre = FRAME @ Vector((0.0, 0.0, RZ + 0.055))
    blobs = [(centre, (0.07, 0.07, 0.062), None)]
    for _ in range(26):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 1))).normalized()
        blobs.append((centre + d * 0.058, (0.026, 0.026, 0.026), None))
    append_mesh("pompom", fused("pompom", blobs, voxel=0.007, smooth=0.5, repeat=3, decimate=0.2), TRIM)


beanie()
pompom()

guest_finish("knit_guest_bea", SCALE)
