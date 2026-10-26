class_name CampScrapbook
extends RefCounted
## The scrapbook (owner picks, 26 Oct 2026): a page for each animal, tool, build and find (data/scrapbook.json).
## Animals fill when a player photographs them; the rest fill by themselves the first time the players use, build or
## find them. The camp's "scrapbook" keeps its id (naming the folder of snapshots on each PC) and the filled pages:
## page id -> {"day", "by" (a profile ID), "shots" (how many photos, for photo pages)}. The host's copy decides; the
## snapshots themselves are files, kept on each PC (photo.dir) and sent to the other (Camp._photo_file).

## Where snapshots are kept; tests point it at their own folder.
static var photo_root := ""

var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


func data() -> Dictionary:
	if not state.camp.has("scrapbook"):
		state.camp["scrapbook"] = {"id": "", "pages": {}}
	var book: Dictionary = state.camp["scrapbook"]
	if not book.has("pages"):
		book["pages"] = {}
	return book


func filled() -> Dictionary:
	return data()["pages"]


static func categories() -> Array:
	return Tuning.value("scrapbook", "categories", [])


static func pages() -> Array:
	return Tuning.value("scrapbook", "pages", [])


static func page(id: String) -> Dictionary:
	for row: Dictionary in pages():
		if str(row["id"]) == id:
			return row
	return {}


## The pages of one category, in the table's order.
static func in_category(cat: String) -> Array:
	return pages().filter(func(row: Dictionary) -> bool: return str(row["cat"]) == cat)


func has(id: String) -> bool:
	return filled().has(id)


## How many pages of a category are filled, out of how many.
func count(cat: String) -> Vector2i:
	var rows := in_category(cat)
	return Vector2i(rows.filter(func(row: Dictionary) -> bool: return has(str(row["id"]))).size(), rows.size())


func _fill(id: String, profile_id: String) -> bool:
	if has(id) or page(id).is_empty():
		return false
	filled()[id] = {"day": state.day.today(), "by": profile_id}
	return true


## Host: the pages the camp has earned by itself and not yet filled: items in a Pack or the camp box, builds standing,
## and animals photographed before the scrapbook (the field guide's photos). Returns the new page ids.
func sweep(profile_id: String) -> Array[String]:
	var out: Array[String] = []
	var items := {}
	for id: String in state.camp["profiles"]:
		for st: Dictionary in state.pack.slots(id):
			items[str(st["item"])] = true
	for item: String in state.camp.get("box", {}):
		if int(state.camp["box"][item]) > 0:
			items[item] = true
	var kinds := {}
	for id: String in state.camp["objects"]:
		kinds[CampBuild.kind_of(state, id)] = true
	var photos: Dictionary = state.camp.get("journal", {}).get("photos", {})
	for row: Dictionary in pages():
		var id := str(row["id"])
		var fill := str(row.get("fill", ""))
		if has(id):
			continue
		if (fill == "item" and items.has(id)) or (fill == "build" and kinds.has(id)) \
				or (fill == "photo" and int(photos.get(id, 0)) > 0):
			if _fill(id, profile_id):
				out.append(id)
	return out


## Host: a step the players took ("chop", "fish:perch"...) fills the pages that wait for it. Returns the new ids.
func note(event: String, profile_id: String) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in pages():
		var want := str(row.get("event", ""))
		if str(row.get("fill", "")) == "event" and want != "" and (event == want or event.begins_with(want + ":")):
			if _fill(str(row["id"]), profile_id):
				out.append(str(row["id"]))
	return out


## Host: a player photographed `id`. Fills its page the first time; every photo after replaces the snapshot.
## Returns "" or a text key.
func photo(profile_id: String, id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if str(page(id).get("fill", "")) != "photo":
		return "deny.not_movable"
	_fill(id, profile_id)
	var row: Dictionary = filled()[id]
	row["shots"] = int(row.get("shots", 0)) + 1
	row["by"] = profile_id
	row["day"] = state.day.today()
	return ""


# --- Snapshots -----------------------------------------------------------------------------------------------------

## Host: names this camp's scrapbook once, so each PC keeps its snapshots in a folder of its own.
func ensure_id() -> String:
	if str(data().get("id", "")) == "":
		var letters := "abcdefghijkmnpqrstuvwxyz23456789"
		var id := ""
		for i in 12:
			id += letters[randi() % letters.length()]
		data()["id"] = id
	return str(data()["id"])


func photo_path(id: String) -> String:
	var root := photo_root if photo_root != "" else str(Tuning.value("scrapbook", "photo.dir", "user://photos"))
	return "%s/%s/%s.webp" % [root, str(data().get("id", "")), id]


## Keeps a snapshot for a photo page on this PC. False when it is not a photo page, too big, or not a picture.
func keep_photo(id: String, bytes: PackedByteArray) -> bool:
	if str(page(id).get("fill", "")) != "photo" or str(data().get("id", "")) == "" or bytes.is_empty() \
			or bytes.size() > int(Tuning.num("scrapbook", "photo.max_bytes", 200000)):
		return false
	var check := Image.new()
	if check.load_webp_from_buffer(bytes) != OK:
		return false
	var path := photo_path(id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func photo_bytes(id: String) -> PackedByteArray:
	var path := photo_path(id)
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## The snapshot for a page as a texture, or null when this PC has none.
func photo_texture(id: String) -> Texture2D:
	var bytes := photo_bytes(id)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


## A snapshot from a frame: the middle of it at the photo's shape, scaled to photo.width_px x height_px, as WebP.
static func snapshot(frame: Image) -> PackedByteArray:
	if frame == null or frame.is_empty() or frame.is_compressed():
		return PackedByteArray()
	var w := int(Tuning.num("scrapbook", "photo.width_px", 320))
	var h := int(Tuning.num("scrapbook", "photo.height_px", 240))
	var shot := frame.duplicate() as Image
	shot.convert(Image.FORMAT_RGB8)
	var aspect := float(w) / float(h)
	var cw := mini(shot.get_width(), int(shot.get_height() * aspect))
	var ch := mini(shot.get_height(), int(cw / aspect))
	shot = shot.get_region(Rect2i((shot.get_width() - cw) / 2, (shot.get_height() - ch) / 2, cw, ch))
	shot.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return shot.save_webp_to_buffer(true, Tuning.num("scrapbook", "photo.quality", 0.8))
