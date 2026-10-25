class_name CampRating
extends RefCounted
## The camp's star rating, like Animal Crossing's island stars but cozier: it is worked out each night from what the
## camp has (pitches, crafted pieces, happy guests, photos, finished projects), never goes down, and comes with one
## hint from the ranger about what would help next. The host's copy decides. Numbers: data/rating.json. Saved in
## the camp's "rating" {stars}.

var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func factors() -> Array:
	return Tuning.value("rating", "factors", [])


## How many of a factor the camp has now.
func count(id: String) -> int:
	var objects: Dictionary = state.camp["objects"]
	match id:
		"pitches":
			return objects.values().filter(func(o: Dictionary) -> bool:
					return str(o.get("model", "")) == str(Tuning.value("build", "kinds.pitch.model", "pitch"))).size()
		"pieces":
			var models: Array = _factor(id).get("models", [])
			return objects.values().filter(func(o: Dictionary) -> bool: return models.has(o.get("model", ""))).size()
		"happy":
			var n := 0
			var ledger: Array = state.camp.get("ledger", [])
			for night: Dictionary in ledger.slice(maxi(ledger.size() - int(_factor(id).get("nights", 3)), 0)):
				for r: Dictionary in night.get("reviews", []):
					n += int(r.get("points", 0))
			return n
		"photos":
			return (state.camp["journal"].get("photos", {}) as Dictionary).size()
		"projects":
			return (state.camp["projects"]["done"] as Array).size()
	return 0


static func _factor(id: String) -> Dictionary:
	for f: Dictionary in factors():
		if f["id"] == id:
			return f
	return {}


func points() -> int:
	var total := 0
	for f: Dictionary in factors():
		total += mini(count(str(f["id"])) * int(f["per"]), int(f["cap"]))
	return total


static func stars_for(p: int) -> int:
	var stars := 1
	for row: Array in Tuning.value("rating", "stars", [[0, 1]]):
		if p >= int(row[0]):
			stars = int(row[1])
	return stars


static func max_stars() -> int:
	var rows: Array = Tuning.value("rating", "stars", [[0, 1]])
	return int(rows[-1][1])


## The stars the camp has (at least one; they never go down).
func stars() -> int:
	return maxi(int(state.camp["rating"].get("stars", 0)), 1)


## The first factor still under its cap, for the ranger's hint, or "" when the camp has everything.
func hint() -> String:
	for f: Dictionary in factors():
		if count(str(f["id"])) * int(f["per"]) < int(f["cap"]):
			return str(f["id"])
	return ""


## The night's rating: works the stars out again (never fewer than before) and saves them. Returns {stars, was, hint}.
func settle() -> Dictionary:
	var was := int(state.camp["rating"].get("stars", 0))
	var now := maxi(maxi(was, stars_for(points())), 1)
	state.camp["rating"]["stars"] = now
	return {"stars": now, "was": was, "hint": hint()}
