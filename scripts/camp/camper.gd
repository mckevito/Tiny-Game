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
## A visiting guest walks here at `walk_speed` (data/day.json stays.walk_speed_mps), in its parent's space, then
## emits `arrived`; null when it is not walking anywhere.
var walk_target: Variant = null
var walk_speed := 1.5
## A player's walking pace as a share of the usual (a long log carried alone is slow; CampGather.carry_speed).
var speed_scale := 1.0

## The tool shown in the camper's mitten (data/items.json tools.order; "hands" shows none).
var held := "hands"

signal arrived

var _body: Node3D
var _tool: Node3D
var _walk_phase := 0.0


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
	_tool.position = FeltBuilder.vec3(Tuning.value("tuning", "camper.hand_pos"))
	_tool.rotation_degrees = FeltBuilder.vec3(row.get("rot", [0, 0, 0]))
	_tool.scale = Vector3.ONE * Tuning.num("tuning", "camper.tool_scale", 1.0)
	_body.add_child(_tool)


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
	_waddle(delta)


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


## A guest's stroll: straight to its target at walking pace, facing the way it goes.
func _walk(delta: float) -> void:
	var target: Vector3 = walk_target
	target.y = position.y
	var before := position
	position = position.move_toward(target, walk_speed * delta)
	var step := position - before
	if step.length() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(-step.x, -step.z), Tuning.num("tuning", "movement.turn_speed_rad_s") * delta)
	velocity = step / maxf(delta, 0.0001)
	_waddle(delta)
	if position.distance_to(target) < 0.01:
		walk_target = null
		velocity = Vector3.ZERO
		arrived.emit()


func _waddle(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / maxf(Tuning.num("tuning", "movement.walk_speed_mps"), 0.01)
	_walk_phase += delta * TAU * Tuning.num("tuning", "movement.waddle_hz") * speed
	var sway := sin(_walk_phase) * deg_to_rad(Tuning.num("tuning", "movement.waddle_deg")) * speed
	_body.rotation.z = sway
	_body.position.y = absf(sin(_walk_phase)) * Tuning.num("tuning", "movement.bob_m") * speed
