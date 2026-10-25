extends SceneTree
## Playtest driver (dev only, not a test): plays the real main scene from the title through real key and pad presses
## (Input.parse_input_event, so GUI focus sees them as a player's would), saving a frame per step and logging, for each
## frame, which HUD pieces show and any that leave the screen or overlap ("BAD"). Solo, then a couch drop-in with a
## split screen. Uses a throwaway save and settings file. Read every frame before reporting.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --script res://scripts/tools/playtest.gd --resolution 1600x900 \
##     -- --out=DIR
## Host and join between two real copies: scripts/tools/playtest_net.gd.

var out := "user://playtest"
var camp: Node
var log_lines: PackedStringArray = []
var step_no := 0


func _initialize() -> void:
	_run.call_deferred()


func _key(name: String, down: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = OS.find_keycode_from_string(name)
	ev.keycode = ev.physical_keycode
	ev.pressed = down
	Input.parse_input_event(ev)


func tap(name: String, frames: int = 6) -> void:
	_key(name, true)
	await process_frame
	_key(name, false)
	for f in frames:
		await process_frame


func hold(name: String, frames: int) -> void:
	_key(name, true)
	for f in frames:
		await process_frame
	_key(name, false)
	await process_frame


func pad(device: int, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	for f in 6:
		await process_frame


func settle(frames: int = 20) -> void:
	for f in frames:
		await process_frame


func shot(name: String) -> void:
	await settle()
	step_no += 1
	var path := "%s/%02d_%s.png" % [out, step_no, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	note("shot %s | page=%s menu=%s report=%s | %s" % [path.get_file(), camp.menu.page(), camp.menu.visible,
			camp.report.visible, _layout()])


func note(s: String) -> void:
	print("PT ", s)
	log_lines.append(s)


func _layout() -> String:
	var hud: Node = camp.get_node("Hud")
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var pieces: Array = []
	var bad: PackedStringArray = []
	for c in hud.get_children():
		if not (c is Control) or not c.visible:
			continue
		if c.name in ["Night"]:
			continue
		if c is Label and str(c.text).strip_edges() == "":
			continue
		var r: Rect2 = c.get_global_rect()
		if not screen.encloses(r.grow(-1)):
			bad.append("OFF %s %s" % [c.name, r])
		pieces.append([c, r])
	var covers := ["Menu", "Report"]
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			var a: Control = pieces[i][0]
			var b: Control = pieces[j][0]
			if a.name in covers or b.name in covers:
				continue
			if (pieces[i][1] as Rect2).intersects(pieces[j][1]):
				bad.append("OVERLAP %s %s / %s %s" % [a.name, pieces[i][1], b.name, pieces[j][1]])
	var names: PackedStringArray = []
	for p in pieces:
		names.append(str(p[0].name))
	return "on: %s %s" % [",".join(names), ("BAD " + "; ".join(bad)) if bad.size() else "ok"]


## Frames must come from the owner's renderer: without lavapipe Godot quietly falls back to OpenGL.
func _forward_plus() -> bool:
	# OpenGL and the headless dummy renderer have no RenderingDevice.
	if RenderingServer.get_rendering_device() == null or DisplayServer.get_name() == "headless":
		push_error("playtest: no Vulkan Forward+ renderer; run under xvfb-run with mesa-vulkan-drivers installed")
		return false
	return true


func me() -> String:
	return str(camp.profile["id"])


func put(who: String, at: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.position = Vector3(at.x, c.position.y, at.y)
	camp.state.set_player_pos(who, at, 0.0)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	if not _forward_plus():
		quit(1)
		return
	CampSave.dir = "user://playtest_save"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_settings.json"))
	Settings.use_file("user://playtest_settings.json")
	await process_frame
	camp = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_play_one", "name": "Juniper", "last_address": ""}
	root.add_child(camp)
	await settle(30)
	await shot("title")
	await tap("Enter")
	await shot("start_page")
	await tap("Enter")  # focus starts on Play alone
	await settle(10)
	note("after Play alone: state=%s mode=%s" % [camp.state != null, camp.mode])
	await shot("welcome_report")
	await tap("E")
	await shot("camp_hud")
	var start: Vector3 = camp.campers[me()].position
	await hold("W", 40)
	note("walked W: moved %.2f m" % camp.campers[me()].position.distance_to(start))
	await tap("J")
	await shot("clipboard")
	for i in 4:
		await tap("R")
		await shot("clipboard_tab_%d" % (i + 1))
	await tap("J")
	await tap("I")
	await shot("pack_open")
	await tap("D")
	await tap("I")
	for i in 4:
		await tap("T")
		await shot("tool_%d" % i)
	await tap("B")
	await shot("build_mode")
	await tap("C")
	await shot("build_next_kind")
	await tap("B")
	await tap("Tab")
	await shot("pause_menu")
	# walk focus down the pause menu to Options
	var opts: Button = null
	for b in camp.menu._pause.get_children():
		if b is Button and b.text == Tuning.text("title.options"):
			opts = b
	if opts:
		opts.grab_focus()
		await tap("Enter")
		await shot("options_from_camp")
		await tap("Escape")
		await shot("back_from_options")
	await tap("Tab")
	await shot("menu_tab_again")
	await tap("Escape")
	await shot("menu_closed")
	await tap("F1")
	await shot("dev_panel")
	await tap("F1")
	# workbench
	put(me(), Vector2(-3.8, 2.4))
	await settle(10)
	await shot("near_bench")
	await tap("E")
	await shot("bench_open")
	await tap("Escape")
	# home tent: find it
	note("action at bench spot: %s" % [camp.action_for(me())])
	# couch drop-in with a second pad's Options button (JOY_BUTTON_START = 6)
	await pad(1, JOY_BUTTON_START)
	note("couch after drop-in: '%s'" % camp.couch_id)
	await shot("couch_dropped_in")
	if camp.couch_id != "":
		put(camp.couch_id, Vector2(14, -6))
		await settle(40)
		await shot("couch_split")
		await pad(1, JOY_BUTTON_TOUCHPAD)
		await shot("couch_clipboard_split")
		await pad(1, JOY_BUTTON_DPAD_DOWN)
		await shot("couch_pack_split")
		await pad(1, JOY_BUTTON_DPAD_DOWN)
		await pad(1, JOY_BUTTON_TOUCHPAD)
		await tap("J")
		await shot("both_clipboards_split")
		await pad(1, JOY_BUTTON_TOUCHPAD)
		await tap("I")
		await pad(1, JOY_BUTTON_DPAD_DOWN)
		await shot("both_packs_split")
		await tap("I")
		await pad(1, JOY_BUTTON_DPAD_DOWN)
		await tap("F1")
		await shot("dev_in_split")
		await tap("F1")
		await tap("J")
		await pad(1, JOY_BUTTON_START)
		await shot("couch_menu")
		await pad(1, JOY_BUTTON_START)
	# evening, bed from the menu
	await tap("Tab")
	await shot("menu_with_couch")
	await tap("Tab")
	var f := FileAccess.open(out + "/playtest_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	camp.stop("")
	await settle(5)
	note("after leave: page=%s" % camp.menu.page())
	CampSave.dir = ""
	quit(0)
