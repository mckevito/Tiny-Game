class_name PlayCamera
extends Camera3D
## The elevated third-person play camera: follows a target, turns with camera_left/right, zooms within limits and
## dithers away trees that hide the target. Numbers: data/tuning.json "camera".

var target: Node3D
var yaw := 0.0
var distance := 11.0
var _want_distance := 11.0
var _focus := Vector3.ZERO
var _faders: Array[MeshInstance3D] = []
var _fade: Dictionary = {}


func _ready() -> void:
	fov = _num("fov_deg", 40.0)
	near = 0.1
	distance = _num("distance_m", 11.0)
	_want_distance = distance
	snap()


## Jumps straight to the target, without easing (on spawn and for screenshots).
func snap() -> void:
	if target:
		_focus = target.global_position
	_place()


func _num(key: String, fallback: float) -> float:
	return Tuning.num("tuning", "camera." + key, fallback)


## Meshes that fade when they hide the target (data/models.json "fade").
func set_faders(meshes: Array[MeshInstance3D]) -> void:
	_faders = meshes


func _process(delta: float) -> void:
	yaw += (Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")) \
			* deg_to_rad(_num("yaw_speed_deg_s", 90.0)) * delta
	if Input.is_action_just_pressed("zoom_in"):
		_want_distance -= _num("zoom_step_m", 1.0)
	if Input.is_action_just_pressed("zoom_out"):
		_want_distance += _num("zoom_step_m", 1.0)
	_want_distance = clampf(_want_distance, _num("min_distance_m", 7.0), _num("max_distance_m", 15.0))
	distance = lerpf(distance, _want_distance, 1.0 - exp(-_num("zoom_rate", 8.0) * delta))
	if target:
		_focus = _focus.lerp(target.global_position, 1.0 - exp(-_num("follow_rate", 6.0) * delta))
	_place()
	_update_fades(delta)


## Puts the camera at its pitch, yaw and distance from the focus point.
func _place() -> void:
	var pitch := deg_to_rad(_num("pitch_deg", 42.0))
	var look_at_point := _focus + Vector3(0, _num("target_height_m", 0.7), 0)
	var offset := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw) * distance
	global_position = look_at_point + offset
	look_at(look_at_point)


## True when a vertical column at `base` (radius `r`, height `h`) stands between the camera and the target.
func hides_target(base: Vector3, r: float, h: float) -> bool:
	if target == null:
		return false
	var aim := target.global_position + Vector3(0, _num("target_height_m", 0.7), 0)
	return column_hides(global_position, aim, base, r, h)


## True when the sight line from `eye` to `aim` passes within `r` of a column at `base` that is `h` tall,
## before it reaches `aim`.
static func column_hides(eye: Vector3, aim: Vector3, base: Vector3, r: float, h: float) -> bool:
	var seg := Vector2(aim.x - eye.x, aim.z - eye.z)
	var len2 := seg.length_squared()
	if len2 < 0.0001:
		return false
	var t := clampf(Vector2(base.x - eye.x, base.z - eye.z).dot(seg) / len2, 0.0, 1.0)
	if t >= 0.999:
		return false
	var closest := Vector2(eye.x, eye.z) + seg * t
	var height := lerpf(eye.y, aim.y, t)
	return closest.distance_to(Vector2(base.x, base.z)) < r and height < base.y + h


func _update_fades(delta: float) -> void:
	var r := _num("fade_radius_m", 1.6)
	var rate := 1.0 - exp(-_num("fade_rate", 6.0) * delta)
	for m in _faders:
		var h := m.get_aabb().end.y
		var want := _num("fade_amount", 0.6) if hides_target(m.global_position, r, h) else 0.0
		var now: float = lerpf(_fade.get(m, 0.0), want, rate)
		_fade[m] = now
		m.set_instance_shader_parameter("fade", now)
