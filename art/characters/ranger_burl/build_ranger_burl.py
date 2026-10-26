# Builds Ranger Burl, the camp's senior ranger and guide, in Blender from code:
#   blender --background --factory-startup --python art/characters/ranger_burl/build_ranger_burl.py -- OUT.glb [--pose=talk]
# Add --pose=t for the review T-pose, or --pose=talk for his talking pose (his free hand raised, as if pointing the
# way). The shared guest body (../knit_guests/guest_body.py), a little taller and rounder than the players, with Burl's
# own top: a big olive campaign hat with a pinched crown and a wide brim, a grey knitted beard of yarn locks, bushy
# brows, a honey badge on a khaki ranger sweater and a knobbly walking stick. Made by following art/RECIPE.md; the game
# paints it from the palette (data/models.json "ranger_burl" file_slots). Original work, CC BY 4.0 (CREDITS.md).
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "knit_guests"))
from guest_body import *  # the kit, the head helpers, the slots and body()

STICK = 13                    # a fixed swatch after the guests' thirteen slots (data/models.json)
GIRTH, SCALE = 1.07, 1.05     # older, a little rounder and taller than the players
TALK = "--pose=talk" in ARGS
# talking: the left arm lifts forward and out, as if showing the way; the right hand keeps the stick
POSES = {-1: (math.radians(10.0), math.radians(42.0))} if TALK else None

body(GIRTH, smile=True, cheeks=True, arm_poses=POSES)

# --- Hair: short white-grey felt round the sides and back, with short yarn locks over it ----------------------------
HAIRLINE = [(0, 1.1), (40, 1.08), (62, 1.0), (78, 0.93), (95, 0.96), (115, 0.95), (140, 0.88), (180, 0.86)]
hair_cap(HAIRLINE, slot=HAIR_SHADE, cols=40, rows=8)

rnd = random.Random(8)
for row, (top, drop) in enumerate([(0.07, 0.07), (0.035, 0.06)]):
    n = 20 if row == 0 else 18
    for k in range(n):
        th = math.radians(72.0 + (360.0 - 144.0) * (k + 0.5 * row + 0.5) / n + rnd.uniform(-3, 3))
        th = (th + math.pi) % math.tau - math.pi
        lock_r = rnd.uniform(0.014, 0.017)
        z0 = table_at(HAIRLINE, th) + top + rnd.uniform(0.0, 0.015)
        pts = []
        for s in range(7):
            z = z0 - drop * s / 6
            r = head_radius(th, z) + HAIR_OFF + lock_r * 0.8 + 0.004 * row
            pts.append(Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z)))
        tube("hair", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.4 * max(0.0, s - 0.7) / 0.3)


# --- Beard: a long felt mass down to the chest, covered in two-ply yarn locks, a moustache and bushy brows -----------
def beard_mass():
    blobs = []
    for k in range(13):
        th = math.radians(-94.0 + 188.0 * k / 12)
        w = abs(math.degrees(th)) / 94.0
        z = 0.855 + 0.075 * w ** 1.6
        r = head_radius(th, z) + 0.008
        c = Vector((HEAD_C.x + r * math.sin(th), HEAD_C.y + r * math.cos(th), z))
        size = 0.06 - 0.02 * w
        blobs.append((c, (size, size, size * 1.15), None))
    front = head_y(0.0, 0.8)
    blobs.append((Vector((0.0, front + 0.04, 0.80)), (0.135, 0.08, 0.085), None))
    blobs.append((Vector((0.0, front + 0.06, 0.74)), (0.105, 0.065, 0.075), None))
    blobs.append((Vector((0.0, front + 0.065, 0.69)), (0.06, 0.045, 0.05), None))
    return fused("beard", blobs, voxel=0.009, smooth=0.6, repeat=5, decimate=0.16)


BEARD = beard_mass()
append_mesh("beard", BEARD, HAIR_SHADE)


def beard_locks():
    """Yarn locks from the jaw line down over the mass, gathering toward the beard's rounded point."""
    tree = surface_tree(BEARD)
    rnd = random.Random(12)
    front = head_y(0.0, 0.8)
    n = 17
    for k in range(n):
        th = math.radians(-88.0 + 176.0 * k / (n - 1) + rnd.uniform(-2, 2))
        w = abs(math.degrees(th)) / 88.0
        z0 = 0.885 + 0.07 * w ** 1.6
        x0 = math.sin(th) * (head_radius(th, z0) + 0.02)
        end_z = 0.67 + 0.13 * w ** 1.3 + rnd.uniform(-0.01, 0.01)
        lock_r = rnd.uniform(0.016, 0.019)
        pts = []
        steps = 12
        for s in range(steps + 1):
            f = s / steps
            z = z0 + (end_z - z0) * f
            x = x0 * (1.0 - 0.55 * f)
            # aim at the beard from in front, toward the inside of the jaw
            inner = Vector((x * 0.3, front - 0.06, z))
            out = Vector((x * 1.6, front + 0.35, z)) if abs(th) < math.radians(60) else \
                Vector((x * 1.9, front + 0.05, z))
            loc, nrm = hit(tree, out, inner - out)
            if loc is None:
                continue
            pts.append(loc + nrm * lock_r * 0.55)
        if len(pts) < 4:
            continue
        # a small curl at the tip
        last, prev = pts[-1], pts[-2]
        down = (last - prev).normalized()
        fwd = Vector((0.0, 1.0, 0.0))
        for j in range(1, 5):
            a = math.radians(45.0 * j)
            pts.append(last + down * lock_r * math.sin(a) + fwd * lock_r * (1 - math.cos(a)))
        tube("beard", pts, lock_r, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.35 * smoothstep(0.7, 1.0, s))


def moustache():
    for sx in (-1, 1):
        pts = []
        for k in range(10):
            f = k / 9
            x = sx * (0.008 + 0.1 * f)
            z = 0.93 - 0.05 * f * f + 0.008 * math.sin(math.pi * f)
            pts.append(Vector((x, head_y(x, z) + 0.018, z)))
        tube("moustache", pts, 0.022, HAIR, sides=6, lobe_depth=0.18, weave=YARN, yarn=LOCK_PLY,
                taper=lambda s: 1.0 - 0.55 * smoothstep(0.5, 1.0, s))


def brows():
    for sx in (-1, 1):
        x, z = sx * 0.122, 1.04
        c = Vector((x, head_y(x, z), z))
        n = head_normal(c)
        b = basis_from(n) @ Matrix.Rotation(sx * math.radians(-12.0), 3, "Z")
        ellipsoid("brows", c + n * 0.009, (0.048, 0.018, 0.016), HAIR, cols=10, rings=6, basis=b)


beard_locks()
moustache()
brows()


# --- Ranger touches: a honey badge on the chest, two pocket flaps, a walking stick -----------------------------------
def torso_front(x, z):
    """A point on the sweater's front at x and z, and its normal (from a ray toward the body's axis)."""
    for (z0, a0, b0), (z1, a1, b1) in zip(TORSO, TORSO[1:]):
        if z0 <= z <= z1:
            f = (z - z0) / (z1 - z0)
            a, b = (a0 + (a1 - a0) * f) * GIRTH, (b0 + (b1 - b0) * f) * GIRTH
            k = max(1.0 - abs(x / a) ** 2.4, 0.0) ** (1 / 2.4)
            p = Vector((x, b * k, z))
            n = Vector((x / a ** 2 * 0.6, (b * k) / b ** 2, 0.0)).normalized()
            return p, n
    raise ValueError(z)


def badge():
    p, n = torso_front(-0.11, 0.64)
    b = basis_from(n)
    # a shield: a rounded felt plate with a bead boss in its middle and a stitched rim
    ellipsoid("badge", p + n * 0.004, (0.036, 0.044, 0.008), THREAD, cols=14, rings=8, basis=b, weave=BEAD)
    ellipsoid("badge", p + n * 0.012, (0.014, 0.014, 0.006), TRIM, cols=10, rings=6, basis=b, weave=BEAD)


def pockets():
    for sx in (-1, 1):
        p, n = torso_front(sx * 0.12, 0.575)
        b = basis_from(n)
        ellipsoid("pockets", p + n * 0.006, (0.06, 0.024, 0.01), SHIRT, cols=14, rings=8, basis=b)
        ellipsoid("pockets", p + n * 0.016 + b @ Vector((0.0, -0.01, 0.0)), (0.009, 0.009, 0.005), TRIM, cols=8,
                rings=5, basis=b, weave=BEAD)


def stick():
    """A knobbly wooden walking stick standing on the ground, held in the right mitten."""
    hand = arm_matrix(1, GIRTH, (POSES or {}).get(1)) @ Vector((0, 0, HAND_AT))
    foot = Vector((hand.x + 0.03, hand.y + 0.06, 0.014))
    top = foot + (hand - foot) * (1.0 + 0.32 / max((hand - foot).length, 0.1))
    pts = [foot.lerp(top, k / 20) + Vector((0.006 * math.sin(k * 1.3), 0.005 * math.cos(k * 0.9), 0.0))
           for k in range(21)]
    tube("stick", pts, 0.019, STICK, sides=8, taper=lambda s: 0.85 + 0.15 * s)
    ellipsoid("stick", top + Vector((0, 0, 0.01)), (0.032, 0.032, 0.03), STICK, cols=12, rings=8)
    for f in (0.3, 0.55):
        ellipsoid("stick", foot.lerp(top, f) + Vector((0.012, 0.004, 0.0)), (0.013, 0.011, 0.016), STICK, cols=8,
                rings=5)
    print("stick hand (Blender x, y, z): %.3f %.3f %.3f" % tuple(hand))


badge()
pockets()
stick()


# --- Campaign hat: a tall crown pinched into four dents, on a wide flat brim with a leather band -------------------
FRAME = hat_frame(15.0, 0.035)
HAT_RX, HAT_RY = 0.33, 0.31     # the crown's foot, round the hair
BRIM, BRIM_THICK = 0.125, 0.022


def campaign_hat():
    w = BRIM / HAT_RX
    # the brim: under side out to its lip (curling a little down), round the lip, back along the top
    prof = [(0.06, 0.99)]
    for k in range(1, 5):
        f = k / 4
        prof.append((0.06 - 0.012 * f * f, 1.0 + w * f))
    for d in (-60, 0, 60):
        a = math.radians(d)
        prof.append((0.048 + BRIM_THICK * 0.5 + BRIM_THICK * 0.5 * math.sin(a), 1.0 + w + 0.01 * math.cos(a)))
    for k in range(4, 0, -1):
        f = k / 4
        prof.append((0.06 + BRIM_THICK - 0.012 * f * f, 1.0 + w * f))
    # the crown: straight-ish sides tapering to a pinched top
    crown = [(0.08, 0.97), (0.12, 0.93), (0.17, 0.88), (0.22, 0.82), (0.26, 0.76), (0.29, 0.68), (0.305, 0.5)]
    start = len(prof)
    prof += crown
    cols = 36
    P, S = lathe([(z, HAT_RX * r, HAT_RY * r) for z, r in prof], cols, 4, 0.02)
    # four dents: the crown pinches in at the front, back and sides near the top (a "Montana" peak)
    for j in range(start, len(P)):
        lift = (prof[j][0] - 0.08) / (0.305 - 0.08)
        for i, p in enumerate(P[j]):
            a = math.atan2(p.y, p.x)
            pinch = 1.0 - 0.13 * lift ** 1.5 * max(math.cos(4 * (a - math.pi / 4)), 0.0)
            P[j][i] = Vector((p.x * pinch, p.y * pinch, p.z - 0.015 * lift ** 2 * max(math.cos(4 * a), 0.0)))
    P = transformed(P, FRAME)
    vs, _ = grid("hat", P, S, FELT, HAT, period=cols)
    cap("hat", vs[-1], S[-1], FRAME @ Vector((0, 0, 0.3)), 0.0, FELT, HAT, cols)
    # the leather band round the crown's foot, with a small honey buckle at the side
    band = [(z, HAT_RX * (r + 0.025), HAT_RY * (r + 0.025)) for z, r in
            [(0.075, 0.975), (0.08, 0.99), (0.11, 0.955), (0.118, 0.935)]]
    P, S = lathe(band, cols, 2, 0.02)
    grid("hat band", transformed(P, FRAME), S, FELT, TRIM, period=cols)
    ellipsoid("hat band", FRAME @ Vector((HAT_RX * 1.0, 0.0, 0.097)), (0.008, 0.02, 0.016), THREAD, cols=8, rings=6,
            weave=BEAD)
    # a stitched line round the brim
    path = []
    for k in range(73):
        a = -math.pi / 2 + math.tau * k / 72
        r = 1.0 + w * 0.7
        p = FRAME @ Vector((HAT_RX * r * math.cos(a), HAT_RY * r * math.sin(a), 0.06 + BRIM_THICK - 0.006 + 0.0012))
        path.append((p, (FRAME.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()))
    running_stitch("hat stitch", path, THREAD, dash=0.032, gap=0.016, thick=0.004)


campaign_hat()

guest_finish("ranger_burl", SCALE)
