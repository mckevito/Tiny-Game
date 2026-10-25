extends SceneTree
## Review captures of the sandbox from the play camera, one per light mood, plus a close shot and a short walking
## clip as numbered frames. Needs a renderer (in the cloud: xvfb-run). Not a test; nothing here ships.
##   godot --script res://scripts/tools/capture.gd --resolution 1280x720 -- --out=DIR [--clip] [--couch]
## --couch instead plays the camp with a couch player who walks away (the screen splits), around and back (it
## merges), saving couch_###.png frames; it uses a throwaway save and profile.
## --stage-a plays the camp with a built pitch, its guest's tent and a build ghost, saving day_<hour>.png at a
## morning, an evening and a late-evening hour (the light follows the clock), also with a throwaway save.
## --stage-b plays the camp with two pitches, a water point and a lantern post, guests with requests over their
## heads and the player fishing at the pond, saving camp_day.png and camp_dusk.png, then report.png (the morning
## report after a night). Round 2 adds welcome.png (the first morning's Today list), a log bench by the fire, the
## animals in the day and dusk shots (day 3: rabbits, squirrels, deer, the bear by the fire), chop.png, and
## stump_log_clipboard.png (a felled tree's stump and sapling, a planted sapling, the long log carried and the
## clipboard open on Supplies).
## --menus saves the title over the clearing (title.png), the start page (start.png), each Options tab
## (options_<tab>.png, focus on the first setting) and Options opened from the in-camp menu (options_in_camp.png),
## with a throwaway save and settings file.

const SETTLE_FRAMES := 30


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://captures"
	var clip := false
	var couch := false
	var stage_a := false
	var stage_b := false
	var menus := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		clip = clip or arg == "--clip"
		couch = couch or arg == "--couch"
		stage_a = stage_a or arg == "--stage-a"
		stage_b = stage_b or arg == "--stage-b"
		menus = menus or arg == "--menus"
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
	if stage_b:
		await _stage_b(out)
		quit(0)
		return
	if menus:
		await _menus(out)
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


## Stage B: three pitches with the booked family and a walk-in guest (requests over their heads), a water point and
## a lantern post, by day and at dusk; the player fishing at the pond; then the morning report.
func _stage_b(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await process_frame
	camp.start_solo(1)
	var s: CampState = camp.state
	camp._welcome_report()
	await _settle()
	_save(out + "/welcome.png")
	camp.report.visible = false
	s.camp["coins"] = 200
	s.camp["wood"] = 20
	for row in [["pitch", Vector2(3, 5)], ["pitch", Vector2(-4, 7)], ["pitch", Vector2(-7.5, 5)],
			["water_point", Vector2(0, 8)], ["lantern_post", Vector2(1, 3)], ["log_bench", Vector2(-2, -2)]]:
		var why: String = s.build.build("p_capture_one", row[0], row[1], 0.0)
		if why != "":
			print("could not build ", row, ": ", why)
		camp._show_object(s.build.last_id)
	s.guests.refresh_offers()
	s.guests.decide("p_capture_one", "ferns", "accept")
	s.camp["calendar"]["day"] = 3
	var start := Tuning.num("day", "clock.start_hour")
	s.camp["calendar"]["minute"] = (Tuning.num("day", "stays.arrive_hour") - start) * 60.0
	await process_frame
	for c: Camper in camp.visitors.values():
		c.walk_speed = 100.0
	var me: Camper = camp.campers["p_capture_one"]
	me.position = Vector3(-1.5, 0, 10.0)
	me.rotation.y = 0.0
	s.camp["profiles"]["p_capture_one"]["pockets"] = ["perch", "grilled_trout"]
	camp.camera._want_distance = Tuning.num("tuning", "camera.max_distance_m")
	for hour in [11.0, 19.0]:
		s.camp["calendar"]["minute"] = (hour - start) * 60.0
		await _settle()
		_save(out + "/camp_%s.png" % ("day" if hour < 12.0 else "dusk"))
	s.camp["calendar"]["minute"] = (11.0 - start) * 60.0
	var tree: Dictionary = CampGather.trees()[4]
	me.position = Vector3(tree["pos"].x - 1.0, 0, tree["pos"].y + 0.3)
	me.rotation.y = deg_to_rad(-90.0)
	s.set_player_pos("p_capture_one", Vector2(me.position.x, me.position.z), -90.0)
	camp.interact("p_capture_one")
	camp.camera._want_distance = Tuning.num("tuning", "camera.min_distance_m")
	await _settle()
	if camp._busy.has("p_capture_one"):
		camp._busy["p_capture_one"]["left"] = 100.0
	camp.wobble(int(tree["index"]))
	for f in 6:
		await process_frame
	_save(out + "/chop.png")
	camp._end_busy("p_capture_one")
	var fell: Dictionary = CampGather.trees()[1]
	s.camp["trees"][str(fell["index"])] = {"chops": 0, "stage": "stump", "sapling_out": true, "planted": 0}
	var grown: Dictionary = CampGather.trees()[2]
	s.camp["trees"][str(grown["index"])] = {"chops": 0, "stage": "sapling", "sapling_out": false, "planted": 3}
	camp._sync_trees()
	me.position = Vector3(fell["pos"].x + 1.6, 0, fell["pos"].y + 1.4)
	var log_id := ""
	for id: String in s.camp["objects"]:
		if str(s.camp["objects"][id]["model"]) == "long_log":
			log_id = id
	s.carriers[log_id] = "p_capture_one"
	camp._apply_object(log_id)
	camp.toggle_clipboard("p_capture_one")
	camp._boards["p_capture_one"].flip(2)
	camp._refresh_boards()
	await _settle()
	_save(out + "/stump_log_clipboard.png")
	camp.toggle_clipboard("p_capture_one")
	s.carriers.erase(log_id)
	camp._apply_object(log_id)
	me.position = Vector3(2.4, 0, -3.6)
	me.rotation.y = deg_to_rad(-90.0)
	s.set_player_pos("p_capture_one", Vector2(2.4, -3.6), -90.0)
	camp.interact("p_capture_one")
	camp.camera.yaw = PI
	camp.camera._want_distance = Tuning.num("tuning", "camera.min_distance_m")
	if camp._busy.has("p_capture_one"):
		camp._busy["p_capture_one"]["left"] = 100.0
	await _settle()
	await _settle()
	_save(out + "/fishing.png")
	s.camp["calendar"]["minute"] = (Tuning.num("day", "clock.evening_hour") - start) * 60.0
	s.day.vote("p_capture_one", true)
	camp._check_bed()
	for f in 90:
		await process_frame
	_save(out + "/report.png")
	camp.stop("")
	CampSave.dir = ""


func _menus(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captures_settings.json"))
	Settings.use_file("user://captures_settings.json")
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	var menu: CampMenu = camp.menu
	await _settle()
	_save(out + "/title.png")
	menu.show_start()
	await _settle()
	_save(out + "/start.png")
	for page: Dictionary in Tuning.value("settings", "pages", []):
		menu.show_options(str(page["id"]), "title")
		await _settle()
		_save(out + "/options_%s.png" % page["id"])
	camp.start_solo(1)
	camp.report.visible = false
	camp._open_menu()
	menu.show_options("controls", "pause")
	await _settle()
	_save(out + "/options_in_camp.png")
