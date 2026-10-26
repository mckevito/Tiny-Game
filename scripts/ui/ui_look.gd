class_name UiLook
extends RefCounted
## The shared menu look: felt-coloured panels and buttons with a thick, clear focus ring, so the D-pad or the keyboard
## always shows where it is. Sizes and swatches: data/settings.json "look". The fonts (Figtree for reading, Fredoka for
## felt lettering) and the felt lettering's season colours: data/look.json.

## The season the felt lettering is coloured for; "" until a camp sets it (data/look.json "title_season" until then).
static var season := ""
static var _fonts: Dictionary = {}


static func num(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("settings", "look." + key, fallback)


## A font from art/ui/fonts at the weight in data/look.json "fonts": "body" (Figtree) or "felt" (Fredoka).
static func font(which: String) -> Font:
	if not _fonts.has(which):
		var row: Dictionary = Tuning.value("look", "fonts." + which, {})
		var f := FontVariation.new()
		f.base_font = load(str(row.get("file", ""))) as FontFile
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): int(row.get("weight", 400))}
		_fonts[which] = f
	return _fonts[which]


## The felt lettering's colours now: this PC's preset (Options, data/settings.json "colours") in the camp's season.
## {letters: [Color], back, seam: Color, pins: [Color]}.
static func felt_colours() -> Dictionary:
	var preset := str(Settings.value("colours"))
	if not (Tuning.value("look", "presets", {}) as Dictionary).has(preset):
		preset = str(Tuning.value("look", "default", ""))
	var s := season if season != "" else str(Tuning.value("look", "title_season", "autumn"))
	var row: Dictionary = Tuning.value("look", "presets.%s.%s" % [preset, s], {})
	var html := func(list: Array) -> Array: return list.map(func(h: String) -> Color: return Color.html(h))
	return {"letters": html.call(row.get("letters", ["#ffffff"])), "back": Color.html(str(row.get("back", "#000000"))),
			"seam": Color.html(str(row.get("seam", "#ffffff"))), "pins": html.call(row.get("pins", ["#ffffff"]))}


## The camp tells the look its season; felt lettering everywhere recolours when it changes.
static func set_season(s: String) -> void:
	if s != season:
		season = s
		refresh()


## Recolours every felt lettering on screen (a new season or a new preset in Options).
static func refresh() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group("felt_letters", "queue_redraw_all")


static func swatch(key: String) -> Color:
	return FeltBuilder.swatch(str(Tuning.value("settings", "look." + key, "warm_cream")))


static func _box(colour_key: String, edge_key: String, edge_px: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = swatch(colour_key)
	box.border_color = swatch(edge_key)
	box.set_border_width_all(int(edge_px))
	box.set_corner_radius_all(int(num("corner_px", 16)))
	box.set_content_margin_all(num("button_pad_px", 10))
	return box


## A line of text that can show button glyphs (Prompts.rich): wraps at its own width, grows to fit, ignores the
## mouse. `centre` centres it; `font_px` 0 keeps the theme's size.
static func rich_label(centre: bool, font_px: int = 0) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centre:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_px > 0:
		label.add_theme_font_size_override("normal_font_size", font_px)
	return label


## The felt panel behind a menu.
static func panel() -> StyleBoxFlat:
	var box := _box("panel_swatch", "edge_swatch", num("edge_px", 6))
	box.bg_color.a = num("panel_alpha", 0.96)
	box.set_content_margin_all(num("margin_px", 28))
	return box


## The strip behind an Options row while one of its controls has focus.
static func row_focus() -> StyleBoxFlat:
	var box := _box("focus_swatch", "focus_swatch", num("focus_px", 5))
	box.bg_color.a = num("focus_fill_alpha", 0.25)
	box.set_content_margin_all(num("row_pad_px", 4))
	return box


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = int(num("font_px", 28))
	var ink := swatch("ink_swatch")
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(swatch("focus_swatch"), num("focus_fill_alpha", 0.25))
	focus.border_color = swatch("focus_swatch")
	focus.set_border_width_all(int(num("focus_px", 5)))
	focus.set_corner_radius_all(int(num("corner_px", 16)))
	focus.set_expand_margin_all(num("focus_px", 5) * 0.5)
	for type in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", type, _box("button_swatch", "edge_swatch", 2))
		t.set_stylebox("hover", type, _box("hover_swatch", "edge_swatch", 2))
		t.set_stylebox("pressed", type, _box("hover_swatch", "focus_swatch", 2))
		t.set_stylebox("hover_pressed", type, _box("hover_swatch", "focus_swatch", 2))
		var off := _box("button_swatch", "edge_swatch", 2)
		off.bg_color.a = num("disabled_alpha", 0.45)
		t.set_stylebox("disabled", type, off)
		t.set_stylebox("focus", type, focus)
		for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(colour, type, ink)
		t.set_color("font_disabled_color", type, Color(ink, num("disabled_alpha", 0.45)))
	for type in ["HSlider", "LineEdit"]:
		t.set_stylebox("focus", type, focus)
	var track := _box("ink_swatch", "ink_swatch", 0)
	track.set_content_margin_all(num("track_px", 6))
	t.set_stylebox("slider", "HSlider", track)
	var filled := _box("focus_swatch", "focus_swatch", 0)
	filled.set_content_margin_all(num("track_px", 6))
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_color("font_color", "Label", ink)
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("font_placeholder_color", "LineEdit", Color(ink, num("placeholder_alpha", 0.6)))
	t.set_stylebox("normal", "LineEdit", _box("panel_swatch", "edge_swatch", 2))
	t.set_constant("separation", "VBoxContainer", int(num("gap_px", 10)))
	t.set_constant("separation", "HBoxContainer", int(num("gap_px", 10)))
	return t
