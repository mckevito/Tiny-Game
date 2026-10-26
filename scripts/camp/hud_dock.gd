class_name HudDock
extends VBoxContainer
## A player's corner dock, like Animal Crossing's: the tool in hand and the build piece picked, each on a felt chip
## that shows the one before and the one after it either side (smaller and faded, so the player sees what the next
## press brings) and a row of dots for where it sits in its cycle, with a Pack line under them, and above them the
## player's legend: icons for what they can do now (Camp.legend). On the couch the player's own prompt sits on top
## (show_prompt). Player one's sits bottom right (bottom left while someone is on the couch); the couch player's bottom
## right. Sizes and colours: data/tuning.json "dock".

var _prompt := UiLook.rich_label(true)
var _legend := UiLook.rich_label(true)
var _tool_caption := UiLook.rich_label(true)
var _tool_chip: Control
var _placing := false
var _tool := Label.new()
var _tool_prev := Label.new()
var _tool_next := Label.new()
var _tool_dots := Label.new()
var _build_caption := UiLook.rich_label(true)
var _build := Label.new()
var _build_prev := Label.new()
var _build_next := Label.new()
var _build_dots := Label.new()
var _pack := UiLook.rich_label(true)


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "dock." + key, fallback)


func _caption(label: RichTextLabel) -> void:
	label.add_theme_font_size_override("normal_font_size", int(_n("caption_px", 19)))
	label.add_theme_color_override("default_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", int(_n("outline_px", 6)))
	add_child(label)


func _chip(label: Label, prev: Label, next: Label, dots: Label) -> Control:
	var chip := PanelContainer.new()
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "dock.swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(str(Tuning.value("tuning", "dock.edge_swatch", "rust_canvas")))
	felt.set_border_width_all(int(_n("edge_px", 4)))
	felt.set_corner_radius_all(int(_n("corner_px", 12)))
	felt.content_margin_left = _n("side_px", 10)
	felt.content_margin_right = _n("side_px", 10)
	chip.add_theme_stylebox_override("panel", felt)
	chip.custom_minimum_size = Vector2(_n("width_px", 320), _n("chip_h_px", 50))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_n("row_gap_px", 4)))
	box.add_child(row)
	var ink := FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown")))
	var faded := ink
	faded.a = _n("near_alpha", 0.5)
	for l: Label in [prev, label, next]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.add_theme_color_override("font_color", faded)
		l.add_theme_font_size_override("font_size", int(_n("near_px", 17)))
		row.add_child(l)
	prev.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_stretch_ratio = _n("centre_share", 2.0)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_size_override("font_size", int(_n("font_px", 24)))
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override("font_size", int(_n("caption_px", 19)))
	dots.add_theme_color_override("font_color", ink)
	box.add_child(dots)
	add_child(chip)
	return chip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(_n("row_gap_px", 4)))
	_caption(_prompt)
	_prompt.add_theme_font_size_override("normal_font_size", int(_n("prompt_px", 22)))
	_prompt.custom_minimum_size.x = _n("width_px", 320)
	_prompt.visible = false
	_caption(_legend)
	_legend.custom_minimum_size.x = _n("width_px", 320)
	_legend.add_theme_constant_override("line_separation", int(_n("legend_gap_px", 6)))
	_caption(_tool_caption)
	_tool_chip = _chip(_tool, _tool_prev, _tool_next, _tool_dots)
	_caption(_build_caption)
	_chip(_build, _build_prev, _build_next, _build_dots)
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


## Shows the tool in hand and the build piece (each a list of names and the place of the one in hand; the piece in
## hand shows as `piece_label`, which adds how many the kit holds), the captions and the Pack line. The names either
## side are the previous and next ones, round the cycle (only the next with two, none with one). Captions: the tool,
## build and Pack lines, then the legend.
func show_dock(tool_names: Array[String], tool_at: int, piece_names: Array[String], piece_at: int,
		piece_label: String, captions: Array[String]) -> void:
	_cycle(_tool, _tool_prev, _tool_next, _tool_dots, tool_names, tool_at)
	_cycle(_build, _build_prev, _build_next, _build_dots, piece_names, piece_at)
	_build.text = piece_label
	_tool_caption.text = captions[0]
	_build_caption.text = captions[1]
	_pack.text = captions[2]
	_legend.text = captions[3] if captions.size() > 3 else ""
	_fit()


## The couch: each player's prompt shows on their own dock, not in the shared column, so two prompts never squeeze
## between the docks (Playtest, PR #47). To keep the dock no taller, a prompt takes the legend's place while walking,
## and while `placing` (build mode) the tool row steps aside instead, so the build buttons stay in the legend.
func show_prompt(text: String, placing: bool) -> void:
	_prompt.text = text
	_placing = placing
	_fit()


func _fit() -> void:
	_prompt.visible = _prompt.text != ""
	_legend.visible = _legend.text != "" and (_placing or not _prompt.visible)
	_tool_caption.visible = not _placing
	_tool_chip.visible = not _placing


func prompt_text() -> String:
	return _prompt.text


static func _cycle(label: Label, prev: Label, next: Label, dots_label: Label, names: Array[String], at: int) -> void:
	var n := names.size()
	at = posmod(at, maxi(n, 1))
	label.text = names[at] if n > 0 else ""
	prev.text = Tuning.text("dock.prev") % names[posmod(at - 1, n)] if n > 2 else ""
	next.text = Tuning.text("dock.next") % names[posmod(at + 1, n)] if n > 1 else ""
	dots_label.text = dots(n, at)


func legend_text() -> String:
	return _legend.text


func tool_text() -> String:
	return _tool.text


func piece_text() -> String:
	return _build.text


## The text either side of the tool in hand: [previous, next] (data/text.json dock.prev, dock.next).
func tool_near() -> Array[String]:
	return [_tool_prev.text, _tool_next.text]
