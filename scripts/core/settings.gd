class_name Settings
extends RefCounted
## This PC's settings: picture, window, sound, controls and accessibility. Kept in user://settings.json, never in the
## save and never sent to the other PC, so each PC keeps its own. Rows and defaults: data/settings.json "pages".
## Remapped buttons live under "binds": {action: {"key": key name, "pad": JoyButton number, "drop_key": [second keys
## taken by another action]}}; InputSetup reads them.

## The settings file; tests point it somewhere else so they never touch the real one.
static var file := "user://settings.json"
static var _data: Dictionary = {}
static var _loaded := false


## Every row in data/settings.json, by key.
static func rows() -> Dictionary:
	var out := {}
	for page: Dictionary in Tuning.value("settings", "pages", []):
		for row: Dictionary in page.get("rows", []):
			out[str(row["key"])] = row
	return out


static func default_of(key: String) -> Variant:
	return rows().get(key, {}).get("default")


## Loads the file once (or again with `force`). A missing or broken file means every default.
static func load_file(force := false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	_data = {}
	if FileAccess.file_exists(file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if parsed is Dictionary:
			_data = parsed


static func save() -> void:
	_data["version"] = int(Tuning.num("settings", "version", 1))
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data, "\t"))


## Uses another settings file (tests), starting from what it holds.
static func use_file(path: String) -> void:
	file = path
	load_file(true)


static func value(key: String) -> Variant:
	load_file()
	return _data.get(key, default_of(key))


## True when this PC chose the setting itself (it is in the file).
static func has_value(key: String) -> bool:
	load_file()
	return _data.has(key)


static func num(key: String) -> float:
	var v: Variant = value(key)
	return float(v) if (v is float or v is int) else 0.0


## Sets, saves and applies one setting. A choice must be one of its options and a slider stays inside its range.
static func set_value(key: String, v: Variant) -> void:
	load_file()
	var row: Dictionary = rows().get(key, {})
	match str(row.get("kind", "")):
		"slider":
			v = clampf(snappedf(float(v), float(row.get("step", 1))), float(row.get("min", 0)), float(row.get("max", 100)))
		"toggle":
			v = bool(v)
		"choice":
			if not choices(key).has(v):
				v = row.get("default")
	_data[key] = v
	save()
	apply(key)


## The options of a choice row (picture takes the presets in data/graphics.json).
static func choices(key: String) -> Array:
	var row: Dictionary = rows().get(key, {})
	return Quality.names() if row.get("from", "") == "graphics" else row.get("options", [])


## Puts every row of a page back to its default (the controls page also clears every remap).
static func reset_page(page_id: String) -> void:
	load_file()
	for page: Dictionary in Tuning.value("settings", "pages", []):
		if page.get("id", "") != page_id:
			continue
		for row: Dictionary in page.get("rows", []):
			_data.erase(str(row["key"]))
		if page.get("bindings", false):
			_data.erase("binds")
	save()
	apply_all()


# --- Remapping ---------------------------------------------------------------------------------------------------


## Actions the player can remap: every action in data/input.json except the fixed ones (the dev menu).
static func remappable() -> Array:
	var fixed: Array = Tuning.value("settings", "controls.fixed", [])
	return InputSetup.action_names().filter(func(a: String) -> bool: return not fixed.has(a))


static func binds() -> Dictionary:
	load_file()
	var b: Variant = _data.get("binds", {})
	return b if b is Dictionary else {}


## The action's main binding on a device ("key": a key name, "pad": a JoyButton number), remaps included; null
## when it has none (walking on the pad is the stick).
static func bound(action: String, device: String) -> Variant:
	var row := InputSetup.row(action)
	var list: Array = row.get("keys" if device == "key" else "joy_buttons", [])
	return list[0] if not list.is_empty() else null


## Binds `input` (a key name or a JoyButton number) to `action` on `device`. Another action that used it gets this
## action's old binding, so nothing is left without one. Returns the swapped action, or "".
static func bind(action: String, device: String, input: Variant) -> String:
	var old: Variant = bound(action, device)
	if old == null or old == input:
		return ""
	var swapped := ""
	var all := binds().duplicate(true)
	for other: String in remappable():
		if other == action or not InputSetup.row(other).get("keys" if device == "key" else "joy_buttons", []).has(input):
			continue
		var row: Dictionary = all.get(other, {})
		if bound(other, device) == input:
			swapped = other
			row[device] = old
		else:
			# A second key (the arrow keys for walking) is dropped from the other action instead.
			var drop: Array = row.get("drop_" + device, [])
			drop.append(input)
			row["drop_" + device] = drop
		all[other] = row
	var mine: Dictionary = all.get(action, {})
	mine[device] = input
	if mine.has("drop_" + device):
		mine["drop_" + device].erase(input)
	all[action] = mine
	_data["binds"] = all
	save()
	InputSetup.apply()
	return swapped


## True when a key or pad button can't be taken: the key that stops a remap, and the fixed actions' buttons.
static func reserved(device: String, input: Variant) -> bool:
	if device == "key" and input == Tuning.value("settings", "controls.cancel_key", "Escape"):
		return true
	for action: String in Tuning.value("settings", "controls.fixed", []):
		var row: Dictionary = Tuning.value("input", "actions." + action, {})
		if row.get("keys" if device == "key" else "joy_buttons", []).has(input):
			return true
	return false


## The name of a binding for menus and prompts: the key's name, or the DualSense button's (data/settings.json).
static func input_name(device: String, input: Variant) -> String:
	if input == null:
		return ""
	if device == "key":
		return OS.get_keycode_string(OS.find_keycode_from_string(str(input)))
	return str(Tuning.value("settings", "pad_names.%d" % int(input), "%d" % int(input)))


# --- Applying ----------------------------------------------------------------------------------------------------


static func apply_all() -> void:
	for key: String in rows():
		apply(key)
	InputSetup.apply()


## Applies one setting to the engine. The picture preset is applied by the camp, which owns the views.
static func apply(key: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var windowed := DisplayServer.get_name() != "headless"
	match key:
		"window_mode":
			if windowed:
				DisplayServer.window_set_mode({"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
						"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
						"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN}.get(str(value(key)),
						DisplayServer.WINDOW_MODE_WINDOWED))
		"vsync":
			if windowed:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value(key) else DisplayServer.VSYNC_DISABLED)
		"fps_cap":
			Engine.max_fps = int(num(key))
		"master", "music", "effects", "ambience":
			var bus := bus_index(key)
			AudioServer.set_bus_volume_db(bus, linear_to_db(num(key) / 100.0))
			AudioServer.set_bus_mute(bus, num(key) <= 0.0)
		"stick_deadzone":
			InputSetup.apply()
		"ui_scale":
			if tree:
				tree.root.content_scale_factor = num(key) / 100.0
		"still_trees":
			FeltBuilder.material(true).set_shader_parameter("sway_amount",
					0.0 if value(key) else Tuning.num("art", "felt.sway_amount_m", 0.0))


## The audio bus for a volume row: Master for "master", else the bus named in data/settings.json, made when missing.
static func bus_index(key: String) -> int:
	if key == "master":
		return 0
	var bus_name := str(Tuning.value("settings", "audio_buses." + key, key))
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


## The camera turn speed as a multiplier (Controls, camera turn speed).
static func camera_speed() -> float:
	return num("camera_speed") / 100.0
