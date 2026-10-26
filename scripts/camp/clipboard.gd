class_name Clipboard
extends PanelContainer
## A player's clipboard: a knitted felt board on their side of the screen holding a knitted sheet of paper, with a
## ribbed clip and stitched rules under the writing, and tabs (Today, Bookings, Supplies) that the camera's
## turn buttons flip through. Each player on this PC has their own; it never pauses the game, so the other player plays
## on. The camp fills each tab's text (Camp.clipboard_text). Sizes and colours: data/tuning.json "clipboard"; the knit
## is scripts/ui/knit.gdshader.

const KNIT := preload("res://scripts/ui/knit.gdshader")

## The tab showing now: an index into data/tuning.json clipboard.tabs.
var tab := 0
## A title shown instead of the tab row (the workbench panel uses the clipboard's look), or "".
var heading := ""
var _sheet := PanelContainer.new()
var _head := UiLook.rich_label(false)
var _body := Label.new()
var _hint := UiLook.rich_label(true)


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "clipboard." + key, fallback)


## A clipboard colour (data/tuning.json clipboard.<key>, a palette swatch) as the screen shows it.
static func _colour(key: String, fallback: String) -> Color:
	return FeltBuilder.swatch(str(Tuning.value("tuning", "clipboard." + key, fallback))).linear_to_srgb()


static func tabs() -> Array:
	return Tuning.value("tuning", "clipboard.tabs", ["today"])


static func _knit(key: String) -> ShaderMaterial:
	var knit := ShaderMaterial.new()
	knit.shader = KNIT
	var row: Array = Tuning.value("tuning", "clipboard." + key, [14, 10, 0.2])
	knit.set_shader_parameter("stitch", Vector2(float(row[0]), float(row[1])))
	knit.set_shader_parameter("depth", float(row[2]))
	return knit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 22))
	var board := StyleBoxFlat.new()
	board.bg_color = _colour("board_swatch", "wood_felt")
	board.set_corner_radius_all(int(_n("corner_px", 20)))
	board.set_content_margin_all(_n("board_px", 14))
	board.content_margin_top = _n("board_top_px", 30)
	add_theme_stylebox_override("panel", board)
	material = _knit("knit_board")
	var paper := StyleBoxFlat.new()
	paper.bg_color = _colour("sheet_swatch", "warm_cream")
	paper.set_corner_radius_all(int(_n("sheet_corner_px", 8)))
	paper.set_content_margin_all(_n("margin_px", 22))
	paper.shadow_size = int(_n("sheet_shadow_px", 5))
	paper.shadow_offset = Vector2(0, paper.shadow_size * 0.6)
	paper.shadow_color = Color(_colour("ink_swatch", "ink_brown"), _n("sheet_shadow_alpha", 0.3))
	_sheet.add_theme_stylebox_override("panel", paper)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knit := _knit("knit_sheet")
	knit.set_shader_parameter("rule_color", Color(_colour("rule_swatch", "honey_thread"), _n("rule_alpha", 0.6)))
	knit.set_shader_parameter("rule_width", _n("rule_px", 2))
	knit.set_shader_parameter("rule_dash", _n("rule_dash_px", 10))
	_sheet.material = knit
	_sheet.draw.connect(_draw_clip)
	add_child(_sheet)
	var ink := _colour("ink_swatch", "ink_brown")
	theme.set_color("font_color", "Label", ink)
	theme.set_color("default_color", "RichTextLabel", ink)
	var box := VBoxContainer.new()
	_sheet.add_child(box)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Control in [_head, _body, _hint]:
		label.custom_minimum_size.x = _n("width_px", 544)
		box.add_child(label)


## The knitted clip across the top of the sheet: a ribbed felt bar with a ring, half on the board. It also lines the
## sheet up with the writing: a stitched rule under each line of the page.
func _draw_clip() -> void:
	var size_px: Array = Tuning.value("tuning", "clipboard.clip_size_px", [150, 40])
	var clip := Rect2(Vector2((_sheet.size.x - float(size_px[0])) * 0.5, -float(size_px[1]) * 0.6),
			Vector2(float(size_px[0]), float(size_px[1])))
	var honey := _colour("clip_swatch", "honey_thread")
	var bar := StyleBoxFlat.new()
	bar.bg_color = honey
	bar.set_corner_radius_all(int(clip.size.y * 0.35))
	bar.shadow_size = int(_n("sheet_shadow_px", 5))
	bar.shadow_offset = Vector2(0, bar.shadow_size * 0.6)
	bar.shadow_color = Color(_colour("ink_swatch", "ink_brown"), _n("sheet_shadow_alpha", 0.3))
	var ring := _n("clip_ring_px", 26)
	_sheet.draw_arc(Vector2(clip.get_center().x, clip.position.y), ring * 0.5, PI, TAU, 16, honey.darkened(0.25),
			ring * 0.22, true)
	_sheet.draw_style_box(bar, clip)
	var rib := _n("clip_rib_px", 9)
	var x := clip.position.x + rib
	while x < clip.end.x - rib * 0.5:
		_sheet.draw_line(Vector2(x, clip.position.y + 5), Vector2(x, clip.end.y - 5), honey.darkened(0.18), 2.0, true)
		x += rib
	# The rules follow the page's own lines (data/tuning.json clipboard.rule_*).
	var knit := _sheet.material as ShaderMaterial
	var line_h := float(_body.get_line_height()) + float(_body.get_theme_constant("line_spacing"))
	var top := _body.position.y + (_body.get_parent() as Control).position.y
	var margin := _n("margin_px", 22)
	knit.set_shader_parameter("rule_px", line_h)
	knit.set_shader_parameter("rule_top", top if _body.text != "" else -1.0)
	knit.set_shader_parameter("rule_bottom", top + _body.size.y + 1.0)
	knit.set_shader_parameter("rule_span", Vector2(margin * 0.5, _sheet.size.x - margin * 0.5))


## Puts the panel on the left (player one) or the right (the couch player) of the screen.
func dock(right: bool) -> void:
	var gap := _n("gap_px", 24)
	anchor_left = 1.0 if right else 0.0
	anchor_right = anchor_left
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	offset_left = -gap if right else gap
	offset_right = offset_left
	offset_top = _n("top_px", 110)


## Flips to the next or previous tab, round and round.
func flip(step: int) -> void:
	tab = posmod(tab + step, tabs().size())


func tab_name() -> String:
	return str(tabs()[tab])


## Shows a tab's text: the tab row with the open one marked, the body, and the hint line.
func show_text(body: String, hint: String) -> void:
	if heading != "":
		_head.text = heading
	else:
		var names: PackedStringArray = []
		var ink := _colour("ink_swatch", "ink_brown")
		var dim := Color(ink, _n("tab_dim_alpha", 0.55)).to_html()
		var pad := Tuning.text("glyphs.key_pad")
		for i in tabs().size():
			var label := Tuning.text("clipboard.tab." + str(tabs()[i]))
			if i == tab:
				names.append("[bgcolor=#%s][color=#%s]%s%s%s[/color][/bgcolor]" % [
					_colour("tab_swatch", "honey_thread").to_html(), ink.to_html(), pad, label, pad])
			else:
				names.append("[color=#%s]%s[/color]" % [dim, label])
		_head.text = "   ".join(names)
	_body.text = body
	_hint.text = hint
	_sheet.queue_redraw()


## Puts the top edge at `top` (below the hint or the clock on its side) and keeps the panel above `bottom`: a page too
## long for the room shows as many lines as fit, then the "more" line (text: clipboard.more).
func fit(top: float, bottom: float) -> void:
	offset_top = top
	_body.clip_text = false
	_body.custom_minimum_size.y = 0.0
	var line_h := float(_body.get_line_height()) + float(_body.get_theme_constant("line_spacing"))
	var extra := get_combined_minimum_size().y - _body.get_combined_minimum_size().y
	var room := int(floor((bottom - top - extra) / maxf(line_h, 1.0)))
	if _body.get_line_count() > room:
		# A clipped Label is as tall as its own minimum, so the cut page keeps room for the "more" line.
		_body.clip_text = true
		_body.custom_minimum_size.y = maxi(room - 1, 1) * line_h
		_hint.text = Tuning.text("clipboard.more") + "\n" + _hint.text
	reset_size()


func text() -> String:
	return _body.text
