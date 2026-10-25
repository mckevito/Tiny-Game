extends CharacterBody3D
## The Milestone 0 test capsule: proves both input methods move a body. Numbers: data/tuning.json "movement".


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target := Vector3(input.x, 0.0, input.y) * Tuning.num("tuning", "movement.walk_speed_mps")
	var accel := Tuning.num("tuning", "movement.acceleration_mps2") * delta
	velocity.x = move_toward(velocity.x, target.x, accel)
	velocity.z = move_toward(velocity.z, target.z, accel)
	velocity.y -= Tuning.num("tuning", "movement.gravity_mps2") * delta if not is_on_floor() else 0.0
	if input.length() > 0.1:
		var want := atan2(-target.x, -target.z)
		rotation.y = lerp_angle(rotation.y, want, Tuning.num("tuning", "movement.turn_speed_rad_s") * delta)
	move_and_slide()
