extends "res://scripts/tools/playtest.gd"
## Host and join between two real game copies on this machine, each started from the title through the real buttons
## (dev only, not a test). The guest walks, opens the clipboard, the workbench and the menu, takes out a tool and
## crawls into the camp's tent; the host watches, then joins them in the tent so the night passes on both PCs.
## Start the host first, then the guest about 15 s later, each under its own xvfb-run:
##   godot --script res://scripts/tools/playtest_net.gd --resolution 1280x720 -- --out=DIR --role=host
##   godot --script res://scripts/tools/playtest_net.gd --resolution 1280x720 -- --out=DIR --role=join

var role := "host"


func _focus_start(action: String) -> void:
	for b in camp.menu._start.get_children():
		if b is Button and b.text == Tuning.text("menu." + action):
			b.grab_focus()


func _wait(check: Callable, frames: int) -> bool:
	for i in frames:
		if check.call():
			return true
		await process_frame
	return check.call()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	DirAccess.make_dir_recursive_absolute(out)
	if not _forward_plus():
		quit(1)
		return
	CampSave.dir = "user://playtest_save_" + role
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	Settings.use_file("user://playtest_settings_%s.json" % role)
	await process_frame
	camp = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_play_" + role, "name": "Host Hazel" if role == "host" else "Guest Gus", "last_address": ""}
	root.add_child(camp)
	await settle(10)
	await tap("Enter")
	if role == "host":
		_focus_start("host")
		await tap("Enter")
		note("host started: %s mode=%s" % [camp.state != null, camp.mode])
		await tap("E")
		var ok: bool = await _wait(func() -> bool: return camp.state.online.size() >= 2, 1500)
		note("guest arrived: %s online=%s" % [ok, camp.state.online])
		await settle(120)
		await shot("host_sees_guest")
		note("host campers: %s" % [camp.campers.keys()])
		await settle(150)
		await shot("host_sees_guest_tool")
		var gid := "p_play_join"
		note("host: guest held=%s inside=%s" % [camp.campers[gid].held if camp.campers.has(gid) else "?", camp._inside.keys()])
		await settle(250)
		note("host: guest held=%s inside=%s" % [camp.campers[gid].held if camp.campers.has(gid) else "?", camp._inside.keys()])
		var tp: Vector2 = camp.home_tent_pos()
		put(me(), tp + Vector2(0, 1.6))
		await settle(20)
		note("host action by tent: %s" % [camp.action_for(me())])
		await shot("host_peeks_guest_in_tent")
		await tap("E")
		await shot("host_and_guest_in_tent")
		note("host: inside=%s votes=%s" % [camp._inside.keys(), camp.state.day.votes])
		await settle(200)
		note("host after: day=%s inside=%s" % [camp.state.camp["calendar"], camp._inside.keys()])
		await shot("host_late")
		note("host campers at end: %s objects=%d coins=%s" % [camp.campers.keys(), camp.objects.size(), camp.state.camp.get("coins")])
	else:
		camp.menu.address_edit.text = "127.0.0.1"
		_focus_start("join")
		await tap("Enter")
		var ok: bool = await _wait(func() -> bool: return camp.state != null, 600)
		note("joined: %s mode=%s page=%s" % [ok, camp.mode, camp.menu.page()])
		if ok:
			await settle(30)
			await shot("guest_arrived")
			await tap("E")
			await hold("D", 30)
			await tap("J")
			await shot("guest_clipboard")
			await tap("J")
			for i in 2:
				await tap("T")
			await shot("guest_rod")
			camp.campers[me()].position = Vector3(-3.8, camp.campers[me()].position.y, 2.4)
			await settle(10)
			await tap("E")
			await shot("guest_bench")
			await tap("Escape")
			await tap("Tab")
			await shot("guest_menu")
			await tap("Escape")
			note("guest campers: %s" % [camp.campers.keys()])
			for i in 4:
				await tap("T")
			note("guest tool: %s" % camp.tool_of(me()))
			await shot("guest_axe")
			await settle(150)
			var tp: Vector2 = camp.home_tent_pos()
			put(me(), tp + Vector2(0, 1.6))
			await settle(20)
			note("guest action by tent: %s" % [camp.action_for(me())])
			await tap("E")
			note("guest inside=%s" % [camp._inside.keys()])
			await shot("guest_in_tent")
			await settle(300)
			await shot("guest_sees_host_in_tent")
			note("guest end: inside=%s calendar=%s report=%s" % [camp._inside.keys(), camp.state.camp["calendar"], camp.report.visible])
	var f := FileAccess.open(out + "/net_%s_log.txt" % role, FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	camp.stop("")
	await settle(5)
	CampSave.dir = ""
	quit(0)
