extends Node3D
## The camp: the game scene. Play alone, host a camp for a friend's PC, or join one (Godot's ENet multiplayer;
## data/net.json). Two players in total, both on this PC (couch) or one on each PC. The host's CampState decides every
## change to the shared camp: a guest asks with _request and the host answers with _object_changed or _denied. Each
## PC steers its own campers and tells the other PC where they are. Characters belong to profile IDs, never
## connection IDs.
## Couch (Milestone 3): a controller player one has not used drops in with the menu button and drops out from its
## menu; the couch character lives in the host's save and its link code lets its own PC claim it later.
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

@onready var clearing: Clearing = $Clearing
@onready var camera: PlayCamera = $PlayCamera
@onready var menu: CampMenu = $Hud/Menu
@onready var couch: CouchView = $Couch


func _ready() -> void:
	LightMoods.apply("day", $Sun, $World.environment, clearing.fire_lights)
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
	camera.target = campers.get(profile["id"])
	camera.snap()
	menu.visible = false


func _clear_world() -> void:
	for node: Node in campers.values() + objects.values():
		node.get_parent().remove_child(node)
		node.queue_free()
	campers.clear()
	objects.clear()
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
	var lines: PackedStringArray = []
	if state and not menu.visible:
		for id in local_ids():
			var key := "prompt.put_down" if state.carried_by(id) != "" else \
					("prompt.pick_up" if nearest_object(id) != "" else "")
			if key == "":
				continue
			var line := Prompts.fill(Tuning.text(key), _pad if id == profile["id"] else true)
			lines.append(Tuning.text("prompt.for_player") % [state.camp["profiles"][id]["name"], line] \
					if couch_id != "" else line)
	$Hud/Prompt.text = "\n".join(lines)
	_update_hint()
	if $Hud/Dev.visible:
		_dev_clock -= delta
		if _dev_clock <= 0.0:
			_dev_clock = Tuning.num("tuning", "dev.fps_refresh_s", 0.5)
			var size := get_viewport().get_visible_rect().size
			$Hud/Dev.text = Tuning.text("dev.stats") % [Engine.get_frames_per_second(),
					Tuning.text("quality." + str(profile.get("quality", ""))), "%dx%d" % [get_window().size.x,
					get_window().size.y] if get_window() else "%dx%d" % [size.x, size.y],
					roundi(get_viewport().scaling_3d_scale * 100.0)]


func _toast(text: String) -> void:
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
	if event.is_action_pressed("menu") or (menu.visible and event.is_action_pressed("cancel")):
		_close_menu() if menu.visible else _open_menu(who)
	elif not menu.visible and event.is_action_pressed("interact"):
		interact(who)


func _open_menu(who: String = "") -> void:
	_menu_for = who if who != "" else str(profile["id"])
	var lines: PackedStringArray = []
	for id: String in state.camp["profiles"]:
		var p: Dictionary = state.camp["profiles"][id]
		if bool(p.get("couch", false)) and str(p.get("link_code", "")) != "" \
				and (_menu_for == profile["id"] or id == _menu_for):
			lines.append(Tuning.text("menu.link_info") % [p["name"], CampState.show_code(p["link_code"])])
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
	_toast(Tuning.text("toast.dropped_out") % state.camp["profiles"][id]["name"])
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


## The interact button of a player on this PC (player one by default): put down what they carry in front of them,
## or pick up the nearest thing.
func interact(who: String = "") -> void:
	if who == "":
		who = profile["id"]
	var me: Camper = campers.get(who)
	if me == null:
		return
	if state.carried_by(who) != "":
		var spot := me.position - me.transform.basis.z * Tuning.num("tuning", "carry.place_distance_m")
		ask("place", [Vector2(spot.x, spot.z), rad_to_deg(me.rotation.y)], who)
	elif nearest_object(who) != "":
		ask("pick_up", [nearest_object(who)], who)


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
	if why != "":
		if peer == 0:
			_toast(Tuning.text(why))
		else:
			_denied.rpc_id(peer, why)
		return
	_apply_object(id)
	for guest: int in _guests:
		_object_changed.rpc_id(guest, id, state.camp["objects"][id], state.carriers.get(id, ""))
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
func _denied(why: String) -> void:
	_toast(Tuning.text(why))


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
	save_camp()
