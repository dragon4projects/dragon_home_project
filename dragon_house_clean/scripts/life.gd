extends RefCounted
const MediaRuntime = preload("res://scripts/media_runtime.gd")
## Autonomous utility/need scheduler. No external events or AI dependency.
var world
var media_runtime = MediaRuntime.new()
var rng := RandomNumberGenerator.new()
var clock := 0.0
var max_jobs_per_tick := 2
var log: Array = []
var steps := 0

const INTENTS := {
	"REST": ["rest", "private"], "SLEEP": ["rest", "private"],
	"WORK_CREATE": ["study", "workshop"], "READ_BOOK": ["library", "rest"],
	"GET_COFFEE": ["common"], "WATCH_FIRE": ["common"],
	"TALK_PAIR": ["common", "rest"], "LISTEN_MUSIC": ["music"],
	"WATCH_FILM": ["cinema"], "VIEW_ART": ["artifact"],
	"PURPOSEFUL_EXPLORE": ["arrival", "corridor", "study", "library", "artifact", "rest"]
}

func setup(p_world) -> void:
	world = p_world
	media_runtime.setup(world)
	rng.seed = 814223
	clock = world.sim_clock

func daypart() -> String:
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	if hour < 6:
		return "night"
	if hour < 11:
		return "morning"
	if hour < 18:
		return "day"
	return "evening"

func _utilities(actor: Dictionary) -> Dictionary:
	var need: Dictionary = actor.get("needs", {})
	var traits: Dictionary = actor.get("traits", {})
	var rest := float(need.get("rest", 0.4))
	var social := float(need.get("social", 0.4))
	var curiosity := float(need.get("curiosity", 0.4))
	var phase := daypart()
	var scores: Dictionary = {
		"REST": 0.3 + rest * 1.2, "SLEEP": 0.1 + rest * 1.5,
		"WORK_CREATE": 0.55 + curiosity * 0.5,
		"GET_COFFEE": 0.65,
		"WATCH_FIRE": 0.4 + (0.35 if phase == "evening" else 0.0),
		"TALK_PAIR": 0.2 + social * 1.0,
		"READ_BOOK": 0.3 + float(traits.get("reading", 0.3)) + curiosity * 0.3,
		"LISTEN_MUSIC": 0.2 + float(traits.get("music", 0.3)),
		"WATCH_FILM": 0.3 + (0.35 if phase == "evening" else 0.0),
		"VIEW_ART": 0.2 + curiosity * 0.8,
		"PURPOSEFUL_EXPLORE": 0.2 + curiosity * 0.35
	}
	if phase == "night":
		scores["SLEEP"] += 1.0
		scores["TALK_PAIR"] -= 0.4
	if phase == "morning":
		scores["GET_COFFEE"] += 0.6
		scores["WORK_CREATE"] += 0.2
	if phase == "day":
		scores["WORK_CREATE"] += 0.45
	if actor["id"] == "MANJKA":
		return {"REST": 0.2 + rest, "PURPOSEFUL_EXPLORE": 1.0 + curiosity}
	if media_runtime.available_books().is_empty():
		scores.erase("READ_BOOK")
	if media_runtime.playable("films").is_empty():
		scores.erase("WATCH_FILM")
	if media_runtime.playable("tracks").is_empty():
		scores.erase("LISTEN_MUSIC")
	return scores

func choose_intent(actor: Dictionary) -> Dictionary:
	var scored: Dictionary = _utilities(actor)
	var best := ""
	var best_score := -999.0
	var best_room: Dictionary = {}
	for intent in scored:
		var types: Array = INTENTS[intent]
		var candidates: Array = world.matching_rooms(types, actor["id"])
		if candidates.is_empty():
			continue
		var destination: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var path: Array = world.find_route(actor["room_id"], destination["id"], actor["id"])
		if path.is_empty():
			continue
		var habits: Dictionary = actor.get("habits", {})
		var repeat_bonus := minf(float(habits.get(intent, 0.0)), 0.3)
		var path_cost: float = maxf(0.0, float(path.size() - 1) * 0.045)
		var score: float = float(scored[intent]) + repeat_bonus - path_cost + rng.randf_range(-0.2, 0.2)
		if intent == "TALK_PAIR" and rng.randf() > 0.15:
			# Reserve actual social sessions later; do not fake dialogue.
			continue
		if score > best_score:
			best_score = score
			best = intent
			best_room = destination
	if best == "":
		return {}
	return {"intent": best, "room": best_room}

func _choose_partner(actor: Dictionary, destination: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := 99999
	for id in world.residents:
		var other: Dictionary = world.residents[id]
		if id == actor["id"] or id == "MANJKA" or not other.get("active", false):
			continue
		if other.get("partner_id", "") != "" or other.get("phase", "idle") == "travel":
			continue
		if float(other.get("until", 0.0)) > clock:
			continue
		if float(other.get("needs", {}).get("social", 0.0)) < 0.15:
			continue
		var route: Array = world.find_route(other.get("room_id", ""), destination["id"], id)
		if route.is_empty():
			continue
		if route.size() < best_cost:
			best_cost = route.size()
			best = other
	return best

func _record(message: String) -> void:
	log.push_back(message)
	while log.size() > 60:
		log.pop_front()

func _assign(actor: Dictionary, task: Dictionary) -> void:
	if task.is_empty():
		actor["until"] = clock + 15.0
		return
	var room: Dictionary = task["room"]
	var route: Array = world.find_route(actor["room_id"], room["id"], actor["id"])
	if route.is_empty():
		actor["until"] = clock + 15.0
		return
	if task["intent"] == "READ_BOOK":
		var books: Array = media_runtime.available_books()
		if books.is_empty():
			actor["until"] = clock + 12.0
			return
		var book_id: String = books[rng.randi_range(0, books.size() - 1)]["id"]
		if not media_runtime.borrow(actor["id"], book_id, int(Time.get_unix_time_from_system())):
			actor["until"] = clock + 12.0
			return
		actor["held_book"] = book_id
	var session_end := 0.0
	if task["intent"] == "TALK_PAIR":
		var other: Dictionary = _choose_partner(actor, room)
		if other.is_empty():
			actor["until"] = clock + 10.0
			return
		var other_route: Array = world.find_route(other["room_id"], room["id"], other["id"])
		session_end = clock + maxf(float(route.size()), float(other_route.size())) * 3.2 + 34.0
		other["intent"] = "TALK_PAIR"
		other["phase"] = "travel" if other_route.size() > 1 else "perform"
		other["route"] = other_route
		other["path_index"] = 1
		other["until"] = session_end
		other["partner_id"] = actor["id"]
		actor["partner_id"] = other["id"]
		_record("%s и %s — встретились для разговора" % [actor.get("name", ""), other.get("name", "")])
	actor["intent"] = task["intent"]
	actor["phase"] = "travel" if route.size() > 1 else "perform"
	actor["route"] = route
	actor["path_index"] = 1
	actor["until"] = session_end if task["intent"] == "TALK_PAIR" else clock + rng.randf_range(20.0, 40.0) + float(route.size()) * 2.0
	var habits: Dictionary = actor.get("habits", {})
	habits[task["intent"]] = minf(0.3, float(habits.get(task["intent"], 0.0)) + 0.012)
	actor["habits"] = habits
	if task["intent"] != "TALK_PAIR":
		_record("%s → %s" % [actor.get("name", actor["id"]), task["intent"]])
	steps += 1

func _move(actor: Dictionary, delta: float) -> void:
	var route: Array = actor.get("route", [])
	var idx := int(actor.get("path_index", 0))
	if idx >= route.size():
		actor["phase"] = "perform"
		return
	var room: Dictionary = world.room_by_id(route[idx])
	if room.is_empty():
		actor["phase"] = "idle"
		actor["route"] = []
		return
	var at := Vector2(float(actor["x"]), float(actor.get("visual_y", float(actor["level"]) * world.FLOOR_H)))
	var to := Vector2(float(room["x"]) * world.MODULE_W, float(room["level"]) * world.FLOOR_H)
	var advance := 2.1 * delta if actor["id"] != "MANJKA" else 2.9 * delta
	var next: Vector2 = at.move_toward(to, advance)
	actor["x"] = next.x
	# Continuous vertical interpolated movement for lift motion.
	actor["visual_y"] = next.y
	if next.distance_to(to) <= 0.04:
		actor["room_id"] = room["id"]
		actor["level"] = room["level"]
		actor["path_index"] = idx + 1
		if int(actor["path_index"]) >= route.size():
			actor["phase"] = "perform"
	else:
		# Keep logical floor stable until a waypoint is reached.
		pass

func tick(delta: float) -> void:
	clock += delta
	world.sim_clock = clock
	var jobs := 0
	for id in world.residents:
		var actor: Dictionary = world.residents[id]
		if not actor.get("active", false):
			continue
		var needs: Dictionary = actor.get("needs", {})
		needs["rest"] = clampf(float(needs.get("rest", 0.5)) + delta * 0.00065, 0, 1)
		needs["curiosity"] = clampf(float(needs.get("curiosity", 0.4)) + delta * 0.0004, 0, 1)
		needs["social"] = clampf(float(needs.get("social", 0.4)) + delta * 0.00025, 0, 1)
		actor["needs"] = needs
		if actor.get("phase", "idle") == "travel":
			_move(actor, delta)
			continue
		if float(actor.get("until", 0.0)) > clock:
			if actor["intent"] in ["REST", "SLEEP"]:
				needs["rest"] = maxf(0.0, float(needs["rest"]) - delta * 0.004)
			elif actor["intent"] == "PURPOSEFUL_EXPLORE":
				needs["curiosity"] = maxf(0.0, float(needs["curiosity"]) - delta * 0.002)
			continue
		if jobs >= max_jobs_per_tick:
			continue
		if actor.get("partner_id", "") != "":
			var partner_id: String = actor["partner_id"]
			actor.erase("partner_id")
			var partner: Dictionary = world.residents.get(partner_id, {})
			if partner.get("partner_id", "") == id:
				partner.erase("partner_id")
		if actor.get("held_book", "") != "":
			var book_id: String = actor["held_book"]
			media_runtime.read(id, book_id, 25.0)
			media_runtime.return_book(id, book_id)
			actor.erase("held_book")
			_record("%s — вернула книгу" % actor.get("name", id))
		jobs += 1
		_assign(actor, choose_intent(actor))

