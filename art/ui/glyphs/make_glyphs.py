"""Draws the controller button icons for prompts as SVG files beside this script (original art, CC BY 4.0).

Run: python3 art/ui/glyphs/make_glyphs.py, then godot --headless --import. Each icon is a felt button: a dark ink disc
or pad with a cream rim and a cream mark. Which icon each button name gets is in data/input.json "pad_icons".
"""
import os

INK = "#3B2C25"     # data/palette.json ink_brown
CREAM = "#EEE3CB"   # data/palette.json warm_cream
HONEY = "#D6AF66"   # data/palette.json honey_thread
OUT = os.path.dirname(os.path.abspath(__file__))
W = 7               # mark stroke width


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'{body}</svg>\n')


def disc(mark):
    return svg(64, 64, f'<circle cx="32" cy="32" r="29" fill="{INK}" stroke="{CREAM}" stroke-width="3"/>{mark}')


def line(points, w=W):
    d = " ".join(("M" if i == 0 else "L") + f"{x},{y}" for i, (x, y) in enumerate(points))
    return (f'<path d="{d}" fill="none" stroke="{CREAM}" stroke-width="{w}" stroke-linecap="round" '
            f'stroke-linejoin="round"/>')


# Letters and digits as strokes on a 10 x 16 cell, so no font is needed.
STROKES = {
    "L": [[(0, 0), (0, 16), (9, 16)]],
    "R": [[(0, 16), (0, 0), (6, 0), (9, 2.5), (9, 5.5), (6, 8), (0, 8)], [(5, 8), (9, 16)]],
    "1": [[(1.5, 3), (5, 0), (5, 16)]],
    "2": [[(0.5, 3), (3, 0), (7, 0), (9.5, 3), (9.5, 6), (0.5, 16), (9.5, 16)]],
    "3": [[(0.5, 1), (8.5, 1), (4, 7), (7, 7), (9.5, 10), (9.5, 13), (7, 16), (2, 16), (0, 14)]],
}


def word(text, x, y, scale, w=5):
    out = ""
    for ch in text:
        for stroke in STROKES[ch]:
            out += line([(x + px * scale, y + py * scale) for px, py in stroke], w)
        x += 13 * scale
    return out


def bumper(text, right):
    # A shoulder button: a rounded slab, higher on its outer corner.
    path = ("M6,52 L6,26 Q6,12 22,10 L58,6 Q62,6 62,12 L62,52 Q62,58 56,58 L12,58 Q6,58 6,52 Z" if right else
            "M58,52 L58,26 Q58,12 42,10 L6,6 Q2,6 2,12 L2,52 Q2,58 8,58 L52,58 Q58,58 58,52 Z")
    return svg(64, 64, f'<path d="{path}" fill="{INK}" stroke="{CREAM}" stroke-width="3"/>'
               + word(text, 16, 21, 1.6))


def stick(text):
    ring = (f'<circle cx="32" cy="32" r="29" fill="{INK}" stroke="{CREAM}" stroke-width="3"/>'
            f'<circle cx="32" cy="32" r="18" fill="none" stroke="{HONEY}" stroke-width="3"/>')
    return svg(64, 64, ring + (word(text, 19.5, 22, 1.2, 4.5) if text else ""))


def dpad(arm):
    plus = (f'<path d="M24,4 L40,4 L40,24 L60,24 L60,40 L40,40 L40,60 L24,60 L24,40 L4,40 L4,24 L24,24 Z" '
            f'fill="{INK}" stroke="{CREAM}" stroke-width="3" stroke-linejoin="round"/>')
    # The pressed arm is filled honey with an ink arrow, so up, down, left and right tell apart at prompt size.
    arms = {"up": (24, 4, 16, 22), "down": (24, 38, 16, 22), "left": (4, 24, 22, 16), "right": (38, 24, 22, 16)}
    tips = {"up": "M32,9 L38,19 L26,19 Z", "down": "M32,55 L38,45 L26,45 Z",
            "left": "M9,32 L19,26 L19,38 Z", "right": "M55,32 L45,26 L45,38 Z"}
    x, y, w, h = arms[arm]
    lit = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="3" fill="{HONEY}"/>'
    return svg(64, 64, plus + lit + f'<path d="{tips[arm]}" fill="{INK}"/>')


ICONS = {
    "pad_cross": disc(line([(20, 20), (44, 44)]) + line([(44, 20), (20, 44)])),
    "pad_circle": disc(f'<circle cx="32" cy="32" r="13" fill="none" stroke="{CREAM}" stroke-width="{W}"/>'),
    "pad_square": disc(f'<rect x="20" y="20" width="24" height="24" fill="none" stroke="{CREAM}" '
                       f'stroke-width="{W}" stroke-linejoin="round"/>'),
    "pad_triangle": disc(line([(32, 17), (46, 42), (18, 42), (32, 17)])),
    "pad_options": svg(64, 64, f'<rect x="12" y="6" width="40" height="52" rx="14" fill="{INK}" stroke="{CREAM}" '
                       f'stroke-width="3"/>' + line([(23, 22), (41, 22)], 5) + line([(23, 32), (41, 32)], 5)
                       + line([(23, 42), (41, 42)], 5)),
    "pad_create": svg(64, 64, f'<rect x="12" y="6" width="40" height="52" rx="14" fill="{INK}" stroke="{CREAM}" '
                      f'stroke-width="3"/>' + line([(32, 16), (32, 30)], 4) + line([(24, 22), (32, 14), (40, 22)], 4)
                      + line([(22, 40), (42, 40)], 4) + line([(22, 48), (42, 48)], 4)),
    "pad_touchpad": svg(96, 64, f'<rect x="3" y="8" width="90" height="48" rx="12" fill="{INK}" stroke="{CREAM}" '
                        f'stroke-width="3"/><path d="M48,14 L48,50" stroke="{HONEY}" stroke-width="2" '
                        f'stroke-dasharray="4 4"/>'),
    "pad_l1": bumper("L1", False), "pad_r1": bumper("R1", True),
    "pad_l2": bumper("L2", False), "pad_r2": bumper("R2", True),
    "pad_lstick": stick(""), "pad_rstick": stick(""),
    "pad_l3": stick("L3"), "pad_r3": stick("R3"),
    "pad_up": dpad("up"), "pad_down": dpad("down"), "pad_left": dpad("left"), "pad_right": dpad("right"),
}

for name, text in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(text)
print(len(ICONS), "icons")
