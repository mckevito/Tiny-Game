class_name LocalProfile
extends RefCounted
## This PC's player: a random profile ID made once, a name and the last address joined. Kept in user://, never in
## the repo. A character in a camp save belongs to this ID, not to a connection. `which` picks a second profile file,
## so two copies of the game on one PC are two different players (command line: -- --profile=NAME).


static func path(which: String = "") -> String:
	return "user://profile%s.json" % ("" if which == "" else "_" + which.validate_filename())


static func load_or_create(which: String = "") -> Dictionary:
	var data: Variant = null
	if FileAccess.file_exists(path(which)):
		data = JSON.parse_string(FileAccess.get_file_as_string(path(which)))
	if not (data is Dictionary and str(data.get("id", "")).begins_with("p_")):
		data = {"id": new_id(), "name": Tuning.text("profile.default_name"), "last_address": ""}
		save(data, which)
	return data


static func save(profile: Dictionary, which: String = "") -> void:
	var f := FileAccess.open(path(which), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))


static func new_id() -> String:
	return "p_" + Crypto.new().generate_random_bytes(8).hex_encode()
