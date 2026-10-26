class_name DevTools
extends RefCounted
## What the developer menu's rows do (data/dev.json). Rows marked `host` change the shared camp, so they go through
## `camp.ask("dev", [row, value])` and the host runs them here (`run`), like any other request: a guest PC asks, the
## host decides. The rest change only this PC (`run_local`). Only a debug build (the editor) or a game started with
## `-- --dev` has dev tools; anywhere else F1 shows just the fps line.

## Tests set this to true or false to stand in for the build; null asks the build.
static var allowed: Variant = null


static func enabled() -> bool:
	if allowed != null:
		return bool(allowed)
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")


static func rows() -> Array:
	return Tuning.value("dev", "rows", [])


static func row(id: String) -> Dictionary:
	for r: Dictionary in rows():
		if str(r["id"]) == id:
			return r
	return {}


## The models the preview row offers: data/dev.json previews that exist in data/models.json (a model still being made,
## such as Ranger Burl before it lands, is left out until it does).
static func previews() -> Array:
	var models := Tuning.table("models")
	return (Tuning.value("dev", "previews", []) as Array).filter(func(m: Variant) -> bool: return models.has(str(m)))


# --- Host side ---------------------------------------------------------------------------------------------------

## Host: runs a dev row for `profile_id`. Returns "" or a text key saying why not. The camp shares and saves after.
static func run(camp: Node, profile_id: String, id: String, value: Variant) -> String:
	if not enabled():
		return "dev.denied"
	var state: CampState = camp.state
	var cal: Dictionary = state.camp["calendar"]
	match id:
		"hour":
			if not (value is float or value is int):
				return "dev.denied"
			var start := Tuning.num("day", "clock.start_hour", 7.0)
			cal["minute"] = clampf((float(value) - start) * 60.0, 0.0, CampDay.day_minutes())
		"speed":
			if not (value is float or value is int) or not (Tuning.value("dev", "speeds", [1]) as Array).any(
					func(v: Variant) -> bool: return int(v) == int(value)):
				return "dev.denied"
			camp.dev_speed = float(value)
		"sleep":
			for who: String in state.online:
				if not state.day.votes.has(who):
					state.day.votes.append(who)
			camp._check_bed()
		"season":
			if not (Tuning.value("day", "calendar.seasons", []) as Array).has(value):
				return "dev.denied"
			cal["season"] = str(value)
		"day":
			if not (value is float or value is int):
				return "dev.denied"
			cal["day"] = clampi(int(value), 1, int(Tuning.num("day", "calendar.days_per_season", 14)))
		"guest":
			if not (Tuning.value("day", "stays.looks", []) as Array).has(value):
				return "dev.denied"
			return _call_guest(camp, profile_id, str(value))
		"coins":
			state.camp["coins"] = int(state.camp.get("coins", 0)) + int(Tuning.num("dev", "coins_step", 100))
		"item":
			if not (Tuning.value("items", "items", {}) as Dictionary).has(str(value)):
				return "dev.denied"
			if state.pack.add(profile_id, str(value), int(Tuning.num("dev", "give_n", 1))) <= 0:
				return "deny.pack_full"
		_:
			return "dev.denied"
	return ""


## Host: a walk-in guest with this look comes now, whatever the hour, at a free pitch; with none free, a pitch is put
## up at the first open spot in data/dev.json guest_spots (the dev pays its coins).
static func _call_guest(camp: Node, profile_id: String, look: String) -> String:
	var state: CampState = camp.state
	var free := state.guests.free_pitches()
	if free.is_empty():
		var cost := state.build.cost("pitch")
		for spot: Array in Tuning.value("dev", "guest_spots", []):
			state.camp["coins"] = int(state.camp.get("coins", 0)) + cost
			if state.build.build(profile_id, "pitch", Vector2(float(spot[0]), float(spot[1])), 0.0) == "":
				var built := state.build.last_id
				camp._show_object(built)
				for guest: int in camp._guests:
					camp._object_changed.rpc_id(guest, built, state.camp["objects"][built], "")
				free = [built]
				break
			state.camp["coins"] = int(state.camp["coins"]) - cost
		if free.is_empty():
			return "dev.no_pitch"
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	var names: Array = Tuning.value("text", "guest.names", ["Guest"])
	var id := "stay_%d" % n
	state.camp["stays"][id] = {"pitch": str(free[0]), "name": str(names[n % names.size()]), "look": look,
			"nights_left": int(Tuning.num("day", "stays.nights", 1)), "arrived": state.day.today(),
			"arrived_min": state.day.minute(), "request": CampGuests.new_request(n, state.day.today())}
	camp._sync_stays(true)
	return ""


# --- This PC only ------------------------------------------------------------------------------------------------

## Runs a dev row that changes only this PC, for the local player `who`.
static func run_local(camp: Node, who: String, id: String, value: Variant) -> void:
	match id:
		"teleport":
			var at: Array = Tuning.value("dev", "places." + str(value), [0.0, 0.0])
			var c: Camper = camp.campers.get(who)
			if c:
				c.position = Vector3(float(at[0]), c.position.y, float(at[1]))
				c.velocity = Vector3.ZERO
		"preview":
			if str(value) == "":
				clear_previews(camp)
			else:
				_preview(camp, who, str(value))
		"welcome":
			var lines: Array[String] = [Tuning.text("report.welcome"), ""]
			lines.append_array(camp._today_report())
			camp.report.show_report("\n".join(lines), Prompts.rich(Tuning.text("prompt.report_close"), camp._pad, true),
					Prompts.rich(Tuning.text("prompt.report_next"), camp._pad, true))


## A still model of a character in front of a local player, facing them, to look at up close. Only on this PC and
## never saved; "put them away" (or leaving the camp) clears them.
static func _preview(camp: Node, who: String, model: String) -> void:
	var c: Camper = camp.campers.get(who)
	if c == null:
		return
	var ahead := Tuning.num("dev", "preview_ahead_m", 1.8)
	var front := -c.transform.basis.z
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	# Each further preview stands a step to the side of the last.
	var count := camp.get_tree().get_nodes_in_group("dev_preview").size()
	var spot := c.position + front * ahead + front.cross(Vector3.UP) * 1.1 * count
	var p := Camper.new()
	p.name = "DevPreview_%d" % count
	p.model_id = model
	p.display_name = model
	p.add_to_group("dev_preview")
	p.position = spot
	var back := c.position - spot
	p.rotation.y = atan2(-back.x, -back.z)
	camp.add_child(p)

static func clear_previews(camp: Node) -> void:
	for p in camp.get_tree().get_nodes_in_group("dev_preview"):
		if camp.is_ancestor_of(p):
			p.get_parent().remove_child(p)
			p.queue_free()
