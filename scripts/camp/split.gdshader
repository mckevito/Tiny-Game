shader_type canvas_item;
// The couch split screen (CouchView): draws the second player's view on their side of a line through the middle of
// the screen, at right angles to the direction between the players. Player one's side stays see-through, so the main
// view shows. Numbers come from data/tuning.json "couch".

uniform sampler2D view : filter_linear;
// Screen direction from player one toward player two, in pixels (y down), normalized.
uniform vec2 dir = vec2(1.0, 0.0);
// The screen size in pixels, so the line keeps its angle on any window shape.
uniform vec2 size = vec2(1920.0, 1080.0);
uniform float seam_px = 0.0;
uniform vec4 seam_color = vec4(0.93, 0.89, 0.8, 1.0);

void fragment() {
	float side = dot((UV - 0.5) * size, dir);
	if (side < -seam_px * 0.5) {
		COLOR = vec4(0.0);
	} else if (side < seam_px * 0.5) {
		COLOR = seam_color;
	} else {
		COLOR = vec4(texture(view, UV).rgb, 1.0);
	}
}
