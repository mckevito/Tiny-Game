class_name Prompts
extends RefCounted
## Fills {action} in a player-facing string with the glyph of the device that player last used
## (data/input.json "glyphs"). Strings never name a button themselves (CLAUDE.md). A button this PC remapped
## (Settings) shows its new name instead; "move" and "camera" are built from their actions (data/settings.json
## "glyph_parts"). `fill` gives words ("Cross"); `rich` gives the same as BBCode for a RichTextLabel, with a drawn
## icon for each controller button (data/input.json "pad_icons", art/ui/glyphs/) and a felt keycap for each key
## (data/tuning.json "glyphs").


static func fill(text: String, pad: bool) -> String:
	var glyphs: Dictionary = Tuning.value("input", "glyphs.pad" if pad else "glyphs.keyboard", {})
	for action: String in glyphs:
		if text.contains("{%s}" % action):
			text = text.replace("{%s}" % action, glyph(action, pad, str(glyphs[action])))
	return text


## Like `fill`, but as BBCode with button icons and keycaps (show it in a RichTextLabel with bbcode_enabled).
static func rich(text: String, pad: bool, paper := false) -> String:
	var glyphs: Dictionary = Tuning.value("input", "glyphs.pad" if pad else "glyphs.keyboard", {})
	for action: String in glyphs:
		if text.contains("{%s}" % action):
			text = text.replace("{%s}" % action, icons(glyph(action, pad, str(glyphs[action])), pad, paper))
	return text


## One glyph's words ("L1 and R1", "WASD", "Q/E") as BBCode: an icon for each pad button the table knows, a keycap
## for each key, and anything else as plain words.
static func icons(words: String, pad: bool, paper := false) -> String:
	var pair := Tuning.text("options.glyph_pair") % ["", ""]
	var parts: PackedStringArray = []
	for name in words.replace(pair, "/").split("/"):
		parts.append(_icon(name) if pad else _keycap(name, paper))
	return Tuning.text("glyphs.join").join(parts)


static func _icon(name: String) -> String:
	var path := str(Tuning.value("input", "pad_icons." + name, ""))
	if path == "" or not ResourceLoader.exists(path):
		return name
	var tex: Texture2D = load(path)
	var h := Tuning.num("tuning", "glyphs.icon_px", 34.0)
	return "[img=%dx%d]%s[/img]" % [roundi(h * tex.get_width() / maxf(tex.get_height(), 1.0)), roundi(h), path]


## A key's cap: cream over the world (glyphs.key_swatch), honey on a cream panel or sheet (glyphs.paper_key_swatch).
static func _keycap(name: String, paper := false) -> String:
	var face_key := "glyphs.paper_key_swatch" if paper else "glyphs.key_swatch"
	var face := Color(FeltBuilder.swatch(str(Tuning.value("tuning", face_key, "warm_cream"))).linear_to_srgb())
	var ink := Color(FeltBuilder.swatch(str(Tuning.value("tuning", "glyphs.key_ink_swatch", "ink_brown"))).linear_to_srgb())
	# A one-letter key gets wider padding (text: glyphs.key_pad_one), so a thin letter such as I still reads as a key.
	var pad := Tuning.text("glyphs.key_pad_one" if name.length() == 1 else "glyphs.key_pad")
	return "[bgcolor=#%s][color=#%s][outline_size=0]%s%s%s[/outline_size][/color][/bgcolor]" % [face.to_html(),
			ink.to_html(), pad, name, pad]


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
