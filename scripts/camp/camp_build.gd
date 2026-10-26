class_name CampBuild
extends RefCounted
## Grid placement: building things (Stage A: tent pitches) on the camp's grid, packing them away at a full refund,
## and undoing a player's own last steps. Round 3: crafting at the workbench fills the camp's build kit, shared by
## both players; build mode places from the kit (the tent pitch is free, always there) and packing puts it back. The host's copy decides; every rule takes a profile ID and returns "" or a
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


## True for a kind that is always in the kit (the tent pitch) and costs coins to put down.
static func is_free(kind: String) -> bool:
	return bool(kinds().get(kind, {}).get("free", false))


## How many of a kind the build kit holds now (-1 for a free kind: always one more).
func in_kit(kind: String) -> int:
	return -1 if is_free(kind) else int(state.camp["kit"].get(kind, 0))


## The kinds build mode can put down now, in data/build.json order: the free ones and those in the kit.
func available() -> Array[String]:
	var out: Array[String] = []
	for kind: String in kinds():
		if in_kit(kind) != 0:
			out.append(kind)
	return out


## What putting one down costs, as the player reads it: "25 coins" or "2 in the kit".
func cost_text(kind: String) -> String:
	return Tuning.text("build.coins") % cost(kind) if is_free(kind) else Tuning.text("build.in_kit") % in_kit(kind)


## What packing one away gives back, as the player reads it.
static func refund_text(kind: String) -> String:
	return Tuning.text("build.coins") % cost(kind) if is_free(kind) else Tuning.text("build.to_kit")


## "" when the camp can put down `kind`, or the text key saying what it lacks.
func afford(kind: String) -> String:
	if is_free(kind):
		return "deny.coins" if int(state.camp.get("coins", 0)) < cost(kind) else ""
	return "" if in_kit(kind) > 0 else "deny.not_in_kit"


# --- Crafting --------------------------------------------------------------------------------------------------------

static func recipes() -> Array:
	return Tuning.value("craft", "recipes", [])


## The recipes open at the workbench now: those no project locks, and those whose project is done.
func known_recipes() -> Array:
	return recipes().filter(func(r: Dictionary) -> bool: return state.projects.knows(r))


static func recipe(kind: String) -> Dictionary:
	for r: Dictionary in recipes():
		if r["kind"] == kind:
			return r
	return {}


static func bench_pos() -> Vector2:
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		if str(row.get("model", "")) == str(Tuning.value("craft", "bench_model", "workbench")):
			var o := Clearing.placement_transform(row).origin
			return Vector2(o.x, o.z)
	return Vector2(INF, INF)


static func near_bench(pos: Vector2) -> bool:
	return pos.distance_to(bench_pos()) <= Tuning.num("craft", "reach_m", 1.8)


## "" when a player could craft `kind` now, or the text key saying what is missing.
func can_craft(profile_id: String, kind: String) -> String:
	var r := recipe(kind)
	if r.is_empty() or not state.projects.knows(r):
		return "deny.not_buildable"
	if int(state.camp.get("coins", 0)) < int(r.get("coins", 0)):
		return "deny.coins"
	for item: String in r.get("items", {}):
		if state.pack.have(profile_id, item) < int(r["items"][item]):
			return "deny.materials"
	return ""


## Crafts one `kind` at the workbench from the crafter's Pack and the camp box, into the build kit.
func craft(profile_id: String, kind: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not near_bench(state.player_pos(profile_id)):
		return "deny.too_far"
	var why := can_craft(profile_id, kind)
	if why != "":
		return why
	var r := recipe(kind)
	state.camp["coins"] = int(state.camp.get("coins", 0)) - int(r.get("coins", 0))
	for item: String in r.get("items", {}):
		state.pack.spend(profile_id, item, int(r["items"][item]))
	state.camp["kit"][kind] = in_kit(kind) + 1
	return ""


# --- The camp fire's levels (data/craft.json fire) ---------------------------------------------------------------

static func fire_levels() -> Array:
	return Tuning.value("craft", "fire.levels", [])


## How far the camp fire has been upgraded: 0 (the plain fire pit) to the number of levels.
func fire_level() -> int:
	return int(state.camp.get("fire", {}).get("level", 0))


## The next level the fire can grow to ({id, coins, items, model, light_scale}), or {} when it is as big as it gets.
func next_fire() -> Dictionary:
	var levels := fire_levels()
	return levels[fire_level()] if fire_level() < levels.size() else {}


## "" when a player could upgrade the fire now, or the text key saying what is missing.
func can_upgrade_fire(profile_id: String) -> String:
	var r := next_fire()
	if r.is_empty():
		return "deny.fire_done"
	if int(state.camp.get("coins", 0)) < int(r.get("coins", 0)):
		return "deny.coins"
	for item: String in r.get("items", {}):
		if state.pack.have(profile_id, item) < int(r["items"][item]):
			return "deny.materials"
	return ""


## Grows the fire one level, paid like a recipe from the player's Pack, then the camp box, and the camp's coins.
func upgrade_fire(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not CampPack.can_cook_at(state.player_pos(profile_id)):
		return "deny.too_far"
	if not state.story.lit():
		return "deny.fire_cold"
	var why := can_upgrade_fire(profile_id)
	if why != "":
		return why
	var r := next_fire()
	state.camp["coins"] = int(state.camp.get("coins", 0)) - int(r.get("coins", 0))
	for item: String in r.get("items", {}):
		state.pack.spend(profile_id, item, int(r["items"][item]))
	state.camp["fire"] = {"level": fire_level() + 1}
	return ""


## The camp's grid: cells grid_m wide, centred on grid points counted from grid_origin (data/build.json). A Stage C
## build zone can pass its own cell and origin; the camp uses these.
static func cell_m() -> float:
	return maxf(Tuning.num("build", "grid_m", 1.0), 0.01)


static func grid_origin() -> Vector2:
	var o: Array = Tuning.value("build", "grid_origin", [0.0, 0.0])
	return Vector2(float(o[0]), float(o[1]))


## The grid point nearest to a spot on the ground.
static func snap(pos: Vector2) -> Vector2:
	var g := cell_m()
	var o := grid_origin()
	return o + Vector2(roundf((pos.x - o.x) / g) * g, roundf((pos.y - o.y) / g) * g)


## Where a building's centre goes on the grid so its footprint covers whole cells: an odd number of cells centres on
## a grid point, an even number on the stitch line between two.
static func snap_fit(kind: String, pos: Vector2, yaw_deg: float) -> Vector2:
	var g := cell_m()
	var size := footprint(kind, quarter(yaw_deg))
	var half := Vector2(0.0 if int(roundf(size.x / g)) % 2 == 1 else g * 0.5,
			0.0 if int(roundf(size.y / g)) % 2 == 1 else g * 0.5)
	return snap(pos - half) + half


## Free building: a spot kept to free.step_m so saves stay tidy, and turns in free.turn_deg steps.
static func free_spot(pos: Vector2) -> Vector2:
	var s := maxf(Tuning.num("build", "free.step_m", 0.05), 0.001)
	return Vector2(roundf(pos.x / s) * s, roundf(pos.y / s) * s)


static func free_turn(yaw_deg: float) -> float:
	var t := maxf(Tuning.num("build", "free.turn_deg", 15.0), 1.0)
	return fposmod(roundf(yaw_deg / t) * t, 360.0)


## A yaw in degrees turned to the nearest quarter turn, 0 to 270.
static func quarter(yaw_deg: float) -> float:
	return fposmod(roundf(yaw_deg / 90.0) * 90.0, 360.0)


## The box a building's footprint [x, z] in metres covers on the ground at any yaw (its size swapped at a quarter
## turn, a little wider at a free angle).
static func footprint(kind: String, yaw_deg: float) -> Vector2:
	var s: Array = kinds().get(kind, {}).get("size", [1, 1])
	var size := Vector2(float(s[0]), float(s[1]))
	var a := deg_to_rad(yaw_deg)
	var c := absf(cos(a))
	var n := absf(sin(a))
	return Vector2(size.x * c + size.y * n, size.x * n + size.y * c).snapped(Vector2(0.001, 0.001))


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
	var rows: Array = Tuning.table("clearing").get("placements", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var radius := float(blockers.get(str(row.get("model", "")), 0.0))
		if radius > 0.0 and not state.gather.cleared(i):
			var p: Array = row["pos"]
			var at := Vector2(float(p[0]), float(p[1]))
			if at.distance_to(at.clamp(rect.position, rect.end)) < radius:
				return "deny.too_close"
	return ""


## Builds `kind` at the grid spot nearest `pos` (or, building free, at `pos` itself), from the kit (or for coins, for
## a free kind). Returns "" or a text key.
func build(profile_id: String, kind: String, pos: Vector2, yaw_deg: float, free: bool = false) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	pos = free_spot(pos) if free else snap_fit(kind, pos, yaw_deg)
	yaw_deg = free_turn(yaw_deg) if free else quarter(yaw_deg)
	var why := check(kind, pos, yaw_deg)
	if why == "":
		why = afford(kind)
	if why != "":
		return why
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	var id := "%s_%d" % [kind, n]
	_put(id, kind, pos, yaw_deg)
	_remember(profile_id, {"op": "build", "id": id})
	return ""


func _put(id: String, kind: String, pos: Vector2, yaw_deg: float) -> void:
	if is_free(kind):
		state.camp["coins"] = int(state.camp.get("coins", 0)) - cost(kind)
	else:
		state.camp["kit"][kind] = in_kit(kind) - 1
	state.camp["objects"][id] = {"model": str(kinds()[kind]["model"]), "pos": [pos.x, pos.y], "yaw": yaw_deg}
	last_id = id


## Packs a building away: back into the kit, or its coins back for a free kind. A pitch with a guest stays until they leave. Returns "" or a text key.
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
	if is_free(kind):
		state.camp["coins"] = int(state.camp.get("coins", 0)) + cost(kind)
	else:
		state.camp["kit"][kind] = in_kit(kind) + 1
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
		if why == "":
			why = afford(kind)
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
