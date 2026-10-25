extends RefCounted
## Stage A rules without a scene: the day clock and calendar, the sleep vote, the night that pays exactly once, guests
## at a free pitch, and grid placement with undo (data/day.json, data/build.json).

## A grid spot in the clearing with room for a pitch (clear of the trees, the path and the pond).
const OPEN := Vector2(-3.2, 7.9)


func _camp() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


func _at_hour(state: CampState, hour: float) -> void:
	state.camp["calendar"]["minute"] = (hour - Tuning.num("day", "clock.start_hour")) * 60.0


func _price() -> int:
	return int(Tuning.num("day", "lodging.pitch"))


func test_the_clock_runs_to_the_evening_and_waits_there() -> String:
	var state := _camp()
	var day := state.day
	if not is_equal_approx(day.hour(), Tuning.num("day", "clock.start_hour")):
		return "a new camp should start in the morning, got %s" % day.hour()
	var real := Tuning.num("day", "clock.real_seconds_per_day")
	day.advance(real * 0.5)
	var half := lerpf(Tuning.num("day", "clock.start_hour"), Tuning.num("day", "clock.end_hour"), 0.5)
	if not is_equal_approx(day.hour(), half):
		return "half a day of real time should reach %s, got %s" % [half, day.hour()]
	day.advance(real * 10.0)
	if not is_equal_approx(day.hour(), Tuning.num("day", "clock.end_hour")):
		return "the clock should wait at the end of the day, got %s" % day.hour()
	if int(state.camp["calendar"]["day"]) != 1 or not day.is_evening():
		return "waiting at the end of the day should stay on day 1 in the evening"
	return ""


func test_the_calendar_turns_days_seasons_and_years() -> String:
	var state := _camp()
	var per := int(Tuning.num("day", "calendar.days_per_season"))
	var seasons: Array = Tuning.value("day", "calendar.seasons")
	var before := state.day.today()
	state.camp["calendar"]["day"] = per
	state.day._next_morning()
	var cal: Dictionary = state.camp["calendar"]
	if not (cal["season"] == seasons[1] and int(cal["day"]) == 1 and float(cal["minute"]) == 0.0):
		return "after the last day of spring should come the first morning of summer, got %s" % cal
	cal["season"] = seasons[-1]
	cal["day"] = per
	var last := state.day.today()
	state.day._next_morning()
	if not (cal["season"] == seasons[0] and int(cal["year"]) == 2 and state.day.today() == last + 1):
		return "after winter's last day should come year two's spring, the next day number, got %s" % cal
	if before != 1:
		return "the first day should be day number 1, got %d" % before
	return ""


func test_bed_needs_everyone_and_either_can_cancel() -> String:
	var state := _camp()
	if state.day.vote("p_host", true) != "deny.too_early":
		return "bed should wait for the evening"
	_at_hour(state, Tuning.num("day", "clock.evening_hour"))
	if state.day.vote("p_host", true) != "" or state.day.everyone_ready():
		return "one of two players ready should not start the night"
	if state.day.vote("p_nobody", true) != "deny.not_here":
		return "a player not in the camp should not vote"
	state.day.vote("p_guest", true)
	if not state.day.everyone_ready():
		return "both players ready should start the night"
	state.day.vote("p_host", false)
	if state.day.everyone_ready():
		return "either player should be able to cancel"
	state.day.vote("p_host", true)
	state.leave("p_guest")
	if not (state.day.everyone_ready() and not state.day.votes.has("p_guest")):
		return "a player who leaves takes their vote with them; whoever is left decides"
	return ""


func test_a_night_pays_exactly_once() -> String:
	var state := _camp()
	if state.build.build("p_host", "pitch", OPEN, 0.0) != "":
		return "the pitch could not be built at the test spot"
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	if state.day.maybe_arrive() == "":
		return "no guest came to the free pitch"
	var coins := int(state.camp["coins"])
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	var night := state.day.today()
	var summary := state.day.settle_night()
	if int(summary.get("coins", -1)) != _price() or int(state.camp["coins"]) != coins + _price():
		return "the night should pay the pitch's price once, got %s" % summary
	if int(state.camp["last_settled"]) != night or (state.camp["ledger"] as Array).size() != 1:
		return "the night should be written down as settled"
	if state.day.today() != night + 1 or state.day.hour() != Tuning.num("day", "clock.start_hour"):
		return "the night should turn to the next morning"
	# A stale request for the night already paid (an old calendar, as after reloading an older copy) pays nothing.
	state.camp["calendar"]["day"] = int(state.camp["calendar"]["day"]) - 1
	if not state.day.settle_night().is_empty() or int(state.camp["coins"]) != coins + _price():
		return "a night that already paid was paid again"
	return ""


func test_a_night_survives_save_and_load_without_paying_again() -> String:
	CampSave.dir = "user://test_saves/day"
	var state := _camp()
	state.build.build("p_host", "pitch", OPEN, 0.0)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	state.day.maybe_arrive()
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	state.day.settle_night()
	CampSave.save(1, state.camp)
	var loaded := CampState.new(CampSave.load_slot(1)["camp"])
	CampSave.dir = ""
	loaded.join("p_host", "Hana")
	if int(loaded.camp["coins"]) != int(state.camp["coins"]) or loaded.day.today() != state.day.today():
		return "the save should hold the coins and the next morning"
	if loaded.day.vote("p_host", true) != "deny.too_early":
		return "after loading, the morning should not allow bed again at once"
	loaded.camp["calendar"] = state.camp["calendar"].duplicate()
	loaded.camp["calendar"]["day"] = int(loaded.camp["calendar"]["day"]) - 1
	_at_hour(loaded, Tuning.num("day", "clock.end_hour"))
	if not loaded.day.settle_night().is_empty():
		return "the loaded camp paid the settled night again"
	return ""


func test_a_guest_comes_to_a_free_pitch_stays_and_heads_home() -> String:
	var state := _camp()
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	if state.day.maybe_arrive() != "":
		return "a guest came with no pitch to stay at"
	state.build.build("p_host", "pitch", OPEN, 0.0)
	_at_hour(state, Tuning.num("day", "stays.arrive_hour") - 1.0)
	if state.day.maybe_arrive() != "":
		return "a guest came before the arrival hour"
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	var first := state.day.maybe_arrive()
	if first == "" or state.day.maybe_arrive() != "":
		return "one guest should come to the one free pitch, and only one"
	var pitch: String = state.camp["stays"][first]["pitch"]
	if state.day.stay_at(pitch) != first or state.day.free_pitch() != "":
		return "the guest's pitch should be taken"
	var stand := state.day.stand_point(first)
	if stand.distance_to(state.object_pos(pitch)) > 3.0:
		return "the guest should stand by their pitch, got %s" % stand
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	var summary := state.day.settle_night()
	if not (summary["left"] as Array).has(first) or state.camp["stays"].has(first):
		return "after their night the guest should head home"
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	var second := state.day.maybe_arrive()
	if second == "" or state.camp["stays"][second]["name"] == state.camp["ledger"][0]["lines"][0]["name"]:
		return "the next morning a different guest should come"
	return ""


func test_grid_placement_snaps_costs_and_refuses_bad_spots() -> String:
	var state := _camp()
	var start := int(state.camp["coins"])
	var cost := CampBuild.cost("pitch")
	if start < cost:
		return "a new camp should afford its first pitch"
	if state.build.build("p_host", "pitch", OPEN, 80.0) != "":
		return "the pitch could not be built"
	var id := state.build.last_id
	var row: Dictionary = state.camp["objects"][id]
	if not (Vector2(row["pos"][0], row["pos"][1]).is_equal_approx(CampBuild.snap(OPEN)) and float(row["yaw"]) == 90.0):
		return "the pitch should sit on the grid in a quarter turn, got %s" % row
	if int(state.camp["coins"]) != start - cost:
		return "the pitch should cost its price"
	if state.build.building_at(CampBuild.snap(OPEN) + Vector2(1.2, -1.2)) != id:
		return "a spot inside the pitch's footprint should find the pitch"
	for spot in [OPEN + Vector2(1, 0), Vector2(5.6, -4.2), Vector2(0, 0), Vector2(11.5, 0)]:
		if state.build.check("pitch", CampBuild.snap(spot), 0.0) == "":
			return "a pitch should not fit at %s (another pitch, the pond, the fire, the camp edge)" % spot
	if state.build.check("pitch", Vector2(11.5, 0), 0.0) != "deny.out_of_bounds":
		return "past the camp edge should say so"
	var chair := state.object_pos("chair_teal_1")
	if state.build.check("pitch", CampBuild.snap(chair), 0.0) != "deny.too_close":
		return "a pitch should not cover a chair"
	state.camp["coins"] = cost - 1
	if state.build.build("p_host", "pitch", Vector2(-6, 5), 0.0) != "deny.coins":
		return "a pitch should wait for enough coins"
	return ""


func test_undo_and_pack_away_refund_in_full() -> String:
	var state := _camp()
	var start := int(state.camp["coins"])
	state.build.build("p_host", "pitch", OPEN, 0.0)
	var id := state.build.last_id
	if state.build.undo_last("p_guest") != "deny.nothing_to_undo":
		return "a player should only undo their own steps"
	if state.build.undo_last("p_host") != "" or state.camp["objects"].has(id) or int(state.camp["coins"]) != start:
		return "undo should take the pitch away at a full refund"
	if state.build.undo_last("p_host") != "deny.nothing_to_undo":
		return "nothing should be left to undo"
	state.build.build("p_guest", "pitch", OPEN, 0.0)
	id = state.build.last_id
	if state.build.pack("p_host", id) != "" or int(state.camp["coins"]) != start:
		return "packing a pitch away should refund it in full"
	if state.build.undo_last("p_host") != "" or not state.camp["objects"].has(id) \
			or int(state.camp["coins"]) != start - CampBuild.cost("pitch"):
		return "undoing a pack should bring the same pitch back"
	_at_hour(state, Tuning.num("day", "stays.arrive_hour"))
	state.day.maybe_arrive()
	if state.build.pack("p_host", id) != "deny.pitch_in_use" or state.build.undo_last("p_guest") != "deny.pitch_in_use":
		return "a pitch with a guest should stay until they leave"
	_at_hour(state, Tuning.num("day", "clock.end_hour"))
	state.day.settle_night()
	if state.build.undo_last("p_guest") != "deny.nothing_to_undo":
		return "the undo list should clear each night"
	if state.build.pack("p_guest", id) != "":
		return "after the guest left, the pitch should pack away"
	return ""


func test_an_older_save_gets_the_starting_coins() -> String:
	var old := CampSave.new_camp()
	old["version"] = 1
	old["coins"] = 0
	old.erase("stays")
	old.erase("last_settled")
	var camp := CampSave.upgrade(old)
	if int(camp["coins"]) != int(Tuning.value("save", "new_camp.coins")) or int(camp["last_settled"]) != 0 \
			or not camp["stays"] is Dictionary or int(camp["version"]) != CampSave.version():
		return "a version 1 camp should get the starting coins and the new fields, got %s" % camp
	return ""
