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


func test_fishing_and_grilling_fill_the_pack_and_never_fail() -> String:
	var state := _camp()
	state.set_player_pos("p_host", Vector2(0, 9), 0.0)
	if state.pack.fish("p_host") != "deny.no_water":
		return "fishing away from the water should say so"
	var shore := _scenery("pond") + Vector2(-3.4, 0)
	state.set_player_pos("p_host", shore, 0.0)
	for i in 5:
		if state.pack.fish("p_host") != "":
			return "a cast at the water's edge should always catch something"
	var caught := 0
	for st: Dictionary in state.pack.slots("p_host"):
		if CampPack.kind_of(str(st["item"])) == "fish":
			caught += int(st["n"])
	if caught != 5 or state.pack.slots("p_host").size() > 3:
		return "each catch should stack in the Pack as a fish, got %s" % [state.pack.slots("p_host")]
	if state.pack.cook("p_host") != "deny.no_fire":
		return "grilling away from the fire should say so"
	state.set_player_pos("p_host", Vector2(1.2, 0.4), 0.0)
	if state.pack.cook("p_host") != "deny.no_wood":
		return "grilling with no stick or wood should ask for some"
	state.pack.add_to_box("wood", 2)
	state.pack.add("p_host", "stick", 1)
	var raw := state.pack.first_of("p_host", "fish")
	if state.pack.cook("p_host") != "" or state.pack.count("p_host", str(Tuning.value("fishing", "recipes." + raw))) != 1:
		return "grilling should turn the first raw fish into its recipe, got %s" % [state.pack.slots("p_host")]
	if state.pack.count("p_host", "stick") != 0 or state.pack.box_count("wood") != 2:
		return "grilling should burn a stick from the Pack before the box's wood"
	if state.pack.cook("p_host") != "" or state.pack.box_count("wood") != 1:
		return "with no sticks left the fire should take wood from the camp box"
	if CampPack.kind_of(state.pack.last_item) != "meal":
		return "a grilled fish should be a meal"
	state.camp["profiles"]["p_guest"]["pack"] = [{"item": "grilled_trout", "n": 1}]
	state.set_player_pos("p_guest", Vector2(1.2, 0.4), 0.0)
	if state.pack.cook("p_guest") != "deny.no_fish":
		return "grilling with no raw fish should say so"
	return ""


func test_the_pack_stacks_drops_bundles_and_never_loses_anything() -> String:
	var state := _camp()
	var cap := int(Tuning.num("items", "stack_max"))
	var slots := int(Tuning.num("items", "pack_slots"))
	if state.pack.add("p_host", "stick", cap + 5) != cap + 5 or state.pack.slots("p_host").size() != 2:
		return "a stack should hold up to stack_max and spill into a new slot"
	if state.pack.room_for("p_host", "berries") != (slots - 2) * cap:
		return "room should count free slots"
	for i in slots - 2:
		state.pack.add("p_host", "item_%d" % i, cap)
	if state.pack.add("p_host", "berries") != 0 or state.pack.room_for("p_host", "stick") != cap - 5:
		return "a full Pack should take no new kind but still top up its own stacks"
	state.set_player_pos("p_host", Vector2(-3, 6), 0.0)
	if state.pack.drop("p_host", 1) != "" or state.pack.count("p_host", "stick") != cap:
		return "dropping should set down the whole picked stack"
	var bundle := state.pack.last_bundle
	if state.pack.bundle_near(Vector2(-3, 6)) != bundle or int(state.camp["bundles"][bundle]["n"]) != 5:
		return "the dropped stack should lie as a bundle at the player's feet"
	state.pack.drop("p_host", 0)
	if state.camp["bundles"].size() != 1 or int(state.camp["bundles"][bundle]["n"]) != cap + 5:
		return "a stack dropped by a bundle of the same thing should join it"
	state.set_player_pos("p_guest", Vector2(-3, 6.5), 0.0)
	if state.pack.pick_bundle("p_guest", bundle) != "" or state.pack.count("p_guest", "stick") != cap + 5 \
			or state.camp["bundles"].has(bundle):
		return "the other player should pick the whole bundle up: dropping is how you hand things over"
	state.camp["profiles"]["p_guest"]["pack"] = []
	for i in slots - 1:
		state.pack.add("p_guest", "item_%d" % i, cap)
	state.pack.add("p_guest", "stick", cap - 3)
	state.camp["bundles"]["b1"] = {"item": "stick", "n": 10, "pos": [-3, 6.5]}
	if state.pack.pick_bundle("p_guest", "b1") != "" or int(state.camp["bundles"]["b1"]["n"]) != 7:
		return "what doesn't fit should stay in the bundle, never lost"
	return ""


func test_the_camp_box_takes_materials_and_pays_for_crafts() -> String:
	var state := _camp()
	state.pack.add("p_host", "wood", 6)
	state.pack.add("p_host", "stick", 3)
	state.pack.add("p_host", "perch", 1)
	state.set_player_pos("p_host", Vector2(5, 5), 0.0)
	if state.pack.deposit("p_host") != 0:
		return "the box should be out of reach from across the camp"
	state.set_player_pos("p_host", CampPack.box_pos() + Vector2(0.9, 0.0), 0.0)
	if state.pack.deposit("p_host") != 9 or state.pack.box_count("wood") != 6 or state.pack.count("p_host", "perch") != 1:
		return "deposit should put every material in the box and keep the fish"
	state.set_player_pos("p_host", CampBuild.bench_pos() + Vector2(0.0, 1.2), 0.0)
	var r := CampBuild.recipe("log_bench")
	if state.build.craft("p_host", "log_bench") != "" or state.build.in_kit("log_bench") != 1:
		return "the workbench should craft a log bench from the camp box into the kit"
	if state.pack.box_count("wood") != 6 - int(r["items"]["wood"]):
		return "crafting should take materials from the box"
	if state.build.craft("p_host", "water_point") != "deny.materials":
		return "a recipe short of materials should say so"
	state.set_player_pos("p_host", Vector2(5, 5), 0.0)
	if state.build.craft("p_host", "log_bench") != "deny.too_far":
		return "crafting happens at the workbench"
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
	state.camp["profiles"]["p_host"]["pack"] = [{"item": "perch", "n": 1}]
	if state.guests.guest_near("p_host") != stay:
		return "a guest with an open request should be found within talk reach"
	if state.guests.give("p_host", stay) != "deny.nothing_to_give":
		return "a raw fish is not the meal they asked for"
	state.camp["profiles"]["p_host"]["pack"] = [{"item": "perch", "n": 1}, {"item": "grilled_perch", "n": 1}]
	var coins := int(state.camp["coins"])
	if state.guests.give("p_host", stay) != "":
		return "handing over the grilled fish should be allowed"
	if state.pack.slots("p_host") != [{"item": "perch", "n": 1}]:
		return "only the meal should leave the Pack, got %s" % [state.pack.slots("p_host")]
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
	state.camp["kit"]["water_point"] = 1
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
	state.camp["kit"]["water_point"] = 1
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
	for night in int(plan.get("nights", 1)) - 1:
		if row["state"] == "done":
			return "the booking should stay all its nights"
		_at_hour(state, Tuning.num("day", "clock.end_hour"))
		if not (state.day.settle_night()["bonuses"] as Array).is_empty():
			return "the extras bonus should be paid only once"
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
	state.camp["profiles"]["p_host"]["pack"] = [{"item": "trout", "n": 2}]
	state.pack.add_to_box("wood", 4)
	state.camp["kit"]["log_bench"] = 1
	state.camp["bundles"]["bundle_9"] = {"item": "stick", "n": 3, "pos": [1, 2]}
	CampSave.save(1, state.camp)
	var loaded := CampSave.load_slot(1)["camp"] as Dictionary
	CampSave.dir = ""
	if loaded == null or loaded["reservations"][0]["state"] != "accepted" \
			or int(loaded["profiles"]["p_host"]["pack"][0]["n"]) != 2 or int(loaded["box"]["wood"]) != 4 \
			or int(loaded["kit"]["log_bench"]) != 1 or int(loaded["bundles"]["bundle_9"]["n"]) != 3:
		return "bookings, Packs, the box, the kit and bundles should come back from the save"
	var v4 := CampSave.new_camp()
	v4["version"] = 4
	v4["wood"] = 7
	v4.erase("box")
	v4["profiles"]["p_old"] = {"name": "Old", "pockets": ["perch", "perch", "berries"]}
	var up := CampSave.upgrade(v4)
	if int(up["box"].get("wood", 0)) != 7 or up.has("wood") or up["profiles"]["p_old"].has("pockets") \
			or up["profiles"]["p_old"]["pack"] != [{"item": "perch", "n": 2}, {"item": "berries", "n": 1}]:
		return "a round 2 save should move its wood pile into the box and its pockets into stacks, got %s" % [up["profiles"]["p_old"]]
	var old := CampSave.new_camp()
	old["version"] = 2
	old.erase("reservations")
	if not CampSave.upgrade(old)["reservations"] is Array:
		return "a Stage A save (version 2) should get an empty booking board"
	return ""


## Guests are the heart of the day (owner, 25 Oct 2026): a met request is followed by another a while later, up to
## today's share, which grows as the days go on; nothing new is asked at night.
func test_guests_ask_again_up_to_a_share_that_grows() -> String:
	var state := _camp()
	if CampGuests.per_day(1) < 2 or CampGuests.per_day(5) <= CampGuests.per_day(1):
		return "guests should ask more than once a day, and more later in the season"
	_pitch(state, NEAR_FIRE)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	var stay := state.day.maybe_arrive()
	var wait := Tuning.num("guests", "more.wait_min")
	for i in CampGuests.per_day(1):
		var kind := state.guests.open_request(stay)
		if kind == "":
			return "request %d should be open" % (i + 1)
		state.guests._met(stay)
		if not state.guests.refresh_requests().is_empty():
			return "a new request should wait a while after one is met"
		state.camp["calendar"]["minute"] = state.day.minute() + wait + 1.0
		var fresh := state.guests.refresh_requests()
		if i < CampGuests.per_day(1) - 1 and fresh != [stay]:
			return "after the wait the guest should ask again (request %d)" % (i + 2)
		if i == CampGuests.per_day(1) - 1 and not fresh.is_empty():
			return "after today's share the guest should be content till tomorrow"
	return ""


## First-minutes round 4: guests with nothing to ask go fishing, take photos, fly kites, sit or rest, and two of them
## sometimes throw a frisbee together; never two on one spot, the same answer every time (so both PCs agree); a guest
## with an open request or asleep stays by their tent; a carried chair is no seat and the grown fire adds its logs.
func test_free_guests_find_something_to_do_and_wait_home_with_a_request() -> String:
	var state := _camp()
	for p: Vector2 in [Vector2(3, 5), Vector2(-4, 7), Vector2(-7.5, 5)]:
		var why := state.build.build("p_host", "pitch", p, 0.0)
		if why != "":
			return "could not build a pitch at %s: %s" % [p, why]
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	for i in 3:
		state.day.maybe_arrive()
		state.camp["calendar"]["minute"] = float(state.camp["calendar"]["minute"]) + Tuning.num("day", "stays.gap_min")
	if state.camp["stays"].size() != 3:
		return "three guests should have come, got %d" % state.camp["stays"].size()
	for id: String in state.camp["stays"]:
		state.camp["stays"][id]["request"] = {"kind": "fish", "done": true}
	var seen := {}
	var slot_min := Tuning.num("guests", "activities.slot_min")
	for day in 4:
		state.camp["calendar"]["day"] = day + 1
		for slot in int(CampDay.day_minutes() / slot_min):
			state.camp["calendar"]["minute"] = slot * slot_min + 1.0
			var plans := GuestPlans.plan(state, false)
			if plans != GuestPlans.plan(state, false) or plans.size() != 3:
				return "every guest should get one steady plan, got %s" % plans
			var spots := {}
			for id: String in plans:
				var p: Dictionary = plans[id]
				seen[p["kind"]] = true
				if spots.has(p["at"]):
					return "two guests should never share a spot: %s" % plans
				spots[p["at"]] = true
				if p["kind"] == "frisbee" and (plans[p["pair"]]["pair"] != id or plans[p["pair"]]["kind"] != "frisbee"):
					return "a frisbee needs two players throwing to each other: %s" % plans
	for kind in ["fish", "photo", "kite", "sit", "frisbee"]:
		if not seen.has(kind):
			return "over four days some guest should go %s, saw %s" % [kind, seen.keys()]
	var first: String = state.camp["stays"].keys()[0]
	state.camp["stays"][first]["request"] = {"kind": "fish", "done": false}
	if GuestPlans.plan(state, false)[first] != GuestPlans.home(state, first):
		return "a guest with an open request should wait by their tent"
	if GuestPlans.plan(state, true).values().any(func(p: Dictionary) -> bool: return p["kind"] != "rest"):
		return "asleep, every guest should be at their tent"
	var seats := GuestPlans.seats(state).size()
	state.carriers["chair_teal_1"] = "p_host"
	if GuestPlans.seats(state).size() != seats - 1:
		return "a chair someone carries should be no seat"
	state.camp["fire"] = {"level": 1}
	if GuestPlans.seats(state).size() != seats - 1 + (Tuning.value("guests", "activities.sit.fire_ring") as Array).size():
		return "the stone ring should add its log seats"
	return ""
