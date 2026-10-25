extends RefCounted
## Milestone 2: the camp save has room for the whole year, keeps a backup, upgrades older saves and refuses newer ones.

const DIR := "user://test_saves/save"


func _fresh() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _done() -> void:
	CampSave.dir = ""


func test_new_camp_has_room_for_the_whole_year() -> String:
	var camp := CampSave.new_camp()
	var missing: PackedStringArray = []
	for key in ["version", "calendar", "coins", "box", "kit", "bundles", "ledger", "reservations", "areas", "staff", "visitors",
			"rating", "journal", "mailbox", "objects", "next_object_id", "profiles"]:
		if not camp.has(key):
			missing.append(key)
	if not missing.is_empty():
		return "new camp is missing " + ", ".join(missing)
	if not (camp["calendar"].has("day") and camp["calendar"].has("season") and camp["calendar"].has("year")):
		return "the calendar needs year, season and day"
	if camp["areas"].size() != 5 or camp["staff"].size() != 3:
		return "the plan has five areas and three staff roles, got %d and %d" % [camp["areas"].size(), camp["staff"].size()]
	var who := CampSave.new_profile("Hana", "camper_a")
	for key in ["name", "look", "outfit", "outfits", "pet", "pack", "pos", "link_code"]:
		if not who.has(key):
			return "a new profile is missing " + key
	if not camp["objects"].has("chair_teal_1"):
		return "the starting chairs from data/clearing.json are not in a new camp"
	return ""


func test_slots_round_trip_and_stay_separate() -> String:
	_fresh()
	var camp := CampSave.new_camp()
	camp["coins"] = 42
	camp["profiles"]["p_test"] = CampSave.new_profile("Hana", "camper_b")
	CampSave.save(2, camp)
	var back := CampSave.load_slot(2)
	var one := CampSave.load_slot(1)
	_done()
	if back["camp"] == null:
		return "slot 2 did not load: " + str(back["error"])
	if int(back["camp"]["coins"]) != 42 or back["camp"]["profiles"]["p_test"]["look"]["model"] != "camper_b":
		return "slot 2 came back different"
	return "" if one["camp"] == null and one["error"] == "" else "slot 1 should be empty"


func test_a_broken_save_falls_back_to_the_backup() -> String:
	_fresh()
	var camp := CampSave.new_camp()
	camp["wood"] = 7
	CampSave.save(1, camp)
	camp["wood"] = 9
	CampSave.save(1, camp)
	var f := FileAccess.open(CampSave.path(1), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var back := CampSave.load_slot(1)
	_done()
	if back["camp"] == null or not back["from_backup"]:
		return "the backup was not used"
	return "" if int(back["camp"]["wood"]) == 7 else "the backup should hold the previous save"


func test_an_older_save_gets_the_new_fields() -> String:
	var old := {"coins": 5, "profiles": {"p_old": {"name": "Gus", "look": {"model": "camper_b"}}}, "objects": {}}
	var camp := CampSave.upgrade(old)
	if int(camp["version"]) != CampSave.version():
		return "the version was not raised"
	if not (camp.has("reservations") and camp["profiles"]["p_old"].has("pet")):
		return "missing fields were not filled from data/save.json"
	return "" if int(camp["coins"]) == 5 and camp["profiles"]["p_old"]["look"]["model"] == "camper_b" \
			else "upgrading changed what was already saved"


func test_a_newer_save_is_refused_and_kept() -> String:
	_fresh()
	var camp := CampSave.new_camp()
	camp["version"] = CampSave.version() + 1
	var f := FileAccess.open(CampSave.path(3), FileAccess.WRITE)
	f.store_string(JSON.stringify(camp))
	f.close()
	var back := CampSave.load_slot(3)
	var still := FileAccess.file_exists(CampSave.path(3))
	_done()
	return "" if back["camp"] == null and back["error"] == "save.too_new" and still else "a newer save was not refused"
