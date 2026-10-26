class_name OptionsScreen
extends VBoxContainer
## The one Options screen, opened from the title and from the in-camp menu: tabs for picture, sound, controls and
## accessibility, built from data/settings.json "pages". Every change is saved and applied at once, on this PC only
## (Settings), except the window and picture rows (apply_on_button): those wait for Apply, and leaving Options without
## it puts them back. The controls tab remaps each action on the keyboard and on the controller: choose the button, then press
## the new key or button (a clash swaps the two). Works with the mouse, the keyboard and the D-pad; focus always shows.
## Text: data/text.json "options"; sizes: data/settings.json "look".

signal closed
## The picture preset changed; the camp applies it to its views.
signal picture_changed(preset: String)

var status := Label.new()
var _tabs := HBoxContainer.new()
var _scroll := ScrollContainer.new()
var _body := VBoxContainer.new()
var _page := ""
## The remap waiting for a key or button: {action, device, left}; empty when none.
var _waiting: Dictionary = {}
var _bind_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
## Changes waiting for Apply: key -> the value in use before them.
var _before: Dictionary = {}
var _apply := Button.new()


func _ready() -> void:
	custom_minimum_size.x = UiLook.num("options_width_px", 1040)
	var title := FeltLetters.new()
	title.pins = false
	title.font_px = int(UiLook.num("felt_heading_font_px", 56))
	title.text = Tuning.text("options.title")
	add_child(title)
	add_child(_tabs)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	for page: Dictionary in Tuning.value("settings", "pages", []):
		var id := str(page["id"])
		var b := Button.new()
		b.text = Tuning.text("options.tab." + id)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func() -> void: open(id))
		_tabs.add_child(b)
		_tab_buttons[id] = b
	_scroll.custom_minimum_size.y = UiLook.num("options_height_px", 560)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	add_child(_scroll)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = UiLook.num("options_width_px", 1040)
	add_child(status)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_apply.text = Tuning.text("options.apply")
	_apply.disabled = true
	_apply.pressed.connect(apply_changes)
	foot.add_child(_apply)
	var reset := Button.new()
	reset.text = Tuning.text("options.reset")
	reset.pressed.connect(_reset)
	foot.add_child(reset)
	var back := Button.new()
	back.text = Tuning.text("options.back")
	back.pressed.connect(close)
	foot.add_child(back)
	add_child(foot)


## Shows a tab ("" keeps the last one, or the first) and puts focus on its first setting.
func open(page_id: String = "") -> void:
	var pages: Array = Tuning.value("settings", "pages", [])
	if page_id == "" or not _tab_buttons.has(page_id):
		page_id = _page if _page != "" else str(pages[0]["id"])
	_page = page_id
	_tab_buttons[page_id].button_pressed = true
	_waiting = {}
	status.text = ""
	_build()
	var first := _first_focus()
	if first:
		first.grab_focus.call_deferred()


func page() -> String:
	return _page


func waiting() -> bool:
	return not _waiting.is_empty()


func close() -> void:
	_waiting = {}
	for key: String in _before:
		Settings.set_value(key, _before[key], false)
	_before = {}
	_apply.disabled = true
	closed.emit()


## Saves a change: at once, or waiting for Apply for the window and picture rows.
func change(key: String, v: Variant) -> void:
	if not Settings.apply_on_button().has(key):
		Settings.set_value(key, v)
		return
	if not _before.has(key):
		_before[key] = Settings.value(key)
	Settings.set_value(key, v, false)
	if Settings.value(key) == _before[key]:
		_before.erase(key)
	_apply.disabled = _before.is_empty()
	status.text = Tuning.text("options.not_applied") if not _before.is_empty() else ""


## Applies the waiting changes.
func apply_changes() -> void:
	for key: String in _before:
		Settings.apply(key)
		if key == "picture":
			picture_changed.emit(str(Settings.value(key)))
	_before = {}
	_apply.disabled = true
	status.text = Tuning.text("options.applied")


func pending() -> Array:
	return _before.keys()


func _reset() -> void:
	# A reset applies everything at once (Settings.reset_page), so nothing waits for Apply after it.
	_before = {}
	_apply.disabled = true
	Settings.reset_page(_page)
	if _page == "picture":
		picture_changed.emit(str(Settings.value("picture")))
	open(_page)


func _first_focus() -> Control:
	for strip in _body.get_children():
		for c in strip.get_child(0).get_children():
			if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and not (c is Button and c.disabled):
				return c
	return _tab_buttons.get(_page)


func _build() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_bind_buttons = {}
	for page: Dictionary in Tuning.value("settings", "pages", []):
		if page["id"] != _page:
			continue
		for row: Dictionary in page.get("rows", []):
			_add_row(row)
		if page.get("bindings", false):
			_add_bindings()
	_light_rows()


## One row: a label and its controls, on a felt strip that lights up while any of its controls has focus (a slider
## draws no focus ring of its own).
func _line(label_text: String) -> HBoxContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = UiLook.num("label_width_px", 420)
	line.add_child(label)
	strip.add_child(line)
	_body.add_child(strip)
	return line


func _light_rows() -> void:
	for strip: PanelContainer in _body.get_children():
		for c in strip.get_child(0).get_children():
			if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE:
				c.focus_entered.connect(func() -> void: strip.add_theme_stylebox_override("panel", UiLook.row_focus()))
				c.focus_exited.connect(func() -> void: strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new()))


func _add_row(row: Dictionary) -> void:
	var key := str(row["key"])
	var line := _line(Tuning.text("options.row." + key))
	var width := UiLook.num("control_width_px", 420)
	match str(row["kind"]):
		"toggle":
			var flip := Button.new()
			flip.custom_minimum_size.x = width
			flip.text = _toggle_text(key)
			flip.pressed.connect(func() -> void:
				change(key, not bool(Settings.value(key)))
				flip.text = _toggle_text(key))
			flip.gui_input.connect(func(event: InputEvent) -> void:
				if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
					change(key, event.is_action_pressed("ui_right"))
					flip.text = _toggle_text(key)
					flip.accept_event())
			line.add_child(flip)
		"slider":
			var slider := HSlider.new()
			slider.min_value = float(row.get("min", 0))
			slider.max_value = float(row.get("max", 100))
			slider.step = float(row.get("step", 1))
			slider.value = Settings.num(key)
			slider.custom_minimum_size.x = width
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.focus_mode = Control.FOCUS_ALL
			var shown := Label.new()
			shown.text = Tuning.text("options.percent") % roundi(slider.value)
			slider.value_changed.connect(func(v: float) -> void:
				change(key, v)
				shown.text = Tuning.text("options.percent") % roundi(v))
			line.add_child(slider)
			line.add_child(shown)
		"choice":
			var pick := Button.new()
			pick.custom_minimum_size.x = width
			pick.name = key
			pick.text = _choice_text(key)
			pick.pressed.connect(func() -> void: step_choice(key, 1, pick))
			pick.gui_input.connect(func(event: InputEvent) -> void:
				if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
					step_choice(key, -1 if event.is_action_pressed("ui_left") else 1, pick)
					pick.accept_event())
			line.add_child(pick)


func _toggle_text(key: String) -> String:
	return Tuning.text("options.choice_shown") % Tuning.text("options.on" if Settings.value(key) else "options.off")


func _choice_text(key: String) -> String:
	var v: Variant = Settings.value(key)
	var label := Tuning.text("quality." + str(v)) if Settings.rows()[key].get("from", "") == "graphics" \
			else Tuning.text("options.choice.%s.%s" % [key, str(v) if not (v is float) else str(int(v))])
	return Tuning.text("options.choice_shown") % label


## Moves a choice one option on (or back), wrapping round.
func step_choice(key: String, by: int, shown: Button = null) -> void:
	var all := Settings.choices(key)
	var at := all.find(Settings.value(key))
	change(key, all[posmod(at + by, all.size())])
	if shown:
		shown.text = _choice_text(key)


func _add_bindings() -> void:
	var head := _line("")
	for device_text in ["options.keyboard", "options.controller"]:
		var h := Label.new()
		h.text = Tuning.text(device_text)
		h.custom_minimum_size.x = UiLook.num("bind_width_px", 260)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(h)
	for action: String in Settings.remappable():
		var line := _line(Tuning.text("options.action." + action))
		for device: String in ["key", "pad"]:
			var b := Button.new()
			b.custom_minimum_size.x = UiLook.num("bind_width_px", 260)
			var input: Variant = Settings.bound(action, device)
			if input == null:
				b.text = Tuning.text("options.stick")
				b.disabled = true
				b.focus_mode = Control.FOCUS_NONE
			else:
				b.text = Settings.input_name(device, input)
				b.pressed.connect(func() -> void: listen(action, device))
			_bind_buttons[action + ":" + device] = b
			line.add_child(b)


## The button that remaps `action` on `device` ("key" or "pad"), for tests.
func bind_button(action: String, device: String) -> Button:
	return _bind_buttons.get(action + ":" + device)


## Waits for the next key (or pad button) to bind to the action.
func listen(action: String, device: String) -> void:
	_waiting = {"action": action, "device": device, "left": Tuning.num("settings", "controls.wait_s", 6.0)}
	bind_button(action, device).text = Tuning.text("options.press_key" if device == "key" else "options.press_button")
	status.text = Tuning.text("options.wait_key") % Settings.input_name("key", Tuning.value("settings", "controls.cancel_key")) \
			if device == "key" else Tuning.text("options.wait_button")


func _process(delta: float) -> void:
	if _waiting.is_empty():
		return
	_waiting["left"] = float(_waiting["left"]) - delta
	if float(_waiting["left"]) <= 0.0:
		_stop_listening("")


func _stop_listening(message: String) -> void:
	var focus := [str(_waiting.get("action", "")), str(_waiting.get("device", ""))]
	_waiting = {}
	_build()
	status.text = message
	var b := bind_button(focus[0], focus[1])
	if b:
		b.grab_focus.call_deferred()


## While a remap waits, the next press is the new binding: a key for the keyboard column, a pad button for the
## controller column. The stop key, a click or the other device's press keeps the old one.
func _input(event: InputEvent) -> void:
	if _waiting.is_empty() or not is_visible_in_tree():
		return
	var device := str(_waiting["device"])
	var input: Variant = null
	if event is InputEventKey and event.pressed and not event.echo:
		var key_name := OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		input = key_name if device == "key" and key_name != Tuning.value("settings", "controls.cancel_key") else false
	elif event is InputEventJoypadButton and event.pressed:
		input = int(event.button_index) if device == "pad" else false
	elif event is InputEventMouseButton and event.pressed:
		input = false
	else:
		return
	get_viewport().set_input_as_handled()
	if input is bool:
		_stop_listening("")
	else:
		rebind(str(_waiting["action"]), device, input)


## Binds and reports what happened (a swap, a kept button, or nothing to say).
func rebind(action: String, device: String, input: Variant) -> void:
	if Settings.reserved(device, input):
		_stop_listening(Tuning.text("options.reserved") % Settings.input_name(device, input))
		return
	var swapped := Settings.bind(action, device, input)
	_stop_listening("" if swapped == "" else Tuning.text("options.swapped") % [Tuning.text("options.action." + swapped),
			Settings.input_name(device, Settings.bound(swapped, device))])


## Back closes the screen (cancel on either device), unless a remap is waiting.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _waiting.is_empty():
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
