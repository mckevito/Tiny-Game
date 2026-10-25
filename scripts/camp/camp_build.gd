class_name CampBuild
extends RefCounted
## Grid placement: building things (Stage A: tent pitches) on the camp's grid, packing them away at a full refund,
## and undoing a player's own last steps. The host's copy decides; every rule takes a profile ID and returns "" or a
## text key ("deny.*" in data/text.json). Numbers: data/build.json.

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## Profile id -> that player's steps, newest last: {"op": "build", "id"} or {"op": "pack", "id", "row"}. Not saved;
## cleared each night.
var undo := {}
## The object the last allowed step built, packed or brought back.
var last_id := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func kinds() -> Dictionary:
	return Tuning.value("build", "kinds", {})


## What kind of building an object is ("pitch"), or "" when it is not a building.
static func kind_of(camp_state: CampState, object_id: String) -> String:
	var row: Dictionary = camp_state.camp["objects"].get(object_id, {})
	var model := str(row.get("model", ""))
	for kind: String in kinds():
		if str(kinds()[kind].get("model", "")) == model:
			return kind
	return ""


static func cost(kind: String) -> int:
	return int(kinds().get(kind, {}).get("cost", 0))


## The grid point nearest to a spot on the ground.
static func snap(pos: Vector2) -> Vector2:
	var g := maxf(Tuning.num("build", "grid_m", 1.0), 0.01)
	return Vector2(roundf(pos.x / g) * g, roundf(pos.y / g) * g)


## A yaw in degrees turned to the nearest quarter turn, 0 to 270.
static func quarter(yaw_deg: float) -> float:
	return fposmod(roundf(yaw_deg / 90.0) * 90.0, 360.0)


## A building's footprint size [x, z] in metres at a quarter-turn yaw.
static func footprint(kind: String, yaw_deg: float) -> Vector2:
	var s: Array = kinds().get(kind, {}).get("size", [1, 1])
	var size := Vector2(float(s[0]), float(s[1]))
	return Vector2(size.y, size.x) if int(quarter(yaw_deg)) % 180 == 90 else size


func _rect(id: String) -> Rect2:
	var row: Dictionary = state.camp["objects"][id]
	var size := footprint(kind_of(state, id), float(row.get("yaw", 0)))
	return Rect2(Vector2(float(row["pos"][0]), float(row["pos"][1])) - size * 0.5, size)


## The building whose footprint holds a spot, or "".
func building_at(pos: Vector2) -> String:
	for id: String in state.camp["objects"]:
		if kind_of(state, id) != "" and _rect(id).has_point(pos):
			return id
	return ""


## "" when `kind` could be built at a grid spot, or a text key saying why not. `ignore` is a building to leave out.
func check(kind: String, pos: Vector2, yaw_deg: float, ignore: String = "") -> String:
	if not kinds().has(kind):
		return "deny.not_buildable"
	var size := footprint(kind, yaw_deg)
	var rect := Rect2(pos - size * 0.5, size)
	var edge := Tuning.num("tuning", "carry.camp_radius_m")
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if (corner as Vector2).length() > edge:
			return "deny.out_of_bounds"
	var gap := Tuning.num("build", "object_gap_m", 0.5)
	for id: String in state.camp["objects"]:
		if id == ignore:
			continue
		if kind_of(state, id) != "":
			if _rect(id).intersects(rect):
				return "deny.too_close"
		elif rect.grow(gap).has_point(state.object_pos(id)):
			return "deny.too_close"
	var blockers: Dictionary = Tuning.value("build", "blockers", {})
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		var radius := float(blockers.get(str(row.get("model", "")), 0.0))
		if radius > 0.0:
			var p: Array = row["pos"]
			var at := Vector2(float(p[0]), float(p[1]))
			if at.distance_to(at.clamp(rect.position, rect.end)) < radius:
				return "deny.too_close"
	return ""


## Builds `kind` at the grid spot nearest `pos` for its cost in coins. Returns "" or a text key.
func build(profile_id: String, kind: String, pos: Vector2, yaw_deg: float) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	pos = snap(pos)
	yaw_deg = quarter(yaw_deg)
	var why := check(kind, pos, yaw_deg)
	if why == "" and int(state.camp.get("coins", 0)) < cost(kind):
		why = "deny.coins"
	if why != "":
		return why
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	var id := "%s_%d" % [kind, n]
	_put(id, kind, pos, yaw_deg)
	_remember(profile_id, {"op": "build", "id": id})
	return ""


func _put(id: String, kind: String, pos: Vector2, yaw_deg: float) -> void:
	state.camp["coins"] = int(state.camp.get("coins", 0)) - cost(kind)
	state.camp["objects"][id] = {"model": str(kinds()[kind]["model"]), "pos": [pos.x, pos.y], "yaw": yaw_deg}
	last_id = id


## Packs a building away at a full refund. A pitch with a guest stays until they leave. Returns "" or a text key.
func pack(profile_id: String, id: String, remember: bool = true) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	var kind := kind_of(state, id)
	if kind == "":
		return "deny.not_movable"
	if state.day.stay_at(id) != "":
		return "deny.pitch_in_use"
	var row: Dictionary = state.camp["objects"][id]
	state.camp["objects"].erase(id)
	state.camp["coins"] = int(state.camp.get("coins", 0)) + cost(kind)
	last_id = id
	if remember:
		_remember(profile_id, {"op": "pack", "id": id, "row": row})
	return ""


## Takes back this player's last building step: a building goes away (refunded), a packed one comes back (paid).
func undo_last(profile_id: String) -> String:
	var steps: Array = undo.get(profile_id, [])
	if steps.is_empty():
		return "deny.nothing_to_undo"
	var step: Dictionary = steps.back()
	var why := ""
	if step["op"] == "build":
		last_id = step["id"]
		why = pack(profile_id, step["id"], false) if state.camp["objects"].has(step["id"]) else ""
	else:
		var row: Dictionary = step["row"]
		var kind := ""
		for k: String in kinds():
			if kinds()[k]["model"] == row["model"]:
				kind = k
		var pos := Vector2(float(row["pos"][0]), float(row["pos"][1]))
		why = check(kind, pos, float(row["yaw"]))
		if why == "" and int(state.camp.get("coins", 0)) < cost(kind):
			why = "deny.coins"
		if why == "":
			_put(step["id"], kind, pos, float(row["yaw"]))
	if why == "":
		steps.pop_back()
	return why


func _remember(profile_id: String, step: Dictionary) -> void:
	if not undo.has(profile_id):
		undo[profile_id] = []
	var steps: Array = undo[profile_id]
	steps.append(step)
	while steps.size() > int(Tuning.num("build", "undo_depth", 20)):
		steps.pop_front()
