shader_type spatial;
// The one shared wool material (docs/PLAN.md art direction). Colour comes from the vertex colour, which the builder
// paints from data/palette.json; vertex alpha below 1 marks glowing parts (1 - alpha = glow). UV.x picks the weave a
// part is made of (data/art.json "weaves": 0 felt, 1 knit, 2 wood, 3 water, 4 grass, 5 knit_map, 6 rib_map, 7 yarn,
// 8 bead), so one material still draws everything. knit_map and rib_map read the model's own stitch map from UV2
// (column, row), so each V stitch runs along its column on a sculpted model; yarn reads UV2 as (round the strand in
// plies, along it in twists) and draws twisted plies; bead is smooth (button eyes): no fibres, fuzz or ragged edge.
// Every value is set from data/art.json "felt" by FeltBuilder.
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
// Stitch-mapped knit (UV2): a stitch's width over its height, a loop's half-thickness (in rows), how far a rib's
// stitches squeeze onto its ridge and how dark its grooves go, the plies' light and dark, and how much stitches vary.
uniform float stitch_aspect = 1.4;
uniform float stitch_width = 0.25;
uniform float rib_narrow = 0.78;
uniform float rib_shade = 0.35;
uniform float rib_groove = 0.22;
uniform float ply_strength = 0.1;
uniform float stitch_vary = 0.08;
// Yarn strands (curls): how dark the twist between two plies goes.
uniform float yarn_shade = 0.4;
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

// One leg of a V stitch: a yarn loop leaning out from near the column's middle at the bottom to near its edge at
// the top, a little longer than a row so it tucks under the next stitch up. It stops short of the middle and the
// edge, so a dark line runs up between a V's two legs and between columns, as on knitted wool (wheat ears). q.x runs
// out from the column's middle and q.y up from the stitch's bottom, both in rows. Returns the yarn's height 0..1;
// `ply` the twisted plies' light and dark.
float stitch_leg(vec2 q, out float ply) {
	vec2 a = vec2(0.12 * stitch_aspect, 0.02);
	vec2 b = vec2(0.365 * stitch_aspect, 1.16);
	vec2 ab = b - a;
	float s = clamp(dot(q - a, ab) / dot(ab, ab), 0.0, 1.0);
	vec2 off = q - (a + ab * s);
	float r = stitch_width * (0.7 + 0.3 * sin(3.14159 * s));
	float d = length(off) / r;
	float across = (off.x * ab.y - off.y * ab.x) / (length(ab) * r);
	ply = cos(6.2832 * (s * 2.6 + across * 0.6));
	return sqrt(max(1.0 - d * d, 0.0));
}

// A V stitch in a model's own stitch map (UV2: x counts columns, y counts rows up the column): two slanted loops
// meeting at the bottom, stacked up the column like a braid, as stockinette looks. The stitches above and below
// reach into this one, so the front-most loop wins. Returns the yarn's height 0..1 (0 between loops). `narrow` < 1
// squeezes the V onto the middle of its column (a rib's knit column standing on its ridge). A model's stitch map may
// make its rows shorter than stitch_aspect says, which squashes the V's and leans their legs out further.
float stitch_v(vec2 uv, float narrow, out float ply) {
	vec2 c = fract(uv);
	float x = abs(c.x - 0.5) / narrow * stitch_aspect;
	float best = 0.0;
	ply = 0.0;
	for (int k = -1; k <= 1; k++) {
		float p;
		float h = stitch_leg(vec2(x, c.y - float(k)), p);
		if (h > best) {
			best = h;
			ply = p;
		}
	}
	return best;
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
	int kind = int(weave + 0.5);
	if (shell > 0.0) {
		// Only fibre tips survive on a shell: a random few cells, fewer the farther out the shell sits.
		if (COLOR.a < 0.99 || kind == 8 || hash3(floor(obj_pos * strand_scale)) > shell_keep / shell) {
			discard;
		}
	}
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
	if (hair_edge > 0.0 && edge > 1.0 - hair_edge && COLOR.a > 0.99 && kind != 8) {
		if (fibre * 1.6 < (edge - (1.0 - hair_edge)) / hair_edge) {
			discard;
		}
	}
	float shade = 1.0 + (n - 0.5) * noise_strength + (g - 0.5) * grain_strength + (fibre - 0.35) * fibre_strength;
	float h = fibre + n * 0.5;
	float bump = bump_strength * near;
	vec3 tint = vec3(1.0);
	if (kind == 1) {
		float k = knit3(obj_pos * knit_scale, normalize(obj_normal));
		shade *= mix(1.0 - knit_depth, 1.05, k);
		h = k * (knit_bump / max(bump_strength, 0.0001)) + fibre * 0.5;
	} else if (kind == 5 || kind == 6) {
		float rib = float(kind == 6);
		// A stitch a few pixels across only shimmers: fade it to an even knit.
		float near_st = clamp(1.5 - length(fwidth(stitch_uv)) * 4.0, 0.0, 1.0);
		float ply;
		float k = stitch_v(stitch_uv, mix(1.0, rib_narrow, rib), ply);
		float groove = rib * smoothstep(0.5 - rib_groove, 0.5, abs(fract(stitch_uv.x) - 0.5));
		k = mix(0.55, k, near_st);
		shade *= mix(1.0 - knit_depth, 1.06, k) * (1.0 - groove * rib_shade);
		shade *= 1.0 + (ply * ply_strength * k + (hash3(vec3(floor(stitch_uv), 3.0)) - 0.5) * stitch_vary) * near_st;
		h = k * (knit_bump / max(bump_strength, 0.0001)) + fibre * 0.5;
	} else if (kind == 7) {
		// Two or more plies twisting round the strand: each ply a round cord, dark where it meets the next.
		float near_st = clamp(1.5 - length(fwidth(stitch_uv)) * 4.0, 0.0, 1.0);
		float k = mix(0.65, sin(3.14159 * fract(stitch_uv.x + stitch_uv.y)), near_st);
		shade *= mix(1.0 - yarn_shade, 1.08, k);
		h = k * (knit_bump / max(bump_strength, 0.0001)) + fibre * 0.5;
	} else if (kind == 8) {
		shade = 1.0 + (n - 0.5) * 0.04;
		h = 0.0;
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
