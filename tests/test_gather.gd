extends RefCounted
## Stage B round 2 rules without a scene: trees that give wood and rest until morning, forage spots that refill,
## the log bench built from wood, the Today list (firsts, then daily tasks) and the animals' hours
## (data/gather.json, data/tasks.json, data/wildlife.json).


func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func test_a_tree_falls_drops_a_sapling_and_grows_back_where_it_is_planted() -> String:
	var state := _camp()
	var tree: Dictionary = CampGather.trees()[0]
	var index := int(tree["index"])
	var per_tree := int(Tuning.num("gather", "trees.wood_per_tree"))
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(6, 0), 0.0)
	if state.gather.chop("p_host", index) != "deny.too_far":
		return "chopping from far away should say so"
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(1, 0), 0.0)
	var at := state.player_pos("p_host")
	if state.gather.tree_near(at) != index:
		return "the tree should be within reach"
	for i in per_tree:
		if state.gather.chop("p_host", index) != "" or state.gather.felled != (i == per_tree - 1):
			return "chop %d should be allowed, and only the last should fell the tree" % (i + 1)
	if int(state.camp["wood"]) != per_tree:
		return "each chop should add one wood, got %d" % int(state.camp["wood"])
	if state.gather.chop("p_host", index) != "deny.no_tree" or state.gather.tree_near(at) == index:
		return "a fallen tree should not be offered for chopping"
	if state.gather.chop("p_host", 0) != "deny.not_movable":
		return "the ground is not a tree"
	if state.gather.sapling_near(at) != index or state.gather.stump_near(at) >= 0:
		return "the fallen tree should leave a sapling to pick up by its stump"
	state.camp["profiles"]["p_host"]["pockets"] = ["perch", "perch", "perch", "perch", "perch", "perch"]
	if state.gather.take_sapling("p_host", index) != "deny.pockets_full" or state.gather.sapling_near(at) != index:
		return "with full pockets the sapling should wait by the stump, never lost"
	state.camp["profiles"]["p_host"]["pockets"] = []
	if state.gather.plant("p_host", index) != "deny.no_stump":
		return "planting needs a bare stump first"
	if state.gather.take_sapling("p_host", index) != "" or state.pockets.first_of("p_host", "plant") != "sapling":
		return "the sapling should go into the pockets"
	if state.gather.plant("p_guest", index) != "deny.no_sapling" and state.player_pos("p_guest").distance_to(at) < 2.0:
		return "planting needs a sapling"
	if state.gather.plant("p_host", index) != "" or not state.pockets.pockets("p_host").is_empty() \
			or state.gather.tree(index)["stage"] != "sapling":
		return "a sapling should be planted at the bare stump"
	for d in int(Tuning.num("gather", "trees.grow_days")) - 1:
		state.camp["calendar"]["day"] = int(state.camp["calendar"]["day"]) + 1
		state.gather.new_day()
	if state.gather.wood_left(index) != 0:
		return "a sapling should take its time to grow"
	state.camp["calendar"]["day"] = int(state.camp["calendar"]["day"]) + 1
	state.gather.new_day()
	if state.gather.wood_left(index) != per_tree:
		return "after grow_days mornings the tree should stand again, full of wood"
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


func test_the_long_log_goes_faster_together_and_splits_by_the_fire() -> String:
	var state := _camp()
	var id := state.gather.lay_log()
	if id == "" or state.gather.lay_log() != "":
		return "one long log should lie at the edge of the woods, never two"
	var model := str(state.camp["objects"][id]["model"])
	if not CampState.can_carry(model):
		return "the long log should be carried like a chair"
	var me := Vector3(-9, 0, 3.6)
	var alone := CampGather.carry_speed(model, me, [Vector3(5, 0, 5)] as Array[Vector3])
	var together := CampGather.carry_speed(model, me, [me + Vector3(1, 0, 0)] as Array[Vector3])
	if alone >= 1.0 or together != 1.0 or CampGather.carry_speed("chair", me, [] as Array[Vector3]) != 1.0:
		return "the log should go slowly alone and at full pace with a friend beside (got %s, %s)" % [alone, together]
	if CampGather.log_by_fire(model, Vector2(-9, 3.6)) or not CampGather.log_by_fire(model, Vector2(1.5, 1.0)) \
			or CampGather.log_by_fire("chair", Vector2(1.5, 1.0)):
		return "only a long log set down by the fire should split"
	var wood := int(state.camp["wood"])
	var got := state.gather.split_log(id)
	if state.camp["objects"].has(id) or int(state.camp["wood"]) != wood + got or got <= 0:
		return "splitting should turn the log into wood on the pile"
	if state.gather.lay_log() == "":
		return "the next morning should lay a new log"
	return ""
