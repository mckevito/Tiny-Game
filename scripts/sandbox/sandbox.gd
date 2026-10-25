extends Node3D
## The one sandbox scene (CLAUDE.md). Places the camera from data/tuning.json "camera" and shows the hint text.


func _ready() -> void:
	var cam: Camera3D = $Camera3D
	cam.fov = Tuning.num("tuning", "camera.fov_deg", 40.0)
	cam.position = Vector3(0.0, Tuning.num("tuning", "camera.height_m"), Tuning.num("tuning", "camera.distance_m"))
	cam.look_at(Vector3.ZERO)
	$Hint.text = Tuning.text("sandbox.hint")
