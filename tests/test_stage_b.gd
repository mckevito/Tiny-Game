extends RefCounted
## Stage B in the real camp scene: three days of play from the buttons (fishing, grilling, a guest's request, the
## booking board, a second kind of building, bed and the morning report), and over ENet the guest PC doing the same
## through the host.

const DIR := "user://test_saves/stage_b"
const NEAR_FIRE := Vector2(3, 5)
const OPEN := Vector2(-3.2, 7.9)
const WATER := Vector2(4, 8)
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


func _key(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = OS.find_keycode_from_string(str(Tuning.value("input", "actions.%s.keys" % action)[0]))
	ev.pressed = true
	return ev


func _stand(camp: Node, who: String, at: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.position = Vector3(at.x, c.position.y, at.y)
	camp.state.set_player_pos(who, at, 0.0)


## Fishing or grilling from the interact button, with the wait cut short.
func _use(camp: Node, who: String) -> bool:
	camp._unhandled_input(_key("interact"))
	if not camp._busy.has(who):
		return false
	camp._busy[who]["left"] = 0.0
	return await _until(func() -> bool: return not camp._busy.has(who))


func _shore() -> Vector2:
	for row: Dictionary in Tuning.table("clearing")["placements"]:
		if row["model"] == "pond":
			return Vector2(float(row["pos"][0]) - 3.4, float(row["pos"][1]))
	return Vector2.ZERO


## Bed from the menu; the night settles and the morning report comes up.
func _sleep(camp: Node) -> String:
	_at_hour(camp, Tuning.num("day", "clock.evening_hour"))
	camp._open_menu("p_host")
	camp._on_menu("sleep")
	if not camp.report.visible:
		return "the morning report should come up after the night"
	return ""


func test_three_days_of_play_from_the_buttons() -> String:
	_fresh()
	var camp := _camp("PlaySide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	var s: CampState = camp.state
	s.build.build("p_host", "pitch", NEAR_FIRE, 0.0)
	camp._show_object(s.build.last_id)
	_at_hour(camp, Tuning.num("day", "stays.arrive_hour"))
	await _tree().process_frame
	# Day 1: a guest with a request; the booking board.
	if camp.visitors.size() != 1 or s.guests.current().get("id", "") != "ferns":
		why = "on day 1 a guest should come and the first booking should be on the board"
	var stay := "" if why != "" else str(camp.visitors.keys()[0])
	var guest_name := "" if why != "" else str(s.camp["stays"][stay]["name"])
	if why == "":
		s.camp["stays"][stay]["request"] = {"kind": "meal", "done": false}
		camp._sync_stays(false)
		var label: Label3D = camp.visitors[stay].get_node("Name")
		if not label.text.contains(Tuning.text("request.say.meal")):
			why = "the guest should show their request over their head, got " + label.text
	if why == "":
		camp._open_menu("p_host")
		if not camp.menu.status.text.contains(Tuning.text("booking.ferns.name")) or not camp.menu._booking[0].visible:
			why = "the menu should show the booking board with an accept button"
		else:
			camp._on_menu("booking_accept")
			if s.guests.row("ferns").get("state", "") != "accepted":
				why = "accept on the board should book them"
	# Fish at the pond, grill at the fire, hand it over.
	if why == "":
		_stand(camp, "p_host", _shore())
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.fill(Tuning.text("prompt.fish"), false)):
			why = "by the pond the prompt should offer to fish, got " + camp.get_node("Hud/Prompt").text
		elif not await _use(camp, "p_host") or s.pockets.first_of("p_host", "fish") == "":
			why = "interact by the pond should cast and catch a fish"
		elif not camp.get_node("Hud/Clock").text.contains(Tuning.text("items." + s.pockets.first_of("p_host", "fish"))):
			why = "the HUD should list what's in the pockets"
	if why == "":
		_stand(camp, "p_host", Vector2(1.3, 0.3))
		if not await _use(camp, "p_host") or s.pockets.first_of("p_host", "meal") == "":
			why = "interact by the fire with a fish should grill it"
	if why == "":
		_stand(camp, "p_host", s.day.stand_point(stay) + Vector2(0.8, 0))
		var coins := int(s.camp["coins"])
		camp._unhandled_input(_key("interact"))
		if s.guests.open_request(stay) != "" or int(s.camp["coins"]) <= coins:
			why = "interact by the guest should hand over the meal and get the tip"
		elif camp.visitors[stay].get_node("Name").text.contains("\n"):
			why = "a met request should leave the guest's label"
	# A second kind of building: the next-kind button.
	if why == "":
		camp._unhandled_input(_key("build"))
		camp._unhandled_input(_key("next_kind"))
		if camp._building.get("p_host", {}).get("kind", "") != "water_point":
			why = "the next-kind button should switch build mode to the water point"
		camp._unhandled_input(_key("build"))
	if why == "":
		why = _sleep(camp)
	if why == "":
		var text: String = camp.report.text()
		for want in [Tuning.text("report.morning") % [Tuning.text("clock.season.spring"), 2], guest_name,
				Tuning.text("booking.ferns.name"), Tuning.text("report.today")]:
			if not text.contains(str(want)):
				why = "the morning report should say %s, got:\n%s" % [want, text]
				break
	if why == "":
		camp._unhandled_input(_key("interact"))
		if camp.report.visible:
			why = "interact should close the morning report"
	# Day 2: room for the booking; day 3 they come; morning 4 shows the next booking.
	if why == "":
		s.build.build("p_host", "pitch", OPEN, 0.0)
		s.build.build("p_host", "water_point", WATER, 0.0)
		why = _sleep(camp)
		camp.report.visible = false
	if why == "":
		_at_hour(camp, Tuning.num("day", "stays.arrive_hour"))
		await _tree().process_frame
		if s.guests.row("ferns").get("state", "") != "arrived":
			why = "on day 3 the Fern family should arrive"
	if why == "":
		why = _sleep(camp)
	if why == "":
		var text: String = camp.report.text()
		if not (text.contains(Tuning.text("booking.birdwatchers.name")) and text.contains(Tuning.text("build.water_point"))):
			why = "morning 4 should show the extras bonus and the next booking, got:\n" + text
		elif s.guests.row("ferns").get("state", "") != "done":
			why = "the Fern family should have gone home"
	await _done()
	return why


func test_the_guest_pc_fishes_gives_and_books_through_the_host() -> String:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24731)
	if why == "":
		why = host.state.build.build("p_host", "pitch", NEAR_FIRE, 0.0)
		host._show_object(host.state.build.last_id)
		_at_hour(host, Tuning.num("day", "stays.arrive_hour"))
		await _tree().process_frame
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24731)
	if why == "" and not await _until(func() -> bool: return guest.state != null and host.campers.size() == 2):
		why = "the guest never got in"
	if why == "" and not (guest.visitors.size() == 1 and guest.state.guests.current().get("id", "") == "ferns"):
		why = "the guest PC should see the guest and the booking board"
	if why == "":
		_stand(guest, "p_guest", _shore())
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_shore()) < 0.05)
		guest.interact("p_guest")
		guest._busy["p_guest"]["left"] = 0.0
		if not await _until(func() -> bool: return guest.state.pockets.first_of("p_guest", "fish") != ""):
			why = "the guest PC's catch should come back from the host"
		elif host.state.pockets.first_of("p_guest", "fish") == "":
			why = "the host should keep the guest's catch"
	if why == "":
		var stay: String = host.state.camp["stays"].keys()[0]
		host.state.camp["stays"][stay]["request"] = {"kind": "fish", "done": false}
		host._share()
		var at: Vector2 = host.state.day.stand_point(stay) + Vector2(0.8, 0)
		_stand(guest, "p_guest", at)
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(at) < 0.05 \
				and guest.state.guests.open_request(stay) == "fish")
		guest.interact("p_guest")
		if not await _until(func() -> bool: return guest.state.guests.open_request(stay) == "" \
				and host.state.guests.open_request(stay) == ""):
			why = "the guest PC should hand the fish over through the host"
	if why == "":
		guest._open_menu("p_guest")
		guest._on_menu("booking_later")
		if not await _until(func() -> bool: return int(guest.state.guests.row("ferns").get("arrive_day", 0)) \
				== int(CampGuests.plan("ferns")["arrive_day"]) + 1):
			why = "the guest PC should move the booking a day through the host"
	if why == "":
		_at_hour(host, Tuning.num("day", "clock.evening_hour"))
		host.ask("sleep", [true])
		guest.ask("sleep", [true])
		if not await _until(func() -> bool: return guest.report.visible and host.report.visible):
			why = "both PCs should see the morning report"
		elif guest.report.text() != host.report.text():
			why = "both PCs should read the same report:\n%s\n---\n%s" % [host.report.text(), guest.report.text()]
	await _done()
	return why
