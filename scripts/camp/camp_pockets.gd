class_name CampPockets
extends RefCounted
## Stage B's fishing and grilling: what each player carries in their pockets. A cast at the water's edge always
## catches something; grilling at the fire turns a raw fish into a meal. Nothing is ever lost: a full pocket just
## can't take more. The host's copy decides; every rule takes a profile ID and returns "" or a text key.
## Numbers: data/fishing.json.

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## The item the last allowed step caught or grilled.
var last_item := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("fishing", key, fallback)


## What kind an item is ("fish" or "meal"), or "".
static func kind_of(item: String) -> String:
	return str(Tuning.value("fishing", "items.%s.kind" % item, ""))


func pockets(profile_id: String) -> Array:
	var p: Dictionary = state.camp["profiles"].get(profile_id, {})
	if not p.has("pockets"):
		p["pockets"] = []
	return p.get("pockets", [])


## The first item of a kind in a player's pockets, or "".
func first_of(profile_id: String, kind: String) -> String:
	for item in pockets(profile_id):
		if kind_of(str(item)) == kind:
			return str(item)
	return ""


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


func _room(profile_id: String) -> bool:
	return pockets(profile_id).size() < int(_n("pockets_max", 6))


## A cast: a fish by weight goes into the player's pockets.
func fish(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not can_fish_at(state.player_pos(profile_id)):
		return "deny.no_water"
	if not _room(profile_id):
		return "deny.pockets_full"
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
	pockets(profile_id).append(last_item)
	return ""


## Grills the first raw fish in the player's pockets into its recipe, burning wood from the camp's pile
## (data/gather.json cook_wood).
func cook(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not can_cook_at(state.player_pos(profile_id)):
		return "deny.no_fire"
	var raw := first_of(profile_id, "fish")
	if raw == "":
		return "deny.no_fish"
	var fuel := int(Tuning.num("gather", "cook_wood", 1))
	if int(state.camp.get("wood", 0)) < fuel:
		return "deny.no_wood"
	state.camp["wood"] = int(state.camp.get("wood", 0)) - fuel
	var list := pockets(profile_id)
	last_item = str(Tuning.value("fishing", "recipes." + raw, raw))
	list[list.find(raw)] = last_item
	return ""


## Takes one item of a kind out of a player's pockets. Returns the item, or "" when there was none.
func take(profile_id: String, kind: String) -> String:
	var item := first_of(profile_id, kind)
	if item != "":
		pockets(profile_id).erase(item)
	return item
