extends RefCounted
## Milestone 2: the host's rules for carrying and placing, keyed by profile IDs (data/tuning.json "carry").


func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func _stand(state: CampState, who: String, x: float, z: float) -> void:
	state.set_player_pos(who, Vector2(x, z), 0.0)


func test_pick_up_and_place_a_chair() -> String:
	var state := _camp()
	var chair := state.object_pos("chair_teal_1")
	_stand(state, "p_guest", chair.x, chair.y + 0.5)
	var why := state.pick_up("p_guest", "chair_teal_1")
	if why != "":
		return "pick up refused: " + why
	_stand(state, "p_guest", 0.0, 3.0)
	why = state.place("p_guest", Vector2(0, 2.2), 90.0)
	if why != "":
		return "place refused: " + why
	return "" if state.object_pos("chair_teal_1").is_equal_approx(Vector2(0, 2.2)) and state.carriers.is_empty() \
			else "the chair did not move"


func test_one_carrier_at_a_time_and_one_thing_each() -> String:
	var state := _camp()
	var teal := state.object_pos("chair_teal_1")
	_stand(state, "p_guest", teal.x, teal.y)
	_stand(state, "p_host", teal.x, teal.y)
	state.pick_up("p_guest", "chair_teal_1")
	if state.pick_up("p_host", "chair_teal_1") != "deny.carried":
		return "the host took a chair the guest was carrying"
	var honey := state.object_pos("chair_honey_1")
	_stand(state, "p_guest", honey.x, honey.y)
	return "" if state.pick_up("p_guest", "chair_honey_1") == "deny.hands_full" else "a player carried two things"


func test_reach_bounds_and_room_are_checked() -> String:
	var state := _camp()
	var teal := state.object_pos("chair_teal_1")
	_stand(state, "p_guest", teal.x + 5.0, teal.y)
	if state.pick_up("p_guest", "chair_teal_1") != "deny.too_far":
		return "picked up from too far away"
	_stand(state, "p_guest", teal.x, teal.y)
	state.pick_up("p_guest", "chair_teal_1")
	var edge := Tuning.num("tuning", "carry.camp_radius_m")
	_stand(state, "p_guest", edge + 0.5, 0.0)
	if state.place("p_guest", Vector2(edge + 1.0, 0.0), 0.0) != "deny.out_of_bounds":
		return "placed outside the camp"
	var honey := state.object_pos("chair_honey_1")
	_stand(state, "p_guest", honey.x, honey.y + 1.0)
	if state.place("p_guest", honey + Vector2(0.1, 0.0), 0.0) != "deny.too_close":
		return "placed on top of the other chair"
	_stand(state, "p_guest", 0.0, -4.0)
	_stand(state, "p_host", 0.0, -3.0)
	return "" if state.place("p_guest", Vector2(0.0, -3.1), 0.0) == "deny.too_close" else "placed on the other player"


func test_scenery_cannot_be_carried() -> String:
	var state := _camp()
	state.camp["objects"]["tent_x"] = {"model": "tent", "pos": [0, 0], "yaw": 0}
	_stand(state, "p_guest", 0.0, 0.0)
	return "" if state.pick_up("p_guest", "tent_x") == "deny.not_movable" else "a tent was picked up"


func test_leaving_sets_things_down_at_their_last_spot() -> String:
	var state := _camp()
	var teal := state.object_pos("chair_teal_1")
	_stand(state, "p_guest", teal.x, teal.y)
	state.pick_up("p_guest", "chair_teal_1")
	var dropped := state.leave("p_guest")
	if dropped != ["chair_teal_1"] or not state.carriers.is_empty():
		return "leaving did not put the chair down"
	return "" if state.object_pos("chair_teal_1") == teal and not state.online.has("p_guest") else "the chair moved"


func test_characters_belong_to_profiles_not_connections() -> String:
	var state := _camp()
	var look: String = state.camp["profiles"]["p_guest"]["look"]["model"]
	if look == state.camp["profiles"]["p_host"]["look"]["model"]:
		return "the two players got the same look"
	_stand(state, "p_guest", 3.0, 2.0)
	state.leave("p_guest")
	var back := state.join("p_guest", "")
	if back["look"]["model"] != look or state.player_pos("p_guest") != Vector2(3, 2) or back["name"] != "Gus":
		return "rejoining did not bring back the same character"
	return "" if state.camp["profiles"].size() == 2 else "rejoining made a second character"


## Playtest found a player could walk off the clearing into the empty field; the edge holds them now.
func test_a_player_cannot_walk_off_the_clearing() -> String:
	var edge := Tuning.num("tuning", "movement.edge_m")
	if Camper.keep_in(Vector3(edge * 3.0, 0.5, 0.0)).distance_to(Vector3(edge, 0.5, 0.0)) > 0.001:
		return "a spot far past the edge should be brought back to the edge"
	if Camper.keep_in(Vector3(1, 0, 2)) != Vector3(1, 0, 2):
		return "a spot inside the clearing should stay as it is"
	var c := Camper.new()
	c.controlled = true
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	c.position = Vector3(edge + 5.0, 0.0, 0.0)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var out := Vector2(c.position.x, c.position.z).length()
	c.free()
	return "" if out <= edge + 0.01 else "a walking player should be held at the edge, got %.2f m out" % out
