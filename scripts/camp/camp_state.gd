class_name CampState
extends RefCounted
## The rules for changing the shared camp. The host's copy decides; a guest's copy only mirrors what the host sent.
## Every rule takes a profile ID, never a connection ID. A rule returns "" when allowed, or a text key
## ("deny.*" in data/text.json) saying why not. Numbers: data/tuning.json "carry".

## The camp save (see CampSave), or on a guest the part of it the host shared.
var camp: Dictionary
## The parts of the camp a guest PC mirrors besides objects and profiles: the day, the coins and the guests.
const SHARED: Array[String] = ["calendar", "coins", "wood", "stays", "last_settled", "ledger", "reservations", "tasks",
		"trees", "forage", "journal"]
## Object id -> profile id of whoever carries it. Not saved: a carried thing stays at its last spot in the save.
var carriers := {}
## Profile ids of the players in the camp right now.
var online: Array[String] = []
## Stage A: the day, sleep and night (CampDay), and grid placement (CampBuild).
var day: CampDay
var build: CampBuild
## Stage B: requests, satisfaction and bookings (CampGuests), and fishing and grilling (CampPockets).
var guests: CampGuests
var pockets: CampPockets
## Stage B round 2: chopping and forage (CampGather), and the Today list (CampTasks).
var gather: CampGather
var tasks: CampTasks


func _init(data: Dictionary) -> void:
	camp = data
	if not camp.has("objects"):
		camp["objects"] = {}
	if not camp.has("profiles"):
		camp["profiles"] = {}
	for key: String in SHARED:
		if not camp.has(key):
			var v: Variant = Tuning.value("save", "new_camp." + key)
			camp[key] = v.duplicate(true) if v is Dictionary or v is Array else v
	day = CampDay.new(self)
	build = CampBuild.new(self)
	guests = CampGuests.new(self)
	pockets = CampPockets.new(self)
	gather = CampGather.new(self)
	tasks = CampTasks.new(self)


static func _num(key: String) -> float:
	return Tuning.num("tuning", "carry." + key)


## Brings a profile into the camp, making its character the first time. Returns the character.
func join(profile_id: String, display_name: String) -> Dictionary:
	var profiles: Dictionary = camp["profiles"]
	if not profiles.has(profile_id):
		var character := CampSave.new_profile(display_name, _least_used_look())
		character["pos"] = _spawn_point(profiles.size())
		profiles[profile_id] = character
	elif display_name != "":
		profiles[profile_id]["name"] = display_name
	profiles[profile_id]["last_seen"] = int(Time.get_unix_time_from_system())
	if not online.has(profile_id):
		online.append(profile_id)
	return profiles[profile_id]


## Takes a profile out of the camp. Anything it carried goes back to its last spot. Returns those object ids.
func leave(profile_id: String) -> Array[String]:
	var dropped: Array[String] = []
	for id: String in carriers.keys():
		if carriers[id] == profile_id:
			carriers.erase(id)
			dropped.append(id)
	online.erase(profile_id)
	if day:
		day.votes.erase(profile_id)
	return dropped


## Who drops in on the host's couch: the character that played here most recently and is not in the camp now
## (never the host's own), or "" when there is none and a new couch character is needed.
func couch_candidate(host_id: String) -> String:
	var best := ""
	var best_seen := -1
	for id: String in camp["profiles"]:
		var seen := int(camp["profiles"][id].get("last_seen", 0))
		if id != host_id and not online.has(id) and seen > best_seen:
			best = id
			best_seen = seen
	return best


## A fresh link code that no character in this camp has (data/net.json "link_code_*").
func new_link_code() -> String:
	var letters := str(Tuning.value("net", "link_code_letters", "ACDEFGHJKMNPQRTUVWXY34679"))
	var code := ""
	while code == "" or find_link(code) != "":
		code = ""
		for i in int(Tuning.num("net", "link_code_length", 6)):
			code += letters[randi() % letters.length()]
	return code


## The couch character a link code belongs to, or "". Spaces, dashes and lower case are ignored.
func find_link(code: String) -> String:
	var want := normalize_code(code)
	if want == "":
		return ""
	for id: String in camp["profiles"]:
		var p: Dictionary = camp["profiles"][id]
		if bool(p.get("couch", false)) and normalize_code(str(p.get("link_code", ""))) == want:
			return id
	return ""


## A link code as typed, reduced to its letters: upper case, without spaces or dashes.
static func normalize_code(code: String) -> String:
	var letters := str(Tuning.value("net", "link_code_letters", "ACDEFGHJKMNPQRTUVWXY34679"))
	var out := ""
	for ch in code.to_upper():
		if letters.contains(ch):
			out += ch
	return out


## A link code split in two halves for reading aloud, such as "KQ7-M3P".
static func show_code(code: String) -> String:
	var half := code.length() / 2
	return code.left(half) + "-" + code.substr(half)


func _least_used_look() -> String:
	var looks: Array = Tuning.value("save", "looks", ["camper_a"])
	var best := str(looks[0])
	var best_count := 1 << 30
	for look in looks:
		var count := 0
		for p: Dictionary in camp["profiles"].values():
			count += 1 if p["look"]["model"] == look else 0
		if count < best_count:
			best = str(look)
			best_count = count
	return best


func _spawn_point(index: int) -> Array:
	var spawns: Array = Tuning.value("save", "spawn", [[0, 0]])
	return (spawns[index % spawns.size()] as Array).duplicate()


func player_pos(profile_id: String) -> Vector2:
	var p: Array = camp["profiles"].get(profile_id, {}).get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func set_player_pos(profile_id: String, pos: Vector2, yaw_deg: float) -> void:
	if camp["profiles"].has(profile_id):
		camp["profiles"][profile_id]["pos"] = [pos.x, pos.y]
		camp["profiles"][profile_id]["yaw"] = yaw_deg


func object_pos(id: String) -> Vector2:
	var p: Array = camp["objects"][id]["pos"]
	return Vector2(float(p[0]), float(p[1]))


## The object a profile is carrying, or "".
func carried_by(profile_id: String) -> String:
	for id: String in carriers:
		if carriers[id] == profile_id:
			return id
	return ""


static func can_carry(model_id: String) -> bool:
	return bool(FeltBuilder.resolve(model_id).get("carry", false))


func pick_up(profile_id: String, id: String) -> String:
	if not (online.has(profile_id) and camp["objects"].has(id)):
		return "deny.not_movable"
	if not can_carry(str(camp["objects"][id]["model"])):
		return "deny.not_movable"
	if carriers.has(id):
		return "deny.carried"
	if carried_by(profile_id) != "":
		return "deny.hands_full"
	if player_pos(profile_id).distance_to(object_pos(id)) > _num("reach_m") + _num("reach_slack_m"):
		return "deny.too_far"
	carriers[id] = profile_id
	return ""


func place(profile_id: String, pos: Vector2, yaw_deg: float) -> String:
	var id := carried_by(profile_id)
	if id == "":
		return "deny.nothing_carried"
	if pos.length() > _num("camp_radius_m"):
		return "deny.out_of_bounds"
	if player_pos(profile_id).distance_to(pos) > _num("reach_m") + _num("reach_slack_m"):
		return "deny.too_far"
	var gap := _num("min_gap_m")
	for other: String in camp["objects"]:
		if other != id and not carriers.has(other) and object_pos(other).distance_to(pos) < gap:
			return "deny.too_close"
	for other: String in online:
		if other != profile_id and player_pos(other).distance_to(pos) < gap:
			return "deny.too_close"
	camp["objects"][id]["pos"] = [pos.x, pos.y]
	camp["objects"][id]["yaw"] = yaw_deg
	carriers.erase(id)
	return ""


## What a joining guest needs: the objects, who carries what, the characters in the camp now, and the shared day.
func snapshot() -> Dictionary:
	var profiles := {}
	for id in online:
		profiles[id] = camp["profiles"][id]
	var snap := shared()
	snap.merge({"objects": camp["objects"], "carriers": carriers, "profiles": profiles})
	return snap


## The shared day as a guest PC mirrors it: SHARED plus who is ready for bed and what the players in the camp carry
## in their pockets.
func shared() -> Dictionary:
	var held := {}
	for id in online:
		held[id] = camp["profiles"][id].get("pockets", [])
	var out := {"votes": day.votes.duplicate(), "pockets": held}
	for key in SHARED:
		out[key] = camp[key]
	return out


## A guest PC takes in the host's shared day.
func apply_shared(data: Dictionary) -> void:
	for key in SHARED:
		if data.has(key):
			camp[key] = data[key]
	if data.has("votes"):
		day.votes.assign(data["votes"])
	for id: String in data.get("pockets", {}):
		if camp["profiles"].has(id):
			camp["profiles"][id]["pockets"] = data["pockets"][id]


## A guest's mirror of the camp, built from the host's snapshot.
static func from_snapshot(snap: Dictionary) -> CampState:
	var state := CampState.new({"objects": snap.get("objects", {}), "profiles": snap.get("profiles", {})})
	state.apply_shared(snap)
	state.carriers = snap.get("carriers", {})
	for id: String in state.camp["profiles"]:
		state.online.append(id)
	return state
