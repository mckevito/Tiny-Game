class_name CampStory
extends RefCounted
## The arrival evening with Ranger Burl (owner picks, 26 Oct 2026). A camp the menu starts new opens with his letter;
## he waits by the cold fire and asks for what lights it (data/ranger.json fire), from either player's Pack or the
## camp box; once it burns the players name the camp, and he hands over his clipboard. The camp's "story" step is
## "fire" (the fire is cold), "name" (it burns; the camp waits for a name) or "done", and a camp made any other way
## (tests, older saves) is "done" from the start. Names the players chose live in the camp's "names" ("" means the
## default in data/text.json names.*); either player can repaint the camp sign at any time. The host's copy decides;
## every rule takes a profile ID and returns "" or a text key.
##
## After the evening Burl gives story jobs one at a time (data/ranger_jobs.json), kept in the story's "job" (the
## index of his current job), "asked" (true once he has given it) and "have" (steps toward a job counted from the
## players' steps).

var state: CampState:
	get:
		return _state.get_ref()
var _state: WeakRef


func _init(camp_state: CampState) -> void:
	_state = weakref(camp_state)


## Starts the arrival evening on a new camp: the fire goes cold until it is given what it needs.
func begin() -> void:
	state.camp["story"] = {"step": "fire", "given": {}}


func step() -> String:
	return str(state.camp.get("story", {}).get("step", "done"))


## True once the camp's first fire burns (grilling and the fire's upgrades wait for it).
func lit() -> bool:
	return step() != "fire"


func given() -> Dictionary:
	var story: Dictionary = state.camp["story"]
	if not story.has("given"):
		story["given"] = {}
	return story["given"]


## What lights the first fire: item -> how many (data/ranger.json fire).
static func needs() -> Dictionary:
	return Tuning.value("ranger", "fire", {})


## What the cold fire still needs: item -> how many ({} once it burns).
func missing() -> Dictionary:
	var out := {}
	if lit():
		return out
	for item: String in needs():
		var left := int(needs()[item]) - int(given().get(item, 0))
		if left > 0:
			out[item] = left
	return out


## A list of items in words, such as "3 sticks and 1 wood" (data/text.json story.need, story.and).
static func words(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item: String in items:
		parts.append(Tuning.text("story.need") % [int(items[item]), Tuning.text("items." + item)])
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, -1)) + Tuning.text("story.and") + parts[-1]


func can_feed(profile_id: String) -> bool:
	var left := missing()
	return left.keys().any(func(item: String) -> bool: return state.pack.have(profile_id, item) > 0)


## A player at the cold fire lays on what it still needs, from their Pack first, then the camp box. The last piece
## lights it, and the camp waits for a name.
func feed_fire(profile_id: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if lit():
		return "deny.fire_lit_already"
	if not CampPack.can_cook_at(state.player_pos(profile_id)):
		return "deny.too_far"
	if not can_feed(profile_id):
		return "deny.nothing_for_fire"
	var left := missing()
	for item: String in left:
		var n := mini(int(left[item]), state.pack.have(profile_id, item))
		if n > 0 and state.pack.spend(profile_id, item, n):
			given()[item] = int(given().get(item, 0)) + n
	if missing().is_empty():
		state.camp["story"] = {"step": "name", "given": {}}
	return ""


# --- Ranger Burl's story jobs ------------------------------------------------------------------------------------

## Coins the last jobs Burl thanked the players for paid, and the ids of those jobs (for the host's toasts).
var paid := 0
var thanked: Array[String] = []


static func jobs() -> Array:
	return Tuning.value("ranger_jobs", "jobs", [])


static func job_row(id: String) -> Dictionary:
	for row: Dictionary in jobs():
		if str(row.get("id", "")) == id:
			return row
	return {}


func _story() -> Dictionary:
	if not state.camp.has("story"):
		state.camp["story"] = {"step": "done", "given": {}}
	return state.camp["story"]


func job_index() -> int:
	return int(_story().get("job", 0))


## Burl's current job (data/ranger_jobs.json), or {} once every job is done.
func job() -> Dictionary:
	var i := job_index()
	return jobs()[i] if i >= 0 and i < jobs().size() else {}


## True once Burl has given his current job.
func asked() -> bool:
	return bool(_story().get("asked", false))


## How far the current job has come: builds standing now, the camp's stars, or the players' steps since he asked.
func job_have() -> int:
	return _have(job_index())


func _have(i: int) -> int:
	if i < 0 or i >= jobs().size():
		return 0
	var need := str(jobs()[i].get("need", ""))
	if need == "stars":
		return state.rating.stars()
	if need.begins_with("has:"):
		var n := 0
		for id: String in state.camp["objects"]:
			if CampBuild.kind_of(state, id) == need.trim_prefix("has:"):
				n += 1
		return n
	return int(_story().get("have", 0)) if i == job_index() and asked() else 0


func job_ready() -> bool:
	return asked() and not job().is_empty() and job_have() >= int(job().get("count", 1))


## True while Burl has something new to say: the next job to give, or a done job to thank them for.
func has_word() -> bool:
	return step() == "done" and not job().is_empty() and (not asked() or job_ready())


## What Burl says when a player talks to him now, in order: [{"say": "thanks" or "ask", "job": index}]. A job that
## is already done when he gives it (a pitch built before he asked) is thanked for straight away.
func talk_plan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if step() != "done":
		return out
	var i := job_index()
	var given := asked()
	while i < jobs().size():
		if not given:
			out.append({"say": "ask", "job": i})
			given = true
		elif _have(i) >= int(jobs()[i].get("count", 1)):
			out.append({"say": "thanks", "job": i})
			i += 1
			given = false
		else:
			break
	return out


## A player talks to Burl: he thanks them for what is done (paying its coins) and gives the next job.
func hear(profile_id: String) -> String:
	paid = 0
	thanked.clear()
	if not state.online.has(profile_id):
		return "deny.not_here"
	if not near_ranger(state.player_pos(profile_id)):
		return "deny.too_far"
	var plan := talk_plan()
	if plan.is_empty():
		return "deny.nothing_new"
	var story := _story()
	for part: Dictionary in plan:
		var row: Dictionary = jobs()[int(part["job"])]
		if part["say"] == "thanks":
			paid += int(row.get("coins", 0))
			thanked.append(str(row["id"]))
			story["job"] = int(part["job"]) + 1
			story["asked"] = false
		else:
			story["job"] = int(part["job"])
			story["asked"] = true
		story["have"] = 0
	state.camp["coins"] = int(state.camp.get("coins", 0)) + paid
	return ""


## A step the players took ("give", "cook", "build:pitch"...). True when it just finished Burl's current job.
func note(event: String) -> bool:
	if step() != "done" or not asked() or job().is_empty():
		return false
	var need := str(job().get("need", ""))
	var count := int(job().get("count", 1))
	if need.begins_with("has:"):
		return event == "build:" + need.trim_prefix("has:") and job_have() == count
	if need == "stars" or (event != need and not event.begins_with(need + ":")):
		return false
	_story()["have"] = mini(int(_story().get("have", 0)) + 1, count)
	return int(_story()["have"]) == count


# --- Names ---------------------------------------------------------------------------------------------------------

func camp_name() -> String:
	var chosen := str(state.camp.get("names", {}).get("camp", ""))
	return chosen if chosen != "" else Tuning.text("names.camp")


func ranger_name() -> String:
	var chosen := str(state.camp.get("names", {}).get("ranger", ""))
	return chosen if chosen != "" else Tuning.text("names.ranger")


## A typed name tidied up: no line breaks, single spaces, at most data/ranger.json name_max letters.
static func clean(text: String) -> String:
	var out := " ".join(text.replace("\n", " ").replace("\t", " ").split(" ", false))
	return out.left(int(Tuning.num("ranger", "name_max", 28))).strip_edges()


## A player names the camp while the ranger asks for a name (wherever they stand when the fire catches), or
## repaints it at the camp sign any time after. The first name finishes the arrival evening.
func name_camp(profile_id: String, text: String) -> String:
	if not state.online.has(profile_id):
		return "deny.not_here"
	if step() != "name" and not near_sign(state.player_pos(profile_id)):
		return "deny.too_far"
	var name := clean(text)
	if name == "":
		return "deny.name_empty"
	if not state.camp.has("names"):
		state.camp["names"] = {}
	state.camp["names"]["camp"] = name
	if step() == "name":
		state.camp["story"] = {"step": "done", "given": {}}
	return ""


# --- Where things are ----------------------------------------------------------------------------------------------

static func ranger_pos() -> Vector2:
	var p: Array = Tuning.value("ranger", "pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func near_ranger(pos: Vector2) -> bool:
	return pos.distance_to(ranger_pos()) <= Tuning.num("ranger", "talk_m", 1.8)


## The camp sign's index among the clearing's placements (-1 when there is none).
static func sign_index() -> int:
	var rows: Array = Tuning.table("clearing").get("placements", [])
	for i in rows.size():
		if str(rows[i].get("model", "")) == str(Tuning.value("ranger", "sign.model", "camp_sign")):
			return i
	return -1


static func sign_pos() -> Vector2:
	var i := sign_index()
	if i < 0:
		return Vector2(INF, INF)
	var o := Clearing.placement_transform(Tuning.table("clearing")["placements"][i]).origin
	return Vector2(o.x, o.z)


static func near_sign(pos: Vector2) -> bool:
	return pos.distance_to(sign_pos()) <= Tuning.num("ranger", "sign.reach_m", 1.6)
