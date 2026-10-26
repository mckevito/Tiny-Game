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


## Playtest (PR #47): "" when each building player's prompt is on their own dock, the shared column holds only the
## bed line, a dock is no taller than with its tool row, and the column stands clear of both campers.
func _prompt_roomy(camp: Node, what: String) -> String:
	var prompt: RichTextLabel = camp.get_node("Hud/Prompt")
	for who: String in camp.local_ids():
		var dock: HudDock = camp._docks[who]
		if dock.prompt_text() == "":
			return what + ": %s's prompt should be on their dock" % who
		if prompt.text.contains(dock.prompt_text()):
			return what + ": %s's prompt should not also be in the shared column" % who
	if prompt.text != Prompts.rich(camp._bed_line(), camp._pad):
		return what + ": the shared column should hold just the bed line, got " + prompt.text
	camp._keep_in_view(10.0)
	camp._keep_in_view(10.0)
	var view: Rect2 = camp.get_viewport().get_visible_rect()
	for who: String in camp.local_ids():
		var cam: PlayCamera = camp.couch.second_camera() if camp.couch.split and who == camp.couch_id else camp.camera
		var body: Vector3 = camp.campers[who].global_position + Vector3.UP * Tuning.num("tuning", "hud.keep_clear_height_m")
		var at := cam.unproject_position(body) * (view.size.y / cam.get_viewport().get_visible_rect().size.y)
		if prompt.get_global_rect().has_point(at):
			return what + ": the bed line %s should not cover %s's camper at %s" % [prompt.get_global_rect(), who, at]
	return ""


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
		# Playtest (PR #47): with the clipboards away and both players building, the docks squeezed the prompt column
		# to a sliver, so the two prompts stacked 8 to 10 lines over both campers. Each now sits on its own dock.
		if why == "":
			camp.toggle_clipboard(p1)
			camp.toggle_clipboard(p2)
			for who in [p1, p2]:
				if not camp._building.has(who):
					camp.toggle_build(who)
			# The F1 dev line may pass under a dock here; it is a dev tool, not part of play.
			why = await _couch_fits(camp, "both building at the biggest interface size", [["Toast", "Prompt"],
					["Dev", "Dock"]])
		if why == "":
			why = _prompt_roomy(camp, "both building at the biggest interface size")
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


## Playtest: the controls wrapped inside a control ("Tab for the / menu") or left a lone dot at a line's end, and a toast that came with the morning report
## drew under it and was never read.
func test_the_hint_wraps_between_controls_and_toasts_wait_for_the_report() -> String:
	_fresh()
	var camp := _camp("WrapSide", "p_host", "Hana")
	camp.start_solo(1)
	await _frames(2)
	var why := ""
	# The owner's pick (26 Oct 2026): the always-on controls line became a legend in each player's dock. Entries sit
	# apart by a wide space, the only place it can break, so no key is parted from its word and no dot is left over.
	var legend: String = camp._docks[camp.local_ids()[0]].legend_text()
	if legend == "" or str(camp.get_node("Hud/Hint").text).contains(legend.get_slice(Tuning.text("glyphs.gap"), 0)):
		why = "the controls should be a legend in the dock, not the top line, got " + legend
	if why == "" and legend.contains("·"):
		why = "the legend should part its entries with space, not dots: " + legend
	for part in legend.split(Tuning.text("glyphs.gap")):
		if why == "" and part.contains(" "):
			why = "the legend should only break between entries, but %s can break inside" % part
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


## Playtest (PR #40): at a big interface size an open clipboard covered the prompt in the middle of the screen and the
## toasts ran over a hint that had wrapped to four lines; a morning report with three guests ran off the top and bottom
## of the screen. Alone on the PC the prompt and toasts move beside the clipboard and below the hint, and a report too
## tall for the screen turns into pages: interact turns them, and on the last page it closes the report.
func test_big_sizes_keep_prompts_clear_and_long_reports_turn_pages() -> String:
	_fresh()
	var was := _tree().root.size
	_tree().root.size = SCREEN
	var camp := _camp("BigSide", "p_host", "Hana")
	camp.start_solo(1)
	var who: String = camp.local_ids()[0]
	camp.toggle_build(who)
	for i in 3:
		camp._toast(Tuning.text("toast.crafted") % ["Hana", Tuning.text("build.lantern_post")])
	var why := ""
	for scale in [120, 150]:
		Settings.set_value("ui_scale", scale)
		Settings.apply("ui_scale")
		camp.toggle_clipboard(who)
		await _frames(3)
		var view: Rect2 = camp.get_viewport().get_visible_rect()
		var hud: Node = camp.get_node("Hud")
		if str(hud.get_node("Prompt").text) == "":
			why = "a building prompt should show at %d%%" % scale
		if why == "":
			why = hud_fits(view, [hud.get_node("Hint"), hud.get_node("Clock"), hud.get_node("Prompt"),
					hud.get_node("Toast"), camp._boards[who]])
			why = "" if why == "" else "at %d%% with the clipboard open: %s" % [scale, why]
		camp.toggle_clipboard(who)
		# Playtest (PR #45): with the clipboard away, the dock in the corner reached into the prompt column at 150%.
		await _frames(3)
		if why == "":
			why = hud_fits(view, [hud.get_node("Prompt"), camp._docks[who]])
			why = "" if why == "" else "at %d%% with the dock showing: %s" % [scale, why]
		if why != "":
			break
	if why == "":
		var lines: PackedStringArray = []
		for i in 60:
			lines.append("Guest %d had a lovely stay and left a kind note by the fire." % i)
		camp.report.show_report("\n".join(lines), "close", "next %d of %d")
		await _frames(3)
		var view: Rect2 = camp.get_viewport().get_visible_rect()
		var pages: int = camp.report.page_count()
		if pages < 2:
			why = "a 60-line report should take more than one page at 150%"
		elif not view.encloses(camp.report.get_global_rect()):
			why = "each page of the report should fit the screen, got %s in %s" % [camp.report.get_global_rect(), view]
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		for i in pages - 1:
			if why == "":
				camp._unhandled_input(press)
				if not camp.report.visible:
					why = "interact should turn to page %d, not close the report" % (i + 2)
		if why == "":
			camp._unhandled_input(press)
			if camp.report.visible:
				why = "interact on the last page should close the report"
	camp.report.visible = false
	Settings.reset_page("access")
	Settings.apply("ui_scale")
	_tree().root.size = was
	await _done()
	if why == "" and not Prompts.rich("{pack}", false).contains(Tuning.text("glyphs.key_pad_one") + "I"):
		why = "a one-letter key should get the wider keycap padding"
	# Playtest: an en space (a breaking space) let the hint wrap between "E" and "use or pick up" at 150%.
	for key in ["glyphs.key_pad", "glyphs.key_pad_one", "glyphs.join"]:
		for c in Tuning.text(key):
			if why == "" and not ["\u00a0", "\u2007", "\u202f"].has(c):
				why = "%s should only hold no-break spaces, so a keycap never wraps from its words" % key
	return why


## The owner's pick (26 Oct 2026): a context legend instead of the always-on controls line. Each player's dock shows
## icons for what they can do now, in their own device's buttons: walking on day 1, not after; the build buttons'
## legend while placing. On the couch each half shows its own player's legend.
func test_each_dock_has_a_legend_for_now() -> String:
	var camp := _full_couch()
	await _frames(2)
	var why := ""
	var p1: String = camp.local_ids()[0]
	var p2: String = camp.couch_id
	var walk_word := Tuning.text("legend.move")
	for who in [p1, p2]:
		camp.toggle_build(who)
	camp._refresh_docks()
	var one: String = camp._docks[p1].legend_text()
	var two: String = camp._docks[p2].legend_text()
	if not (one.contains("[bgcolor=") and not one.contains("[img=")):
		why = "player one is on the keyboard, so their legend should show keycaps, got " + one
	elif not (two.contains("[img=") and not two.contains("[bgcolor=")):
		why = "the couch player is on a pad, so their legend should show pad icons, got " + two
	elif not one.contains(walk_word):
		why = "on day 1 the legend should say how to walk, got " + one
	if why == "":
		camp.toggle_build(p1)
		camp._refresh_docks()
		var building: String = camp._docks[p1].legend_text()
		if building.contains(Tuning.text("legend.interact")) or building.split(Tuning.text("glyphs.gap")).size() != \
				(Tuning.value("tuning", "legend.build", []) as Array).size():
			why = "while building the legend should show only the build mode's entries, got " + building
		camp.toggle_build(p1)
	if why == "":
		camp.state.camp["calendar"]["day"] = 2
		camp._refresh_docks()
		if camp.state.day.today() == 2 and camp._docks[p1].legend_text().contains(walk_word):
			why = "after day 1 the legend should leave walking out"
	await _done()
	return why
