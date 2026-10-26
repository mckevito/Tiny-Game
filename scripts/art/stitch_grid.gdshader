shader_type spatial;
// The build grid while placing: running stitches along the camp's cell lines, fading out round the builder's spot.
// Numbers come from data/build.json grid_view (set in scripts/camp/camp.gd).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color = vec3(1.0);
uniform float alpha = 0.7;
uniform float cell = 1.0;
uniform vec2 origin = vec2(0.0);
uniform float line_m = 0.05;
uniform float stitches_per_m = 5.0;
uniform float dash = 0.6;
uniform float radius_m = 4.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Lines run between cells: cells are centred on grid points, so the lines sit half a cell off them.
	vec2 p = (world.xz - origin) / cell + 0.5;
	vec2 off = abs(p - round(p)) * cell;
	vec2 on_line = 1.0 - smoothstep(line_m * 0.35, line_m * 0.5, off);
	vec2 run = step(fract(world.zx * stitches_per_m), vec2(dash));
	float a = max(on_line.x * run.x, on_line.y * run.y);
	float fade = 1.0 - smoothstep(radius_m * 0.55, radius_m, distance(world.xz, NODE_POSITION_WORLD.xz));
	ALBEDO = color;
	ALPHA = a * fade * alpha;
}
