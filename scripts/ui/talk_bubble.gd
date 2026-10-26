class_name TalkBubble
extends VBoxContainer
## Ranger Burl's speech bubble at the bottom of the screen: a honey name tag over a cream felt bubble, one line at a
## time, with the button that turns to the next line. The camp feeds it lines and turns them (interact), and closes it
## (cancel, or past the last line). With `name_entry` the bubble also holds a line to type a name into (the camp
## sign). Sizes and swatches: data/tuning.json "talk".

var _tag := Label.new()
var _body := UiLook.rich_label(false)
var _hint := UiLook.rich_label(true)
var _entry := LineEdit.new()
var _lines: Array[String] = []
var _at := 0
var _next_hint := ""
var _end_hint := ""


static func _num(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "talk." + key, fallback)


static func _box(swatch: String, corner: float, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FeltBuilder.swatch(str(Tuning.value("tuning", "talk." + swatch, "warm_cream")))
	box.set_corner_radius_all(int(corner))
	box.set_content_margin_all(margin)
	return box


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(_num("tag_overlap_px", -10)))
	var ink := FeltBuilder.swatch(str(Tuning.value("tuning", "talk.ink_swatch", "ink_brown")))
	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.custom_minimum_size.x = _num("tag_inset_px", 28)
	tag_row.add_child(gap)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _box("tag_swatch", _num("tag_corner_px", 14), _num("tag_pad_px", 8)))
	tag.z_index = 1
	_tag.add_theme_font_size_override("font_size", int(_num("tag_font_px", 24)))
	_tag.add_theme_color_override("font_color", ink)
	tag.add_child(_tag)
	tag_row.add_child(tag)
	add_child(tag_row)
	var bubble := PanelContainer.new()
	var felt := _box("bubble_swatch", _num("corner_px", 30), _num("margin_px", 24))
	felt.bg_color.a = _num("alpha", 0.96)
	felt.border_color = FeltBuilder.swatch(str(Tuning.value("tuning", "talk.edge_swatch", "honey_thread")))
	felt.set_border_width_all(int(_num("edge_px", 4)))
	felt.content_margin_top = _num("margin_px", 24) + _num("tag_room_px", 8)
	bubble.add_theme_stylebox_override("panel", felt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_num("gap_px", 10)))
	bubble.add_child(box)
	for label: RichTextLabel in [_body, _hint]:
		label.custom_minimum_size.x = _num("width_px", 860)
		label.add_theme_color_override("default_color", ink)
	_body.add_theme_font_size_override("normal_font_size", int(_num("font_px", 28)))
	_hint.add_theme_font_size_override("normal_font_size", int(_num("hint_font_px", 22)))
	box.add_child(_body)
	_entry.visible = false
	_entry.add_theme_font_size_override("font_size", int(_num("font_px", 28)))
	_entry.max_length = int(Tuning.num("ranger", "name_max", 28))
	_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_entry)
	box.add_child(_hint)
	add_child(bubble)


## Shows `lines` from the first, said by `speaker`. `next_hint` and `end_hint` are the button lines under them.
func say(speaker: String, lines: Array[String], next_hint: String, end_hint: String) -> void:
	_tag.text = speaker
	_lines = lines
	_at = 0
	_next_hint = next_hint
	_end_hint = end_hint
	_entry.visible = false
	visible = not lines.is_empty()
	_show_line()


## Turns to the next line; false past the last one (the camp then closes the bubble).
func next_line() -> bool:
	if _at >= _lines.size() - 1:
		return false
	_at += 1
	_show_line()
	return true


func line() -> String:
	return _lines[_at] if _at < _lines.size() else ""


func on_last_line() -> bool:
	return _at >= _lines.size() - 1


## Asks for a name under `question`, starting from `current`; the keyboard types into it at once.
func ask_name(title: String, question: String, current: String, hint: String) -> void:
	say(title, [question] as Array[String], hint, hint)
	_entry.text = current
	_entry.visible = true
	_entry.grab_focus.call_deferred()
	_entry.select_all.call_deferred()


func asking_name() -> bool:
	return visible and _entry.visible


func typed() -> String:
	return _entry.text


func entry() -> LineEdit:
	return _entry


func close() -> void:
	visible = false
	if _entry.has_focus():
		_entry.release_focus()
	_entry.visible = false


func _show_line() -> void:
	_body.text = line()
	_hint.text = _end_hint if on_last_line() else _next_hint
	reset_size()
	_place.call_deferred()


## Sits at the bottom middle of the screen, data/tuning.json talk.bottom_px above the edge.
func _place() -> void:
	if not is_inside_tree():
		return
	reset_size()
	var screen := get_viewport().get_visible_rect().size
	position = Vector2((screen.x - size.x) * 0.5, screen.y - size.y - _num("bottom_px", 40))
