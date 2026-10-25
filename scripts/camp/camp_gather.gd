class_name CampGather
extends RefCounted
## Gathering: chopping the clearing's trees for wood and picking up what the forage spots hold. Trees never die:
## each gives a few wood a day, then rests until morning; forage spots refill each morning. Wood goes on the camp's
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


func wood_left(index: int) -> int:
	return int(_v("trees.wood_per_day", 3)) - int(state.camp["trees"].get(str(index), 0))


## The nearest choppable tree with wood left today within reach of a spot, or -1.
func tree_near(pos: Vector2) -> int:
	var best := -1
	var best_d := float(_v("trees.reach_m", 1.6))
	for t: Dictionary in trees():
		var d := pos.distance_to(t["pos"])
		if d <= best_d and wood_left(int(t["index"])) > 0:
			best = int(t["index"])
			best_d = d
	return best


## A chop: one wood from the tree onto the camp's pile.
func chop(profile_id: String, index: int) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	var at := -1
	for t: Dictionary in trees():
		if int(t["index"]) == index:
			at = index
			if (t["pos"] as Vector2).distance_to(state.player_pos(profile_id)) \
					> float(_v("trees.reach_m", 1.6)) + Tuning.num("tuning", "carry.reach_slack_m"):
				return "deny.too_far"
	if at < 0:
		return "deny.not_movable"
	if wood_left(index) <= 0:
		return "deny.tree_resting"
	state.camp["trees"][str(index)] = int(state.camp["trees"].get(str(index), 0)) + 1
	state.camp["wood"] = int(state.camp.get("wood", 0)) + 1
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


## Picks up what a forage spot holds: wood items go on the pile, others into the pockets.
func forage(profile_id: String, index: int) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if index < 0 or index >= spots().size() or not spot_ready(index):
		return "deny.nothing_here"
	if spot_pos(index).distance_to(state.player_pos(profile_id)) \
			> float(_v("forage_reach_m", 1.3)) + Tuning.num("tuning", "carry.reach_slack_m"):
		return "deny.too_far"
	last_item = str(spots()[index]["item"])
	if (_v("wood_items", []) as Array).has(last_item):
		state.camp["wood"] = int(state.camp.get("wood", 0)) + 1
	else:
		if state.pockets.pockets(profile_id).size() >= int(Tuning.num("fishing", "pockets_max", 6)):
			return "deny.pockets_full"
		state.pockets.pockets(profile_id).append(last_item)
	state.camp["forage"][str(index)] = true
	return ""


## The morning: every tree has its wood again and every forage spot refills.
func new_day() -> void:
	state.camp["trees"] = {}
	state.camp["forage"] = {}
