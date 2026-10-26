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


## Walks a player onto the first loose piece and waits for it to land and be swept up.
func _sweep_up(camp: Node, who: String) -> bool:
	var bundles: Dictionary = camp.state.camp["bundles"]
	if bundles.is_empty():
		return false
	var id: String = bundles.keys()[0]
	_stand(camp, who, CampPack.bundle_pos(bundles[id]))
	return await _until(func() -> bool: return not bundles.has(id))


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
		var rod := Prompts.rich(Tuning.text("prompt.need_tool") % Tuning.text("tool.rod"), false)
		if not camp.get_node("Hud/Prompt").text.contains(rod):
			why = "by the pond with bare hands the prompt should ask for the rod, got " + camp.get_node("Hud/Prompt").text
		# A tap of the next-tool button (pressed and let go before the ring opens) goes hands, axe, rod, and the
		# corner dock shows it.
		for i in 2:
			camp._unhandled_input(_key("next_tool"))
			var up := _key("next_tool")
			up.pressed = false
			camp._unhandled_input(up)
		await _tree().process_frame
		if why != "":
			pass
		elif camp._docks["p_host"].tool_text() != Tuning.text("tool.rod"):
			why = "two presses of next tool should take out the rod, the dock shows " + camp._docks["p_host"].tool_text()
		elif not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.fish"), false)):
			why = "by the pond with the rod the prompt should offer to fish, got " + camp.get_node("Hud/Prompt").text
		elif not await _use(camp, "p_host") or s.pack.first_of("p_host", "fish") == "":
			why = "interact by the pond should cast and catch a fish"
		else:
			camp._unhandled_input(_key("pack"))
			if not camp._packs.has("p_host") or not camp._packs["p_host"]["panel"].slot_text(0).contains(
					Tuning.text("items." + s.pack.first_of("p_host", "fish"))):
				why = "the pack button should open the Pack, showing the catch"
			camp._unhandled_input(_key("pack"))
			if why == "" and (camp._packs.has("p_host") or not camp.campers["p_host"].controlled):
				why = "the pack button again should close the Pack and free the camper"
	# Chop a tree for the fire's wood.
	if why == "":
		var tree: Dictionary = CampGather.trees()[0]
		_stand(camp, "p_host", (tree["pos"] as Vector2) + Vector2(1.0, 0.0))
		camp.hold_tool("p_host", "axe")
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.chop") % 3, false)):
			why = "by a tree the prompt should offer to chop, got " + camp.get_node("Hud/Prompt").text
		elif not await _use(camp, "p_host") or s.pack.count("p_host", "wood") != 0 or s.camp["bundles"].size() != 1:
			why = "interact by a tree should pop one wood out onto the grass"
		elif not camp.campers["p_host"].swinging() or not camp._airborne.has(s.camp["bundles"].keys()[0]):
			why = "the camper should swing the axe and the wood should be in the air"
		elif not await _sweep_up(camp, "p_host") or s.pack.count("p_host", "wood") != 1:
			why = "walking over the landed wood should sweep it into the Pack"
		elif not camp.get_node("Hud/Clock").text.contains(CampTasks.line({"id": "first_board", "have": 0}, true)):
			why = "the HUD's Today list should move on from the first chop, got " + camp.get_node("Hud/Clock").text
	if why == "":
		_stand(camp, "p_host", Vector2(1.3, 0.3))
		if not await _use(camp, "p_host") or s.pack.first_of("p_host", "meal") == "":
			why = "interact by the fire with a fish should grill it"
	if why == "":
		_stand(camp, "p_host", s.day.stand_point(stay) + Vector2(0.8, 0))
		var coins := int(s.camp["coins"])
		camp._unhandled_input(_key("interact"))
		if s.guests.open_request(stay) != "" or int(s.camp["coins"]) <= coins:
			why = "interact by the guest should hand over the meal and get the tip"
		elif camp.visitors[stay].get_node("Name").text.contains("\n"):
			why = "a met request should leave the guest's label"
	# Craft a water point at the workbench, then the next-kind button finds it in build mode.
	if why == "":
		s.camp["coins"] = int(s.camp["coins"]) + 50
		s.pack.add_to_box("wood", 10)
		_stand(camp, "p_host", CampBuild.bench_pos() + Vector2(0.0, -1.2))
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.bench"), false)):
			why = "by the workbench the prompt should offer it, got " + camp.get_node("Hud/Prompt").text
		camp._unhandled_input(_key("interact"))
		if why == "" and not camp._bench.has("p_host"):
			why = "interact by the workbench should open its panel"
		elif why == "" and not camp.camera.hold_turn:
			why = "the turn buttons pick recipes at the workbench, so they should not turn the camera"
		if why == "":
			var pick := CampBuild.recipes().map(func(r: Dictionary) -> String: return r["kind"]).find("water_point")
			for i in pick:
				camp._unhandled_input(_key("next_kind"))
			camp._unhandled_input(_key("interact"))
			if s.build.in_kit("water_point") != 1:
				why = "interact on the picked recipe should craft a water point into the kit"
			camp._unhandled_input(_key("cancel"))
			if camp._bench.has("p_host") or not camp.campers["p_host"].controlled or camp.camera.hold_turn:
				why = "cancel should close the workbench and free the camper and the camera"
	if why == "":
		camp._unhandled_input(_key("next_kind"))
		await _tree().process_frame
		if not camp._docks["p_host"].piece_text().contains(Tuning.text("build.water_point")):
			why = "outside build mode the next-kind button should pick the water point in the dock, got " \
					+ camp._docks["p_host"].piece_text()
		camp._unhandled_input(_key("build"))
		if why == "" and camp._building.get("p_host", {}).get("kind", "") != "water_point":
			why = "build mode should start on the piece picked in the dock"
		camp._unhandled_input(_key("build"))
	if why == "":
		why = _sleep(camp)
	if why == "":
		var text: String = camp.report.text()
		for want in [Tuning.text("report.morning") % [Tuning.text("clock.season.spring"), 2], guest_name,
				Tuning.text("booking.ferns.name"), Tuning.text("report.today"),
				Tuning.text("report.tomorrow") % Tuning.text("news.day_3")]:
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
		elif s.guests.row("ferns").get("state", "") != "arrived":
			why = "the Fern family should still be staying on morning 4 (two nights)"
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
		guest.hold_tool("p_guest", "rod")
		guest.interact("p_guest")
		guest._busy["p_guest"]["left"] = 0.0
		if not await _until(func() -> bool: return guest.state.pack.first_of("p_guest", "fish") != ""):
			why = "the guest PC's catch should come back from the host"
		elif host.state.pack.first_of("p_guest", "fish") == "":
			why = "the host should keep the guest's catch"
	# Reading the clipboard shows on the other PC too.
	if why == "":
		guest.toggle_clipboard("p_guest")
		if not await _until(func() -> bool: return host.campers["p_guest"].held == "clipboard"):
			why = "the host should see the guest's camper reading the clipboard"
		guest.toggle_clipboard("p_guest")
		if why == "" and not await _until(func() -> bool: return host.campers["p_guest"].held == "rod"):
			why = "putting the clipboard away should hand the rod back on the host too"
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


## Round 2 from the buttons: a tree chopped until it falls, its sapling picked up and planted at the stump, the
## clipboard's tabs, and the long log carried to the fire.
func test_felling_replanting_the_clipboard_and_the_long_log_from_the_buttons() -> String:
	_fresh()
	var camp := _camp("RoundTwo", "p_host", "Hana")
	camp.start_solo(1)
	var s: CampState = camp.state
	var why := ""
	var tree: Dictionary = CampGather.trees()[0]
	var index := int(tree["index"])
	_stand(camp, "p_host", (tree["pos"] as Vector2) + Vector2(1.0, 0.0))
	camp.hold_tool("p_host", "axe")
	for i in int(Tuning.num("gather", "trees.wood_per_tree")):
		if why == "" and not await _use(camp, "p_host"):
			why = "chop %d should work" % (i + 1)
	var root: Node3D = camp.clearing.placed[index]
	if why == "" and not (root.get_child(0).visible and root.get_child(0).has_meta("falling")):
		why = "the felled tree should topple over before it hides"
	if why == "" and (not await _until(func() -> bool: return not root.get_child(0).visible) \
			or (camp._tree_props.get(index, []) as Array).size() != 2):
		why = "the felled tree should hide, leaving a stump and a sapling beside it"
	s.camp["bundles"] = {}
	camp._sync_bundles()
	if why == "":
		camp._unhandled_input(_key("interact"))
		if s.pack.first_of("p_host", "plant") != "sapling":
			why = "interact by the stump should pick up the sapling"
	if why == "":
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.plant"), false)):
			why = "with a sapling in the Pack the stump should offer to plant, got " + camp.get_node("Hud/Prompt").text
		camp._unhandled_input(_key("interact"))
		if s.gather.tree(index)["stage"] != "sapling" or (camp._tree_props.get(index, []) as Array).size() != 1:
			why = "interact should plant the sapling at the stump, and show it"
	# The shovel digs a bare stump up into a hole.
	if why == "":
		var other: Dictionary = {}
		for t: Dictionary in CampGather.trees().slice(1):
			var near := false
			for i in CampGather.spots().size():
				near = near or CampGather.spot_pos(i).distance_to(t["pos"]) < 3.0
			if not near and other.is_empty():
				other = t
		var j := int(other["index"])
		s.camp["trees"][str(j)] = {"chops": 0, "stage": "stump", "sapling_out": false, "planted": 0}
		camp._sync_trees(false)
		_stand(camp, "p_host", (other["pos"] as Vector2) + Vector2(1.0, 0.0))
		camp.hold_tool("p_host", "shovel")
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.dig"), false)):
			why = "with the shovel by a stump the prompt should offer to dig, got " + camp.get_node("Hud/Prompt").text
		elif not await _use(camp, "p_host") or s.gather.tree(j)["stage"] != "hole" or s.camp["bundles"].size() != 1:
			why = "interact with the shovel should dig the stump into a hole and pop out its roots"
		camp.hold_tool("p_host", "hands")
	# The clipboard: open, flip through every tab, put away.
	if why == "":
		camp._unhandled_input(_key("clipboard"))
		var board: Clipboard = camp._boards.get("p_host")
		if board == null or not board.text().contains(CampTasks.line(s.tasks.active()[0])):
			why = "the clipboard key should open the clipboard on its Today tab"
		elif camp.held_by("p_host") != "clipboard":
			why = "while the clipboard is open the camper should hold it up to read"
		elif not camp.camera.hold_turn:
			why = "while the clipboard is open the turn buttons should flip its tabs, not the camera"
		else:
			camp._unhandled_input(_key("camera_right"))
			if board.tab_name() != "bookings" or not board.text().contains(Tuning.text("booking.ferns.name")):
				why = "the next tab should show the bookings, got " + board.text()
			camp._unhandled_input(_key("camera_right"))
			if why == "" and (board.tab_name() != "supplies" or not board.text().contains(
					Tuning.text("clipboard.coins") % int(s.camp["coins"]))):
				why = "the third tab should show the supplies, got " + board.text()
			camp._unhandled_input(_key("clipboard"))
			if why == "" and (camp._boards.has("p_host") or camp.camera.hold_turn):
				why = "the clipboard key again should put it away"
	# The long log: slow alone, splits by the fire.
	if why == "":
		var log_id := ""
		for id: String in s.camp["objects"]:
			if str(s.camp["objects"][id]["model"]) == "long_log":
				log_id = id
		_stand(camp, "p_host", s.object_pos(log_id) + Vector2(0.6, 0.0))
		camp._unhandled_input(_key("interact"))
		await _tree().physics_frame
		await _tree().physics_frame
		var wood := s.pack.box_count("wood")
		if s.carried_by("p_host") != log_id or camp.campers["p_host"].speed_scale >= 1.0:
			why = "the long log should be picked up and go slowly alone"
		else:
			_stand(camp, "p_host", Vector2(0.0, 2.6))
			camp.campers["p_host"].rotation.y = 0.0
			camp._unhandled_input(_key("interact"))
			if s.camp["objects"].has(log_id) or s.pack.box_count("wood") <= wood:
				why = "set down by the fire the log should split into wood"
	await _done()
	return why


## Round 3 and 4 from the buttons: open the Pack, pick a slot, drop it as a bundle, pick it back up, fill the camp
## box; and with a full Pack, long words and a busy screen every HUD piece stays inside the view and none covers
## another, also with the menu open (the owner saw the top line run off, then the menu run under the Pack bar).
func test_dropping_the_camp_box_and_a_hud_that_stays_on_screen() -> String:
	_fresh()
	var camp := _camp("RoundThree", "p_host", "Hana")
	camp.start_solo(1)
	var s: CampState = camp.state
	var why := ""
	# A 16:9 screen like the owner's (headless windows start square, which hides anything too tall).
	var was := _tree().root.size
	_tree().root.size = Vector2i(1920, 1080)
	s.pack.add("p_host", "berries", 2)
	s.pack.add("p_host", "stick", 5)
	_stand(camp, "p_host", Vector2(-3.0, 6.0))
	camp._unhandled_input(_key("pack"))
	camp._unhandled_input(_key("next_kind"))
	if not camp._packs.has("p_host") or int(camp._packs["p_host"]["pick"]) != 1:
		why = "next kind in the open Pack should pick the next slot"
	if why == "":
		camp._unhandled_input(_key("interact"))
		if s.pack.count("p_host", "stick") != 0 or s.camp["bundles"].size() != 1 or camp._bundle_nodes.size() != 1:
			why = "interact in the open Pack should set the picked stack down as a bundle you can see"
		camp._unhandled_input(_key("cancel"))
	if why == "":
		await _tree().process_frame
		if not camp.get_node("Hud/Prompt").text.contains(Prompts.rich(Tuning.text("prompt.pick_bundle")
				% [Tuning.text("items.stick"), 5], false)):
			why = "by a bundle the prompt should offer to pick it up, got " + camp.get_node("Hud/Prompt").text
		camp._unhandled_input(_key("interact"))
		if s.pack.count("p_host", "stick") != 5 or not s.camp["bundles"].is_empty() or not camp._bundle_nodes.is_empty():
			why = "interact should pick the whole bundle back up"
	if why == "":
		_stand(camp, "p_host", CampPack.box_pos() + Vector2(0.9, -0.4))
		await _tree().process_frame
		camp._unhandled_input(_key("interact"))
		if s.pack.box_count("stick") != 5 or s.pack.count("p_host", "berries") != 2:
			why = "interact by the camp box should put the sticks in and keep the berries"
	if why == "":
		var cap := int(Tuning.num("items", "stack_max"))
		s.camp["profiles"]["p_host"]["pack"] = []
		for item in ["grilled_sunfish", "grilled_perch", "grilled_trout", "berries", "sapling", "stick", "wood", "sunfish"]:
			s.pack.add("p_host", item, cap)
		for i in 4:
			camp._toast(Tuning.text("toast.crafted") % ["Hana", Tuning.text("build.lantern_post")])
		camp._unhandled_input(_key("clipboard"))
		camp._unhandled_input(_key("pack"))
		_stand(camp, "p_host", _shore())
		for f in 3:
			await _tree().process_frame
		if camp._boards.has("p_host"):
			why = "opening the Pack should put the clipboard away"
		else:
			why = _hud_fits(camp, [camp.get_node("Hud/Clock"), camp.get_node("Hud/Hint"), camp.get_node("Hud/Toast"),
					camp.get_node("Hud/Prompt"), camp._packs["p_host"]["panel"]])
		camp._unhandled_input(_key("pack"))
		camp._unhandled_input(_key("clipboard"))
		for f in 2:
			await _tree().process_frame
		if why == "":
			why = _hud_fits(camp, [camp.get_node("Hud/Clock"), camp.get_node("Hud/Hint"), camp.get_node("Hud/Toast"),
					camp.get_node("Hud/Prompt"), camp._docks["p_host"], camp._boards["p_host"]])
	# The menu covers the HUD: nothing else shows over or under it, and it fits on screen.
	if why == "":
		camp._unhandled_input(_key("menu"))
		for f in 2:
			await _tree().process_frame
		var panel: Control = camp.menu
		if not camp.get_viewport().get_visible_rect().encloses(panel.get_global_rect()):
			why = "the menu should fit on screen, got %s" % panel.get_global_rect()
		for c: Control in [camp.get_node("Hud/Hint"), camp.get_node("Hud/Toast"), camp._docks["p_host"], camp._boards["p_host"]]:
			if why == "" and c.is_visible_in_tree() and c.get_global_rect().intersects(panel.get_global_rect()):
				why = "%s should be hidden under the open menu" % c.name
		camp._unhandled_input(_key("menu"))
		# The biggest interface size still fits.
		Settings.set_value("ui_scale", 150)
		Settings.apply("ui_scale")
		camp._unhandled_input(_key("menu"))
		for f in 2:
			await _tree().process_frame
		if why == "" and not camp.get_viewport().get_visible_rect().encloses(panel.get_global_rect()):
			why = "at the biggest interface size the menu should still fit, got %s in %s" % [panel.get_global_rect(),
					camp.get_viewport().get_visible_rect()]
		camp._unhandled_input(_key("menu"))
		Settings.reset_page("access")
		Settings.apply("ui_scale")
	_tree().root.size = was
	await _done()
	return why


## "" when every visible piece with something in it is inside the view and none covers another (test_hud.gd).
func _hud_fits(camp: Node, pieces: Array) -> String:
	return preload("res://tests/test_hud.gd").hud_fits(camp.get_viewport().get_visible_rect(), pieces)


## Round 5 from the buttons (owner: freedom to finish day 1 and sleep any time, guests at the heart of the day, tents
## to sleep in, a camera for the animals): a guest asks again after a met request, the camp's tent takes a player to
## bed in the morning, a guest sleeps in their tent at night with a name bubble, and the camera fills the field guide.
func test_guests_ask_again_tents_and_the_camera_from_the_buttons() -> String:
	_fresh()
	var camp := _camp("RoundFive", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	var s: CampState = camp.state
	s.build.build("p_host", "pitch", NEAR_FIRE, 0.0)
	camp._show_object(s.build.last_id)
	_at_hour(camp, Tuning.num("day", "stays.arrive_hour"))
	await _tree().process_frame
	var stay := str(camp.visitors.keys()[0]) if camp.visitors.size() == 1 else ""
	if stay == "":
		why = "a guest should come to the pitch"
	else:
		camp._pitch_tent(stay)
	# A met request: a while later the guest asks for something else, up to today's share.
	if why == "":
		s.camp["stays"][stay]["request"] = {"kind": "fish", "done": false}
		s.pack.add("p_host", "perch")
		_stand(camp, "p_host", s.day.stand_point(stay) + Vector2(0.8, 0))
		camp._unhandled_input(_key("interact"))
		await _tree().process_frame
		if s.guests.open_request(stay) != "":
			why = "handing over the fish should meet the request"
		elif not camp.today_lines().contains(Tuning.text("hud.today")):
			why = "the corner should list the odd jobs under the guests"
	if why == "":
		s.camp["calendar"]["minute"] = float(s.camp["calendar"]["minute"]) + Tuning.num("guests", "more.wait_min") + 1.0
		await _tree().process_frame
		await _tree().process_frame
		var want := s.guests.open_request(stay)
		if want == "" or want == "fish":
			why = "after a while the guest should ask for something new, got '%s'" % want
		elif not camp.today_lines().contains(Tuning.text("request.want." + want)):
			why = "the corner should show what the guest would love now: " + camp.today_lines()
	# The camp's tent in the morning: crawl in, ready for bed (bed is open all day), get up again.
	if why == "":
		# A friend in the camp who is not ready yet keeps the day going while the host lies in the tent.
		s.join("p_friend", "Ash")
		var door: Vector2 = camp.home_tent_pos() + Vector2(1.6, 0.0)
		_stand(camp, "p_host", door)
		await _tree().process_frame
		var tent: Node3D = camp.clearing.placed[camp.home_tent_index()]
		if not camp.get_node("Hud/Prompt").text.contains(Tuning.text("prompt.tent")):
			why = "by the camp's tent the prompt should offer to crawl in, got " + camp.get_node("Hud/Prompt").text
		else:
			camp._unhandled_input(_key("interact"))
			await _tree().process_frame
			if not camp._inside.has("p_host") or not s.day.votes.has("p_host") or camp.campers["p_host"].visible:
				why = "interact by the tent should put the player in a sleeping bag and ready for bed, in the morning too"
			elif not camp.is_open(tent, "tent"):
				why = "the tent should open up so you can see the player inside"
			else:
				camp._unhandled_input(_key("interact"))
				await _tree().process_frame
				if camp._inside.has("p_host") or s.day.votes.has("p_host") or not camp.campers["p_host"].visible \
						or camp.is_open(tent, "tent"):
					why = "interact in the tent should get the player up and out of bed"
		s.leave("p_friend")
	# At night the guest sleeps in their tent; the bubble names them; it opens up when a player is close.
	if why == "":
		_at_hour(camp, Tuning.num("guests", "tent.in_hour") + 0.5)
		_stand(camp, "p_host", Vector2(-6.0, 6.0))
		await _tree().process_frame
		var tent: Node3D = camp._tents.get(stay)
		var name := str(s.camp["stays"][stay]["name"])
		if tent == null or not camp._asleep.has(stay) or camp.visitors[stay].visible:
			why = "at night the guest should be asleep inside their tent"
		elif camp._bubbles[stay].text != Tuning.text("tent.asleep") % name:
			why = "the tent's bubble should name its sleeping guest, got " + camp._bubbles[stay].text
		elif camp.is_open(tent, "tent_guest"):
			why = "a guest tent should stay closed while nobody is near"
		else:
			_stand(camp, "p_host", Vector2(tent.position.x + 1.8, tent.position.z))
			await _tree().process_frame
			if not camp.is_open(tent, "tent_guest"):
				why = "a player close by should see into the sleeping guest's tent"
			elif s.guests.guest_near("p_host") != "":
				why = "a sleeping guest should not be asked for anything"
	# The camera: an animal close by goes in the field guide, the first photo pays.
	if why == "":
		_at_hour(camp, 12.0)
		await _tree().process_frame
		var rabbit: Dictionary = camp.wildlife.animals[0]
		var at: Vector3 = (rabbit["node"] as Node3D).position
		camp.hold_tool("p_host", "camera")
		_stand(camp, "p_host", Vector2(at.x + 1.5, at.z))
		camp.wildlife.set_process(false)
		var coins := int(s.camp["coins"])
		camp._unhandled_input(_key("interact"))
		await _tree().process_frame
		var photos: Dictionary = s.camp["journal"].get("photos", {})
		if int(photos.get(str(rabbit["row"]["model"]), 0)) != 1 or int(s.camp["coins"]) != coins + int(Tuning.num("wildlife", "photo_bonus")):
			why = "interact with the camera by an animal should photograph it for the guide and pay the bonus: %s" % [photos]
		elif not camp.state.scrapbook.has(str(rabbit["row"]["model"])):
			why = "the photo should fill the animal's scrapbook page"
	# Alone, crawling into the tent at midday sleeps the day away.
	if why == "":
		var day := s.day.today()
		camp.hold_tool("p_host", "hands")
		_stand(camp, "p_host", camp.home_tent_pos() + Vector2(1.6, 0.0))
		await _tree().process_frame
		camp._unhandled_input(_key("interact"))
		await _tree().process_frame
		if s.day.today() != day + 1 or not camp.report.visible or camp._inside.has("p_host"):
			why = "alone, sleeping in the tent at midday should bring the next morning"
	await _done()
	return why


## First-minutes round 4 in the scene, over ENet: free guests walk off to what GuestPlans says and settle there with
## its prop or on their seat, the same on the guest PC as on the host; two frisbee players get a disc in the air.
func test_guests_go_fishing_sit_and_play_frisbee_on_both_pcs() -> String:
	_fresh()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24732)
	var s: CampState = host.state if why == "" else null
	if why == "":
		s.camp["coins"] = 500
		for p: Vector2 in [Vector2(3, 5), Vector2(-4, 7), Vector2(4, 9)]:
			why = s.build.build("p_host", "pitch", p, 0.0)
			if why != "":
				break
			host._show_object(s.build.last_id)
	if why == "":
		_at_hour(host, Tuning.num("day", "stays.arrive_hour"))
		for i in 3:
			s.day.maybe_arrive()
			s.camp["calendar"]["minute"] = float(s.camp["calendar"]["minute"]) + Tuning.num("day", "stays.gap_min")
		for id: String in s.camp["stays"]:
			s.camp["stays"][id]["request"] = {"kind": "fish", "done": true}
			s.camp["stays"][id]["next_at"] = INF
		# A slot with a frisbee pair and a seat taken, so every kind of settling shows.
		var found := false
		for day in 8:
			s.camp["calendar"]["day"] = day + 1
			for slot in int(CampDay.day_minutes() / Tuning.num("guests", "activities.slot_min")) - 3:
				s.camp["calendar"]["minute"] = (slot + 0.5) * Tuning.num("guests", "activities.slot_min")
				var kinds: Array = GuestPlans.plan(s, false).values().map(func(p: Dictionary) -> String: return p["kind"])
				if kinds.has("frisbee") and (kinds.has("sit") or kinds.has("fish")):
					found = true
					break
			if found:
				break
		if not found:
			why = "no slot in 8 days had a frisbee pair with a seat or fishing"
		host._sync_stays(false)
		host._share()
	var guest := _camp("GuestSide", "p_guest", "Gus")
	if why == "":
		guest.start_join("127.0.0.1", 24732)
		if not await _until(func() -> bool: return guest.state != null and guest.visitors.size() == 3 \
				and guest.state.day.minute() == s.day.minute()):
			why = "the guest PC should see all three guests"
	for camp: Node in [host, guest]:
		if why != "":
			break
		await _tree().process_frame
		for id: String in camp.visitors:
			var c: Camper = camp.visitors[id]
			if c.walk_target is Vector3:
				c.position = c.walk_target
		if not await _until(func() -> bool: return camp._doing.size() == 3 and camp._doing.values().all(
				func(d: Dictionary) -> bool: return d.get("settled", false))):
			why = "every guest should settle at what they are doing"
			break
		var plans := GuestPlans.plan(camp.state, false)
		for id: String in plans:
			var p: Dictionary = plans[id]
			var c: Camper = camp.visitors[id]
			if Vector2(c.position.x, c.position.z).distance_to(p["at"]) > 0.05 or c.held != p["prop"] \
					or c.sitting() != (float(p["sit_y"]) > 0.0):
				why = "%s should be at %s holding %s, is at %s holding %s" % [id, p, p["prop"], c.position, c.held]
		if why == "" and camp._discs.size() != 1:
			why = "%s: the frisbee pair should have a disc in the air, got %d: %s" % [camp.name, camp._discs.size(), camp._doing]
	if why == "" and GuestPlans.plan(guest.state, false) != GuestPlans.plan(s, false):
		why = "both PCs should agree on what every guest is doing"
	await _done()
	return why
