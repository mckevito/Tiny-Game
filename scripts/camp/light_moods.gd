class_name LightMoods
extends RefCounted
## Applies a lighting mood from data/lighting.json to the sun, the environment and the fire lights.


static func names() -> Array:
	return Tuning.table("lighting").get("order", [])


static func apply(mood: String, sun: DirectionalLight3D, env: Environment, fires: Array[OmniLight3D]) -> void:
	var m: Dictionary = Tuning.value("lighting", "moods." + mood, {})
	sun.light_color = Color.html(str(m.get("sun_color", "#FFFFFF")))
	sun.light_energy = float(m.get("sun_energy", 1.0))
	sun.rotation = Vector3(-deg_to_rad(float(m.get("sun_elevation_deg", 45.0))),
			deg_to_rad(float(m.get("sun_azimuth_deg", 0.0))), 0.0)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(str(m.get("background", "#808080")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(str(m.get("ambient_color", "#FFFFFF")))
	env.ambient_light_energy = float(m.get("ambient_energy", 0.5))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(m.get("exposure", 1.0))
	env.glow_enabled = bool(m.get("glow", false))
	env.ssao_enabled = true
	for light in fires:
		light.light_color = Color.html(str(m.get("fire_color", "#FFAA55")))
		light.light_energy = float(m.get("fire_energy", 1.0))
		light.omni_range = float(m.get("fire_range_m", 4.0))
		light.set_meta("base_energy", light.light_energy)


## Sets the light between two moods: `t` 0 is mood `a`, 1 is mood `b`. Colours, strengths and the sun's angle
## blend; glow follows the nearer mood and the picture preset (data/graphics.json). Ambient occlusion is left to the
## preset. Used by the day clock (data/day.json "light").
static func blend(a: String, b: String, t: float, sun: DirectionalLight3D, env: Environment,
		fires: Array[OmniLight3D]) -> void:
	var ma: Dictionary = Tuning.value("lighting", "moods." + a, {})
	var mb: Dictionary = Tuning.value("lighting", "moods." + b, {})
	var col := func(key: String, fallback: String) -> Color:
		return Color.html(str(ma.get(key, fallback))).lerp(Color.html(str(mb.get(key, fallback))), t)
	var num := func(key: String, fallback: float) -> float:
		return lerpf(float(ma.get(key, fallback)), float(mb.get(key, fallback)), t)
	sun.light_color = col.call("sun_color", "#FFFFFF")
	sun.light_energy = num.call("sun_energy", 1.0)
	sun.rotation = Vector3(-deg_to_rad(num.call("sun_elevation_deg", 45.0)), deg_to_rad(num.call("sun_azimuth_deg", 0.0)), 0.0)
	env.background_color = col.call("background", "#808080")
	env.ambient_light_color = col.call("ambient_color", "#FFFFFF")
	env.ambient_light_energy = num.call("ambient_energy", 0.5)
	env.tonemap_exposure = num.call("exposure", 1.0)
	env.glow_enabled = bool((mb if t >= 0.5 else ma).get("glow", false)) \
			and bool(Quality.preset(Quality.current).get("glow", true))
	for light in fires:
		light.light_color = col.call("fire_color", "#FFAA55")
		light.light_energy = num.call("fire_energy", 1.0)
		light.omni_range = num.call("fire_range_m", 4.0)
		light.set_meta("base_energy", light.light_energy)
