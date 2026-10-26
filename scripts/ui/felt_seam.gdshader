shader_type canvas_item;
// The running stitch on felt lettering (FeltLetters): diagonal gaps cut the seam line into short stitches.
// FeltLetters sets both from data/look.json "felt" (stitch, stitch_on).

uniform float stitch_px = 6.0;
uniform float on = 0.6;

void fragment() {
	COLOR.a *= step(fract((FRAGCOORD.x + FRAGCOORD.y) / max(stitch_px, 1.0)), on);
}
