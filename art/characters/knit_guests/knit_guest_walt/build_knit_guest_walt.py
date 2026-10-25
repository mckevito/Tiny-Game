# Builds the third guest's knitted camper (Walt Hollis, an old fisherman; look guest_c) in Blender, from code:
#   blender --background --factory-startup --python art/characters/knit_guests/knit_guest_walt/build_knit_guest_walt.py -- OUT.glb
# Add --pose=t for the review T-pose. The shared guest body (../guest_body.py), rounder and a little taller than the
# players, with Walt's own top: a felt flat cap with a short peak and a button, short grey hair, a full felt beard
# with a yarn moustache and bushy brows. Made by following art/RECIPE.md; the game paints it from the palette
# (data/models.json "knit_guest_walt" file_slots). Original work, CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from guest_body import *  # the kit, the head helpers, the slots and body()

GIRTH, SCALE = 1.12, 1.03     # rounder and a little taller than the players

body(GIRTH, smile=True, cheeks=False)

# --- Hair: short grey felt round the sides and back, with small yarn curls over it ----------------------------------
HAIRLINE = [(0, 1.1), (40, 1.08), (62, 1.0), (78, 0.92), (95, 0.96), (115, 0.95), (140, 0.88), (180, 0.86)]
hair_cap(HAIRLINE, slot=HAIR_SHADE, cols=40, rows=8)

rnd = random.Random(4)
for row, (top, drop) in enumerate([(0.07, 0.07), (0.035, 0.06)]):
    n = 20 if row == 0 else 18
    for k in range(n):
        th = math.radians(70.0 + (360.0 - 140.0) * (k + 0.5 * row + 0.5) / n + rnd.uniform(-3, 3))
        th = (th + math.pi) % math.tau - math.pi
        lock_r = rnd.uniform(0.014, 0.017)
        z0 = table_at(HAIRLINE, th) + top + rnd.uniform(0.0, 0.015)
        pts = []
        for s in range(7):
            z = z0 - drop * s / 6
            r = head_radius(th, z) + HAIR_OFF + lock_r * 0.8 + 0.004 * row
            pts.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
        # a short flick out at the end
        last, prev = pts[-1], pts[-2]
        down = (last - prev).normalized()
        out = Vector((math.sin(th), math.cos(th), 0.0))
        for j in range(1, 4):
            a = math.radians(45.0 * j)
            pts.append(last + down * lock_r * math.sin(a) + out * lock_r * (1 - math.cos(a)))
        tube("hair", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.4 * max(0.0, s - 0.7) / 0.3)


# --- Beard: felt blobs round the jaw fused into one mass, a yarn moustache over the smile, bushy brows ---------------
def beard():
    blobs = []
    for k in range(13):
        th = math.radians(-96.0 + 192.0 * k / 12)
        w = abs(math.degrees(th)) / 96.0
        z = 0.86 + 0.07 * w ** 1.6           # low round the chin, up the cheeks to the sideburns
        r = head_radius(th, z) + 0.01
        c = Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z))
        size = 0.062 - 0.02 * w
        blobs.append((c, (size, size, size * 1.15), None))
    blobs.append((Vector((0.0, head_y(0.0, 0.8) + 0.035, 0.81)), (0.12, 0.075, 0.075), None))
    blobs.append((Vector((0.0, head_y(0.0, 0.8) + 0.015, 0.77)), (0.085, 0.06, 0.05), None))
    me = fused("beard", blobs, voxel=0.009, smooth=0.6, repeat=5, decimate=0.18)
    append_mesh("beard", me, HAIR)


def moustache():
    for sx in (-1, 1):
        pts = []
        for k in range(9):
            f = k / 8
            x = sx * (0.008 + 0.085 * f)
            z = 0.925 - 0.035 * f * f + 0.006 * math.sin(math.pi * f)
            pts.append(Vector((x, head_y(x, z) + 0.016, z)))
        tube("moustache", pts, 0.019, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.5 * smoothstep(0.55, 1.0, s))


def brows():
    for sx in (-1, 1):
        x, z = sx * 0.12, 1.035
        c = Vector((x, head_y(x, z), z))
        n = head_normal(c)
        b = basis_from(n) @ Matrix.Rotation(sx * math.radians(-10.0), 3, "Z")
        ellipsoid("brows", c + n * 0.008, (0.042, 0.016, 0.014), HAIR, cols=10, rings=6, basis=b)


beard()
moustache()
brows()

# --- Flat cap: a soft felt crown pulled forward over a short stiff peak, with a button on top -------------------------
FRAME = hat_frame(14.0, 0.05)
CAP_RX, CAP_RY = 0.335, 0.31


def flat_cap():
    # (height up the cap's axis, radius as a fraction of its foot, how far forward the ring slides)
    prof = [(0.07, 0.97, 0.0), (0.085, 1.0, 0.0), (0.115, 1.05, 0.006), (0.145, 1.08, 0.016), (0.172, 1.06, 0.026),
            (0.192, 0.98, 0.032), (0.205, 0.84, 0.035), (0.213, 0.62, 0.036), (0.217, 0.35, 0.036)]
    cols = 32
    P, S = lathe([(z, CAP_RX * r, CAP_RY * r) for z, r, _ in prof], cols, 4, 0.02)
    P = [[p + Vector((0.0, prof[j][2], 0.0)) for p in ring] for j, ring in enumerate(P)]
    vs, _ = grid("cap", transformed(P, FRAME), S, FELT, HAT, period=cols)
    top = FRAME @ Vector((0.0, prof[-1][2], 0.219))
    cap("cap", vs[-1], S[-1], top, 0.0, FELT, HAT, cols)
    ellipsoid("cap", top + Vector((0, 0, 0.004)), (0.024, 0.024, 0.012), HAT, cols=10, rings=6)
    # a stitched seam from the button down to the front
    path = []
    for j in range(len(prof) - 1, 2, -1):
        p = FRAME @ (P[j][cols * 2] + Vector((0, 0, 0.002)))
        path.append((p, (FRAME.to_3x3() @ Vector((0, 0.4, 1))).normalized()))
    running_stitch("cap", path, THREAD, dash=0.02, gap=0.012, thick=0.0035)


def peak():
    """A short stiff peak over the brow: a thin felt slab round the front of the cap's foot, its loop traced
    (under side out, round the lip, top side back) for each slice across."""
    slices = 15
    span = math.radians(62.0)
    rings = []
    for j in range(slices):
        a = math.pi / 2 - span + 2 * span * j / (slices - 1)
        w = 0.062 * max(math.cos((a - math.pi / 2) / span * math.pi / 2), 0.0) ** 0.6 + 0.004
        loop = []
        for k, (out, up) in enumerate([(0.0, 0.0), (0.4, -0.006), (0.8, -0.015), (1.0, -0.016), (1.02, -0.008),
                                       (1.0, 0.0), (0.8, -0.003), (0.4, 0.006), (0.0, 0.012)]):
            r = 1.0
            x, y = CAP_RX * r * math.cos(a), CAP_RY * r * math.sin(a)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            loop.append(FRAME @ (Vector((x, y, 0.075 + up)) + d * (w * out - 0.004) + Vector((0, 0, -0.008 * out * out))))
        rings.append(loop)
    # rings run across the peak (j), points round its loop (k): open both ways
    P = [[rings[j][k] for j in range(slices)] for k in range(len(rings[0]))]
    S = [[(0.0, 0.0)] * slices for _ in P]
    grid("peak", P, S, FELT, HAT, closed=False)


flat_cap()
peak()

guest_finish("knit_guest_walt", SCALE)
