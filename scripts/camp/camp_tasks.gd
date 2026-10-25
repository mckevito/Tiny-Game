class_name CampTasks
extends RefCounted
## The Today list: a few counted tasks at once, shared by both players. The firsts teach the game on day 1 (pick up
## sticks, chop, build a bench, fish, grill, make a pitch); after them the daily tasks cycle forever. Either player's
## step counts; a finished task pays its bonus at once and the next one takes its place. Nothing expires.
## Numbers: data/tasks.json; saved in the camp's "tasks".

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


func data() -> Dictionary:
	return state.camp["tasks"]


static func plan(id: String) -> Dictionary:
	for list in ["firsts", "daily"]:
		for row: Dictionary in Tuning.value("tasks", list, []):
			if str(row.get("id", "")) == id:
				return row
	return {}


## The tasks on the list now: [{id, have}].
func active() -> Array:
	fill()
	return data()["active"]


func _is_active(id: String) -> bool:
	for row: Dictionary in data()["active"]:
		if row["id"] == id:
			return true
	return false


## Tops the list up: the firsts not done yet, in order, then the daily tasks in turn.
func fill() -> void:
	var list: Array = data()["active"]
	var want := int(Tuning.num("tasks", "active_max", 4))
	for row: Dictionary in Tuning.value("tasks", "firsts", []):
		if list.size() >= want:
			return
		if not (data()["done"] as Array).has(row["id"]) and not _is_active(str(row["id"])):
			list.append({"id": row["id"], "have": 0})
	var daily: Array = Tuning.value("tasks", "daily", [])
	var tries := 0
	while list.size() < want and tries < daily.size():
		var row: Dictionary = daily[int(data()["next_daily"]) % daily.size()]
		data()["next_daily"] = int(data()["next_daily"]) + 1
		tries += 1
		if not _is_active(str(row["id"])):
			list.append({"id": row["id"], "have": 0})


## A step someone took ("chop", "forage:stick", "build:pitch"...). Returns the tasks it finished, each paid.
func note(event: String, amount: int = 1) -> Array[String]:
	var done: Array[String] = []
	for row: Dictionary in active().duplicate():
		var p := plan(str(row["id"]))
		var want := str(p.get("event", ""))
		if event != want and not event.begins_with(want + ":"):
			continue
		row["have"] = int(row["have"]) + amount
		if int(row["have"]) >= int(p.get("count", 1)):
			(data()["active"] as Array).erase(row)
			if (Tuning.value("tasks", "firsts", []) as Array).any(func(f: Dictionary) -> bool: return f["id"] == row["id"]):
				(data()["done"] as Array).append(row["id"])
			state.camp["coins"] = int(state.camp.get("coins", 0)) + int(p.get("bonus", 0))
			done.append(str(row["id"]))
	if not done.is_empty():
		fill()
	return done


## One task as a line: its words, the count so far, and where it happens (`short` for the HUD: no place).
static func line(row: Dictionary, short: bool = false) -> String:
	var p := plan(str(row["id"]))
	if short:
		return Tuning.text("task.hud_line") % [Tuning.text("task." + str(row["id"])), int(row["have"]),
				int(p.get("count", 1))]
	return Tuning.text("task.line") % [Tuning.text("task." + str(row["id"])), int(row["have"]), int(p.get("count", 1)),
			Tuning.text("task.place." + str(p.get("place", "")))]
