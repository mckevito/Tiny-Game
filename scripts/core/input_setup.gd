class_name InputSetup
extends RefCounted
## Registers every action in res://data/input.json with its keyboard, mouse and joypad bindings, plus this PC's
## remaps and stick deadzone (Settings). Both input methods are first-class (CLAUDE.md), so each action gets a
## keyboard or mouse binding and a joypad binding.


static func apply() -> void:
	var dz := deadzone()
	for action: String in action_names():
		var row := row(action)
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, dz)
		for key_name: String in row.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = OS.find_keycode_from_string(key_name)
			InputMap.action_add_event(action, ev)
		for button: int in row.get("mouse", []):
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
		for button: int in row.get("joy_buttons", []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			ev.device = -1
			InputMap.action_add_event(action, ev)
		for axis_row: Array in row.get("joy_axes", []):
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(axis_row[0])
			ev.axis_value = float(axis_row[1])
			ev.device = -1
			InputMap.action_add_event(action, ev)
	_apply_ui()


## Godot's menu actions (ui_accept, ui_cancel) get the pad buttons of the game actions named in data/input.json "ui",
## replacing any pad buttons from an earlier apply, so a pad presses menu buttons with its own Cross and Circle.
static func _apply_ui() -> void:
	var ui: Dictionary = Tuning.table("input").get("ui", {})
	for ui_action: String in ui:
		if ui_action.begins_with("_") or not InputMap.has_action(ui_action):
			continue
		for ev in InputMap.action_get_events(ui_action):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(ui_action, ev)
		for button: int in row(str(ui[ui_action])).get("joy_buttons", []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			ev.device = -1
			InputMap.action_add_event(ui_action, ev)


## An action's bindings from the table with this PC's remaps on top: a remap replaces the first key or pad button,
## and a second key another action took is left out. Pad buttons come back as whole numbers.
static func row(action: String) -> Dictionary:
	var out: Dictionary = Tuning.value("input", "actions." + action, {}).duplicate(true)
	var remap: Dictionary = Settings.binds().get(action, {})
	for device: String in ["key", "pad"]:
		var field := "keys" if device == "key" else "joy_buttons"
		var list: Array = []
		for input: Variant in out.get(field, []):
			list.append(str(input) if device == "key" else int(input))
		if remap.has(device):
			var mine: Variant = str(remap[device]) if device == "key" else int(remap[device])
			if list.is_empty():
				list.append(mine)
			else:
				list[0] = mine
		for dropped: Variant in remap.get("drop_" + device, []):
			var at := list.find(str(dropped) if device == "key" else int(dropped), 1)
			if at > 0:
				list.remove_at(at)
		if not list.is_empty() or out.has(field):
			out[field] = list
	return out


## How far a stick must move before it counts (0 to 1), from this PC's settings.
static func deadzone() -> float:
	return Settings.num("stick_deadzone") / 100.0


## The action names from the table, for tests and menus.
static func action_names() -> Array:
	return Tuning.table("input").get("actions", {}).keys()
