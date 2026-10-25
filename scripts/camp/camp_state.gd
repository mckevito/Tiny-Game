class_name CampState
extends RefCounted
## The rules for changing the shared camp. The host's copy decides; a guest's copy only mirrors what the host sent.
## Every rule takes a profile ID, never a connection ID. A rule returns "" when allowed, or a text key
## ("deny.*" in data/text.json) saying why not. Numbers: data/tuning.json "carry".

## The camp save (see CampSave), or on a guest the part of it the host shared.
var camp: Dictionary
## Object id -> profile id of whoever carries it. Not saved: a carried thing stays at its last spot in the save.
var carriers := {}
## Profile ids of the players in the camp right now.
var online: Array[String] = []


func _init(data: Dictionary) -> void:
	camp = data
	if not camp.has("objects"):
		camp["objects"] = {}
	if not camp.has("profiles"):
		camp["profiles"] = {}


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
	return dropped


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


## What a joining guest needs: the objects, who carries what, and the characters in the camp now.
func snapshot() -> Dictionary:
	var profiles := {}
	for id in online:
		profiles[id] = camp["profiles"][id]
	return {"objects": camp["objects"], "carriers": carriers, "profiles": profiles}


## A guest's mirror of the camp, built from the host's snapshot.
static func from_snapshot(snap: Dictionary) -> CampState:
	var state := CampState.new({"objects": snap.get("objects", {}), "profiles": snap.get("profiles", {})})
	state.carriers = snap.get("carriers", {})
	for id: String in state.camp["profiles"]:
		state.online.append(id)
	return state
