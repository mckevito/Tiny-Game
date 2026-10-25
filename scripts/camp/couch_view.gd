class_name CouchView
extends Node
## The couch camera, like modern LEGO games: one shared view while the two players on this PC are close, backing off
## a little to fit both. When they walk apart the screen splits along a line at right angles to the way between them,
## each half following its own player and leaning toward the other; walking back together merges it again. At the
## moment of the split both halves show the same picture, so the line grows in without a jump.
## Based on the idea of the Godot Foundation's Dynamic Split Screen Demo (MIT; CREDITS.md). Numbers: data/tuning.json
## "couch". The second view draws only while the screen is split, so a merged couch costs the same as one player;
## while split both halves use the preset's split_render_scale (data/graphics.json).

## The main play camera: player one's half, and the whole screen while merged.
var main: PlayCamera
## The two campers, player one first; empty when only one player is on this PC.
var players: Array[Camper] = []
## True while the screen is split.
var split := false

var _view := SubViewport.new()
var _camera := PlayCamera.new()
var _layer := CanvasLayer.new()
var _overlay := ColorRect.new()


static func _num(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "couch." + key, fallback)


func _ready() -> void:
	_view.name = "SecondView"
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	_camera.name = "SecondCamera"
	_camera.current = true
	_view.add_child(_camera)
	_layer.name = "Split"
	_layer.layer = 0
	add_child(_layer)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/camp/split.gdshader")
	mat.set_shader_parameter("view", _view.get_texture())
	mat.set_shader_parameter("seam_color", FeltBuilder.swatch(str(Tuning.value("tuning", "couch.seam_swatch", "warm_cream"))))
	_overlay.material = mat
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_layer.add_child(_overlay)


## Starts the shared view for two campers, or goes back to one player's camera with an empty list.
func follow(campers: Array[Camper]) -> void:
	players = campers
	if split:
		Quality.scale_views([get_viewport(), _view] as Array[Viewport], Quality.render_scale(false))
	split = false
	_overlay.visible = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if main == null:
		return
	_camera.leader = main if campers.size() == 2 else null
	if campers.size() < 2:
		main.aim = null
		main.extra_distance = 0.0
		return
	_camera.target = campers[1]
	_update(true)


## The second camera, for tests and the capture tool.
func second_camera() -> PlayCamera:
	return _camera


## The second view, so the picture preset (Quality) reaches it too.
func second_view() -> SubViewport:
	return _view


## Where each half looks: both at the middle while the players are within split_m, otherwise each at its own player
## pulled split_m / 2 toward the other. Returns [player one's aim, player two's aim].
static func aims(p1: Vector3, p2: Vector3, split_m: float) -> Array[Vector3]:
	var d := Vector3(p2.x - p1.x, 0.0, p2.z - p1.z)
	if d.length() <= split_m:
		var mid := (p1 + p2) * 0.5
		return [mid, mid]
	var lean := d.normalized() * split_m * 0.5
	return [p1 + lean, p2 - lean]


## The on-screen direction (pixels, y down) of a ground direction, for a camera turned by `yaw` and tilted by
## `pitch` (radians), like PlayCamera.
static func screen_dir(ground: Vector3, yaw: float, pitch: float) -> Vector2:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var away := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var v := Vector2(ground.dot(right), -ground.dot(away) * sin(pitch))
	return v.normalized() if v.length() > 0.0001 else Vector2.RIGHT


func _process(_delta: float) -> void:
	if players.size() == 2 and main:
		_update(false)


func _update(jump: bool) -> void:
	var p1 := players[0].global_position
	var p2 := players[1].global_position
	var split_m := _num("split_m", 7.0)
	var apart := Vector2(p2.x - p1.x, p2.z - p1.z).length()
	var both := aims(p1, p2, split_m)
	main.aim = both[0]
	_camera.aim = both[1]
	main.extra_distance = minf(apart, split_m) * _num("zoom_out_per_m", 0.3)
	if jump:
		_camera.yaw = main.yaw
		_camera.distance = main.distance
		_camera.extra_distance = main.extra_distance
		main.snap()
		_camera.snap()
	var was := split
	split = apart > split_m
	if split != was:
		_overlay.visible = split
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if split else SubViewport.UPDATE_DISABLED
		Quality.scale_views([get_viewport(), _view] as Array[Viewport], Quality.render_scale(split))
	if not split:
		return
	var size := Vector2(get_viewport().get_visible_rect().size)
	var window := get_window()
	if window and window.size.x > 0:
		size = Vector2(window.size)
	if Vector2(_view.size) != size:
		_view.size = Vector2i(size)
	var mat := _overlay.material as ShaderMaterial
	mat.set_shader_parameter("dir", screen_dir(p2 - p1, main.yaw, deg_to_rad(Tuning.num("tuning", "camera.pitch_deg", 42.0))))
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("seam_px", minf(apart - split_m, 1.0) * _num("seam_px", 6.0))
