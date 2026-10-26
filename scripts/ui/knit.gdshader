shader_type canvas_item;
// Knitted wool for a 2D panel: rows of V stitches shaded over the panel's own colour, and optional stitched rules
// for writing on (the clipboard's sheet, scripts/camp/clipboard.gd). Numbers: data/tuning.json clipboard.knit_* and rule_*.

uniform vec2 stitch = vec2(14.0, 10.0); // one stitch's width and height, in pixels
uniform float depth = 0.2; // how much darker the grooves between stitches are
uniform float rule_top = -1.0; // where the first written line starts; below 0, no rules
uniform float rule_bottom = 0.0; // the last rule sits at or above this
uniform float rule_px = 30.0; // one written line's height
uniform vec2 rule_span = vec2(0.0, 0.0); // the rules' left and right ends
uniform float rule_width = 2.0;
uniform float rule_dash = 10.0;
uniform vec4 rule_color : source_color = vec4(0.84, 0.69, 0.4, 0.5);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local / stitch;
	float u = fract(p.x) * 2.0 - 1.0;
	// Each stitch is two slanted legs meeting at the bottom: a V.
	float v = fract(p.y + abs(u) * 0.55);
	float d = length(vec2((abs(u) - 0.5) * 2.2, (v - 0.5) * 1.5));
	float shade = 1.0 - depth + depth * 1.2 * (1.0 - smoothstep(0.3, 1.0, d));
	vec4 c = COLOR;
	c.rgb *= shade;
	if (rule_top >= 0.0 && local.y > rule_top + rule_width && local.y <= rule_bottom
			&& local.x > rule_span.x && local.x < rule_span.y) {
		float y = mod(local.y - rule_top, rule_px);
		float on = step(rule_px - rule_width, y) * step(0.45, fract(local.x / rule_dash));
		c.rgb = mix(c.rgb, rule_color.rgb, on * rule_color.a);
	}
	COLOR = c;
}
