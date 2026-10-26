extends RefCounted
## Milestone 2: two camps talk over ENet on this machine, each under its own multiplayer branch, as two PCs would.
## The host decides every change; characters follow profile IDs; a third PC is told the camp is full.

const DIR := "user://test_saves/net"
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _fresh() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


## A camp scene on its own branch and multiplayer, set apart so its colliders don't meet the other camp's.
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


## Host on `port` and a guest joined; "" or what went wrong.
func _pair(port: int) -> Array:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, port)
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", port)
	var ok: bool = await _until(func() -> bool: return guest.state != null and host.campers.size() == 2)
	return [host, guest, why if why != "" else ("" if ok else "the guest never got in")]


func _walk(camp: Node, who: String, x: float, z: float, yaw: float, watcher: Node) -> bool:
	var c: Camper = camp.campers[who]
	c.position = Vector3(x, c.position.y, z)
	c.rotation.y = yaw
	return await _until(func() -> bool:
		return watcher.state.player_pos(who).distance_to(Vector2(x, z)) < 0.05)


func test_host_and_join_both_players_appear() -> String:
	var pair := await _pair(24711)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	if why == "":
		if not (guest.campers.has("p_host") and guest.campers.has("p_guest")):
			why = "the guest does not see both campers"
		elif not (guest.campers["p_guest"].controlled and not host.campers["p_guest"].controlled):
			why = "each PC should steer only its own camper"
		elif host.campers["p_guest"].model_id == host.campers["p_host"].model_id:
			why = "both campers have the same look"
	await _done()
	return why


func test_movement_reaches_the_other_pc() -> String:
	var pair := await _pair(24712)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	if why == "" and not await _walk(guest, "p_guest", 2.4, 2.6, 0.0, host):
		why = "the host never heard where the guest walked"
	if why == "" and not await _until(func() -> bool:
			return host.campers["p_guest"].position.distance_to(Vector3(2.4, 0, 2.6)) < 0.3):
		why = "the guest's camper did not glide there on the host"
	if why == "" and not await _walk(host, "p_host", -2.0, 0.5, 0.0, guest):
		why = "the guest never heard where the host walked"
	await _done()
	return why


func test_guest_carries_and_places_a_chair_and_the_host_decides() -> String:
	var pair := await _pair(24713)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	var chair: Vector2 = host.state.object_pos("chair_teal_1") if why == "" else Vector2.ZERO
	if why == "" and not await _walk(guest, "p_guest", chair.x, chair.y - 0.6, 0.0, host):
		why = "the guest's walk did not arrive"
	if why == "":
		guest.interact()
		if not await _until(func() -> bool:
				return guest.state.carriers.get("chair_teal_1", "") == "p_guest" \
						and host.state.carriers.get("chair_teal_1", "") == "p_guest"):
			why = "the host did not hand the chair to the guest"
	if why == "":
		await _walk(host, "p_host", chair.x, chair.y + 0.5, 0.0, guest)
		host.ask("pick_up", ["chair_teal_1"])
		if host.state.carriers["chair_teal_1"] != "p_guest":
			why = "the host took the chair out of the guest's hands"
	if why == "" and not await _walk(guest, "p_guest", 0.0, 4.0, 0.0, host):
		why = "the guest's second walk did not arrive"
	if why == "":
		guest.interact()
		var spot := Vector2(0.0, 4.0 - Tuning.num("tuning", "carry.place_distance_m"))
		if not await _until(func() -> bool:
				return guest.state.carriers.is_empty() and host.state.object_pos("chair_teal_1").distance_to(spot) < 0.05 \
						and guest.state.object_pos("chair_teal_1").distance_to(spot) < 0.05):
			why = "the chair was not put down in the same place on both PCs"
	if why == "":
		var saved: Dictionary = CampSave.load_slot(1)["camp"]
		var p: Array = saved["objects"]["chair_teal_1"]["pos"]
		if not (saved["profiles"].has("p_guest") and absf(float(p[1]) - (4.0 - Tuning.num("tuning", "carry.place_distance_m"))) < 0.05):
			why = "the host's save does not hold the guest's profile and the moved chair"
	await _done()
	return why


func test_a_third_pc_is_told_the_camp_is_full() -> String:
	var pair := await _pair(24714)
	var why: String = pair[2]
	var heard: Array[String] = []
	if why == "":
		var third := _camp("ThirdSide", "p_third", "Tess")
		third.stopped.connect(func(reason: String) -> void: heard.append(reason))
		third.start_join("127.0.0.1", 24714)
		if not await _until(func() -> bool: return not heard.is_empty()):
			why = "the third PC heard nothing"
		elif heard[0] != "join.full":
			why = "the third PC was told " + heard[0]
		elif pair[0].state.online.size() != 2:
			why = "the host let a third player in"
	await _done()
	return why


func test_rejoining_brings_back_the_same_character() -> String:
	var pair := await _pair(24715)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	var chair: Vector2 = host.state.object_pos("chair_teal_1") if why == "" else Vector2.ZERO
	var first_peer := 0
	if why == "":
		first_peer = host._guests.keys()[0]
		await _walk(guest, "p_guest", chair.x, chair.y - 0.6, 0.0, host)
		guest.interact()
		if not await _until(func() -> bool: return host.state.carriers.has("chair_teal_1")):
			why = "the guest never picked up the chair"
		guest.stop("")
		if why == "" and not await _until(func() -> bool: return host.state.online.size() == 1):
			why = "the host did not notice the guest leave"
		if why == "" and not host.state.carriers.is_empty() or host.state.object_pos("chair_teal_1") != chair:
			why = "the chair was not set down at its last spot"
	if why == "":
		var again := _camp("GuestAgain", "p_guest", "Gus")
		again.start_join("127.0.0.1", 24715)
		if not await _until(func() -> bool: return again.state != null):
			why = "the guest could not rejoin"
		elif host._guests.keys()[0] == first_peer:
			why = "the test needs a new connection id"
		elif host.state.camp["profiles"].size() != 2:
			why = "rejoining made a new character"
		elif again.state.player_pos("p_guest").distance_to(Vector2(chair.x, chair.y - 0.6)) > 0.1:
			why = "the guest did not come back where they left"
	await _done()
	return why


## Gameplay round 1: the other PC sees the tool in your mitten and you asleep in the camp's tent, then up again.
func test_the_other_pc_sees_the_tool_in_hand_and_the_tent() -> String:
	var pair := await _pair(24716)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var why: String = pair[2]
	if why == "":
		guest.hold_tool("p_guest", "axe")
		if not await _until(func() -> bool: return host.campers["p_guest"].held == "axe"):
			why = "the host should see the axe in the guest's hand"
		elif host.campers["p_guest"].find_child("Tool", true, false) == null:
			why = "the axe should be drawn in the guest's mitten on the host"
	if why == "":
		var home: Vector2 = guest.home_tent_pos()
		guest.campers["p_guest"].position = Vector3(home.x + 1.6, 0, home.y)
		guest.enter_tent("p_guest")
		var tent: Node3D = host.clearing.placed[host.home_tent_index()]
		if not await _until(func() -> bool: return host._inside.has("p_guest")):
			why = "the host should see the guest lie down in the camp's tent"
		elif host.campers["p_guest"].visible:
			why = "the guest's camper should be hidden on the host while in the tent"
		elif not await _until(func() -> bool: return host.is_open(tent, "tent")):
			why = "the camp's tent should open on the host so the sleeping guest shows"
		elif not host.state.day.votes.has("p_guest"):
			why = "the guest in the tent should be ready for bed on the host"
		else:
			# Looks only: both voting would start the night.
			host._lie_down("p_host")
			var bags: Array = host._inside.values().map(func(n: Node3D) -> int: return int(n.get_meta("bag")))
			if bags.size() != 2 or bags[0] == bags[1]:
				why = "two players in the tent should lie in two different bags, got %s" % [bags]
			host._get_up("p_host")
	if why == "":
		guest.leave_tent("p_guest")
		if not await _until(func() -> bool: return not host._inside.has("p_guest") and host.campers["p_guest"].visible):
			why = "the host should see the guest get up out of the tent"
	await _done()
	return why
