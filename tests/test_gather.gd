extends RefCounted
## Stage B round 2 rules without a scene: trees that give wood and rest until morning, forage spots that refill,
## the log bench built from wood, the Today list (firsts, then daily tasks) and the animals' hours
## (data/gather.json, data/tasks.json, data/wildlife.json).


func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func test_a_tree_gives_its_wood_then_rests_until_morning() -> String:
	var state := _camp()
	var tree: Dictionary = CampGather.trees()[0]
	var index := int(tree["index"])
	var per_day := int(Tuning.num("gather", "trees.wood_per_day"))
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(6, 0), 0.0)
	if state.gather.chop("p_host", index) != "deny.too_far":
		return "chopping from far away should say so"
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(1, 0), 0.0)
	if state.gather.tree_near(state.player_pos("p_host")) != index:
		return "the tree should be within reach"
	for i in per_day:
		if state.gather.chop("p_host", index) != "":
			return "chop %d should be allowed" % (i + 1)
	if int(state.camp["wood"]) != per_day:
		return "each chop should add one wood, got %d" % int(state.camp["wood"])
	if state.gather.chop("p_host", index) != "deny.tree_resting" or state.gather.tree_near(state.player_pos("p_host")) == index:
		return "a tree with no wood left today should rest, and not be offered"
	if state.gather.chop("p_host", 0) != "deny.not_movable":
		return "the ground is not a tree"
	state.gather.new_day()
	if state.gather.wood_left(index) != per_day:
		return "a tree should have its wood again in the morning; trees never die"
	return ""


func test_forage_spots_refill_each_morning_and_berries_wait_for_day_two() -> String:
	var state := _camp()
	var stick := -1
	var berry := -1
	for i in CampGather.spots().size():
		var item := str(CampGather.spots()[i]["item"])
		if item == "stick" and stick < 0:
			stick = i
		elif item == "berries" and berry < 0:
			berry = i
	state.set_player_pos("p_host", CampGather.spot_pos(stick), 0.0)
	if state.gather.forage("p_host", stick) != "" or int(state.camp["wood"]) != 1 \
			or not state.pockets.pockets("p_host").is_empty():
		return "sticks should go straight onto the wood pile"
	if state.gather.forage("p_host", stick) != "deny.nothing_here" or state.gather.spot_near(CampGather.spot_pos(stick)) >= 0:
		return "a picked spot should be empty until morning"
	state.set_player_pos("p_host", CampGather.spot_pos(berry), 0.0)
	if state.gather.spot_ready(berry) or state.gather.forage("p_host", berry) != "deny.nothing_here":
		return "berries should not be out on day 1"
	state.camp["calendar"]["day"] = 2
	state.gather.new_day()
	if not state.gather.spot_ready(stick) or state.gather.forage("p_host", berry) != "" \
			or state.pockets.first_of("p_host", "fruit") != "berries":
		return "on day 2 the sticks should be back and berries should go into the pockets"
	return ""


func test_the_log_bench_costs_wood_and_packing_gives_it_back() -> String:
	var state := _camp()
	var at := Vector2(-3.2, 7.9)
	if state.build.build("p_host", "log_bench", at, 0.0) != "deny.wood":
		return "a log bench with an empty wood pile should ask for wood"
	var need := CampBuild.wood_cost("log_bench")
	state.camp["wood"] = need
	var coins := int(state.camp["coins"])
	if state.build.build("p_host", "log_bench", at, 0.0) != "" or int(state.camp["wood"]) != 0 \
			or int(state.camp["coins"]) != coins - CampBuild.cost("log_bench"):
		return "the log bench should be built from wood"
	if state.build.pack("p_host", state.build.last_id) != "" or int(state.camp["wood"]) != need:
		return "packing the bench away should put its wood back on the pile"
	return ""


func test_the_today_list_teaches_with_firsts_then_cycles_daily_tasks() -> String:
	var state := _camp()
	var firsts: Array = Tuning.value("tasks", "firsts")
	var want := int(Tuning.num("tasks", "active_max"))
	var ids: Array = state.tasks.active().map(func(r: Dictionary) -> String: return r["id"])
	if ids != firsts.slice(0, want).map(func(r: Dictionary) -> String: return r["id"]):
		return "the list should start with the firsts in order, got %s" % [ids]
	var coins := int(state.camp["coins"])
	var got: Array[String] = []
	for i in 2:
		got = state.tasks.note("forage:stick")
	if not got.is_empty() or int(state.tasks.active()[0]["have"]) != 2:
		return "steps should count toward the task"
	got = state.tasks.note("forage:stick")
	if got != ["first_sticks"] or int(state.camp["coins"]) != coins + int(firsts[0]["bonus"]):
		return "the third stick should finish the first task and pay its bonus, got %s" % [got]
	if state.tasks.active().size() != want:
		return "the list should top itself up"
	for row: Dictionary in firsts:
		var event := str(row["event"])
		for i in int(row["count"]):
			state.tasks.note(event)
	if not (state.tasks.data()["done"] as Array).has(str(firsts.back()["id"])):
		return "every first should be done"
	ids = state.tasks.active().map(func(r: Dictionary) -> String: return r["id"])
	var daily: Array = Tuning.value("tasks", "daily").map(func(r: Dictionary) -> String: return r["id"])
	if ids.size() != want or ids.any(func(id: String) -> bool: return not daily.has(id)):
		return "after the firsts the list should hold daily tasks, got %s" % [ids]
	if state.tasks.note("spot:deer").is_empty() and state.tasks.note("spot:rabbit").is_empty() \
			and ids.has("spot_animals"):
		return "spotting animals should count"
	var line := CampTasks.line({"id": "chop_wood", "have": 1})
	if not line.contains(Tuning.text("task.chop_wood")) or not line.contains("1/") \
			or not line.contains(Tuning.text("task.place.trees")):
		return "a task line should name the task, the count and the place, got " + line
	return ""


func test_animals_keep_their_hours_and_days() -> String:
	var herds := {}
	for row: Dictionary in Tuning.value("wildlife", "herds"):
		herds[row["model"]] = row
	if not Wildlife.is_out(herds["rabbit"], 9.0, 1) or Wildlife.is_out(herds["rabbit"], 23.0, 1):
		return "rabbits should be out by day and home at night"
	if Wildlife.is_out(herds["deer"], 8.0, 1) or not Wildlife.is_out(herds["deer"], 8.0, 2) \
			or Wildlife.is_out(herds["deer"], 13.0, 2):
		return "deer should come from day 2, at dawn and dusk only"
	if not Wildlife.is_out(herds["bear"], 19.0, 3) or Wildlife.is_out(herds["bear"], 19.0, 2):
		return "the bear should sit by the fire in the evening from day 3"
	var w := Wildlife.new()
	Engine.get_main_loop().root.add_child(w)
	var why := ""
	if w.animals.size() > int(Tuning.num("wildlife", "max_animals")):
		why = "the number of animals should stay within the cap"
	var rabbit: Dictionary = w.animals[0]
	var none: Array[Vector3] = []
	var seen := w.tick(0.1, 9.0, 1, none, [rabbit["node"].position] as Array[Vector3])
	if why == "" and not seen.has("rabbit"):
		why = "a player next to a rabbit should spot it"
	if why == "" and w.tick(0.1, 9.0, 1, none, [rabbit["node"].position] as Array[Vector3]).has("rabbit") \
			and w.animals.filter(func(a: Dictionary) -> bool: return a["row"]["model"] == "rabbit").size() == 1:
		why = "the same animal should be spotted once a day"
	var start: Vector3 = rabbit["node"].position
	for i in 20:
		w.tick(0.05, 9.0, 1, [start + Vector3(0.3, 0, 0)] as Array[Vector3], none)
	if why == "" and rabbit["node"].position.distance_to(start + Vector3(0.3, 0, 0)) <= 0.3:
		why = "a rabbit should hop away from a player who comes close"
	w.free()
	return why
