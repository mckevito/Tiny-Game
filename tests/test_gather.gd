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
	if state.pack.count("p_host", "wood") != 0 or _loose(state, "wood") != per_tree:
		return "each chop should pop one wood out onto the grass, not into the Pack"
	for id: String in state.camp["bundles"].keys():
		state.set_player_pos("p_host", CampPack.bundle_pos(state.camp["bundles"][id]), 0.0)
		if state.pack.sweep("p_host", [id]) != "":
			return "a piece still in the air should wait before it can be swept up"
		if state.pack.sweep("p_host") != id:
			return "walking over a landed piece should sweep it up"
	if state.pack.count("p_host", "wood") != per_tree or _loose(state, "wood") != 0:
		return "sweeping should put every piece in the Pack, got %d" % state.pack.count("p_host", "wood")
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(1, 0), 0.0)
	if state.gather.chop("p_host", index) != "deny.no_tree" or state.gather.tree_near(at) == index:
		return "a fallen tree should not be offered for chopping"
	if state.gather.chop("p_host", 0) != "deny.not_movable":
		return "the ground is not a tree"
	if state.gather.sapling_near(at) != index or state.gather.stump_near(at) >= 0:
		return "the fallen tree should leave a sapling to pick up by its stump"
	for i in int(Tuning.num("items", "pack_slots")):
		state.pack.add("p_host", "item_%d" % i, int(Tuning.num("items", "stack_max")))
	if state.gather.take_sapling("p_host", index) != "deny.pack_full" or state.gather.sapling_near(at) != index:
		return "with a full Pack the sapling should wait by the stump, never lost"
	state.pack.add("p_host", "wood", int(Tuning.num("items", "stack_max")))
	var other: Dictionary = CampGather.trees()[1]
	state.set_player_pos("p_host", (other["pos"] as Vector2) + Vector2(1, 0), 0.0)
	if state.gather.chop("p_host", int(other["index"])) != "" or _loose(state, "wood") != 1:
		return "with a full Pack a chop should still pop its wood onto the grass"
	var piece: String = state.camp["bundles"].keys()[0]
	state.set_player_pos("p_host", CampPack.bundle_pos(state.camp["bundles"][piece]), 0.0)
	if state.pack.sweep("p_host") != "" or not state.camp["bundles"].has(piece):
		return "a full Pack should leave the wood on the grass, never lost"
	state.camp["bundles"].erase(piece)
	state.camp["trees"].erase(str(other["index"]))
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(1, 0), 0.0)
	state.camp["profiles"]["p_host"]["pack"] = []
	if state.gather.plant("p_host", index) != "deny.no_stump":
		return "planting needs a bare stump first"
	if state.gather.take_sapling("p_host", index) != "" or state.pack.first_of("p_host", "plant") != "sapling":
		return "the sapling should go into the Pack"
	if state.gather.plant("p_guest", index) != "deny.no_sapling" and state.player_pos("p_guest").distance_to(at) < 2.0:
		return "planting needs a sapling"
	if state.gather.plant("p_host", index) != "" or not state.pack.slots("p_host").is_empty() \
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


func _loose(state: CampState, item: String) -> int:
	var n := 0
	for row: Dictionary in state.camp["bundles"].values():
		if row.get("loose", false) and row["item"] == item:
			n += int(row["n"])
	return n


## The shovel: a stump (its sapling still by it or not) digs up into a hole, popping its roots as wood and the sapling
## too; a sapling planted in the hole grows back; a hole left empty is grass by morning and free to build on.
func test_the_shovel_digs_a_stump_into_a_hole_that_grasses_over() -> String:
	var state := _camp()
	var tree: Dictionary = CampGather.trees()[0]
	var index := int(tree["index"])
	state.set_player_pos("p_host", (tree["pos"] as Vector2) + Vector2(1, 0), 0.0)
	if state.gather.dig("p_host", index) != "deny.no_dig":
		return "a standing tree should not be dug up"
	for i in int(Tuning.num("gather", "trees.wood_per_tree")):
		state.gather.chop("p_host", index)
	state.camp["bundles"] = {}
	var at := state.player_pos("p_host")
	if state.gather.dig_near(at) != index or state.gather.dig("p_host", index) != "":
		return "a stump with its sapling beside it should dig up"
	if state.gather.tree(index)["stage"] != "hole" or _loose(state, "sapling") != 1 \
			or _loose(state, "wood") != int(Tuning.num("gather", "dig.roots_wood")):
		return "digging should leave a hole and pop out the roots and the sapling"
	if state.gather.dig_near(at) >= 0 or state.gather.stump_near(at) != index:
		return "a hole is not dug again, but takes a sapling"
	state.pack.add("p_host", "sapling")
	if state.gather.plant("p_host", index) != "" or state.gather.tree(index)["stage"] != "sapling":
		return "a sapling should go into the hole"
	var second: Dictionary = CampGather.trees()[1]
	var j := int(second["index"])
	state.set_player_pos("p_host", (second["pos"] as Vector2) + Vector2(1, 0), 0.0)
	for i in int(Tuning.num("gather", "trees.wood_per_tree")):
		state.gather.chop("p_host", j)
	state.gather.take_sapling("p_host", j)
	if state.gather.dig("p_host", j) != "":
		return "a bare stump should dig up too"
	var spot := CampGather.tree_pos(j)
	var blocked := state.build.check("pitch", spot, 0.0)
	state.camp["calendar"]["day"] = int(state.camp["calendar"]["day"]) + 1
	state.gather.new_day()
	if not state.gather.cleared(j) or state.gather.tree(index)["stage"] != "sapling":
		return "an empty hole should grass over by morning; a planted one keeps growing"
	if blocked == state.build.check("pitch", spot, 0.0) and blocked == "deny.too_close":
		return "a cleared spot should no longer block building"
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
	if state.gather.forage("p_host", stick) != "" or state.pack.count("p_host", "stick") != 1:
		return "sticks should go into the Pack"
	if state.gather.forage("p_host", stick) != "deny.nothing_here" or state.gather.spot_near(CampGather.spot_pos(stick)) >= 0:
		return "a picked spot should be empty until morning"
	state.set_player_pos("p_host", CampGather.spot_pos(berry), 0.0)
	if state.gather.spot_ready(berry) or state.gather.forage("p_host", berry) != "deny.nothing_here":
		return "berries should not be out on day 1"
	state.camp["calendar"]["day"] = 2
	state.gather.new_day()
	if not state.gather.spot_ready(stick) or state.gather.forage("p_host", berry) != "" \
			or state.pack.first_of("p_host", "fruit") != "berries":
		return "on day 2 the sticks should be back and berries should go into the Pack"
	return ""


func test_crafted_things_go_into_the_kit_and_build_mode_places_them() -> String:
	var state := _camp()
	var at := Vector2(-3.2, 7.9)
	if Array(state.build.available()) != ["pitch", "project_board"]:
		return "a new camp's kit should hold the free tent pitch and the camp board, got %s" % [state.build.available()]
	if state.build.build("p_host", "log_bench", at, 0.0) != "deny.not_in_kit":
		return "a log bench not crafted yet should say so"
	state.set_player_pos("p_host", CampBuild.bench_pos() + Vector2(0.0, 1.2), 0.0)
	if state.build.craft("p_host", "log_bench") != "deny.materials":
		return "crafting with an empty Pack and box should say what is missing"
	var r := CampBuild.recipe("log_bench")
	for item: String in r["items"]:
		state.pack.add("p_host", item, int(r["items"][item]))
	var coins := int(state.camp["coins"])
	if state.build.craft("p_host", "log_bench") != "" or state.build.in_kit("log_bench") != 1 \
			or not state.pack.slots("p_host").is_empty() or int(state.camp["coins"]) != coins - int(r.get("coins", 0)):
		return "crafting should use the Pack's materials and put a bench in the kit"
	if not state.build.available().has("log_bench"):
		return "build mode should offer what the kit holds"
	if state.build.build("p_host", "log_bench", at, 0.0) != "" or state.build.in_kit("log_bench") != 0:
		return "putting the bench down should take it from the kit"
	if state.build.pack("p_host", state.build.last_id) != "" or state.build.in_kit("log_bench") != 1:
		return "packing the bench away should put it back in the kit, not back into wood"
	coins = int(state.camp["coins"])
	if state.build.build("p_host", "pitch", Vector2(3, 5), 0.0) != "" or state.build.in_kit("pitch") != -1 \
			or int(state.camp["coins"]) != coins - CampBuild.cost("pitch"):
		return "the tent pitch should always be in the kit, for its coins"
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
	var got := state.gather.split_log(id)
	if state.camp["objects"].has(id) or state.pack.box_count("wood") != got or got <= 0:
		return "splitting should turn the log into wood in the camp box"
	if state.gather.lay_log() == "":
		return "the next morning should lay a new log"
	return ""
