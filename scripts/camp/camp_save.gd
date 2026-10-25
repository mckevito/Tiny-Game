class_name CampSave
extends RefCounted
## The camp save: one JSON file per slot with a version number, a backup of the previous save and migrations.
## The layout already has room for the whole year (data/save.json "new_camp"). Profiles are keyed by profile ID.

## Where slots are kept (data/save.json "dir"); tests point it somewhere else.
static var dir := ""


static func version() -> int:
	return int(Tuning.value("save", "version", 1))


static func slot_count() -> int:
	return int(Tuning.value("save", "slots", 3))


static func path(slot: int) -> String:
	var base := dir if dir != "" else str(Tuning.value("save", "dir", "user://saves"))
	return "%s/camp_%d.json" % [base, slot]


## A fresh camp: the whole-year layout plus the starting objects from data/clearing.json "objects".
static func new_camp() -> Dictionary:
	var camp: Dictionary = (Tuning.value("save", "new_camp", {}) as Dictionary).duplicate(true)
	camp["version"] = version()
	var objects: Dictionary = camp.get("objects", {})
	for row: Dictionary in Tuning.table("clearing").get("objects", []):
		var t := Clearing.placement_transform(row)
		objects[str(row["id"])] = {"model": str(row["model"]), "pos": [t.origin.x, t.origin.z],
				"yaw": rad_to_deg(t.basis.get_euler().y)}
	camp["objects"] = objects
	return camp


## A new character for a profile, with the given name and look model.
static func new_profile(display_name: String, look_model: String) -> Dictionary:
	var profile: Dictionary = (Tuning.value("save", "new_profile", {}) as Dictionary).duplicate(true)
	profile["name"] = display_name
	profile["look"]["model"] = look_model
	return profile


## Writes the slot through a temporary file, keeping the previous save as the backup (`.bak`).
static func save(slot: int, camp: Dictionary) -> Error:
	var p := path(slot)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var tmp := FileAccess.open(p + ".tmp", FileAccess.WRITE)
	if tmp == null:
		return FileAccess.get_open_error()
	tmp.store_string(JSON.stringify(camp, "\t"))
	tmp.close()
	if FileAccess.file_exists(p):
		if FileAccess.file_exists(p + ".bak"):
			DirAccess.remove_absolute(p + ".bak")
		DirAccess.rename_absolute(p, p + ".bak")
	return DirAccess.rename_absolute(p + ".tmp", p)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot) + ".bak")


## Reads a slot: {"camp": Dictionary or null, "error": text key or "", "from_backup": bool}. An empty slot gives
## camp null and no error. A broken file falls back to the backup. A save from a newer game is refused, untouched.
static func load_slot(slot: int) -> Dictionary:
	if not exists(slot):
		return {"camp": null, "error": "", "from_backup": false}
	for backup in [false, true]:
		var p := path(slot) + (".bak" if backup else "")
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		if data is Dictionary:
			if int(data.get("version", 0)) > version():
				return {"camp": null, "error": "save.too_new", "from_backup": backup}
			return {"camp": upgrade(data), "error": "", "from_backup": backup}
	return {"camp": null, "error": "save.unreadable", "from_backup": false}


## Brings an older save up to this version: each migration step, then any missing key from the new-camp layout.
static func upgrade(camp: Dictionary) -> Dictionary:
	var from := int(camp.get("version", 0))
	while from < version():
		match from:
			0:
				pass  # Version 0 is a save written before versions existed: filling the defaults is enough.
			1:
				# Stage A gives a new camp its starting coins; a camp that never earned or spent gets them too.
				if int(camp.get("coins", 0)) == 0 and (camp.get("ledger", []) as Array).is_empty():
					camp["coins"] = int(Tuning.value("save", "new_camp.coins", 0))
			4:
				# Round 3: pockets (one item each) become Pack stacks, and the wood pile goes into the camp box.
				for id: String in camp.get("profiles", {}):
					var p: Dictionary = camp["profiles"][id]
					var pack: Array = []
					for item in p.get("pockets", []):
						var found := false
						for s: Dictionary in pack:
							if s["item"] == item:
								s["n"] = int(s["n"]) + 1
								found = true
						if not found:
							pack.append({"item": str(item), "n": 1})
					p["pack"] = pack
					p.erase("pockets")
				if int(camp.get("wood", 0)) > 0:
					camp["box"] = {"wood": int(camp["wood"])}
				camp.erase("wood")
		from += 1
	_fill(camp, Tuning.value("save", "new_camp", {}))
	for id: String in camp["profiles"]:
		_fill(camp["profiles"][id], Tuning.value("save", "new_profile", {}))
	camp["next_object_id"] = int(camp["next_object_id"])
	camp["coins"] = int(camp["coins"])
	camp["last_settled"] = int(camp["last_settled"])
	camp["version"] = version()
	return camp


static func _fill(into: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not into.has(key):
			into[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array \
					else defaults[key]
		elif into[key] is Dictionary and defaults[key] is Dictionary and key != "objects" and key != "profiles":
			_fill(into[key], defaults[key])
