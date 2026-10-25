extends SceneTree
## Review captures of the sandbox from the play camera, one per light mood, plus a close shot and a short walking
## clip as numbered frames. Needs a renderer (in the cloud: xvfb-run). Not a test; nothing here ships.
##   godot --script res://scripts/tools/capture.gd --resolution 1280x720 -- --out=DIR [--clip]

const SETTLE_FRAMES := 30


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://captures"
	var clip := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		clip = clip or arg == "--clip"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var sandbox: Node = load("res://scenes/sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await process_frame
	var cam: PlayCamera = sandbox.camera
	for i in LightMoods.names().size():
		sandbox.set_mood(i)
		var mood: String = LightMoods.names()[i]
		cam._want_distance = Tuning.num("tuning", "camera.distance_m")
		cam.distance = cam._want_distance
		await _settle()
		_save(out + "/play_%s.png" % mood)
		cam._want_distance = Tuning.num("tuning", "camera.min_distance_m")
		cam.distance = cam._want_distance
		await _settle()
		_save(out + "/close_%s.png" % mood)
	if clip:
		await _clip(sandbox, out)
	quit(0)


func _settle() -> void:
	for f in SETTLE_FRAMES:
		await process_frame


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## A loop walk round the fire: right, back, left, forward, saving every second frame.
func _clip(sandbox: Node, out: String) -> void:
	sandbox.set_mood(0)
	var cam: PlayCamera = sandbox.camera
	cam._want_distance = Tuning.num("tuning", "camera.distance_m") - 2.0
	var frame := 0
	for action in ["move_right", "move_back", "move_left", "move_forward"]:
		Input.action_press(action)
		for f in 40:
			await process_frame
			if f % 2 == 0:
				root.get_viewport().get_texture().get_image().save_png(out + "/clip_%03d.png" % frame)
				frame += 1
		Input.action_release(action)
