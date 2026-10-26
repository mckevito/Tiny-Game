extends RefCounted
## The developer menu (F1 or the DualSense's Create button): time of day, clock speed, sleep, season and day, calling
## a guest, coins and items, teleports, character previews, the fps line and hiding the HUD; driven by key and pad
## presses, alone, on the couch and from a guest PC (the host decides), and off in a build without dev tools.

const DIR := "user://test_saves/dev"
const CREATE := 4
const MENU_BUTTON := 6
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _fresh() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _camp(side_name: String, profile_id: String, display_name: String) -> Node:
	var side := Node3D.new()
	side.name = side_name
	side.position.x = 200.0 * _sides.size()
	_tree().root.add_child(side)
	_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	_sides.append(side)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": profile_id, "name": display_name, "last_address": ""}
	side.add_child(camp)
	return camp


func _until(check: Callable, frames: int = 600) -> bool:
	for i in frames:
		if check.call():
			return true
		await _tree().process_frame
	return check.call()


func _done() -> void:
	DevTools.allowed = null
	for side in _sides:
		var camp: Node = side.get_child(0)
		if camp.state != null:
			camp.stop("")
	await _tree().process_frame
	for side in _sides:
		_tree().set_multiplayer(null, side.get_path())
		side.free()
	_sides.clear()
	CampSave.dir = ""


func _key(name: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = OS.find_keycode_from_string(name)
	ev.keycode = ev.physical_keycode
	ev.pressed = true
	return ev


func _pad(device: int, button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	return ev


func _stick(device: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	return ev


func _press(camp: Node, ev: InputEvent) -> void:
	camp._input(ev)
	camp._unhandled_input(ev)


## Moves the menu's choice to a row with the keyboard's down arrow (the way a player would).
func _go_to(camp: Node, id: String, ev_down: InputEvent) -> bool:
	for i in DevTools.rows().size() + 1:
		if camp.dev.row_id() == id:
			return true
		_press(camp, ev_down)
	return camp.dev.row_id() == id


## Moves the choice to a row with the down arrow; "" or why not.
func _row(camp: Node, id: String) -> String:
	return "" if _go_to(camp, id, _key("Down")) else "the dev menu has no %s row" % id


func test_every_row_has_words_and_every_value_a_name() -> String:
	_fresh()
	var camp := _camp("WordsSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	camp.toggle_dev("p_host")
	for r: Dictionary in DevTools.rows():
		var id := str(r["id"])
		if Tuning.text("dev.row." + id) == "dev.row." + id:
			why = "row %s has no name in data/text.json" % id
		elif str(r["kind"]) == "pick" and camp.dev.values(id).is_empty():
			why = "row %s has nothing to pick" % id
		for v: Variant in camp.dev.values(id):
			var shown: String = camp.dev.value_text(id, v)
			if shown.begins_with("dev.") or shown.begins_with("items.") or shown.begins_with("clock."):
				why = "row %s value %s has no words (%s)" % [id, v, shown]
	var models := Tuning.table("models")
	for m: Variant in DevTools.previews():
		if not models.has(str(m)):
			why = "the preview row offers %s, which is not a model yet" % m
	await _done()
	return why


func test_f1_opens_the_menu_and_holds_the_camper_and_closes_again() -> String:
	_fresh()
	var camp := _camp("OpenSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	_press(camp, _key("F1"))
	if not camp.dev.visible or camp.dev.who != "p_host":
		why = "F1 did not open the dev menu for player one"
	elif camp.campers["p_host"].controlled:
		why = "the camper should stand still while the dev menu is open"
	elif camp.get_node("Hud/Dev").visible or not camp.dev.stats.is_visible_in_tree():
		why = "the fps line should show in the dev menu, not on the HUD, while the menu is open"
	if why == "":
		_press(camp, _key("Escape"))
		if camp.dev.visible or not camp.campers["p_host"].controlled:
			why = "Esc should close the dev menu and give the camper back"
		elif camp.get_node("Hud/Dev").visible:
			why = "the fps line should go with the menu unless it is kept on"
	if why == "":
		_press(camp, _pad(0, CREATE))
		if not camp.dev.visible:
			why = "the DualSense's Create button did not open the dev menu"
		_press(camp, _pad(0, CREATE))
		if camp.dev.visible:
			why = "Create again should close it"
	await _done()
	return why


func test_without_dev_tools_f1_shows_only_the_fps_line() -> String:
	_fresh()
	DevTools.allowed = false
	var camp := _camp("OffSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	_press(camp, _key("F1"))
	if camp.dev.visible:
		why = "a build without dev tools opened the dev menu"
	elif not camp.get_node("Hud/Dev").visible:
		why = "F1 should still show the fps line"
	elif not camp.campers["p_host"].controlled:
		why = "the camper should keep walking"
	else:
		var before := int(camp.state.camp["coins"])
		camp.ask("dev", ["coins", null])
		if int(camp.state.camp["coins"]) != before:
			why = "the host gave coins with dev tools off"
	_press(camp, _key("F1"))
	if why == "" and camp.get_node("Hud/Dev").visible:
		why = "F1 again should hide the fps line"
	await _done()
	return why


func test_time_speed_season_day_and_sleep_from_the_keys() -> String:
	_fresh()
	var camp := _camp("TimeSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	_press(camp, _key("F1"))
	var hour: float = camp.state.day.hour()
	why = _row(camp, "hour")
	if why == "":
		for i in 3:
			_press(camp, _key("Right"))
		if absf(camp.state.day.hour() - (floor(hour) + 3.0)) > 0.01:
			why = "three steps right should move the clock on three hours, from %.2f got %.2f" % [hour, camp.state.day.hour()]
		_press(camp, _key("Left"))
		if why == "" and absf(camp.state.day.hour() - (floor(hour) + 2.0)) > 0.01:
			why = "a step left should move the clock back an hour"
	if why == "":
		why = _row(camp, "speed")
	if why == "":
		_press(camp, _key("Right"))
		var speeds: Array = Tuning.value("dev", "speeds")
		if camp.dev_speed != float(speeds[1]) or camp._clock_scale() != float(speeds[1]):
			why = "the clock speed should step to %s, got %s" % [speeds[1], camp.dev_speed]
	if why == "":
		why = _row(camp, "season")
	if why == "":
		_press(camp, _key("Right"))
		var seasons: Array = Tuning.value("day", "calendar.seasons")
		if camp.state.camp["calendar"]["season"] != seasons[1]:
			why = "the season should step to %s" % seasons[1]
	if why == "":
		why = _row(camp, "day")
	if why == "":
		_press(camp, _key("Right"))
		_press(camp, _key("Right"))
		if int(camp.state.camp["calendar"]["day"]) != 3:
			why = "the day should step from 1 to 3, got %s" % camp.state.camp["calendar"]["day"]
	if why == "":
		why = _row(camp, "sleep")
	if why == "":
		var night: int = camp.state.day.today()
		_press(camp, _key("E"))
		if int(camp.state.camp.get("last_settled", 0)) != night or camp.state.day.today() != night + 1:
			why = "sleep now should pay the night and turn to the next morning"
		elif not camp.report.visible:
			why = "sleep now should show the morning report"
	await _done()
	return why


func test_a_guest_coins_an_item_a_teleport_and_previews() -> String:
	_fresh()
	var camp := _camp("GiveSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	var down := _key("Down")
	_press(camp, _key("F1"))
	var stays: int = camp.state.camp["stays"].size()
	why = _row(camp, "guest")
	if why == "":
		_press(camp, _key("E"))
		if camp.state.camp["stays"].size() != stays + 1:
			why = "calling a guest should make a stay (with a pitch put up when none is free)"
		elif camp.visitors.size() != stays + 1:
			why = "the called guest should walk in"
	var coins := int(camp.state.camp["coins"])
	if why == "":
		why = _row(camp, "coins")
	if why == "":
		_press(camp, _key("E"))
		if int(camp.state.camp["coins"]) != coins + int(Tuning.num("dev", "coins_step")):
			why = "give coins should add %d" % Tuning.num("dev", "coins_step")
	if why == "":
		why = _row(camp, "item")
	if why == "":
		_press(camp, _key("Right"))
		var item := str(camp.dev.current("item"))
		_press(camp, _key("E"))
		if camp.state.pack.count("p_host", item) != int(Tuning.num("dev", "give_n")):
			why = "give an item should put %d %s in the Pack" % [Tuning.num("dev", "give_n"), item]
	if why == "":
		why = _row(camp, "teleport")
	if why == "":
		_press(camp, _key("Right"))
		var place := str(camp.dev.current("teleport"))
		_press(camp, _key("E"))
		var at: Array = Tuning.value("dev", "places." + place)
		var pos: Vector3 = camp.campers["p_host"].position
		if Vector2(pos.x, pos.z).distance_to(Vector2(float(at[0]), float(at[1]))) > 0.05:
			why = "go to %s should move the camper there, got %s" % [place, pos]
	if why == "":
		why = _row(camp, "preview")
	if why == "":
		_press(camp, _key("E"))
		_press(camp, _key("E"))
		var shown := _tree().get_nodes_in_group("dev_preview").filter(func(n: Node) -> bool: return camp.is_ancestor_of(n))
		if shown.size() != 2:
			why = "two presses should stand two previews beside the player, got %d" % shown.size()
		else:
			var me: Vector3 = camp.campers["p_host"].position
			for p: Camper in shown:
				if p.position.distance_to(me) > Tuning.num("dev", "preview_ahead_m") + 1.0:
					why = "a preview should stand close to the player"
		for i in camp.dev.values("preview").size():
			if str(camp.dev.current("preview")) == "":
				break
			_press(camp, _key("Right"))
		_press(camp, _key("E"))
		if why == "" and not _tree().get_nodes_in_group("dev_preview").filter(
				func(n: Node) -> bool: return camp.is_ancestor_of(n)).is_empty():
			why = "put them away should clear the previews"
	await _done()
	return why


func test_hide_the_hud_and_keep_the_fps_line() -> String:
	_fresh()
	var camp := _camp("HudSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	_press(camp, _key("F1"))
	why = _row(camp, "hud")
	if why == "":
		_press(camp, _key("E"))
		await _tree().process_frame
		if camp.get_node("Hud").visible:
			why = "hide the HUD should hide it"
		elif not camp.dev.is_visible_in_tree():
			why = "the dev menu should stay on screen with the HUD hidden"
		_press(camp, _key("E"))
		await _tree().process_frame
		if why == "" and not camp.get_node("Hud").visible:
			why = "a second press should bring the HUD back"
	if why == "":
		why = _row(camp, "stats")
	if why == "":
		_press(camp, _key("E"))
		_press(camp, _key("Escape"))
		if not camp.get_node("Hud/Dev").visible:
			why = "keep the fps line on should leave it showing after the menu closes"
	await _done()
	return why


func test_on_the_couch_each_player_opens_their_own_and_the_other_keeps_playing() -> String:
	_fresh()
	var camp := _camp("CouchSide", "p_host", "Hana")
	camp.start_solo(1)
	camp._input(_key("W"))
	camp._input(_pad(1, MENU_BUTTON))
	var why := "" if camp.couch_id != "" else "the controller did not drop in"
	var couch: String = camp.couch_id
	if why == "":
		_press(camp, _pad(1, CREATE))
		if not camp.dev.visible or camp.dev.who != couch:
			why = "the couch player's Create should open the dev menu for them"
		elif camp.campers[couch].controlled or not camp.campers["p_host"].controlled:
			why = "only the couch player's camper should stand still"
	if why == "":
		var first: String = camp.dev.row_id()
		_press(camp, _stick(1, JOY_AXIS_LEFT_Y, 0.9))
		_press(camp, _stick(1, JOY_AXIS_LEFT_Y, 0.95))
		if camp.dev.row_id() != str(DevTools.rows()[1]["id"]):
			why = "one lean of the stick should step one row down from %s, got %s" % [first, camp.dev.row_id()]
		_press(camp, _stick(1, JOY_AXIS_LEFT_Y, 0.0))
		_press(camp, _pad(1, JOY_BUTTON_DPAD_DOWN))
		if why == "" and camp.dev.row_id() != str(DevTools.rows()[2]["id"]):
			why = "the D-pad should step down a row"
	if why == "":
		# Player one's keys still belong to player one: the menu doesn't take them.
		var pick: int = camp.dev.pick
		_press(camp, _key("Down"))
		if camp.dev.pick != pick:
			why = "player one's keys moved the couch player's dev menu"
	if why == "":
		_press(camp, _key("F1"))
		if camp.dev.who != "p_host" or not camp.campers[couch].controlled:
			why = "player one's F1 should move the menu to them and free the couch player"
	if why == "":
		_press(camp, _key("Escape"))
		if camp.dev.visible:
			why = "Esc should close player one's dev menu"
	await _done()
	return why


func test_a_guest_pc_asks_and_the_host_decides() -> String:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	host.start_host(1, 24751)
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24751)
	var why := "" if await _until(func() -> bool: return guest.state != null and host.campers.size() == 2) \
			else "the guest never got in"
	if why == "":
		guest.toggle_dev("p_guest")
		_go_to(guest, "hour", _key("Down"))
		var hour: float = host.state.day.hour()
		_press(guest, _key("Right"))
		_press(guest, _key("Right"))
		if not await _until(func() -> bool: return absf(host.state.day.hour() - (floor(hour) + 2.0)) < 0.01):
			why = "the guest's time change never reached the host"
		elif not await _until(func() -> bool: return absf(guest.state.day.hour() - host.state.day.hour()) < 0.05):
			why = "the host's new time never came back to the guest PC"
	if why == "":
		var coins := int(host.state.camp["coins"])
		_go_to(guest, "coins", _key("Down"))
		_press(guest, _key("E"))
		if not await _until(func() -> bool: return int(guest.state.camp["coins"]) == coins + int(Tuning.num("dev", "coins_step"))):
			why = "the guest's coins never came back through the host"
	if why == "":
		var before: int = host.state.camp["stays"].size()
		_go_to(guest, "guest", _key("Down"))
		_press(guest, _key("E"))
		if not await _until(func() -> bool: return host.visitors.size() > before and guest.visitors.size() == host.visitors.size()):
			why = "a guest called from the guest PC should show on both PCs"
	if why == "":
		# The host's build has no dev tools now: it refuses.
		DevTools.allowed = false
		var coins := int(host.state.camp["coins"])
		guest.ask("dev", ["coins", null])
		await _until(func() -> bool: return false, 30)
		if int(host.state.camp["coins"]) != coins:
			why = "a host without dev tools gave coins"
	await _done()
	return why


func test_jump_to_each_step_of_the_arrival_evening() -> String:
	_fresh()
	var camp := _camp("StorySide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	_press(camp, _key("F1"))
	why = _row(camp, "story")
	for step: String in ["fire", "name", "done"]:
		if why != "":
			break
		while str(camp.dev.current("story")) != step:
			_press(camp, _key("Right"))
		_press(camp, _key("E"))
		if camp.state.story.step() != step:
			why = "the arrival evening should jump to %s, got %s" % [step, camp.state.story.step()]
		elif camp.state.story.lit() == (step == "fire"):
			why = "the fire should be cold only at the fire step (at %s)" % step
		else:
			_press(camp, _key("Escape"))
			if not await _until(func() -> bool: return camp.talk.visible):
				why = "Ranger Burl should say the %s lines again" % step
			camp._end_talk(true)
			camp.talk.close()
			_press(camp, _key("F1"))
			_go_to(camp, "story", _key("Down"))
	if why == "":
		why = _row(camp, "letter")
	if why == "":
		_press(camp, _key("E"))
		if not camp.report.visible:
			why = "show the letter should open Ranger Burl's letter"
	await _done()
	return why


## At a large text size the menu fits the screen with its fps line at its foot, and the rows scroll so the last
## row can still be chosen and seen.
func test_at_150_percent_the_menu_fits_and_its_rows_scroll() -> String:
	_fresh()
	var root := _tree().root
	var was_size := root.size
	var was_scale := root.content_scale_factor
	root.size = Vector2i(1920, 1080)
	root.content_scale_factor = 1.5
	var camp := _camp("BigSide", "p_host", "Hana")
	camp.start_solo(1)
	_press(camp, _key("F1"))
	var why := "" if camp.dev.visible else "F1 did not open the dev menu"
	for i in 3:
		camp._place_dev()
		await _tree().process_frame
	var view: Rect2 = camp.get_viewport().get_visible_rect()
	var menu_rect: Rect2 = camp.dev.get_global_rect()
	if why == "" and not view.encloses(menu_rect):
		why = "the menu %s should fit the screen %s" % [menu_rect, view]
	elif why == "" and camp.get_node("Hud/Dev").visible:
		why = "the HUD's fps line should give way to the menu's own"
	if why == "":
		for i in DevTools.rows().size() - 1:
			_press(camp, _key("Down"))
		for i in 3:
			await _tree().process_frame
		var last: Control = camp.dev._buttons[DevTools.rows().size() - 1]
		var shown: Rect2 = camp.dev._scroll.get_global_rect()
		if camp.dev.pick != DevTools.rows().size() - 1:
			why = "Down should reach the last row"
		elif not shown.grow(1.0).encloses(last.get_global_rect()):
			why = "the last row %s should scroll into view %s" % [last.get_global_rect(), shown]
	await _done()
	root.content_scale_factor = was_scale
	root.size = was_size
	return why
