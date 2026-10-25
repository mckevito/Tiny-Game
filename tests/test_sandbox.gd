extends RefCounted
## Milestone 0: the one sandbox scene loads and has its test capsule.


func test_sandbox_loads() -> String:
	var packed: PackedScene = load("res://scenes/sandbox.tscn")
	if packed == null:
		return "scenes/sandbox.tscn did not load"
	var root := packed.instantiate()
	var ok := root.has_node("TestMover") and root.has_node("Camera3D")
	root.free()
	return "" if ok else "sandbox is missing TestMover or Camera3D"
