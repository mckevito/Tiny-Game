class_name CampReport
extends PanelContainer
## Stage B's morning report: a panel after the night with what the camp earned, each departing guest's line, the
## bookings and the day's three goals. Either player closes it with interact, cancel or the menu button (the camp
## handles the buttons). A report too tall for the screen splits into pages that interact turns, the last page closing
## it. Sizes and felt colours: data/tuning.json "hud" report_*.

var _body := Label.new()
var _hint := UiLook.rich_label(true)
var _pages: PackedStringArray = []
var _page := 0
var _text := ""
var _close_hint := ""
var _next_hint := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = int(Tuning.num("tuning", "hud.report_font_px", 26))
	var felt := StyleBoxFlat.new()
	felt.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_swatch", "warm_cream")))
	felt.bg_color.a = Tuning.num("tuning", "hud.report_alpha", 0.95)
	felt.border_color = FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_edge_swatch", "honey_thread")))
	felt.set_border_width_all(int(Tuning.num("tuning", "hud.report_edge_px", 6)))
	felt.set_corner_radius_all(int(Tuning.num("tuning", "hud.report_corner_px", 18)))
	felt.set_content_margin_all(Tuning.num("tuning", "hud.report_margin_px", 28))
	add_theme_stylebox_override("panel", felt)
	theme.set_color("font_color", "Label", FeltBuilder.swatch(str(Tuning.value("tuning", "hud.report_ink_swatch", "ink_brown"))))
	theme.set_color("default_color", "RichTextLabel", theme.get_color("font_color", "Label"))
	var box := VBoxContainer.new()
	add_child(box)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = Tuning.num("tuning", "hud.report_width_px", 980)
	box.add_child(_body)
	_hint.custom_minimum_size.x = _body.custom_minimum_size.x
	box.add_child(_hint)


## The whole report, every page.
func text() -> String:
	return _text


## `hint` closes it; `next_hint` (with a %d of %d for the page) turns to the next page of a long report.
func show_report(body: String, hint: String, next_hint: String = "") -> void:
	_text = body
	_close_hint = hint
	_next_hint = next_hint
	_pages = [body]
	_page = 0
	_body.text = body
	_hint.text = hint
	visible = true
	_fit.call_deferred()


func page_count() -> int:
	return _pages.size()


## Turns to the next page; false on the last page (the camp then closes the report).
func next_page() -> bool:
	if _page >= _pages.size() - 1:
		return false
	_page += 1
	_show_page()
	return true


func _show_page() -> void:
	_body.text = _pages[_page]
	var last := _page >= _pages.size() - 1
	_hint.text = _close_hint if last or _next_hint == "" else _next_hint % [_page + 1, _pages.size()]
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Splits the report into pages that fit the screen (hud.report_gap_px from its top and bottom), whole lines at a time.
func _fit() -> void:
	if not is_inside_tree():
		return
	var room := get_viewport().get_visible_rect().size.y - 2.0 * Tuning.num("tuning", "hud.report_gap_px", 24.0)
	_body.size.x = _body.custom_minimum_size.x
	_hint.text = _next_hint % [1, 9] if _next_hint != "" else _close_hint
	_body.text = ""
	var extra := get_combined_minimum_size().y - _body.get_combined_minimum_size().y
	var line_h := float(_body.get_line_height()) + float(_body.get_theme_constant("line_spacing"))
	var most := maxi(int(floor((room - extra) / maxf(line_h, 1.0))), 1)
	_pages = []
	var page := ""
	for line in _text.split("\n"):
		var more := line if page == "" else page + "\n" + line
		_body.text = more
		if page != "" and _body.get_line_count() > most:
			_pages.append(page)
			page = line
		else:
			page = more
	_pages.append(page)
	_page = 0
	_show_page()
