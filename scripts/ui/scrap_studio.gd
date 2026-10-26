class_name ScrapStudio
extends Node
## Draws a model once into a small picture for the scrapbook (a page with no snapshot: tools, builds, finds, and an
## animal not photographed yet): its own little world with a camera at a three-quarter angle fitted to the model, and
## a sun. Each picture is drawn once and kept. Sizes and angles: data/scrapbook.json book.studio.

var _shots := {}
var _tokens := {}


static func _n(key: String, fallback: float) -> float:
	return Tuning.num("scrapbook", "book.studio." + key, fallback)


## The picture of a model, drawn the first time it is asked for (null for no model).
func picture(model: String) -> Texture2D:
	if model == "":
		return null
	if _shots.has(model):
		return (_shots[model] as SubViewport).get_texture()
	var size: Array = Tuning.value("scrapbook", "book.studio.size_px", [256, 192])
	var view := SubViewport.new()
	view.name = "Shot_" + model
	view.size = Vector2i(int(size[0]), int(size[1]))
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	var body := FeltBuilder.build(model)
	view.add_child(body)
	var box := body.get_aabb()
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.05)
	var cam := Camera3D.new()
	cam.fov = _n("fov_deg", 30.0)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, deg_to_rad(_n("pitch_deg", -22.0))) \
			.rotated(Vector3.UP, deg_to_rad(_n("yaw_deg", 35.0)))
	var back := radius * _n("fill", 1.25) / sin(deg_to_rad(cam.fov * 0.5))
	view.add_child(cam)
	cam.position = centre + dir * back
	cam.look_at(centre)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	view.add_child(sun)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_CLEAR_COLOR
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color(1, 1, 1)
	sky.environment.ambient_light_energy = 0.6
	view.add_child(sky)
	_shots[model] = view
	return view.get_texture()


## A round felt token in a swatch, for a page with no model (the fish and meals), like the Pack's slots.
func token(swatch: String) -> Texture2D:
	if _tokens.has(swatch):
		return _tokens[swatch]
	var size: Array = Tuning.value("scrapbook", "book.studio.size_px", [256, 192])
	var image := Image.create(int(size[0]), int(size[1]), false, Image.FORMAT_RGBA8)
	var middle := Vector2(image.get_size()) * 0.5
	var radius := minf(middle.x, middle.y) * 0.6
	var colour := FeltBuilder.swatch(swatch).linear_to_srgb()
	for y in image.get_height():
		for x in image.get_width():
			var d := Vector2(x, y).distance_to(middle)
			if d <= radius:
				image.set_pixel(x, y, colour.darkened(0.25) if d > radius - 6.0 else colour)
	_tokens[swatch] = ImageTexture.create_from_image(image)
	return _tokens[swatch]
