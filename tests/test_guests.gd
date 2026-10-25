extends RefCounted
## Stage B rules without a scene: fishing and grilling, guests' small requests, satisfaction lines that name their
## cause, and advance bookings (data/guests.json, data/fishing.json).

## Grid spots with room for a pitch: one within reach of the campfire, one out by the path.
const NEAR_FIRE := Vector2(3, 5)
const OPEN := Vector2(-3.2, 7.9)
const WATER := Vector2(4, 8)


func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	state.camp["coins"] = 500
	return state


func _at_hour(state: CampState, hour: float) -> void:
	state.camp["calendar"]["minute"] = (hour - Tuning.num("day", "clock.start_hour")) * 60.0


## Where a scenery model stands (its first placement in data/clearing.json).
func _scenery(model: String) -> Vector2:
	for row: Dictionary in Tuning.table("clearing")["placements"]:
		if row["model"] == model:
			return Vector2(float(row["pos"][0]), float(row["pos"][1]))
	return Vector2.ZERO


func _pitch(state: CampState, at: Vector2) -> String:
	var why := state.build.build("p_host", "pitch", at, 0.0)
	return state.build.last_id if why == "" else ""


func test_fishing_and_grilling_fill_the_pockets_and_never_fail() -> String:
	var state := _camp()
	state.set_player_pos("p_host", Vector2(0, 9), 0.0)
	if state.pockets.fish("p_host") != "deny.no_water":
		return "fishing away from the water should say so"
	var shore := _scenery("pond") + Vector2(-3.4, 0)
	state.set_player_pos("p_host", shore, 0.0)
	for i in 5:
		if state.pockets.fish("p_host") != "":
			return "a cast at the water's edge should always catch something"
	var held := state.pockets.pockets("p_host")
	if held.size() != 5 or CampPockets.kind_of(str(held[0])) != "fish":
		return "each catch should go into the pockets as a fish, got %s" % [held]
	state.pockets.fish("p_host")
	if state.pockets.fish("p_host") != "deny.pockets_full" or held.size() != int(Tuning.num("fishing", "pockets_max")):
		return "a full pocket should refuse more, keeping what it holds"
	if state.pockets.cook("p_host") != "deny.no_fire":
		return "grilling away from the fire should say so"
	state.set_player_pos("p_host", Vector2(1.2, 0.4), 0.0)
	var raw := str(held[0])
	if state.pockets.cook("p_host") != "" or str(held[0]) != str(Tuning.value("fishing", "recipes." + raw)):
		return "grilling should turn the first raw fish into its recipe, got %s" % [held]
	if CampPockets.kind_of(state.pockets.last_item) != "meal":
		return "a grilled fish should be a meal"
	state.camp["profiles"]["p_guest"]["pockets"] = ["grilled_trout"]
	state.set_player_pos("p_guest", Vector2(1.2, 0.4), 0.0)
	if state.pockets.cook("p_guest") != "deny.no_fish":
		return "grilling with no raw fish should say so"
	return ""


func test_a_request_is_met_by_a_gift_or_a_chair_and_tips_at_once() -> String:
	var state := _camp()
	var pitch := _pitch(state, NEAR_FIRE)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	var stay := state.day.maybe_arrive()
	if stay == "" or (state.camp["stays"][stay].get("request", {}) as Dictionary).is_empty():
		return "a guest should come with a request"
	state.camp["stays"][stay]["request"] = {"kind": "meal", "done": false}
	var stand := state.day.stand_point(stay)
	state.set_player_pos("p_host", stand + Vector2(1, 0), 0.0)
	state.camp["profiles"]["p_host"]["pockets"] = ["perch"]
	if state.guests.guest_near("p_host") != stay:
		return "a guest with an open request should be found within talk reach"
	if state.guests.give("p_host", stay) != "deny.nothing_to_give":
		return "a raw fish is not the meal they asked for"
	state.camp["profiles"]["p_host"]["pockets"] = ["perch", "grilled_perch"]
	var coins := int(state.camp["coins"])
	if state.guests.give("p_host", stay) != "":
		return "handing over the grilled fish should be allowed"
	if state.pockets.pockets("p_host") != ["perch"]:
		return "only the meal should leave the pockets, got %s" % [state.pockets.pockets("p_host")]
	var tip := int(Tuning.value("guests", "requests.meal.tip"))
	if int(state.camp["coins"]) != coins + tip or state.guests.open_request(stay) != "":
		return "a met request should pay its tip at once and close"
	if state.guests.give("p_host", stay) != "deny.no_request":
		return "a met request can't be met twice"
	state.camp["stays"][stay]["request"] = {"kind": "chair", "done": false}
	if not state.guests.check_near_requests().is_empty():
		return "no chair is near the pitch yet"
	state.set_player_pos("p_host", state.object_pos("chair_honey_1"), 0.0)
	state.pick_up("p_host", "chair_honey_1")
	var spot := state.object_pos(pitch) + Vector2(-1.6, 1.8)
	state.set_player_pos("p_host", spot, 0.0)
	if state.place("p_host", spot, 0.0) != "":
		return "the chair could not be put down by the pitch"
	if Array(state.guests.check_near_requests()) != [stay]:
		return "a chair by the tent should meet the chair request"
	return ""


func test_each_stay_is_scored_once_with_a_line_that_names_its_cause() -> String:
	var state := _camp()
	_pitch(state, NEAR_FIRE)
	_pitch(state, OPEN)
	if state.build.build("p_host", "water_point", WATER, 0.0) != "":
		return "the water point could not be built"
	state.camp["reservations"].append({"id": "nobody", "state": "declined", "arrive_day": 0})
	state.camp["stays"]["stay_a"] = {"pitch": "pitch_1", "name": "Pip", "look": "guest_a", "nights_left": 1,
			"request": {"kind": "fish", "done": true}}
	state.camp["stays"]["stay_b"] = {"pitch": "pitch_2", "name": "Wren", "look": "guest_b", "nights_left": 2,
			"request": {"kind": "fish", "done": false}}
	var a := state.guests.review("stay_a")
	var b := state.guests.review("stay_b")
	if int(a["points"]) != 3 or a["mood"] != "happy" or a["loved"] != "water" or a["wished"] != "chair":
		return "by the fire and the water with its request met: 3 points, happy, loved water, wished a chair; got %s" % a
	if int(b["points"]) != 0 or b["mood"] != "okay" or b["loved"] != "" or b["wished"] != "water":
		return "out by the path with nothing near: 0 points, okay, wished water; got %s" % b
	if int(a["tip"]) != 3 * int(Tuning.value("guests", "satisfaction.tip_per_point")):
		return "the tip should be the points times tip_per_point"
	var coins := int(state.camp["coins"])
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	var summary := state.day.settle_night()
	var reviews: Array = summary["reviews"]
	if reviews.size() != 1 or reviews[0]["name"] != "Pip":
		return "only the guest whose stay ended is scored, once; got %s" % [reviews]
	var lodging := 2 * int(Tuning.num("day", "lodging.pitch"))
	if int(state.camp["coins"]) != coins + lodging + int(a["tip"]) or int(summary["coins"]) != lodging + int(a["tip"]):
		return "the night should pay both pitches and Pip's tip"
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	summary = state.day.settle_night()
	if (summary["reviews"] as Array).size() != 1 or summary["reviews"][0]["name"] != "Wren":
		return "Wren is scored when her stay ends, the next night"
	return ""


func test_a_booking_waits_on_the_board_and_comes_when_there_is_room() -> String:
	var state := _camp()
	var plan := CampGuests.plan("ferns")
	if Array(state.guests.refresh_offers()) != ["ferns"] or not state.guests.refresh_offers().is_empty():
		return "day 1 should put the first booking on the board once"
	var row := state.guests.row("ferns")
	if row["state"] != "offered" or int(row["arrive_day"]) != int(plan["arrive_day"]):
		return "the booking should be offered for its arrival day, got %s" % row
	var line := state.guests.booking_line(row)
	if not (line.contains(Tuning.text("booking.ferns.name")) and line.contains(str(int(plan["essential"]["pitches"])))
			and line.contains(Tuning.text("build.water_point"))):
		return "the board should list who, the pitches needed and the nice-to-haves before accepting: " + line
	if state.guests.decide("p_host", "ferns", "later") != "" or int(row["arrive_day"]) != int(plan["arrive_day"]) + 1:
		return "asking them to come a day later should move the day"
	if state.guests.decide("p_guest", "ferns", "accept") != "" or row["state"] != "accepted":
		return "either player should be able to accept"
	if state.guests.decide("p_host", "ferns", "accept") != "deny.no_booking":
		return "an accepted booking can't be accepted again"
	# Arrival day with one pitch: they wait, and the walk-in guest leaves the pitch for them.
	state.camp["calendar"]["day"] = int(row["arrive_day"])
	_pitch(state, NEAR_FIRE)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	if not state.day.arrivals().is_empty() or row["state"] != "accepted":
		return "without room the booking should wait, and no walk-in should take its pitch"
	if not state.guests.booking_line(row).contains(Tuning.text("booking.waiting") % 1):
		return "the board should say how many more pitches they wait for"
	_pitch(state, OPEN)
	state.build.build("p_host", "water_point", WATER, 0.0)
	var came := state.day.arrivals()
	if came.size() != int(plan["essential"]["pitches"]) or row["state"] != "arrived":
		return "with room the whole booking should arrive, got %s" % [came]
	if (row["extras"] as Array) != ["water_point"] or int(row["bonus"]) != int(plan["optional"][0]["bonus"]):
		return "the water point should count as an extra, got %s" % row
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	var summary := state.day.settle_night()
	if (summary["bonuses"] as Array).size() != 1 or int(summary["bonuses"][0]["coins"]) != int(row["bonus"]):
		return "the extras bonus should be paid with the first night"
	if row["state"] != "done":
		return "after the guests head home the booking is done"
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	if not (state.day.settle_night()["bonuses"] as Array).is_empty():
		return "the bonus pays once"
	state.camp["calendar"]["day"] = int(CampGuests.plan("birdwatchers")["offer_day"])
	state.guests.refresh_offers()
	if state.guests.decide("p_host", "birdwatchers", "decline") != "" or not state.guests.current().is_empty():
		return "declining takes a booking off the board with no penalty"
	return ""


func test_the_day_offers_three_goals() -> String:
	var state := _camp()
	state.guests.refresh_offers()
	var goals := state.guests.goals()
	if goals.size() != 3 or not goals[1].contains(Tuning.text("booking.ferns.name")) \
			or not goals[2].contains(Tuning.text("build.water_point")):
		return "with an offer on the board, the project is the booking and the dream the first improvement: %s" % [goals]
	state.guests.decide("p_host", "ferns", "accept")
	goals = state.guests.goals()
	if not goals[1].contains("2"):
		return "an accepted booking's project should say how many pitches to make: %s" % [goals]
	_pitch(state, NEAR_FIRE)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	var stay := state.day.maybe_arrive()
	state.camp["stays"][stay]["request"] = {"kind": "fish", "done": false}
	if not state.guests.goals()[0].contains(str(state.camp["stays"][stay]["name"])):
		return "a guest's open request should be the quick task"
	return ""


func test_stage_b_survives_save_and_load() -> String:
	CampSave.dir = "user://test_saves/guests"
	var state := _camp()
	state.guests.refresh_offers()
	state.guests.decide("p_host", "ferns", "accept")
	state.camp["profiles"]["p_host"]["pockets"] = ["trout", "grilled_perch"]
	CampSave.save(1, state.camp)
	var loaded := CampSave.load_slot(1)["camp"] as Dictionary
	CampSave.dir = ""
	if loaded == null or loaded["reservations"][0]["state"] != "accepted" \
			or loaded["profiles"]["p_host"]["pockets"] != ["trout", "grilled_perch"]:
		return "bookings and pockets should come back from the save"
	var old := CampSave.new_camp()
	old["version"] = 2
	old.erase("reservations")
	if not CampSave.upgrade(old)["reservations"] is Array:
		return "a Stage A save (version 2) should get an empty booking board"
	return ""
