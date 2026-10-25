class_name CampMenu
extends PanelContainer
## Every menu page in one felt panel over the clearing: the title (start game, options, controls, quit), the start
## page (play alone, host, join, with an optional link code), the in-camp menu (back to camp, ready for bed, the
## booking board (Stage B), Players, options, leave, or hop off the couch for a couch player), the Players page (which
## device each player on this PC uses, chosen by pressing a button on it) and the one Options screen
## (OptionsScreen), which the title and the in-camp menu both open. Works with the keyboard and mouse or a pad:
## buttons take focus (a clear ring shows it), so the D-pad or left stick moves between them, Cross presses and
## cancel goes back a page. Typing a name or an address needs a keyboard; both are remembered for next time.
## Text: data/text.json "menu" and "title"; sizes and look: data/tuning.json "hud", data/settings.json "look".

signal chose(action: String)

var name_edit := LineEdit.new()
var address_edit := LineEdit.new()
var link_edit := LineEdit.new()
var slot_pick := OptionButton.new()
var status := Label.new()
var options := OptionsScreen.new()
var _heading := Label.new()
var _tagline := Label.new()
var _title := VBoxContainer.new()
var _start := VBoxContainer.new()
var _pause := VBoxContainer.new()
var _players := VBoxContainer.new()
var _first_players: Button
var _players_couch: Array[Button] = []
var _first_title: Button
var _first_start: Button
var _first_pause: Button
var _leave: Button
var _leave_couch: Button
var _sleep: Button
## Stage B's booking board: accept, a day later, decline (shown while a booking can be changed).
var _booking: Array[Button] = []
## The page Options goes back to ("title" or "pause"), and the in-camp text to show again there.
var _options_from := "title"
var _pause_info := ""
var _pause_couch := false


func _ready() -> void:
	theme = UiLook.theme()
	add_theme_stylebox_override("panel", UiLook.panel())
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = Tuning.num("tuning", "hud.menu_width_px", 560)
	add_child(box)
	_heading.text = Tuning.text("menu.title")
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_heading)
	_tagline.text = Tuning.text("title.tagline")
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.add_theme_font_size_override("font_size", int(UiLook.num("tagline_font_px", 26)))
	box.add_child(_tagline)
	for page in [_title, _start, _pause, _players, options]:
		box.add_child(page)
	_first_title = _page_button(_title, "title.start", show_start.bind(""))
	_page_button(_title, "title.options", show_options.bind("", "title"))
	_page_button(_title, "title.controls", show_options.bind("controls", "title"))
	_page_button(_title, "title.quit", func() -> void: get_tree().quit())
	name_edit.placeholder_text = Tuning.text("menu.name")
	_start.add_child(name_edit)
	for i in CampSave.slot_count():
		slot_pick.add_item(Tuning.text("menu.slot") % (i + 1), i + 1)
	_start.add_child(slot_pick)
	_first_start = _button(_start, "solo")
	_button(_start, "host")
	address_edit.placeholder_text = Tuning.text("menu.address")
	_start.add_child(address_edit)
	link_edit.placeholder_text = Tuning.text("menu.link_code")
	_start.add_child(link_edit)
	_button(_start, "join")
	_page_button(_start, "title.back", show_title)
	_first_pause = _button(_pause, "resume")
	_sleep = _button(_pause, "sleep")
	for choice in ["booking_accept", "booking_later", "booking_decline"]:
		_booking.append(_button(_pause, choice))
	_button(_pause, "players")
	_page_button(_pause, "title.options", func() -> void: show_options("", "pause"))
	_leave = _button(_pause, "leave")
	_leave_couch = _button(_pause, "leave_couch")
	_first_players = _button(_players, "players_p1")
	_button(_players, "players_p2")
	_players_couch.append(_button(_players, "players_swap"))
	_players_couch.append(_button(_players, "players_nobody"))
	_page_button(_players, "title.back", func() -> void: show_pause(_pause_couch, _pause_info))
	options.closed.connect(_options_closed)
	options.picture_changed.connect(func(_preset: String) -> void: chose.emit("picture"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = Tuning.num("tuning", "hud.menu_width_px", 560)
	box.add_child(status)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _button(parent: Control, action: String) -> Button:
	var b := Button.new()
	b.text = Tuning.text("menu." + action)
	b.pressed.connect(func() -> void: chose.emit(action))
	parent.add_child(b)
	return b


## A button that moves between pages inside the menu (the camp is not told).
func _page_button(parent: Control, text_key: String, go: Callable) -> Button:
	var b := Button.new()
	b.text = Tuning.text(text_key)
	b.pressed.connect(go)
	parent.add_child(b)
	return b


## The camp slot picked on the start page (1 to the slot count).
func slot() -> int:
	return slot_pick.get_selected_id()


## The page showing now: "title", "start", "pause", "players" or "options".
func page() -> String:
	for p: Array in [[_title, "title"], [_start, "start"], [_pause, "pause"], [_players, "players"],
			[options, "options"]]:
		if p[0].visible:
			return p[1]
	return ""


func _show(which: Control, message: String, focus: Control) -> void:
	for p in [_title, _start, _pause, _players, options]:
		p.visible = p == which
	var big := which == _title
	_heading.add_theme_font_size_override("font_size", int(UiLook.num("title_font_px", 56)) if big
			else int(Tuning.num("tuning", "hud.title_font_px", 40)))
	_heading.visible = which != options
	_tagline.visible = big
	status.text = message
	status.visible = message != ""
	visible = true
	_fit.call_deferred()
	if focus:
		focus.grab_focus.call_deferred()


## The landing page: start game, options, controls, quit.
func show_title() -> void:
	_show(_title, "", _first_title)


func show_start(message: String = "") -> void:
	_show(_start, message, _first_start)


## The in-camp menu. A couch player gets "hop off the couch" instead of "leave camp"; `info` is shown below
## (link codes of couch characters).
func show_pause(couch_player: bool = false, info: String = "") -> void:
	_pause_couch = couch_player
	_pause_info = info
	_leave.visible = not couch_player
	_leave_couch.visible = couch_player
	_show(_pause, info, _first_pause)


## The Players page: `info` says which device each player has; swap and "nobody" show only with a couch player.
func show_players(info: String, couch_on: bool) -> void:
	for b in _players_couch:
		b.visible = couch_on
	var keep := get_viewport().gui_get_focus_owner() if is_inside_tree() and _players.visible else null
	_show(_players, info, keep if keep and keep.visible and _players.is_ancestor_of(keep) else _first_players)


## The Options screen at a tab ("" for the last one); back returns to `from` ("title" or "pause").
func show_options(tab: String = "", from: String = "") -> void:
	if from != "":
		_options_from = from
	_show(options, "", null)
	options.open(tab)
	_fit.call_deferred()


func _options_closed() -> void:
	if _options_from == "pause":
		show_pause(_pause_couch, _pause_info)
	else:
		show_title()


## Cancel on the start page goes back to the title (Options handles its own; the camp closes the in-camp menu).
func _unhandled_input(event: InputEvent) -> void:
	if visible and (_start.visible or _players.visible) \
			and (event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _players.visible:
			show_pause(_pause_couch, _pause_info)
		else:
			show_title()


## The bed button: "Ready for bed", "Not ready for bed yet", or greyed out before the evening with `closed_text`.
## The bed button: open all day (owner: sleep the day away whenever you like); before the evening it reads
## `early_text`.
func set_sleep(evening: bool, ready: bool, early_text: String) -> void:
	var open := evening
	var closed_text := early_text
	_sleep.disabled = false
	_sleep.text = Tuning.text("menu.not_sleep") if ready else (Tuning.text("menu.sleep") if open else closed_text)


## The booking board buttons for the booking on the board: its state ("offered", "accepted", or "" for none).
func set_booking(state: String) -> void:
	_booking[0].visible = state == "offered"
	_booking[1].visible = state in ["offered", "accepted"]
	_booking[2].visible = state in ["offered", "accepted"]


## Shrinks the panel to what it shows now and centres it, scaled down when it would not fit the screen (a big
## interface size, a short window; data/tuning.json hud.menu_margin_px).
func _fit() -> void:
	scale = Vector2.ONE
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var room := get_viewport_rect().size - Vector2.ONE * Tuning.num("tuning", "hud.menu_margin_px", 24.0) * 2.0
	var k := minf(1.0, minf(room.x / size.x, room.y / size.y))
	pivot_offset = size / 2.0
	scale = Vector2(k, k)
