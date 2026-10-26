extends RefCounted
## The arrival evening (owner picks, 26 Oct 2026): Ranger Burl's letter on a new camp, the cold fire he asks the
## players to light, naming the camp, the clipboard handover, and the sign that can be repainted any time; as rules,
## from the buttons, and on a guest PC over ENet (data/ranger.json).

const DIR := "user://test_saves/story"
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _state() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func _fire() -> Vector2:
	return Vector2(0.0, -1.2)


func _by_ranger() -> Vector2:
	return CampStory.ranger_pos() + Vector2(-0.6, -0.6)


func _by_sign() -> Vector2:
	return CampStory.sign_pos() + Vector2(0.0, -0.9)


func test_only_a_new_camp_from_the_menu_starts_cold() -> String:
	var s := _state()
	if s.story.step() != "done" or not s.story.lit():
		return "a camp made any other way (tests, older saves) should skip the arrival evening"
	var old := CampSave.new_camp()
	old.erase("story")
	old.erase("names")
	old["version"] = 7
	var camp := CampSave.upgrade(old)
	if str(camp["story"]["step"]) != "done" or str(camp["names"]["camp"]) != "":
		return "a version 7 save should open with its fire burning and the default name"
	s.story.begin()
	if s.story.lit() or CampStory.words(s.story.missing()) != CampStory.words(CampStory.needs()):
		return "the arrival evening should start with a cold fire that needs data/ranger.json fire"
	s.pack.add("p_host", "perch", 1)
	s.pack.add("p_host", "wood", 2)
	s.set_player_pos("p_host", _fire(), 0.0)
	if s.pack.cook("p_host") != "deny.fire_cold":
		return "nothing grills on a cold fire"
	if s.build.upgrade_fire("p_host") != "deny.fire_cold":
		return "a cold fire can't be upgraded"
	return ""


func test_the_fire_lights_from_both_packs_and_the_box_then_the_camp_takes_a_name() -> String:
	var s := _state()
	s.story.begin()
	var sticks := int(CampStory.needs().get("stick", 0))
	if sticks < 2 or int(CampStory.needs().get("wood", 0)) < 1:
		return "this test expects the fire to need at least 2 sticks and a wood"
	s.pack.add("p_host", "stick", 1)
	s.set_player_pos("p_host", Vector2(20, 20), 0.0)
	if s.story.feed_fire("p_host") != "deny.too_far":
		return "only a player at the fire can lay on sticks"
	s.set_player_pos("p_host", _fire(), 0.0)
	if s.story.feed_fire("p_host") != "" or s.pack.count("p_host", "stick") != 0 or s.story.lit():
		return "one stick should go on and leave the fire still cold"
	if s.story.feed_fire("p_host") != "deny.nothing_for_fire":
		return "with nothing the fire needs, the press should say so"
	if not CampStory.words(s.story.missing()).contains(Tuning.text("items.stick")):
		return "what is still missing should name the sticks: " + CampStory.words(s.story.missing())
	s.pack.add("p_guest", "stick", sticks + 4)
	s.pack.add_to_box("wood", 3)
	s.set_player_pos("p_guest", _fire(), 0.0)
	if s.story.feed_fire("p_guest") != "" or not s.story.lit() or s.story.step() != "name":
		return "the guest's sticks and the camp box's wood should light the fire"
	if s.pack.count("p_guest", "stick") != 5 or s.pack.box_count("wood") != 3 - int(CampStory.needs()["wood"]):
		return "lighting the fire should take only what it still needed"
	if s.story.feed_fire("p_guest") != "deny.fire_lit_already":
		return "a burning fire takes no more"
	s.set_player_pos("p_host", Vector2(20, 20), 0.0)
	if s.story.name_camp("p_host", "   ") != "deny.name_empty":
		return "a camp name needs a letter"
	if s.story.name_camp("p_host", "  Pinecone \n Point  ") != "" or s.story.camp_name() != "Pinecone Point" \
			or s.story.step() != "done":
		return "the name should be tidied up and finish the arrival evening: " + s.story.camp_name()
	if s.story.name_camp("p_host", "Again") != "deny.too_far":
		return "after the evening the name changes only at the sign"
	s.set_player_pos("p_host", _by_sign(), 0.0)
	var long := "Thimble Hollow Campground And Fishing Lodge"
	if s.story.name_camp("p_host", long) != "" or s.story.camp_name().length() > int(Tuning.num("ranger", "name_max")):
		return "the sign should take a new name any time, cut to name_max letters"
	var saved := CampSave.upgrade(JSON.parse_string(JSON.stringify(s.camp)))
	if str(saved["names"]["camp"]) != s.story.camp_name() or str(saved["story"]["step"]) != "done":
		return "the name and the finished evening should survive a save"
	return ""


func test_nothing_is_built_over_the_camp_sign() -> String:
	var s := _state()
	var at := CampStory.sign_pos()
	for kind: String in ["pitch", "log_bench"]:
		for yaw: float in [0.0, 90.0]:
			if s.build.check(kind, at, yaw) == "":
				return "a %s should not go over the camp sign (data/build.json blockers camp_sign)" % kind
	if s.build.check("log_bench", at + Vector2(0.0, 0.5), 0.0) == "":
		return "a bench half a metre from the sign should be refused"
	return ""


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


func _clean() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _stand(camp: Node, who: String, at: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.position = Vector3(at.x, c.position.y, at.y)
	camp.state.set_player_pos(who, at, 0.0)


func _press(camp: Node, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	camp._unhandled_input(press)


## A real key press through Godot's input, as a player's keyboard sends it (with its letter).
func _type(code: Key, letter: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = letter
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _fire_node(camp: Node) -> Node3D:
	return camp.clearing.placed[Tuning.table("clearing")["placements"].map(
			func(r: Dictionary) -> String: return r["model"]).find("fire_pit")]


func test_a_new_camp_opens_with_the_letter_and_the_evening_plays_from_the_buttons() -> String:
	_clean()
	var camp := _camp("Solo", "p_host", "Hana")
	camp.menu.slot_pick.select(0)
	camp._on_menu("solo")
	var why := ""
	if camp.state == null or camp.state.story.step() != "fire":
		why = "starting a new camp from the menu should begin the arrival evening"
	elif not camp.report.visible or not camp.report.text().contains(camp.story_text(Tuning.text("story.letter")).left(40)):
		why = "the first thing a new camp shows should be the ranger's letter"
	elif camp.ranger == null or not camp.ranger.get_node("Mark").visible:
		why = "Ranger Burl should stand in the camp with a '!' over him"
	elif (_fire_node(camp).get_child(0) as MeshInstance3D).mesh != FeltBuilder.mesh("fire_pit_cold"):
		why = "the fire should be cold until it is lit"
	elif not camp.today_lines().contains(Tuning.text("hud.fire_job").split("%")[0]):
		why = "the HUD's list should say what the fire needs"
	if why == "":
		_press(camp, "interact")
		if not await _until(func() -> bool: return camp.talk.visible):
			why = "after the letter, the ranger should greet the players"
		elif not camp.talk.line().contains(camp.story_text(Tuning.text("ranger.hello")).left(20)):
			why = "his first line should be his hello: " + camp.talk.line()
		elif camp.campers["p_host"].controlled:
			why = "the player should stand still while he talks"
		elif camp.ranger.model_id != str(Tuning.value("ranger", "talk_model")):
			why = "Burl should take his talking pose while he speaks"
	if why == "":
		var keys: Array = Tuning.value("ranger", "lines.fire")
		for i in keys.size():
			_press(camp, "interact")
		if camp.talk.visible or not camp.campers["p_host"].controlled:
			why = "pressing through his lines should close the bubble and free the player"
		elif camp.ranger.model_id != str(Tuning.value("ranger", "model")):
			why = "Burl should stand as before once he stops talking"
	if why == "":
		var cold_hint: String = camp.state.camp["story"]["step"]
		camp.state.pack.add("p_host", "stick", 9)
		camp.state.pack.add("p_host", "wood", 2)
		_stand(camp, "p_host", _fire())
		if camp.action_for("p_host").get("what", "") != "feed_fire":
			why = "at the cold fire with sticks and wood, interact should feed it (step %s): %s" % [cold_hint, camp.action_for("p_host")]
		else:
			camp.interact("p_host")
			if not camp.state.story.lit():
				why = "feeding the fire everything it needs should light it"
			elif (_fire_node(camp).get_child(0) as MeshInstance3D).mesh != FeltBuilder.mesh("fire_pit"):
				why = "the fire on screen should burn once lit"
	if why == "":
		if not await _until(func() -> bool: return camp.talk.visible):
			why = "the lit fire should bring the ranger's next lines"
		else:
			var keys: Array = Tuning.value("ranger", "lines.name")
			for i in keys.size():
				_press(camp, "interact")
			if not camp.talk.asking_name():
				why = "after his lines about the fire, the bubble should ask for the camp's name"
			elif camp.talk.typed() != Tuning.text("names.camp"):
				why = "the name line should start from the default name"
	if why == "":
		if camp._docks.values().any(func(d: Control) -> bool: return d.visible) or camp.get_node("Hud/Prompt").visible:
			why = "the docks and the prompt line should make way while Burl talks (Playtest, couch at 150%)"
		elif not camp.talk._hint.text.contains("Enter") or camp.talk._hint.text.contains("[E]"):
			why = "on the keyboard the name line should say Enter finishes it, since E types a letter: " + camp.talk._hint.text
	if why == "":
		# A real E key while the line has focus types a letter and keeps the line open (Playtest: "Pine Edgee").
		await _tree().process_frame
		camp.talk.entry().text = "Pine Edg"
		camp.talk.entry().deselect()
		camp.talk.entry().caret_column = camp.talk.entry().text.length()
		await _tree().process_frame
		_type(KEY_E, "e".unicode_at(0))
		await _tree().process_frame
		if camp.talk.typed() != "Pine Edge" or not camp.talk.asking_name():
			why = "E should type a letter into the name, not finish it: " + camp.talk.typed()
	if why == "":
		camp.talk.entry().text = "Pinecone Point"
		_type(KEY_ENTER, 0)
		await _tree().process_frame
		if camp.state.story.camp_name() != "Pinecone Point" or camp.state.story.step() != "done":
			why = "interact should paint the typed name and finish the evening"
		elif str(camp.clearing.placed[CampStory.sign_index()].get_node("Name").text) != "Pinecone Point":
			why = "the camp sign should show the new name"
	if why == "":
		if not await _until(func() -> bool: return camp.talk.visible and not camp.talk.asking_name()):
			why = "the ranger should thank them and hand over his clipboard"
		else:
			var keys: Array = Tuning.value("ranger", "lines.done")
			for i in keys.size():
				_press(camp, "interact")
			if not camp._boards.has("p_host"):
				why = "the handover should end with the clipboard open"
			elif camp.ranger.get_node("Mark").visible:
				why = "the '!' should go once the evening is over"
	if why == "":
		camp.toggle_clipboard("p_host")
		_stand(camp, "p_host", _by_ranger())
		if camp.action_for("p_host").get("what", "") != "talk":
			why = "beside the ranger, interact should talk to him"
		else:
			camp.interact("p_host")
			if not camp.talk.visible or camp.talk.line() == "":
				why = "talking to him afterwards should give one of his everyday lines"
			_press(camp, "cancel")
	if why == "":
		_stand(camp, "p_host", _by_sign())
		if camp.action_for("p_host").get("what", "") != "sign":
			why = "at the camp sign, interact should repaint it: %s" % camp.action_for("p_host")
		else:
			camp.interact("p_host")
			_press(camp, "cancel")
			if camp.talk.visible or camp.state.story.camp_name() != "Pinecone Point":
				why = "cancel at the sign should keep the name as it is"
	if why == "":
		var reopened := CampSave.load_slot(1)
		if str(reopened["camp"]["names"]["camp"]) != "Pinecone Point":
			why = "the camp's name should be saved"
	await _done()
	return why


func test_the_guest_pc_reads_the_letter_and_lights_the_fire_through_the_host() -> String:
	_clean()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24751)
	host._fresh = true
	host._begin_story()
	host.report.visible = false
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24751)
	if not await _until(func() -> bool: return guest.state != null and host.campers.size() == 2):
		why = "the guest never got in"
	elif not guest.report.visible or not guest.report.text().contains(Tuning.text("story.letter").left(20)):
		why = "the guest PC should read the ranger's letter too"
	if why == "":
		guest.report.visible = false
		var fire: Node3D = _fire_node(guest)
		if (fire.get_child(0) as MeshInstance3D).mesh != FeltBuilder.mesh("fire_pit_cold"):
			why = "the guest PC should see the cold fire"
		host.state.pack.add("p_guest", "stick", 9)
		host.state.pack.add("p_guest", "wood", 2)
		host._share()
		await _until(func() -> bool: return guest.state.pack.count("p_guest", "wood") == 2)
		_stand(guest, "p_guest", _fire())
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_fire()) < 0.1)
		guest.interact("p_guest")
		if why != "":
			pass
		elif not await _until(func() -> bool: return guest.state.story.lit() and host.state.story.lit()):
			why = "the guest's sticks should light the fire through the host"
		elif not await _until(func() -> bool: return (fire.get_child(0) as MeshInstance3D).mesh == FeltBuilder.mesh("fire_pit")):
			why = "the guest PC should see the fire burn"
	if why == "":
		_stand(guest, "p_guest", _by_ranger())
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_by_ranger()) < 0.1)
		guest.ask("name_camp", ["Bramble Bend"], "p_guest")
		if not await _until(func() -> bool: return guest.state.story.camp_name() == "Bramble Bend"):
			why = "the guest should name the camp through the host"
		elif not await _until(func() -> bool: return str(guest.clearing.placed[CampStory.sign_index()].get_node("Name").text) == "Bramble Bend"):
			why = "the guest PC's sign should show the new name"
		elif host.state.story.step() != "done":
			why = "naming the camp on the guest PC should finish the evening for both"
	await _done()
	return why
