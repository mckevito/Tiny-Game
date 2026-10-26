class_name Camper
extends CharacterBody3D
## A felt camper. The controlled one walks relative to the play camera with either input method. A remote one (the
## other PC's player) glides to the last place it was told; both waddle and bob as they walk.
## Numbers: data/tuning.json "movement" and "camper", data/net.json for the remote smoothing.

@export var model_id := "camper_a"
@export var controlled := false
## The camera whose yaw makes "forward" mean "away from the camera".
var camera: Node3D
## The player's name, shown above the camper (names as well as colours: the accessibility baseline).
var display_name := ""
## Where a remote camper should be, in its parent's space; null for a camper nobody steers from afar.
var remote_target: Variant = null
var remote_yaw := 0.0
## The devices this camper listens to on a shared PC (couch play); null reads every device.
var input: PlayerInput
## A visiting guest walks here at `walk_speed` (data/day.json stays.walk_speed_mps), in its parent's space, then on
## through `_path` (walk_along), then emits `arrived`; null when it is not walking anywhere.
var walk_target: Variant = null
var walk_speed := 1.5
## A player's walking pace as a share of the usual (a long log carried alone is slow; CampGather.carry_speed).
var speed_scale := 1.0

## The tool shown in the camper's mitten (data/items.json tools.order; "hands" shows none), or "clipboard" while
## the player reads their clipboard (held up in front of the chest).
var held := "hands"

signal arrived

var _body: Node3D
var _tool: Node3D
var _walk_phase := 0.0
## A swing of the tool in hand: seconds into it (-1 when still) and its wind-up time.
var _swing := -1.0
var _wind := 0.0
## How high a sitting guest's body is lifted onto its seat (0 standing), and the clock for a held model's sway.
var _sit_y := 0.0
var _sway_t := 0.0
## The standing look while a sitting pose is shown, or "" (sit).
var _stand_id := ""
## The rest of a guest's walk after walk_target, and whether it takes the last leg backwards (onto a seat).
var _path: Array[Vector3] = []
var _back_in := false


## Swaps the camper's model for another look of the same body, such as a talking pose (data/ranger.json talk_model).
func set_look(id: String) -> void:
	model_id = id
	if _body is MeshInstance3D:
		(_body as MeshInstance3D).mesh = FeltBuilder.mesh(id)


func _ready() -> void:
	_body = FeltBuilder.build(model_id)
	add_child(_body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Tuning.num("tuning", "movement.collider_radius_m", 0.3)
	capsule.height = Tuning.num("tuning", "movement.collider_height_m", 1.2)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	if display_name != "":
		var label := Label3D.new()
		label.name = "Name"
		label.text = display_name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = Tuning.num("tuning", "camper.name_height_m", 1.75)
		label.font_size = int(Tuning.num("tuning", "camper.name_font_px", 48))
		label.outline_size = int(Tuning.num("tuning", "camper.name_outline_px", 12))
		label.pixel_size = 0.004
		label.no_depth_test = true
		add_child(label)


## Shows a tool in the camper's mitten: its model and turn come from data/items.json tools.held, the grip from
## data/tuning.json camper.hand_pos and tool_scale.
func hold(tool: String) -> void:
	if tool == held or _body == null:
		return
	held = tool
	if _tool:
		_tool.queue_free()
		_tool = null
	var row: Dictionary = Tuning.value("items", "tools.held." + tool, {})
	if row.is_empty():
		return
	_tool = FeltBuilder.build(str(row["model"]))
	_tool.name = "Tool"
	_tool.position = FeltBuilder.vec3(row.get("pos", Tuning.value("tuning", "camper.hand_pos")))
	_tool.rotation_degrees = FeltBuilder.vec3(row.get("rot", [0, 0, 0]))
	_tool.scale = Vector3.ONE * Tuning.num("tuning", "camper.tool_scale", 1.0)
	_body.add_child(_tool)


## Swings the tool in hand (data/items.json tools.held.<tool>.swing): it winds back over `wind_s`, strikes, then
## settles, while the body leans into the strike. Anyone can see it; it changes nothing in the camp.
func swing(wind_s: float) -> void:
	if _tool == null:
		return
	_swing = 0.0
	_wind = maxf(wind_s, 0.12)


## True while a swing is playing.
func swinging() -> bool:
	return _swing >= 0.0


## Sits a guest down with its body lifted `height` metres onto a seat, or stands it up again with 0. A look with a
## sitting pose (data/models.json "sit_model") swaps to it while seated, legs out in front instead of through the seat.
## A guest (steered by nobody) stays put between walks: nothing pushes it off its seat or its spot.
func sit(height: float) -> void:
	_sit_y = maxf(height, 0.0)
	if _sit_y > 0.0 and _stand_id == "":
		var seated := str(FeltBuilder.resolve(model_id).get("sit_model", ""))
		if seated != "":
			_stand_id = model_id
			set_look(seated)
	elif _sit_y == 0.0 and _stand_id != "":
		set_look(_stand_id)
		_stand_id = ""
	if _body:
		_body.position.y = _sit_y


func sitting() -> bool:
	return _sit_y > 0.0


## Walks a guest through `points` (Vector3, in its parent's space) one after another, then emits `arrived`. With
## `back_in`, the last leg is taken backwards, facing away from where it goes, as when sitting down on a seat.
func walk_along(points: Array, back_in := false) -> void:
	_path.clear()
	for p: Vector3 in points:
		_path.append(p)
	_back_in = back_in
	walk_target = _path.pop_front() if not _path.is_empty() else null


## Where the current walk ends, or null when there is none.
func walk_end() -> Variant:
	if not walk_target is Vector3:
		return null
	return _path.back() if not _path.is_empty() else walk_target


## Jumps to the end of the current walk (a test or a capture skipping ahead); `arrived` still comes on the next step.
func skip_walk() -> void:
	var end: Variant = walk_end()
	if end is Vector3:
		_path.clear()
		position = end
		walk_target = end


func _process(delta: float) -> void:
	if _swing < 0.0:
		_sway(delta)
		return
	var row: Dictionary = Tuning.value("items", "tools.held.%s.swing" % held, {})
	if _tool == null or row.is_empty():
		_swing = -1.0
		return
	_swing += delta
	var wind := float(row.get("wind_deg", 60))
	var strike := float(row.get("strike_deg", -50))
	var lean := float(row.get("lean_deg", 8))
	var strike_s := maxf(float(row.get("strike_s", 0.1)), 0.01)
	var settle_s := maxf(float(row.get("settle_s", 0.25)), 0.01)
	var turn := 0.0
	var bend := 0.0
	if _swing < _wind:
		var k := smoothstep(0.0, 1.0, _swing / _wind)
		turn = wind * k
		bend = -0.3 * lean * k
	elif _swing < _wind + strike_s:
		var k := (_swing - _wind) / strike_s
		turn = lerpf(wind, strike, k * k)
		bend = lerpf(-0.3 * lean, lean, k)
	elif _swing < _wind + strike_s + settle_s:
		var k := smoothstep(0.0, 1.0, (_swing - _wind - strike_s) / settle_s)
		turn = lerpf(strike, 0.0, k)
		bend = lerpf(lean, 0.0, k)
	else:
		_swing = -1.0
	var rest: Array = Tuning.value("items", "tools.held.%s.rot" % held, [0, 0, 0])
	_tool.rotation_degrees.x = float(rest[0]) + turn
	_body.rotation.x = deg_to_rad(-bend)


## Rocks a held model with a sway row (data/items.json tools.held.<tool>.sway), such as a guest's kite on the wind.
func _sway(delta: float) -> void:
	var row: Dictionary = Tuning.value("items", "tools.held.%s.sway" % held, {})
	if _tool == null or row.is_empty():
		return
	_sway_t += delta * TAU * float(row.get("hz", 0.2))
	var deg: Array = row.get("deg", [0, 0])
	var rest: Array = Tuning.value("items", "tools.held.%s.rot" % held, [0, 0, 0])
	_tool.rotation_degrees.x = float(rest[0]) + sin(_sway_t) * float(deg[0])
	_tool.rotation_degrees.z = float(rest[2]) + sin(_sway_t * 0.63 + 1.0) * float(deg[1])


## The wanted ground velocity for a stick or key input, turned by the camera's yaw.
static func wish_velocity(input: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw) * Tuning.num("tuning", "movement.walk_speed_mps")


func _physics_process(delta: float) -> void:
	if not controlled and remote_target is Vector3:
		_glide(delta)
		return
	if walk_target is Vector3:
		_walk(delta)
		return
	if sitting() or (not controlled and remote_target == null):
		return
	var stick := Vector2.ZERO
	if controlled:
		stick = input.move() if input else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target := wish_velocity(stick, camera.global_rotation.y if camera else 0.0) * speed_scale
	var accel := Tuning.num("tuning", "movement.acceleration_mps2") * delta
	velocity.x = move_toward(velocity.x, target.x, accel)
	velocity.z = move_toward(velocity.z, target.z, accel)
	velocity.y = 0.0 if is_on_floor() else velocity.y - Tuning.num("tuning", "movement.gravity_mps2") * delta
	if target.length() > 0.1:
		var want := atan2(-target.x, -target.z)
		rotation.y = lerp_angle(rotation.y, want, Tuning.num("tuning", "movement.turn_speed_rad_s") * delta)
	move_and_slide()
	position = keep_in(position)
	_waddle(delta)


## A player walking out past the clearing's edge (data/tuning.json movement.edge_m from the camp's middle) is held
## at it, so nobody wanders off into the empty field.
static func keep_in(at: Vector3) -> Vector3:
	var flat := Vector2(at.x, at.z)
	var edge := Tuning.num("tuning", "movement.edge_m", 14.0)
	if flat.length() <= edge:
		return at
	flat = flat.normalized() * edge
	return Vector3(flat.x, at.y, flat.y)


## Eases a remote camper toward where the other PC last said it was; jumps if it is far off.
func _glide(delta: float) -> void:
	var before := position
	var target: Vector3 = remote_target
	if before.distance_to(target) > Tuning.num("net", "remote_snap_m", 4.0):
		position = target
	else:
		position = before.lerp(target, 1.0 - exp(-Tuning.num("net", "remote_smoothing", 14.0) * delta))
	rotation.y = lerp_angle(rotation.y, remote_yaw, 1.0 - exp(-Tuning.num("net", "remote_smoothing", 14.0) * delta))
	velocity = (position - before) / maxf(delta, 0.0001)
	_waddle(delta)


## A guest's stroll: straight to its target at walking pace, facing the way it goes (backwards onto a seat), then on to
## the next point of its path.
func _walk(delta: float) -> void:
	var target: Vector3 = walk_target
	target.y = position.y
	var before := position
	position = position.move_toward(target, walk_speed * delta)
	var step := position - before
	if step.length() > 0.0001:
		var face := atan2(step.x, step.z) if _back_in and _path.is_empty() else atan2(-step.x, -step.z)
		rotation.y = lerp_angle(rotation.y, face, Tuning.num("tuning", "movement.turn_speed_rad_s") * delta)
	velocity = step / maxf(delta, 0.0001)
	_waddle(delta)
	if position.distance_to(target) < 0.01:
		if not _path.is_empty():
			walk_target = _path.pop_front()
			return
		walk_target = null
		velocity = Vector3.ZERO
		arrived.emit()


func _waddle(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / maxf(Tuning.num("tuning", "movement.walk_speed_mps"), 0.01)
	_walk_phase += delta * TAU * Tuning.num("tuning", "movement.waddle_hz") * speed
	var sway := sin(_walk_phase) * deg_to_rad(Tuning.num("tuning", "movement.waddle_deg")) * speed
	_body.rotation.z = sway
	_body.position.y = _sit_y + absf(sin(_walk_phase)) * Tuning.num("tuning", "movement.bob_m") * speed
