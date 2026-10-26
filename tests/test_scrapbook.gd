extends RefCounted
## The scrapbook (owner picks, 26 Oct 2026; data/scrapbook.json): pages that fill by themselves for tools, builds and
## finds, animal pages filled by a real snapshot kept on each PC, as rules, from the buttons, and on a guest PC.

const DIR := "user://test_saves/scrapbook"
const PHOTOS := "user://test_saves/scrapbook_photos"
const OPEN := Vector2(-3.2, 7.9)
var _sides: Array[Node3D] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _state() -> CampState:
	var state := CampState.new(CampSave.new_camp())
	state.join("p_host", "Hana")
	state.join("p_guest", "Gus")
	return state


## A test frame: a wide picture, so the snapshot has to crop it to the photo's shape.
func _frame() -> Image:
	var frame := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0.3, 0.6, 0.3))
	frame.fill_rect(Rect2i(280, 140, 80, 80), Color(0.8, 0.7, 0.5))
	return frame


func _wipe_photos() -> void:
	CampScrapbook.photo_root = PHOTOS
	DirAccess.make_dir_recursive_absolute(PHOTOS)
	for dir in DirAccess.get_directories_at(PHOTOS):
		for f in DirAccess.get_files_at(PHOTOS + "/" + dir):
			DirAccess.remove_absolute("%s/%s/%s" % [PHOTOS, dir, f])


func test_pages_fill_by_themselves_and_animals_need_a_photo() -> String:
	_wipe_photos()
	var s := _state()
	var book := s.scrapbook
	if book.count("animals") != Vector2i(0, CampScrapbook.in_category("animals").size()):
		return "a new camp's scrapbook should be empty"
	s.pack.add("p_host", "berries", 2)
	if Array(book.sweep("p_host")) != Array(["berries"]) or not book.has("berries"):
		return "berries in a Pack should fill their page: %s" % [book.filled()]
	if not book.sweep("p_host").is_empty():
		return "a filled page is filled once"
	if s.build.build("p_host", "project_board", OPEN, 0.0) != "" or Array(book.sweep("p_guest")) != Array(["project_board"]):
		return "a build standing should fill its page"
	if str(book.filled()["project_board"]["by"]) != "p_guest":
		return "the page should say who filled it"
	if Array(book.note("chop", "p_host")) != Array(["axe"]) or Array(book.note("fish:perch", "p_host")) != Array(["rod"]):
		return "chopping and fishing should fill the axe and rod pages"
	if not book.note("cook:grilled_perch", "p_host").is_empty():
		return "a step no page waits for fills nothing"
	if book.photo("p_host", "axe") == "" or book.photo("p_host", "nobody") == "":
		return "only animal pages are filled by a photo"
	if book.photo("p_host", "deer") != "" or not book.has("deer") or int(book.filled()["deer"]["shots"]) != 1:
		return "photographing a deer should fill its page"
	book.photo("p_guest", "deer")
	if int(book.filled()["deer"]["shots"]) != 2 or str(book.filled()["deer"]["by"]) != "p_guest":
		return "a second photo should count and say who took it"
	var old := CampSave.new_camp()
	old.erase("scrapbook")
	old["journal"] = {"wildlife": ["rabbit"], "photos": {"rabbit": 2}}
	var o := CampState.new(CampSave.upgrade(old))
	o.join("p_host", "Hana")
	if not o.scrapbook.sweep("p_host").has("rabbit"):
		return "a camp saved with field-guide photos should find them taped in its scrapbook"
	return ""


func test_a_snapshot_is_a_small_photo_kept_in_the_camps_folder() -> String:
	_wipe_photos()
	var s := _state()
	var bytes := CampScrapbook.snapshot(_frame())
	var image := Image.new()
	if bytes.is_empty() or image.load_webp_from_buffer(bytes) != OK:
		return "a snapshot should be a WebP picture"
	var w := int(Tuning.num("scrapbook", "photo.width_px"))
	var h := int(Tuning.num("scrapbook", "photo.height_px"))
	if image.get_size() != Vector2i(w, h):
		return "a snapshot should be %dx%d (data/scrapbook.json photo): %s" % [w, h, image.get_size()]
	if bytes.size() > int(Tuning.num("scrapbook", "photo.max_bytes")):
		return "a snapshot should fit photo.max_bytes: %d" % bytes.size()
	if s.scrapbook.keep_photo("rabbit", bytes):
		return "a camp's scrapbook needs its id before it keeps snapshots"
	var id := s.scrapbook.ensure_id()
	if id.length() != 12 or s.scrapbook.ensure_id() != id:
		return "the scrapbook id should be made once"
	if s.scrapbook.keep_photo("axe", bytes) or s.scrapbook.keep_photo("rabbit", "not a picture".to_utf8_buffer()):
		return "only animal pages keep snapshots, and only real pictures"
	var big := PackedByteArray()
	big.resize(int(Tuning.num("scrapbook", "photo.max_bytes")) + 1)
	if s.scrapbook.keep_photo("rabbit", big):
		return "a snapshot bigger than photo.max_bytes is turned away"
	if not s.scrapbook.keep_photo("rabbit", bytes) or not s.scrapbook.photo_path("rabbit").begins_with(PHOTOS + "/" + id):
		return "a snapshot should be kept in the camp's own folder"
	if s.scrapbook.photo_texture("rabbit") == null or s.scrapbook.photo_texture("deer") != null:
		return "the kept snapshot should load back as a picture"
	return ""


# --- In the camp scene ---------------------------------------------------------------------------------------------

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


func _until(check: Callable, frames: int = 600) -> bool:
	for i in frames:
		if check.call():
			return true
		await _tree().process_frame
	return check.call()


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


func _clean() -> void:
	CampSave.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)
	_wipe_photos()


func _press(camp: Node, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	camp._unhandled_input(press)


func test_the_book_opens_from_its_button_and_turns_its_tabs() -> String:
	_clean()
	var camp := _camp("Side", "p_host", "Hana")
	var why: String = camp.start_solo(1)
	camp.report.visible = false
	if why == "":
		camp.ask("build", ["project_board", OPEN, 0.0], "p_host")
		await _tree().process_frame
		var card: Control = camp.get_node("Hud").get_node_or_null("PageCard")
		if not camp.state.scrapbook.has("project_board"):
			why = "putting up the camp board should fill its page"
		elif card == null or not card.visible or not (str(card.get_meta("page")) == "project_board" or (card.get_meta("queue") as Array).has("project_board")):
			why = "a new page should show its card, after any other pages filled with it"
		elif not (card.get_node("Col/Words") as Label).text.contains(Tuning.text("scrap.page.%s.name" % card.get_meta("page"))):
			why = "the card should name its page: %s / %s" % [card.get_meta("page"), (card.get_node("Col/Words") as Label).text]
		elif card.get_node("Col/Picture").get("texture") == null:
			why = "the card should show the board's knitted picture"
	if why == "":
		_press(camp, "scrapbook")
		await _tree().process_frame
		var panel: ScrapBook = camp.get_node("Hud").get_node_or_null("Book_p_host")
		if panel == null or camp.campers["p_host"].controlled:
			why = "the scrapbook button should open the book and hold the player still"
		elif not panel.tabs_text().contains(Tuning.text("scrap.cat.animals")) or panel.tile_text(0) != Tuning.text("scrap.unknown"):
			why = "the book should open on the animals, none photographed yet: " + panel.tabs_text()
		else:
			_press(camp, "camera_right")
			_press(camp, "camera_right")
			_press(camp, "move_right")
			var builds := CampScrapbook.in_category("builds")
			var want := Tuning.text("scrap.page.%s.name" % builds[1]["id"])
			if panel.page_name() != Tuning.text("scrap.unknown"):
				why = "a page not filled yet shows as unknown: " + panel.page_name()
			else:
				var board := builds.map(func(r: Dictionary) -> String: return str(r["id"])).find("project_board")
				for i in board - 1:
					_press(camp, "move_right")
				if panel.page_name() != Tuning.text("scrap.page.project_board.name") or panel.page_picture() == null:
					why = "the camp board's page should show its name and picture: " + panel.page_name()
				elif want == "":
					why = "every page needs a name in data/text.json"
		if why == "":
			_press(camp, "scrapbook")
			await _tree().process_frame
			if camp.get_node("Hud").get_node_or_null("Book_p_host") != null or not camp.campers["p_host"].controlled:
				why = "the scrapbook button should close the book again"
	if why == "":
		var reopened := CampSave.load_slot(1)
		if not reopened["camp"].get("scrapbook", {}).get("pages", {}).has("project_board"):
			why = "the scrapbook should be saved"
	await _done()
	return why


## Playtest (PR #62): at 150% the two couch books overlapped, and alone the book ran off the top of the screen.
func test_the_book_fits_the_screen_at_big_sizes_and_on_the_couch() -> String:
	_clean()
	var was := _tree().root.size
	_tree().root.size = Vector2i(1920, 1080)
	Settings.set_value("ui_scale", 150)
	Settings.apply("ui_scale")
	var camp := _camp("BigSide", "p_host", "Hana")
	var why: String = camp.start_solo(1)
	camp.report.visible = false
	var view: Rect2 = camp.get_viewport().get_visible_rect()
	if why == "":
		camp.open_book("p_host")
		await _tree().process_frame
		await _tree().process_frame
		var alone: ScrapBook = camp._books["p_host"]["panel"]
		if not view.grow(1.0).encloses(alone.shown_rect()):
			why = "alone at 150%% the book should fit the screen: %s in %s" % [alone.shown_rect(), view]
		camp.close_book("p_host")
	if why == "" and camp.drop_in(1) != "":
		why = "a couch player should drop in"
	if why == "":
		var two: Array[String] = camp.local_ids()
		for who in two:
			camp.open_book(who)
		await _tree().process_frame
		await _tree().process_frame
		var a: Rect2 = (camp._books[two[0]]["panel"] as ScrapBook).shown_rect()
		var b: Rect2 = (camp._books[two[1]]["panel"] as ScrapBook).shown_rect()
		if a.intersects(b) or not view.grow(1.0).encloses(a) or not view.grow(1.0).encloses(b):
			why = "on the couch at 150%% each book should keep to its half: %s and %s in %s" % [a, b, view]
	Settings.reset_page("access")
	Settings.apply("ui_scale")
	_tree().root.size = was
	await _done()
	return why


func test_a_snapshot_reaches_the_other_pc_both_ways() -> String:
	_clean()
	var host := _camp("HostSide", "p_host", "Hana")
	var why: String = host.start_host(1, 24751)
	host.report.visible = false
	var guest := _camp("GuestSide", "p_guest", "Gus")
	guest.start_join("127.0.0.1", 24751)
	if not await _until(func() -> bool: return guest.state != null and host.campers.size() == 2):
		why = "the guest never got in"
	var bytes := CampScrapbook.snapshot(_frame())
	if why == "":
		guest.report.visible = false
		# The guest takes the camp's first photo: its PC has no scrapbook id yet, so the host keeps it and sends it back.
		guest.ask("photo", ["deer"], "p_guest")
		guest._keep_and_send("deer", bytes)
		if not await _until(func() -> bool: return host.state.scrapbook.photo_bytes("deer") == bytes):
			why = "the guest's snapshot should reach the host"
		elif not await _until(func() -> bool: return guest.state.scrapbook.has("deer") and guest.state.scrapbook.photo_bytes("deer") == bytes):
			why = "the guest should keep its own snapshot once the scrapbook id arrives"
		elif host.page_view("deer")["footer"] != Tuning.text("scrap.footer.photo") % ["Gus", host.state.day.today()]:
			why = "the page should say who took it: " + str(host.page_view("deer")["footer"])
	if why == "":
		host.ask("photo", ["rabbit"], "p_host")
		host._keep_and_send("rabbit", bytes)
		if not await _until(func() -> bool: return guest.state.scrapbook.photo_bytes("rabbit") == bytes):
			why = "the host's snapshot should reach the guest PC"
		elif guest.page_picture("rabbit") == null or not guest.page_view("rabbit")["photo"]:
			why = "the guest's book should show the host's snapshot taped in"
	await _done()
	return why
