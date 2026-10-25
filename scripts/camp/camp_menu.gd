class_name CampMenu
extends PanelContainer
## The start menu (play alone, host, join) and the in-camp menu (back to camp, leave). Works with the keyboard and
## mouse or a pad: buttons take focus, so the D-pad or left stick moves between them and Cross presses.
## Typing a name or an address needs a keyboard; both are remembered for next time. Text: data/text.json "menu"; sizes: data/tuning.json "hud".

signal chose(action: String)

var name_edit := LineEdit.new()
var address_edit := LineEdit.new()
var slot_pick := OptionButton.new()
var status := Label.new()
var _start := VBoxContainer.new()
var _pause := VBoxContainer.new()
var _first_start: Button
var _first_pause: Button


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = int(Tuning.num("tuning", "hud.menu_font_px", 28))
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = Tuning.num("tuning", "hud.menu_width_px", 560)
	add_child(box)
	var title := Label.new()
	title.text = Tuning.text("menu.title")
	title.add_theme_font_size_override("font_size", int(Tuning.num("tuning", "hud.title_font_px", 40)))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_start)
	box.add_child(_pause)
	name_edit.placeholder_text = Tuning.text("menu.name")
	_start.add_child(name_edit)
	for i in CampSave.slot_count():
		slot_pick.add_item(Tuning.text("menu.slot") % (i + 1), i + 1)
	_start.add_child(slot_pick)
	_first_start = _button(_start, "solo")
	_button(_start, "host")
	address_edit.placeholder_text = Tuning.text("menu.address")
	_start.add_child(address_edit)
	_button(_start, "join")
	_first_pause = _button(_pause, "resume")
	_button(_pause, "leave")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _button(parent: Control, action: String) -> Button:
	var b := Button.new()
	b.text = Tuning.text("menu." + action)
	b.pressed.connect(func() -> void: chose.emit(action))
	parent.add_child(b)
	return b


func slot() -> int:
	return slot_pick.get_selected_id()


func show_start(message: String = "") -> void:
	_start.visible = true
	_pause.visible = false
	status.text = message
	status.visible = message != ""
	visible = true
	_fit.call_deferred()
	_first_start.grab_focus.call_deferred()


func show_pause() -> void:
	_start.visible = false
	_pause.visible = true
	status.visible = false
	visible = true
	_fit.call_deferred()
	_first_pause.grab_focus.call_deferred()


## Shrinks the panel to what it shows now and centres it.
func _fit() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
