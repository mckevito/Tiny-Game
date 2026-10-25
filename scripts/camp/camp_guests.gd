class_name CampGuests
extends RefCounted
## Stage B's guests: each brings one small request, each stay is scored once when it ends (comfort, things to do,
## atmosphere) with a line that names its cause, and advance bookings wait on the board to be accepted, moved a day
## or declined, never with a penalty. Also the day's three goals (a quick task, a project, a dream). The host's copy
## decides; every rule takes a profile ID and returns "" or a text key. Numbers: data/guests.json.

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## What the last allowed give paid, and to whom.
var last_tip := 0
var last_stay := ""


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _v(key: String, fallback: Variant = null) -> Variant:
	return Tuning.value("guests", key, fallback)


# --- Requests ----------------------------------------------------------------------------------------------------

## The request a new guest brings on day `today`, the n-th in turn from request_order among those open that day.
static func new_request(n: int, today: int = 1 << 30) -> Dictionary:
	var order: Array = (_v("request_order", []) as Array).filter(func(k: String) -> bool:
			return int(_v("requests.%s.from_day" % k, 1)) <= today)
	if order.is_empty():
		return {}
	return {"kind": str(order[n % order.size()]), "done": false}


## The stay's request kind while it is still open, or "".
func open_request(stay_id: String) -> String:
	var req: Dictionary = state.camp["stays"].get(stay_id, {}).get("request", {})
	return "" if req.is_empty() or bool(req.get("done", false)) else str(req.get("kind", ""))


## The kind of item a request asks to be handed over, or "" for one met by the camp itself.
static func gift_kind(request_kind: String) -> String:
	return str(_v("requests.%s.give" % request_kind, ""))


func _met(stay_id: String) -> void:
	var stay: Dictionary = state.camp["stays"][stay_id]
	stay["request"]["done"] = true
	last_tip = int(_v("requests.%s.tip" % stay["request"]["kind"], 0))
	last_stay = stay_id
	state.camp["coins"] = int(state.camp.get("coins", 0)) + last_tip


## A guest with an open give-request who stands within talk reach of a player, or "".
func guest_near(profile_id: String) -> String:
	var at := state.player_pos(profile_id)
	for id: String in state.camp["stays"]:
		if gift_kind(open_request(id)) != "" and state.day.stand_point(id).distance_to(at) <= float(_v("talk_reach_m", 2.0)):
			return id
	return ""


## Hands a guest what they asked for from the player's Pack; their tip is paid at once.
func give(profile_id: String, stay_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	var want := gift_kind(open_request(stay_id))
	if want == "":
		return "deny.no_request"
	if state.day.stand_point(stay_id).distance_to(state.player_pos(profile_id)) \
			> float(_v("talk_reach_m", 2.0)) + Tuning.num("tuning", "carry.reach_slack_m"):
		return "deny.too_far"
	if state.pack.take(profile_id, want) == "":
		return "deny.nothing_to_give"
	_met(stay_id)
	return ""


## Meets every open request that the camp itself now answers (a chair by the tent). Returns the stays met.
func check_near_requests() -> Array[String]:
	var met: Array[String] = []
	for id: String in state.camp["stays"]:
		var kind := open_request(id)
		var models: Array = _v("requests.%s.near" % kind, []) if kind != "" else []
		if not models.is_empty() and _near_pitch(id, models, float(_v("requests.%s.radius_m" % kind, 3.0))):
			_met(id)
			met.append(id)
	return met


## True when one of the models stands within radius of a stay's pitch: a camp object or a piece of scenery.
func _near_pitch(stay_id: String, models: Array, radius: float) -> bool:
	var pitch: Dictionary = state.camp["objects"].get(state.camp["stays"][stay_id].get("pitch", ""), {})
	if pitch.is_empty():
		return false
	var at := Vector2(float(pitch["pos"][0]), float(pitch["pos"][1]))
	for id: String in state.camp["objects"]:
		if models.has(state.camp["objects"][id]["model"]) and not state.carriers.has(id) \
				and state.object_pos(id).distance_to(at) <= radius:
			return true
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		if models.has(row.get("model", "")):
			var o := Clearing.placement_transform(row).origin
			if Vector2(o.x, o.z).distance_to(at) <= radius:
				return true
	return false


# --- Satisfaction ------------------------------------------------------------------------------------------------

## A stay's score, once, when it ends: {name, points, mood, loved, wished, tip}. loved and wished are cause names
## (data/guests.json satisfaction.sources), or "".
func review(stay_id: String) -> Dictionary:
	var stay: Dictionary = state.camp["stays"][stay_id]
	var points := 0
	var loved := ""
	var wished := ""
	var default_r := float(_v("satisfaction.radius_m", 6.0))
	for src: Dictionary in _v("satisfaction.sources", []):
		var ok := false
		if bool(src.get("request", false)):
			ok = not (stay.get("request", {}) as Dictionary).is_empty() and bool(stay["request"].get("done", false))
		else:
			ok = _near_pitch(stay_id, src.get("near", []), float(src.get("radius_m", default_r)))
		if ok:
			points += 1
			if loved == "":
				loved = str(src["cause"])
		elif wished == "":
			wished = str(src["cause"])
	var mood := ""
	for row: Array in _v("satisfaction.moods", []):
		if points >= int(row[0]):
			mood = str(row[1])
	return {"name": stay.get("name", ""), "points": points, "mood": mood, "loved": loved, "wished": wished,
			"tip": points * int(_v("satisfaction.tip_per_point", 0))}


# --- Bookings ----------------------------------------------------------------------------------------------------

func bookings() -> Array:
	return state.camp["reservations"]


## A booking's plan in data/guests.json, or {}.
static func plan(id: String) -> Dictionary:
	for row: Dictionary in _v("bookings", []):
		if str(row.get("id", "")) == id:
			return row
	return {}


func row(id: String) -> Dictionary:
	for r: Dictionary in bookings():
		if str(r.get("id", "")) == id:
			return r
	return {}


## Puts each booking whose offer day has come on the board. Returns the ids newly offered.
func refresh_offers() -> Array[String]:
	var added: Array[String] = []
	var today := state.day.today()
	for p: Dictionary in _v("bookings", []):
		var id := str(p.get("id", ""))
		if int(p.get("offer_day", 0)) <= today and row(id).is_empty():
			bookings().append({"id": id, "state": "offered", "arrive_day": maxi(int(p.get("arrive_day", 0)), today + 1)})
			added.append(id)
	return added


## The booking the board shows: the first one offered, accepted or staying, or {}.
func current() -> Dictionary:
	for r: Dictionary in bookings():
		if r.get("state", "") in ["offered", "accepted", "arrived"]:
			return r
	return {}


## Accept an offered booking, ask an offered or accepted one to come a day later, or decline it.
func decide(profile_id: String, id: String, choice: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	var r := row(id)
	var now := str(r.get("state", ""))
	if not now in ["offered", "accepted"]:
		return "deny.no_booking"
	match choice:
		"accept":
			if now != "offered":
				return "deny.no_booking"
			r["state"] = "accepted"
		"later":
			r["arrive_day"] = maxi(int(r["arrive_day"]), state.day.today()) + 1
		"decline":
			r["state"] = "declined"
		_:
			return "deny.no_booking"
	return ""


func pitches_needed(id: String) -> int:
	return int(plan(id).get("essential", {}).get("pitches", 1))


## Free pitches a walk-in guest must leave for a booking due today that hasn't arrived yet.
func pitches_held() -> int:
	var held := 0
	for r: Dictionary in bookings():
		if r.get("state", "") == "accepted" and int(r["arrive_day"]) <= state.day.today():
			held += pitches_needed(str(r["id"]))
	return held


## The built pitches nobody is staying at.
func free_pitches() -> Array[String]:
	var taken := {}
	for stay: Dictionary in state.camp["stays"].values():
		taken[stay.get("pitch", "")] = true
	var out: Array[String] = []
	for id: String in state.camp["objects"]:
		if CampBuild.kind_of(state, id) == "pitch" and not taken.has(id):
			out.append(id)
	return out


func count_built(kind: String) -> int:
	var n := 0
	for id: String in state.camp["objects"]:
		n += 1 if CampBuild.kind_of(state, id) == kind else 0
	return n


## From the arrival hour an accepted booking due today (or waiting since) arrives if it has room, each guest at
## their own free pitch with their own request. Returns the new stay ids.
func maybe_arrive() -> Array[String]:
	var made: Array[String] = []
	if state.day.hour() < Tuning.num("day", "stays.arrive_hour", 9.0):
		return made
	for r: Dictionary in bookings():
		if r.get("state", "") != "accepted" or int(r["arrive_day"]) > state.day.today():
			continue
		var p := plan(str(r["id"]))
		var free := free_pitches()
		if free.size() < pitches_needed(str(r["id"])):
			continue
		var names: Array = Tuning.value("text", "booking.%s.guests" % r["id"], ["Guest"])
		var looks: Array = p.get("looks", ["guest_a"])
		for i in pitches_needed(str(r["id"])):
			var n := int(state.camp.get("next_object_id", 1))
			state.camp["next_object_id"] = n + 1
			var id := "stay_%d" % n
			state.camp["stays"][id] = {"pitch": free[i], "name": str(names[i % names.size()]),
					"look": str(looks[i % looks.size()]), "nights_left": int(p.get("nights", 1)),
					"arrived": state.day.today(), "booking": r["id"], "request": new_request(n, state.day.today())}
			made.append(id)
		var extras: Array = []
		var bonus := 0
		for opt: Dictionary in p.get("optional", []):
			if count_built(str(opt["build"])) > 0:
				extras.append(opt["build"])
				bonus += int(opt.get("bonus", 0))
		r["state"] = "arrived"
		r["extras"] = extras
		r["bonus"] = bonus
		r["paid"] = false
	return made


## The night's part for bookings: unpaid extras bonuses (paid once), and bookings whose guests have all gone are
## done. Returns [{id, extras, coins}].
func settle_bonuses() -> Array:
	var out: Array = []
	for r: Dictionary in bookings():
		if r.get("state", "") == "arrived" and not bool(r.get("paid", false)):
			r["paid"] = true
			out.append({"id": r["id"], "extras": r.get("extras", []), "coins": int(r.get("bonus", 0))})
	return out


func finish_departed() -> void:
	for r: Dictionary in bookings():
		if r.get("state", "") != "arrived":
			continue
		var staying := false
		for stay: Dictionary in state.camp["stays"].values():
			staying = staying or stay.get("booking", "") == r["id"]
		if not staying:
			r["state"] = "done"


# --- Words for the board, the report and the goals ---------------------------------------------------------------

## A day number as the player reads it, such as "Spring, day 3".
static func day_label(n: int) -> String:
	var seasons: Array = Tuning.value("day", "calendar.seasons", ["spring"])
	var per := int(Tuning.num("day", "calendar.days_per_season", 14))
	var i := maxi(n - 1, 0)
	var season := str(seasons[(i / per) % seasons.size()])
	return Tuning.text("clock.day_label") % [Tuning.text("clock.season." + season), i % per + 1]


## One booking on one line: who, when, what it needs and what's nice to have.
func booking_line(r: Dictionary) -> String:
	var id := str(r.get("id", ""))
	var line := Tuning.text("booking.line") % [Tuning.text("booking.%s.name" % id), Tuning.text("booking.state."
			+ str(r.get("state", "offered"))), day_label(int(r.get("arrive_day", 0))), pitches_needed(id)]
	var extras: PackedStringArray = []
	for opt: Dictionary in plan(id).get("optional", []):
		extras.append(Tuning.text("booking.extra") % [Tuning.text("build." + str(opt["build"])), int(opt.get("bonus", 0))])
	if not extras.is_empty():
		line += Tuning.text("booking.extras") % ", ".join(extras)
	if r.get("state", "") == "accepted" and int(r["arrive_day"]) <= state.day.today():
		var short := pitches_needed(id) - free_pitches().size()
		if short > 0:
			line += Tuning.text("booking.waiting") % short
	return line


## The day's three goals: a quick task, a project for today and a bigger dream, as lines of text.
func goals() -> Array[String]:
	var quick := Tuning.text("goal.fish")
	for id: String in state.camp["stays"]:
		if open_request(id) != "":
			quick = Tuning.text("goal.request") % [state.camp["stays"][id]["name"],
					Tuning.text("request.want." + open_request(id))]
			break
	var project := Tuning.text("goal.pitch")
	var r := current()
	var id := str(r.get("id", ""))
	if r.get("state", "") == "offered":
		project = Tuning.text("goal.offer") % [Tuning.text("booking.%s.name" % id), day_label(int(r["arrive_day"]))]
	elif r.get("state", "") == "accepted":
		var short := pitches_needed(id) - count_built("pitch")
		project = (Tuning.text("goal.pitches") % [short, Tuning.text("booking.%s.name" % id), day_label(int(r["arrive_day"]))]
				if short > 0 else Tuning.text("goal.ready") % [Tuning.text("booking.%s.name" % id), day_label(int(r["arrive_day"]))])
	var dream := Tuning.text("goal.cosy")
	for kind: String in CampBuild.kinds():
		if bool(CampBuild.kinds()[kind].get("improvement", false)) and count_built(kind) == 0:
			dream = Tuning.text("goal.build") % [Tuning.text("build." + kind), CampBuild.cost(kind),
					Tuning.text("improvement." + kind)]
			break
	return [Tuning.text("report.goal_quick") % quick, Tuning.text("report.goal_project") % project,
			Tuning.text("report.goal_dream") % dream]
