extends RefCounted
## Milestone 0: every action has a keyboard or mouse binding and a joypad binding (both inputs are first-class).


func test_every_action_has_both_input_methods() -> String:
	InputSetup.apply()
	var missing: PackedStringArray = []
	var names := InputSetup.action_names()
	if names.is_empty():
		return "data/input.json has no actions"
	for action: String in names:
		var pc := false
		var pad := false
		for ev in InputMap.action_get_events(action):
			pc = pc or ev is InputEventKey or ev is InputEventMouseButton
			pad = pad or ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if not (pc and pad):
			missing.append("%s (keyboard/mouse %s, joypad %s)" % [action, pc, pad])
	return "" if missing.is_empty() else "missing bindings: " + ", ".join(missing)


func test_keys_resolve_to_real_keycodes() -> String:
	var bad: PackedStringArray = []
	var actions: Dictionary = Tuning.table("input").get("actions", {})
	for action: String in actions:
		for key_name: String in actions[action].get("keys", []):
			if OS.find_keycode_from_string(key_name) == KEY_NONE:
				bad.append("%s: %s" % [action, key_name])
	return "" if bad.is_empty() else "unknown key names: " + ", ".join(bad)
