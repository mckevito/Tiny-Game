# Puts a Blender-built model's studio turnaround (art/tools/turnaround.sh) beside its reference sheet and measures the
# difference, for the method in art/RECIPE.md. A reference.json beside the model's build script describes the sheet.
#   python3 art/tools/compare.py sheets  RENDERS REF.json                  # compare8.png, pairs.png, versus.png
#   python3 art/tools/compare.py outline RENDERS REF.json [VIEW]           # width at each height, sheet against ours
#   python3 art/tools/compare.py colours RENDERS REF.json                  # median colour of each band, and the fix
#   python3 art/tools/compare.py zoom    RENDERS REF.json VIEW X0,Y0,X1,Y1 [TIMES]   # both, cropped (render pixels)
#   python3 art/tools/compare.py overlay RENDERS REF.json VIEW             # our outline drawn over the sheet
#   python3 art/tools/compare.py siblings RENDERS REF.json OTHER_RENDERS   # siblings.png: OTHER's views beside ours
# RENDERS is the folder of turn_<view>.png; images are written there. Needs Pillow and NumPy.
import json, math, os, signal, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

if hasattr(signal, "SIGPIPE"):
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet when piped into head
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
VIEWS = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]  # capture.gd's order
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf"
INK = (60, 40, 30)
PICKS = {  # which pixels of a colour band count, so the background and other parts drop out
    "blue": lambda p: (p[:, 2] > p[:, 0] + 10) & (p[:, 1] > p[:, 0]),
    "skin": lambda p: (p[:, 0] > 180) & (p[:, 0] > p[:, 2] + 40) & (p[:, 1] > 120),
    "brown": lambda p: (p[:, 0] > p[:, 2] + 15) & (p[:, 0] < 170) & (p[:, 1] < 120),
    "dark": lambda p: p.max(1) < 90,
    "any": lambda p: np.ones(len(p), bool),
}


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT % ("-Bold" if bold else ""), size)
    except OSError:
        return ImageFont.load_default()


def studio(height):
    """Where the ground lands (pixel row) in a turn render `height` pixels tall, and its pixels per metre, from the
    studio camera in data/art.json "turnaround"."""
    with open(os.path.join(ROOT, "data", "art.json")) as f:
        cfg = json.load(f)["turnaround"]
    dist, cam_h, aim = cfg["camera_distance_m"], cfg["camera_height_m"], cfg["aim_height_m"]
    focal = height / 2 / math.tan(math.radians(cfg["fov_deg"]) / 2)
    below = math.atan(cam_h / dist) - math.atan((cam_h - aim) / dist)
    return height / 2 + focal * math.tan(below), focal / dist


def to_lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255


def hexed(c):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c)


def multiply_onto(factors, im, x, y):
    """Lays a studio render on a sheet as a multiply: each row is divided by its own backdrop (the brighter of its two
    ends), so the floor and the wall both drop out and shadows overlap without seams."""
    a = np.asarray(im).astype(float)
    edge = np.maximum(a[:, :8].mean(1), a[:, -8:].mean(1))
    a = np.clip(a / np.maximum(edge[:, None, :], 1.0), 0.0, 1.06)
    H, W = factors.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + a.shape[1], W), min(y + a.shape[0], H)
    if x1 > x0 and y1 > y0:
        factors[y0:y1, x0:x1] *= a[y0 - y:y1 - y, x0 - x:x1 - x]


def row_span(row, threshold=45):
    """The first and last pixel of a row that differ from the row's own ends (the background)."""
    bg = np.maximum(row[:6].mean(0), row[-6:].mean(0))
    xs = np.nonzero(np.abs(row - bg).sum(1) > threshold)[0]
    return (xs.min(), xs.max()) if len(xs) else None


class Round:
    """One round's renders and the reference sheet they are judged against."""

    def __init__(self, renders, layout):
        with open(layout) as f:
            self.cfg = json.load(f)
        self.dir = renders
        self.ref_path = layout
        self.ref = Image.open(self.cfg["sheet"]).convert("RGB")
        self.bg = self.ref.getpixel(tuple(self.cfg["background_at"]))
        self.ppm = float(self.cfg["px_per_m"])
        self.views = self.cfg["views"]

    def render(self, view):
        """A render, the row its ground lands on, its pixels per metre, and the scale that puts it on the sheet."""
        im = Image.open(os.path.join(self.dir, "turn_%s.png" % view)).convert("RGB")
        ground, ppm = studio(im.height)
        return im, ground, ppm, self.ppm / ppm

    def placed(self, factors, view, cx, gy):
        im, ground, _, s = self.render(view)
        small = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        multiply_onto(factors, small, round(cx - small.width / 2), round(gy - ground * s))

    def save(self, im, name):
        path = os.path.join(self.dir, name)
        im.save(path)
        print("saved", path)

    def laid_out(self):
        """Our eight renders laid out exactly as the sheet's views."""
        f = np.ones((self.ref.height, self.ref.width, 3))
        for view, (cx, gy) in self.views.items():
            self.placed(f, view, cx, gy)
        return Image.fromarray(np.clip(f * np.array(self.bg, float), 0, 255).astype(np.uint8))

    def siblings(self, other_dir, labels=("Player one", "Player two")):
        """Two models' rounds side by side in each of the sheet's paired views (a sibling against the model it was
        made beside): other_dir's renders on the left, this round's on the right."""
        mine, theirs = self.laid_out(), Round(other_dir, self.ref_path).laid_out()
        cells = []
        for box in self.cfg.get("pairs", {}).values():
            a, b = theirs.crop(box), mine.crop(box)
            pair = Image.new("RGB", (a.width * 2, a.height + 40), self.bg)
            pair.paste(a, (0, 40))
            pair.paste(b, (a.width, 40))
            draw = ImageDraw.Draw(pair)
            for k, name in enumerate(labels):
                x = a.width * k + a.width / 2 - draw.textlength(name, font=font(22)) / 2
                draw.text((x, 8), name, fill=INK, font=font(22))
            cells.append(pair)
        strip = Image.new("RGB", (sum(c.width for c in cells), max(c.height for c in cells)), self.bg)
        x = 0
        for c in cells:
            strip.paste(c, (x, 0))
            x += c.width
        self.save(strip, "siblings.png")

    def sheets(self):
        ref, bg = self.ref, self.bg
        # ours laid out exactly as the sheet, under it
        ours = self.laid_out()
        draw = ImageDraw.Draw(ours)
        for view, (cx, gy) in self.views.items():
            name = view.replace("_", " ").capitalize()
            draw.text((cx - draw.textlength(name, font=font(22)) / 2, gy + 16), name, fill=INK, font=font(22))
        both = Image.new("RGB", (ref.width, ref.height * 2), bg)
        both.paste(ref, (0, 0))
        both.paste(ours, (0, ref.height))
        self.save(both, "compare8.png")
        self.save(both.resize((ref.width // 2, ref.height)), "compare8_small.png")
        # each reference view beside ours
        cells = []
        for box in self.cfg.get("pairs", {}).values():
            a, b = ref.crop(box), ours.crop(box)
            pair = Image.new("RGB", (a.width * 2, a.height), bg)
            pair.paste(a, (0, 0))
            pair.paste(b, (a.width, 0))
            cells.append(pair)
        if cells:
            strip = Image.new("RGB", (sum(c.width for c in cells), max(c.height for c in cells)), bg)
            x = 0
            for c in cells:
                strip.paste(c, (x, 0))
                x += c.width
            self.save(strip, "pairs.png")
        # the sheet to show the owner: their sheet on top, ours from the front, right, back and left below
        cell_w, top, cell_h = ref.width // 4, 70, max(300, round(1.72 * self.ppm))
        f = np.ones((top + cell_h + 50, ref.width, 3))
        for k, view in enumerate(["front", "right", "back", "left"]):
            self.placed(f, view, cell_w * k + cell_w // 2, top + cell_h)
        lower = Image.fromarray(np.clip(f * np.array(bg, float), 0, 255).astype(np.uint8))
        draw = ImageDraw.Draw(lower)
        title = self.cfg.get("title", "THE GAME'S MODEL: SAME VIEWS, STUDIO LIGHT")
        draw.text(((ref.width - draw.textlength(title, font=font(30, True))) / 2, 18), title, fill=INK,
                font=font(30, True))
        for k, name in enumerate(["Front", "Right", "Back", "Left"]):
            cx = cell_w * k + cell_w // 2
            draw.text((cx - draw.textlength(name, font=font(22)) / 2, top + cell_h + 8), name, fill=INK, font=font(22))
        out = Image.new("RGB", (ref.width, ref.height + lower.height), bg)
        out.paste(ref, (0, 0))
        out.paste(lower, (0, ref.height))
        ImageDraw.Draw(out).line([(40, ref.height + 4), (ref.width - 40, ref.height + 4)], fill=(220, 205, 185), width=2)
        self.save(out, "versus.png")

    def outline(self, view="front"):
        """The figure's left and right edge at every 5 cm of height, in metres from its middle: sheet, then ours.
        The lowest rows also catch the floor shadow."""
        cx, gy = self.views[view]
        x0, top, x1, bottom = self.cfg.get("pairs", {}).get(view, [cx - self.ref.width // 8, 0,
                cx + self.ref.width // 8, self.ref.height])
        ref = np.asarray(self.ref).astype(float)
        try:
            im, ground, ppm, _ = self.render(view)
            ours = np.asarray(im).astype(float)
        except FileNotFoundError:  # no renders yet: measure the sheet alone, to plan the model
            im, ground, ppm, ours = None, 0, 1, np.zeros((0, 0, 3))
        print("%s     sheet left..right (m)   ours left..right (m)" % view)
        for z in np.arange(1.80, -0.01, -0.05):
            y = round(gy - z * self.ppm)
            yo = round(ground - z * ppm)
            if y < top or y >= bottom or (im and yo < 0):
                continue
            r = row_span(ref[y, x0:x1])
            o = row_span(ours[yo]) if im and yo < ours.shape[0] else None
            rs = "%+.3f..%+.3f" % ((r[0] + x0 - cx) / self.ppm, (r[1] + x0 - cx) / self.ppm) if r else "-"
            os_ = "%+.3f..%+.3f" % ((o[0] - im.width / 2) / ppm, (o[1] - im.width / 2) / ppm) if o else "-"
            if r or o:
                print("  %.2f   %-22s  %-22s" % (z, rs, os_))

    def colours(self):
        """Median colour of each band of the front view (in linear light), sheet against ours, the ratio, and the
        swatch that ratio asks for."""
        with open(os.path.join(ROOT, "data", "palette.json")) as f:
            swatches = json.load(f)["swatches"]
        cx, gy = self.views["front"]
        im, ground, ppm, _ = self.render("front")
        ref, ours = np.asarray(self.ref).astype(float), np.asarray(im).astype(float)

        def sample(img, gy_, ppm_, cx_, z0, z1, half, pick):
            reg = img[round(gy_ - z1 * ppm_):round(gy_ - z0 * ppm_), round(cx_ - half * ppm_):round(cx_ + half * ppm_)]
            reg = reg.reshape(-1, 3)
            keep = PICKS[pick](reg)
            sel = reg[keep] if keep.any() else reg
            return np.median(to_lin(sel), 0), int(keep.sum())

        for name, band in self.cfg.get("bands", {}).items():
            z0, z1, half, pick = band[:4]
            a, na = sample(ref, gy, self.ppm, cx, z0, z1, half, pick)
            b, nb = sample(ours, ground, ppm, im.width / 2, z0, z1, half, pick)
            ratio = a / np.maximum(b, 1e-4)
            line = "%-9s sheet %s (%d px)  ours %s (%d px)  ratio %s" % (name, hexed(to_srgb(a)), na,
                    hexed(to_srgb(b)), nb, np.round(ratio, 3))
            if len(band) > 4 and band[4] in swatches:
                old = Image.new("RGB", (1, 1), swatches[band[4]]).getpixel((0, 0))
                line += "  %s %s -> %s" % (band[4], hexed(old), hexed(to_srgb(to_lin(old) * ratio)))
            print(line)

    def zoom(self, view, box, times=1):
        """The same region of the sheet and of our render (in render pixels), the sheet's scaled up to ours."""
        cx, gy = self.views[view]
        im, ground, _, s = self.render(view)
        x0, y0, x1, y1 = box
        ox, oy = cx - im.width * s / 2, gy - ground * s
        a = self.ref.crop((round(ox + x0 * s), round(oy + y0 * s), round(ox + x1 * s), round(oy + y1 * s)))
        a = a.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        b = im.crop(box)
        pair = Image.new("RGB", (a.width * 2 + 10, a.height), (255, 255, 255))
        pair.paste(a, (0, 0))
        pair.paste(b, (a.width + 10, 0))
        if times > 1:
            pair = pair.resize((pair.width * times, pair.height * times), Image.LANCZOS)
        self.save(pair, "zoom_%s.png" % view)

    def overlay(self, view):
        """Our outline in red over the sheet's view, and the two blended half and half."""
        cx, gy = self.views[view]
        im, ground, _, s = self.render(view)
        small = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        a = np.asarray(small).astype(float)
        edge = np.maximum(a[:, :6].mean(1), a[:, -6:].mean(1))
        mask = np.abs(a - edge[:, None, :]).sum(2) > 40
        canvas = np.zeros((self.ref.height, self.ref.width), bool)
        blend = np.asarray(self.ref).astype(float).copy()
        x, y = round(cx - small.width / 2), round(gy - ground * s)
        x0, y0 = max(x, 0), max(y, 0)
        x1, y1 = min(x + small.width, self.ref.width), min(y + small.height, self.ref.height)
        canvas[y0:y1, x0:x1] = mask[y0 - y:y1 - y, x0 - x:x1 - x]
        blend[y0:y1, x0:x1] = blend[y0:y1, x0:x1] * 0.5 + a[y0 - y:y1 - y, x0 - x:x1 - x] * 0.5
        lines = np.asarray(Image.fromarray((canvas * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES)) > 0
        red = np.asarray(self.ref).astype(float).copy()
        red[lines] = [255, 0, 0]
        box = self.cfg.get("pairs", {}).get(view, [0, 0, self.ref.width, self.ref.height])
        left = Image.fromarray(red.astype(np.uint8)).crop(box)
        right = Image.fromarray(blend.astype(np.uint8)).crop(box)
        both = Image.new("RGB", (left.width * 2, left.height))
        both.paste(left, (0, 0))
        both.paste(right, (left.width, 0))
        self.save(both.resize((both.width * 2, both.height * 2), Image.LANCZOS), "overlay_%s.png" % view)


def main(argv):
    if len(argv) < 3:
        print(__doc__ or open(__file__).read().split("\nimport")[0])
        return 1
    cmd, r = argv[0], Round(argv[1], argv[2])
    if cmd == "sheets":
        r.sheets()
    elif cmd == "outline":
        r.outline(argv[3] if len(argv) > 3 else "front")
    elif cmd == "colours":
        r.colours()
    elif cmd == "zoom":
        r.zoom(argv[3], [int(v) for v in argv[4].split(",")], int(argv[5]) if len(argv) > 5 else 1)
    elif cmd == "overlay":
        r.overlay(argv[3])
    elif cmd == "siblings":
        r.siblings(argv[3])
    else:
        print("unknown command", cmd)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
