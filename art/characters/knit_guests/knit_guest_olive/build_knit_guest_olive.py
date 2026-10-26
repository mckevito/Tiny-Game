# Builds the second guest's knitted camper (Olive Ashby, a birdwatcher; look guest_b) in Blender, from code:
#   blender --background --factory-startup --python art/characters/knit_guests/knit_guest_olive/build_knit_guest_olive.py -- OUT.glb
# Add --pose=t for the review T-pose. The shared guest body (../guest_body.py) with Olive's own top: a felt bucket hat
# with a ribbon band, a silver bob of yarn locks, round wire glasses and a cream cardigan with wooden buttons. She is
# a little smaller than the players. Made by following art/RECIPE.md; the game paints it from the palette
# (data/models.json "knit_guest_olive" file_slots). Original work, CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from guest_body import *  # the kit, the head helpers, the slots and body()

GIRTH, SCALE = 1.0, 0.94

body(GIRTH, smile=True, cheeks=False)


# --- Cardigan: a ribbed button band down the front and four wooden buttons -----------------------------------------
def torso_front(z):
    """The sweater's front surface (y) on the middle line at height z."""
    for (z0, _, b0), (z1, _, b1) in zip(TORSO, TORSO[1:]):
        if z0 <= z <= z1:
            return (b0 + (b1 - b0) * (z - z0) / (z1 - z0)) * GIRTH
    return TORSO[-1][2] * GIRTH


band = [Vector((0.0, torso_front(z) + 0.004, z)) for z in [0.40 + 0.33 * k / 14 for k in range(15)]]
tube("cardigan", band, 0.014, SHIRT, sides=6)
for k in range(4):
    z = 0.47 + 0.075 * k
    ellipsoid("cardigan", Vector((0.0, torso_front(z) + 0.019, z)), (0.019, 0.008, 0.019), TRIM, cols=10, rings=6,
            weave=BEAD)


# --- Hair: a silver bob, a felt mass under yarn locks that curl under at the jaw, and a fringe ----------------------
BOB_LINE = [(0, 1.05), (40, 1.04), (60, 0.94), (80, 0.87), (180, 0.86)]   # where the hair ends round the head
BOB_FULL = 0.034     # how far the bob stands out past the felt cap at its fullest


def bob_w(theta):
    return smoothstep(45.0, 80.0, abs(math.degrees(theta)))


def bob_at(theta, f):
    """A point on the bob's outside: f 0 at its lower edge, 1 at the crown."""
    d0 = dir_at(theta, table_at(BOB_LINE, theta) - 0.004)
    d = slerp(d0, Vector((0, 0, 1)), f * 0.96)
    full = BOB_FULL * bob_w(theta) * math.sin(min(f * 4.0, 1.0) * math.pi * 0.5) * (1.0 - f) ** 1.5
    return on_head(d, HAIR_OFF + full + 0.01 * bob_w(theta) * (1.0 - f))


def bob():
    cols, rows = 48, 11
    P = []
    # a ring tucked under the lower edge, so the bob has thickness
    tuck = []
    for i in range(cols):
        th = math.pi - math.tau * i / cols
        p = bob_at(th, 0.0)
        tuck.append(p.lerp(on_head(dir_at(th, table_at(BOB_LINE, th) + 0.02), HAIR_OFF), 0.7))
    P.append(tuck)
    for j in range(rows):
        P.append([bob_at(math.pi - math.tau * i / cols, j / (rows - 1)) for i in range(cols)])
    S = [[(0.0, 0.0)] * cols for _ in P]
    vs, _ = grid("hair", P, S, FELT, HAIR_SHADE)
    cap("hair", vs[-1], S[-1], bob_at(0.0, 1.0), 0.0, FELT, HAIR_SHADE, 0)


def bob_locks():
    rnd = random.Random(9)
    n = 21
    for k in range(n):
        th = math.radians(62.0 + (360.0 - 124.0) * (k + 0.5) / n) + rnd.uniform(-0.03, 0.03)
        th = (th + math.pi) % math.tau - math.pi
        lock_r = rnd.uniform(0.016, 0.02)
        pts = []
        steps = 12
        for s in range(steps + 1):
            f = 0.5 * (1.0 - s / steps)
            p = bob_at(th, f)
            pts.append(p + head_normal(p) * lock_r * 0.7)
        # curl under at the ends, toward the neck
        last, prev = pts[-1], pts[-2]
        down = (last - prev).normalized()
        inward = -Vector((math.sin(th), math.cos(th), 0.0))
        for j in range(1, 6):
            a = math.radians(36.0 * j)
            pts.append(last + down * lock_r * 1.2 * math.sin(a) + inward * lock_r * 1.2 * (1 - math.cos(a)))
        tube("hair", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY)
    for k in range(9):
        th = math.radians(-46.0 + 92.0 * k / 8 + rnd.uniform(-2.0, 2.0))
        lock_r = rnd.uniform(0.015, 0.018)
        top, end = 1.13, table_at(BOB_LINE, th) - 0.01
        pts = []
        for s in range(9):
            z = top - (top - end) * s / 8
            r = head_radius(th, z) + HAIR_OFF + lock_r * 0.9
            pts.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
        tube("hair", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.35 * max(0.0, s - 0.7) / 0.3)


bob()
bob_locks()


# --- Glasses: two round wire rims, a bridge and arms back to the ears ------------------------------------------------
def glasses():
    rim_r, wire = 0.05, 0.0055
    centres = []
    for sx in (-1, 1):
        x, z = sx * 0.117, 0.975
        c = Vector((x, head_y(x, z), z))
        n = head_normal(c)
        b = basis_from(n)
        c = c + n * 0.022
        centres.append((c, b))
        tube("glasses", [c + b @ Vector((rim_r * math.cos(a), rim_r * math.sin(a), 0.0)) for a in
                [math.tau * k / 20 for k in range(21)]], wire, INK, sides=5, weave=BEAD)
        # the arm: from the rim's outer edge back over the cheek to the ear
        arm = [c + b @ Vector((-sx * rim_r, 0.008, 0.0))]   # the basis's x points to the camper's left
        for k in range(1, 7):
            th = sx * math.radians(30.0 + 52.0 * k / 6)
            z = 0.985 - 0.035 * k / 6
            r = head_radius(th, z) + 0.016
            arm.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
        tube("glasses", arm, wire * 0.9, INK, sides=5, weave=BEAD)
    (c0, b0), (c1, b1) = centres
    a0 = c0 + b0 @ Vector((-rim_r, 0.006, 0.0))
    a1 = c1 + b1 @ Vector((rim_r, 0.006, 0.0))
    mid = (a0 + a1) * 0.5 + Vector((0.0, 0.008, 0.012))
    tube("glasses", [a0, a0.lerp(mid, 0.5) + Vector((0, 0.004, 0.006)), mid, mid.lerp(a1, 0.5) + Vector((0, 0.004, 0.006)), a1],
            wire, INK, sides=5, weave=BEAD)


glasses()


# --- Bucket hat: a felt crown and a brim sloping down all round, with a ribbon band ----------------------------------
FRAME = hat_frame(17.0, 0.025)
HAT_RX, HAT_RY = 0.385, 0.36      # the crown's foot, roomy round the bob
BRIM, BRIM_SLOPE, BRIM_THICK = 0.07, math.radians(20.0), 0.012


def bucket_hat():
    # a cross-section as (height, radius as a fraction of the foot): under the brim out to its lip, round the lip,
    # back along its top, then up the crown and over its flat round top
    sl, cl = math.sin(BRIM_SLOPE), math.cos(BRIM_SLOPE)
    r0 = 1.0
    w = BRIM / HAT_RX
    prof = [(0.05, r0 - 0.01)]
    for k in range(1, 5):
        f = k / 4
        prof.append((0.05 - BRIM * sl * f, r0 + w * cl * f))
    for d in (-60, 0, 60):
        a = math.radians(d)
        prof.append((0.05 - BRIM * sl + BRIM_THICK * 0.5 + BRIM_THICK * 0.5 * math.sin(a),
                r0 + w * cl + 0.012 * math.cos(a)))
    for k in range(4, 0, -1):
        f = k / 4
        prof.append((0.05 + BRIM_THICK - BRIM * sl * f, r0 + w * cl * f))
    wall = [(0.07, 1.0), (0.12, 0.975), (0.17, 0.945), (0.215, 0.91), (0.25, 0.87), (0.275, 0.8), (0.29, 0.7),
            (0.298, 0.55)]
    prof += wall
    rings = [(z, HAT_RX * r, HAT_RY * r) for z, r in prof]
    P, S = lathe(rings, 32, 4, 0.02)
    P = transformed(P, FRAME)
    vs, _ = grid("hat", P, S, FELT, HAT, period=32)
    cap("hat", vs[-1], S[-1], FRAME @ Vector((0, 0, 0.303)), 0.0, FELT, HAT, 32)
    # the ribbon band round the crown's foot
    band_rings = [(z, HAT_RX * (r + 0.03), HAT_RY * (r + 0.03)) for z, r in
                  [(0.066, 0.985), (0.07, 1.0), (0.09, 1.0), (0.11, 0.99), (0.114, 0.97)]]
    P, S = lathe(band_rings, 32, 2, 0.02)
    grid("hat band", transformed(P, FRAME), S, FELT, THREAD, period=32)
    # a stitched line round the brim
    tree_pts = []
    for k in range(97):
        a = -math.pi / 2 + math.tau * k / 96
        r = 1.0 + w * cl * 0.62
        z = 0.05 + BRIM_THICK - BRIM * sl * 0.62 + 0.0005
        p = FRAME @ Vector((HAT_RX * r * math.cos(a), HAT_RY * r * math.sin(a), z))
        nrm = (FRAME.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
        tree_pts.append((p, nrm))
    running_stitch("hat stitch", tree_pts, THREAD, dash=0.032, gap=0.016, thick=0.004)


bucket_hat()

guest_finish("knit_guest_olive", SCALE)
