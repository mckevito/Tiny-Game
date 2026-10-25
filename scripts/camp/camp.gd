extends Node3D
## The camp: the game scene. Play alone, host a camp for a friend's PC, or join one (Godot's ENet multiplayer;
## data/net.json). Two players in total, both on this PC (couch) or one on each PC. The host's CampState decides every
## change to the shared camp: a guest asks with _request and the host answers with _object_changed or _denied. Each
## PC steers its own campers and tells the other PC where they are. Characters belong to profile IDs, never
## connection IDs.
## Couch (Milestone 3): a controller player one has not used drops in with the menu button and drops out from its
## menu; the couch character lives in the host's save and its link code lets its own PC claim it later.
## Stage A: the host's day clock (CampDay), guests who come to a free pitch, the sleep vote from the menu, the night
## that pays exactly once, and grid placement with undo (CampBuild) in build mode.
## Stage B: guests' small requests, fishing at the pond and grilling at the fire (CampPockets), two improvements to
## build, the booking board in the menu, satisfaction lines and the morning report (CampGuests, CampReport).
## Command line: -- --solo | --host | --join=ADDRESS [--link=CODE], plus --slot=N and --profile=NAME (a second local
## player file).

signal started
signal stopped(reason: String)

enum Mode { MENU, SOLO, HOST, GUEST }

var mode := Mode.MENU
var slot := 1
## This PC's player (LocalProfile); tests set it before the scene enters the tree.
var profile: Dictionary = {}
var state: CampState
## Profile id -> Camper, and object id -> its node.
var campers := {}
var objects := {}
## Host only: connection id -> profile id, for guests that said hello.
var _guests := {}
## The couch player on this PC ("" when none) and the controller it owns.
var couch_id := ""
var couch_pad := -1
## Controllers player one has used; any other controller can drop in.
var _p1_pads: Array[int] = []
## Player one's devices while someone is on the couch: the keyboard, the mouse and every other controller.
var _p1_input := PlayerInput.new()
## Whose menu is open ("" when closed).
var _menu_for := ""
var _link_code := ""
var _dev_clock := 0.0
var _profile_file := ""
var _send_clock := 0.0
var _pad := false
var _toast_left := 0.0
## Stage A: stay id -> the guest's camper, and stay id -> its tent on the pitch.
var visitors := {}
var _tents := {}
## Local players in build mode: profile id -> {"kind", "yaw", "ghost" (Node3D), "tile" (MeshInstance3D)}.
var _building := {}
var _clock_send := 0.0
var _light_t := -1.0
var _night_left := 0.0
## Stage B: local players fishing or grilling: profile id -> {"what", "left" (seconds), "bobber" (Node3D or null)}.
var _busy := {}

@onready var clearing: Clearing = $Clearing
@onready var camera: PlayCamera = $PlayCamera
@onready var menu: CampMenu = $Hud/Menu
@onready var couch: CouchView = $Couch
@onready var report: CampReport = $Hud/Report


func _ready() -> void:
	LightMoods.apply("day", $Sun, $World.environment, clearing.fire_lights)
	$Hud/Night.color = FeltBuilder.swatch(str(Tuning.value("day", "night.swatch", "ink_brown")))
	$Hud/Night.color.a = 0.0
	couch.main = camera
	camera.set_faders(clearing.faders)
	menu.chose.connect(_on_menu)
	Input.joy_connection_changed.connect(_on_joy_connection)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: stop.call_deferred("join.unreachable"))
	multiplayer.server_disconnected.connect(func() -> void: stop.call_deferred("join.host_left"))
	var args := _args()
	_profile_file = str(args.get("profile", ""))
	if profile.is_empty():
		profile = LocalProfile.load_or_create(_profile_file)
	menu.name_edit.text = str(profile.get("name", ""))
	menu.address_edit.text = str(profile.get("last_address", ""))
	menu.show_start()
	apply_quality(str(profile.get("quality", Quality.names()[0])), false)
	if args.has("slot"):
		menu.slot_pick.select(clampi(int(args["slot"]) - 1, 0, CampSave.slot_count() - 1))
	if args.has("solo"):
		start_solo(menu.slot())
	elif args.has("host"):
		start_host(menu.slot())
	elif args.has("join"):
		start_join(str(args["join"]), 0, str(args.get("link", "")))


static func _args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


func _net(key: String) -> float:
	return Tuning.num("net", key)


# --- Starting and stopping ---------------------------------------------------------------------------------------

func _on_menu(action: String) -> void:
	profile["name"] = menu.name_edit.text.strip_edges() if menu.name_edit.text.strip_edges() != "" \
			else Tuning.text("profile.default_name")
	match action:
		"solo": start_solo(menu.slot())
		"host": start_host(menu.slot())
		"join": start_join(menu.address_edit.text.strip_edges(), 0, menu.link_edit.text)
		"resume": _close_menu()
		"leave": stop("")
		"leave_couch": drop_out(couch_id)
		"sleep":
			var who := _menu_for
			_close_menu()
			ask("sleep", [not state.day.votes.has(who)], who)
		"booking_accept", "booking_later", "booking_decline":
			var who := _menu_for
			_close_menu()
			ask("booking", [str(state.guests.current().get("id", "")), action.trim_prefix("booking_")], who)
		"quality": apply_quality(Quality.next(str(profile.get("quality", ""))))
	LocalProfile.save(profile, _profile_file)


## Opens a camp slot on this PC with nobody else allowed in. Returns "" or a text key saying why not.
func start_solo(slot_number: int) -> String:
	var why := _open_camp(slot_number)
	if why == "":
		mode = Mode.SOLO
		started.emit()
	return why


## Opens a camp slot and lets one friend's PC join on `port` (data/net.json "port" when 0).
func start_host(slot_number: int, port: int = 0) -> String:
	var why := _open_camp(slot_number)
	if why != "":
		return why
	var peer := ENetMultiplayerPeer.new()
	var max_guests := int(_net("max_players")) - 1 + int(_net("spare_connections"))
	if peer.create_server(port if port > 0 else int(_net("port")), max_guests) != OK:
		stop("join.host_failed")
		return "join.host_failed"
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	_toast(Tuning.text("menu.hosting") % slot)
	started.emit()
	return ""


## Knocks on a friend's camp. `started` follows when the host says welcome; `stopped` if not. A link code claims the
## couch character it belongs to, so this PC plays as that character from now on.
func start_join(address: String, port: int = 0, link_code: String = "") -> String:
	if address == "":
		menu.show_start(Tuning.text("join.no_address"))
		return "join.no_address"
	profile["last_address"] = address
	_link_code = CampState.normalize_code(link_code)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port if port > 0 else int(_net("port"))) != OK:
		stop("join.unreachable")
		return "join.unreachable"
	multiplayer.multiplayer_peer = peer
	mode = Mode.GUEST
	menu.show_start(Tuning.text("menu.connecting"))
	return ""


func _open_camp(slot_number: int) -> String:
	slot = slot_number
	var loaded := CampSave.load_slot(slot)
	if loaded["error"] != "":
		menu.show_start(Tuning.text(loaded["error"]))
		return loaded["error"]
	var camp: Dictionary = loaded["camp"] if loaded["camp"] != null else CampSave.new_camp()
	state = CampState.new(camp)
	state.join(profile["id"], profile["name"])
	if str(camp.get("host_profile", "")) == "":
		camp["host_profile"] = profile["id"]
	_build_world()
	save_camp()
	return ""


## Leaves the camp: the host or solo player saves first; a guest's character is saved by the host.
## `reason` is a text key shown on the start menu, or "".
func stop(reason: String) -> void:
	if mode == Mode.MENU and state == null:
		menu.show_start(Tuning.text(reason) if reason != "" else "")
		return
	if mode == Mode.SOLO or mode == Mode.HOST:
		_note_own_position()
		save_camp()
	_end_couch()
	_menu_for = ""
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_guests.clear()
	_clear_world()
	state = null
	mode = Mode.MENU
	menu.show_start(Tuning.text(reason) if reason != "" else "")
	stopped.emit(reason)


func save_camp() -> void:
	if state and (mode == Mode.SOLO or mode == Mode.HOST or mode == Mode.MENU):
		CampSave.save(slot, state.camp)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and (mode == Mode.SOLO or mode == Mode.HOST):
		_note_own_position()
		save_camp()


# --- The world ---------------------------------------------------------------------------------------------------

func _build_world() -> void:
	_clear_world()
	for id: String in state.camp["objects"]:
		_spawn_object(id)
	for id: String in state.online:
		_spawn_camper(id)
	_sync_stays(false)
	camera.target = campers.get(profile["id"])
	camera.snap()
	menu.visible = false


func _clear_world() -> void:
	for who: String in _busy.keys():
		_end_busy(who)
	report.visible = false
	for id: String in _building.keys():
		toggle_build(id)
	for node: Node in campers.values() + objects.values() + visitors.values() + _tents.values():
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	campers.clear()
	objects.clear()
	visitors.clear()
	_tents.clear()
	_light_t = -1.0
	camera.target = null


func _spawn_object(id: String) -> void:
	var row: Dictionary = state.camp["objects"][id]
	var node := clearing.place({"model": row["model"], "pos": row["pos"], "yaw": row["yaw"]})
	node.name = id
	objects[id] = node
	_apply_object(id)


## Puts an object's node where the camp says: at its spot, or in its carrier's hands with its collider off.
func _apply_object(id: String) -> void:
	var node: Node3D = objects.get(id)
	if node == null:
		return
	var row: Dictionary = state.camp["objects"][id]
	var carried := state.carriers.has(id)
	if not carried:
		node.transform = Clearing.placement_transform({"pos": row["pos"], "yaw": row["yaw"]})
	for body in node.find_children("*", "StaticBody3D", false, false):
		(body as StaticBody3D).collision_layer = 0 if carried else 1


## Brings an object's node in line with the camp: made, moved, or gone when the camp no longer has it.
func _show_object(id: String) -> void:
	if not state.camp["objects"].has(id):
		if objects.has(id):
			objects[id].queue_free()
			objects.erase(id)
	elif objects.has(id):
		_apply_object(id)
	else:
		_spawn_object(id)


func _spawn_camper(id: String) -> void:
	if campers.has(id):
		return
	var p: Dictionary = state.camp["profiles"][id]
	var c := Camper.new()
	c.name = "Camper_" + id
	c.model_id = str(p["look"]["model"])
	c.display_name = str(p["name"])
	c.controlled = local_ids().has(id)
	c.camera = camera
	c.transform = Clearing.placement_transform({"pos": p["pos"], "yaw": p["yaw"]})
	add_child(c)
	campers[id] = c


func _remove_camper(id: String) -> void:
	if campers.has(id):
		campers[id].queue_free()
		campers.erase(id)


## The players on this PC, player one first.
func local_ids() -> Array[String]:
	var ids: Array[String] = [str(profile.get("id", ""))]
	if couch_id != "":
		ids.append(couch_id)
	return ids


func _note_own_position() -> void:
	if state == null:
		return
	for id in local_ids():
		var me: Camper = campers.get(id)
		if me:
			state.set_player_pos(id, Vector2(me.position.x, me.position.z), rad_to_deg(me.rotation.y))


func _physics_process(delta: float) -> void:
	if state == null:
		return
	_note_own_position()
	var hold := FeltBuilder.vec3(Tuning.value("tuning", "carry.hold_pos"))
	for id: String in state.carriers:
		var carrier: Camper = campers.get(state.carriers[id])
		if carrier and objects.has(id):
			objects[id].transform = carrier.transform * Transform3D(Basis.IDENTITY, hold)
	_send_clock += delta
	if mode in [Mode.HOST, Mode.GUEST] and _send_clock >= 1.0 / maxf(_net("send_rate_hz"), 1.0):
		_send_clock = 0.0
		for id in local_ids():
			var me: Camper = campers.get(id)
			if me:
				for peer: int in ([1] if mode == Mode.GUEST else _guests.keys()):
					_moved.rpc_id(peer, id, me.position, me.rotation.y)


func _process(delta: float) -> void:
	_toast_left -= delta
	if _toast_left <= 0.0:
		$Hud/Toast.text = ""
	_tick_day(delta)
	_tick_busy(delta)
	_update_night(delta)
	var lines: PackedStringArray = []
	if state and not menu.visible and not report.visible:
		for id in local_ids():
			var line := _build_prompt(id) if _building.has(id) else _carry_prompt(id)
			if line == "":
				continue
			line = Prompts.fill(line, _pad if id == profile["id"] else true)
			lines.append(Tuning.text("prompt.for_player") % [state.camp["profiles"][id]["name"], line] \
					if couch_id != "" else line)
		var bed := _bed_line()
		if bed != "":
			lines.append(Prompts.fill(bed, _pad))
	$Hud/Prompt.text = "\n".join(lines)
	$Hud/Clock.text = clock_line() + pockets_lines() if state else ""
	_update_hint()
	if $Hud/Dev.visible:
		_dev_clock -= delta
		if _dev_clock <= 0.0:
			_dev_clock = Tuning.num("tuning", "dev.fps_refresh_s", 0.5)
			var size := get_viewport().get_visible_rect().size
			$Hud/Dev.text = Tuning.text("dev.stats") % [Engine.get_frames_per_second(),
					Tuning.text("quality." + str(profile.get("quality", ""))), "%dx%d" % [get_window().size.x,
					get_window().size.y] if get_window() else "%dx%d" % [size.x, size.y],
					roundi(get_viewport().scaling_3d_scale * 100.0), roundi(_clock_scale())]


## The interact line for a player: what the button does now (action_for), or that they are fishing or grilling.
func _carry_prompt(id: String) -> String:
	if _busy.has(id):
		return Tuning.text("prompt.fishing" if _busy[id]["what"] == "fish" else "prompt.cooking")
	var act := action_for(id)
	match act.get("what", ""):
		"place":
			return Tuning.text("prompt.put_down")
		"pick_up":
			return Tuning.text("prompt.pick_up")
		"fish":
			return Tuning.text("prompt.fish")
		"cook":
			return Tuning.text("prompt.cook") % Tuning.text("items." + str(act["arg"]))
		"give":
			var stay: Dictionary = state.camp["stays"][act["arg"]]
			var item := state.pockets.first_of(id, CampGuests.gift_kind(state.guests.open_request(act["arg"])))
			return Tuning.text("prompt.give") % [stay["name"], Tuning.text("items." + item)]
	return ""


## A short line at the top of the screen. Lines that come close together stack, newest last (data/tuning.json
## hud.toast_lines at most).
func _toast(text: String) -> void:
	if _toast_left > 0.0 and $Hud/Toast.text != "" and $Hud/Toast.text != text:
		var lines: PackedStringArray = (str($Hud/Toast.text) + "\n" + text).split("\n")
		var keep := int(Tuning.num("tuning", "hud.toast_lines", 3))
		text = "\n".join(lines.slice(maxi(lines.size() - keep, 0)))
	$Hud/Toast.text = text
	_toast_left = Tuning.num("tuning", "hud.toast_s", 3.0)


func _update_hint() -> void:
	var text := Prompts.fill(Tuning.text("prompt.controls"), _pad) if state else ""
	if can_drop_in() == "":
		text += "\n" + Prompts.fill(Tuning.text("prompt.drop_in"), true)
	$Hud/Hint.text = text


## Applies a picture preset (data/graphics.json) to every view; `keep` saves it for this PC.
func apply_quality(preset: String, keep: bool = true) -> void:
	if not Quality.names().has(preset):
		preset = str(Quality.names()[0])
	profile["quality"] = preset
	var views: Array[Viewport] = [get_viewport(), couch.second_view()]
	Quality.apply(preset, views, $World.environment, $Sun, couch.split)
	menu.set_quality(Tuning.text("menu.quality") % Tuning.text("quality." + preset))
	if keep:
		LocalProfile.save(profile, _profile_file)


# --- Input -------------------------------------------------------------------------------------------------------

## Sees every controller event before the menus do: a controller player one has not used drops in with the menu
## button; any other controller that player one touches becomes theirs.
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or event.device == couch_pad:
		return
	if event.is_action_pressed("menu") and not _p1_pads.has(event.device) and state != null and not menu.visible:
		var why := drop_in(event.device)
		if why != "couch.not_now":
			if why != "":
				_toast(Tuning.text(why))
			get_viewport().set_input_as_handled()
			return
	if Prompts.device_of(event) == true and not _p1_pads.has(event.device):
		_p1_pads.append(event.device)


## Which local player an event belongs to: the couch player for their controller, player one for everything else.
func owner_of(event: InputEvent) -> String:
	if couch_id != "" and (event is InputEventJoypadButton or event is InputEventJoypadMotion) \
			and event.device == couch_pad:
		return couch_id
	return str(profile.get("id", ""))


func _unhandled_input(event: InputEvent) -> void:
	var who := owner_of(event)
	var pad: Variant = Prompts.device_of(event)
	if pad != null and who == profile.get("id", ""):
		_pad = pad
	if event.is_action_pressed("dev_menu"):
		$Hud/Dev.visible = not $Hud/Dev.visible
		_dev_clock = 0.0
		return
	if state == null:
		return
	if report.visible and not menu.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
			report.visible = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") or (menu.visible and event.is_action_pressed("cancel")):
		_close_menu() if menu.visible else _open_menu(who)
	elif menu.visible:
		return
	elif event.is_action_pressed("build"):
		toggle_build(who)
	elif _building.has(who) and event.is_action_pressed("next_kind"):
		next_kind(who)
	elif _building.has(who) and event.is_action_pressed("rotate"):
		_building[who]["yaw"] = fposmod(float(_building[who]["yaw"]) + 90.0, 360.0)
	elif _building.has(who) and event.is_action_pressed("undo"):
		ask("undo", [], who)
	elif _building.has(who) and event.is_action_pressed("interact"):
		build_here(who)
	elif event.is_action_pressed("interact"):
		interact(who)


func _open_menu(who: String = "") -> void:
	_menu_for = who if who != "" else str(profile["id"])
	var lines: PackedStringArray = []
	for id: String in state.camp["profiles"]:
		var p: Dictionary = state.camp["profiles"][id]
		if bool(p.get("couch", false)) and str(p.get("link_code", "")) != "" \
				and (_menu_for == profile["id"] or id == _menu_for):
			lines.append(Tuning.text("menu.link_info") % [p["name"], CampState.show_code(p["link_code"])])
	menu.set_sleep(state.day.is_evening(), state.day.votes.has(_menu_for), Tuning.text("menu.sleep_closed")
			% time_text(Tuning.num("day", "clock.evening_hour", 18.0)))
	var board := state.guests.current()
	lines.append(Tuning.text("menu.bookings") + ": " + (state.guests.booking_line(board) if not board.is_empty()
			else Tuning.text("menu.board_empty")))
	lines.append_array(state.guests.goals())
	menu.set_booking(str(board.get("state", "")))
	menu.show_pause(_menu_for == couch_id, "\n".join(lines))
	if campers.has(_menu_for):
		campers[_menu_for].controlled = false


func _close_menu() -> void:
	menu.visible = false
	if campers.has(_menu_for):
		campers[_menu_for].controlled = true
	_menu_for = ""


# --- Couch -------------------------------------------------------------------------------------------------------

## "" when a controller could drop in now, or a text key saying why not ("couch.not_now" when couch play does not
## apply at all: no camp, or this PC joined someone else's).
func can_drop_in() -> String:
	if state == null or not (mode == Mode.SOLO or mode == Mode.HOST) or couch_id != "":
		return "couch.not_now"
	if state.online.size() >= int(_net("max_players")):
		return "join.full"
	return ""


## A second controller drops in on this PC as the camp's other character (the one that played here last, or a new
## couch character with a link code). Returns "" or a text key saying why not.
func drop_in(pad: int) -> String:
	var why := can_drop_in()
	if why != "":
		return why
	var id := state.couch_candidate(profile["id"])
	if id == "":
		id = LocalProfile.new_id()
		state.join(id, Tuning.text("profile.couch_name"))
		state.camp["profiles"][id]["couch"] = true
	else:
		state.join(id, "")
	var p: Dictionary = state.camp["profiles"][id]
	if bool(p.get("couch", false)) and str(p.get("link_code", "")) == "":
		p["link_code"] = state.new_link_code()
	couch_id = id
	couch_pad = pad
	_p1_input.taken.assign([pad])
	_spawn_camper(id)
	campers[id].input = PlayerInput.new(pad)
	campers[profile["id"]].input = _p1_input
	var both: Array[Camper] = [campers[profile["id"]], campers[id]]
	couch.follow(both)
	_toast(Tuning.text("toast.dropped_in") % p["name"])
	save_camp()
	return ""


## The couch player leaves this PC; their character, pockets and spot wait in the save. Anything they carried goes
## back to its last spot.
func drop_out(id: String) -> void:
	if id == "" or id != couch_id:
		return
	if _menu_for == id:
		_close_menu()
	_note_own_position()
	for dropped in state.leave(id):
		_apply_object(dropped)
		for guest: int in _guests:
			_object_changed.rpc_id(guest, dropped, state.camp["objects"][dropped], "")
	_remove_camper(id)
	_end_couch()
	if _building.has(id):
		toggle_build(id)
	_toast(Tuning.text("toast.dropped_out") % state.camp["profiles"][id]["name"])
	_share()
	_check_bed()
	save_camp()


func _end_couch() -> void:
	couch_id = ""
	couch_pad = -1
	_p1_input.taken.clear()
	if campers.has(profile.get("id", "")):
		campers[profile["id"]].input = null
	couch.follow([] as Array[Camper])


## A couch controller that goes quiet leaves its camper waiting; the next free controller to connect takes over.
func _on_joy_connection(device: int, connected: bool) -> void:
	if couch_id == "" or not campers.has(couch_id):
		return
	var name: String = state.camp["profiles"][couch_id]["name"]
	if not connected and device == couch_pad:
		_toast(Tuning.text("toast.pad_asleep") % name)
	elif connected and not Input.get_connected_joypads().has(couch_pad) and not _p1_pads.has(device):
		couch_pad = device
		_p1_input.taken.assign([device])
		campers[couch_id].input = PlayerInput.new(device)
		_toast(Tuning.text("toast.pad_back") % name)


# --- Carrying ----------------------------------------------------------------------------------------------------

## The nearest thing a player on this PC (player one by default) could pick up, or "".
func nearest_object(who: String = "") -> String:
	if who == "":
		who = profile["id"]
	var me: Camper = campers.get(who)
	if me == null or state.carried_by(who) != "":
		return ""
	var best := ""
	var best_d := Tuning.num("tuning", "carry.reach_m")
	for id: String in state.camp["objects"]:
		if state.carriers.has(id) or not CampState.can_carry(str(state.camp["objects"][id]["model"])):
			continue
		var d := Vector2(me.position.x, me.position.z).distance_to(state.object_pos(id))
		if d <= best_d:
			best = id
			best_d = d
	return best


## What the interact button does for a player on this PC right now, first that applies: put down what they carry,
## give a guest what they asked for, grill a fish at the fire, pick up the nearest thing, or fish at the water's
## edge. {"what", "arg"}, or {} for nothing.
func action_for(who: String) -> Dictionary:
	var me: Camper = campers.get(who)
	if me == null or _busy.has(who):
		return {}
	if state.carried_by(who) != "":
		return {"what": "place"}
	var at := Vector2(me.position.x, me.position.z)
	state.set_player_pos(who, at, rad_to_deg(me.rotation.y))
	var guest := state.guests.guest_near(who)
	if guest != "" and state.pockets.first_of(who, CampGuests.gift_kind(state.guests.open_request(guest))) != "":
		return {"what": "give", "arg": guest}
	if CampPockets.can_cook_at(at) and state.pockets.first_of(who, "fish") != "":
		return {"what": "cook", "arg": state.pockets.first_of(who, "fish")}
	if nearest_object(who) != "":
		return {"what": "pick_up", "arg": nearest_object(who)}
	if CampPockets.can_fish_at(at):
		return {"what": "fish"}
	return {}


## The interact button of a player on this PC (player one by default): see action_for. Fishing and grilling take a
## moment first (data/fishing.json cast_s, cook_s) while the camper stands still.
func interact(who: String = "") -> void:
	if who == "":
		who = profile["id"]
	var me: Camper = campers.get(who)
	var act := action_for(who)
	if me == null or act.is_empty():
		return
	match act["what"]:
		"place":
			var spot := me.position - me.transform.basis.z * Tuning.num("tuning", "carry.place_distance_m")
			ask("place", [Vector2(spot.x, spot.z), rad_to_deg(me.rotation.y)], who)
		"pick_up":
			ask("pick_up", [act["arg"]], who)
		"give":
			ask("give", [act["arg"]], who)
		"fish", "cook":
			_start_busy(who, act["what"])


func _start_busy(who: String, what: String) -> void:
	var me: Camper = campers[who]
	var bobber: Node3D = null
	if what == "fish":
		bobber = clearing.place({"model": "bobber", "pos": [0, 0]})
		var ahead := me.position - me.transform.basis.z * Tuning.num("fishing", "cast_m", 1.6)
		bobber.position = Vector3(ahead.x, 0.0, ahead.z)
	me.controlled = false
	me.velocity = Vector3.ZERO
	_busy[who] = {"what": what, "left": Tuning.num("fishing", "cast_s" if what == "fish" else "cook_s", 2.0),
			"bobber": bobber}


## Counts down fishing and grilling; at the end the host is asked for the catch or the meal.
func _tick_busy(delta: float) -> void:
	for who: String in _busy.keys():
		var b: Dictionary = _busy[who]
		b["left"] = float(b["left"]) - delta
		var bobber: Node3D = b["bobber"]
		if bobber:
			bobber.position.y = sin(float(b["left"]) * TAU) * 0.03
		if float(b["left"]) <= 0.0:
			_end_busy(who)
			ask(str(b["what"]), [], who)


func _end_busy(who: String) -> void:
	var b: Dictionary = _busy.get(who, {})
	_busy.erase(who)
	if b.get("bobber") and is_instance_valid(b["bobber"]):
		b["bobber"].get_parent().remove_child(b["bobber"])
		b["bobber"].queue_free()
	if campers.has(who) and _menu_for != who:
		campers[who].controlled = true


## Asks for a change to the camp for a player on this PC: the host decides at once; a guest sends the request to
## the host.
func ask(what: String, args: Array, who: String = "") -> void:
	_note_own_position()
	if mode == Mode.GUEST:
		_request.rpc_id(1, what, args)
	else:
		_decide(who if who != "" else str(profile["id"]), what, args, 0)


# --- Host decisions and messages ---------------------------------------------------------------------------------

func _decide(profile_id: String, what: String, args: Array, peer: int) -> void:
	var id := ""
	var why := "deny.not_movable"
	if what == "pick_up" and args.size() == 1 and args[0] is String:
		id = args[0]
		why = state.pick_up(profile_id, id)
	elif what == "place" and args.size() == 2 and args[0] is Vector2 and (args[1] is float or args[1] is int):
		id = state.carried_by(profile_id)
		why = state.place(profile_id, args[0], float(args[1]))
	elif what == "build" and args.size() == 3 and args[0] is String and args[1] is Vector2 \
			and (args[2] is float or args[2] is int):
		why = state.build.build(profile_id, args[0], args[1], float(args[2]))
		id = state.build.last_id
	elif what == "pack" and args.size() == 1 and args[0] is String:
		why = state.build.pack(profile_id, args[0])
		id = state.build.last_id
	elif what == "undo" and args.is_empty():
		why = state.build.undo_last(profile_id)
		id = state.build.last_id
	elif what == "sleep" and args.size() == 1 and args[0] is bool:
		why = state.day.vote(profile_id, args[0])
	elif what == "fish" and args.is_empty():
		why = state.pockets.fish(profile_id)
	elif what == "cook" and args.is_empty():
		why = state.pockets.cook(profile_id)
	elif what == "give" and args.size() == 1 and args[0] is String:
		why = state.guests.give(profile_id, args[0])
	elif what == "booking" and args.size() == 2 and args[0] is String and args[1] is String:
		why = state.guests.decide(profile_id, args[0], args[1])
	if why != "":
		if peer == 0:
			_toast(Tuning.text(why))
		else:
			_denied.rpc_id(peer, why)
		return
	if what in ["sleep", "fish", "cook", "give", "booking"]:
		match what:
			"fish": _say(peer, "toast.caught", [Tuning.text("items." + state.pockets.last_item)])
			"cook": _say(peer, "toast.grilled", [Tuning.text("items." + state.pockets.last_item)])
			"give":
				_say_all("toast.thanks", [state.camp["stays"][args[0]]["name"], state.guests.last_tip])
				_sync_stays(false)
			"booking":
				var r := state.guests.row(args[0])
				var key: String = "toast.booking_" + {"accept": "accepted", "later": "later", "decline": "declined"}[args[1]]
				_say_all(key, [Tuning.text("booking.%s.name" % args[0]), CampGuests.day_label(int(r["arrive_day"]))])
		_share()
		if what == "sleep":
			_check_bed()
		else:
			save_camp()
		return
	if what == "place":
		for met in state.guests.check_near_requests():
			_say_all("toast.thanks", [state.camp["stays"][met]["name"], state.guests.last_tip])
		_sync_stays(false)
	_show_object(id)
	for guest: int in _guests:
		if state.camp["objects"].has(id):
			_object_changed.rpc_id(guest, id, state.camp["objects"][id], state.carriers.get(id, ""))
		else:
			_object_removed.rpc_id(guest, id)
	if what in ["build", "pack", "undo", "place"]:
		_share()
	save_camp()


## A guest's PC says hello. With a link code it claims that couch character (taking it off this PC's couch if it is
## playing here now), and from then on that PC plays it under the same profile ID.
@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, profile_id: String, display_name: String, link_code: String) -> void:
	if mode != Mode.HOST:
		return
	var peer := multiplayer.get_remote_sender_id()
	var why := ""
	var linked := link_code != ""
	if protocol != int(_net("protocol")):
		why = "join.wrong_version"
	elif linked:
		profile_id = state.find_link(link_code)
		if profile_id == "":
			why = "join.bad_link"
		elif profile_id == couch_id:
			drop_out(couch_id)
	if why == "":
		if state.online.size() >= int(_net("max_players")):
			why = "join.full"
		elif state.online.has(profile_id) or not profile_id.begins_with("p_"):
			why = "join.already_here"
	if why != "":
		_refused.rpc_id(peer, why)
		return
	_guests[peer] = profile_id
	state.join(profile_id, "" if linked else display_name.left(32))
	if linked:
		state.camp["profiles"][profile_id]["couch"] = false
		state.camp["profiles"][profile_id]["link_code"] = ""
	_spawn_camper(profile_id)
	_welcome.rpc_id(peer, state.snapshot(), profile_id)
	_toast(Tuning.text("toast.joined") % state.camp["profiles"][profile_id]["name"])
	save_camp()


## The host lets this PC in, as `your_id`: this PC's own profile, or the couch character its link code claimed.
@rpc("authority", "call_remote", "reliable")
func _welcome(snap: Dictionary, your_id: String) -> void:
	state = CampState.from_snapshot(snap)
	if your_id != profile["id"] and state.camp["profiles"].has(your_id):
		profile["id"] = your_id
		profile["name"] = str(state.camp["profiles"][your_id]["name"])
		menu.name_edit.text = profile["name"]
		menu.link_edit.text = ""
		LocalProfile.save(profile, _profile_file)
		_toast(Tuning.text("toast.linked") % profile["name"])
	_build_world()
	started.emit()


@rpc("authority", "call_remote", "reliable")
func _refused(why: String) -> void:
	stop.call_deferred(why)


@rpc("any_peer", "call_remote", "reliable")
func _request(what: String, args: Array) -> void:
	var profile_id: String = _guests.get(multiplayer.get_remote_sender_id(), "")
	if mode == Mode.HOST and profile_id != "":
		_decide(profile_id, what, args, multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _object_changed(id: String, row: Dictionary, carrier: String) -> void:
	if state == null:
		return
	state.camp["objects"][id] = row
	if carrier != "":
		state.carriers[id] = carrier
	else:
		state.carriers.erase(id)
	if not objects.has(id):
		_spawn_object(id)
	_apply_object(id)


@rpc("authority", "call_remote", "reliable")
func _object_removed(id: String) -> void:
	if state != null:
		state.camp["objects"].erase(id)
		state.carriers.erase(id)
		_show_object(id)


@rpc("authority", "call_remote", "reliable")
func _denied(why: String) -> void:
	_toast(Tuning.text(why))


## Host: a line for the player who asked (this PC when `peer` is 0), from a text key filled with `args`.
func _say(peer: int, key: String, args: Array) -> void:
	if peer == 0:
		_told(key, args)
	else:
		_told.rpc_id(peer, key, args)


## Host: a line for both PCs.
func _say_all(key: String, args: Array) -> void:
	_told(key, args)
	for guest: int in _guests:
		_told.rpc_id(guest, key, args)


@rpc("authority", "call_remote", "reliable")
func _told(key: String, args: Array) -> void:
	_toast(Tuning.text(key) % args if not args.is_empty() else Tuning.text(key))


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _moved(profile_id: String, pos: Vector3, yaw: float) -> void:
	if state == null or local_ids().has(profile_id):
		return
	var sender := multiplayer.get_remote_sender_id()
	if (mode == Mode.HOST and _guests.get(sender, "") != profile_id) or (mode == Mode.GUEST and sender != 1):
		return
	state.set_player_pos(profile_id, Vector2(pos.x, pos.z), rad_to_deg(yaw))
	var c: Camper = campers.get(profile_id)
	if c:
		c.remote_target = pos
		c.remote_yaw = yaw


func _on_connected() -> void:
	_hello.rpc_id(1, int(_net("protocol")), str(profile["id"]), str(profile["name"]), _link_code)


func _on_peer_disconnected(peer: int) -> void:
	if mode != Mode.HOST or not _guests.has(peer):
		return
	var id: String = _guests[peer]
	_guests.erase(peer)
	for dropped in state.leave(id):
		_apply_object(dropped)
	_remove_camper(id)
	_toast(Tuning.text("toast.left") % state.camp["profiles"][id]["name"])
	_check_bed()
	save_camp()


# --- Stage A: the day, guests and the night ----------------------------------------------------------------------

## How fast the clock runs: faster while the F1 dev panel is open on the host (data/tuning.json dev.clock_scale).
func _clock_scale() -> float:
	return Tuning.num("tuning", "dev.clock_scale", 1.0) if $Hud/Dev.visible and mode != Mode.GUEST else 1.0


## Moves the clock on. The host's clock is the true one: it waits while the menu is open with no guest PC in, lets a
## guest come to a free pitch, and tells a guest PC the time now and then. A guest PC runs its clock in between.
func _tick_day(delta: float) -> void:
	if state == null:
		return
	if mode == Mode.GUEST:
		state.day.advance(delta)
	else:
		if not (_guests.is_empty() and (menu.visible or report.visible)):
			state.day.advance(delta * _clock_scale())
		var offered := state.guests.refresh_offers()
		var came := state.day.arrivals()
		for id in offered:
			_say_all("toast.booking_offer", [Tuning.text("booking.%s.name" % id)])
		var booked := {}
		for stay in came:
			var row: Dictionary = state.camp["stays"][stay]
			if row.has("booking"):
				booked[row["booking"]] = true
			else:
				_say_all("guest.arrived", [row["name"], Tuning.text("build." + CampBuild.kind_of(state, row["pitch"]))])
		for id: String in booked:
			_say_all("toast.booking_arrived", [Tuning.text("booking.%s.name" % id)])
		if not came.is_empty():
			for met in state.guests.check_near_requests():
				_say_all("toast.thanks", [state.camp["stays"][met]["name"], state.guests.last_tip])
		if not (came.is_empty() and offered.is_empty()):
			_sync_stays(true)
			_share()
			save_camp()
		_clock_send += delta
		if mode == Mode.HOST and _clock_send >= 1.0 / maxf(Tuning.num("day", "clock.send_hz", 1.0), 0.1):
			_clock_send = 0.0
			for guest: int in _guests:
				_clock.rpc_id(guest, state.camp["calendar"])
	var t := clampf(inverse_lerp(Tuning.num("day", "light.dusk_from_hour"), Tuning.num("day", "light.dusk_full_hour"),
			state.day.hour()), 0.0, 1.0)
	if absf(t - _light_t) > 0.004:
		_light_t = t
		var order := LightMoods.names()
		LightMoods.blend(str(order[0]), str(order[1]), t, $Sun, $World.environment, clearing.fire_lights)


## A time of day as the clock shows it, such as "6:00 pm".
static func time_text(hour: float) -> String:
	var h := int(floor(hour))
	var m := int(floor((hour - h) * 60.0))
	var pm := h >= 12
	h = h % 12
	return Tuning.text("clock.time") % [12 if h == 0 else h, m, Tuning.text("clock.pm" if pm else "clock.am")]


## The top-right line: season, day, time and coins.
func clock_line() -> String:
	var cal: Dictionary = state.camp["calendar"]
	return Tuning.text("clock.line") % [Tuning.text("clock.season." + str(cal.get("season", "spring"))),
			int(cal.get("day", 1)), time_text(state.day.hour()), int(state.camp.get("coins", 0))]


## Under the clock: what each local player carries in their pockets, or "" when they are empty.
func pockets_lines() -> String:
	var out := ""
	for id in local_ids():
		var names: PackedStringArray = []
		for item in (state.pockets.pockets(id) if state.camp["profiles"].has(id) else []):
			names.append(Tuning.text("items." + str(item)))
		if not names.is_empty():
			out += "\n" + (Tuning.text("prompt.pockets_for") % [state.camp["profiles"][id]["name"], ", ".join(names)]
					if couch_id != "" else Tuning.text("prompt.pockets") % ", ".join(names))
	return out


## The bed line under the prompts: who is ready for bed, or that bed is open.
func _bed_line() -> String:
	var votes := state.day.votes
	if not votes.is_empty():
		var names: PackedStringArray = []
		for id in votes:
			names.append(str(state.camp["profiles"].get(id, {}).get("name", "")))
		return Tuning.text("prompt.sleep_wait") % [", ".join(names), votes.size(), state.online.size()]
	return Tuning.text("prompt.bed_open") if state.day.is_evening() else ""


## Host: when everyone in the camp is ready for bed, the night pays once, the guest PC is told, and the camp saves.
func _check_bed() -> void:
	if state == null or mode == Mode.GUEST or not state.day.everyone_ready():
		return
	var summary := state.day.settle_night()
	if summary.is_empty():
		return
	save_camp()
	for guest: int in _guests:
		_night.rpc_id(guest, summary, state.shared())
	_show_night(summary)


## The night as both PCs see it: a short fade, then the morning report (what the night paid, each guest's line,
## the bookings and the day's goals) until a player starts the day.
func _show_night(summary: Dictionary) -> void:
	_night_left = Tuning.num("day", "night.fade_s") * 2.0 + Tuning.num("day", "night.hold_s")
	$Hud/Night.visible = true
	for who: String in _busy.keys():
		_end_busy(who)
	report.show_report(morning_report(summary), Prompts.fill(Tuning.text("prompt.report_close"), _pad))
	_sync_stays(false)


## The morning report's text for a night's summary, read against the camp as it is this morning.
func morning_report(summary: Dictionary) -> String:
	var cal: Dictionary = state.camp["calendar"]
	var lines: PackedStringArray = [Tuning.text("report.morning") % [Tuning.text("clock.season." + str(cal["season"])),
			int(cal["day"])], ""]
	if (summary.get("lines", []) as Array).is_empty():
		lines.append(Tuning.text("report.quiet"))
	else:
		lines.append(Tuning.text("report.earned") % int(summary["coins"]))
	for line: Dictionary in summary.get("lines", []):
		lines.append(Tuning.text("report.paid") % [line["name"], int(line["coins"]), Tuning.text("build." + str(line["kind"]))])
	for r: Dictionary in summary.get("reviews", []):
		var text := Tuning.text("report.review") % [r["name"], Tuning.text("mood." + str(r["mood"])),
				Tuning.text("cause.loved." + str(r["loved"]))] if str(r["loved"]) != "" else \
				Tuning.text("report.review_none") % [r["name"], Tuning.text("mood." + str(r["mood"]))]
		if str(r["wished"]) != "":
			text += Tuning.text("report.wish") % Tuning.text("cause.wished." + str(r["wished"]))
		if int(r["tip"]) > 0:
			text += Tuning.text("report.tip") % int(r["tip"])
		lines.append(text)
	for b: Dictionary in summary.get("bonuses", []):
		if int(b["coins"]) > 0:
			var extras: PackedStringArray = []
			for e in b["extras"]:
				extras.append(Tuning.text("build." + str(e)))
			lines.append(Tuning.text("report.bonus") % [Tuning.text("booking.%s.name" % b["id"]), ", ".join(extras),
					int(b["coins"])])
	lines.append("")
	lines.append(Tuning.text("report.bookings"))
	var any := false
	for r: Dictionary in state.camp["reservations"]:
		if r.get("state", "") in ["offered", "accepted", "arrived"]:
			lines.append(state.guests.booking_line(r))
			any = true
	if not any:
		lines.append(Tuning.text("report.none"))
	lines.append("")
	lines.append(Tuning.text("report.today"))
	lines.append_array(state.guests.goals())
	return "\n".join(lines)


func _update_night(delta: float) -> void:
	if _night_left <= 0.0:
		return
	_night_left -= delta
	var fade := maxf(Tuning.num("day", "night.fade_s"), 0.01)
	var total := fade * 2.0 + Tuning.num("day", "night.hold_s")
	var since := total - _night_left
	$Hud/Night.color.a = clampf(minf(since / fade, _night_left / fade), 0.0, 1.0)
	if _night_left <= 0.0:
		$Hud/Night.visible = false


## Guests on screen follow the camp's stays: a new guest walks in from the camp's entry (or stands at the pitch when
## `walk_in` is false), puts up a tent when they reach it, and a guest whose stay is over walks home.
func _sync_stays(walk_in: bool) -> void:
	var stays: Dictionary = state.camp["stays"]
	for id: String in visitors.keys():
		if not stays.has(id):
			_send_home(id)
	var entry: Array = Tuning.value("day", "stays.entry", [0, 10])
	for id: String in stays:
		if visitors.has(id):
			var label: Label3D = visitors[id].get_node_or_null("Name")
			if label:
				label.text = guest_label(id)
			continue
		if not state.camp["objects"].has(stays[id].get("pitch", "")):
			continue
		var c := Camper.new()
		c.name = "Guest_" + id
		c.model_id = str(stays[id]["look"])
		c.display_name = guest_label(id)
		c.walk_speed = Tuning.num("day", "stays.walk_speed_mps", 1.5)
		var stand := state.day.stand_point(id)
		if walk_in:
			c.position = Vector3(float(entry[0]), 0.0, float(entry[1]))
			c.walk_target = Vector3(stand.x, 0.0, stand.y)
			c.arrived.connect(_pitch_tent.bind(id), CONNECT_ONE_SHOT)
		else:
			c.position = Vector3(stand.x, 0.0, stand.y)
		add_child(c)
		visitors[id] = c
		if not walk_in:
			_pitch_tent(id)


## A guest who reached their pitch puts up their tent and turns to it.
func _pitch_tent(id: String) -> void:
	if state == null or not state.camp["stays"].has(id) or _tents.has(id):
		return
	var pitch: Dictionary = state.camp["objects"].get(state.camp["stays"][id]["pitch"], {})
	if pitch.is_empty():
		return
	var tent := clearing.place({"model": "tent_guest", "pos": pitch["pos"], "yaw": pitch["yaw"]})
	_tents[id] = tent
	var c: Camper = visitors.get(id)
	if c:
		var to := tent.position - c.position
		c.rotation.y = atan2(-to.x, -to.z)


## A guest's name, with their request under it while it is open.
func guest_label(stay_id: String) -> String:
	var stay: Dictionary = state.camp["stays"][stay_id]
	var kind := state.guests.open_request(stay_id)
	return str(stay["name"]) + ("\n" + Tuning.text("request.say." + kind) if kind != "" else "")


func _send_home(id: String) -> void:
	var c: Camper = visitors[id]
	visitors.erase(id)
	if _tents.has(id):
		_tents[id].queue_free()
		_tents.erase(id)
	var entry: Array = Tuning.value("day", "stays.entry", [0, 10])
	c.walk_target = Vector3(float(entry[0]), 0.0, float(entry[1]))
	for link in c.arrived.get_connections():
		c.arrived.disconnect(link["callable"])
	c.arrived.connect(c.queue_free)


func _share() -> void:
	for guest: int in _guests:
		_shared.rpc_id(guest, state.shared())


## The host's shared day: coins, the calendar, the guests and who is ready for bed.
@rpc("authority", "call_remote", "reliable")
func _shared(data: Dictionary) -> void:
	if state != null:
		state.apply_shared(data)
		_sync_stays(true)


@rpc("authority", "call_remote", "unreliable_ordered")
func _clock(calendar: Dictionary) -> void:
	if state != null:
		state.camp["calendar"] = calendar


@rpc("authority", "call_remote", "reliable")
func _night(summary: Dictionary, data: Dictionary) -> void:
	if state != null:
		state.apply_shared(data)
		_show_night(summary)


# --- Stage A: building on the grid -------------------------------------------------------------------------------

## Build mode on or off for a player on this PC. In build mode a ghost of the building sits on the grid in front of
## them; interact builds it there (or packs away the building under it), rotate turns it, undo takes back their last
## step.
func toggle_build(who: String, kind: String = "") -> void:
	if _building.has(who):
		var ghost: Node3D = _building[who]["ghost"]
		if is_instance_valid(ghost):
			remove_child(ghost)
			ghost.queue_free()
		_building.erase(who)
		return
	if state == null or not campers.has(who):
		return
	if state.carried_by(who) != "":
		_toast(Tuning.text("deny.hands_full"))
		return
	if kind == "":
		kind = str(CampBuild.kinds().keys()[0])
	var ghost := Node3D.new()
	ghost.name = "Ghost_" + who
	var mesh := FeltBuilder.build(str(CampBuild.kinds()[kind]["model"]))
	mesh.set_instance_shader_parameter("fade", Tuning.num("build", "ghost.fade", 0.35))
	ghost.add_child(mesh)
	var tile := MeshInstance3D.new()
	var box := BoxMesh.new()
	var size := CampBuild.footprint(kind, 0.0)
	box.size = Vector3(size.x, Tuning.num("build", "ghost.thick_m", 0.02), size.y)
	tile.mesh = box
	tile.position.y = Tuning.num("build", "ghost.lift_m", 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tile.material_override = mat
	ghost.add_child(tile)
	add_child(ghost)
	_building[who] = {"kind": kind, "yaw": 0.0, "ghost": ghost, "tile": tile}
	_place_ghost(who)


## Build mode on the next kind of building (data/build.json kinds, in order), keeping the turn.
func next_kind(who: String) -> void:
	if not _building.has(who):
		return
	var kinds := CampBuild.kinds().keys()
	var kind := str(kinds[(kinds.find(_building[who]["kind"]) + 1) % kinds.size()])
	var yaw := float(_building[who]["yaw"])
	toggle_build(who)
	toggle_build(who, kind)
	_building[who]["yaw"] = yaw


## The grid spot in front of a building player.
func build_spot(who: String) -> Vector2:
	var me: Camper = campers[who]
	var ahead := me.position - me.transform.basis.z * Tuning.num("build", "ahead_m", 2.6)
	return CampBuild.snap(Vector2(ahead.x, ahead.z))


## Moves a player's ghost to their grid spot and tints it: ok to build (or a building to pack away), or blocked.
func _place_ghost(who: String) -> String:
	var b: Dictionary = _building[who]
	var spot := build_spot(who)
	var existing := state.build.building_at(spot)
	var why := ""
	if existing == "":
		why = state.build.check(b["kind"], spot, b["yaw"])
		if why == "" and int(state.camp.get("coins", 0)) < CampBuild.cost(b["kind"]):
			why = "deny.coins"
	var ghost: Node3D = b["ghost"]
	ghost.position = Vector3(spot.x, 0.0, spot.y)
	ghost.rotation.y = deg_to_rad(float(b["yaw"]))
	ghost.get_child(0).visible = existing == ""
	var tint := FeltBuilder.swatch(str(Tuning.value("build", "ghost.ok" if why == "" else "ghost.blocked")))
	tint.a = Tuning.num("build", "ghost.alpha", 0.45)
	(b["tile"].material_override as StandardMaterial3D).albedo_color = tint
	return why


func _build_prompt(who: String) -> String:
	var b: Dictionary = _building[who]
	var why := _place_ghost(who)
	var existing := state.build.building_at(build_spot(who))
	var kind_name := Tuning.text("build." + str(b["kind"]))
	if existing != "":
		return Tuning.text("prompt.pack_here") % [Tuning.text("build." + CampBuild.kind_of(state, existing)),
				CampBuild.cost(CampBuild.kind_of(state, existing))]
	if why != "":
		return Tuning.text("prompt.build_blocked") % Tuning.text(why)
	return Tuning.text("prompt.build_here") % [kind_name, CampBuild.cost(b["kind"])]


## Interact in build mode: pack away the building under the ghost, or build there.
func build_here(who: String) -> void:
	if not _building.has(who):
		return
	var spot := build_spot(who)
	var existing := state.build.building_at(spot)
	if existing != "":
		ask("pack", [existing], who)
	else:
		ask("build", [str(_building[who]["kind"]), spot, float(_building[who]["yaw"])], who)
