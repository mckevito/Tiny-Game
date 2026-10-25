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
## Stage B: guests' small requests, fishing at the pond and grilling at the fire (CampPack), two improvements to
## build, the booking board in the menu, satisfaction lines and the morning report (CampGuests, CampReport).
## Stage B round 2: the Today list (CampTasks) whose firsts teach day 1, chopping the clearing's trees and picking up
## what the forage spots hold (CampGather), the log bench built from wood, felt animals to spot (Wildlife), and the
## morning report's line about tomorrow, and each player's clipboard (Today, Bookings, Supplies; Clipboard).
## Round 3: each player's Pack of stacks (drop one as a bundle), the camp box for materials, and the workbench that
## crafts into the shared build kit build mode places from.
## Round 4: like Animal Crossing, the Pack opens as a grid (PackPanel), and a corner dock (HudDock) shows the tool in
## hand (cycled with next tool; chopping needs the axe, fishing the rod) and the build piece picked (next kind).
## First-minutes round: the camper swings the axe or shovel, the tree shudders and puffs, wood pops out onto the grass
## and flies into the Pack of whoever walks over it with a +N tag, a felled tree topples, and the shovel digs stumps.
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
## Player one's devices: the keyboard, the mouse and every other controller (only their own while on the keyboard).
var _p1_input := PlayerInput.new(-1, [], _p1_pads)
## True while player one's last press came from the keyboard or mouse: then any controller's menu button drops in a
## second player, and a controller player one has not used neither steers them nor becomes theirs.
var _p1_on_keys := false
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
## Stage B round 2: the animals, the forage spots' models by spot index, and trees still wobbling (index -> s left).
var wildlife: Wildlife
var _forage_nodes := {}
var _wobble := {}
## Stumps and saplings drawn for felled trees (tree index -> [Node3D]).
var _tree_props := {}
## Open clipboards by player on this PC, and the countdown to refreshing their text.
var _boards := {}
var _board_clock := 0.0
## Round 3: open workbench panels ({panel, pick}) and dropped bundles' nodes by bundle id.
## Round 4: each local player's corner dock, open Pack panels ({panel, pick}), tool in hand (an index into
## data/items.json tools.order) and picked build piece.
var _docks := {}
## Toasts that came while the morning report was up, shown once it is put away.
var _held_toasts: Array[String] = []
var _packs := {}
var _tools := {}
var _kinds := {}
var _bench := {}
## Round 5: players asleep in the camp's tent on this PC (who -> the sleeper shown in the bag), guests asleep in their
## tents (stay id -> sleeper), and the name bubbles over the guests' tents.
var _inside := {}
var _asleep := {}
var _bubbles := {}
var _bundle_nodes := {}
## First-minutes round: loose pieces still in the air (bundle id -> seconds before they can be swept), and who swept
## a piece up (bundle id -> profile id), so its node flies to them.
var _airborne := {}
var _sweeper := {}

@onready var clearing: Clearing = $Clearing
@onready var camera: PlayCamera = $PlayCamera
@onready var menu: CampMenu = $Hud/Menu
@onready var couch: CouchView = $Couch
@onready var report: CampReport = $Hud/Report


func _ready() -> void:
	LightMoods.apply("day", $Sun, $World.environment, clearing.fire_lights)
	$Hud/Night.color = FeltBuilder.swatch(str(Tuning.value("day", "night.swatch", "ink_brown")))
	$Hud/Night.color.a = 0.0
	# The prompts keep to a centre column, clear of the clipboards and Packs at the sides (hud.prompt_width_px).
	$Hud/Prompt.offset_left = -Tuning.num("tuning", "hud.prompt_width_px", 640.0) * 0.5
	$Hud/Prompt.offset_right = -$Hud/Prompt.offset_left
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
	menu.show_title()
	# The picture preset is a setting of this PC (Settings); a profile from before settings existed held it.
	apply_quality(str(Settings.value("picture") if Settings.has_value("picture") or not profile.has("quality")
			else profile["quality"]), false)
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
		"solo":
			if start_solo(menu.slot()) == "":
				_welcome_report()
		"host":
			if start_host(menu.slot()) == "":
				_welcome_report()
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
		"picture": apply_quality(str(Settings.value("picture")), false)
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
	state.gather.lay_log()
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
	wildlife = Wildlife.new()
	wildlife.name = "Wildlife"
	add_child(wildlife)
	_sync_forage()
	_sync_trees(false)
	_sync_bundles(false)
	_sync_fire()
	camera.target = campers.get(profile["id"])
	camera.snap()
	menu.visible = false


func _clear_world() -> void:
	for who: String in _busy.keys():
		_end_busy(who)
	report.visible = false
	_held_toasts.clear()
	for id: String in _building.keys():
		toggle_build(id)
	for who: String in _boards.keys():
		toggle_clipboard(who)
	for who: String in _bench.keys():
		close_bench(who)
	for who: String in _packs.keys():
		close_pack(who)
	for who: String in _docks.keys():
		_docks[who].queue_free()
	_docks.clear()
	for who: String in _inside.keys():
		leave_tent(who, false)
	for node: Node3D in _asleep.values() + _bubbles.values():
		node.queue_free()
	_asleep.clear()
	_bubbles.clear()
	for node: Node3D in _bundle_nodes.values():
		node.queue_free()
	_bundle_nodes.clear()
	_airborne.clear()
	_sweeper.clear()
	if wildlife:
		wildlife.queue_free()
		wildlife = null
	for index: int in _wobble:
		clearing.placed[index].rotation.z = 0.0
	_wobble.clear()
	for node: Node in campers.values() + objects.values() + visitors.values() + _tents.values() + _forage_nodes.values():
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	campers.clear()
	objects.clear()
	visitors.clear()
	_tents.clear()
	_forage_nodes.clear()
	for index: int in _tree_props:
		clearing.placed[index].get_child(0).visible = true
		for node: Node3D in _tree_props[index]:
			node.queue_free()
	_tree_props.clear()
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
	if id == profile.get("id", ""):
		_sync_p1_input()


func _remove_camper(id: String) -> void:
	_get_up(id)
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
	for id in local_ids():
		if campers.has(id):
			(campers[id] as Camper).hold(tool_of(id))
	var hold := FeltBuilder.vec3(Tuning.value("tuning", "carry.hold_pos"))
	var spots: Array[Vector3] = []
	for c: Camper in campers.values():
		c.speed_scale = 1.0
		spots.append(c.position)
	for id: String in state.carriers:
		var carrier: Camper = campers.get(state.carriers[id])
		if carrier and objects.has(id):
			objects[id].transform = carrier.transform * Transform3D(Basis.IDENTITY, hold)
			carrier.speed_scale = CampGather.carry_speed(str(state.camp["objects"][id]["model"]), carrier.position,
					spots.filter(func(p: Vector3) -> bool: return p != carrier.position))
	_sweep(delta)
	_send_clock += delta
	if mode in [Mode.HOST, Mode.GUEST] and _send_clock >= 1.0 / maxf(_net("send_rate_hz"), 1.0):
		_send_clock = 0.0
		for id in local_ids():
			var me: Camper = campers.get(id)
			if me:
				for peer: int in ([1] if mode == Mode.GUEST else _guests.keys()):
					_moved.rpc_id(peer, id, me.position, me.rotation.y, tool_of(id), _inside.has(id))


func _process(delta: float) -> void:
	if not report.visible and not _held_toasts.is_empty():
		var held := _held_toasts.duplicate()
		_held_toasts.clear()
		for text: String in held:
			_toast(text)
	_toast_left -= delta
	if _toast_left <= 0.0:
		$Hud/Toast.text = ""
	_tick_day(delta)
	_tick_busy(delta)
	_tick_wobble(delta)
	_tick_wildlife(delta)
	_tick_tents()
	_board_clock -= delta
	if _board_clock <= 0.0:
		_refresh_boards()
	_update_night(delta)
	var lines: PackedStringArray = []
	if state and not menu.visible and not report.visible:
		for id in local_ids():
			if _packs.has(id) or _bench.has(id):
				continue
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
	_update_clock()
	_update_hint()
	_show_hud()
	_keep_in_view(delta)
	if $Hud/Dev.visible:
		_dev_clock -= delta
		if _dev_clock <= 0.0:
			_dev_clock = Tuning.num("tuning", "dev.fps_refresh_s", 0.5)
			var size := get_viewport().get_visible_rect().size
			$Hud/Dev.text = Tuning.text("dev.stats") % [Engine.get_frames_per_second(),
					Tuning.text("quality." + Quality.current), "%dx%d" % [get_window().size.x,
					get_window().size.y] if get_window() else "%dx%d" % [size.x, size.y],
					roundi(get_viewport().scaling_3d_scale * 100.0), roundi(_clock_scale())]


## The interact line for a player: what the button does now (action_for), or that they are fishing or grilling.
func _carry_prompt(id: String) -> String:
	if not _busy.has(id) and campers.has(id) and campers[id].speed_scale < 1.0:
		var put := action_for(id)
		if put.get("what", "") == "place":
			return Tuning.text("prompt.put_down") + " · " + Tuning.text("prompt.log_alone")
	if _inside.has(id):
		return Tuning.text("prompt.in_tent")
	if _bench.has(id) or _packs.has(id):
		return ""
	if _busy.has(id):
		return Tuning.text({"fish": "prompt.fishing", "cook": "prompt.cooking", "chop": "prompt.chopping",
				"dig": "prompt.digging"}[_busy[id]["what"]])
	var act := action_for(id)
	match act.get("what", ""):
		"place":
			return Tuning.text("prompt.put_down")
		"pick_up":
			return Tuning.text("prompt.pick_up")
		"fish":
			return Tuning.text("prompt.fish")
		"chop":
			return Tuning.text("prompt.chop") % state.gather.wood_left(int(act["arg"]))
		"forage":
			return Tuning.text("prompt.forage") % Tuning.text("items." + str(CampGather.spots()[act["arg"]]["item"]))
		"take_sapling":
			return Tuning.text("prompt.take_sapling")
		"pick_bundle":
			var b: Dictionary = state.camp["bundles"][act["arg"]]
			return Tuning.text("prompt.pick_bundle") % [Tuning.text("items." + str(b["item"])), int(b["n"])]
		"bench":
			return Tuning.text("prompt.bench")
		"tent":
			return Tuning.text("prompt.tent")
		"photo":
			return Tuning.text("prompt.photo") % Tuning.text("animal." + str(act["arg"]))
		"deposit":
			return Tuning.text("prompt.deposit")
		"ship":
			var item := str(act["arg"])
			return Tuning.text("prompt.ship") % [Tuning.text("items." + item), state.pack.count(id, item),
					CampProjects.price(item) * state.pack.count(id, item)]
		"take_back":
			return Tuning.text("prompt.take_back") % Tuning.text("items." + str(act["arg"]))
		"project":
			return Tuning.text("prompt.project") % Tuning.text("project.%s.name" % state.projects.current()["id"])
		"plant":
			return Tuning.text("prompt.plant")
		"dig":
			return Tuning.text("prompt.dig")
		"read_board":
			return Tuning.text("prompt.read_board")
		"upgrade_fire":
			var r := state.build.next_fire()
			var parts: Array[String] = []
			for item: String in r.get("items", {}):
				parts.append("%d %s" % [int(r["items"][item]), Tuning.text("items." + item)])
			return Tuning.text("prompt.upgrade_fire") % [Tuning.text("fire." + str(r["id"])),
					Tuning.text("fire.cost") % [", ".join(parts), int(r.get("coins", 0))]]
		"need_tool":
			return Tuning.text("prompt.need_tool") % Tuning.text("tool." + str(act["arg"]))
		"cook":
			return Tuning.text("prompt.cook") % Tuning.text("items." + str(act["arg"]))
		"give":
			var stay: Dictionary = state.camp["stays"][act["arg"]]
			var item := state.pack.first_of(id, CampGuests.gift_kind(state.guests.open_request(act["arg"])))
			return Tuning.text("prompt.give") % [stay["name"], Tuning.text("items." + item)]
	return ""


## A short line at the top of the screen. Lines that come close together stack, newest last (data/tuning.json
## hud.toast_lines at most).
func _toast(text: String) -> void:
	# A toast under the morning report would never be read: it waits until the report is put away.
	if report.visible:
		_held_toasts.append(text)
		return
	text = Prompts.fill(text, _pad)
	if _toast_left > 0.0 and $Hud/Toast.text != "" and $Hud/Toast.text != text:
		var lines: PackedStringArray = (str($Hud/Toast.text) + "\n" + text).split("\n")
		var keep := int(Tuning.num("tuning", "hud.toast_lines", 3))
		text = "\n".join(lines.slice(maxi(lines.size() - keep, 0)))
	$Hud/Toast.text = text
	_toast_left = Tuning.num("tuning", "hud.toast_s", 3.0)


func _update_hint() -> void:
	# Spaces inside each control are non-breaking, so the line only wraps between controls ("Tab for the menu").
	var parts: PackedStringArray = []
	for part in (Prompts.fill(Tuning.text("prompt.controls"), _pad) if state else "").split(" · "):
		parts.append(part.replace(" ", "\u00a0"))
	var text := " · ".join(parts)
	if can_drop_in() == "":
		text += "\n" + Prompts.fill(Tuning.text("prompt.drop_in"), true)
	$Hud/Hint.text = text


## Applies a picture preset (data/graphics.json) to every view; `keep` saves it in this PC's settings (Options does
## that itself, then asks for this).
func apply_quality(preset: String, keep: bool = true) -> void:
	if not Quality.names().has(preset):
		preset = str(Quality.names()[0])
	var views: Array[Viewport] = [get_viewport(), couch.second_view()]
	Quality.apply(preset, views, $World.environment, $Sun, couch.split)
	if keep:
		Settings.set_value("picture", preset)


# --- Input -------------------------------------------------------------------------------------------------------

## Sees every controller event before the menus do: a controller player one has not used drops in with the menu
## button; any other controller that player one touches becomes theirs. While player one is on the keyboard and mouse,
## the keyboard and mouse are their device: every controller's menu button drops in, and other controllers stay free.
func _input(event: InputEvent) -> void:
	var from_keys: Variant = Prompts.device_of(event)
	if from_keys == false and event.is_pressed() and not _p1_on_keys:
		_set_p1_on_keys(true)
	elif from_keys == true and _p1_on_keys and _p1_pads.has(event.device) and not event.is_action_pressed("menu"):
		_set_p1_on_keys(false)
	# The menu button closes the in-camp menu before its focused button sees it (Godot's focus moves on Tab).
	if state != null and menu.visible and menu.page() == "pause" and event.is_action_pressed("menu"):
		_close_menu()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or event.device == couch_pad:
		return
	var free := not _p1_pads.has(event.device)
	if event.is_action_pressed("menu") and (free or _p1_on_keys) and state != null and not menu.visible:
		var why := drop_in(event.device)
		if why != "couch.not_now":
			if why != "":
				_toast(Tuning.text(why))
			get_viewport().set_input_as_handled()
			return
	if free and _p1_on_keys:
		if state != null:
			get_viewport().set_input_as_handled()
		return
	if from_keys == true and free:
		_p1_pads.append(event.device)


func _set_p1_on_keys(on: bool) -> void:
	_p1_on_keys = on
	_p1_input.free_pads = not on
	_sync_p1_input()


## Player one reads their own devices (PlayerInput) when the couch is shared or they are on the keyboard; alone on a
## controller they read every action as before.
func _sync_p1_input() -> void:
	if campers.has(profile.get("id", "")):
		campers[profile["id"]].input = _p1_input if couch_id != "" or _p1_on_keys else null


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
	if _bench.has(who) and not menu.visible:
		if event.is_action_pressed("next_kind") or event.is_action_pressed("camera_right"):
			_bench[who]["pick"] = posmod(int(_bench[who]["pick"]) + 1, state.build.known_recipes().size())
		elif event.is_action_pressed("camera_left"):
			_bench[who]["pick"] = posmod(int(_bench[who]["pick"]) - 1, state.build.known_recipes().size())
		elif event.is_action_pressed("interact"):
			ask("craft", [str(state.build.known_recipes()[int(_bench[who]["pick"])]["kind"])], who)
		elif event.is_action_pressed("cancel") or event.is_action_pressed("menu") or event.is_action_pressed("clipboard"):
			close_bench(who)
		else:
			return
		_refresh_boards()
		get_viewport().set_input_as_handled()
		return
	if _inside.has(who) and not menu.visible and (event.is_action_pressed("interact") or event.is_action_pressed("cancel")):
		leave_tent(who)
		get_viewport().set_input_as_handled()
		return
	if _packs.has(who) and not menu.visible:
		var count := int(Tuning.num("items", "pack_slots", 8))
		var cols := int(Tuning.num("tuning", "pack_panel.columns", 4))
		var step := 0
		if event.is_action_pressed("next_kind") or event.is_action_pressed("camera_right") or event.is_action_pressed("move_right"):
			step = 1
		elif event.is_action_pressed("camera_left") or event.is_action_pressed("move_left"):
			step = -1
		elif event.is_action_pressed("move_back"):
			step = cols
		elif event.is_action_pressed("move_forward"):
			step = -cols
		elif event.is_action_pressed("interact"):
			ask("drop", [int(_packs[who]["pick"])], who)
		elif event.is_action_pressed("pack") or event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
			close_pack(who)
		else:
			return
		if _packs.has(who):
			_packs[who]["pick"] = posmod(int(_packs[who]["pick"]) + step, count)
		_refresh_boards()
		get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed("clipboard") or (_boards.has(who) and event.is_action_pressed("cancel")):
		toggle_clipboard(who)
	elif _boards.has(who) and (event.is_action_pressed("camera_left") or event.is_action_pressed("camera_right")):
		_boards[who].flip(1 if event.is_action_pressed("camera_right") else -1)
		_refresh_boards()
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
	elif not _building.has(who) and event.is_action_pressed("next_kind"):
		var kinds := state.build.available()
		_kinds[who] = kinds[(kinds.find(piece(who)) + 1) % kinds.size()]
		_refresh_boards()
	elif event.is_action_pressed("next_tool"):
		_tools[who] = posmod(int(_tools.get(who, 0)) + 1, tools().size())
		_refresh_boards()
	elif not _building.has(who) and event.is_action_pressed("pack"):
		open_pack(who)
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
	menu.set_sleep(state.day.is_evening(), state.day.votes.has(_menu_for), Tuning.text("menu.sleep_early"))
	var board := state.guests.current()
	lines.append(Tuning.text("menu.bookings") + ": " + (state.guests.booking_line(board) if not board.is_empty()
			else Tuning.text("menu.board_empty")))
	menu.set_booking(str(board.get("state", "")))
	menu.show_pause(_menu_for == couch_id, "\n".join(lines))
	if campers.has(_menu_for):
		campers[_menu_for].controlled = false


func _close_menu() -> void:
	menu.visible = false
	if campers.has(_menu_for):
		campers[_menu_for].controlled = not (_bench.has(_menu_for) or _packs.has(_menu_for))
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
	_p1_pads.erase(pad)
	_p1_input.taken.assign([pad])
	_spawn_camper(id)
	campers[id].input = PlayerInput.new(pad)
	_sync_p1_input()
	var both: Array[Camper] = [campers[profile["id"]], campers[id]]
	couch.follow(both)
	_toast(Tuning.text("toast.dropped_in") % p["name"])
	save_camp()
	return ""


## The couch player leaves this PC; their character, Pack and spot wait in the save. Anything they carried goes
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
	_sync_p1_input()
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
## give a guest what they asked for, grill a fish at the fire, pick up a bundle, pick up what a forage spot holds,
## take or plant a sapling, chop a tree, pick up the nearest thing, use the workbench, fill the camp box, or fish at
## the water's edge. {"what", "arg"}, or {} for nothing.
func action_for(who: String) -> Dictionary:
	var me: Camper = campers.get(who)
	if me == null or _busy.has(who):
		return {}
	if state.carried_by(who) != "":
		return {"what": "place"}
	if tool_of(who) == tool_for("photo") and wildlife:
		var kind := wildlife.nearest(me.position, Tuning.num("wildlife", "photo_m", 7.0))
		if kind != "":
			return {"what": "photo", "arg": kind}
	var at := Vector2(me.position.x, me.position.z)
	state.set_player_pos(who, at, rad_to_deg(me.rotation.y))
	var guest := state.guests.guest_near(who)
	if guest != "" and state.pack.first_of(who, CampGuests.gift_kind(state.guests.open_request(guest))) != "":
		return {"what": "give", "arg": guest}
	if CampPack.can_cook_at(at) and state.pack.first_of(who, "fish") != "":
		return {"what": "cook", "arg": state.pack.first_of(who, "fish")}
	if state.pack.bundle_near(at) != "":
		return {"what": "pick_bundle", "arg": state.pack.bundle_near(at)}
	if state.gather.spot_near(at) >= 0:
		return {"what": "forage", "arg": state.gather.spot_near(at)}
	if has_tool(who, "dig") and state.gather.dig_near(at) >= 0:
		return {"what": "dig", "arg": state.gather.dig_near(at)}
	if state.gather.sapling_near(at) >= 0:
		return {"what": "take_sapling", "arg": state.gather.sapling_near(at)}
	if state.gather.stump_near(at) >= 0 and state.pack.first_of(who, "plant") != "":
		return {"what": "plant", "arg": state.gather.stump_near(at)}
	var need := ""
	if state.gather.tree_near(at) >= 0:
		if has_tool(who, "chop"):
			return {"what": "chop", "arg": state.gather.tree_near(at)}
		need = tool_for("chop")
	if state.pack.bundle_near(at, true) != "":
		return {"what": "pick_bundle", "arg": state.pack.bundle_near(at, true)}
	if nearest_object(who) != "":
		return {"what": "pick_up", "arg": nearest_object(who)}
	if at.distance_to(home_tent_pos()) <= Tuning.num("guests", "tent.reach_m", 2.0):
		return {"what": "tent"}
	if CampProjects.near_crate(at):
		if state.projects.sellable(who) != "":
			return {"what": "ship", "arg": state.projects.sellable(who)}
		if not state.projects.crate().is_empty():
			return {"what": "take_back", "arg": str(state.projects.crate()[-1]["item"])}
	if CampProjects.near_board(state, at):
		return {"what": "project"} if state.projects.can_give(who) else {"what": "read_board"}
	if CampBuild.near_bench(at):
		return {"what": "bench"}
	if CampPack.near_box(at) and state.pack.has_boxable(who):
		return {"what": "deposit"}
	if CampPack.can_cook_at(at) and not state.build.next_fire().is_empty():
		return {"what": "upgrade_fire"}
	if CampPack.can_fish_at(at):
		if has_tool(who, "fish"):
			return {"what": "fish"}
		need = tool_for("fish")
	return {"what": "need_tool", "arg": need} if need != "" else {}


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
		"forage", "take_sapling", "plant", "pick_bundle":
			ask(act["what"], [act["arg"]], who)
		"deposit", "ship", "take_back", "project", "upgrade_fire":
			ask(act["what"], [], who)
		"read_board":
			if not _boards.has(who):
				toggle_clipboard(who)
			var board: Clipboard = _boards.get(who)
			if board:
				board.flip(1 - board.tab)
				_refresh_boards()
		"bench":
			open_bench(who)
		"tent":
			enter_tent(who)
		"photo":
			_flash()
			ask("photo", [act["arg"]], who)
		"fish", "cook", "chop", "dig":
			_start_busy(who, act["what"], act.get("arg") if act["what"] in ["chop", "dig"] else null)


## Starts a moment of fishing, grilling, chopping or digging (`arg`: the tree's index); the camper stands still
## meanwhile. A chop or a dig winds the tool back over the wait and strikes as it ends (Camper.swing).
func _start_busy(who: String, what: String, arg: Variant = null) -> void:
	var me: Camper = campers[who]
	var bobber: Node3D = null
	var wait := Tuning.num("fishing", "cast_s" if what == "fish" else "cook_s", 2.0)
	if what == "chop":
		wait = Tuning.num("gather", "trees.chop_s", 0.8)
	elif what == "dig":
		wait = Tuning.num("gather", "dig.dig_s", 1.0)
	if what in ["chop", "dig"]:
		var at := CampGather.tree_pos(int(arg))
		me.rotation.y = atan2(-(at.x - me.position.x), -(at.y - me.position.z))
		me.swing(wait)
	if what == "fish":
		bobber = clearing.place({"model": "bobber", "pos": [0, 0]})
		var ahead := me.position - me.transform.basis.z * Tuning.num("fishing", "cast_m", 1.6)
		bobber.position = Vector3(ahead.x, 0.0, ahead.z)
	me.controlled = false
	me.velocity = Vector3.ZERO
	_busy[who] = {"what": what, "left": wait, "bobber": bobber, "arg": arg}


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
			ask(str(b["what"]), [] if b["arg"] == null else [b["arg"]], who)


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
		why = state.pack.fish(profile_id)
	elif what == "cook" and args.is_empty():
		why = state.pack.cook(profile_id)
	elif what == "give" and args.size() == 1 and args[0] is String:
		why = state.guests.give(profile_id, args[0])
	elif what == "booking" and args.size() == 2 and args[0] is String and args[1] is String:
		why = state.guests.decide(profile_id, args[0], args[1])
	elif what == "chop" and args.size() == 1 and args[0] is int:
		why = state.gather.chop(profile_id, args[0])
	elif what == "forage" and args.size() == 1 and args[0] is int:
		why = state.gather.forage(profile_id, args[0])
	elif what == "take_sapling" and args.size() == 1 and args[0] is int:
		why = state.gather.take_sapling(profile_id, args[0])
	elif what == "plant" and args.size() == 1 and args[0] is int:
		why = state.gather.plant(profile_id, args[0])
	elif what == "dig" and args.size() == 1 and args[0] is int:
		why = state.gather.dig(profile_id, args[0])
	elif what == "upgrade_fire" and args.is_empty():
		why = state.build.upgrade_fire(profile_id)
	elif what == "drop" and args.size() == 1 and args[0] is int:
		why = state.pack.drop(profile_id, args[0])
	elif what == "pick_bundle" and args.size() == 1 and args[0] is String:
		why = state.pack.pick_bundle(profile_id, args[0])
	elif what == "deposit" and args.is_empty():
		why = "" if state.pack.deposit(profile_id) > 0 else "deny.nothing_to_box"
	elif what == "ship" and args.is_empty():
		why = state.projects.ship(profile_id)
	elif what == "take_back" and args.is_empty():
		why = state.projects.take_back(profile_id)
	elif what == "project" and args.is_empty():
		why = state.projects.give(profile_id)
	elif what == "craft" and args.size() == 1 and args[0] is String:
		why = state.build.craft(profile_id, args[0])
	elif (what == "spot" or what == "photo") and args.size() == 1 and args[0] is String:
		why = "" if Wildlife.kinds().has(args[0]) else "deny.not_movable"
	if why != "":
		if peer == 0:
			_toast(Tuning.text(why))
		else:
			_denied.rpc_id(peer, why)
		return
	if what in ["sleep", "fish", "cook", "give", "booking", "chop", "dig", "upgrade_fire", "forage", "spot", "take_sapling", "plant", "drop",
			"pick_bundle", "deposit", "craft", "photo", "ship", "take_back", "project"]:
		match what:
			"fish":
				_say(peer, "toast.caught", [Tuning.text("items." + state.pack.last_item)])
				_progress("fish")
			"cook":
				_say(peer, "toast.grilled", [Tuning.text("items." + state.pack.last_item)])
				_progress("cook")
			"give":
				_say_all("toast.thanks", [state.camp["stays"][args[0]]["name"], state.guests.last_tip])
				_sync_stays(false)
				_progress("give")
			"chop":
				_strike(profile_id, "chop", args[0])
				if state.gather.felled:
					_say_all("toast.felled", [])
					_sync_trees()
				_sync_bundles()
				_progress("chop")
			"upgrade_fire":
				var level: Dictionary = CampBuild.fire_levels()[state.build.fire_level() - 1]
				_say_all("toast.fire_up", [state.camp["profiles"][profile_id]["name"], Tuning.text("fire." + str(level["id"]))])
				_sync_fire()
				_progress("fire")
			"dig":
				_strike(profile_id, "dig", args[0])
				_say(peer, "toast.dug", [])
				_sync_trees()
				_sync_bundles()
				_progress("dig")
			"take_sapling":
				_say(peer, "toast.found", [Tuning.text("items.sapling")])
				_sync_trees()
			"plant":
				_say_all("toast.planted", [])
				_sync_trees()
				_progress("plant")
			"drop":
				_say(peer, "toast.dropped", [Tuning.text("items." + state.pack.last_item)])
				_sync_bundles()
			"pick_bundle":
				_say(peer, "toast.found", [Tuning.text("items." + state.pack.last_item)])
				_sync_bundles()
			"deposit":
				_say(peer, "toast.deposited", [])
			"ship":
				_say(peer, "toast.shipped", [Tuning.text("items." + state.projects.last_item), state.projects.last_n])
				_progress("ship")
			"take_back":
				_say(peer, "toast.took_back", [Tuning.text("items." + state.projects.last_item), state.projects.last_n])
			"project":
				var done := state.projects.finished
				if done != "":
					_say_all("toast.project_done", [Tuning.text("project.%s.name" % done), project_reward(done)])
					_progress("project")
				else:
					_say(peer, "toast.project_given", [Tuning.text("project.%s.name" % state.projects.current()["id"])])
			"craft":
				_say_all("toast.crafted", [state.camp["profiles"][profile_id]["name"], Tuning.text("build." + args[0])])
				_progress("craft:" + str(args[0]))
			"forage":
				_say(peer, "toast.found", [Tuning.text("items." + state.gather.last_item)])
				_sync_forage()
				_progress("forage:" + state.gather.last_item)
			"spot":
				var seen: Array = state.camp["journal"]["wildlife"]
				if not seen.has(args[0]):
					seen.append(args[0])
					_say_all("toast.spotted_new", [Tuning.text("animal." + str(args[0]))])
				_progress("spot:" + str(args[0]))
			"photo":
				var photos: Dictionary = state.camp["journal"].get("photos", {})
				state.camp["journal"]["photos"] = photos
				var kind := str(args[0])
				photos[kind] = int(photos.get(kind, 0)) + 1
				if not (state.camp["journal"]["wildlife"] as Array).has(kind):
					state.camp["journal"]["wildlife"].append(kind)
				if int(photos[kind]) == 1:
					var bonus := int(Tuning.num("wildlife", "photo_bonus", 5))
					state.camp["coins"] = int(state.camp.get("coins", 0)) + bonus
					_say_all("toast.photo_new", [Tuning.text("animal." + kind), bonus])
				else:
					_say(peer, "toast.photo_again", [Tuning.text("animal." + kind), int(photos[kind])])
				_progress("photo:" + kind)
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
		if CampGather.log_by_fire(str(state.camp["objects"][id]["model"]), state.object_pos(id)):
			_say_all("toast.log_split", [state.gather.split_log(id)])
			_progress("log")
		for met in state.guests.check_near_requests():
			_say_all("toast.thanks", [state.camp["stays"][met]["name"], state.guests.last_tip])
		_sync_stays(false)
	_show_object(id)
	for guest: int in _guests:
		if state.camp["objects"].has(id):
			_object_changed.rpc_id(guest, id, state.camp["objects"][id], state.carriers.get(id, ""))
		else:
			_object_removed.rpc_id(guest, id)
	if what == "build":
		_progress("build:" + str(args[0]))
	if what in ["build", "pack", "undo", "place"]:
		_share()
	save_camp()


## Host: counts a step toward the Today list and tells everyone about each task it finished (and its bonus).
func _progress(event: String) -> void:
	for id in state.tasks.note(event):
		_say_all("toast.task_done", [Tuning.text("task." + id), int(CampTasks.plan(id).get("bonus", 0))])


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


## Where the other PC's player is, the tool in their hand and whether they lie in the camp's tent (looks only: the
## tool and the tent are never saved, and the bed vote that goes with the tent is sent through `ask`).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _moved(profile_id: String, pos: Vector3, yaw: float, tool: String, in_tent: bool) -> void:
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
		c.hold(tool if tools().has(tool) else "hands")
	if in_tent and not _inside.has(profile_id):
		_lie_down(profile_id)
	elif not in_tent and _inside.has(profile_id):
		_get_up(profile_id)


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
		var asked := state.guests.refresh_requests()
		if not (came.is_empty() and asked.is_empty()):
			for met in state.guests.check_near_requests():
				_say_all("toast.thanks", [state.camp["stays"][met]["name"], state.guests.last_tip])
		for stay in asked:
			_say_all("toast.new_request", [state.camp["stays"][stay]["name"],
					Tuning.text("request.want." + state.guests.open_request(stay))])
		if not (came.is_empty() and offered.is_empty() and asked.is_empty()):
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


## Under the clock: what the guests would love now (hud.guests_max), then the first few odd jobs with their live
## counts (data/tuning.json hud.today_max; the clipboard has them all).
func today_lines() -> String:
	var out := ""
	var wants := guest_wants()
	if not wants.is_empty():
		out += "\n" + Tuning.text("hud.guests")
		for line in wants.slice(0, int(Tuning.num("tuning", "hud.guests_max", 3))):
			out += "\n" + line
	out += "\n" + Tuning.text("hud.today")
	var rows: Array = state.tasks.active()
	for row: Dictionary in rows.slice(0, int(Tuning.num("tuning", "hud.today_max", 3))):
		out += "\n" + CampTasks.line(row, true)
	return out


## One line for each guest with an open request: who and what they would love.
func guest_wants() -> Array[String]:
	var out: Array[String] = []
	for id: String in state.camp["stays"]:
		var want := state.guests.open_request(id)
		if want != "":
			out.append(Tuning.text("hud.guest_line") % [state.camp["stays"][id]["name"], Tuning.text("request.want." + want)])
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
	var laid := state.gather.lay_log()
	if laid != "":
		_show_object(laid)
		for guest: int in _guests:
			_object_changed.rpc_id(guest, laid, state.camp["objects"][laid], "")
	save_camp()
	for guest: int in _guests:
		_night.rpc_id(guest, summary, state.shared())
	_show_night(summary)


## The night as both PCs see it: a short fade, then the morning report (what the night paid, each guest's line,
## the bookings and the day's goals) until a player starts the day.
func _show_night(summary: Dictionary) -> void:
	_night_left = Tuning.num("day", "night.fade_s") * 2.0 + Tuning.num("day", "night.hold_s")
	$Hud/Night.visible = true
	for who: String in _inside.keys():
		leave_tent(who, false)
	for who: String in _busy.keys():
		_end_busy(who)
	report.show_report(morning_report(summary), Prompts.fill(Tuning.text("prompt.report_close"), _pad))
	_sync_stays(false)
	_sync_forage()
	_sync_trees()


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
	var sale: Dictionary = summary.get("sale", {})
	if not (sale.get("items", {}) as Dictionary).is_empty():
		var sold: PackedStringArray = []
		for item: String in sale["items"]:
			sold.append(Tuning.text("pack.slot") % [Tuning.text("items." + item), int(sale["items"][item])])
		lines.append(Tuning.text("report.sale") % [int(sale["coins"]), ", ".join(sold)])
	# The Today part below gives the stars and the ranger's hint; up here only the news of a new star.
	var rated: Dictionary = summary.get("rating", {})
	if not rated.is_empty() and int(rated["stars"]) > maxi(int(rated["was"]), 1):
		lines.append(Tuning.text("rating.up") % [int(rated["stars"]), CampRating.max_stars(), int(rated["was"])])
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
	lines.append_array(_today_report())
	return "\n".join(lines)


## The report's Today part: the task list, the bigger goals, and a word about tomorrow.
func _today_report() -> Array[String]:
	var lines: Array[String] = []
	var wants := guest_wants()
	if not wants.is_empty():
		lines.append(Tuning.text("report.guests"))
		lines.append_array(wants)
		lines.append("")
	lines.append(Tuning.text("report.today"))
	for row: Dictionary in state.tasks.active():
		lines.append(CampTasks.line(row))
	var goals := state.guests.goals()
	lines.append_array(goals.slice(1))
	lines.append(project_line())
	lines.append(Tuning.text("rating.line") % [state.rating.stars(), CampRating.max_stars()])
	if state.rating.hint() != "":
		lines.append(ranger_hint(state.rating.hint()))
	var tomorrow := state.day.today() + 1
	if (Tuning.value("tasks", "news", []) as Array).any(func(d: Variant) -> bool: return int(d) == tomorrow):
		lines.append("")
		lines.append(Tuning.text("report.tomorrow") % Tuning.text("news.day_%d" % tomorrow))
	return lines


## The open camp project and what it still needs, for the Today list ("" once every project is done, then a thank-you).
func project_line() -> String:
	var r := state.projects.current()
	if r.is_empty():
		return Tuning.text("project.all_done")
	var needs: PackedStringArray = []
	for need: String in r["needs"]:
		needs.append(Tuning.text("bench.need") % [Tuning.text("items." + need), int(state.projects.given().get(need, 0)),
				int(r["needs"][need])])
	return Tuning.text("project.line") % [Tuning.text("project.%s.name" % r["id"]), ", ".join(needs),
			project_reward(str(r["id"]))]


## The ranger's hint about what would raise the camp's rating (data/text.json rating.hint.<factor>).
func ranger_hint(factor: String) -> String:
	return Tuning.text("rating.ranger") % [str(Tuning.value("rating", "ranger", "Ada")), Tuning.text("rating.hint." + factor)]


## What a camp project gives, in words (data/text.json project.<id>.reward, with its coins from data/projects.json).
static func project_reward(id: String) -> String:
	var text := Tuning.text("project.%s.reward" % id)
	return text % int(CampProjects.row(id).get("coins", 0)) if text.contains("%d") else text


## The first morning of a new camp, started from the menu: a welcome and the first Today list.
func _welcome_report() -> void:
	if state.day.today() != 1 or not (state.tasks.data()["done"] as Array).is_empty() or report.visible:
		return
	var lines: Array[String] = [Tuning.text("report.welcome"), ""]
	lines.append_array(_today_report())
	report.show_report("\n".join(lines), Prompts.fill(Tuning.text("prompt.report_close"), _pad))


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
	_refresh_boards()


## The host's shared day: coins, the calendar, the guests and who is ready for bed.
@rpc("authority", "call_remote", "reliable")
func _shared(data: Dictionary) -> void:
	if state != null:
		state.apply_shared(data)
		_sync_stays(true)
		_sync_forage()
		_sync_trees()
		_sync_bundles()
		_sync_fire()
		_refresh_boards()


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
		kind = piece(who)
	_kinds[who] = kind
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


## Build mode on the next kind of building the kit holds (data/build.json kinds, in order), keeping the turn.
func next_kind(who: String) -> void:
	if not _building.has(who):
		return
	var kinds := state.build.available()
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
		if why == "":
			why = state.build.afford(b["kind"])
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
				CampBuild.refund_text(CampBuild.kind_of(state, existing))]
	if why != "":
		return Tuning.text("prompt.build_blocked") % Tuning.text(why)
	return Tuning.text("prompt.build_here") % [kind_name, state.build.cost_text(b["kind"])]


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


# --- Stage B round 2: gathering and animals ----------------------------------------------------------------------

## A tree sways for a moment when chopped (data/gather.json trees.wobble_deg, wobble_s).
func wobble(index: int) -> void:
	if index >= 0 and index < clearing.placed.size():
		_wobble[index] = Tuning.num("gather", "trees.wobble_s", 0.5)


func _tick_wobble(delta: float) -> void:
	var span := maxf(Tuning.num("gather", "trees.wobble_s", 0.5), 0.01)
	for index: int in _wobble.keys():
		var left := float(_wobble[index]) - delta
		var tree := clearing.placed[index]
		if left <= 0.0:
			_wobble.erase(index)
			tree.rotation.z = 0.0
		else:
			_wobble[index] = left
			tree.rotation.z = deg_to_rad(Tuning.num("gather", "trees.wobble_deg", 7.0)) * sin(left / span * TAU * 2.0) \
					* left / span


## The forage spots on screen follow the camp: a model at each spot that holds something now.
func _sync_forage() -> void:
	if state == null:
		return
	for i in CampGather.spots().size():
		var ready := state.gather.spot_ready(i)
		if ready and not _forage_nodes.has(i):
			var row: Dictionary = CampGather.spots()[i]
			_forage_nodes[i] = clearing.place({"model": row["model"], "pos": row["pos"], "yaw": row.get("yaw", 0)})
		elif not ready and _forage_nodes.has(i):
			_forage_nodes[i].queue_free()
			_forage_nodes.erase(i)


## Felled trees on screen follow the camp: the tree hides, its stump shows (with the dropped sapling beside it until
## someone picks it up), and a planted sapling stands in its place until it grows back.
## A tree that falls while someone watches topples over first (`animate`; data/gather.json fall). A dug-up stump leaves
## a hole, and a cleared spot shows nothing; neither blocks walking.
func _sync_trees(animate: bool = true) -> void:
	if state == null:
		return
	for t: Dictionary in CampGather.trees():
		var index := int(t["index"])
		var row := state.gather.tree(index)
		for node: Node3D in _tree_props.get(index, []):
			node.queue_free()
		_tree_props.erase(index)
		var root := clearing.placed[index]
		var mesh := root.get_child(0) as Node3D
		var standing: bool = row["stage"] == "standing"
		if animate and mesh.visible and not standing and row["stage"] == "stump":
			_topple(index, mesh)
		elif not mesh.has_meta("falling"):
			mesh.visible = standing
		for body in root.get_children():
			if body is StaticBody3D:
				for shape in body.get_children():
					if shape is CollisionShape3D:
						shape.set_deferred("disabled", row["stage"] in ["hole", "cleared"])
		if standing or row["stage"] == "cleared":
			continue
		var at: Vector2 = t["pos"]
		var props: Array[Node3D] = []
		var model := str(Tuning.value("gather", "trees.sapling_model"))
		if row["stage"] == "stump":
			model = str(Tuning.value("gather", "trees.stump_model"))
		elif row["stage"] == "hole":
			model = str(Tuning.value("gather", "dig.hole_model"))
		props.append(clearing.place({"model": model, "pos": [at.x, at.y]}))
		if bool(row["sapling_out"]):
			var off: Array = Tuning.value("gather", "trees.sapling_offset", [0.7, 0.5])
			props.append(clearing.place({"model": str(Tuning.value("gather", "trees.sapling_model")),
					"pos": [at.x + float(off[0]), at.y + float(off[1])], "yaw": 25}))
		_tree_props[index] = props


## Moves the animals on, and tells the host when a player on this PC spots one.
func _tick_wildlife(delta: float) -> void:
	if state == null or wildlife == null:
		return
	var players: Array[Vector3] = []
	for id: String in campers:
		players.append(campers[id].position)
	var mine: Array[Vector3] = []
	var mine_ids: Array[String] = []
	for id in local_ids():
		if campers.has(id):
			mine.append(campers[id].position)
			mine_ids.append(id)
	for kind in wildlife.tick(delta, state.day.hour(), state.day.today(), players, mine):
		ask("spot", [kind], mine_ids[0] if not mine_ids.is_empty() else "")


# --- Stage B round 2: the clipboard ------------------------------------------------------------------------------

## Opens or puts away a player's clipboard. Player one's sits on the left, the couch player's on the right. While
## one is open the camera's turn buttons flip its tabs instead.
func toggle_clipboard(who: String) -> void:
	if _boards.has(who):
		var board: Clipboard = _boards[who]
		_boards.erase(who)
		board.get_parent().remove_child(board)
		board.queue_free()
	elif state != null and campers.has(who):
		var board := Clipboard.new()
		board.name = "Clipboard_" + who
		$Hud.add_child(board)
		board.dock(who == couch_id)
		_boards[who] = board
	_hold_camera()
	_refresh_boards()


func _refresh_boards() -> void:
	_board_clock = Tuning.num("tuning", "clipboard.refresh_s", 0.25)
	_refresh_docks()
	_refresh_packs()
	_refresh_bench()
	for who: String in _boards.keys():
		if state == null or not local_ids().has(who):
			toggle_clipboard(who)
			continue
		var board: Clipboard = _boards[who]
		board.show_text(clipboard_text(who, board.tab_name()), Prompts.fill(Tuning.text("clipboard.hint"),
				_pad if who == profile["id"] else true))
		_fit_panel(board, who)


## A clipboard tab's text for a player: "today" (the task list with places, goals and tomorrow), "bookings" (the
## board and the guests staying now) or "supplies" (coins, the camp box, the build kit, everyone's Pack and the
## animals seen).
func clipboard_text(who: String, tab: String) -> String:
	var lines: Array[String] = []
	match tab:
		"today":
			lines = _today_report()
		"bookings":
			var any := false
			for r: Dictionary in state.camp["reservations"]:
				if r.get("state", "") in ["offered", "accepted", "arrived"]:
					lines.append(state.guests.booking_line(r))
					any = true
			if not any:
				lines.append(Tuning.text("report.none"))
			lines.append(Prompts.fill(Tuning.text("clipboard.answer"), _pad if who == profile["id"] else true))
			lines.append("")
			lines.append(Tuning.text("clipboard.staying"))
			if (state.camp["stays"] as Dictionary).is_empty():
				lines.append(Tuning.text("clipboard.nobody"))
			for id: String in state.camp["stays"]:
				var stay: Dictionary = state.camp["stays"][id]
				var want := state.guests.open_request(id)
				lines.append(Tuning.text("clipboard.stay") % [stay["name"],
						Tuning.text("build." + CampBuild.kind_of(state, str(stay["pitch"]))),
						Tuning.text("request.want." + want) if want != "" else Tuning.text("clipboard.content")])
		"supplies":
			lines.append(Tuning.text("clipboard.coins") % int(state.camp.get("coins", 0)))
			var boxed: PackedStringArray = []
			for item: String in state.camp["box"]:
				boxed.append(Tuning.text("pack.slot") % [Tuning.text("items." + item), state.pack.box_count(item)])
			lines.append(Tuning.text("clipboard.box") % (", ".join(boxed) if not boxed.is_empty() else Tuning.text("clipboard.empty")))
			var kit: PackedStringArray = []
			for kind in state.build.available():
				if not CampBuild.is_free(kind):
					kit.append(Tuning.text("pack.slot") % [Tuning.text("build." + kind), state.build.in_kit(kind)])
			lines.append(Tuning.text("clipboard.kit") % (", ".join(kit) if not kit.is_empty() else Tuning.text("clipboard.empty")))
			var crate: PackedStringArray = []
			for st: Dictionary in state.projects.crate():
				crate.append(Tuning.text("pack.slot") % [Tuning.text("items." + str(st["item"])), int(st["n"])])
			lines.append(Tuning.text("clipboard.crate") % (", ".join(crate) if not crate.is_empty() else Tuning.text("clipboard.empty")))
			var shipped := 0
			for item: String in state.camp["shipped"]:
				shipped += int(state.camp["shipped"][item])
			lines.append(Tuning.text("clipboard.shipped") % shipped)
			lines.append("")
			for id: String in state.online:
				var names: PackedStringArray = []
				for st: Dictionary in state.pack.slots(id):
					names.append(Tuning.text("pack.slot") % [Tuning.text("items." + str(st["item"])), int(st["n"])])
				lines.append(Tuning.text("clipboard.pack") % [state.camp["profiles"][id]["name"],
						", ".join(names) if not names.is_empty() else Tuning.text("clipboard.empty")])
			lines.append("")
			var seen: PackedStringArray = []
			for kind: String in state.camp["journal"]["wildlife"]:
				seen.append(Tuning.text("animal." + kind))
			lines.append(Tuning.text("clipboard.animals") % [seen.size(), Wildlife.kinds().size(),
					", ".join(seen) if not seen.is_empty() else Tuning.text("clipboard.none_yet")])
		"guide":
			lines = field_guide()
	return "\n".join(lines)


## The field guide: each animal kind, photographed (how many), seen, or still a mystery, with where and when to look.
func field_guide() -> Array[String]:
	var photos: Dictionary = state.camp["journal"].get("photos", {})
	var seen: Array = state.camp["journal"]["wildlife"]
	var kinds: Array[String] = []
	for kind in Wildlife.kinds():
		if not kinds.has(kind):
			kinds.append(kind)
	var lines: Array[String] = [Tuning.text("guide.head") % [photos.size(), kinds.size()], ""]
	for kind in kinds:
		var hint := Tuning.text("guide.hint." + kind)
		if int(photos.get(kind, 0)) > 0:
			lines.append(Tuning.text("guide.photo") % [Tuning.text("animal." + kind).capitalize(), int(photos[kind]), hint])
		elif seen.has(kind):
			lines.append(Tuning.text("guide.seen") % [Tuning.text("animal." + kind).capitalize(), hint])
		else:
			lines.append(Tuning.text("guide.unknown") % hint)
	return lines


## A quick white flash over the screen for a photo (data/tuning.json hud.flash_s).
func _flash() -> void:
	var flash: ColorRect = $Hud.get_node_or_null("Flash")
	if flash == null:
		flash = ColorRect.new()
		flash.name = "Flash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		$Hud.add_child(flash)
	flash.color = Color(1, 1, 1, Tuning.num("tuning", "hud.flash_alpha", 0.7))
	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, Tuning.num("tuning", "hud.flash_s", 0.35))


# --- Round 3: the Pack bar, dropped bundles and the workbench ------------------------------------------------------

## Keeps a corner dock for each player on this PC: player one's bottom right (bottom left with a couch player), the
## couch player's bottom right.
func _refresh_docks() -> void:
	var mine := local_ids() if state != null else ([] as Array[String])
	for who: String in _docks.keys():
		if not mine.has(who):
			_docks[who].queue_free()
			_docks.erase(who)
	for who in mine:
		if not campers.has(who) or not state.camp["profiles"].has(who):
			continue
		if not _docks.has(who):
			var made := HudDock.new()
			made.name = "Dock_" + who
			$Hud.add_child(made)
			_docks[who] = made
		var dock: HudDock = _docks[who]
		dock.dock(couch_id != "" and who != couch_id)
		var pad: Variant = _pad if who == profile["id"] else true
		var kinds := state.build.available()
		var tool_names: Array[String] = []
		for t in tools():
			tool_names.append(Tuning.text("tool." + str(t)))
		var piece_names: Array[String] = []
		for k in kinds:
			piece_names.append(Tuning.text("build." + k))
		var kind := piece(who)
		var label := Tuning.text("build." + kind)
		if not CampBuild.is_free(kind):
			label = Tuning.text("pack.slot") % [label, state.build.in_kit(kind)]
		dock.show_dock(tool_names, posmod(int(_tools.get(who, 0)), tools().size()), piece_names, kinds.find(kind), label,
				[Prompts.fill(Tuning.text("dock.tool"), pad),
				Prompts.fill(Tuning.text("dock.build"), pad), Prompts.fill(Tuning.text("dock.pack"), pad)
				% [state.pack.slots(who).size(), int(Tuning.num("items", "pack_slots", 8))]])


## Shows or hides the HUD's parts: the menu and the morning report cover the hint and the docks, and an open Pack,
## clipboard or workbench covers its player's dock.
func _show_hud() -> void:
	var covered := menu.visible or report.visible
	$Hud/Hint.visible = not covered
	$Hud/Toast.visible = not menu.visible
	for who: String in _docks:
		_docks[who].visible = not covered and not (_packs.has(who) or _boards.has(who) or _bench.has(who))
	for who: String in _boards:
		_boards[who].visible = not menu.visible
	for panels: Dictionary in [_packs, _bench]:
		for who: String in panels:
			panels[who]["panel"].visible = not menu.visible


## The top right: the clock line, then guests' wishes and odd jobs (just the clock line under the couch player's
## clipboard or workbench).
func _update_clock() -> void:
	$Hud/Clock.text = (clock_line() + ("" if _right_panel_open() else today_lines())) if state else ""


## Fits a clipboard or workbench panel between the hint (left) or the clock (right) and the bottom of the screen
## (data/tuning.json clipboard.top_px and gap_px).
func _fit_panel(panel: Clipboard, who: String) -> void:
	_update_clock()
	var gap := Tuning.num("tuning", "clipboard.gap_px", 24.0)
	var above: Label = $Hud/Clock if who == couch_id else $Hud/Hint
	var top := Tuning.num("tuning", "clipboard.top_px", 150.0)
	if above.visible and above.text != "":
		top = maxf(top, above.position.y + above.get_combined_minimum_size().y + gap)
	panel.fit(top, get_viewport().get_visible_rect().size.y - gap)


## A player's open panel: their Pack, workbench or clipboard, or null.
func _panel_of(who: String) -> Control:
	if _packs.has(who):
		return _packs[who]["panel"]
	if _bench.has(who):
		return _bench[who]["panel"]
	return _boards.get(who)


## Keeps each player on this PC in view beside their open panel: when the panel would cover their camper, the camera
## drawing them slides the picture (sideways toward the middle of the screen, or up, whichever is less) until the
## camper stands hud.keep_clear_px clear of it, easing at hud.keep_clear_rate (data/tuning.json).
func _keep_in_view(delta: float) -> void:
	var view := get_viewport().get_visible_rect()
	var margin := Tuning.num("tuning", "hud.keep_clear_px", 60.0)
	var cams: Array[PlayCamera] = [camera, couch.second_camera()]
	var want: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var depth: Array[float] = [camera.distance, camera.distance]
	for who in local_ids() if state != null else ([] as Array[String]):
		var panel := _panel_of(who)
		if panel == null or not panel.is_visible_in_tree() or not campers.has(who):
			continue
		var i := 1 if couch.split and who == couch_id else 0
		var cam := cams[i]
		var body: Vector3 = campers[who].global_position + Vector3.UP * Tuning.num("tuning", "hud.keep_clear_height_m", 0.6)
		if cam.is_position_behind(body):
			continue
		var at := cam.unproject_position(body) * (view.size.y / cam.get_viewport().get_visible_rect().size.y) - cam.shift_px
		var r := panel.get_global_rect().grow(margin)
		if not r.has_point(at):
			continue
		var side := r.end.x - at.x if r.get_center().x < view.get_center().x else r.position.x - at.x
		var up := r.position.y - at.y
		want[i] = Vector2(side, 0.0) if absf(side) < absf(up) else Vector2(0.0, up)
		depth[i] = (body - cam.global_position).dot(-cam.global_basis.z)
	var ease := 1.0 - exp(-Tuning.num("tuning", "hud.keep_clear_rate", 6.0) * delta)
	for i in cams.size():
		cams[i].slide(cams[i].shift_px.lerp(want[i], ease), depth[i], view.size.y)


## True while the couch player's clipboard or workbench is open on the right, under the clock: the clock then shows
## only its own line (the wishes and odd jobs are on the clipboard's Today page).
func _right_panel_open() -> bool:
	return couch_id != "" and (_boards.has(couch_id) or _bench.has(couch_id))


## Keeps the turn buttons off the camera while any panel that uses them is open.
func _hold_camera() -> void:
	camera.hold_turn = not (_boards.is_empty() and _bench.is_empty() and _packs.is_empty())


## The tools every player cycles through (data/items.json tools.order).
static func tools() -> Array:
	return Tuning.value("items", "tools.order", ["hands"])


## The tool a step needs in hand ("chop": the axe, "fish": the rod), or "" when any will do.
static func tool_for(step: String) -> String:
	return str(Tuning.value("items", "tools.needs." + step, ""))


func tool_of(who: String) -> String:
	return str(tools()[posmod(int(_tools.get(who, 0)), tools().size())])


func has_tool(who: String, step: String) -> bool:
	return tool_for(step) == "" or tool_of(who) == tool_for(step)


## Takes a tool out for a player on this PC.
func hold_tool(who: String, tool: String) -> void:
	_tools[who] = maxi(tools().find(tool), 0)
	_refresh_boards()


## The build piece a player has picked: one the kit holds (the tent pitch until they pick another).
func piece(who: String) -> String:
	var kinds := state.build.available()
	return str(_kinds.get(who, "")) if kinds.has(str(_kinds.get(who, ""))) else str(kinds[0])


## Opens a player's Pack, like Animal Crossing's pockets (putting their clipboard away): the camper stands still while
## it is open.
func open_pack(who: String) -> void:
	if _packs.has(who) or not campers.has(who):
		return
	if _boards.has(who):
		toggle_clipboard(who)
	var panel := PackPanel.new()
	panel.name = "Pack_" + who
	$Hud.add_child(panel)
	panel.dock("right" if who == couch_id else ("left" if couch_id != "" else "centre"))
	_packs[who] = {"panel": panel, "pick": 0}
	campers[who].controlled = false
	campers[who].velocity = Vector3.ZERO
	_hold_camera()
	_refresh_boards()


func close_pack(who: String) -> void:
	if not _packs.has(who):
		return
	var panel: PackPanel = _packs[who]["panel"]
	_packs.erase(who)
	panel.get_parent().remove_child(panel)
	panel.queue_free()
	if campers.has(who) and _menu_for != who and not _bench.has(who):
		campers[who].controlled = true
	_hold_camera()


func _refresh_packs() -> void:
	for who: String in _packs.keys():
		if state == null or not local_ids().has(who) or not state.camp["profiles"].has(who):
			close_pack(who)
			continue
		var panel: PackPanel = _packs[who]["panel"]
		panel.show_pack(Tuning.text("pack.title") % state.camp["profiles"][who]["name"], state.pack.slots(who),
				int(_packs[who]["pick"]), Prompts.fill(Tuning.text("pack.hint"), _pad if who == profile["id"] else true))


## Dropped bundles on screen follow the camp's. A loose piece new since the last look pops out of its tree in an arc
## (`animate`); one swept up flies into its sweeper (or the nearest camper) with a +N tag.
func _sync_bundles(animate: bool = true) -> void:
	if state == null:
		return
	var bundles: Dictionary = state.camp["bundles"]
	for id: String in _bundle_nodes.keys():
		if not bundles.has(id):
			_fly_away(_bundle_nodes[id], _sweeper.get(id, ""))
			_bundle_nodes.erase(id)
			_airborne.erase(id)
			_sweeper.erase(id)
	for id: String in bundles:
		if not _bundle_nodes.has(id):
			var row: Dictionary = bundles[id]
			var p: Vector2 = CampPack.bundle_pos(row)
			var model := str(Tuning.value("items", "items.%s.drop_model" % row["item"], ""))
			if model == "" or not row.get("loose", false):
				model = str(Tuning.value("items", "bundle.model", "bundle"))
			var node := clearing.place({"model": model, "pos": [p.x, p.y], "yaw": hash(id) % 360})
			node.set_meta("count", int(row["n"]))
			_bundle_nodes[id] = node
			if animate and row.get("loose", false) and row.has("from"):
				_pop_out(node, Vector2(float(row["from"][0]), float(row["from"][1])))
				_airborne[id] = Tuning.num("gather", "drops.sweep_wait_s", 0.6)


## The camp fire on screen follows its level: the models of every level reached stand on the fire pit and its light
## grows (data/craft.json fire; LightMoods reads the light's "scale").
func _sync_fire() -> void:
	if state == null:
		return
	var rows: Array = Tuning.table("clearing").get("placements", [])
	for i in rows.size():
		if str(rows[i].get("model", "")) != str(Tuning.value("craft", "fire.model", "fire_pit")):
			continue
		var root := clearing.placed[i]
		var old := root.get_node_or_null("Upgrade")
		var level := mini(state.build.fire_level(), CampBuild.fire_levels().size())
		if old and int(old.get_meta("level", -1)) == level:
			continue
		if old:
			root.remove_child(old)
			old.queue_free()
		var scale := 1.0
		var radius := -1.0
		if level > 0:
			var up := Node3D.new()
			up.name = "Upgrade"
			up.set_meta("level", level)
			for row: Dictionary in CampBuild.fire_levels().slice(0, level):
				up.add_child(FeltBuilder.build(str(row.get("model", ""))))
			root.add_child(up)
			scale = float(CampBuild.fire_levels()[level - 1].get("light_scale", 1.0))
			radius = float(CampBuild.fire_levels()[level - 1].get("collide_m", -1.0))
		for child in root.get_children():
			if child is OmniLight3D:
				child.set_meta("scale", scale)
			elif child is StaticBody3D:
				for shape in child.get_children():
					if shape is CollisionShape3D and shape.shape is CylinderShape3D:
						if not shape.has_meta("radius"):
							shape.set_meta("radius", shape.shape.radius)
						shape.shape.radius = radius if radius > 0.0 else float(shape.get_meta("radius"))
		_light_t = -1.0


# --- First-minutes round: the swing, the drop and the sweep ---------------------------------------------------------

## Host: the strike of a chop or a dig, shown on every PC (the tree shudders and puffs; the other PC's camper swings).
func _strike(profile_id: String, what: String, index: int) -> void:
	_struck(profile_id, what, index)
	for guest: int in _guests:
		_struck.rpc_id(guest, profile_id, what, index)


@rpc("authority", "call_remote", "reliable")
func _struck(profile_id: String, what: String, index: int) -> void:
	if index < 0 or index >= clearing.placed.size():
		return
	if not local_ids().has(profile_id) and campers.has(profile_id):
		(campers[profile_id] as Camper).swing(0.0)
	if what == "chop":
		wobble(index)
	puff(index, what == "chop")


## Host: tells the other PC who swept a piece up, just before the shared camp drops it, so its node flies to them.
@rpc("authority", "call_remote", "reliable")
func _swept(bundle_id: String, profile_id: String) -> void:
	_sweeper[bundle_id] = profile_id


## A puff of felt bits from a tree's crown (`crown`) or round its stump (data/gather.json hit).
func puff(index: int, crown: bool) -> void:
	var bits := CPUParticles3D.new()
	var life := Tuning.num("gather", "hit.puff_s", 0.7)
	bits.one_shot = true
	bits.amount = int(Tuning.num("gather", "hit.puff_count", 10))
	bits.lifetime = life
	bits.explosiveness = 1.0
	bits.direction = Vector3.UP
	bits.spread = 95.0
	bits.initial_velocity_min = 1.2
	bits.initial_velocity_max = 2.6
	bits.gravity = Vector3(0, -5.0, 0)
	bits.scale_amount_min = 0.6
	bits.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	var paint := StandardMaterial3D.new()
	paint.albedo_color = FeltBuilder.swatch(str(Tuning.value("gather",
			"hit.puff_swatch" if crown else "hit.stump_swatch", "olive_felt"))).linear_to_srgb()
	dot.material = paint
	bits.mesh = dot
	var at := CampGather.tree_pos(index)
	bits.position = Vector3(at.x, Tuning.num("gather", "hit.crown_y_m", 1.3) if crown else 0.3, at.y)
	add_child(bits)
	bits.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(bits.queue_free)


## A felled tree tips over away from the nearest camper (whoever chopped it), but never toward the camera, where it
## would fade out unseen; then it hides (data/gather.json fall).
func _topple(index: int, mesh: Node3D) -> void:
	mesh.set_meta("falling", true)
	var at := CampGather.tree_pos(index)
	var away := Vector3(1, 0, 0)
	var best := INF
	for c: Camper in campers.values():
		var d := Vector3(at.x - c.position.x, 0, at.y - c.position.z)
		if d.length() < best and d.length() > 0.01:
			best = d.length()
			away = d.normalized()
	var to_camera := camera.global_transform.basis.z
	to_camera.y = 0.0
	if to_camera.length() > 0.01 and away.dot(to_camera.normalized()) > 0.0:
		away = (away - 2.0 * away.dot(to_camera.normalized()) * to_camera.normalized()).normalized()
	var local: Vector3 = mesh.get_parent().global_transform.basis.inverse() * away
	local.y = 0.0
	var axis := Vector3.UP.cross(local.normalized()).normalized()
	var rest := mesh.transform.basis
	var tip := create_tween()
	tip.tween_method(func(a: float) -> void:
		mesh.transform.basis = Basis(axis, a) * rest,
			0.0, deg_to_rad(Tuning.num("gather", "fall.deg", 84.0)),
			Tuning.num("gather", "fall.fall_s", 0.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tip.tween_callback(func() -> void:
		mesh.visible = state != null and state.gather.tree(index)["stage"] == "standing"
		mesh.transform.basis = rest
		mesh.remove_meta("falling")
		puff(index, false))


## A piece of wood pops out of the tree at `from` in an arc to where it lies, with a little hop on landing.
func _pop_out(node: Node3D, from: Vector2) -> void:
	var land := node.position
	var start := Vector3(from.x, Tuning.num("gather", "drops.start_y_m", 1.0), from.y)
	var high := Tuning.num("gather", "drops.pop_height_m", 0.8)
	var hop := Tuning.num("gather", "drops.bounce_m", 0.12)
	var pop := create_tween()
	pop.tween_method(func(k: float) -> void:
		if is_instance_valid(node):
			node.position = start.lerp(land, k) + Vector3.UP * (4.0 * high * k * (1.0 - k)),
			0.0, 1.0, Tuning.num("gather", "drops.pop_s", 0.45))
	pop.tween_method(func(k: float) -> void:
		if is_instance_valid(node):
			node.position = land + Vector3.UP * (4.0 * hop * k * (1.0 - k)),
			0.0, 1.0, Tuning.num("gather", "drops.pop_s", 0.45) * 0.4)


## A swept-up piece flies into its sweeper and shrinks away, and a +N tag rises over them; other bundles just go.
func _fly_away(node: Node3D, who: String) -> void:
	var to: Camper = campers.get(who)
	if to == null:
		var best := Tuning.num("items", "reach_m", 1.4) + 0.5
		for c: Camper in campers.values():
			if c.position.distance_to(node.position) < best:
				best = c.position.distance_to(node.position)
				to = c
	if to == null:
		node.queue_free()
		return
	var fly_s := Tuning.num("gather", "drops.fly_s", 0.28)
	var fly := create_tween().set_parallel()
	fly.tween_property(node, "global_position", to.global_position + Vector3.UP * 0.8, fly_s)
	fly.tween_property(node, "scale", Vector3.ONE * 0.2, fly_s)
	fly.chain().tween_callback(node.queue_free)
	var tag := Label3D.new()
	tag.text = Tuning.text("toast.got_tag") % int(node.get_meta("count", 1))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = int(Tuning.num("tuning", "camper.name_font_px", 48))
	tag.outline_size = int(Tuning.num("tuning", "camper.name_outline_px", 12))
	tag.pixel_size = 0.004
	tag.modulate = FeltBuilder.swatch("honey_thread").linear_to_srgb()
	tag.position = Vector3.UP * 1.2
	to.add_child(tag)
	var rise_s := Tuning.num("gather", "drops.tag_s", 0.9)
	var up := tag.create_tween().set_parallel()
	up.tween_property(tag, "position:y", 1.2 + Tuning.num("gather", "drops.rise_m", 0.6), rise_s)
	up.tween_property(tag, "modulate:a", 0.0, rise_s).set_delay(rise_s * 0.4)
	up.chain().tween_callback(tag.queue_free)


## Host: a player walking over a loose piece that has landed sweeps it into their Pack.
func _sweep(delta: float) -> void:
	for id: String in _airborne.keys():
		_airborne[id] = float(_airborne[id]) - delta
		if float(_airborne[id]) <= 0.0:
			_airborne.erase(id)
	if mode == Mode.GUEST or state.camp["bundles"].is_empty():
		return
	for who: String in state.online:
		var id := state.pack.sweep(who, _airborne.keys())
		if id == "":
			continue
		_sweeper[id] = who
		for guest: int in _guests:
			_swept.rpc_id(guest, id, who)
		_sync_bundles()
		_share()
		_progress("sweep:" + state.pack.last_item)
		save_camp()


## Opens the workbench panel for a player on this PC: the recipes, what each needs and what they have; the camper
## stands still while it is open.
func open_bench(who: String) -> void:
	if _bench.has(who) or not campers.has(who):
		return
	if _boards.has(who):
		toggle_clipboard(who)
	var panel := Clipboard.new()
	panel.name = "Bench_" + who
	panel.heading = Tuning.text("bench.title")
	$Hud.add_child(panel)
	panel.dock(who == couch_id)
	_bench[who] = {"panel": panel, "pick": 0}
	campers[who].controlled = false
	campers[who].velocity = Vector3.ZERO
	_hold_camera()
	_refresh_bench()


func close_bench(who: String) -> void:
	if not _bench.has(who):
		return
	var panel: Clipboard = _bench[who]["panel"]
	_bench.erase(who)
	panel.get_parent().remove_child(panel)
	panel.queue_free()
	if campers.has(who) and _menu_for != who and not _packs.has(who):
		campers[who].controlled = true
	_hold_camera()


## The workbench panel's text for a player: each recipe (the picked one marked) with its needs as have/need.
func bench_text(who: String, pick: int) -> String:
	var lines: Array[String] = []
	var recipes := state.build.known_recipes()
	for i in recipes.size():
		var r: Dictionary = recipes[i]
		var needs: PackedStringArray = []
		if int(r.get("coins", 0)) > 0:
			needs.append(Tuning.text("bench.coins") % [int(state.camp.get("coins", 0)), int(r["coins"])])
		for item: String in r.get("items", {}):
			needs.append(Tuning.text("bench.need") % [Tuning.text("items." + item), state.pack.have(who, item),
					int(r["items"][item])])
		var ready := state.build.can_craft(who, str(r["kind"])) == ""
		lines.append(Tuning.text("bench.row_picked" if i == pick else "bench.row") % [Tuning.text("build." + str(r["kind"])),
				", ".join(needs), Tuning.text("bench.ready" if ready else "bench.short"),
				maxi(state.build.in_kit(str(r["kind"])), 0)])
	return "\n".join(lines)


func _refresh_bench() -> void:
	for who: String in _bench.keys():
		if state == null or not local_ids().has(who):
			close_bench(who)
			continue
		var panel: Clipboard = _bench[who]["panel"]
		panel.show_text(bench_text(who, int(_bench[who]["pick"])), Prompts.fill(Tuning.text("bench.hint"),
				_pad if who == profile["id"] else true))
		_fit_panel(panel, who)


# --- Round 5: tents to sleep in, guests asleep in theirs, name bubbles -------------------------------------------

## The camp's own tent (the first "tent" in data/clearing.json), where the players sleep.
static func home_tent_index() -> int:
	var rows: Array = Tuning.table("clearing").get("placements", [])
	for i in rows.size():
		if str(rows[i].get("model", "")) == "tent":
			return i
	return -1


static func home_tent_pos() -> Vector2:
	var i := home_tent_index()
	if i < 0:
		return Vector2(INF, INF)
	var o := Clearing.placement_transform(Tuning.table("clearing")["placements"][i]).origin
	return Vector2(o.x, o.z)


## A felt camper tucked into a sleeping bag in a tent: `bag` is a row of data/guests.json (tent.bags or
## tent.home_bags): [x, feet z, the bag's cover model]. The body lies face up with its head on the pillow and the
## cover hides it to the chin.
func _sleeper(tent: Node3D, look: String, bag: Array) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(float(bag[0]), 0.0, 0.0)
	var body := FeltBuilder.build(look)
	body.position = Vector3(0.0, Tuning.num("guests", "tent.lie_y_m", 0.2), float(bag[1]))
	body.rotation = Vector3(deg_to_rad(Tuning.num("guests", "tent.lie_deg", 80.0)), 0.0, 0.0)
	body.scale = Vector3.ONE * Tuning.num("guests", "tent.lie_scale", 1.0)
	holder.add_child(body)
	holder.add_child(FeltBuilder.build(str(bag[2])))
	tent.add_child(holder)
	return holder


## A player on this PC crawls into the camp's tent: they lie in a sleeping bag (the tent opens so you can see them)
## and are ready for bed; interact or back gets them up again. The other PC sees it through `_moved`.
func enter_tent(who: String) -> void:
	if _inside.has(who) or not campers.has(who) or home_tent_index() < 0:
		return
	_lie_down(who)
	campers[who].controlled = false
	campers[who].velocity = Vector3.ZERO
	if not state.day.votes.has(who):
		ask("sleep", [true], who)


func leave_tent(who: String, cancel_bed: bool = true) -> void:
	if not _inside.has(who):
		return
	_get_up(who)
	if not local_ids().has(who):
		return
	if campers.has(who):
		campers[who].controlled = _menu_for != who
	if cancel_bed and state != null and state.day.votes.has(who):
		ask("sleep", [false], who)


## Shows a player (on this PC or the other) in the first free bag of the camp's tent, their camper hidden.
func _lie_down(who: String) -> void:
	if _inside.has(who) or not campers.has(who) or home_tent_index() < 0:
		return
	var bags: Array = Tuning.value("guests", "tent.home_bags", [[0, 0, "bag_cover"]])
	var used: Array = _inside.values().map(func(n: Node3D) -> int: return int(n.get_meta("bag")))
	var bag := 0
	while used.has(bag):
		bag += 1
	var sleeper := _sleeper(clearing.placed[home_tent_index()], str(campers[who].model_id), bags[bag % bags.size()])
	sleeper.set_meta("bag", bag)
	_inside[who] = sleeper
	campers[who].visible = false


func _get_up(who: String) -> void:
	if not _inside.has(who):
		return
	(_inside[who] as Node3D).queue_free()
	_inside.erase(who)
	if campers.has(who):
		campers[who].visible = true


func guests_asleep() -> bool:
	return state != null and state.guests.asleep()


## Each frame: guests go into their tents at bedtime (a sleeper in the bag, the camper hidden); a tent with someone in
## it opens up (the roof lifts away, like a doll's house) while a player on this PC is close by, or always for the
## camp's tent while a player is inside; each guest tent has a bubble with its guest's name.
func _tick_tents() -> void:
	if state == null:
		return
	var night := guests_asleep()
	for id: String in _tents:
		var tent: Node3D = _tents[id]
		if not is_instance_valid(tent) or not state.camp["stays"].has(id):
			continue
		var c: Camper = visitors.get(id)
		if night and not _asleep.has(id):
			_asleep[id] = _sleeper(tent, str(state.camp["stays"][id]["look"]), Tuning.value("guests", "tent.bags")[0])
		elif not night and _asleep.has(id):
			(_asleep[id] as Node3D).queue_free()
			_asleep.erase(id)
		if c:
			c.visible = not night
		_tent_look(tent, "tent_guest", night and _player_near(tent.position))
		if not _bubbles.has(id):
			var bubble := Label3D.new()
			bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			bubble.font_size = int(Tuning.num("guests", "tent.bubble_px", 40))
			bubble.outline_size = int(Tuning.num("guests", "tent.bubble_outline_px", 10))
			bubble.position = Vector3(0, Tuning.num("guests", "tent.bubble_y_m", 2.1), 0)
			tent.add_child(bubble)
			_bubbles[id] = bubble
		(_bubbles[id] as Label3D).text = Tuning.text("tent.asleep" if night else "tent.bubble") % state.camp["stays"][id]["name"]
	for id: String in _asleep.keys():
		if not _tents.has(id) or not state.camp["stays"].has(id):
			(_asleep[id] as Node3D).queue_free()
			_asleep.erase(id)
	for id: String in _bubbles.keys():
		if not _tents.has(id) or not is_instance_valid(_bubbles[id]):
			_bubbles.erase(id)
	if home_tent_index() >= 0:
		_tent_look(clearing.placed[home_tent_index()], "tent", not _inside.is_empty())


func _player_near(at: Vector3) -> bool:
	for who in local_ids():
		if campers.has(who) and (campers[who] as Node3D).position.distance_to(at) <= Tuning.num("guests", "tent.peek_m", 2.8):
			return true
	return false


## Shows a tent closed, or open with its roof lifted away (the model's "_open" variant).
func _tent_look(tent: Node3D, model: String, open: bool) -> void:
	var mesh := tent.get_child(0) as MeshInstance3D
	var want := FeltBuilder.mesh(model + "_open" if open else model)
	if mesh and mesh.mesh != want:
		mesh.mesh = want


func is_open(tent: Node3D, model: String) -> bool:
	return (tent.get_child(0) as MeshInstance3D).mesh == FeltBuilder.mesh(model + "_open")

