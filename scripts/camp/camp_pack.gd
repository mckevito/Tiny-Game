class_name CampPack
extends RefCounted
## Each player's Pack: a few slots, each a stack of one item (fish, meals, berries, saplings, wood, sticks). Also
## the camp box (shared materials, no limit), dropped bundles, fishing at the pond and grilling at the fire. Nothing
## is ever lost: a full Pack just can't take more, and a dropped stack lies where it fell until someone picks it up.
## The host's copy decides; every rule takes a profile ID and returns "" or a text key. Numbers: data/items.json,
## data/fishing.json. Saved in each profile's "pack" ([{item, n}]) and the camp's "box" and "bundles".

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## The item the last allowed step caught, grilled, dropped or picked up.
var last_item := ""
## The bundle the last allowed drop or pick-up touched.
var last_bundle := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("fishing", key, fallback)


## What kind an item is ("fish", "meal", "fruit", "plant" or "material"), or "".
static func kind_of(item: String) -> String:
	return str(Tuning.value("items", "items.%s.kind" % item, ""))


static func boxable(item: String) -> bool:
	return bool(Tuning.value("items", "items.%s.box" % item, false))


## A player's slots: [{item, n}], at most data/items.json pack_slots.
func slots(profile_id: String) -> Array:
	var p: Dictionary = state.camp["profiles"].get(profile_id, {})
	if not p.has("pack"):
		p["pack"] = []
	return p.get("pack", [])


## How many of an item a player carries.
func count(profile_id: String, item: String) -> int:
	var total := 0
	for s: Dictionary in slots(profile_id):
		if s["item"] == item:
			total += int(s["n"])
	return total


## How many more of an item fit in a player's Pack.
func room_for(profile_id: String, item: String) -> int:
	var cap := int(Tuning.num("items", "stack_max", 99))
	var room := (int(Tuning.num("items", "pack_slots", 8)) - slots(profile_id).size()) * cap
	for s: Dictionary in slots(profile_id):
		if s["item"] == item:
			room += cap - int(s["n"])
	return room


## Puts up to `n` of an item in a player's Pack, topping up stacks first. Returns how many went in.
func add(profile_id: String, item: String, n: int = 1) -> int:
	var cap := int(Tuning.num("items", "stack_max", 99))
	var left := mini(n, room_for(profile_id, item))
	var put := left
	for s: Dictionary in slots(profile_id):
		if left > 0 and s["item"] == item:
			var more := mini(cap - int(s["n"]), left)
			s["n"] = int(s["n"]) + more
			left -= more
	while left > 0:
		var more := mini(cap, left)
		slots(profile_id).append({"item": item, "n": more})
		left -= more
	return put


## Takes `n` of an item from a player's Pack, emptying the last stacks first. False (and nothing taken) when short.
func remove(profile_id: String, item: String, n: int = 1) -> bool:
	if count(profile_id, item) < n:
		return false
	var list := slots(profile_id)
	for i in range(list.size() - 1, -1, -1):
		if n <= 0:
			break
		var s: Dictionary = list[i]
		if s["item"] == item:
			var less := mini(int(s["n"]), n)
			s["n"] = int(s["n"]) - less
			n -= less
			if int(s["n"]) <= 0:
				list.remove_at(i)
	return true


## The first item of a kind in a player's Pack, or "".
func first_of(profile_id: String, kind: String) -> String:
	for s: Dictionary in slots(profile_id):
		if kind_of(str(s["item"])) == kind:
			return str(s["item"])
	return ""


## Takes one item of a kind out of a player's Pack. Returns the item, or "" when there was none.
func take(profile_id: String, kind: String) -> String:
	var item := first_of(profile_id, kind)
	if item != "":
		remove(profile_id, item)
	return item


# --- The camp box --------------------------------------------------------------------------------------------------

func box_count(item: String) -> int:
	return int(state.camp["box"].get(item, 0))


## How many of an item a player can use: their Pack plus the camp box.
func have(profile_id: String, item: String) -> int:
	return count(profile_id, item) + box_count(item)


## Spends `n` of an item from a player's Pack first, then the camp box. False (and nothing spent) when short.
func spend(profile_id: String, item: String, n: int) -> bool:
	if have(profile_id, item) < n:
		return false
	var from_pack := mini(count(profile_id, item), n)
	remove(profile_id, item, from_pack)
	if n > from_pack:
		state.camp["box"][item] = box_count(item) - (n - from_pack)
		if box_count(item) <= 0:
			state.camp["box"].erase(item)
	return true


func add_to_box(item: String, n: int) -> void:
	state.camp["box"][item] = box_count(item) + n


static func box_pos() -> Vector2:
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		if str(row.get("model", "")) == str(Tuning.value("items", "box_model", "camp_box")):
			var o := Clearing.placement_transform(row).origin
			return Vector2(o.x, o.z)
	return Vector2(INF, INF)


static func near_box(pos: Vector2) -> bool:
	return pos.distance_to(box_pos()) <= Tuning.num("items", "reach_m", 1.4)


## True when a player carries something the camp box takes.
func has_boxable(profile_id: String) -> bool:
	return slots(profile_id).any(func(s: Dictionary) -> bool: return boxable(str(s["item"])))


## Puts every material a player carries into the camp box. Returns how many things went in.
func deposit(profile_id: String) -> int:
	if not state.online.has(profile_id) or not near_box(state.player_pos(profile_id)):
		return 0
	var moved := 0
	var list := slots(profile_id)
	for i in range(list.size() - 1, -1, -1):
		var s: Dictionary = list[i]
		if boxable(str(s["item"])):
			add_to_box(str(s["item"]), int(s["n"]))
			moved += int(s["n"])
			list.remove_at(i)
	return moved


# --- Dropped bundles -----------------------------------------------------------------------------------------------

static func bundle_pos(row: Dictionary) -> Vector2:
	return Vector2(float(row["pos"][0]), float(row["pos"][1]))


## The nearest bundle within reach of a spot, or "": dropped ones, or with `loose` pieces popped out of a tree.
func bundle_near(pos: Vector2, loose: bool = false) -> String:
	var best := ""
	var best_d := Tuning.num("items", "reach_m", 1.4)
	for id: String in state.camp["bundles"]:
		if bool(state.camp["bundles"][id].get("loose", false)) != loose:
			continue
		var d := pos.distance_to(bundle_pos(state.camp["bundles"][id]))
		if d <= best_d:
			best = id
			best_d = d
	return best


## Drops a player's whole stack in slot `index` at their feet as a bundle (joining a bundle of the same item close by).
func drop(profile_id: String, index: int) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	var list := slots(profile_id)
	if index < 0 or index >= list.size():
		return "deny.nothing_to_drop"
	var s: Dictionary = list[index]
	list.remove_at(index)
	last_item = str(s["item"])
	var at := state.player_pos(profile_id)
	last_bundle = ""
	for id: String in state.camp["bundles"]:
		var row: Dictionary = state.camp["bundles"][id]
		if row["item"] == last_item and not row.get("loose", false) \
				and bundle_pos(row).distance_to(at) <= Tuning.num("items", "bundle.merge_m", 1.0):
			row["n"] = int(row["n"]) + int(s["n"])
			last_bundle = id
			return ""
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	last_bundle = "bundle_%d" % n
	state.camp["bundles"][last_bundle] = {"item": last_item, "n": int(s["n"]), "pos": [at.x, at.y]}
	return ""


## Picks up as much of a bundle as fits; the rest stays where it lies.
func pick_bundle(profile_id: String, id: String) -> String:
	if not state.online.has(profile_id) or not state.camp["bundles"].has(id):
		return "deny.nothing_here"
	var row: Dictionary = state.camp["bundles"][id]
	if bundle_pos(row).distance_to(state.player_pos(profile_id)) \
			> Tuning.num("items", "reach_m", 1.4) + Tuning.num("tuning", "carry.reach_slack_m"):
		return "deny.too_far"
	var got := add(profile_id, str(row["item"]), int(row["n"]))
	if got <= 0:
		return "deny.pack_full"
	last_item = str(row["item"])
	last_bundle = id
	row["n"] = int(row["n"]) - got
	if int(row["n"]) <= 0:
		state.camp["bundles"].erase(id)
	return ""


## Lays a loose piece that popped out of a tree or a stump on the grass at `at`, flying from `from` (data/gather.json
## drops). It lies there until a player walks over it (sweep). Returns its bundle id.
func lay(item: String, n: int, at: Vector2, from: Vector2) -> String:
	var next := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = next + 1
	last_bundle = "bundle_%d" % next
	state.camp["bundles"][last_bundle] = {"item": item, "n": n, "pos": [at.x, at.y], "loose": true,
			"from": [from.x, from.y]}
	return last_bundle


## A player walking over a loose piece sweeps it into their Pack (data/gather.json drops.sweep_m); `wait` lists the
## pieces still in the air. Returns the bundle id swept, or "" (a full Pack leaves it on the grass).
func sweep(profile_id: String, wait: Array = []) -> String:
	if not state.online.has(profile_id):
		return ""
	var at := state.player_pos(profile_id)
	for id: String in state.camp["bundles"]:
		var row: Dictionary = state.camp["bundles"][id]
		if not row.get("loose", false) or wait.has(id) \
				or bundle_pos(row).distance_to(at) > Tuning.num("gather", "drops.sweep_m", 0.75):
			continue
		if room_for(profile_id, str(row["item"])) < int(row["n"]):
			continue
		add(profile_id, str(row["item"]), int(row["n"]))
		last_item = str(row["item"])
		last_bundle = id
		state.camp["bundles"].erase(id)
		return id
	return ""


# --- Fishing and grilling ------------------------------------------------------------------------------------------

## True when a spot is within reach of a scenery model listed in `table` (model -> radius in metres).
static func _near_scenery(pos: Vector2, table: String) -> bool:
	var spots: Dictionary = Tuning.value("fishing", table, {})
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		var model := str(row.get("model", ""))
		if spots.has(model):
			var at := Clearing.placement_transform(row).origin
			if Vector2(at.x, at.z).distance_to(pos) <= float(spots[model]):
				return true
	return false


static func can_fish_at(pos: Vector2) -> bool:
	return _near_scenery(pos, "waters")


static func can_cook_at(pos: Vector2) -> bool:
	return _near_scenery(pos, "fires")


## A cast: a fish by weight goes into the player's Pack.
func fish(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not can_fish_at(state.player_pos(profile_id)):
		return "deny.no_water"
	var catches: Array = Tuning.value("fishing", "fish", [])
	var total := 0.0
	for row: Dictionary in catches:
		total += float(row.get("weight", 1))
	var roll := randf() * total
	last_item = str(catches.back()["item"]) if not catches.is_empty() else ""
	for row: Dictionary in catches:
		roll -= float(row.get("weight", 1))
		if roll <= 0.0:
			last_item = str(row["item"])
			break
	if last_item == "":
		return "deny.no_water"
	if room_for(profile_id, last_item) <= 0:
		return "deny.pack_full"
	add(profile_id, last_item)
	return ""


## Grills the first raw fish in the player's Pack into its recipe, burning one fuel (data/items.json fuel) from the
## Pack or the camp box.
func cook(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not can_cook_at(state.player_pos(profile_id)):
		return "deny.no_fire"
	if not state.story.lit():
		return "deny.fire_cold"
	var raw := first_of(profile_id, "fish")
	if raw == "":
		return "deny.no_fish"
	var fuel := ""
	for item: String in Tuning.value("items", "fuel", []):
		if have(profile_id, item) > 0:
			fuel = item
			break
	if fuel == "":
		return "deny.no_wood"
	last_item = str(Tuning.value("fishing", "recipes." + raw, raw))
	remove(profile_id, raw)
	if add(profile_id, last_item) <= 0:
		add(profile_id, raw)
		return "deny.pack_full"
	spend(profile_id, fuel, 1)
	return ""
