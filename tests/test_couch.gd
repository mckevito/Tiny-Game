extends RefCounted
## Milestone 3: couch drop-in and drop-out on one PC, the dynamic split screen, link codes that move a couch character
## to its own PC, two players in total, and the picture presets for the weakest PC.

const DIR := "user://test_saves/couch"
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


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _done() -> void:
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


func _pad_button(device: int, button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	return ev


func _stick(device: int) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 1.0
	return ev


## A solo camp with a second controller dropped in.
func _couch() -> Node:
	_fresh()
	var camp := _camp("CouchSide", "p_host", "Hana")
	camp.start_solo(1)
	camp._input(_stick(0))
	camp._input(_pad_button(1, MENU_BUTTON))
	return camp


func test_split_aims_merge_close_and_lean_apart() -> String:
	var split_m := Tuning.num("tuning", "couch.split_m")
	var a := Vector3(0, 0, 0)
	var close := CouchView.aims(a, Vector3(split_m * 0.5, 0, 0), split_m)
	if not (close[0].is_equal_approx(close[1]) and close[0].is_equal_approx(Vector3(split_m * 0.25, 0, 0))):
		return "close players should share one aim at their middle, got %s" % [close]
	var edge := CouchView.aims(a, Vector3(split_m + 0.001, 0, 0), split_m)
	if edge[0].distance_to(edge[1]) > 0.01:
		return "at the split distance both halves should still look at the same place (no jump), got %s" % [edge]
	var far := CouchView.aims(a, Vector3(0, 0, split_m * 3.0), split_m)
	if not (far[0].is_equal_approx(Vector3(0, 0, split_m * 0.5)) and far[1].is_equal_approx(Vector3(0, 0, split_m * 2.5))):
		return "apart, each half should follow its own player leaning toward the other, got %s" % [far]
	return ""


func test_screen_direction_matches_the_camera() -> String:
	var cam := PlayCamera.new()
	_tree().root.add_child(cam)
	var why := ""
	for yaw in [0.0, 0.7, 2.4, -1.9]:
		cam.yaw = yaw
		cam._focus = Vector3.ZERO
		cam._place()
		for ground in [Vector3(4, 0, 0), Vector3(0, 0, 4), Vector3(-3, 0, 2)]:
			var seen: Vector2 = cam.unproject_position(ground) - cam.unproject_position(-ground)
			var want := CouchView.screen_dir(ground, yaw, deg_to_rad(Tuning.num("tuning", "camera.pitch_deg")))
			if seen.normalized().angle_to(want) > deg_to_rad(12.0):
				why = "yaw %s, ground %s: screen shows %s, split line uses %s" % [yaw, ground, seen.normalized(), want]
	cam.free()
	return why


func test_a_free_controller_drops_in_and_out() -> String:
	var camp := _couch()
	var why := ""
	var id: String = camp.couch_id
	if id == "" or camp.campers.size() != 2 or camp.state.online.size() != 2:
		why = "a second controller's menu button did not drop a couch player in"
	elif camp.couch_pad != 1:
		why = "the couch player should own controller 1"
	elif not (camp.campers[id].controlled and camp.campers["p_host"].controlled):
		why = "both couch players should steer their campers"
	elif not camp.campers[id].input.owns_event(_stick(1)) or camp.campers[id].input.owns_event(_stick(0)):
		why = "the couch camper should listen to controller 1 only"
	elif camp.campers["p_host"].input.owns_event(_stick(1)) or not camp.campers["p_host"].input.owns_event(_stick(0)):
		why = "player one should keep their controller and leave controller 1 alone"
	elif camp.owner_of(_pad_button(1, 0)) != id or camp.owner_of(_pad_button(0, 0)) != "p_host":
		why = "buttons should go to the player whose controller pressed them"
	if why == "":
		var p: Dictionary = camp.state.camp["profiles"][id]
		if not (bool(p["couch"]) and CampState.normalize_code(p["link_code"]).length() == int(Tuning.num("net", "link_code_length"))):
			why = "a new couch character should be marked couch and get a link code"
	if why == "":
		camp._open_menu(id)
		if camp.campers[id].controlled or not camp.campers["p_host"].controlled:
			why = "the couch player's menu should pause only the couch player"
		camp._on_menu("leave_couch")
	if why == "" and (camp.couch_id != "" or camp.campers.size() != 1 or camp.state.online.size() != 1):
		why = "hopping off the couch did not drop the couch player out"
	if why == "" and not CampSave.load_slot(1)["camp"]["profiles"].has(id):
		why = "the couch character is not in the host's save"
	if why == "":
		camp._input(_pad_button(1, MENU_BUTTON))
		if camp.couch_id != id or camp.state.camp["profiles"].size() != 2:
			why = "dropping in again should bring back the same couch character"
	await _done()
	return why


func test_player_ones_own_controller_opens_the_menu_not_a_drop_in() -> String:
	_fresh()
	var camp := _camp("SoloSide", "p_host", "Hana")
	camp.start_solo(1)
	camp._input(_stick(0))
	camp._input(_pad_button(0, MENU_BUTTON))
	var why := "" if camp.couch_id == "" else "player one's own controller dropped in a second player"
	await _done()
	return why


func test_couch_players_carry_with_their_own_button() -> String:
	var camp := _couch()
	var id: String = camp.couch_id
	var chair: Vector2 = camp.state.object_pos("chair_teal_1")
	var c: Camper = camp.campers[id]
	c.position = Vector3(chair.x, c.position.y, chair.y - 0.6)
	camp.campers["p_host"].position = Vector3(chair.x + 6.0, 0, chair.y)
	await _frames(2)
	var ev := _pad_button(1, 0)
	camp._unhandled_input(ev)
	var why := ""
	if camp.state.carriers.get("chair_teal_1", "") != id:
		why = "the couch player's Cross did not pick up the chair for the couch player"
	elif camp.state.carried_by("p_host") != "":
		why = "player one picked something up too"
	await _done()
	return why


func test_split_screen_splits_apart_and_merges_together() -> String:
	var camp := _couch()
	var view: CouchView = camp.couch
	var p1: Camper = camp.campers["p_host"]
	var p2: Camper = camp.campers[camp.couch_id]
	var split_m := Tuning.num("tuning", "couch.split_m")
	var why := ""
	p1.position = Vector3(-1, p1.position.y, 0)
	p2.position = Vector3(1, p2.position.y, 0)
	await _frames(3)
	if view.split:
		why = "two close players should share one view"
	if why == "":
		p2.position = Vector3(-1 + split_m * 1.8, p2.position.y, 3)
		if not await _until(func() -> bool: return view.split, 30):
			why = "the screen did not split when the players walked apart"
	if why == "":
		await _frames(120)
		var mat: ShaderMaterial = view._overlay.material
		var dir: Vector2 = mat.get_shader_parameter("dir")
		var centre := Vector2(camp.get_viewport().get_visible_rect().size) * 0.5
		var cam1: PlayCamera = camp.camera
		var cam2: PlayCamera = view.second_camera()
		var size2 := Vector2(view.second_view().size) * 0.5
		if (cam1.unproject_position(p1.global_position) - centre).dot(dir) >= 0.0:
			why = "player one is not on their own side of the split"
		elif (cam2.unproject_position(p2.global_position) - size2).dot(dir) <= 0.0:
			why = "player two is not on their own side of the split"
		elif (cam1.unproject_position(p1.global_position) - centre).abs().x > centre.x \
				or (cam2.unproject_position(p2.global_position) - size2).abs().x > size2.x:
			why = "a player is off their own half of the screen"
		elif not view._overlay.visible:
			why = "the second half is not drawn"
		elif not is_equal_approx(view.second_view().scaling_3d_scale, Quality.render_scale(true)):
			why = "split, both halves should use the preset's split render scale"
	if why == "":
		p2.position = Vector3(0.5, p2.position.y, 0)
		if not await _until(func() -> bool: return not view.split, 30):
			why = "the screen did not merge when the players came back together"
		elif view.second_view().render_target_update_mode != SubViewport.UPDATE_DISABLED:
			why = "the second view should stop drawing once merged (one view costs half as much)"
		elif not is_equal_approx(camp.get_viewport().scaling_3d_scale, Quality.render_scale(false)):
			why = "merged, the view should go back to the preset's full render scale"
	await _done()
	return why


func _pair(port: int) -> Array:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, port)
	return [host, why]


func test_two_players_in_total_across_couch_and_online() -> String:
	var pair := _pair(24721)
	var host: Node = pair[0]
	var why: String = pair[1]
	var heard: Array[String] = []
	if why == "":
		host._input(_stick(0))
		host._input(_pad_button(1, MENU_BUTTON))
		if host.couch_id == "":
			why = "the couch player could not drop in on the host"
	if why == "":
		var guest := _camp("GuestSide", "p_guest", "Gus")
		guest.stopped.connect(func(reason: String) -> void: heard.append(reason))
		guest.start_join("127.0.0.1", 24721)
		if not await _until(func() -> bool: return not heard.is_empty()):
			why = "the guest PC heard nothing"
		elif heard[0] != "join.full":
			why = "with a couch player, a guest PC should be told the camp is full, not " + heard[0]
	if why == "":
		host.drop_out(host.couch_id)
		var guest2 := _camp("GuestSide2", "p_guest", "Gus")
		guest2.start_join("127.0.0.1", 24721)
		if not await _until(func() -> bool: return guest2.state != null):
			why = "the guest could not join once the couch was free"
		elif host.drop_in(2) != "join.full" or host.couch_id != "":
			why = "with a guest PC in, a couch controller should not drop in"
	await _done()
	return why


func test_a_link_code_moves_the_couch_character_to_its_own_pc() -> String:
	var pair := _pair(24722)
	var host: Node = pair[0]
	var why: String = pair[1]
	var heard: Array[String] = []
	var couch_id := ""
	var code := ""
	if why == "":
		host._input(_stick(0))
		host._input(_pad_button(1, MENU_BUTTON))
		couch_id = host.couch_id
		code = str(host.state.camp["profiles"].get(couch_id, {}).get("link_code", ""))
		if code == "":
			why = "the couch character has no link code"
	if why == "":
		var wrong := _camp("WrongSide", "p_other", "Oz")
		wrong.stopped.connect(func(reason: String) -> void: heard.append(reason))
		var bad := "A".repeat(code.length()) if code != "A".repeat(code.length()) else "C".repeat(code.length())
		wrong.start_join("127.0.0.1", 24722, bad)
		if not await _until(func() -> bool: return not heard.is_empty()):
			why = "a wrong link code got no answer"
		elif heard[0] != "join.bad_link":
			why = "a wrong link code was told " + heard[0]
		elif host.couch_id != couch_id:
			why = "a wrong link code took the couch player off the couch"
	if why == "":
		var pc := _camp("OwnPcSide", "p_partner_pc", "Pat")
		pc.start_join("127.0.0.1", 24722, CampState.show_code(code).to_lower())
		if not await _until(func() -> bool: return pc.state != null):
			why = "the couch character's own PC could not join with the link code"
		elif pc.profile["id"] != couch_id:
			why = "the PC did not take over the couch character's profile ID"
		elif host.couch_id != "" or host.state.online.size() != 2 or not host._guests.values().has(couch_id):
			why = "the host should hand the character from its couch to the PC"
		elif host.state.camp["profiles"].size() != 2:
			why = "linking made a new character instead of moving the couch one"
		elif host.state.camp["profiles"][couch_id]["link_code"] != "" or host.state.camp["profiles"][couch_id]["couch"]:
			why = "a used link code should be cleared so it cannot be used again"
		elif not CampSave.load_slot(1)["camp"]["profiles"][couch_id]["link_code"] == "":
			why = "the host's save still holds the used link code"
	await _done()
	return why


func test_link_codes_are_easy_to_read_and_type() -> String:
	var state := CampState.new(CampSave.new_camp())
	var letters := str(Tuning.value("net", "link_code_letters"))
	for look_alike in ["0", "O", "1", "I", "L", "5", "S", "2", "Z", "8", "B"]:
		if letters.contains(look_alike):
			return "link codes should not use the look-alike " + look_alike
	var code := state.new_link_code()
	if CampState.normalize_code(" %s " % CampState.show_code(code).to_lower()) != code:
		return "typing a code in lower case with its dash should still match"
	return ""


func test_picture_presets_apply_to_every_view() -> String:
	_fresh()
	var camp := _camp("QualitySide", "p_host", "Hana")
	var why := ""
	for name: String in Quality.names():
		for key in ["render_scale", "split_render_scale", "fxaa", "ssao", "glow", "shadow_splits", "shadow_atlas_px", "shadow_distance_m"]:
			if not Quality.preset(name).has(key):
				why = "preset %s has no %s" % [name, key]
	if why == "" and not Quality.names().has("low"):
		why = "there is no low preset for the weakest PC"
	if why == "":
		camp.apply_quality("low", false)
		var low := Quality.preset("low")
		if not is_equal_approx(camp.get_viewport().scaling_3d_scale, float(low["render_scale"])):
			why = "low did not lower the render scale"
		elif not is_equal_approx(camp.couch.second_view().scaling_3d_scale, float(low["render_scale"])):
			why = "low did not reach the couch's second view"
		elif camp.get_node("World").environment.ssao_enabled:
			why = "low should turn ambient occlusion off"
	camp.apply_quality(str(Quality.names()[0]), false)
	await _done()
	return why
