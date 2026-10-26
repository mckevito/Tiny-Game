extends RefCounted
## Guests and players never pass through chairs, seats or the fire ring (scripts/camp/guest_path.gd, data/guests.json
## "path", data/models.json "collide"): guests walk round every footprint, sit down from open ground, and the ring's
## log seats stop a player like the stones do.

const DIR := "user://test_saves/guest_path"
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## A solo camp in a side of its own, saving to the tests' own folder.
func _solo() -> Node:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)
	var side := Node3D.new()
	side.name = "PathSide"
	_tree().root.add_child(side)
	_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	_sides.append(side)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_path", "name": "Hana", "last_address": ""}
	side.add_child(camp)
	camp.start_solo(1)
	return camp


func _done() -> void:
	for side in _sides:
		var camp: Node = side.get_child(0)
		if camp.state != null:
			camp.stop("")
	await _tree().process_frame
	for side in _sides:
		_tree().set_multiplayer(null, side.get_path())
		side.free()
	_sides.clear()
	CampSave.dir = ""


## A camp with the fire grown to its ring, three guest pitches, a log bench and a stool by the fire, and three guests.
func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.camp["coins"] = 500
	state.camp["fire"] = {"level": 1}
	for p: Vector2 in [Vector2(3, 5), Vector2(-4, 7), Vector2(4, 9)]:
		state.build.build("p_host", "pitch", p, 0.0)
	state.camp["kit"]["log_bench"] = 1
	state.build.build("p_host", "log_bench", Vector2(1.5, 3.2), 0.0)
	state.camp["kit"]["stool"] = 1
	state.build.build("p_host", "stool", Vector2(-1.2, 3.4), 0.0)
	state.camp["calendar"]["minute"] = \
			(Tuning.num("day", "stays.arrive_hour") - Tuning.num("day", "clock.start_hour")) * 60.0
	for i in 3:
		state.day.maybe_arrive()
		state.camp["calendar"]["minute"] = float(state.camp["calendar"]["minute"]) + Tuning.num("day", "stays.gap_min")
	return state


## The first point along a walk that comes within `pad` of a footprint, or null. The walk starts at `from`; legs listed
## in `skip` (0 is the leg from `from`) are stepped onto or off a seat and may cross that seat's own footprint.
func _hit(from: Vector2, points: Array[Vector2], prints: Array[Dictionary], pad: float, skip: Array) -> Variant:
	var at := from
	for leg in points.size():
		var to: Vector2 = points[leg]
		if not skip.has(leg):
			var steps := int(ceil(at.distance_to(to) / 0.05))
			for k in range(1, steps):
				var p := at.lerp(to, float(k) / steps)
				for f: Dictionary in prints:
					if GuestPath.inside(p, f, pad):
						return p
		at = to
	return null


func test_guests_walk_round_chairs_seats_tents_and_the_fire() -> String:
	var state := _camp()
	if state.camp["stays"].size() != 3:
		return "three guests should have come, got %d" % state.camp["stays"].size()
	var prints := GuestPath.footprints(state)
	# Clear of every footprint by the pad, less the grid's own rounding (half a cell's diagonal).
	var pad := float(Tuning.value("guests", "path.pad_m")) - float(Tuning.value("guests", "path.cell_m")) * 0.75
	var entry: Array = Tuning.value("day", "stays.entry")
	var ends: Array[Vector2] = [Vector2(float(entry[0]), float(entry[1]))]
	var seats := GuestPlans.seats(state)
	if seats.size() < 6:
		return "the camp should offer two chairs, the bench's two places, the stool and the ring's logs, got %d" % seats.size()
	for seat: Dictionary in seats:
		ends.append(seat["from"])
		if not GuestPath.clear_at(seat["from"], prints):
			return "a seat's open ground %s should be clear of every footprint" % seat["from"]
	for id: String in state.camp["stays"]:
		ends.append(state.day.stand_point(id))
	for kind in ["fish", "photo", "kite"]:
		for row: Dictionary in Tuning.value("guests", "activities.%s.spots" % kind):
			ends.append(Vector2(float(row["at"][0]), float(row["at"][1])))
	var crossed := 0
	for a in ends:
		for b in ends:
			if a == b:
				continue
			var way := GuestPath.route(a, b, prints)
			if way.is_empty() or way.back() != b:
				return "a walk from %s should end at %s, got %s" % [a, b, way]
			var straight: Array[Vector2] = [b]
			if _hit(a, straight, prints, pad, [0] if not GuestPath.clear_at(a, prints) else []) != null:
				crossed += 1
			var skip := [0] if not GuestPath.clear_at(a, prints) else []
			if not GuestPath.clear_at(b, prints):
				skip.append(way.size() - 1)
			var hit: Variant = _hit(a, way, prints, pad, skip)
			if hit != null:
				return "the walk from %s to %s passes through something at %s: %s" % [a, b, hit, way]
			if GuestPath.length(a, way) > a.distance_to(b) * 2.0 + 4.0:
				return "the walk from %s to %s goes the long way round (%.1f m): %s" % [a, b, GuestPath.length(a, way), way]
	if crossed < 10:
		return "walking straight should have hit something on many of these walks, only %d did" % crossed
	return ""


func test_no_seat_or_model_overlaps_another() -> String:
	var state := _camp()
	state.camp["fire"] = {"level": CampBuild.fire_levels().size()}
	var prints := GuestPath.footprints(state)
	# The pond (path.avoid) is felt on the ground; only solid models count here.
	prints = prints.slice(0, prints.size() - (Tuning.value("guests", "path.avoid") as Array).size())
	for i in prints.size():
		for j in range(i + 1, prints.size()):
			var a: Dictionary = prints[i]
			var b: Dictionary = prints[j]
			var r: float = (a["half"] as Vector2).length()
			if (a["at"] as Vector2).distance_to(b["at"]) > r + (b["half"] as Vector2).length():
				continue
			var steps := int(ceil(r * 2.0 / 0.05))
			for x in steps + 1:
				for y in steps + 1:
					var p: Vector2 = a["at"] + Vector2(-r + x * 0.05, -r + y * 0.05)
					if GuestPath.inside(p, a, 0.0) and GuestPath.inside(p, b, 0.0):
						return "two models overlap at %s: %s and %s" % [p, a, b]
	return ""


func test_a_guest_backs_onto_a_seat_sits_with_legs_out_and_steps_off_forward() -> String:
	var camp := _solo()
	var why := ""
	var c := Camper.new()
	c.model_id = "guest_a"
	camp.add_child(c)
	camp.state.camp["fire"] = {"level": 1}
	var seat: Dictionary = GuestPlans.seats(camp.state).back()
	c.position = Vector3(0.8, 0, 11)
	camp._route_guest(c, null, seat["from"], seat["at"])
	var end: Variant = c.walk_end()
	if not end is Vector3 or Vector2(end.x, end.z).distance_to(seat["at"]) > 0.001:
		why = "the walk should end on the seat %s, ends at %s" % [seat["at"], end]
	# Walk it out a step at a time: the last leg goes backwards, so the guest ends facing the way it will sit.
	var steps := 0
	while why == "" and c.walk_target is Vector3 and steps < 4000:
		c._walk(1.0 / 30.0)
		steps += 1
	if why == "" and Vector2(c.position.x, c.position.z).distance_to(seat["at"]) > 0.02:
		why = "the guest should reach the seat, is at %s" % c.position
	var look: Vector2 = seat["look"] - seat["at"]
	var facing := Vector2(-sin(c.rotation.y), -cos(c.rotation.y))
	if why == "" and facing.dot(look.normalized()) < 0.9:
		why = "backing onto the seat, the guest should face %s, faces %s" % [look.normalized(), facing]
	# Seated, a guest shows its sitting pose (legs out in front, not through the seat); standing, its own look again.
	c.sit(float(seat["sit_y"]))
	if why == "" and c.model_id != str(FeltBuilder.resolve("guest_a").get("sit_model", "")):
		why = "a seated guest should show its sitting pose, shows %s" % c.model_id
	c.sit(0.0)
	if why == "" and c.model_id != "guest_a":
		why = "a guest standing up should show its own look again, shows %s" % c.model_id
	camp._route_guest(c, seat["from"], Vector2(0.8, 11), Vector2(0.8, 11))
	if why == "" and (c.walk_target as Vector3).distance_to(Vector3(seat["from"].x, 0, seat["from"].y)) > 0.001:
		why = "getting up, the guest should step off the seat the way it sat down, first to %s, goes to %s" % [seat["from"], c.walk_target]
	await _done()
	return why


func test_the_rings_log_seats_stop_a_player() -> String:
	var tree := _tree()
	var camp := _solo()
	camp.state.camp["fire"] = {"level": 1}
	camp._sync_fire()
	await tree.physics_frame
	await tree.physics_frame
	var why := ""
	var probe := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.1
	probe.shape = ball
	for seat: Dictionary in Tuning.value("guests", "activities.sit.fire_ring"):
		probe.transform = Transform3D(Basis(), Vector3(float(seat["at"][0]), 0.15, float(seat["at"][1])))
		if camp.get_world_3d().direct_space_state.intersect_shape(probe, 4).is_empty():
			why = "the ring's log at %s should be solid" % [seat["at"]]
			break
	await _done()
	return why
