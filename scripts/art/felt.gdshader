shader_type spatial;
// The one shared felt material (docs/PLAN.md art direction). Colour comes from the vertex colour, which the builder
// paints from data/palette.json; vertex alpha below 1 marks glowing parts (1 - alpha = glow). Every value is set from
// data/art.json "felt" by FeltBuilder.
render_mode diffuse_lambert_wrap, specular_disabled;

uniform float noise_scale = 3.5;
uniform float noise_strength = 0.16;
uniform float grain_scale = 55.0;
uniform float grain_strength = 0.08;
uniform float fuzz_strength = 0.35;
uniform float rim = 0.35;
uniform float rim_tint = 0.6;
uniform float glow_strength = 2.0;
uniform float sway_amount = 0.0;
uniform float sway_speed = 0.9;
uniform float sway_height = 3.0;
// 0 = solid, 1 = gone. The play camera raises it on trees that hide a player; it dithers, so no sorting is needed.
instance uniform float fade = 0.0;

varying vec3 obj_pos;

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

void vertex() {
	obj_pos = VERTEX;
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
	float n = noise3(obj_pos * noise_scale) * 0.6 + noise3(obj_pos * noise_scale * 2.3) * 0.4;
	float g = noise3(obj_pos * grain_scale);
	vec3 base = COLOR.rgb * (1.0 + (n - 0.5) * noise_strength + (g - 0.5) * grain_strength);
	// Soft fuzz: edges facing away from the camera go a touch lighter, like felt fibres catching light.
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(base, base * 1.25 + vec3(0.02), edge * edge * fuzz_strength);
	ROUGHNESS = 1.0;
	RIM = rim;
	RIM_TINT = rim_tint;
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * glow_strength;
}
