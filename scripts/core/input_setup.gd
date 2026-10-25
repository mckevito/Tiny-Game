class_name InputSetup
extends RefCounted
## Registers every action in res://data/input.json with its keyboard, mouse and joypad bindings. Both input methods
## are first-class (CLAUDE.md), so each action gets a keyboard or mouse binding and a joypad binding.


static func apply() -> void:
	var table := Tuning.table("input")
	var deadzone := float(table.get("deadzone", 0.2))
	var actions: Dictionary = table.get("actions", {})
	for action: String in actions:
		var row: Dictionary = actions[action]
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, deadzone)
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


## The action names from the table, for tests and menus.
static func action_names() -> Array:
	return Tuning.table("input").get("actions", {}).keys()
