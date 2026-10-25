extends RefCounted
## The title screen, the one Options screen and this PC's settings: every page is reachable from the title and the
## in-camp menu and always has focus; settings are saved on this PC only; remapping swaps clashes, keeps the reserved
## keys and shows up in prompts and in each couch player's own input.

const DIR := "user://test_saves/settings"
var _side: Node3D


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Starts each test from the defaults in the runner's own settings file.
func _defaults() -> void:
	for page: Dictionary in Tuning.value("settings", "pages", []):
		Settings.reset_page(str(page["id"]))


func _camp() -> Node:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)
	_side = Node3D.new()
	_side.name = "SettingsSide"
	_tree().root.add_child(_side)
	_tree().set_multiplayer(SceneMultiplayer.new(), _side.get_path())
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_settings", "name": "Tester", "last_address": ""}
	_side.add_child(camp)
	return camp


func _done(camp: Node) -> void:
	if camp.state != null:
		camp.stop("")
	await _tree().process_frame
	_tree().set_multiplayer(null, _side.get_path())
	_side.free()
	CampSave.dir = ""
	_defaults()


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _focus_in(node: Control) -> bool:
	var owner := node.get_viewport().gui_get_focus_owner()
	return owner != null and node.is_ancestor_of(owner) and owner.is_visible_in_tree()


func test_settings_are_saved_on_this_pc_and_kept_in_range() -> String:
	_defaults()
	Settings.set_value("music", 37)
	Settings.set_value("ui_scale", 999)
	Settings.set_value("window_mode", "upside_down")
	Settings.load_file(true)
	var out := ""
	if Settings.num("music") != 35.0:
		out = "music should snap to its step and come back from the file: %s" % Settings.value("music")
	elif Settings.num("ui_scale") != float(Settings.rows()["ui_scale"]["max"]):
		out = "interface size should stop at its max: %s" % Settings.value("ui_scale")
	elif Settings.value("window_mode") != Settings.default_of("window_mode"):
		out = "an unknown window mode should fall back to the default"
	elif not Settings.file.begins_with("user://"):
		out = "settings belong in user://, not the repo: " + Settings.file
	elif _tree().root.content_scale_factor != Settings.num("ui_scale") / 100.0:
		out = "interface size did not reach the window: %s" % _tree().root.content_scale_factor
	_defaults()
	if _tree().root.content_scale_factor != 1.0:
		out = "reset should put the interface size back to 100%"
	return out


func test_settings_never_go_into_the_camp_save_or_to_the_other_pc() -> String:
	var keys: Array = Settings.rows().keys() + ["binds"]
	var state := CampState.new(CampSave.new_camp())
	for key in keys:
		if state.camp.has(key) or state.shared().has(key):
			return "the camp save or the shared state holds the setting " + str(key)
	for key in keys:
		if LocalProfile.load_or_create("settings_test").has(key):
			return "the profile holds the setting " + str(key)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LocalProfile.path("settings_test")))
	return ""


func test_sound_settings_reach_their_buses() -> String:
	_defaults()
	Settings.set_value("effects", 0)
	var bus := Settings.bus_index("effects")
	var out := ""
	if AudioServer.get_bus_name(bus) != str(Tuning.value("settings", "audio_buses.effects")):
		out = "no effects bus"
	elif not AudioServer.is_bus_mute(bus):
		out = "effects at 0 should be silent"
	Settings.set_value("effects", 50)
	if out == "" and (AudioServer.is_bus_mute(bus) or absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) > 0.01):
		out = "effects at 50 should be half volume: %s dB" % AudioServer.get_bus_volume_db(bus)
	_defaults()
	return out


func test_every_option_and_action_has_words() -> String:
	var missing: PackedStringArray = []
	for page: Dictionary in Tuning.value("settings", "pages", []):
		if Tuning.text("options.tab." + str(page["id"])).begins_with("options."):
			missing.append("tab " + str(page["id"]))
		for row: Dictionary in page.get("rows", []):
			var key := str(row["key"])
			if Tuning.text("options.row." + key).begins_with("options."):
				missing.append(key)
			for option: Variant in Settings.choices(key) if row["kind"] == "choice" else []:
				var path := ("quality." + str(option)) if row.get("from", "") == "graphics" \
						else "options.choice.%s.%s" % [key, str(int(option)) if option is float else str(option)]
				if Tuning.text(path) == path:
					missing.append(path)
	for action: String in Settings.remappable():
		if Tuning.text("options.action." + action).begins_with("options."):
			missing.append("action " + action)
	return "" if missing.is_empty() else "no words for: " + ", ".join(missing)


func test_remapping_swaps_clashes_and_shows_in_prompts() -> String:
	_defaults()
	var out := ""
	var old_build: Variant = Settings.bound("build", "key")
	var swapped := Settings.bind("interact", "key", old_build)
	var built := InputMap.action_get_events("interact").any(func(e: InputEvent) -> bool:
			return e is InputEventKey and OS.get_keycode_string(e.physical_keycode) == old_build)
	if swapped != "build" or Settings.bound("build", "key") != "E":
		out = "binding interact to build's key should give build the old key: %s, %s" % [swapped, Settings.bound("build", "key")]
	elif not built:
		out = "the input map did not take the new interact key"
	elif not Prompts.fill(Tuning.text("prompt.pick_up"), false).begins_with(str(old_build)):
		out = "the prompt still names the old key: " + Prompts.fill(Tuning.text("prompt.pick_up"), false)
	if out == "":
		Settings.bind("interact", "key", "Up")
		if InputSetup.row("move_forward")["keys"] != ["W"]:
			out = "a second key taken by another action should leave it: %s" % [InputSetup.row("move_forward")["keys"]]
	if out == "":
		Settings.bind("move_forward", "key", "I")
		if not Prompts.fill("{move}", false).begins_with("I"):
			out = "walking keys in prompts should follow a remap: " + Prompts.fill("{move}", false)
	if out == "" and (not Settings.reserved("key", "Escape") or not Settings.reserved("key", "F1")):
		out = "the key that stops a remap and the dev menu's key must stay reserved"
	_defaults()
	if out == "" and (Settings.bound("interact", "key") != "E" or not Settings.binds().is_empty()):
		out = "reset should clear every remap"
	return out


func test_pad_remaps_reach_each_couch_players_own_input() -> String:
	_defaults()
	var swapped := Settings.bind("build", "pad", JOY_BUTTON_A)
	var out := ""
	if swapped != "interact" or Settings.bound("interact", "pad") != JOY_BUTTON_Y:
		out = "Cross on build should give interact Triangle: %s %s" % [swapped, Settings.bound("interact", "pad")]
	elif InputSetup.row("build")["joy_buttons"] != [JOY_BUTTON_A]:
		out = "the couch player's input (InputSetup.row) did not take the remap: %s" % [InputSetup.row("build")]
	elif Prompts.fill("{build}", true) != Settings.input_name("pad", JOY_BUTTON_A):
		out = "the pad prompt should name the new button: " + Prompts.fill("{build}", true)
	elif Settings.bound("move_forward", "pad") != null:
		out = "walking on the pad is the stick and is not remapped"
	_defaults()
	return out


func test_cross_presses_menu_buttons_and_circle_goes_back() -> String:
	_defaults()
	var camp := _camp()
	await _tree().process_frame
	await _tree().process_frame
	var menu: CampMenu = camp.menu
	var out := ""
	for pair: Array in [["ui_accept", "interact"], ["ui_cancel", "cancel"]]:
		var pads: Array[int] = []
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton:
				pads.append(ev.button_index)
		if pads != InputSetup.row(pair[1])["joy_buttons"]:
			out = "%s should take %s's pad buttons, got %s" % [pair[0], pair[1], pads]
	if out == "":
		menu._first_title.grab_focus()
		for pressed in [true, false]:
			var ev := InputEventJoypadButton.new()
			ev.device = 0
			ev.button_index = JOY_BUTTON_A
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _tree().process_frame
		await _tree().process_frame
		if menu.page() != "start":
			out = "Cross on the focused Start game button should open the start page (page %s)" % menu.page()
	await _done(camp)
	return out


func test_title_start_options_and_back_with_focus_on_every_page() -> String:
	_defaults()
	var camp := _camp()
	await _tree().process_frame
	await _tree().process_frame
	var menu: CampMenu = camp.menu
	var out := ""
	if menu.page() != "title" or not _focus_in(menu):
		out = "the game should open on the title with a button in focus (page %s)" % menu.page()
	if out == "":
		menu._first_title.pressed.emit()
		await _tree().process_frame
		if menu.page() != "start" or not _focus_in(menu):
			out = "Start game should open the start page with focus"
	if out == "":
		_tree().root.push_input(_key(KEY_ESCAPE))
		await _tree().process_frame
		if menu.page() != "title":
			out = "cancel on the start page should go back to the title, not %s" % menu.page()
	if out == "":
		menu.show_options("controls", "title")
		await _tree().process_frame
		await _tree().process_frame
		if menu.page() != "options" or menu.options.page() != "controls" or not _focus_in(menu.options):
			out = "Controls on the title should open Options at the controls tab with focus"
	if out == "":
		_tree().root.push_input(_key(KEY_ESCAPE))
		await _tree().process_frame
		if menu.page() != "title":
			out = "cancel in Options should go back to the title, not %s" % menu.page()
	await _done(camp)
	return out


func test_options_from_the_camp_menu_rebinds_and_goes_back() -> String:
	_defaults()
	var camp := _camp()
	await _tree().process_frame
	camp.start_solo(1)
	await _tree().process_frame
	camp.report.visible = false
	camp._open_menu()
	var menu: CampMenu = camp.menu
	menu.show_options("controls", "pause")
	await _tree().process_frame
	var out := ""
	var options: OptionsScreen = menu.options
	options.bind_button("undo", "key").pressed.emit()
	if not options.waiting():
		out = "choosing a key button should wait for the new key"
	if out == "":
		_tree().root.push_input(_key(KEY_U))
		await _tree().process_frame
		if Settings.bound("undo", "key") != "U" or options.waiting():
			out = "pressing U should bind undo to U: %s" % Settings.bound("undo", "key")
		elif options.bind_button("undo", "key").text != "U" or not _focus_in(options):
			out = "the controls page should show U and keep focus on it"
	if out == "":
		options.bind_button("undo", "key").pressed.emit()
		_tree().root.push_input(_key(KEY_ESCAPE))
		await _tree().process_frame
		if Settings.bound("undo", "key") != "U" or options.waiting() or menu.page() != "options":
			out = "the stop key should keep the old key and stay on Options"
	if out == "":
		var before := Quality.current
		options.step_choice("picture", 1)
		await _tree().process_frame
		if Quality.current != before or options.pending() != ["picture"] or options._apply.disabled:
			out = "a picture change should wait for Apply: %s, waiting %s" % [Quality.current, options.pending()]
		else:
			options._apply.pressed.emit()
			await _tree().process_frame
			if Quality.current != str(Settings.value("picture")) or not options.pending().is_empty():
				out = "Apply should take the picture preset to the camp's views: %s vs %s" % [Quality.current,
						Settings.value("picture")]
	if out == "":
		# A change left without Apply goes back when Options closes.
		var kept: Variant = Settings.value("window_size")
		options.step_choice("window_size", 1)
		options.close()
		if Settings.value("window_size") != kept:
			out = "leaving Options without Apply should put the window size back, got %s" % Settings.value("window_size")
		menu.show_options("picture", "pause")
	if out == "":
		_tree().root.push_input(_key(KEY_ESCAPE))
		await _tree().process_frame
		if menu.page() != "pause" or not menu.visible:
			out = "back from Options should return to the in-camp menu, not %s" % menu.page()
	camp.apply_quality(str(Quality.names()[0]), false)
	await _done(camp)
	return out


## The start page's own button for an action ("solo", "host"), found by its words.
func _start_button(menu: CampMenu, action: String) -> Button:
	for c in menu._start.get_children():
		if c is Button and c.text == Tuning.text("menu." + action):
			return c
	return null


func test_play_alone_and_host_start_from_the_menu_buttons() -> String:
	_defaults()
	var out := ""
	for row in [["solo", 2], ["host", 1]]:
		var camp := _camp()
		await _tree().process_frame
		var menu: CampMenu = camp.menu
		menu._first_title.pressed.emit()
		menu.slot_pick.select(int(row[1]) - 1)
		var b := _start_button(menu, str(row[0]))
		if b == null:
			out = "no %s button on the start page" % row[0]
		else:
			b.pressed.emit()
			await _tree().process_frame
			if camp.state == null:
				out = "%s from the menu did not start a camp" % row[0]
			elif camp.slot != int(row[1]):
				out = "%s should use the camp slot picked on the start page (%d), not %s" % [row[0], row[1], camp.slot]
		await _done(camp)
		if out != "":
			break
	return out
