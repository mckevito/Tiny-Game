extends Node3D
## The camp: the game scene for Milestone 2. Play alone, host a camp for a friend's PC, or join one (Godot's ENet
## multiplayer; data/net.json). Two players in total. The host's CampState decides every change to the shared camp:
## a guest asks with _request and the host answers with _object_changed or _denied. Each player steers their own
## camper and tells the other PC where it is. Characters belong to profile IDs, never connection IDs.
## Command line: -- --solo | --host | --join=ADDRESS, plus --slot=N and --profile=NAME (a second local player file).

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
var _profile_file := ""
var _send_clock := 0.0
var _pad := false
var _toast_left := 0.0

@onready var clearing: Clearing = $Clearing
@onready var camera: PlayCamera = $PlayCamera
@onready var menu: CampMenu = $Hud/Menu


func _ready() -> void:
	LightMoods.apply("day", $Sun, $World.environment, clearing.fire_lights)
	menu.chose.connect(_on_menu)
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
	_update_hint()
	if args.has("slot"):
		menu.slot_pick.select(clampi(int(args["slot"]) - 1, 0, CampSave.slot_count() - 1))
	if args.has("solo"):
		start_solo(menu.slot())
	elif args.has("host"):
		start_host(menu.slot())
	elif args.has("join"):
		start_join(str(args["join"]))


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
		"join": start_join(menu.address_edit.text.strip_edges())
		"resume": _close_menu()
		"leave": stop("")
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


## Knocks on a friend's camp. `started` follows when the host says welcome; `stopped` if not.
func start_join(address: String, port: int = 0) -> String:
	if address == "":
		menu.show_start(Tuning.text("join.no_address"))
		return "join.no_address"
	profile["last_address"] = address
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
	_update_hint()


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
	c.controlled = id == profile["id"]
	c.camera = camera
	c.transform = Clearing.placement_transform({"pos": p["pos"], "yaw": p["yaw"]})
	add_child(c)
	campers[id] = c


func _remove_camper(id: String) -> void:
	if campers.has(id):
		campers[id].queue_free()
		campers.erase(id)


func _note_own_position() -> void:
	var me: Camper = campers.get(profile.get("id", ""))
	if me and state:
		state.set_player_pos(profile["id"], Vector2(me.position.x, me.position.z), rad_to_deg(me.rotation.y))


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
		var me: Camper = campers.get(profile["id"])
		if me:
			for peer: int in ([1] if mode == Mode.GUEST else _guests.keys()):
				_moved.rpc_id(peer, profile["id"], me.position, me.rotation.y)


func _process(delta: float) -> void:
	_toast_left -= delta
	if _toast_left <= 0.0:
		$Hud/Toast.text = ""
	var key := ""
	if state and not menu.visible:
		key = "prompt.put_down" if state.carried_by(profile["id"]) != "" else \
				("prompt.pick_up" if nearest_object() != "" else "")
	$Hud/Prompt.text = Prompts.fill(Tuning.text(key), _pad) if key != "" else ""


func _toast(text: String) -> void:
	$Hud/Toast.text = text
	_toast_left = Tuning.num("tuning", "hud.toast_s", 3.0)


func _update_hint() -> void:
	$Hud/Hint.text = Prompts.fill(Tuning.text("prompt.controls"), _pad) if state else ""


# --- Input -------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pad: Variant = Prompts.device_of(event)
	if pad != null and pad != _pad:
		_pad = pad
		_update_hint()
	if state == null:
		return
	if event.is_action_pressed("menu") or (menu.visible and event.is_action_pressed("cancel")):
		_close_menu() if menu.visible else _open_menu()
	elif not menu.visible and event.is_action_pressed("interact"):
		interact()


func _open_menu() -> void:
	menu.show_pause()
	if campers.has(profile["id"]):
		campers[profile["id"]].controlled = false


func _close_menu() -> void:
	menu.visible = false
	if campers.has(profile["id"]):
		campers[profile["id"]].controlled = true


## The nearest thing this player could pick up, or "".
func nearest_object() -> String:
	var me: Camper = campers.get(profile["id"])
	if me == null or state.carried_by(profile["id"]) != "":
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


## The interact button: put down what this player carries in front of them, or pick up the nearest thing.
func interact() -> void:
	var me: Camper = campers.get(profile["id"])
	if me == null:
		return
	if state.carried_by(profile["id"]) != "":
		var spot := me.position - me.transform.basis.z * Tuning.num("tuning", "carry.place_distance_m")
		ask("place", [Vector2(spot.x, spot.z), rad_to_deg(me.rotation.y)])
	elif nearest_object() != "":
		ask("pick_up", [nearest_object()])


## Asks for a change to the camp: the host decides at once; a guest sends the request to the host.
func ask(what: String, args: Array) -> void:
	_note_own_position()
	if mode == Mode.GUEST:
		_request.rpc_id(1, what, args)
	else:
		_decide(profile["id"], what, args, 0)


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


@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, profile_id: String, display_name: String) -> void:
	if mode != Mode.HOST:
		return
	var peer := multiplayer.get_remote_sender_id()
	var why := ""
	if protocol != int(_net("protocol")):
		why = "join.wrong_version"
	elif state.online.size() >= int(_net("max_players")):
		why = "join.full"
	elif state.online.has(profile_id) or not profile_id.begins_with("p_"):
		why = "join.already_here"
	if why != "":
		_refused.rpc_id(peer, why)
		return
	_guests[peer] = profile_id
	state.join(profile_id, display_name.left(32))
	_spawn_camper(profile_id)
	_welcome.rpc_id(peer, state.snapshot())
	_toast(Tuning.text("toast.joined") % state.camp["profiles"][profile_id]["name"])
	save_camp()


@rpc("authority", "call_remote", "reliable")
func _welcome(snap: Dictionary) -> void:
	state = CampState.from_snapshot(snap)
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
	if state == null or profile_id == profile["id"]:
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
	_hello.rpc_id(1, int(_net("protocol")), str(profile["id"]), str(profile["name"]))


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
