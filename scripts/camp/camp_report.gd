class_name CampReport
extends PanelContainer
## Stage B's morning report: a panel after the night with what the camp earned, each departing guest's line, the
## bookings and the day's three goals. Either player closes it with interact, cancel or the menu button (the camp
## handles the buttons). Sizes and felt colours: data/tuning.json "hud" report_*.

var _body := Label.new()
var _hint := Label.new()


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
	var box := VBoxContainer.new()
	add_child(box)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = Tuning.num("tuning", "hud.report_width_px", 980)
	box.add_child(_body)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)


func text() -> String:
	return _body.text


func show_report(body: String, hint: String) -> void:
	_body.text = body
	_hint.text = hint
	visible = true
	_fit.call_deferred()


func _fit() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
