class_name PackPanel
extends PanelContainer
## A player's Pack, opened with the pack button like Animal Crossing's pockets: a felt grid of rounded slots, each
## with a felt token coloured by the item's kind (fish, meal, fruit, plant, material), its name and a count in the
## corner; the picked slot is outlined and a name tag under the grid says what it is and what it is for, then a hint
## line. Alone it sits low in the middle of the screen; with a couch player each Pack opens in its player's bottom
## corner, where the dock was. Sizes and colours: data/tuning.json "pack_panel".

var _title := Label.new()
var _grid := GridContainer.new()
var _tag := Label.new()
var _hint := UiLook.rich_label(true)
var _slots: Array[PanelContainer] = []
var _ok_box: StyleBoxFlat
var _picked_box: StyleBoxFlat
var _empty_box: StyleBoxFlat


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "pack_panel." + key, fallback)


static func _felt(swatch: String, edge_swatch: String, edge_px: float, margin_px: float, corner_px: float,
		alpha: float) -> StyleBoxFlat:
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(swatch)
	felt.bg_color.a = alpha
	felt.border_color = FeltBuilder.swatch(edge_swatch)
	felt.set_border_width_all(int(edge_px))
	felt.set_corner_radius_all(int(corner_px))
	felt.set_content_margin_all(margin_px)
	return felt


## The token colour for an item: its kind's swatch (data/items.json items.<item>.kind, tuning pack_panel.kind_swatch),
## as the palette shows it (FeltBuilder.swatch gives the linear colour the 3D shader wants, darker on a 2D panel).
static func token_color(item: String) -> Color:
	var kind := str(Tuning.value("items", "items.%s.kind" % item, ""))
	return FeltBuilder.swatch(str(Tuning.value("tuning", "pack_panel.kind_swatch." + kind, "stone_grey"))).linear_to_srgb()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 20))
	theme.set_color("font_color", "Label", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	theme.set_color("default_color", "RichTextLabel", theme.get_color("font_color", "Label"))
	var cream := str(Tuning.value("tuning", "pack_panel.swatch", "warm_cream"))
	var edge := str(Tuning.value("tuning", "pack_panel.edge_swatch", "honey_thread"))
	var alpha := Tuning.num("tuning", "hud.report_alpha", 0.95)
	add_theme_stylebox_override("panel", _felt(cream, edge, _n("edge_px", 3) * 2.0, _n("panel_margin_px", 18),
			_n("panel_corner_px", 18), alpha))
	_ok_box = _felt(cream, edge, _n("edge_px", 3), _n("margin_px", 6), _n("corner_px", 24), alpha)
	_picked_box = _felt(cream, str(Tuning.value("tuning", "pack_panel.picked_swatch", "rust_canvas")),
			_n("picked_px", 6), _n("margin_px", 6), _n("corner_px", 24), alpha)
	_empty_box = _felt(cream, edge, _n("edge_px", 3), _n("margin_px", 6), _n("corner_px", 24), _n("empty_alpha", 0.5))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_n("gap_px", 8)))
	add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", int(_n("title_px", 26)))
	box.add_child(_title)
	_grid.columns = int(_n("columns", 4))
	_grid.add_theme_constant_override("h_separation", int(_n("gap_px", 8)))
	_grid.add_theme_constant_override("v_separation", int(_n("gap_px", 8)))
	box.add_child(_grid)
	var inner := _n("slot_px", 128) - _n("margin_px", 6) * 2.0
	for i in int(Tuning.num("items", "pack_slots", 8)):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(_n("slot_px", 128), _n("slot_px", 128))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		slot.add_child(col)
		var token := Panel.new()
		token.name = "Token"
		token.custom_minimum_size = Vector2.ONE * _n("token_px", 34)
		token.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var dot := StyleBoxFlat.new()
		dot.set_corner_radius_all(int(_n("token_px", 34) * 0.5))
		token.add_theme_stylebox_override("panel", dot)
		col.add_child(token)
		var label := Label.new()
		label.name = "Name"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = inner
		label.add_theme_font_size_override("font_size", int(_n("name_px", 18)))
		col.add_child(label)
		var count := Label.new()
		count.name = "Count"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", int(_n("count_px", 18)))
		col.add_child(count)
		_grid.add_child(slot)
		_slots.append(slot)
	var wide := (_n("slot_px", 128) + _n("gap_px", 8)) * _grid.columns - _n("gap_px", 8)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Control in [_tag, _hint]:
		label.custom_minimum_size.x = wide
		box.add_child(label)
	_tag.add_theme_font_size_override("font_size", int(_n("tag_px", 21)))


## Puts the panel low in the middle of the screen ("centre"), or in the bottom "left" or "right" corner (couch).
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
	offset_bottom = -_n("bottom_px", 200) if where == "centre" else -gap


## Shows the title, the slots ([{item, n}]) with the picked one outlined and named on the tag, and the hint line.
func show_pack(title: String, stacks: Array, picked: int, hint: String) -> void:
	_title.text = title
	for i in _slots.size():
		var slot := _slots[i]
		var token: Panel = slot.get_child(0).get_child(0)
		var name_label: Label = slot.get_child(0).get_child(1)
		var count: Label = slot.get_child(0).get_child(2)
		if i < stacks.size():
			var item := str(stacks[i]["item"])
			name_label.text = Tuning.text("items." + item)
			count.text = Tuning.text("pack.count") % int(stacks[i]["n"])
			(token.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = token_color(item)
			token.modulate.a = 1.0
		else:
			name_label.text = ""
			count.text = ""
			token.modulate.a = 0.0
		slot.add_theme_stylebox_override("panel", _picked_box if i == picked else (_ok_box if i < stacks.size() else _empty_box))
	if picked >= 0 and picked < stacks.size():
		var item := str(stacks[picked]["item"])
		var name := Tuning.text("items." + item)
		_tag.text = Tuning.text("pack.tag") % [name.left(1).to_upper() + name.substr(1), int(stacks[picked]["n"]),
				Tuning.text("pack.about." + str(Tuning.value("items", "items.%s.kind" % item, "")))]
	else:
		_tag.text = Tuning.text("pack.tag_empty")
	_hint.text = hint


## A slot's name and count, as one line.
func slot_text(i: int) -> String:
	var col := _slots[i].get_child(0)
	return "%s %s" % [(col.get_child(1) as Label).text, (col.get_child(2) as Label).text]


func tag_text() -> String:
	return _tag.text
