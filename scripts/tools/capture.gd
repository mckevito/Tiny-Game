extends SceneTree
## Review captures of the sandbox from the play camera, one per light mood, plus a close shot and a short walking
## clip as numbered frames. Needs a renderer (in the cloud: xvfb-run). Not a test; nothing here ships.
##   godot --script res://scripts/tools/capture.gd --resolution 1280x720 -- --out=DIR [--clip] [--couch]
## --couch instead plays the camp with a couch player who walks away (the screen splits), around and back (it
## merges), saving couch_###.png frames; it uses a throwaway save and profile.
## --stage-a plays the camp with a built pitch, its guest's tent and a build ghost, saving day_<hour>.png at a
## morning, an evening and a late-evening hour (the light follows the clock), also with a throwaway save.

const SETTLE_FRAMES := 30


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://captures"
	var clip := false
	var couch := false
	var stage_a := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		clip = clip or arg == "--clip"
		couch = couch or arg == "--couch"
		stage_a = stage_a or arg == "--stage-a"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	if couch:
		await _couch(out)
		quit(0)
		return
	if stage_a:
		await _stage_a(out)
		quit(0)
		return
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


## The couch walk: player two walks off to the east (split), loops north and comes back to the fire (merge) while
## player one strolls nearby. Campers glide like remote ones so they waddle without a real controller.
func _couch(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await process_frame
	camp.start_solo(1)
	var pad := InputEventJoypadButton.new()
	pad.device = 1
	pad.button_index = 6
	pad.pressed = true
	camp._input(pad)
	camp.state.camp["profiles"][camp.couch_id]["name"] = "Clover"
	var one: Camper = camp.campers["p_capture_one"]
	var two: Camper = camp.campers[camp.couch_id]
	two.get_node("Name").text = "Clover"
	for c: Camper in [one, two]:
		c.controlled = false
	var start_one := one.position
	var start_two := two.position
	# Waypoints for player two, relative to where it starts (metres): out east, north, back west, home.
	var path := [Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(12, 0, 1), Vector3(13, 0, -6), Vector3(5, 0, -8),
			Vector3(0, 0, -3), Vector3(0, 0, 0)]
	var speed := Tuning.num("tuning", "movement.walk_speed_mps")
	var dt := 1.0 / 30.0
	var frame := 0
	for f in 20:
		await process_frame
	for i in path.size() - 1:
		var a: Vector3 = start_two + path[i]
		var b: Vector3 = start_two + path[i + 1]
		var steps := int(a.distance_to(b) / (speed * dt))
		for s in steps:
			var t := float(s + 1) / steps
			two.remote_target = a.lerp(b, t)
			two.remote_yaw = atan2(-(b - a).x, -(b - a).z)
			one.remote_target = start_one + Vector3(sin(frame * 0.02) * 1.2, 0, cos(frame * 0.02) * 0.6 - 0.6)
			one.remote_yaw = one.rotation.y
			await process_frame
			if s % 2 == 0:
				root.get_viewport().get_texture().get_image().save_png(out + "/couch_%03d.png" % frame)
				frame += 1
	for f in 45:
		await process_frame
		if f % 2 == 0:
			root.get_viewport().get_texture().get_image().save_png(out + "/couch_%03d.png" % frame)
			frame += 1
	camp.stop("")
	CampSave.dir = ""


## Stage A: a pitch with its guest and tent, the player in build mode beside it, at three hours of the day.
func _stage_a(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await process_frame
	camp.start_solo(1)
	camp.state.build.build("p_capture_one", "pitch", Vector2(-3, 8), 0.0)
	camp._show_object(camp.state.build.last_id)
	camp.state.camp["coins"] = 60
	var start := Tuning.num("day", "clock.start_hour")
	camp.state.camp["calendar"]["minute"] = (Tuning.num("day", "stays.arrive_hour") - start) * 60.0
	await process_frame
	for c: Camper in camp.visitors.values():
		c.walk_speed = 100.0
	var me: Camper = camp.campers["p_capture_one"]
	me.position = Vector3(-6.0, 0, 7.6)
	me.rotation.y = 0.0
	camp.toggle_build("p_capture_one")
	for hour in [11.0, 18.5, 21.0]:
		camp.state.camp["calendar"]["minute"] = (hour - start) * 60.0
		await _settle()
		_save(out + "/day_%02d.png" % int(hour))
	camp.stop("")
	CampSave.dir = ""
