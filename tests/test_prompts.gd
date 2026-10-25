extends RefCounted
## Prompts name the button of the device the player last used, and no string names a button itself.


func test_prompts_follow_the_device() -> String:
	var keys := Prompts.fill(Tuning.text("prompt.pick_up"), false)
	var pad := Prompts.fill(Tuning.text("prompt.pick_up"), true)
	if keys == pad or keys.contains("{") or pad.contains("{"):
		return "pick up prompt: keyboard %s, pad %s" % [keys, pad]
	return ""


func test_every_glyph_exists_for_both_devices() -> String:
	var keyboard: Dictionary = Tuning.value("input", "glyphs.keyboard", {})
	var pad: Dictionary = Tuning.value("input", "glyphs.pad", {})
	var bad: PackedStringArray = []
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for path in _strings(Tuning.table("text"), ""):
		for m in re.search_all(Tuning.text(path)):
			if not (keyboard.has(m.get_string(1)) and pad.has(m.get_string(1))):
				bad.append("%s: {%s}" % [path, m.get_string(1)])
		if Tuning.text(path).to_lower().contains("press a"):
			bad.append(path + " names a button")
	return "" if bad.is_empty() else "glyph missing for one device: " + ", ".join(bad)


func _strings(node: Dictionary, prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in node:
		if node[key] is Dictionary:
			out.append_array(_strings(node[key], prefix + key + "."))
		else:
			out.append(prefix + key)
	return out


## Owner (25 Oct 2026): the DualSense buttons show as drawn icons, not words ("Cross"); keys show as keycaps. Every
## default pad glyph and every button the remap names can show must have an icon file.
func test_prompts_draw_pad_icons_and_keycaps() -> String:
	var pad: Dictionary = Tuning.value("input", "glyphs.pad", {})
	var bad: PackedStringArray = []
	for action: String in pad:
		var rich := Prompts.rich("{%s}" % action, true)
		if not rich.begins_with("[img=") or rich.contains(str(pad[action]).get_slice(" and ", 0) + "[") \
				or rich.contains("Cross") or rich.contains("D-pad"):
			bad.append("%s: %s" % [action, rich])
	for button: String in Tuning.value("settings", "pad_names", {}).values():
		var path := str(Tuning.value("input", "pad_icons." + button, ""))
		if path != "" and not ResourceLoader.exists(path):
			bad.append(button + " has no icon file " + path)
	if not bad.is_empty():
		return "pad prompts should be icons: " + ", ".join(bad)
	var keys := Prompts.rich("{interact}", false)
	if not (keys.contains("[bgcolor=") and keys.contains(str(Tuning.value("input", "glyphs.keyboard.interact")))):
		return "a key should show as a keycap, got " + keys
	if Prompts.rich("{camera}", true).count("[img=") != 2:
		return "a pair of buttons should show two icons, got " + Prompts.rich("{camera}", true)
	return ""
