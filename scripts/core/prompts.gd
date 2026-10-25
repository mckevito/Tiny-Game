class_name Prompts
extends RefCounted
## Fills {action} in a player-facing string with the glyph of the device that player last used
## (data/input.json "glyphs"). Strings never name a button themselves (CLAUDE.md).


static func fill(text: String, pad: bool) -> String:
	var glyphs: Dictionary = Tuning.value("input", "glyphs.pad" if pad else "glyphs.keyboard", {})
	for action: String in glyphs:
		text = text.replace("{%s}" % action, str(glyphs[action]))
	return text


## True when this input event means the player is now using a pad; false for keyboard or mouse; null otherwise.
static func device_of(event: InputEvent) -> Variant:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		return true
	if event is InputEventKey or event is InputEventMouseButton:
		return false
	return null
