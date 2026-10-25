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
## clipboard open on Supplies). Round 3 adds bench.png (the workbench panel and a dropped bundle); round 4 adds
## pack_dock.png (the open Pack and the corner dock with a tool in hand) and menu.png (the in-camp menu over the HUD);
## round 5 adds guest_tent.png (a guest asleep in their opened tent with its name bubble, at night), home_tent.png (the
## player in the camp's tent) and guide.png (the clipboard's field guide).
## --chop plays the first-minutes loop at 30 fps and saves chop_###.png frames: the camper chops a tree three times
## (the swing, the shudder and puff, wood popping onto the grass), the tree topples, the camper walks over the wood
## to sweep it up (+1 tags), then digs the stump with the shovel; a throwaway save.
## --fire saves the camp fire at each level at dusk (fire_<level>.png) with the camp board put up beside the camper
## (from the kit), a throwaway save.
## --menus saves the title over the clearing (title.png), the start page (start.png), each Options tab
## (options_<tab>.png, focus on the first setting) and Options opened from the in-camp menu (options_in_camp.png),
## with a throwaway save and settings file.
## --hero is the art review shot: the sandbox from a lower, closer camera framed like the owner's felt reference
## picture (hero_<mood>.png, no hint text), plus face_<mood>.png, a close look at the two campers.
## --turn=ID saves a turnaround of one model in a studio like the owner's turnaround sheet: a cream backdrop and floor,
## a key light from the camera's upper left, eight views (turn_front.png, turn_front_right.png ... turn_front_left.png;
## data/art.json "turnaround"). --glb=PATH shows that .glb, painted as model ID, instead of the model's own file (a
## camper built with --pose=t to match a T-pose sheet; it needn't be imported).
## --edge saves the play camera looking out from the walking edge to the north, east, south and west (edge_<dir>.png):
## the woods round the camp should fill the top of each frame, with no sky band.
## --player=ID and --friend=ID swap the two campers' models in the hero shots (to compare a new camper with the old).

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
	var hud := false
	var hero := false
	var chop := false
	var fire := false
	var edge := false
	var swap := {}
	var turn := ""
	var glb := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		clip = clip or arg == "--clip"
		couch = couch or arg == "--couch"
		stage_a = stage_a or arg == "--stage-a"
		stage_b = stage_b or arg == "--stage-b"
		menus = menus or arg == "--menus"
		hud = hud or arg == "--hud"
		hero = hero or arg == "--hero"
		chop = chop or arg == "--chop"
		fire = fire or arg == "--fire"
		edge = edge or arg == "--edge"
		if arg.begins_with("--turn="):
			turn = arg.trim_prefix("--turn=")
		if arg.begins_with("--glb="):
			glb = arg.trim_prefix("--glb=")
		for who in ["player", "friend"]:
			if arg.begins_with("--%s=" % who):
				swap[who] = arg.trim_prefix("--%s=" % who)
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
	if fire:
		await _fire(out)
		quit(0)
		return
	if chop:
		await _chop(out)
		quit(0)
		return
	if menus:
		await _menus(out)
		quit(0)
		return
	if hud:
		await _hud(out)
		quit(0)
		return
	if turn != "":
		await _turn(out, turn, glb)
		quit(0)
		return
	if hero:
		await _hero(out, swap)
		quit(0)
		return
	var sandbox: Node = load("res://scenes/sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await process_frame
	var cam: PlayCamera = sandbox.camera
	if edge:
		await _edge(sandbox, out)
		quit(0)
		return
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


## The player stands at the walking edge facing out, with the camera behind them, at each compass point.
func _edge(sandbox: Node, out: String) -> void:
	sandbox.set_mood(0)
	var cam: PlayCamera = sandbox.camera
	var at := Tuning.num("tuning", "movement.edge_m") - 0.2
	for dir: String in ["north", "east", "south", "west"]:
		var d: Vector2 = {"north": Vector2(0, -1), "east": Vector2(1, 0), "south": Vector2(0, 1), "west": Vector2(-1, 0)}[dir]
		sandbox.player.position = Vector3(d.x * at, 0, d.y * at)
		sandbox.player.rotation.y = atan2(-d.x, -d.y)
		cam.yaw = atan2(-d.x, -d.y)
		cam._want_distance = Tuning.num("tuning", "camera.distance_m")
		cam.distance = cam._want_distance
		cam.snap()
		await _settle()
		_save(out + "/edge_%s.png" % dir)


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
	s.pack.add_to_box("wood", 20)
	for kind in ["water_point", "lantern_post", "log_bench"]:
		s.camp["kit"][kind] = 1
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
	s.pack.add("p_capture_one", "perch", 2)
	s.pack.add("p_capture_one", "grilled_trout", 1)
	s.pack.add("p_capture_one", "stick", 7)
	s.pack.add("p_capture_one", "berries", 3)
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
	camp.hold_tool("p_capture_one", "axe")
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
	var bench := CampBuild.bench_pos()
	me.position = Vector3(bench.x + 0.2, 0, bench.y - 1.3)
	s.set_player_pos("p_capture_one", Vector2(me.position.x, me.position.z), 0.0)
	s.camp["bundles"]["bundle_cap"] = {"item": "stick", "n": 4, "pos": [bench.x + 1.4, bench.y - 1.6]}
	camp._sync_bundles()
	camp.camera.yaw = 0.0
	camp.open_bench("p_capture_one")
	camp._bench["p_capture_one"]["pick"] = 1
	camp._refresh_boards()
	await _settle()
	_save(out + "/bench.png")
	camp.close_bench("p_capture_one")
	camp.hold_tool("p_capture_one", "axe")
	camp._kinds["p_capture_one"] = "log_bench"
	camp.open_pack("p_capture_one")
	camp._packs["p_capture_one"]["pick"] = 2
	camp._refresh_boards()
	await _settle()
	_save(out + "/pack_dock.png")
	camp.close_pack("p_capture_one")
	camp._open_menu("p_capture_one")
	await _settle()
	_save(out + "/menu.png")
	camp._close_menu()
	camp.hold_tool("p_capture_one", "rod")
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
	if camp._busy.has("p_capture_one"):
		camp._end_busy("p_capture_one")
	s.camp["calendar"]["minute"] = (Tuning.num("guests", "tent.in_hour") + 0.5 - start) * 60.0
	if not camp._tents.is_empty():
		var tent: Node3D = camp._tents.values()[0]
		me.position = tent.position + Vector3(1.9, 0, -0.6)
		s.set_player_pos("p_capture_one", Vector2(me.position.x, me.position.z), 0.0)
		camp.camera.yaw = deg_to_rad(30.0)
		camp.camera._want_distance = Tuning.num("tuning", "camera.min_distance_m") + 1.0
		await _settle()
		await _settle()
		_save(out + "/guest_tent.png")
	s.join("p_capture_hold", "Ash")
	var home: Vector2 = camp.home_tent_pos()
	me.position = Vector3(home.x + 1.6, 0, home.y)
	s.set_player_pos("p_capture_one", home + Vector2(1.6, 0), 0.0)
	camp.enter_tent("p_capture_one")
	camp.camera.yaw = deg_to_rad(-20.0)
	await _settle()
	await _settle()
	_save(out + "/home_tent.png")
	camp.leave_tent("p_capture_one")
	s.leave("p_capture_hold")
	s.camp["journal"]["photos"] = {"rabbit": 2, "deer": 1}
	if not (s.camp["journal"]["wildlife"] as Array).has("squirrel"):
		s.camp["journal"]["wildlife"].append("squirrel")
	camp.toggle_clipboard("p_capture_one")
	camp._boards["p_capture_one"].tab = Clipboard.tabs().find("guide")
	camp._refresh_boards()
	await _settle()
	_save(out + "/guide.png")
	camp.toggle_clipboard("p_capture_one")
	s.camp["calendar"]["minute"] = (Tuning.num("day", "clock.evening_hour") - start) * 60.0
	s.day.vote("p_capture_one", true)
	camp._check_bed()
	for f in 90:
		await process_frame
	_save(out + "/report.png")
	camp.stop("")
	CampSave.dir = ""


func _chop(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await process_frame
	camp.start_solo(1)
	camp.report.visible = false
	var s: CampState = camp.state
	s.camp["calendar"]["minute"] = (11.0 - Tuning.num("day", "clock.start_hour")) * 60.0
	var tree: Dictionary = CampGather.trees()[4]
	var me: Camper = camp.campers["p_capture_one"]
	me.position = Vector3(tree["pos"].x - 1.1, 0, tree["pos"].y + 0.3)
	camp.hold_tool("p_capture_one", "axe")
	camp.camera._want_distance = Tuning.num("tuning", "camera.min_distance_m")
	await _settle()
	var frame := [0]
	var shoot := func(n: int) -> void:
		for i in n:
			await process_frame
			_save(out + "/chop_%03d.png" % frame[0])
			frame[0] += 1
	for i in int(Tuning.num("gather", "trees.wood_per_tree")):
		camp.interact("p_capture_one")
		await shoot.call(36)
	await shoot.call(10)
	for id: String in s.camp["bundles"].keys():
		var to := CampPack.bundle_pos(s.camp["bundles"][id])
		var from := me.position
		for k in 12:
			me.position = from.lerp(Vector3(to.x, 0, to.y), (k + 1) / 12.0)
			me.rotation.y = atan2(-(to.x - from.x), -(to.y - from.z))
			await shoot.call(1)
		await shoot.call(8)
	me.position = Vector3(tree["pos"].x - 1.1, 0, tree["pos"].y + 0.3)
	s.gather.take_sapling("p_capture_one", int(tree["index"]))
	camp._sync_trees(false)
	camp.hold_tool("p_capture_one", "shovel")
	await shoot.call(4)
	camp.interact("p_capture_one")
	await shoot.call(50)


func _fire(out: String) -> void:
	CampSave.dir = "user://captures_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_capture_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await process_frame
	camp.start_solo(1)
	camp.report.visible = false
	var s: CampState = camp.state
	var me: Camper = camp.campers["p_capture_one"]
	me.position = Vector3(2.4, 0, 2.2)
	s.set_player_pos("p_capture_one", Vector2(2.4, 2.2), 0.0)
	s.build.build("p_capture_one", "project_board", Vector2(-2.0, 3.0), 0.0)
	camp._show_object(s.build.last_id)
	camp.camera._want_distance = Tuning.num("tuning", "camera.distance_m")
	s.camp["calendar"]["minute"] = (19.5 - Tuning.num("day", "clock.start_hour")) * 60.0
	for level in CampBuild.fire_levels().size() + 1:
		s.camp["fire"] = {"level": level}
		camp._sync_fire()
		await _settle()
		_save(out + "/fire_%d.png" % level)


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


## The interface: alone, the dock and the open Pack; then on the couch, split, both docks, both clipboards and both
## Packs, with the HUD as full as play makes it (guests' wishes, a build prompt each, the bed line).
func _hud(out: String) -> void:
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
	for kind in ["water_point", "lantern_post", "log_bench"]:
		s.camp["kit"][kind] = 1
	for item in ["grilled_trout", "perch", "berries", "sapling", "stick", "wood"]:
		s.pack.add("p_capture_one", item, 5)
	camp.hold_tool("p_capture_one", "axe")
	await _settle()
	_save(out + "/hud_dock.png")
	camp.open_pack("p_capture_one")
	camp._packs["p_capture_one"]["pick"] = 3
	camp._refresh_boards()
	await _settle()
	_save(out + "/hud_pack.png")
	camp.close_pack("p_capture_one")
	# Player one's own controller moves first, so the second one drops in (as in test_hud).
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	camp._input(stick)
	var pad := InputEventJoypadButton.new()
	pad.device = 1
	pad.button_index = 6
	pad.pressed = true
	camp._input(pad)
	var two: String = camp.couch_id
	s.camp["profiles"][two]["name"] = "Clover"
	camp.campers[two].get_node("Name").text = "Clover"
	camp.campers[two].position = camp.campers["p_capture_one"].position + Vector3(12, 0, 4)
	for item in ["trout", "berries", "wood"]:
		s.pack.add(two, item, 3)
	var wishes := ["fish", "meal", "chair"]
	for i in wishes.size():
		s.camp["stays"]["capture_%d" % i] = {"name": ["Fern", "Basil", "Hazel"][i], "pitch": "", "look": "camper_a",
				"request": {"kind": wishes[i], "done": false}}
	s.camp["calendar"]["minute"] = (Tuning.num("day", "clock.evening_hour") + 0.5
			- Tuning.num("day", "clock.start_hour")) * 60.0
	for who in camp.local_ids():
		camp.toggle_build(who)
	for f in 30:
		await process_frame
	await _settle()
	_save(out + "/couch_docks.png")
	camp.toggle_clipboard("p_capture_one")
	camp.toggle_clipboard(two)
	camp._refresh_boards()
	await _settle()
	_save(out + "/couch_clipboards.png")
	camp.toggle_clipboard("p_capture_one")
	camp.toggle_clipboard(two)
	camp.open_pack("p_capture_one")
	camp.open_pack(two)
	await _settle()
	_save(out + "/couch_packs.png")
	camp.stop("")
	CampSave.dir = ""


## The art review shot: a lower, closer camera on the sandbox's fire, tent and trees, in each mood, then a close
## look at the campers' faces. The play camera keeps following the player, so this camera is made current instead.
func _hero(out: String, swap: Dictionary) -> void:
	var sandbox: Node = load("res://scenes/sandbox.tscn").instantiate()
	for who: String in swap:
		sandbox.get_node("Player" if who == "player" else "Friend").model_id = swap[who]
	root.add_child(sandbox)
	await process_frame
	for label in ["Hint", "Mood"]:
		sandbox.get_node(label).visible = false
	var mid: Vector3 = (sandbox.player.position + sandbox.friend.position) * 0.5
	var cam := Camera3D.new()
	cam.fov = 40.0
	sandbox.add_child(cam)
	cam.current = true
	for i in LightMoods.names().size():
		sandbox.set_mood(i)
		var mood: String = LightMoods.names()[i]
		cam.look_at_from_position(mid + Vector3(0.6, 8.0, 9.0), mid + Vector3(0.6, 0.0, -1.2))
		Miniature.focus(cam, cam.position.distance_to(mid))
		await _settle()
		_save(out + "/hero_%s.png" % mood)
		cam.look_at_from_position(mid + Vector3(0, 2.1, 3.6), mid + Vector3(0, 0.75, 0))
		Miniature.focus(cam, cam.position.distance_to(mid))
		await _settle()
		_save(out + "/face_%s.png" % mood)


## A turnaround: the model alone in a studio, from eight sides, lit from the camera's upper right as the owner's sheet
## is. The light turns with the camera; the floor is a shadow catcher in the backdrop's colour, so there is no horizon.
func _turn(out: String, id: String, glb: String) -> void:
	var cfg: Dictionary = Tuning.table("art").get("turnaround", {})
	# Drawn larger and scaled down, as a photo would: felt fuzz comes out soft instead of single-pixel speckle.
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = float(cfg.get("supersample", 1.0))
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	LightMoods.apply("day", sun, env, [])
	var backdrop := Color.html(str(cfg.get("background", "#FBF5E8")))
	env.background_color = backdrop
	# A plain camera: no grading or tone curve, so the backdrop and the felt's colours come out as they are.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = false
	env.ambient_light_color = Color.html(str(cfg.get("ambient_color", "#FFFFFF")))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.5))
	sun.light_color = Color.html(str(cfg.get("key_color", "#FFFFFF")))
	sun.light_energy = float(cfg.get("key_energy", 1.0))
	sun.light_angular_distance = float(cfg.get("key_softness_deg", 0.0))
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = Shader.new()
	floor_mat.shader.code = """shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
uniform vec3 backdrop;
uniform float strength;
void fragment() { ALBEDO = backdrop; }
void light() { DIFFUSE_LIGHT += vec3(1.0 - strength * (1.0 - ATTENUATION)); }
"""
	var lin := backdrop.srgb_to_linear()
	floor_mat.set_shader_parameter("backdrop", Vector3(lin.r, lin.g, lin.b))
	floor_mat.set_shader_parameter("strength", float(cfg.get("shadow_strength", 0.35)))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = floor_mat
	world.add_child(ground)
	var model := FeltBuilder.build(id)
	if glb != "":
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(glb, state) == OK:
			var scene := doc.generate_scene(state)
			model.mesh = FeltBuilder.painted(scene, FeltBuilder.resolve(id))
			scene.free()
		else:
			push_error("capture: can't read %s" % glb)
	world.add_child(model)
	var cam := Camera3D.new()
	cam.fov = float(cfg.get("fov_deg", 16.0))
	world.add_child(cam)
	cam.current = true
	var dist := float(cfg.get("camera_distance_m", 6.0))
	var aim := Vector3(0, float(cfg.get("aim_height_m", 0.72)), 0)
	var key_az := deg_to_rad(float(cfg.get("key_azimuth_deg", 40.0)))
	var key_el := deg_to_rad(float(cfg.get("key_elevation_deg", 40.0)))
	var views := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
	for i in views.size():
		# The front is -Z and the camper's right is +X: view i stands 45 degrees further round to its right.
		var a := deg_to_rad(45.0 * i)
		cam.look_at_from_position(Vector3(sin(a) * dist, float(cfg.get("camera_height_m", 1.6)), -cos(a) * dist), aim)
		var key := Vector3(sin(a + key_az) * cos(key_el), sin(key_el), -cos(a + key_az) * cos(key_el))
		sun.look_at_from_position(key * 10.0, Vector3.ZERO)
		await _settle()
		_save(out + "/turn_%s.png" % views[i])
