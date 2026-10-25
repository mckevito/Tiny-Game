extends RefCounted
## Stage A in the real camp scene: build mode on the grid with undo, a guest who walks to the pitch and puts up a
## tent, bed from the menu (both couch players), and over ENet a night that pays exactly once even when the guest PC
## leaves and comes back.

const DIR := "user://test_saves/stage_a"
const OPEN := Vector2(-3.2, 7.9)
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


func _at_hour(camp: Node, hour: float) -> void:
	camp.state.camp["calendar"]["minute"] = (hour - Tuning.num("day", "clock.start_hour")) * 60.0


## Stands a camper so that their build spot is `spot`, facing -Z.
func _face_spot(camp: Node, who: String, spot: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.rotation.y = 0.0
	c.position = Vector3(spot.x, c.position.y, spot.y + Tuning.num("build", "ahead_m"))


func _key(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = OS.find_keycode_from_string(str(Tuning.value("input", "actions.%s.keys" % action)[0]))
	ev.pressed = true
	return ev


func test_build_mode_builds_on_the_grid_and_undoes() -> String:
	_fresh()
	var camp := _camp("BuildSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	var start := int(camp.state.camp["coins"])
	camp._unhandled_input(_key("build"))
	if not camp._building.has("p_host"):
		why = "the build button did not start build mode"
	if why == "":
		_face_spot(camp, "p_host", CampBuild.snap(OPEN))
		await _tree().process_frame
		var ghost: Node3D = camp._building["p_host"]["ghost"]
		if Vector2(ghost.position.x, ghost.position.z).distance_to(CampBuild.snap(OPEN)) > 0.01:
			why = "the ghost should sit on the grid spot in front of the player"
		elif not camp.get_node("Hud/Prompt").text.contains(str(CampBuild.cost("pitch"))):
			why = "the build prompt should name the price, got " + camp.get_node("Hud/Prompt").text
	if why == "":
		camp._unhandled_input(_key("rotate"))
		camp._unhandled_input(_key("interact"))
		var id: String = camp.state.build.last_id
		if not (camp.objects.has(id) and int(camp.state.camp["coins"]) == start - CampBuild.cost("pitch")):
			why = "interact in build mode should build a paid pitch with a node"
		elif float(camp.state.camp["objects"][id]["yaw"]) != 90.0:
			why = "rotate should turn the pitch a quarter turn"
		elif camp.state.carried_by("p_host") != "":
			why = "build mode should not pick things up"
		elif not CampSave.load_slot(1)["camp"]["objects"].has(id):
			why = "the new pitch should be in the save"
		else:
			camp._unhandled_input(_key("undo"))
			await _tree().process_frame
			if camp.objects.has(id) or camp.state.camp["objects"].has(id) or int(camp.state.camp["coins"]) != start:
				why = "undo should take the pitch and its node away at a full refund"
	if why == "":
		camp._unhandled_input(_key("build"))
		if camp._building.has("p_host") or camp.find_children("Ghost_*", "", false, false).size() > 0:
			why = "the build button should end build mode and take the ghost away"
	await _done()
	return why


func test_a_guest_walks_to_the_pitch_and_puts_up_a_tent() -> String:
	_fresh()
	var camp := _camp("GuestSide", "p_host", "Hana")
	camp.start_solo(1)
	var why: String = camp.state.build.build("p_host", "pitch", OPEN, 0.0)
	camp._show_object(camp.state.build.last_id)
	_at_hour(camp, Tuning.num("day", "stays.arrive_hour"))
	await _tree().process_frame
	if why == "" and camp.visitors.size() != 1:
		why = "a guest should come to the free pitch at the arrival hour"
	if why == "":
		var stay: String = camp.visitors.keys()[0]
		var c: Camper = camp.visitors[stay]
		var entry: Array = Tuning.value("day", "stays.entry")
		if c.position.distance_to(Vector3(float(entry[0]), 0, float(entry[1]))) > 0.5 or not c.walk_target is Vector3:
			why = "the guest should walk in from the camp's entry"
		elif camp._tents.has(stay):
			why = "the tent should go up when the guest reaches the pitch, not before"
		else:
			c.walk_speed = 200.0
			if not await _until(func() -> bool: return camp._tents.has(stay), 300):
				why = "the guest never put up their tent"
			elif not camp.get_node("Hud/Clock").text.contains(str(int(camp.state.camp["coins"]))):
				why = "the clock line should show the coins"
	await _done()
	return why


func test_bed_from_the_menu_needs_both_couch_players() -> String:
	_fresh()
	var camp := _camp("CouchSide", "p_host", "Hana")
	camp.start_solo(1)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	camp._input(stick)
	var menu_button := InputEventJoypadButton.new()
	menu_button.device = 1
	menu_button.button_index = int(Tuning.value("input", "actions.menu.joy_buttons")[0])
	menu_button.pressed = true
	camp._input(menu_button)
	var couch: String = camp.couch_id
	var why := "" if couch != "" else "the couch player did not drop in"
	var night := 0
	if why == "":
		camp.state.build.build("p_host", "pitch", OPEN, 0.0)
		_at_hour(camp, Tuning.num("day", "stays.arrive_hour"))
		camp.state.day.maybe_arrive()
		_at_hour(camp, Tuning.num("day", "clock.evening_hour"))
		night = camp.state.day.today()
		camp._open_menu("p_host")
		camp._on_menu("sleep")
		if not camp.state.day.votes.has("p_host") or int(camp.state.camp["last_settled"]) == night:
			why = "player one's vote alone should not start the night on the couch"
	if why == "":
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains("1"):
			why = "the bed line should say who is ready, got " + camp.get_node("Hud/Prompt").text
	if why == "":
		var coins := int(camp.state.camp["coins"])
		camp._open_menu(couch)
		camp._on_menu("sleep")
		if int(camp.state.camp["last_settled"]) != night or int(camp.state.camp["coins"]) != coins + int(Tuning.num("day", "lodging.pitch")):
			why = "both couch players ready should settle the night and pay the guest's price"
		elif not camp.get_node("Hud/Night").visible:
			why = "the night should fade the screen"
		elif int(CampSave.load_slot(1)["camp"]["last_settled"]) != night:
			why = "the settled night should be saved at once"
		else:
			camp._open_menu("p_host")
			camp._on_menu("sleep")
			if int(camp.state.camp["coins"]) != coins + int(Tuning.num("day", "lodging.pitch")):
				why = "voting again in the morning paid again"
	await _done()
	return why


## Host on `port` with a pitch and its guest in the evening, and a guest PC joined.
func _pair(port: int) -> Array:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, port)
	if why == "":
		why = host.state.build.build("p_host", "pitch", OPEN, 0.0)
		host._show_object(host.state.build.last_id)
		_at_hour(host, Tuning.num("day", "stays.arrive_hour"))
		await _tree().process_frame
		_at_hour(host, Tuning.num("day", "clock.evening_hour"))
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", port)
	var ok: bool = await _until(func() -> bool: return guest.state != null and host.campers.size() == 2)
	return [host, guest, why if why != "" else ("" if ok else "the guest never got in")]


func test_the_guest_pc_sees_the_day_and_builds_through_the_host() -> String:
	var pair := await _pair(24721)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	if why == "" and not (guest.visitors.size() == 1 and int(guest.state.camp["coins"]) == int(host.state.camp["coins"])):
		why = "the guest PC should see the host's guest and coins"
	if why == "" and absf(guest.state.day.hour() - host.state.day.hour()) > 0.1:
		why = "the guest PC's clock should match the host's"
	if why == "":
		var spot := CampBuild.snap(Vector2(-6, 5))
		_face_spot(guest, "p_guest", spot)
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(Vector2(spot.x, spot.y + Tuning.num("build", "ahead_m"))) < 0.05)
		host.state.camp["coins"] = 100
		host._share()
		await _until(func() -> bool: return int(guest.state.camp["coins"]) == 100)
		guest.toggle_build("p_guest")
		guest.build_here("p_guest")
		if not await _until(func() -> bool: return guest.objects.size() == host.objects.size() and host.state.build.building_at(spot) != ""):
			why = "the guest PC's pitch should be built by the host and appear on both PCs"
		elif not await _until(func() -> bool: return int(guest.state.camp["coins"]) == 100 - CampBuild.cost("pitch")):
			why = "the guest PC should see the coins the pitch cost"
		else:
			guest._unhandled_input(_key("undo"))
			if not await _until(func() -> bool: return host.state.build.building_at(spot) == "" and guest.state.build.building_at(spot) == ""):
				why = "the guest PC's undo should take its pitch away on both PCs"
	await _done()
	return why


func test_a_night_pays_once_across_a_reconnect() -> String:
	var pair := await _pair(24722)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	var price := int(Tuning.num("day", "lodging.pitch"))
	var coins := int(host.state.camp["coins"]) if why == "" else 0
	var night: int = host.state.day.today() if why == "" else 0
	if why == "":
		guest.ask("sleep", [true])
		if not await _until(func() -> bool: return host.state.day.votes.has("p_guest") and guest.state.day.votes.has("p_guest")):
			why = "the guest PC's vote did not reach the host and come back"
	if why == "":
		guest.stop("")
		if not await _until(func() -> bool: return host.state.online.size() == 1):
			why = "the host did not notice the guest leave"
		elif host.state.day.votes.has("p_guest") or int(host.state.camp["last_settled"]) == night:
			why = "a guest PC that leaves should take its vote with it, and nothing should pay yet"
	var again: Node = null
	if why == "":
		again = _camp("GuestAgain", "p_guest", "Gus")
		again.start_join("127.0.0.1", 24722)
		if not await _until(func() -> bool: return again.state != null):
			why = "the guest could not rejoin"
	if why == "":
		host.ask("sleep", [true])
		if int(host.state.camp["last_settled"]) == night:
			why = "the host alone should not start the night with the guest back in"
		else:
			again.ask("sleep", [true])
			again.ask("sleep", [true])
			if not await _until(func() -> bool: return int(again.state.camp["last_settled"]) == night):
				why = "both ready should settle the night on both PCs"
			elif int(host.state.camp["coins"]) != coins + price or int(again.state.camp["coins"]) != coins + price:
				why = "the night should pay once on both PCs: host %d, guest %d, want %d" % [
						host.state.camp["coins"], again.state.camp["coins"], coins + price]
			elif host.state.camp["stays"].size() != 0 or again.state.camp["stays"].size() != 0:
				why = "the guest whose night was paid should head home on both PCs"
	if why == "":
		again.stop("")
		await _until(func() -> bool: return host.state.online.size() == 1)
		var back := _camp("GuestThird", "p_guest", "Gus")
		back.start_join("127.0.0.1", 24722)
		await _until(func() -> bool: return back.state != null)
		back.ask("sleep", [true])
		await _tree().process_frame
		await _tree().process_frame
		if int(host.state.camp["coins"]) != coins + price or int(CampSave.load_slot(1)["camp"]["coins"]) != coins + price:
			why = "a reconnect after the night paid it again"
		elif back.state == null or int(back.state.camp["coins"]) != coins + price:
			why = "the rejoined guest PC should see the coins the night paid"
	await _done()
	return why
