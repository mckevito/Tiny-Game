extends RefCounted
## Ranger Burl's story jobs (owner go 26 Oct 2026; data/ranger_jobs.json): one job at a time, given and thanked for in
## person, as rules, from the buttons (with the camera showing him and the player side by side), and on a guest PC.

const DIR := "user://test_saves/jobs"
const OPEN := Vector2(-3.2, 7.9)
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _state() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


## Just south of Ranger Burl, so a player walking up the path talks to him head on.
func _by_ranger() -> Vector2:
	return CampStory.ranger_pos() + Vector2(0.0, 1.2)


func _says(plan: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for part in plan:
		parts.append("%s %s" % [part["say"], CampStory.jobs()[int(part["job"])]["id"]])
	return ", ".join(parts)


func test_burl_gives_one_job_at_a_time_and_thanks_each_in_person() -> String:
	var s := _state()
	if not s.story.has_word() or _says(s.story.talk_plan()) != "ask board":
		return "a camp past the arrival evening should have Burl's first job waiting: " + _says(s.story.talk_plan())
	s.set_player_pos("p_host", Vector2(-8, -8), 0.0)
	if s.story.hear("p_host") != "deny.too_far":
		return "Burl gives his jobs in person"
	s.set_player_pos("p_host", _by_ranger(), 0.0)
	if s.story.hear("p_host") != "" or not s.story.asked() or s.story.has_word():
		return "talking to him should give the camp board job, and the '!' should go"
	if s.story.hear("p_host") != "deny.nothing_new":
		return "with the job not done, he has nothing new"
	var coins := int(s.camp["coins"])
	if s.build.build("p_host", "project_board", OPEN, 0.0) != "":
		return "the camp board should go up at the test spot"
	if not s.story.note("build:project_board") or not s.story.has_word():
		return "putting up the board should finish his job and bring the '!' back"
	if s.build.build("p_host", "pitch", Vector2(3, 5), 0.0) != "":
		return "a pitch should go up by the fire"
	coins = int(s.camp["coins"])
	if _says(s.story.talk_plan()) != "thanks board, ask pitch, thanks pitch, ask guest":
		return "a pitch built before he asks for one should be thanked for at once: " + _says(s.story.talk_plan())
	if s.story.hear("p_host") != "" or int(s.camp["coins"]) != coins + 10 or s.story.thanked != ["board", "pitch"]:
		return "his thanks should pay each job's coins (data/ranger_jobs.json): %d" % (int(s.camp["coins"]) - coins)
	if s.story.job()["id"] != "guest" or not s.story.asked():
		return "after the pitch he should ask them to grant a guest's wish"
	if s.story.note("cook") or s.story.job_have() != 0:
		return "a step that isn't the job's shouldn't count toward it"
	if not s.story.note("give") or not s.story.job_ready():
		return "granting a wish should finish the guest job"
	s.story.hear("p_host")
	s.camp["story"]["job"] = CampStory.jobs().size() - 1
	if s.story.job()["need"] != "stars" or s.story.job_have() != s.rating.stars():
		return "the last job counts the camp's stars"
	s.camp["story"]["job"] = CampStory.jobs().size()
	if s.story.has_word() or not s.story.talk_plan().is_empty() or s.story.hear("p_host") != "deny.nothing_new":
		return "with every job done, Burl goes back to his everyday lines"
	var old := CampSave.new_camp()
	old["story"] = {"step": "done", "given": {}}
	var o := CampState.new(CampSave.upgrade(old))
	if o.story.job_index() != 0 or o.story.asked():
		return "a camp saved before the jobs should start at the first one"
	s.story.begin()
	if s.story.has_word() or not s.story.talk_plan().is_empty():
		return "no job comes before the arrival evening is over"
	return ""


func _camp(side_name: String, profile_id: String, display_name: String) -> Node:
	var side := Node3D.new()
	side.name = side_name
	side.position.x = 200.0 * _sides.size()
	_tree().root.add_child(side)
	_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	_sides.append(side)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": profile_id, "name": display_name, "last_address": ""}
	side.add_child(camp)
	return camp


func _until(check: Callable, frames: int = 600) -> bool:
	for i in frames:
		if check.call():
			return true
		await _tree().process_frame
	return check.call()


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


func _clean() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _stand(camp: Node, who: String, at: Vector2) -> void:
	var c: Camper = camp.campers[who]
	c.position = Vector3(at.x, c.position.y, at.y)
	camp.state.set_player_pos(who, at, 0.0)


func _press(camp: Node, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	camp._unhandled_input(press)


func test_talking_to_burl_from_the_buttons_gives_his_job_and_shows_him() -> String:
	_clean()
	var camp := _camp("Side", "p_host", "Hana")
	var why: String = camp.start_solo(1)
	camp.report.visible = false
	var mark: Label3D = camp.ranger.get_node("Mark")
	await _tree().process_frame
	if why == "" and not mark.visible:
		why = "Burl should show his '!' while his first job waits"
	elif why == "" and not camp.today_lines().contains(Tuning.text("hud.burl_word") % "Burl"):
		why = "the HUD should say Burl would like a word: " + camp.today_lines()
	var stand_yaw: float = camp.ranger.rotation.y
	camp.camera.yaw = 0.0
	if why == "":
		_stand(camp, "p_host", _by_ranger())
		camp.interact("p_host")
		await _tree().process_frame
		if not camp.talk.visible or not camp.talk.line().begins_with(Tuning.text("job.board.ask_1").left(20)):
			why = "talking to him should give the camp board job: " + camp.talk.line()
		elif not camp.state.story.asked() or mark.visible:
			why = "the host should give the job, and the '!' should go"
		elif camp.ranger.model_id != str(Tuning.value("ranger", "talk_model")):
			why = "he should raise his arm while he talks"
	if why == "":
		var side := deg_to_rad(Tuning.num("tuning", "camera.talk_side_deg", 55.0))
		await _until(func() -> bool: return absf(camp.camera.yaw - side) < 0.02, 300)
		if absf(camp.camera.yaw - side) > 0.02:
			why = "head on, the camera should turn until Burl and the player stand side by side: %.2f" % camp.camera.yaw
	if why == "":
		var asks: Array = CampStory.jobs()[0]["ask"]
		for i in asks.size():
			_press(camp, "interact")
		await _until(func() -> bool: return absf(camp.camera.yaw) < 0.02, 300)
		if camp.talk.visible:
			why = "the bubble should close after his last line"
		elif not is_equal_approx(camp.ranger.rotation.y, stand_yaw) or camp.ranger.model_id != str(Tuning.value("ranger", "model")):
			why = "after the talk he should stand as he did, facing data/ranger.json face"
		elif absf(camp.camera.yaw) > 0.02:
			why = "the camera should turn back afterwards: %.2f" % camp.camera.yaw
		elif not camp.today_lines().contains(Tuning.text("job.board.goal")):
			why = "the HUD should show the job he gave: " + camp.today_lines()
	if why == "":
		camp.ask("build", ["project_board", OPEN, 0.0], "p_host")
		await _tree().process_frame
		if not mark.visible:
			why = "with the board up, the '!' should come back"
		elif not camp.morning_report({}).contains((Tuning.text("report.burl_word") % "Burl").left(30)):
			why = "the morning report should open with Burl's word"
	if why == "":
		var coins := int(camp.state.camp["coins"])
		_stand(camp, "p_host", _by_ranger())
		camp.interact("p_host")
		if not camp.talk.line().begins_with(Tuning.text("job.board.thanks").left(20)):
			why = "he should thank them first: " + camp.talk.line()
		elif int(camp.state.camp["coins"]) != coins + int(CampStory.jobs()[0]["coins"]):
			why = "his thanks should pay the job's coins"
		elif camp.state.story.job()["id"] != "pitch":
			why = "then he should give the pitch job"
		_press(camp, "cancel")
	if why == "":
		var reopened := CampSave.load_slot(1)
		if int(reopened["camp"]["story"].get("job", 0)) != 1 or not bool(reopened["camp"]["story"].get("asked", false)):
			why = "his jobs should be saved"
	await _done()
	return why


func test_the_guest_pc_takes_a_job_and_the_host_sees_burl_talk() -> String:
	_clean()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24753)
	host.report.visible = false
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24753)
	if not await _until(func() -> bool: return guest.state != null and host.campers.size() == 2):
		why = "the guest never got in"
	if why == "":
		guest.report.visible = false
		_stand(guest, "p_guest", _by_ranger())
		await _until(func() -> bool: return host.state.player_pos("p_guest").distance_to(_by_ranger()) < 0.1)
		guest.interact("p_guest")
		if not guest.talk.visible:
			why = "the guest should hear Burl's job"
		elif not await _until(func() -> bool: return host.state.story.asked() and guest.state.story.asked()):
			why = "the guest's talk should give the job through the host"
		elif not await _until(func() -> bool: return host.ranger.model_id == str(Tuning.value("ranger", "talk_model"))):
			why = "the host PC should see Burl talk to the guest"
		elif not await _until(func() -> bool: return not guest.ranger.get_node("Mark").visible):
			why = "the '!' should go on the guest PC"
	if why == "":
		_press(guest, "cancel")
		if not await _until(func() -> bool: return host.ranger.model_id == str(Tuning.value("ranger", "model"))):
			why = "the host PC should see him stand again when the talk ends"
	await _done()
	return why
