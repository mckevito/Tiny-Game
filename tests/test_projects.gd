extends RefCounted
## Gameplay round 2: where gathering goes. The sell crate (pays at night, take back until then) and the camp
## projects (bundles both players fill, rewards once, recipes open at the workbench), as rules and from the buttons
## over ENet (data/projects.json).

const DIR := "user://test_saves/projects"
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _state() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func _spot(model: String) -> Vector2:
	for row: Dictionary in Tuning.table("clearing")["placements"]:
		if row["model"] == model:
			return Vector2(float(row["pos"][0]), float(row["pos"][1]))
	return Vector2(INF, INF)


func _beside(model: String) -> Vector2:
	if model == "project_board":
		var spot: Array = Tuning.value("save", "board_spot")
		return Vector2(float(spot[0]), float(spot[1])) + Vector2(0.0, -0.9)
	return _spot(model) + Vector2(0.0, -0.9)


## Puts the camp board up where an older camp had it (a new camp keeps it in the kit until the players place it).
func _put_up_board(s: CampState) -> void:
	var spot: Array = Tuning.value("save", "board_spot")
	if s.build.build("p_host", "project_board", Vector2(float(spot[0]), float(spot[1])), 0.0) != "":
		push_error("the camp board should go up at board_spot")


func test_the_sell_crate_pays_at_night_and_gives_back_until_then() -> String:
	var s := _state()
	s.pack.add("p_host", "sapling", 1)
	s.pack.add("p_host", "stick", 5)
	s.pack.add("p_host", "perch", 2)
	s.set_player_pos("p_host", Vector2(20, 20), 0.0)
	if s.projects.ship("p_host") != "deny.too_far":
		return "the crate should only take things from a player beside it"
	s.set_player_pos("p_host", _beside("sell_crate"), 0.0)
	if s.projects.ship("p_host") != "" or s.pack.count("p_host", "stick") != 0 or s.projects.crate().size() != 1:
		return "the first sellable stack (the sapling has no price) should go into the crate whole"
	if s.projects.ship("p_host") != "" or s.pack.count("p_host", "perch") != 0:
		return "a second press should put the next stack in"
	if s.projects.ship("p_host") != "deny.nothing_to_sell" or s.pack.count("p_host", "sapling") != 1:
		return "a sapling is not for sale and stays in the Pack"
	if s.projects.take_back("p_host") != "" or s.pack.count("p_host", "perch") != 2:
		return "the last stack should come back out of the crate whole"
	s.projects.ship("p_host")
	var coins := int(s.camp["coins"])
	var summary := s.day.settle_night()
	var want := 5 * CampProjects.price("stick") + 2 * CampProjects.price("perch")
	if int(summary["sale"]["coins"]) != want or int(s.camp["coins"]) != coins + int(summary["coins"]) \
			or int(summary["coins"]) < want:
		return "the night should pay %d coins for the crate, got %s" % [want, summary.get("sale")]
	if not s.projects.crate().is_empty() or int(s.camp["shipped"].get("stick", 0)) != 5:
		return "the crate should empty and the shipped list count what was sold"
	if not s.day.settle_night().is_empty() and int(s.camp["shipped"].get("stick", 0)) != 5:
		return "a night should never pay the crate twice"
	return ""


func test_camp_projects_fill_from_both_players_and_open_a_recipe_once() -> String:
	var s := _state()
	var first: Dictionary = CampProjects.rows()[0]
	var kind := ""
	for r: Dictionary in CampBuild.recipes():
		if str(r.get("project", "")) == str(first["id"]):
			kind = str(r["kind"])
	if kind == "" or s.build.known_recipes().any(func(r: Dictionary) -> bool: return r["kind"] == kind):
		return "the first project's recipe should be closed until it is done"
	var board := _beside("project_board")
	if CampProjects.near_board(s, board):
		return "a new camp has no board up until the players put it up"
	_put_up_board(s)
	s.set_player_pos("p_host", board, 0.0)
	s.set_player_pos("p_guest", board, 0.0)
	if s.projects.give("p_host") != "deny.nothing_for_project":
		return "with nothing it needs, a gift should be refused with a reason"
	var needs: Dictionary = first["needs"]
	var items := needs.keys()
	# The host brings part of the first need from their Pack; the rest comes from the guest and the camp box.
	s.pack.add("p_host", str(items[0]), int(needs[items[0]]) - 1)
	s.pack.add("p_host", "sapling", 1)
	if s.projects.give("p_host") != "" or s.pack.count("p_host", str(items[0])) != 0 or s.projects.finished != "":
		return "the host's gift should go in without finishing the project"
	if s.pack.count("p_host", "sapling") != 1:
		return "only what the project needs should be taken"
	s.pack.add("p_guest", str(items[0]), 5)
	for i in range(1, items.size()):
		s.pack.add_to_box(str(items[i]), int(needs[items[i]]))
	var coins := int(s.camp["coins"])
	if s.projects.give("p_guest") != "" or s.projects.finished != str(first["id"]):
		return "the guest's gift (with the camp box) should finish the project"
	if s.pack.count("p_guest", str(items[0])) != 4:
		return "a finished project should take only what was missing, leaving the rest"
	if not s.build.known_recipes().any(func(r: Dictionary) -> bool: return r["kind"] == kind):
		return "a finished project should open its recipe at the workbench"
	if int(s.camp["coins"]) != coins + int(first.get("coins", 0)):
		return "a finished project should pay its coins once"
	if s.projects.current()["id"] != CampProjects.rows()[1]["id"]:
		return "the next project should open after the first"
	s.camp["projects"]["done"].assign(CampProjects.rows().map(func(r: Dictionary) -> String: return r["id"]))
	if not s.projects.current().is_empty() or s.projects.give("p_host") != "deny.projects_done":
		return "the project list is finite: once all are done nothing more is asked"
	var saved := CampSave.upgrade(JSON.parse_string(JSON.stringify(s.camp)))
	if (saved["projects"]["done"] as Array).size() != CampProjects.rows().size():
		return "finished projects should survive save and load"
	return ""


func test_a_version_5_save_gets_the_crate_and_projects() -> String:
	var old := CampSave.new_camp()
	for key in ["crate", "shipped", "projects"]:
		old.erase(key)
	old["version"] = 5
	var camp := CampSave.upgrade(old)
	if not (camp["crate"] is Array and camp["shipped"] is Dictionary and camp["projects"]["done"] is Array):
		return "an older save should get an empty crate, shipped list and projects"
	return ""


## First minutes, gameplay round 2: the camp fire grows in levels, paid like a recipe at the fire; each level counts
## toward the rating; the camp board goes up from the kit; an older save gets its board put up where it stood.
func test_the_fire_grows_in_levels_and_the_board_goes_up_from_the_kit() -> String:
	var s := _state()
	var levels := CampBuild.fire_levels()
	s.set_player_pos("p_host", Vector2(1.3, 0.3), 0.0)
	var first: Dictionary = s.build.next_fire()
	if s.build.fire_level() != 0 or first.is_empty():
		return "a new camp's fire should be plain, with a level to grow to"
	if s.build.upgrade_fire("p_host") != "deny.materials":
		return "upgrading without the materials should say so"
	var points := s.rating.points()
	for level: Dictionary in levels:
		for item: String in level["items"]:
			s.pack.add_to_box(item, int(level["items"][item]))
		var coins := int(s.camp["coins"])
		if s.build.upgrade_fire("p_host") != "" or int(s.camp["coins"]) != coins - int(level["coins"]):
			return "with the materials and coins the fire should grow to %s" % level["id"]
	if s.build.fire_level() != levels.size() or not s.build.next_fire().is_empty():
		return "the fire should stop at its last level"
	if s.build.upgrade_fire("p_host") != "deny.fire_done":
		return "a fire at its last level should say it is as big as it gets"
	if s.rating.points() <= points:
		return "a bigger fire should count toward the camp rating"
	s.set_player_pos("p_guest", Vector2(9, 9), 0.0)
	if s.build.upgrade_fire("p_guest") not in ["deny.too_far", "deny.fire_done"]:
		return "the fire is upgraded at the fire"
	if s.build.in_kit("project_board") != 1 or CampProjects.near_board(s, _beside("project_board")):
		return "a new camp's board should wait in the kit"
	_put_up_board(s)
	if s.build.in_kit("project_board") != 0 or not CampProjects.near_board(s, _beside("project_board")):
		return "the board should go up from the kit, and be read where it stands"
	var old := CampSave.new_camp()
	old.erase("fire")
	old["kit"] = {}
	old["version"] = 6
	var camp := CampSave.upgrade(old)
	var boards := (camp["objects"] as Dictionary).values().filter(
			func(o: Dictionary) -> bool: return o["model"] == "project_board")
	if boards.size() != 1 or int(camp["fire"]["level"]) != 0 or camp["kit"].has("project_board"):
		return "a version 6 save should get its board put up where the scenery board stood, and a plain fire"
	return ""


# --- From the buttons, over ENet ---------------------------------------------------------------------------------

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


func _stand(camp: Node, who: String, at: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.position = Vector3(at.x, c.position.y, at.y)
	camp.state.set_player_pos(who, at, 0.0)


func test_the_guest_pc_sells_and_gives_to_a_project_from_the_buttons() -> String:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24741)
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24741)
	if not await _until(func() -> bool: return guest.state != null and host.campers.size() == 2):
		why = "the guest never got in"
	if why == "":
		var spot: Array = Tuning.value("save", "board_spot")
		host.ask("build", ["project_board", Vector2(float(spot[0]), float(spot[1])), 0.0], "p_host")
		if not await _until(func() -> bool: return guest.objects.size() == host.objects.size()):
			why = "the guest PC should see the camp board go up"
	if why == "":
		var first: Dictionary = CampBuild.fire_levels()[0]
		for item: String in first["items"]:
			host.state.pack.add_to_box(item, int(first["items"][item]))
		host.campers["p_host"].position = Vector3(1.3, 0, 0.3)
		host.ask("upgrade_fire", [], "p_host")
		var fire: Node3D = guest.clearing.placed[Tuning.table("clearing")["placements"].map(
				func(r: Dictionary) -> String: return r["model"]).find("fire_pit")]
		if not await _until(func() -> bool: return guest.state.build.fire_level() == 1 \
				and fire.get_node_or_null("Upgrade") != null):
			why = "the guest PC should see the fire grow"
	if why == "":
		host.state.pack.add("p_guest", "stick", 6)
		host.state.pack.add("p_guest", "berries", 4)
		host._share()
		if not await _until(func() -> bool: return guest.state.pack.count("p_guest", "berries") == 4):
			why = "the guest PC should see its Pack"
		_stand(guest, "p_guest", _beside("sell_crate"))
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_beside("sell_crate")) < 0.1)
		guest.interact("p_guest")
		if why != "":
			pass
		elif not await _until(func() -> bool: return guest.state.projects.crate().size() == 1):
			why = "the guest's sticks should go into the crate through the host"
		elif not guest.clipboard_text("p_guest", "supplies").contains(Tuning.text("clipboard.crate") % (Tuning.text("pack.slot") % [Tuning.text("items.stick"), 6])):
			why = "the clipboard's Supplies should list what is in the crate"
	if why == "":
		# The board: the berries the first project needs go in; the crate's sticks are not in the Pack any more.
		_stand(guest, "p_guest", _beside("project_board"))
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_beside("project_board")) < 0.1)
		guest.interact("p_guest")
		var first := str(CampProjects.rows()[0]["id"])
		if not await _until(func() -> bool: return int(guest.state.projects.given().get("berries", 0)) == 4):
			why = "the guest's berries should go to the camp project through the host"
		elif not guest.project_line().contains(Tuning.text("project.%s.name" % first)):
			why = "the Today list should name the open project: " + guest.project_line()
	if why == "":
		host.state.day.vote("p_host", true)
		host.state.day.vote("p_guest", true)
		host._check_bed()
		if not await _until(func() -> bool: return guest.report.visible and host.report.visible):
			why = "both PCs should see the morning report"
		else:
			var line := Tuning.text("report.sale") % [6 * CampProjects.price("stick"),
					Tuning.text("pack.slot") % [Tuning.text("items.stick"), 6]]
			for camp: Node in [host, guest]:
				if why == "" and not camp.report.text().contains(line):
					why = "the morning report should say what the crate paid: " + line
	await _done()
	return why
