class_name CampGather
extends RefCounted
## Gathering: chopping the clearing's trees for wood (into the chopper's Pack) and picking up what the forage spots hold. A tree gives a few
## wood, then falls: a stump stays and a sapling drops beside it to pick up and plant back at a stump, where it grows
## into a tree again in a few mornings (like Animal Crossing). Forage spots refill each morning. Wood goes on the camp's
## shared wood pile. The host's copy decides; every rule takes a profile ID and returns "" or a text key.
## Numbers: data/gather.json.

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## What the last allowed forage picked up.
var last_item := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _v(key: String, fallback: Variant = null) -> Variant:
	return Tuning.value("gather", key, fallback)


## The choppable trees: [{index (in data/clearing.json placements), pos (Vector2)}].
static func trees() -> Array:
	var out: Array = []
	var models: Array = _v("trees.models", [])
	var rows: Array = Tuning.table("clearing").get("placements", [])
	for i in rows.size():
		if models.has(rows[i].get("model", "")):
			var o := Clearing.placement_transform(rows[i]).origin
			out.append({"index": i, "pos": Vector2(o.x, o.z)})
	return out


## A tree's row in the camp's "trees": {chops, stage ("standing", "stump" or "sapling"), sapling_out (a sapling
## lies by the stump to pick up), planted (the day number it was planted)}. A tree never chopped has no row.
func tree(index: int) -> Dictionary:
	return state.camp["trees"].get(str(index), {"chops": 0, "stage": "standing", "sapling_out": false, "planted": 0})


func _set_tree(index: int, row: Dictionary) -> void:
	state.camp["trees"][str(index)] = row


func wood_left(index: int) -> int:
	if tree(index)["stage"] != "standing":
		return 0
	return int(_v("trees.wood_per_tree", 3)) - int(tree(index)["chops"])


static func tree_pos(index: int) -> Vector2:
	var o := Clearing.placement_transform(Tuning.table("clearing")["placements"][index]).origin
	return Vector2(o.x, o.z)


## The nearest tree within reach of a spot for which `test` (index -> bool) holds, or -1.
func _tree_where(pos: Vector2, test: Callable) -> int:
	var best := -1
	var best_d := float(_v("trees.reach_m", 1.6))
	for t: Dictionary in trees():
		var d := pos.distance_to(t["pos"])
		if d <= best_d and test.call(int(t["index"])):
			best = int(t["index"])
			best_d = d
	return best


## The nearest standing tree within reach of a spot, or -1.
func tree_near(pos: Vector2) -> int:
	return _tree_where(pos, func(i: int) -> bool: return wood_left(i) > 0)


## The nearest fallen tree whose sapling still lies by its stump, or -1.
func sapling_near(pos: Vector2) -> int:
	return _tree_where(pos, func(i: int) -> bool: return bool(tree(i)["sapling_out"]))


## The nearest bare stump (its sapling picked up) within reach, or -1.
func stump_near(pos: Vector2) -> int:
	return _tree_where(pos, func(i: int) -> bool: return tree(i)["stage"] == "stump" and not bool(tree(i)["sapling_out"]))


func _check_tree(profile_id: String, index: int) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not trees().any(func(t: Dictionary) -> bool: return int(t["index"]) == index):
		return "deny.not_movable"
	if tree_pos(index).distance_to(state.player_pos(profile_id)) \
			> float(_v("trees.reach_m", 1.6)) + Tuning.num("tuning", "carry.reach_slack_m"):
		return "deny.too_far"
	return ""


## A chop: one wood from the tree into the chopper's Pack (it stays in the tree while the Pack is full). The last chop fells it: a stump stays and a sapling drops
## beside it. `felled` says whether this chop did.
var felled := false


func chop(profile_id: String, index: int) -> String:
	felled = false
	var why := _check_tree(profile_id, index)
	if why != "":
		return why
	if wood_left(index) <= 0:
		return "deny.no_tree"
	var wood := str(_v("wood_item", "wood"))
	if state.pack.room_for(profile_id, wood) <= 0:
		return "deny.pack_full"
	var row := tree(index).duplicate()
	row["chops"] = int(row["chops"]) + 1
	if int(row["chops"]) >= int(_v("trees.wood_per_tree", 3)):
		row = {"chops": 0, "stage": "stump", "sapling_out": true, "planted": 0}
		felled = true
	_set_tree(index, row)
	state.pack.add(profile_id, wood)
	return ""


## Picks up the sapling lying by a fallen tree's stump into the Pack (it waits there while the Pack is full).
func take_sapling(profile_id: String, index: int) -> String:
	var why := _check_tree(profile_id, index)
	if why != "":
		return why
	if not bool(tree(index)["sapling_out"]):
		return "deny.nothing_here"
	if state.pack.add(profile_id, str(_v("trees.sapling_item", "sapling"))) <= 0:
		return "deny.pack_full"
	var row := tree(index).duplicate()
	row["sapling_out"] = false
	_set_tree(index, row)
	return ""


## Plants a sapling from the Pack at a bare stump. It grows back into the tree after grow_days mornings.
func plant(profile_id: String, index: int) -> String:
	var why := _check_tree(profile_id, index)
	if why != "":
		return why
	if tree(index)["stage"] != "stump" or bool(tree(index)["sapling_out"]):
		return "deny.no_stump"
	var item := str(_v("trees.sapling_item", "sapling"))
	if not state.pack.remove(profile_id, item):
		return "deny.no_sapling"
	_set_tree(index, {"chops": 0, "stage": "sapling", "sapling_out": false, "planted": state.day.today()})
	return ""


static func spots() -> Array:
	return _v("spots", [])


## True when a forage spot holds something now: its day has come and nobody picked it today.
func spot_ready(index: int) -> bool:
	var row: Dictionary = spots()[index]
	return state.day.today() >= int(row.get("from_day", 1)) and not state.camp["forage"].has(str(index))


static func spot_pos(index: int) -> Vector2:
	var p: Array = spots()[index]["pos"]
	return Vector2(float(p[0]), float(p[1]))


## The nearest ready forage spot within reach of a spot, or -1.
func spot_near(pos: Vector2) -> int:
	var best := -1
	var best_d := float(_v("forage_reach_m", 1.3))
	for i in spots().size():
		var d := pos.distance_to(spot_pos(i))
		if spot_ready(i) and d <= best_d:
			best = i
			best_d = d
	return best


## Picks up what a forage spot holds into the Pack (it stays on its spot while the Pack is full).
func forage(profile_id: String, index: int) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if index < 0 or index >= spots().size() or not spot_ready(index):
		return "deny.nothing_here"
	if spot_pos(index).distance_to(state.player_pos(profile_id)) \
			> float(_v("forage_reach_m", 1.3)) + Tuning.num("tuning", "carry.reach_slack_m"):
		return "deny.too_far"
	last_item = str(spots()[index]["item"])
	if state.pack.add(profile_id, last_item) <= 0:
		return "deny.pack_full"
	state.camp["forage"][str(index)] = true
	return ""


## The long log: one lies at the edge of the woods each morning while the camp has none. Returns its new object id,
## or "" when one is already about.
func lay_log() -> String:
	var model := str(_v("long_log.model", "long_log"))
	for id: String in state.camp["objects"]:
		if str(state.camp["objects"][id]["model"]) == model:
			return ""
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	var id := "%s_%d" % [model, n]
	var p: Array = _v("long_log.pos", [0, 0])
	state.camp["objects"][id] = {"model": model, "pos": [float(p[0]), float(p[1])], "yaw": float(_v("long_log.yaw", 0))}
	return id


## True when a set-down long log lies by the fire (a fire_model in the clearing), ready to split.
static func log_by_fire(model: String, pos: Vector2) -> bool:
	if model != str(_v("long_log.model", "long_log")):
		return false
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		if str(row.get("model", "")) == str(_v("long_log.fire_model", "fire_pit")):
			var o := Clearing.placement_transform(row).origin
			if Vector2(o.x, o.z).distance_to(pos) <= float(_v("long_log.fire_m", 2.6)):
				return true
	return false


## Splits a long log by the fire into wood in the camp box; the log is gone until the next morning lays another.
func split_log(id: String) -> int:
	var wood := int(_v("long_log.wood", 6))
	state.camp["objects"].erase(id)
	state.pack.add_to_box(str(_v("wood_item", "wood")), wood)
	return wood


## How fast someone carrying `model` walks (1 for most things): a long log goes slowly alone, at full pace with a
## friend within help_m.
static func carry_speed(model: String, carrier: Vector3, others: Array[Vector3]) -> float:
	if model != str(_v("long_log.model", "long_log")):
		return 1.0
	for p in others:
		if Vector2(p.x - carrier.x, p.z - carrier.z).length() <= float(_v("long_log.help_m", 2.2)):
			return 1.0
	return float(_v("long_log.alone_speed", 0.45))


## The morning: saplings old enough grow back into trees, and every forage spot refills.
func new_day() -> void:
	for key: String in (state.camp["trees"] as Dictionary).keys():
		var row: Dictionary = state.camp["trees"][key]
		if row["stage"] == "sapling" and state.day.today() - int(row["planted"]) >= int(_v("trees.grow_days", 2)):
			state.camp["trees"].erase(key)
	state.camp["forage"] = {}
