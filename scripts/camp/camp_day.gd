class_name CampDay
extends RefCounted
## Stage A's day: the clock, guests who come to a free pitch, the sleep vote and the night that pays them. The
## host's copy decides; a guest PC's copy only runs its clock between the host's updates. A night pays exactly once:
## the save keeps the number of the last night that paid ("last_settled"), so a repeated vote, a reload or a
## reconnect can never pay it again. Numbers: data/day.json.

## The camp state this belongs to, held weakly so the two don't keep each other alive.
var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef
## Profile ids of the players ready for bed. Not saved: a reload or a reconnect starts the vote again.
var votes: Array[String] = []


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("day", key, fallback)


func calendar() -> Dictionary:
	return state.camp["calendar"]


## Game minutes since the morning (data/day.json clock.start_hour).
func minute() -> float:
	return float(calendar().get("minute", 0))


static func day_minutes() -> float:
	return (_n("clock.end_hour", 22.0) - _n("clock.start_hour", 7.0)) * 60.0


## The time of day in hours, such as 9.5 for half past nine.
func hour() -> float:
	return _n("clock.start_hour", 7.0) + minute() / 60.0


func is_evening() -> bool:
	return hour() >= _n("clock.evening_hour", 18.0)


## Moves the clock on by `seconds` of real time. It stops at the end of the day and waits there for bed.
func advance(seconds: float) -> void:
	var rate := day_minutes() / maxf(_n("clock.real_seconds_per_day", 1200.0), 1.0)
	calendar()["minute"] = minf(minute() + seconds * rate, day_minutes())


## The number of a day counted from the first morning of year one (day 1).
static func day_number(cal: Dictionary) -> int:
	var seasons: Array = Tuning.value("day", "calendar.seasons", ["spring"])
	var per := int(_n("calendar.days_per_season", 14))
	return (int(cal.get("year", 1)) - 1) * seasons.size() * per + maxi(seasons.find(cal.get("season")), 0) * per \
			+ int(cal.get("day", 1))


func today() -> int:
	return day_number(calendar())


## Turns the calendar to the next morning: the next day, season or year.
func _next_morning() -> void:
	var cal := calendar()
	var seasons: Array = Tuning.value("day", "calendar.seasons", ["spring"])
	cal["day"] = int(cal.get("day", 1)) + 1
	if cal["day"] > int(_n("calendar.days_per_season", 14)):
		cal["day"] = 1
		var next := maxi(seasons.find(cal.get("season")), 0) + 1
		if next >= seasons.size():
			next = 0
			cal["year"] = int(cal.get("year", 1)) + 1
		cal["season"] = seasons[next]
	cal["minute"] = 0


# --- Sleep -------------------------------------------------------------------------------------------------------

## A player says they are ready for bed (or not any more). Returns "" or a text key saying why not.
func vote(profile_id: String, ready: bool) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if ready and not votes.has(profile_id):
		votes.append(profile_id)
	elif not ready:
		votes.erase(profile_id)
	return ""


## Everyone in the camp now is ready for bed.
func everyone_ready() -> bool:
	if state.online.is_empty():
		return false
	for id in state.online:
		if not votes.has(id):
			return false
	return true


## The night: each guest pays for their pitch, a guest whose stay is over is scored and tips (Stage B), a booking
## that arrived today pays its extras bonus, the calendar turns to the next morning, and guests whose stay is over
## head home. The sell crate pays too (sale). Returns the night's summary {night, coins, lines, left, reviews, bonuses, sale}, or {} when this day already
## paid.
func settle_night() -> Dictionary:
	var night := today()
	if int(state.camp.get("last_settled", 0)) >= night:
		return {}
	var stays: Dictionary = state.camp["stays"]
	var lines: Array = []
	var total := 0
	var left: Array = []
	var reviews: Array = []
	for id: String in stays:
		var stay: Dictionary = stays[id]
		var kind := CampBuild.kind_of(state, str(stay.get("pitch", "")))
		var price := int(Tuning.num("day", "lodging." + kind))
		total += price
		lines.append({"name": stay["name"], "coins": price, "kind": kind})
		stay["nights_left"] = int(stay.get("nights_left", 1)) - 1
		if stay["nights_left"] <= 0:
			left.append(id)
			var review := state.guests.review(id)
			total += int(review["tip"])
			reviews.append(review)
	var bonuses := state.guests.settle_bonuses()
	for b: Dictionary in bonuses:
		total += int(b["coins"])
	var sale := state.projects.settle_crate()
	total += int(sale["coins"])
	state.camp["coins"] = int(state.camp.get("coins", 0)) + total
	var summary := {"night": night, "coins": total, "lines": lines, "left": left, "reviews": reviews, "bonuses": bonuses,
			"sale": sale}
	(state.camp["ledger"] as Array).append(summary.duplicate(true))
	state.camp["last_settled"] = night
	for id in left:
		stays.erase(id)
	state.guests.finish_departed()
	_next_morning()
	state.gather.new_day()
	state.guests.refresh_offers()
	votes.clear()
	state.build.undo.clear()
	return summary


# --- Guests ------------------------------------------------------------------------------------------------------

## A built pitch nobody is staying at, or "".
func free_pitch() -> String:
	var free := state.guests.free_pitches()
	return free[0] if not free.is_empty() else ""


## Everyone who comes now: from the arrival hour a booking due today arrives first (Stage B), then a walk-in guest.
## Returns the new stay ids.
func arrivals() -> Array[String]:
	var made := state.guests.maybe_arrive()
	var walk_in := maybe_arrive()
	if walk_in != "":
		made.append(walk_in)
	return made


## From the arrival hour a walk-in guest comes to a free pitch, if there is one past those a booking due today still
## waits for and the camp has room for another walk-in. They bring a request (Stage B). Returns the new stay's id,
## or "".
func maybe_arrive() -> String:
	if hour() < _n("stays.arrive_hour", 9.0):
		return ""
	var walk_ins := 0
	for stay: Dictionary in state.camp["stays"].values():
		walk_ins += 0 if stay.has("booking") else 1
	if walk_ins >= int(_n("stays.max_stays", 1)):
		return ""
	var free := state.guests.free_pitches()
	if free.size() <= state.guests.pitches_held():
		return ""
	var n := int(state.camp.get("next_object_id", 1))
	state.camp["next_object_id"] = n + 1
	var looks: Array = Tuning.value("day", "stays.looks", ["guest_a"])
	var names: Array = Tuning.value("text", "guest.names", ["Guest"])
	var id := "stay_%d" % n
	state.camp["stays"][id] = {"pitch": free[0], "name": str(names[n % names.size()]),
			"look": str(looks[n % looks.size()]), "nights_left": int(_n("stays.nights", 1)), "arrived": today(),
			"request": CampGuests.new_request(n, today())}
	return id


## The pitch a building's guest stays at, or "" when nobody is staying there.
func stay_at(object_id: String) -> String:
	for id: String in state.camp["stays"]:
		if state.camp["stays"][id].get("pitch", "") == object_id:
			return id
	return ""


## Where a guest stands at their pitch, in camp space.
func stand_point(stay_id: String) -> Vector2:
	var stay: Dictionary = state.camp["stays"][stay_id]
	var row: Dictionary = state.camp["objects"].get(stay.get("pitch", ""), {"pos": [0, 0], "yaw": 0})
	var off: Array = Tuning.value("day", "stays.stand_offset", [1.0, 1.0])
	return Vector2(float(row["pos"][0]), float(row["pos"][1])) \
			+ Vector2(float(off[0]), float(off[1])).rotated(-deg_to_rad(float(row.get("yaw", 0))))
