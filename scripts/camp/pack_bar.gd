class_name PackBar
extends VBoxContainer
## A player's Pack along the bottom of the screen: one felt slot per stack (name and count), the picked slot outlined,
## and a hint line under it. Player one's sits bottom centre (bottom left while someone is on the couch); the couch
## player's bottom right. Sizes and colours: data/tuning.json "pack_bar"; the felt look is the report's.

var _row := HBoxContainer.new()
var _hint := Label.new()
var _slots: Array[PanelContainer] = []
var _ok_box: StyleBoxFlat
var _picked_box: StyleBoxFlat


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "pack_bar." + key, fallback)


func _felt(edge_swatch: String, edge_px: float) -> StyleBoxFlat:
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "pack_bar.swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(edge_swatch)
	felt.set_border_width_all(int(edge_px))
	felt.set_corner_radius_all(int(_n("corner_px", 10)))
	felt.set_content_margin_all(_n("margin_px", 6))
	return felt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 20))
	theme.set_color("font_color", "Label", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	_ok_box = _felt(str(Tuning.value("tuning", "pack_bar.edge_swatch", "honey_thread")), _n("edge_px", 3))
	_picked_box = _felt(str(Tuning.value("tuning", "pack_bar.picked_swatch", "rust_canvas")), _n("picked_px", 6))
	_row.add_theme_constant_override("separation", int(_n("gap_px", 6)))
	add_child(_row)
	for i in int(Tuning.num("items", "pack_slots", 8)):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(_n("slot_px", 92), _n("slot_px", 92) * 0.62)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _n("slot_px", 92) - _n("margin_px", 6) * 2.0
		slot.add_child(label)
		_row.add_child(slot)
		_slots.append(slot)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", int(_n("hint_outline_px", 6)))
	add_child(_hint)


## Docks the bar at the bottom: "centre", "left" or "right".
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
	offset_bottom = -_n("bottom_px", 16)


## Shows the slots ([{item, n}]), the picked one outlined, and the hint line.
func show_pack(stacks: Array, picked: int, hint: String) -> void:
	for i in _slots.size():
		var label: Label = _slots[i].get_child(0)
		if i < stacks.size():
			label.text = Tuning.text("pack.slot") % [Tuning.text("items." + str(stacks[i]["item"])), int(stacks[i]["n"])]
		else:
			label.text = ""
		_slots[i].add_theme_stylebox_override("panel", _picked_box if i == picked and i < stacks.size() else _ok_box)
	_hint.text = hint


func slot_text(i: int) -> String:
	return (_slots[i].get_child(0) as Label).text
