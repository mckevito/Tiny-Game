class_name ScrapBook
extends PanelContainer
## A player's scrapbook (owner picks, 26 Oct 2026): a felt book with a tab per category across the top, the
## category's pages as small tiles on the left (a page not filled yet is a faded "?"), and the picked page on the
## right, open like a spread: its picture (a player's snapshot taped in like an instant photo, or a knitted picture
## for pages that fill by themselves), its name, its words and who filled it when. Sizes and swatches:
## data/scrapbook.json "book".

var _title := Label.new()
var _tabs := UiLook.rich_label(true)
var _grid := GridContainer.new()
var _tiles: Array[PanelContainer] = []
var _frame := PanelContainer.new()
var _picture := TextureRect.new()
var _blank := Label.new()
var _tape := ColorRect.new()
var _name := Label.new()
var _about := Label.new()
var _footer := Label.new()
var _hint := UiLook.rich_label(true)
var _tile_box: StyleBoxFlat
var _picked_box: StyleBoxFlat


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("scrapbook", "book." + key, fallback)


static func _colour(key: String, fallback: String) -> Color:
	return FeltBuilder.swatch(str(Tuning.value("scrapbook", "book." + key, fallback))).linear_to_srgb()


static func _felt(colour: Color, edge: Color, edge_px: float, margin_px: float, corner_px: float) -> StyleBoxFlat:
	var felt := StyleBoxFlat.new()
	felt.bg_color = colour
	felt.border_color = edge
	felt.set_border_width_all(int(edge_px))
	felt.set_corner_radius_all(int(corner_px))
	felt.set_content_margin_all(margin_px)
	return felt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := _colour("ink_swatch", "ink_brown")
	var paper := _colour("page_swatch", "warm_cream")
	var edge := _colour("edge_swatch", "honey_thread")
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 20))
	theme.set_color("font_color", "Label", ink)
	theme.set_color("default_color", "RichTextLabel", ink)
	add_theme_stylebox_override("panel", _felt(_colour("swatch", "moss_felt"), edge, _n("edge_px", 4) * 2.0,
			_n("margin_px", 22), _n("corner_px", 22)))
	_tile_box = _felt(paper, edge, _n("edge_px", 4), 4, _n("corner_px", 22) * 0.5)
	_picked_box = _felt(paper, _colour("picked_swatch", "rust_canvas"), _n("edge_px", 4) * 1.5, 4, _n("corner_px", 22) * 0.5)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_n("gap_px", 8)))
	add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", int(_n("title_px", 30)))
	_title.add_theme_color_override("font_color", paper)
	box.add_child(_title)
	_tabs.add_theme_font_size_override("normal_font_size", int(_n("tab_px", 20)))
	_tabs.add_theme_color_override("default_color", paper)
	box.add_child(_tabs)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", int(_n("gap_px", 8)) * 2)
	box.add_child(spread)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _felt(paper, edge, _n("edge_px", 4), _n("gap_px", 8) * 1.5, _n("corner_px", 22) * 0.6))
	_grid.columns = int(_n("columns", 4))
	_grid.add_theme_constant_override("h_separation", int(_n("gap_px", 8)))
	_grid.add_theme_constant_override("v_separation", int(_n("gap_px", 8)))
	left.add_child(_grid)
	spread.add_child(left)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _felt(paper, edge, _n("edge_px", 4), _n("gap_px", 8) * 2.0, _n("corner_px", 22) * 0.6))
	right.custom_minimum_size.x = _n("page_w_px", 380)
	spread.add_child(right)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", int(_n("gap_px", 8)))
	right.add_child(page)
	var pic: Array = Tuning.value("scrapbook", "book.picture_px", [320, 240])
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(float(pic[0]), float(pic[1])) + Vector2.ONE * _n("frame_px", 12) * 2.0
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(holder)
	_frame.add_theme_stylebox_override("panel", _felt(Color.WHITE.lerp(paper, 0.3), Color(ink, 0.25), 1,
			_n("frame_px", 12), 3))
	_frame.size = holder.custom_minimum_size
	_frame.pivot_offset = _frame.size * 0.5
	holder.add_child(_frame)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.custom_minimum_size = Vector2(float(pic[0]), float(pic[1]))
	_frame.add_child(_picture)
	_blank.text = Tuning.text("scrap.unknown")
	_blank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_blank.add_theme_font_size_override("font_size", int(_n("blank_px", 96)))
	_blank.modulate.a = _n("unknown_alpha", 0.35)
	_frame.add_child(_blank)
	var tape: Array = Tuning.value("scrapbook", "book.tape_px", [90, 22])
	_tape.color = Color(_colour("tape_swatch", "honey_thread"), 0.8)
	_tape.size = Vector2(float(tape[0]), float(tape[1]))
	_tape.position = Vector2((holder.custom_minimum_size.x - _tape.size.x) * 0.5, -_tape.size.y * 0.4)
	_tape.rotation_degrees = 3.0
	holder.add_child(_tape)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", int(_n("name_px", 26)))
	page.add_child(_name)
	for label: Label in [_about, _footer]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _n("page_w_px", 380) - _n("gap_px", 8) * 4.0
		page.add_child(label)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.add_theme_font_size_override("font_size", int(_n("hint_px", 18)))
	_footer.modulate.a = 0.75
	_hint.add_theme_font_size_override("normal_font_size", int(_n("hint_px", 18)))
	_hint.add_theme_color_override("default_color", paper)
	box.add_child(_hint)


## Puts the book low in the middle of the screen ("centre"), or in the bottom "left" or "right" corner (couch).
func dock(where: String) -> void:
	var at := {"left": 0.0, "centre": 0.5, "right": 1.0}.get(where, 0.5) as float
	var gap := _n("corner_gap_px", 24)
	anchor_left = at
	anchor_right = at
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = {"left": Control.GROW_DIRECTION_END, "right": Control.GROW_DIRECTION_BEGIN}.get(where,
			Control.GROW_DIRECTION_BOTH)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = {"left": gap, "right": -gap}.get(where, 0.0)
	offset_right = offset_left
	offset_top = 0.0
	offset_bottom = -_n("bottom_px", 60) if where == "centre" else -gap


## Shows the book: its title, the category tabs (the open one bright), the category's tiles
## ([{"name", "picture" (Texture2D or null), "known"}]) with `picked` outlined, the picked page
## ({"name", "about", "footer", "picture", "photo"}) and the hint line.
func show_book(title: String, tabs: Array[String], open: int, tiles: Array, picked: int, page: Dictionary,
		hint: String) -> void:
	_title.text = title
	var dim := Color(_colour("page_swatch", "warm_cream"), 0.55).to_html()
	var honey := _colour("tape_swatch", "honey_thread").to_html()
	var parts: PackedStringArray = []
	for i in tabs.size():
		parts.append("[color=#%s][b]%s[/b][/color]" % [honey, tabs[i]] if i == open else "[color=#%s]%s[/color]" % [dim, tabs[i]])
	_tabs.text = "   ·   ".join(parts)
	while _tiles.size() < tiles.size():
		_tiles.append(_make_tile())
	for i in _tiles.size():
		var tile := _tiles[i]
		tile.visible = i < tiles.size()
		if not tile.visible:
			continue
		var row: Dictionary = tiles[i]
		var pic: TextureRect = tile.get_child(0).get_child(0)
		var label: Label = tile.get_child(0).get_child(1)
		var known := bool(row.get("known", false))
		pic.texture = row.get("picture") if known else null
		label.text = str(row.get("name", "")) if known else Tuning.text("scrap.unknown")
		label.add_theme_font_size_override("font_size", int(_n("tile_font_px", 15) if known else _n("tile_px", 96) * 0.4))
		label.size_flags_vertical = Control.SIZE_SHRINK_END if known else Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pic.visible = known
		tile.modulate.a = 1.0 if known or i == picked else _n("unknown_alpha", 0.35)
		tile.add_theme_stylebox_override("panel", _picked_box if i == picked else _tile_box)
	_picture.texture = page.get("picture")
	_blank.visible = page.get("picture") == null
	_frame.rotation_degrees = _n("tilt_deg", -2.5) if bool(page.get("photo", false)) else 0.0
	_tape.visible = bool(page.get("photo", false)) and page.get("picture") != null
	_name.text = str(page.get("name", ""))
	_about.text = str(page.get("about", ""))
	_footer.text = str(page.get("footer", ""))
	_hint.text = hint


func _make_tile() -> PanelContainer:
	var tile := PanelContainer.new()
	var px := _n("tile_px", 96)
	tile.custom_minimum_size = Vector2(px, px)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	tile.add_child(col)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.custom_minimum_size = Vector2(px - 8, px * 0.62)
	col.add_child(pic)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size.x = px - 8
	label.add_theme_font_size_override("font_size", int(_n("tile_font_px", 15)))
	col.add_child(label)
	_grid.add_child(tile)
	return tile


func page_name() -> String:
	return _name.text


func page_picture() -> Texture2D:
	return _picture.texture


func tabs_text() -> String:
	return _tabs.get_parsed_text()


func tile_text(i: int) -> String:
	return (_tiles[i].get_child(0).get_child(1) as Label).text if i < _tiles.size() else ""
