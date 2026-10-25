extends RefCounted
## Gameplay round 3: the camp's star rating (data/rating.json). It rises with what the camp has, never goes down,
## and the ranger's hint names what would help next.

const NEAR_FIRE := Vector2(3, 5)
const OPEN := Vector2(-3.2, 7.9)


func _state() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.camp["coins"] = 500
	return state


func _build(state: CampState, kind: String, at: Vector2) -> String:
	state.set_player_pos("p_host", at - Vector2(0, Tuning.num("build", "ahead_m")), 0.0)
	return state.build.build("p_host", kind, at, 0.0)


func test_the_rating_rises_with_the_camp_and_never_goes_down() -> String:
	var s := _state()
	if s.rating.stars() != 1 or s.rating.hint() != "pitches":
		return "a new camp should have one star and a hint about pitches, got %d, %s" % [s.rating.stars(), s.rating.hint()]
	for at in [NEAR_FIRE, OPEN]:
		var why := _build(s, "pitch", at)
		if why != "":
			return "could not build a pitch at %s: %s" % [at, why]
	s.camp["kit"]["lantern_post"] = 2
	_build(s, "lantern_post", Vector2(1, 3))
	_build(s, "lantern_post", Vector2(-1, 6))
	s.camp["journal"]["photos"] = {"rabbit": 1, "deer": 2}
	s.camp["projects"]["done"].assign(["stools"])
	var want := mini(2 * 4, 12) + mini(2 * 2, 16) + mini(2 * 2, 8) + 3
	if s.rating.points() != want:
		return "points should add each factor up to its cap: want %d, got %d" % [want, s.rating.points()]
	var summary := s.day.settle_night()
	var rated: Dictionary = summary.get("rating", {})
	if int(rated.get("stars", 0)) != CampRating.stars_for(want) or CampRating.stars_for(want) < 2:
		return "the night should work out the stars again: %s" % [rated]
	if s.rating.hint() != "pitches":
		return "the hint should name the first factor under its cap, got " + s.rating.hint()
	for id: String in s.camp["objects"].keys():
		if str(s.camp["objects"][id]["model"]) in ["lantern_post", "pitch"]:
			s.camp["objects"].erase(id)
	s.day.settle_night()
	if s.rating.stars() != int(rated["stars"]):
		return "packing things away should never take stars away"
	return ""


func test_the_morning_report_and_today_list_show_the_stars_and_a_hint() -> String:
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": "p_rate", "name": "Juniper", "last_address": ""}
	CampSave.dir = "user://test_saves/rating"
	DirAccess.make_dir_recursive_absolute(CampSave.dir)
	for f in DirAccess.get_files_at(CampSave.dir):
		DirAccess.remove_absolute(CampSave.dir + "/" + f)
	(Engine.get_main_loop() as SceneTree).root.add_child(camp)
	await (Engine.get_main_loop() as SceneTree).process_frame
	camp.start_solo(1)
	var why := ""
	var hint: String = camp.ranger_hint("pitches")
	if not camp.clipboard_text("p_rate", "today").contains(hint):
		why = "the Today list should carry the ranger's hint: " + hint
	else:
		var report: String = camp.morning_report(camp.state.day.settle_night())
		if not report.contains(Tuning.text("rating.line") % [1, CampRating.max_stars()]) or not report.contains(hint):
			why = "the morning report should give the stars and the ranger's hint:\n" + report
	camp.stop("")
	await (Engine.get_main_loop() as SceneTree).process_frame
	camp.free()
	CampSave.dir = ""
	return why
