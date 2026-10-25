class_name Prompts
extends RefCounted
## Fills {action} in a player-facing string with the glyph of the device that player last used
## (data/input.json "glyphs"). Strings never name a button themselves (CLAUDE.md). A button this PC remapped
## (Settings) shows its new name instead; "move" and "camera" are built from their actions (data/settings.json
## "glyph_parts").


static func fill(text: String, pad: bool) -> String:
	var glyphs: Dictionary = Tuning.value("input", "glyphs.pad" if pad else "glyphs.keyboard", {})
	for action: String in glyphs:
		if text.contains("{%s}" % action):
			text = text.replace("{%s}" % action, glyph(action, pad, str(glyphs[action])))
	return text


## The glyph for one {name}: the table's, unless this PC remapped the action (or one of its parts).
static func glyph(name: String, pad: bool, table_glyph: String) -> String:
	var device := "pad" if pad else "key"
	var parts: Array = Tuning.value("settings", "glyph_parts." + name, [name])
	var remapped := false
	for part: String in parts:
		remapped = remapped or Settings.binds().get(part, {}).has(device)
	if not remapped:
		return table_glyph
	var names: PackedStringArray = []
	for part: String in parts:
		names.append(Settings.input_name(device, Settings.bound(part, device)))
	if names.size() == 2:
		return Tuning.text("options.glyph_pair") % [names[0], names[1]]
	var short := true
	for n in names:
		short = short and n.length() == 1
	return "".join(names) if short else "/".join(names)


## True when this input event means the player is now using a pad; false for keyboard or mouse; null otherwise.
static func device_of(event: InputEvent) -> Variant:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		return true
	if event is InputEventKey or event is InputEventMouseButton:
		return false
	return null
