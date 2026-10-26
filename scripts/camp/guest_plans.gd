class_name GuestPlans
extends RefCounted
## What each guest is doing right now: fishing at the pond, photographing the animals, flying a kite, sitting on a
## seat the players built or brought, throwing a frisbee with another guest, or resting by their tent. A guest with an
## open request, or asleep, stays by their tent so players can find them. It is worked out from the shared day alone
## (the calendar, the stays, the camp's objects, the fire's level and who carries what), so both PCs agree with no
## extra netcode, and it never changes the camp. Numbers: data/guests.json "activities".


static func _v(key: String, fallback: Variant = null) -> Variant:
	return Tuning.value("guests", "activities." + key, fallback)


static func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## A steady number in [0, 1) for a key, the same on every PC.
static func roll(key: String) -> float:
	var x := key.hash() & 0xFFFFFFFF
	for i in 2:
		x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	return float((x ^ (x >> 16)) & 0xFFFF) / 65536.0


## Stay id -> what that guest is doing: {"kind", "at" (Vector2, where they stand), "look" (Vector2, what they face),
## "prop" (a tools.held row in data/items.json, or "hands"), "sit_y" (seat height in metres, 0 when standing),
## "pair" (the other frisbee player's stay id, or ""), "from" (Vector2, the open ground a seat is sat down on from;
## "at" for anything else)}.
static func plan(state: CampState, asleep: bool) -> Dictionary:
	var out := {}
	var ids: Array = state.camp["stays"].keys()
	ids.sort()
	var free: Array[String] = []
	for id: String in ids:
		if asleep or state.guests.open_request(id) != "":
			out[id] = home(state, id)
		else:
			free.append(id)
	if free.is_empty():
		return out
	var slot := int(state.day.minute() / maxf(float(_v("slot_min", 60.0)), 1.0))
	var stamp := "%d|%d" % [state.day.today(), slot]
	var used := {}
	if free.size() >= 2 and roll("frisbee|" + stamp) < float(_v("frisbee.chance", 0.0)):
		var first := int(roll("pair|" + stamp) * free.size())
		var a: String = free[first]
		var b: String = free[(first + 1) % free.size()]
		var ends := _frisbee_lawn(state)
		if not ends.is_empty():
			out[a] = _spot("frisbee", ends[0], ends[1], "hands", 0.0, b)
			out[b] = _spot("frisbee", ends[1], ends[0], "hands", 0.0, a)
			free.erase(a)
			free.erase(b)
	var kinds: Array = _v("kinds", ["rest"])
	for id in free:
		var start := int(roll("%s|%s" % [id, stamp]) * kinds.size())
		out[id] = home(state, id)
		for k in kinds.size():
			var got := _pick(state, str(kinds[(start + k) % kinds.size()]), used)
			if not got.is_empty():
				out[id] = got
				break
	return out


## Resting by the tent: where the guest stands at their pitch, facing it.
static func home(state: CampState, stay_id: String) -> Dictionary:
	var pitch: Dictionary = state.camp["objects"].get(state.camp["stays"][stay_id].get("pitch", ""), {"pos": [0, 0]})
	return _spot("rest", state.day.stand_point(stay_id), _vec(pitch["pos"]), "hands", 0.0, "")


static func _spot(kind: String, at: Vector2, look: Vector2, prop: String, sit_y: float, pair: String,
		from: Variant = null) -> Dictionary:
	return {"kind": kind, "at": at, "look": look, "prop": prop, "sit_y": sit_y, "pair": pair,
			"from": at if from == null else from}


## The first free spot for a kind, marked used; {} when there is none ("rest" is the guest's own pitch).
static func _pick(state: CampState, kind: String, used: Dictionary) -> Dictionary:
	if kind == "sit":
		for seat: Dictionary in seats(state):
			var key := "sit|%s" % seat["at"]
			if not used.has(key):
				used[key] = true
				return seat
		return {}
	for i in (_v(kind + ".spots", []) as Array).size():
		var row: Dictionary = _v(kind + ".spots")[i]
		var key := "%s|%d" % [kind, i]
		if used.has(key) or not _clear(state, _vec(row["at"])):
			continue
		used[key] = true
		return _spot(kind, _vec(row["at"]), _vec(row["look"]), str(_v(kind + ".prop", "hands")), 0.0, "")
	return {}


## Every seat a guest can take, in a steady order: those on the camp's seats nobody is carrying (activities.sit.seats:
## model -> spots in the seat's own space, facing its front, sat down on from the open ground at "from"), then the fire
## ring's log seats once the fire has grown.
static func seats(state: CampState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_model: Dictionary = _v("sit.seats", {})
	var ids: Array = state.camp["objects"].keys()
	ids.sort()
	for id: String in ids:
		var row: Dictionary = state.camp["objects"][id]
		if not by_model.has(str(row["model"])) or state.carriers.has(id):
			continue
		var yaw := deg_to_rad(float(row.get("yaw", 0.0)))
		var pos := _vec(row["pos"])
		for s: Dictionary in by_model[str(row["model"])]:
			var at := pos + _vec(s["at"]).rotated(-yaw)
			var from := pos + _vec(s.get("from", s["at"])).rotated(-yaw)
			out.append(_spot("sit", at, at + Vector2(0, -1).rotated(-yaw), "hands", float(s["y"]), "", from))
	if state.build.fire_level() >= 1:
		for s: Dictionary in _v("sit.fire_ring", []):
			out.append(_spot("sit", _vec(s["at"]), _vec(_v("sit.fire_at", [0, 0])), "hands", float(s["y"]), "",
					_vec(s.get("from", s["at"]))))
	return out


## The two ends of the first frisbee lawn with nothing built on either end, or [].
static func _frisbee_lawn(state: CampState) -> Array:
	for row: Dictionary in _v("frisbee.spots", []):
		var along := Vector2(0, -1).rotated(-deg_to_rad(float(row.get("yaw", 0.0)))) * float(_v("frisbee.half_m", 2.5))
		var a := _vec(row["at"]) - along
		var b := _vec(row["at"]) + along
		if _clear(state, a) and _clear(state, b):
			return [a, b]
	return []


## True when no camp object stands within activities.clear_m of a spot.
static func _clear(state: CampState, at: Vector2) -> bool:
	var gap := float(_v("clear_m", 1.0))
	for row: Dictionary in state.camp["objects"].values():
		if _vec(row["pos"]).distance_to(at) < gap:
			return false
	return true
