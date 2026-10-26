# Builds the knitted clipboard prop (art/props/knit_clipboard/knit_clipboard.glb) in Blender, from code only.
#   blender --background --factory-startup --python art/props/knit_clipboard/build_knit_clipboard.py -- OUT.glb
# The owner's ask (25 Oct 2026): a clipboard that looks knitted, with a knitted sheet of paper the writing sits on,
# held open by the camper while that player has their clipboard open. Made by art/RECIPE.md with the shared kit
# (art/tools/knit_kit.py): a felt board, a ribbed knitted clip with a yarn loop, a knit-weave sheet pillowed a few mm
# proud of the board, and lines of running stitch for the writing. It stands upright, the sheet facing the front
# (+Y here, -Z in the game), its origin at the bottom centre of the board, where the mittens hold it; Gameplay tips it
# back toward the face. The game paints it (data/models.json "knit_clipboard" file_slots). Original work, CC BY 4.0.
import math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from knit_kit import *  # the shapes, the mesh BM, OUT and finish()

# slots: indices into data/models.json "knit_clipboard" file_slots
BOARD, SHEET, CLIP, INK = range(4)

# Sizes (metres), from the brief: about 0.26 wide, 0.34 tall and 0.03 thick at the camper's scale, a little oversized
# so it reads from the play camera.
BOARD_W, BOARD_H, BOARD_T = 0.26, 0.34, 0.024
SHEET_W, SHEET_BOTTOM, SHEET_TOP = 0.212, 0.024, 0.305   # the sheet's width and where it starts and ends (z)
SHEET_PROUD, SHEET_PILLOW = 0.0015, 0.0035   # its edge off the board, and how much more its middle swells
SHEET_COL = 0.0125     # a knit column on the sheet: finer than the sweater's, as for a small piece of knitting
CLIP_W, CLIP_Z, CLIP_D = 0.11, (0.288, 0.352), 0.0225   # the clip's width, bottom and top, and half its depth
CLIP_RIBS = 18


def board():
    """A rounded felt slab facing +Y: rings of a rounded rectangle from its back, round its edge, then in across its
    front as a frame that stops just inside the sheet's edge. The sheet closes the middle: a front face under it would
    push its fuzz shells (data/art.json "shells", 6 mm) up through the thin sheet as brown speckle."""
    cols, n_exp = 72, 5.0
    hw, hh, zc = BOARD_W / 2, BOARD_H / 2, BOARD_H / 2
    r = BOARD_T * 0.5
    rings = []
    for d in range(-90, 91, 30):
        a = math.radians(d)
        rings.append((-BOARD_T + r + r * math.sin(a), r * (1.0 - math.cos(a)), hw, hh, zc, n_exp))
    # in across the front, to just inside the sheet's edge
    shw, shh, szc = SHEET_W / 2 - 0.004, (SHEET_TOP - SHEET_BOTTOM) / 2 - 0.004, (SHEET_TOP + SHEET_BOTTOM) / 2
    for f in (0.35, 0.7, 1.0):
        rings.append((0.0, 0.0, hw - r + (shw - hw + r) * f, hh - r + (shh - hh + r) * f, zc + (szc - zc) * f,
                n_exp + 3.0 * f))
    P = []
    for y, inset, w, h, z0, ne in rings:
        # reversed: the rings run round the x-z plane, so this way round the faces look outward
        ring = ring_points(w - inset, h - inset, cols, ne)[::-1]
        P.append([Vector((x, y, z0 + z)) for x, z in ring])
    S = [[(0.0, 0.0)] * cols for _ in P]
    vs, _ = grid("board", P, S, FELT, BOARD)
    cap("board", vs[0], S[0], Vector((0, -BOARD_T, zc)), 0.0, FELT, BOARD, 0, at_start=True)


# --- Board: a rounded felt frame, its front face at y = 0, the sheet lying in it ---------------------------------
board()


# --- Sheet: a knitted page lying on the board, its stitch columns running up the page ------------------------------
def sheet_y(x, z):
    """The sheet's front at (x, z): a soft pillow, highest in the middle, tucked down to the board at its edges."""
    fx = 1.0 - (2.0 * x / SHEET_W) ** 6
    fz = 1.0 - ((2.0 * z - SHEET_TOP - SHEET_BOTTOM) / (SHEET_TOP - SHEET_BOTTOM)) ** 6
    return SHEET_PROUD + SHEET_PILLOW * max(fx, 0.0) * max(fz, 0.0)


def sheet():
    cols = round(SHEET_W / SHEET_COL)
    per = 2
    n = cols * per + 1
    rows = 30
    row_h = SHEET_COL * KNIT_ROW
    P, S = [], []
    for j in range(rows + 1):
        z = SHEET_BOTTOM + (SHEET_TOP - SHEET_BOTTOM) * j / rows
        ring, st = [], []
        for i in range(n):
            # right to left, so the faces look out of the page (+Y)
            x = SHEET_W / 2 - SHEET_W * i / (n - 1)
            ring.append(Vector((x, sheet_y(x, z), z)))
            st.append((i / per, (z - SHEET_BOTTOM) / row_h))
        P.append(ring)
        S.append(st)
    grid("sheet", P, S, KNIT_MAP, SHEET, closed=False)


sheet()


# --- Writing: lines of embroidered chain in ink, a little wavy, as handwriting --------------------------------------
# A running stitch this small breaks into dots at the play camera, so each line is one solid two-ply cord, as an
# embroidered chain reads (the recipe's trap: a short line that must read as one stroke has no gaps).
WRITING = [(0.252, 0.088, -0.03, 0.0028), (0.212, 0.088, -0.085), (0.177, 0.088, -0.06), (0.142, 0.088, -0.088),
           (0.107, 0.088, -0.02), (0.072, 0.088, -0.07)]   # (height, start x, end x[, a thicker cord]); x runs from
# the page's left as seen from the front (+x here) to its right


def writing():
    rnd = random.Random(5)
    for row in WRITING:
        z0, x0, x1 = row[:3]
        r = row[3] if len(row) > 3 else 0.002
        phase = rnd.uniform(0.0, math.tau)
        pts = []
        steps = max(int(abs(x1 - x0) / 0.004), 4)
        for k in range(steps + 1):
            x = x0 + (x1 - x0) * k / steps
            z = z0 + 0.0013 * math.sin(x * 150.0 + phase) + 0.0006 * math.sin(x * 410.0 + phase * 2.0)
            pts.append(Vector((x, sheet_y(x, z) + r * 0.55, z)))
        tube("writing", pts, r, INK, sides=6, lobe_depth=0.15, weave=YARN, yarn=(2, 0.012))


writing()


# --- Clip: a ribbed knitted cuff straddling the board's top edge, with a yarn loop for its lever -------------------
def clip():
    z0, z1 = CLIP_Z
    r = 0.012
    prof = [(z0, CLIP_W / 2 - r, CLIP_D - r)]
    for d in range(-60, 1, 30):
        a = math.radians(d)
        prof.append((z0 + r + r * math.sin(a), CLIP_W / 2 - r + r * math.cos(a), CLIP_D - r + r * math.cos(a)))
    for k in range(1, 4):
        prof.append((z0 + r + (z1 - z0 - 2 * r) * k / 4, CLIP_W / 2, CLIP_D))
    for d in range(0, 61, 30):
        a = math.radians(d)
        prof.append((z1 - r + r * math.sin(a), CLIP_W / 2 - r + r * math.cos(a), CLIP_D - r + r * math.cos(a)))
    prof.append((z1, CLIP_W / 2 - r, CLIP_D - r))
    # centred on the board and sheet together
    m = Matrix.Translation((0.0, -BOARD_T / 2 + 0.002, 0.0))
    ribbed_at = lambda j: 0.0035 if 1 <= j <= len(prof) - 2 else 0.0
    P, S = lathe(prof, CLIP_RIBS, 4, 2 * (CLIP_W + CLIP_D * 2) / CLIP_RIBS * KNIT_ROW, n_exp=3.0, ribs=ribbed_at)
    vs, _ = grid("clip", transformed(P, m), S, RIB_MAP, CLIP, period=CLIP_RIBS,
            sharp=lambda j: range(0, len(P[0]), 4) if 1 <= j <= len(prof) - 3 else [])
    cap("clip", vs[0], S[0], m @ Vector((0, 0, z0)), S[0][0][1] - 0.3, RIB_MAP, CLIP, CLIP_RIBS, at_start=True)
    cap("clip", vs[-1], S[-1], m @ Vector((0, 0, z1)), S[-1][0][1] + 0.3, RIB_MAP, CLIP, CLIP_RIBS)
    # the lever: a two-ply yarn loop standing on top of the clip
    loop = []
    for k in range(17):
        a = math.pi * k / 16
        loop.append(m @ Vector((0.03 * math.cos(a), 0.0, z1 - 0.004 + 0.026 * math.sin(a))))
    tube("clip loop", loop, 0.0075, CLIP, sides=8, lobe_depth=0.18, weave=YARN, yarn=(2, 0.03))


clip()

finish("knit_clipboard")
