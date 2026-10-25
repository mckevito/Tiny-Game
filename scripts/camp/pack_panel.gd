class_name PackPanel
extends PanelContainer
## A player's Pack, opened with the pack button like Animal Crossing's pockets: a felt grid of slots (each a stack,
## its name and count), the picked slot outlined, and a hint line. It sits low in the middle of its player's half of
## the screen. Sizes and colours: data/tuning.json "pack_panel".

var _title := Label.new()
var _grid := GridContainer.new()
var _hint := Label.new()
var _slots: Array[PanelContainer] = []
var _ok_box: StyleBoxFlat
var _picked_box: StyleBoxFlat


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "pack_panel." + key, fallback)


func _felt(edge_swatch: String, edge_px: float, margin_px: float) -> StyleBoxFlat:
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "pack_panel.swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(edge_swatch)
	felt.set_border_width_all(int(edge_px))
	felt.set_corner_radius_all(int(_n("corner_px", 10)))
	felt.set_content_margin_all(margin_px)
	return felt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 20))
	theme.set_color("font_color", "Label", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	var edge := str(Tuning.value("tuning", "pack_panel.edge_swatch", "honey_thread"))
	add_theme_stylebox_override("panel", _felt(edge, _n("edge_px", 3) * 2.0, _n("panel_margin_px", 18)))
	_ok_box = _felt(edge, _n("edge_px", 3), _n("margin_px", 6))
	_picked_box = _felt(str(Tuning.value("tuning", "pack_panel.picked_swatch", "rust_canvas")), _n("picked_px", 6),
			_n("margin_px", 6))
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
	for i in int(Tuning.num("items", "pack_slots", 8)):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(_n("slot_w_px", 170), _n("slot_h_px", 84))
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _n("slot_w_px", 170) - _n("margin_px", 6) * 2.0
		slot.add_child(label)
		_grid.add_child(slot)
		_slots.append(slot)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = (_n("slot_w_px", 170) + _n("gap_px", 8)) * _grid.columns - _n("gap_px", 8)
	box.add_child(_hint)


## Puts the panel low in the middle of a part of the screen: "centre", "left" or "right" half.
func dock(where: String) -> void:
	var at := {"left": 0.25, "centre": 0.5, "right": 0.75}.get(where, 0.5) as float
	anchor_left = at
	anchor_right = at
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = -_n("bottom_px", 200)


## Shows the title, the slots ([{item, n}]) with the picked one outlined, and the hint line.
func show_pack(title: String, stacks: Array, picked: int, hint: String) -> void:
	_title.text = title
	for i in _slots.size():
		var label: Label = _slots[i].get_child(0)
		if i < stacks.size():
			label.text = Tuning.text("pack.slot_open") % [Tuning.text("items." + str(stacks[i]["item"])), int(stacks[i]["n"])]
		else:
			label.text = ""
		_slots[i].add_theme_stylebox_override("panel", _picked_box if i == picked else _ok_box)
	_hint.text = hint


func slot_text(i: int) -> String:
	return (_slots[i].get_child(0) as Label).text
