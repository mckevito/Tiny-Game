shader_type spatial;
// The one shared wool material (docs/PLAN.md art direction). Colour comes from the vertex colour, which the builder
// paints from data/palette.json; vertex alpha below 1 marks glowing parts (1 - alpha = glow). UV.x picks the weave a
// part is made of (data/art.json "weaves": 0 felt, 1 knit, 2 wood, 3 water, 4 grass, 5 knit_rows), so one material
// still draws everything. knit_rows is knitting whose stitch column and row are in UV2 (models sculpted outside the
// game, such as the knit camper), so the stitches follow its ribs and rows instead of facing the three axes. Every value is set from data/art.json "felt" by FeltBuilder.
render_mode diffuse_lambert_wrap, specular_disabled;

uniform float noise_scale = 3.5;
uniform float noise_strength = 0.16;
uniform float grain_scale = 55.0;
uniform float grain_strength = 0.08;
uniform float fuzz_strength = 0.35;
// Felt fibres: fine stretched noise that darkens the colour in flecks and bumps the normal (screen-space slopes, so
// no texture). 0 turns either off.
uniform float fibre_scale = 60.0;
uniform float fibre_strength = 0.0;
uniform float bump_strength = 0.0;
// Ragged edges: where a surface turns away from the camera, fibres are cut out so outlines look hairy.
uniform float hair_edge = 0.0;
// Knitted parts: stitches per metre, how dark the gaps between stitches are, and how far they stand out.
uniform float knit_scale = 26.0;
uniform float knit_depth = 0.45;
uniform float knit_bump = 0.006;
// knit_rows only: how dark the groove between two stitch columns (a rib's edge) is.
uniform float knit_rib_dark = 0.0;
// Wood: grain lines per metre along the part's length and how dark they are.
uniform float wood_scale = 7.0;
uniform float wood_strength = 0.35;
// Water: wavy lighter strands per metre and how light.
uniform float water_scale = 3.0;
uniform float water_strength = 0.35;
// Grass felt: how far the colour wanders toward yellow and toward shade, in patches and in single fibres.
uniform float grass_tint = 0.35;
uniform vec3 grass_light = vec3(1.18, 1.08, 0.7);
uniform vec3 grass_dark = vec3(0.62, 0.7, 0.52);
// Fuzz shells: the same mesh drawn again a hair bigger, keeping only scattered fibre tips, so every edge looks
// fuzzy like real felt. shell 0 is the solid model; 1 and up are the shells (FeltBuilder chains them as next passes).
uniform float shell = 0.0;
uniform float shell_height = 0.006;
uniform float shell_keep = 0.4;
uniform float strand_scale = 260.0;
// A finer second layer of fibres that shows only close up, for the macro-photo look.
uniform float fine_scale = 220.0;
uniform float fine_strength = 0.3;
uniform float rim = 0.35;
uniform float rim_tint = 0.6;
uniform float glow_strength = 2.0;
uniform float sway_amount = 0.0;
uniform float sway_speed = 0.9;
uniform float sway_height = 3.0;
// 0 = solid, 1 = gone. The play camera raises it on trees that hide a player; it dithers, so no sorting is needed.
instance uniform float fade = 0.0;

varying vec3 obj_pos;
varying vec3 obj_normal;
varying flat float weave;
varying vec2 stitch_uv;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// One knitted stitch cell: two slanted loops side by side make the V of stockinette. 1 on a loop, 0 in the gaps.
float knit2(vec2 uv) {
	vec2 c = fract(uv * vec2(1.0, 1.4));
	float side = c.x < 0.5 ? 1.0 : -1.0;
	vec2 q = vec2(fract(c.x * 2.0) - 0.5, c.y - 0.5);
	q = mat2(vec2(0.82, side * 0.57), vec2(-side * 0.57, 0.82)) * q;
	float d = length(q * vec2(2.6, 1.15));
	return smoothstep(0.62, 0.18, d);
}

// The knit seen from three sides, blended by the surface's facing (object space, so it moves with the model).
float knit3(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return knit2(p.zy) * w.x + knit2(p.xz) * w.y + knit2(p.xy) * w.z;
}

void vertex() {
	if (shell > 0.0) {
		VERTEX += NORMAL * shell_height * shell;
	}
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	weave = UV.x;
	stitch_uv = UV2;
	if (sway_amount > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(world.y - NODE_POSITION_WORLD.y, 0.0) / sway_height;
		float phase = NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.4;
		vec3 offset = vec3(sin(TIME * sway_speed + phase), 0.0, cos(TIME * sway_speed * 0.8 + phase)) * sway_amount * h * h;
		VERTEX += transpose(mat3(MODEL_MATRIX)) * offset;
	}
}

void fragment() {
	if (fade > 0.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int i = p.x + p.y * 4;
		float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if ((bayer[i] + 0.5) / 16.0 < fade) {
			discard;
		}
	}
	if (shell > 0.0) {
		// Only fibre tips survive on a shell: a random few cells, fewer the farther out the shell sits.
		if (COLOR.a < 0.99 || hash3(floor(obj_pos * strand_scale)) > shell_keep / shell) {
			discard;
		}
	}
	int kind = int(weave + 0.5);
	float n = noise3(obj_pos * noise_scale) * 0.6 + noise3(obj_pos * noise_scale * 2.3) * 0.4;
	float g = noise3(obj_pos * grain_scale);
	// Fibres run in no one direction: two stretched noises at an angle, kept as the darker of the two.
	float f1 = noise3(obj_pos * vec3(fibre_scale, fibre_scale * 0.3, fibre_scale));
	float f2 = noise3(obj_pos.zyx * vec3(fibre_scale * 0.3, fibre_scale, fibre_scale) + 7.0);
	float fibre = min(f1, f2);
	// Far away a fibre is smaller than a pixel and only sparkles: fade it (and its bump) to an even felt.
	float near = clamp(1.5 - length(fwidth(obj_pos)) * fibre_scale, 0.0, 1.0);
	fibre = mix(0.42, fibre, near);
	float near_fine = clamp(1.5 - length(fwidth(obj_pos)) * fine_scale, 0.0, 1.0);
	fibre = mix(fibre, fibre * (0.7 + 0.6 * noise3(obj_pos * vec3(fine_scale, fine_scale * 0.4, fine_scale))), fine_strength * near_fine);
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (hair_edge > 0.0 && edge > 1.0 - hair_edge && COLOR.a > 0.99) {
		if (fibre * 1.6 < (edge - (1.0 - hair_edge)) / hair_edge) {
			discard;
		}
	}
	float shade = 1.0 + (n - 0.5) * noise_strength + (g - 0.5) * grain_strength + (fibre - 0.35) * fibre_strength;
	float h = fibre + n * 0.5;
	float bump = bump_strength * near;
	vec3 tint = vec3(1.0);
	if (kind == 1 || kind == 5) {
		float k = kind == 1 ? knit3(obj_pos * knit_scale, normalize(obj_normal)) : knit2(stitch_uv);
		shade *= mix(1.0 - knit_depth, 1.05, k);
		if (kind == 5) {
			shade *= 1.0 - knit_rib_dark * smoothstep(0.6, 1.0, abs(fract(stitch_uv.x) - 0.5) * 2.0);
		}
		h = k * (knit_bump / max(bump_strength, 0.0001)) + fibre * 0.5;
	} else if (kind == 2) {
		// Grain lines run along X (planks, benches and logs are laid along X): across Z on top, across Y on the sides.
		float across = abs(obj_normal.y) > 0.5 ? obj_pos.z : obj_pos.y;
		float line = sin((across + noise3(obj_pos * vec3(0.8, 3.0, 3.0)) * 0.12) * wood_scale * 6.2832);
		shade *= 1.0 - wood_strength * smoothstep(0.6, 1.0, line);
	} else if (kind == 3) {
		float wave = sin((obj_pos.x + sin(obj_pos.z * 2.1) * 0.25 + n * 0.5) * water_scale * 6.2832);
		tint = vec3(1.0) + vec3(0.25, 0.3, 0.35) * water_strength * smoothstep(0.75, 1.0, wave);
		shade *= 1.0 + (fibre - 0.35) * 0.2;
	} else if (kind == 4) {
		float patch = noise3(obj_pos * 0.45) * 0.7 + n * 0.3;
		tint = mix(grass_dark, grass_light, smoothstep(0.3, 0.75, patch));
		tint = mix(tint, mix(grass_dark, grass_light, step(0.5, g)), grass_tint * smoothstep(0.25, 0.6, fibre));
		bump *= 1.6;
	}
	vec3 base = COLOR.rgb * shade * tint;
	if (bump > 0.0) {
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		float hb = h * bump;
		vec3 grad = sign(det) * (dFdx(hb) * r1 + dFdy(hb) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}
	// Soft fuzz: edges facing away from the camera go a touch lighter, like felt fibres catching light.
	ALBEDO = mix(base, base * 1.25 + vec3(0.02), edge * edge * fuzz_strength) * (1.0 + shell * 0.06);
	ROUGHNESS = 1.0;
	RIM = rim;
	RIM_TINT = rim_tint;
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * glow_strength;
}
