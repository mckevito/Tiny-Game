class_name Clipboard
extends PanelContainer
## A player's clipboard: a felt panel on their side of the screen with tabs (Today, Bookings, Supplies) that the
## camera's turn buttons flip through. Each player on this PC has their own; it never pauses the game, so the other
## player plays on. The camp fills each tab's text (Camp.clipboard_text). Sizes and colours: data/tuning.json
## "clipboard"; the felt look is the morning report's (hud report_*).

## The tab showing now: an index into data/tuning.json clipboard.tabs.
var tab := 0
## A title shown instead of the tab row (the workbench panel uses the clipboard's look), or "".
var heading := ""
var _head := Label.new()
var _body := Label.new()
var _hint := Label.new()


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "clipboard." + key, fallback)


static func tabs() -> Array:
	return Tuning.value("tuning", "clipboard.tabs", ["today"])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(_n("font_px", 22))
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "clipboard.swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(str(Tuning.value("tuning", "clipboard.edge_swatch", "honey_thread")))
	felt.set_border_width_all(int(_n("edge_px", 6)))
	felt.border_width_top = int(_n("clip_px", 18))
	felt.set_corner_radius_all(int(Tuning.num("tuning", "hud.report_corner_px", 18)))
	felt.set_content_margin_all(_n("margin_px", 22))
	add_theme_stylebox_override("panel", felt)
	theme.set_color("font_color", "Label", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	var box := VBoxContainer.new()
	add_child(box)
	for label in [_head, _body, _hint]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _n("width_px", 560)
		box.add_child(label)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


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
		_body.text = body
		_hint.text = hint
		return
	var names: PackedStringArray = []
	for i in tabs().size():
		var label := Tuning.text("clipboard.tab." + str(tabs()[i]))
		names.append(Tuning.text("clipboard.open_tab") % label if i == tab else label)
	_head.text = "   ".join(names)
	_body.text = body
	_hint.text = hint


func text() -> String:
	return _body.text
