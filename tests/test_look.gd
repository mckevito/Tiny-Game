extends RefCounted
## The Pinned Felt look (Interface round 6): the felt lettering's colour presets, each a full year of season schemes
## chosen in Options, and the felt lettering that shows them on the title and in Options.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _reset() -> void:
	Settings.set_value("colours", Settings.default_of("colours"))
	UiLook.season = ""


func test_every_preset_has_a_scheme_for_each_season_and_a_name() -> String:
	var presets: Dictionary = Tuning.value("look", "presets", {})
	if presets.size() < 3:
		return "expected at least three presets, got %d" % presets.size()
	if not presets.has(str(Tuning.value("look", "default", ""))):
		return "the default preset is missing"
	for id: String in presets:
		if Tuning.text("options.choice.colours." + id).begins_with("options."):
			return "preset %s has no name in Options" % id
		for season: String in Tuning.value("day", "calendar.seasons", []):
			var row: Dictionary = presets[id].get(season, {})
			if row.is_empty():
				return "preset %s has no %s scheme" % [id, season]
			if (row.get("letters", []) as Array).size() < 2 or (row.get("pins", []) as Array).is_empty():
				return "preset %s %s needs letter and pin colours" % [id, season]
			for hex in row["letters"] + row["pins"] + [row.get("back", ""), row.get("seam", "")]:
				if not Color.html_is_valid(str(hex)):
					return "preset %s %s has a bad colour %s" % [id, season, hex]
	return ""


func test_the_colours_setting_picks_a_preset_and_the_season_picks_its_scheme() -> String:
	_reset()
	if Settings.choices("colours").size() != (Tuning.value("look", "presets", {}) as Dictionary).size():
		return "Options should offer every preset"
	UiLook.set_season("autumn")
	var harvest: Array = UiLook.felt_colours()["letters"]
	if harvest[0] != Color.html(str(Tuning.value("look", "presets.harvest_camp.autumn.letters")[0])):
		return "the default preset in autumn should be Harvest"
	UiLook.set_season("winter")
	if UiLook.felt_colours()["letters"] == harvest:
		return "the letters should change colour when the season turns"
	Settings.set_value("colours", "twilight")
	var twilight: Array = UiLook.felt_colours()["letters"]
	if twilight[0] != Color.html(str(Tuning.value("look", "presets.twilight.winter.letters")[0])):
		return "picking Twilight in winter should give Northern Lights"
	Settings.set_value("colours", "not_a_preset")
	var back: String = str(Settings.value("colours"))
	_reset()
	return "" if back == Settings.default_of("colours") else "an unknown preset should fall back to the default"


func test_felt_lettering_recolours_when_the_season_turns_and_wraps_to_fit() -> String:
	_reset()
	var felt := FeltLetters.new()
	felt.font_px = 56
	felt.text = Tuning.text("menu.title")
	felt.size = Vector2(2000, 10)
	_tree().root.add_child(felt)
	await _tree().process_frame
	var wide := felt.lines().size()
	var tall := felt.custom_minimum_size.y
	felt.size = Vector2(420, 10)
	await _tree().process_frame
	var narrow := felt.lines()
	var redrawn := [false]
	felt.draw.connect(func() -> void: redrawn[0] = true)
	UiLook.set_season("spring")
	await _tree().process_frame
	felt.queue_free()
	_reset()
	if wide != 1:
		return "a wide title should be one line"
	if narrow.size() < 2 or felt.custom_minimum_size.y <= tall:
		return "a narrow title should wrap onto more lines and grow taller"
	if " ".join(narrow) != Tuning.text("menu.title"):
		return "wrapping should keep every word"
	return "" if redrawn[0] else "a new season should redraw the felt lettering"


func test_the_two_fonts_load_and_reading_text_uses_figtree() -> String:
	for which in ["body", "felt"]:
		var f := UiLook.font(which)
		if f == null or (f as FontVariation).base_font == null:
			return "the %s font did not load" % which
	if ThemeDB.fallback_font != UiLook.font("body"):
		return "controls without a theme should read in the body font"
	return "" if UiLook.theme().default_font == UiLook.font("body") else "the menu theme should use the body font"
