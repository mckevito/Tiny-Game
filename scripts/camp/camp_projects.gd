class_name CampProjects
extends RefCounted
## Where gathering goes: the sell crate and the camp projects. A player at the crate puts in one stack from their
## Pack at a time, keeping back what the open project still needs; the crate pays at night, in the morning report, at flat prices, and anything in it can be taken
## back until then. A camp project is a bundle of things both players bring to the project board, from their Packs
## and the camp box; finished, it gives its reward once (a new workbench recipe, or coins). One project is open at a
## time, in order, and the list is finite. The host's copy decides; every rule takes a profile ID and returns "" or a
## text key. Numbers: data/projects.json. Saved in the camp's "crate", "shipped" and "projects".

var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## The item the last allowed ship or take-back moved, and how many.
var last_item := ""
var last_n := 0
## The project the last allowed gift finished, or "".
var finished := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _spot(model: String) -> Vector2:
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		if str(row.get("model", "")) == model:
			var o := Clearing.placement_transform(row).origin
			return Vector2(o.x, o.z)
	return Vector2(INF, INF)


static func near_crate(pos: Vector2) -> bool:
	return pos.distance_to(_spot(str(Tuning.value("projects", "crate.model", "sell_crate")))) <= \
			Tuning.num("projects", "reach_m", 1.4)


## True when a spot is within reach of the camp board, wherever the players put it up (none until they do).
static func near_board(camp_state: CampState, pos: Vector2) -> bool:
	var model := str(Tuning.value("projects", "board_model", "project_board"))
	for id: String in camp_state.camp["objects"]:
		if str(camp_state.camp["objects"][id].get("model", "")) == model and not camp_state.carriers.has(id) \
				and pos.distance_to(camp_state.object_pos(id)) <= Tuning.num("projects", "reach_m", 1.4):
			return true
	return false


## What the crate pays for one of an item (0: the crate does not take it).
static func price(item: String) -> int:
	return int(Tuning.num("projects", "crate.prices." + item, 0))


# --- The sell crate ------------------------------------------------------------------------------------------------

func crate() -> Array:
	return state.camp["crate"]


## How many of an item the open camp project still needs, counting every need the item fills (0 when none).
func still_needed(item: String) -> int:
	var r := current()
	var n := 0
	for need: String in r.get("needs", {}):
		if fills(need).has(item):
			n += maxi(int(r["needs"][need]) - int(given().get(need, 0)), 0)
	return n


## How many of an item a player could sell: what they carry beyond what the open project still needs, so the crate
## never takes a project's sticks or berries (Playtest pass 2). Items without a price: 0.
func spare(profile_id: String, item: String) -> int:
	if price(item) <= 0:
		return 0
	return maxi(state.pack.count(profile_id, item) - still_needed(item), 0)


## The first item in a player's Pack the crate takes, with some to spare, or "".
func sellable(profile_id: String) -> String:
	for s: Dictionary in state.pack.slots(profile_id):
		if spare(profile_id, str(s["item"])) > 0:
			return str(s["item"])
	return ""


## Puts a player's first sellable item into the crate, all but what the open project still needs.
func ship(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not near_crate(state.player_pos(profile_id)):
		return "deny.too_far"
	var item := sellable(profile_id)
	if item == "":
		for s: Dictionary in state.pack.slots(profile_id):
			if price(str(s["item"])) > 0:
				return "deny.project_needs_it"
		return "deny.nothing_to_sell"
	var n := spare(profile_id, item)
	state.pack.remove(profile_id, item, n)
	crate().append({"item": item, "n": n})
	last_item = item
	last_n = n
	return ""


## Takes the last stack put in the crate back into a player's Pack (as much as fits; the rest stays in the crate).
func take_back(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not near_crate(state.player_pos(profile_id)):
		return "deny.too_far"
	if crate().is_empty():
		return "deny.crate_empty"
	var top: Dictionary = crate()[-1]
	var n := state.pack.add(profile_id, str(top["item"]), int(top["n"]))
	if n <= 0:
		return "deny.pack_full"
	top["n"] = int(top["n"]) - n
	if int(top["n"]) <= 0:
		crate().pop_back()
	last_item = str(top["item"])
	last_n = n
	return ""


## The night's sale: what everything in the crate is worth, added to the shipped list; the crate empties. The night
## (CampDay.settle_night) pays the coins. Returns {coins, items: item -> n}.
func settle_crate() -> Dictionary:
	var items := {}
	var coins := 0
	for s: Dictionary in crate():
		items[s["item"]] = int(items.get(s["item"], 0)) + int(s["n"])
		coins += price(str(s["item"])) * int(s["n"])
	var shipped: Dictionary = state.camp["shipped"]
	for item: String in items:
		shipped[item] = int(shipped.get(item, 0)) + int(items[item])
	crate().clear()
	return {"coins": coins, "items": items}


# --- Camp projects -------------------------------------------------------------------------------------------------

static func rows() -> Array:
	return Tuning.value("projects", "projects", [])


static func row(id: String) -> Dictionary:
	for r: Dictionary in rows():
		if r["id"] == id:
			return r
	return {}


func done() -> Array:
	return state.camp["projects"]["done"]


## The open project (the first not done), or {} when every project is finished.
func current() -> Dictionary:
	for r: Dictionary in rows():
		if not done().has(r["id"]):
			return r
	return {}


## How many of each need the open project has been given: need -> n.
func given() -> Dictionary:
	return state.camp["projects"]["given"]


## True when a recipe is open at the workbench: it names no project, or its project is done.
func knows(recipe: Dictionary) -> bool:
	return str(recipe.get("project", "")) == "" or done().has(str(recipe["project"]))


## The items that can fill a need: the item itself, or every item of that kind (data/items.json) for a kind.
static func fills(need: String) -> Array:
	if Tuning.value("items", "items." + need) != null:
		return [need]
	var out: Array = []
	var items: Dictionary = Tuning.value("items", "items", {})
	for item: String in items:
		if str(items[item].get("kind", "")) == need:
			out.append(item)
	return out


## How many of a need a player could bring now (Pack first, then the camp box), up to what is still missing.
func could_give(profile_id: String, need: String) -> int:
	var r := current()
	if r.is_empty():
		return 0
	var missing := int(r["needs"].get(need, 0)) - int(given().get(need, 0))
	var have := 0
	for item: String in fills(need):
		have += state.pack.have(profile_id, item)
	return clampi(have, 0, maxi(missing, 0))


func can_give(profile_id: String) -> bool:
	var r := current()
	return not r.is_empty() and (r["needs"] as Dictionary).keys().any(
			func(need: String) -> bool: return could_give(profile_id, need) > 0)


## A player brings what the open project still needs; a finished project gives its reward.
func give(profile_id: String) -> String:
	finished = ""
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not near_board(state, state.player_pos(profile_id)):
		return "deny.too_far"
	var r := current()
	if r.is_empty():
		return "deny.projects_done"
	if not can_give(profile_id):
		return "deny.nothing_for_project"
	for need: String in r["needs"]:
		var left := could_give(profile_id, need)
		given()[need] = int(given().get(need, 0)) + left
		for item: String in fills(need):
			var n := mini(left, state.pack.have(profile_id, item))
			if n > 0:
				state.pack.spend(profile_id, item, n)
				left -= n
	if (r["needs"] as Dictionary).keys().all(func(need: String) -> bool:
			return int(given().get(need, 0)) >= int(r["needs"][need])):
		done().append(r["id"])
		given().clear()
		state.camp["coins"] = int(state.camp.get("coins", 0)) + int(r.get("coins", 0))
		finished = str(r["id"])
	return ""
