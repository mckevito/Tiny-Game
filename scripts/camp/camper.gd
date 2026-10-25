class_name Camper
extends CharacterBody3D
## A felt camper. The controlled one walks relative to the play camera with either input method; both waddle and
## bob as they walk. Numbers: data/tuning.json "movement".

@export var model_id := "camper_a"
@export var controlled := false
## The camera whose yaw makes "forward" mean "away from the camera".
var camera: Node3D

var _body: Node3D
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


## The wanted ground velocity for a stick or key input, turned by the camera's yaw.
static func wish_velocity(input: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw) * Tuning.num("tuning", "movement.walk_speed_mps")


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controlled else Vector2.ZERO
	var target := wish_velocity(input, camera.global_rotation.y if camera else 0.0)
	var accel := Tuning.num("tuning", "movement.acceleration_mps2") * delta
	velocity.x = move_toward(velocity.x, target.x, accel)
	velocity.z = move_toward(velocity.z, target.z, accel)
	velocity.y = 0.0 if is_on_floor() else velocity.y - Tuning.num("tuning", "movement.gravity_mps2") * delta
	if target.length() > 0.1:
		var want := atan2(-target.x, -target.z)
		rotation.y = lerp_angle(rotation.y, want, Tuning.num("tuning", "movement.turn_speed_rad_s") * delta)
	move_and_slide()
	_waddle(delta)


func _waddle(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / maxf(Tuning.num("tuning", "movement.walk_speed_mps"), 0.01)
	_walk_phase += delta * TAU * Tuning.num("tuning", "movement.waddle_hz") * speed
	var sway := sin(_walk_phase) * deg_to_rad(Tuning.num("tuning", "movement.waddle_deg")) * speed
	_body.rotation.z = sway
	_body.position.y = absf(sin(_walk_phase)) * Tuning.num("tuning", "movement.bob_m") * speed
