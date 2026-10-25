class_name Quality
extends RefCounted
## Picture presets from data/graphics.json: the 3D render scale (upscaled with FSR below 1), FXAA, ambient occlusion,
## glow and sun shadows. "low" keeps the weakest PC at 30 fps or more, couch split screen included.

## The preset in use, so the couch view can pick its split render scale.
static var current := ""


static func names() -> Array:
	return Tuning.value("graphics", "order", ["normal"])


static func preset(name: String) -> Dictionary:
	var row: Variant = Tuning.value("graphics", "presets." + name)
	return row if row is Dictionary else Tuning.value("graphics", "presets." + str(names()[0]), {})


## The next preset after `name`, for the menu button.
static func next(name: String) -> String:
	var all := names()
	return str(all[(all.find(name) + 1) % all.size()])


## The 3D render scale for the current preset, smaller while the couch screen is split.
static func render_scale(split: bool) -> float:
	return float(preset(current).get("split_render_scale" if split else "render_scale", 1.0))


## Draws the given views at a render scale, upscaled with FSR when below 1.
static func scale_views(views: Array[Viewport], scale: float) -> void:
	for view in views:
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		view.scaling_3d_scale = scale


## Applies a preset to the views that draw the world, the environment (after its light mood) and the sun.
static func apply(name: String, views: Array[Viewport], env: Environment, sun: DirectionalLight3D, split := false) -> void:
	current = name
	var q := preset(name)
	scale_views(views, render_scale(split))
	for view in views:
		view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(q.get("fxaa", false)) else Viewport.SCREEN_SPACE_AA_DISABLED
	env.ssao_enabled = bool(q.get("ssao", true))
	env.glow_enabled = env.glow_enabled and bool(q.get("glow", true))
	var splits := int(q.get("shadow_splits", 4))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if splits <= 1 \
			else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if splits == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	sun.directional_shadow_max_distance = float(q.get("shadow_distance_m", 40.0))
	RenderingServer.directional_shadow_atlas_set_size(int(q.get("shadow_atlas_px", 4096)), true)
