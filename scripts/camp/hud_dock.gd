class_name HudDock
extends VBoxContainer
## A player's corner dock, like Animal Crossing's: the tool in hand and the build piece picked, each on a felt chip
## with a row of dots for where it sits in its cycle, and a Pack line under them. Player one's sits bottom right
## (bottom left while someone is on the couch); the couch player's bottom right. Sizes and colours: data/tuning.json
## "dock".

var _tool_caption := Label.new()
var _tool := Label.new()
var _tool_dots := Label.new()
var _build_caption := Label.new()
var _build := Label.new()
var _build_dots := Label.new()
var _pack := Label.new()


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "dock." + key, fallback)


func _caption(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(_n("caption_px", 19)))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", int(_n("outline_px", 6)))
	add_child(label)


func _chip(label: Label, dots: Label) -> void:
	var chip := PanelContainer.new()
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "dock.swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(str(Tuning.value("tuning", "dock.edge_swatch", "rust_canvas")))
	felt.set_border_width_all(int(_n("edge_px", 4)))
	felt.set_corner_radius_all(int(_n("corner_px", 12)))
	chip.add_theme_stylebox_override("panel", felt)
	chip.custom_minimum_size = Vector2(_n("width_px", 320), _n("chip_h_px", 50))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(_n("font_px", 24)))
	box.add_child(label)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override("font_size", int(_n("caption_px", 19)))
	box.add_child(dots)
	for l: Label in [label, dots]:
		l.add_theme_color_override("font_color", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	add_child(chip)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(_n("row_gap_px", 4)))
	_caption(_tool_caption)
	_chip(_tool, _tool_dots)
	_caption(_build_caption)
	_chip(_build, _build_dots)
	_caption(_pack)


## Docks in the bottom right corner, or the bottom left with `left`.
func dock(left: bool) -> void:
	var gap := _n("gap_px", 24)
	anchor_left = 0.0 if left else 1.0
	anchor_right = anchor_left
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = gap if left else -gap
	offset_right = offset_left
	offset_top = -gap
	offset_bottom = -gap


static func dots(count: int, at: int) -> String:
	var out: PackedStringArray = []
	for i in count:
		out.append(Tuning.text("dock.dot" if i == at else "dock.dot_off"))
	return " ".join(out)


## Shows the tool in hand and the build piece (names, each with its place among `*_count`), the captions and the
## Pack line.
func show_dock(tool_name: String, tool_at: int, tool_count: int, piece: String, piece_at: int, piece_count: int,
		captions: Array[String]) -> void:
	_tool.text = tool_name
	_tool_dots.text = dots(tool_count, tool_at)
	_build.text = piece
	_build_dots.text = dots(piece_count, piece_at)
	_tool_caption.text = captions[0]
	_build_caption.text = captions[1]
	_pack.text = captions[2]


func tool_text() -> String:
	return _tool.text


func piece_text() -> String:
	return _build.text
