class_name DevMenu
extends PanelContainer
## The developer menu: a list of rows from data/dev.json, opened with F1 or the DualSense's Create button by one
## local player (`who`; on the couch, whoever pressed it). Up and down choose a row (W/S, the arrows, the D-pad or the
## left stick), left and right change its value (A/D, the arrows, Q/R, the D-pad or the stick), interact runs it, and
## cancel, the menu button or F1 close it. The mouse works too: point at a row, the wheel changes its value, a click
## runs it. It says what to do through `chose`; the camp runs it (DevTools). Sizes: data/dev.json panel.

signal chose(who: String, id: String, value: Variant)

var camp: Node
## The local player using the menu.
var who := ""
var pick := 0
## Each pick row's chosen value index, by row id (live rows read the camp instead).
var picks := {}
## The fps line stays on after the menu closes; the HUD is hidden (for clean screenshots).
var stats_on := false
var hud_off := false
var pad := false

var _title: Label
var _list: VBoxContainer
var _hint: RichTextLabel
var _buttons: Array[Button] = []
## The stick direction last stepped on each axis (-1, 0 or 1), so one lean is one step.
var _stick := {}


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("dev", "panel." + key, fallback)


func _ready() -> void:
	name = "DevMenu"
	visible = false
	theme = UiLook.theme()
	theme.default_font_size = int(_n("font_px", 24))
	add_theme_stylebox_override("panel", UiLook.panel())
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size.x = _n("width_px", 660)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(_n("row_pad_px", 4)))
	box.add_child(_list)
	for i in DevTools.rows().size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func() -> void: pick = i; refresh())
		b.gui_input.connect(_on_row_mouse.bind(i))
		_list.add_child(b)
		_buttons.append(b)
	_hint = UiLook.rich_label(true, int(_n("font_px", 24)) - 4)
	box.add_child(_hint)


func open(for_who: String, on_pad: bool) -> void:
	who = for_who
	pad = on_pad
	_stick.clear()
	visible = true
	refresh()


func close() -> void:
	visible = false
	who = ""


func row_id(i: int = -1) -> String:
	return str(DevTools.rows()[pick if i < 0 else i]["id"])


## Every value a row can take.
func values(id: String) -> Array:
	match id:
		"hour":
			var out: Array = []
			for h in range(int(Tuning.num("day", "clock.start_hour", 7)), int(Tuning.num("day", "clock.end_hour", 22)) + 1):
				out.append(h)
			return out
		"speed": return (Tuning.value("dev", "speeds", [1]) as Array).map(func(v: Variant) -> int: return int(v))
		"season": return Tuning.value("day", "calendar.seasons", ["spring"])
		"day": return range(1, int(Tuning.num("day", "calendar.days_per_season", 14)) + 1)
		"guest": return Tuning.value("day", "stays.looks", [])
		"item": return (Tuning.value("items", "items", {}) as Dictionary).keys()
		"teleport": return (Tuning.value("dev", "places", {}) as Dictionary).keys()
		"story": return ["fire", "name", "done"]
		"preview": return DevTools.previews() + [""]
		"stats", "hud": return [false, true]
	return []


## The row's value now: live rows and toggles read the camp, other picks remember the last choice.
func current(id: String) -> Variant:
	var vals := values(id)
	if vals.is_empty():
		return null
	var cal: Dictionary = camp.state.camp["calendar"] if camp.state else {}
	match id:
		"hour": return clampi(int(floor(camp.state.day.hour())), int(vals[0]), int(vals[-1])) if camp.state else vals[0]
		"speed": return int(camp.dev_speed)
		"season": return str(cal.get("season", vals[0]))
		"day": return int(cal.get("day", 1))
		"stats": return stats_on
		"hud": return hud_off
	return vals[posmod(int(picks.get(id, 0)), vals.size())]


func value_text(id: String, v: Variant) -> String:
	match id:
		"hour": return camp.time_text(float(v))
		"speed": return Tuning.text("dev.speed") % int(v)
		"season": return Tuning.text("clock.season." + str(v))
		"day": return str(int(v))
		"item": return Tuning.text("dev.item") % [Tuning.text("items." + str(v)), int(Tuning.num("dev", "give_n", 1))]
		"teleport": return Tuning.text("dev.place." + str(v))
		"story": return Tuning.text("dev.story." + str(v))
		"preview": return str(v) if str(v) != "" else Tuning.text("dev.clear")
		"stats", "hud": return Tuning.text("dev.on" if v else "dev.off")
		"coins": return Tuning.text("dev.coins") % int(Tuning.num("dev", "coins_step", 100))
	return str(v)


func refresh() -> void:
	if not visible:
		return
	var p: Dictionary = camp.state.camp["profiles"].get(who, {}) if camp.state else {}
	_title.text = Tuning.text("dev.title") + ("  " + Tuning.text("dev.for") % p["name"] if camp.couch_id != "" and
			not p.is_empty() else "")
	for i in _buttons.size():
		var id := row_id(i)
		var kind := str(DevTools.rows()[i]["kind"])
		var line := Tuning.text("dev.row." + id)
		if kind == "pick" or kind == "toggle":
			line += "   " + Tuning.text("dev.value") % value_text(id, current(id))
		elif id == "coins":
			line += "   " + value_text(id, null)
		_buttons[i].text = line
		if i == pick:
			_buttons[i].add_theme_stylebox_override("normal", theme.get_stylebox("focus", "Button"))
		else:
			_buttons[i].remove_theme_stylebox_override("normal")
	_hint.text = Prompts.rich(Tuning.text("dev.hint"), pad)


## Steps the chosen row's value by `step`; a live row or a toggle says so at once.
func change(step: int) -> void:
	var id := row_id()
	var kind := str(DevTools.rows()[pick]["kind"])
	var vals := values(id)
	if vals.is_empty() or kind == "do":
		return
	var at := vals.find(current(id))
	var next: Variant = vals[posmod((at if at >= 0 else 0) + step, vals.size())]
	picks[id] = vals.find(next)
	if kind == "toggle" or bool(DevTools.rows()[pick].get("live", false)):
		_choose(id, next)
	refresh()


## Runs the chosen row.
func activate() -> void:
	var id := row_id()
	var kind := str(DevTools.rows()[pick]["kind"])
	if kind == "toggle":
		change(1)
	elif kind == "do":
		_choose(id, null)
	else:
		_choose(id, current(id))


func _choose(id: String, value: Variant) -> void:
	if id == "stats":
		stats_on = bool(value)
	elif id == "hud":
		hud_off = bool(value)
	chose.emit(who, id, value)
	refresh()


## Takes a key, button or stick event from the menu's player while it is open; true when the menu used it (it uses
## every press but its own close keys, which the camp handles).
func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		if axis != JOY_AXIS_LEFT_X and axis != JOY_AXIS_LEFT_Y:
			return true
		var v := (event as InputEventJoypadMotion).axis_value
		var dir := 0 if absf(v) < Tuning.num("dev", "stick_deadzone", 0.6) else int(signf(v))
		if dir == int(_stick.get(axis, 0)):
			return true
		_stick[axis] = dir
		if dir != 0:
			if axis == JOY_AXIS_LEFT_Y:
				pick = posmod(pick + dir, _buttons.size())
				refresh()
			else:
				change(dir)
		return true
	if event is InputEventMouseButton:
		return true
	if _pressed(event, ["move_forward", "next_tool"]):
		pick = posmod(pick - 1, _buttons.size())
		refresh()
	elif _pressed(event, ["move_back", "pack"]):
		pick = posmod(pick + 1, _buttons.size())
		refresh()
	elif _pressed(event, ["move_left", "camera_left", "undo"]):
		change(-1)
	elif _pressed(event, ["move_right", "camera_right", "next_kind"]):
		change(1)
	elif event.is_action_pressed("interact"):
		activate()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		return false
	return true


## A press (or a held key's repeat) of any of these actions.
static func _pressed(event: InputEvent, actions: Array) -> bool:
	for a: String in actions:
		if event.is_action_pressed(a, true):
			return true
	return false


func _on_row_mouse(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	pick = i
	match (event as InputEventMouseButton).button_index:
		MOUSE_BUTTON_LEFT: activate()
		MOUSE_BUTTON_WHEEL_UP: change(-1)
		MOUSE_BUTTON_WHEEL_DOWN: change(1)
		_: return
	accept_event()
