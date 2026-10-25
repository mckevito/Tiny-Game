extends RefCounted
## The interface's layout on a 16:9 screen: with a couch player on the same PC (two docks, two clipboards, two Packs,
## the workbench) nothing runs off the screen, nothing covers anything else, and each player's panels stay on their
## own side. The HUD is as full as play makes it: three guests' wishes, odd jobs, three toasts and two prompt lines.

const DIR := "user://test_saves/hud"
const MENU_BUTTON := 6
const SCREEN := Vector2i(1920, 1080)
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _fresh() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _camp(side_name: String, profile_id: String, display_name: String) -> Node:
	var side := Node3D.new()
	side.name = side_name
	side.position.x = 200.0 * _sides.size()
	_tree().root.add_child(side)
	_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	_sides.append(side)
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	camp.profile = {"id": profile_id, "name": display_name, "last_address": ""}
	side.add_child(camp)
	return camp


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _done() -> void:
	for side in _sides:
		var camp: Node = side.get_child(0)
		if camp.state != null:
			camp.stop("")
	await _tree().process_frame
	for side in _sides:
		_tree().set_multiplayer(null, side.get_path())
		side.free()
	_sides.clear()
	CampSave.dir = ""


func _pad_button(device: int, button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = true
	return ev


func _stick(device: int) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 1.0
	return ev


## A solo camp at 1920 x 1080 with a second controller dropped in, the players far apart (split), and the HUD as full
## as play makes it.
func _full_couch() -> Node:
	_fresh()
	_tree().root.size = SCREEN
	var camp := _camp("HudSide", "p_host", "Hana")
	camp.start_solo(1)
	camp._input(_stick(0))
	camp._input(_pad_button(1, MENU_BUTTON))
	var s: CampState = camp.state
	camp.campers[camp.couch_id].position = Vector3(12, 0, 6)
	# Three guests with a wish each (no pitch, so nobody walks in) and a full Pack for both.
	var wishes := ["fish", "meal", "chair"]
	for i in wishes.size():
		s.camp["stays"]["hud_%d" % i] = {"name": "Guest %d" % i, "pitch": "", "look": "camper_a",
				"request": {"kind": wishes[i], "done": false}}
	var cap := int(Tuning.num("items", "stack_max"))
	for who in camp.local_ids():
		for item in ["grilled_sunfish", "grilled_perch", "grilled_trout", "berries", "sapling", "stick", "wood", "sunfish"]:
			s.pack.add(who, item, cap)
	# Evening, so the bed line shows under the prompts, and both players building, so each has a prompt line.
	s.camp["calendar"]["minute"] = (Tuning.num("day", "clock.evening_hour") + 1.0 - Tuning.num("day", "clock.start_hour")) * 60.0
	for who in camp.local_ids():
		camp.toggle_build(who)
	for i in 4:
		camp._toast(Tuning.text("toast.crafted") % ["Hana", Tuning.text("build.lantern_post")])
	# The F1 fps line too (playtest: it sat over the clock).
	camp.get_node("Hud/Dev").visible = true
	return camp


## Every visible HUD piece of the couch camp, with what belongs to whom: [[piece, owner id or ""], ...].
func _pieces(camp: Node) -> Array:
	var out: Array = []
	for path in ["Hud/Clock", "Hud/Hint", "Hud/Toast", "Hud/Prompt", "Hud/Dev"]:
		out.append([camp.get_node(path), ""])
	for who: String in camp._docks:
		out.append([camp._docks[who], who])
	for who: String in camp._boards:
		out.append([camp._boards[who], who])
	for panels: Dictionary in [camp._packs, camp._bench]:
		for who: String in panels:
			out.append([panels[who]["panel"], who])
	return out


## "" when every visible piece with something in it is inside the view and none covers another, except the pairs of
## names in `may_meet`. Shared with test_stage_b.
static func hud_fits(view: Rect2, pieces: Array, may_meet: Array = []) -> String:
	var shown: Array[Control] = []
	for c: Control in pieces:
		if c.is_visible_in_tree() and not (c is Label and (c as Label).text == ""):
			shown.append(c)
	for i in shown.size():
		var r := shown[i].get_global_rect()
		if not view.encloses(r):
			return "%s should stay inside the view %s, got %s" % [shown[i].name, view, r]
		for j in range(i + 1, shown.size()):
			var pair := [str(shown[i].name).get_slice("_", 0), str(shown[j].name).get_slice("_", 0)]
			if may_meet.has(pair) or may_meet.has([pair[1], pair[0]]):
				continue
			if r.intersects(shown[j].get_global_rect()):
				return "%s %s and %s %s should not overlap" % [shown[i].name, r, shown[j].name, shown[j].get_global_rect()]
	return ""


## Fits, plus each player's own pieces on their own half: player one's on the left, the couch player's on the right.
## `may_meet` as in hud_fits.
func _couch_fits(camp: Node, what: String, may_meet: Array = []) -> String:
	await _frames(3)
	var view: Rect2 = camp.get_viewport().get_visible_rect()
	var pieces := _pieces(camp)
	var controls: Array = []
	for p: Array in pieces:
		controls.append(p[0])
	var why := hud_fits(view, controls, may_meet)
	for p: Array in pieces:
		var c: Control = p[0]
		if why != "" or str(p[1]) == "" or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		var mid := view.position.x + view.size.x * 0.5
		var left: bool = str(p[1]) != camp.couch_id
		if (left and r.end.x > mid) or (not left and r.position.x < mid):
			why = "%s should stay on its player's %s half, got %s" % [c.name, "left" if left else "right", r]
	return "" if why == "" else what + ": " + why


## Playtest: an open panel covered its own player's camper. "" when each player with an open panel stands clear of it
## once their view has slid (a long step lets the easing finish).
func _campers_clear(camp: Node, what: String) -> String:
	camp._keep_in_view(10.0)
	camp._keep_in_view(10.0)
	var view: Rect2 = camp.get_viewport().get_visible_rect()
	for who: String in camp.local_ids():
		var panel: Control = camp._panel_of(who)
		if panel == null or not panel.is_visible_in_tree():
			continue
		var cam: PlayCamera = camp.couch.second_camera() if camp.couch.split and who == camp.couch_id else camp.camera
		var body: Vector3 = camp.campers[who].global_position + Vector3.UP * Tuning.num("tuning", "hud.keep_clear_height_m")
		var at := cam.unproject_position(body) * (view.size.y / cam.get_viewport().get_visible_rect().size.y)
		if panel.get_global_rect().has_point(at) or not view.has_point(at):
			return "%s: %s's camper at %s should be in view and clear of their %s %s" % [what, who, at, panel.name,
					panel.get_global_rect()]
	return ""


func test_couch_split_screen_hud_never_overlaps() -> String:
	var was := _tree().root.size
	var camp := _full_couch()
	var why := ""
	var p1: String = camp.profile["id"]
	var p2: String = camp.couch_id
	await _frames(3)
	if p2 == "" or not camp.couch.split:
		why = "the couch player should have dropped in and the screen split"
	if why == "":
		why = await _couch_fits(camp, "two docks")
	if why == "":
		camp.toggle_clipboard(p1)
		camp.toggle_clipboard(p2)
		why = await _couch_fits(camp, "two clipboards")
	if why == "":
		why = _campers_clear(camp, "two clipboards")
	for tab in Clipboard.tabs().size() if why == "" else 0:
		camp._boards[p1].flip(1)
		camp._boards[p2].flip(1)
		camp._refresh_boards()
		why = await _couch_fits(camp, "two clipboards on tab " + camp._boards[p1].tab_name())
		if why != "":
			break
	if why == "":
		camp.open_pack(p1)
		camp.open_pack(p2)
		why = await _couch_fits(camp, "two Packs")
	if why == "":
		why = _campers_clear(camp, "two Packs")
	if why == "":
		camp.close_pack(p2)
		camp.toggle_clipboard(p2)
		why = await _couch_fits(camp, "a Pack and a clipboard")
	if why == "":
		camp.close_pack(p1)
		camp.open_bench(p1)
		camp.open_pack(p2)
		why = await _couch_fits(camp, "the workbench and a Pack")
	if why == "":
		camp.close_bench(p1)
		camp.close_pack(p2)
		camp.toggle_clipboard(p1)
		camp.open_bench(p2)
		why = await _couch_fits(camp, "a clipboard and the workbench")
	# The biggest interface size (a 1280 x 720 screen's worth of room): both clipboards still fit on screen, each on
	# its own half, clear of each other, the hint, the clock and the docks. Only there may the centre column's
	# prompts and toasts pass under a clipboard: two clipboards and a prompt for each player don't fit side by side.
	if why == "":
		camp.close_bench(p2)
		camp.toggle_clipboard(p2)
		Settings.set_value("ui_scale", 150)
		Settings.apply("ui_scale")
		camp._refresh_boards()
		for tab in Clipboard.tabs().size():
			why = await _couch_fits(camp, "two clipboards at the biggest interface size on tab " + camp._boards[p1].tab_name(),
					[["Toast", "Clipboard"], ["Prompt", "Clipboard"], ["Toast", "Prompt"], ["Dev", "Clipboard"]])
			if why != "":
				break
			camp._boards[p1].flip(1)
			camp._boards[p2].flip(1)
			camp._refresh_boards()
		Settings.reset_page("access")
		Settings.apply("ui_scale")
	_tree().root.size = was
	await _done()
	return why


## Animal Crossing's reference (owner): the dock shows what the next press brings either side of the tool in hand,
## and the open Pack names the picked item with what it is for.
func test_the_dock_shows_its_neighbours_and_the_pack_names_the_pick() -> String:
	_fresh()
	var camp := _camp("NearSide", "p_host", "Hana")
	camp.start_solo(1)
	var why := ""
	var order: Array = Tuning.value("items", "tools.order")
	camp.hold_tool("p_host", str(order[1]))
	await _frames(1)
	var near: Array[String] = camp._docks["p_host"].tool_near()
	if near != [Tuning.text("dock.prev") % Tuning.text("tool." + str(order[0])),
			Tuning.text("dock.next") % Tuning.text("tool." + str(order[2]))]:
		why = "with the %s in hand the dock should show %s before and %s after, got %s" % [order[1], order[0], order[2], near]
	if why == "":
		camp.hold_tool("p_host", str(order[0]))
		near = camp._docks["p_host"].tool_near()
		if near[0] != Tuning.text("dock.prev") % Tuning.text("tool." + str(order[order.size() - 1])):
			why = "the cycle goes round: before the first tool comes the last, got " + near[0]
	if why == "":
		camp.state.pack.add("p_host", "sapling", 2)
		camp.open_pack("p_host")
		await _frames(2)
		why = _campers_clear(camp, "the Pack alone")
		var tag: String = camp._packs["p_host"]["panel"].tag_text()
		if not (tag.to_lower().contains(Tuning.text("items.sapling")) and tag.contains(Tuning.text("pack.about.plant"))):
			why = "the Pack's name tag should name the picked sapling and say what it is for, got " + tag
		camp.close_pack("p_host")
	await _done()
	return why


## Playtest: Tab opened the in-camp menu, but once a menu button had focus Godot's focus keys took the next Tab and the
## menu stayed open. Real key presses through the viewport (the GUI sees them first), not a direct call.
func test_the_menu_key_closes_the_menu_it_opened() -> String:
	_fresh()
	var camp := _camp("TabSide", "p_host", "Hana")
	camp.start_solo(1)
	await _frames(2)
	var why := ""
	for want: bool in [true, false, true, false]:
		for pressed: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = KEY_TAB
			ev.physical_keycode = KEY_TAB
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)
		if camp.menu.visible != want:
			why = "Tab should %s the menu" % ("open" if want else "close")
			break
		if want and camp.get_viewport().gui_get_focus_owner() == null:
			why = "the open menu should have a button in focus (that is what took Tab)"
			break
	await _done()
	return why


## Playtest: the hint wrapped inside a control ("Tab for the / menu") or left a lone dot at a line's end, and a toast that came with the morning report
## drew under it and was never read.
func test_the_hint_wraps_between_controls_and_toasts_wait_for_the_report() -> String:
	_fresh()
	var camp := _camp("WrapSide", "p_host", "Hana")
	camp.start_solo(1)
	await _frames(2)
	var why := ""
	var hint: String = camp.get_node("Hud/Hint").text.get_slice("\n", 0)
	# The only breakable spaces come after a dot, so a wrapped line ends on its dot and never starts with one.
	if hint.contains(" ·"):
		why = "a dot in the hint should stay on the line before it: " + hint
	for part in hint.split("\u00a0· "):
		if why == "" and part.contains(" "):
			why = "the hint should only break between controls, but %s can break inside" % part
	if why == "":
		camp._welcome_report()
		camp._toast(Tuning.text("toast.dropped_in") % "Clover")
		await _frames(1)
		if not camp.report.visible or camp.get_node("Hud/Toast").text.contains("Clover"):
			why = "a toast should wait while the morning report is up"
		camp.report.visible = false
		await _frames(2)
		if why == "" and not camp.get_node("Hud/Toast").text.contains("Clover"):
			why = "the toast should show once the report is put away, got " + camp.get_node("Hud/Toast").text
	await _done()
	return why


## The owner (25 Oct 2026): a clipboard that looks knitted, with a knitted sheet of paper the writing sits on. The board
## and the sheet are knitted (scripts/ui/knit.gdshader), the clip sits across the top of the sheet, a stitched rule
## runs under each line of the page and stops at its end, and keys on the sheet are honey caps, not cream on cream.
func test_the_clipboard_is_a_knitted_board_with_a_ruled_sheet() -> String:
	_fresh()
	var camp := _camp("NearSide", "p_host", "Hana")
	camp.start_solo(1)
	camp.toggle_clipboard("p_host")
	await _frames(3)
	var why := ""
	var board: Clipboard = camp._boards.get("p_host")
	var sheet: PanelContainer = board._sheet if board else null
	if board == null or not (board.material is ShaderMaterial and sheet.material is ShaderMaterial):
		why = "the open clipboard should be a knitted board holding a knitted sheet"
	if why == "" and (sheet.material as ShaderMaterial).shader != Clipboard.KNIT:
		why = "the sheet should use the knit shader"
	if why == "":
		var knit := sheet.material as ShaderMaterial
		var body: Label = board._body
		var line_h := float(body.get_line_height()) + float(body.get_theme_constant("line_spacing"))
		var top := float(knit.get_shader_parameter("rule_top"))
		var body_top := body.get_global_rect().position.y - sheet.get_global_rect().position.y
		if absf(float(knit.get_shader_parameter("rule_px")) - line_h) > 0.5:
			why = "a rule should come every line (%.1f px), got %s" % [line_h, knit.get_shader_parameter("rule_px")]
		elif absf(top - body_top) > 0.5:
			why = "the rules should start where the writing starts (%.1f), got %.1f" % [body_top, top]
		elif float(knit.get_shader_parameter("rule_bottom")) > body_top + body.size.y + 1.5:
			why = "the rules should stop at the end of the page"
		elif sheet.get_global_rect().position.y <= board.get_global_rect().position.y:
			why = "the board should show above the sheet, where the clip holds it"
	if why == "":
		var sheet_face := FeltBuilder.swatch(str(Tuning.value("tuning", "clipboard.sheet_swatch"))).linear_to_srgb()
		var paper_key := FeltBuilder.swatch(str(Tuning.value("tuning", "glyphs.paper_key_swatch"))).linear_to_srgb()
		if not Prompts.rich("{clipboard}", false, true).contains(paper_key.to_html()):
			why = "keys on the sheet should be paper keycaps"
		elif absf(sheet_face.get_luminance() - paper_key.get_luminance()) < 0.12:
			why = "a paper keycap should stand out from the sheet"
	camp.toggle_clipboard("p_host")
	await _done()
	return why
