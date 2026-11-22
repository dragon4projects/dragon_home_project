extends RefCounted
## One authoritative local simulation state. No chat/LLM interfaces.
const SAVE_PATH := "user://dragon_house_world_v01.json"
const MODULE_W := 4.8
const FLOOR_H := 4.6
const ROOM_TYPES := ["arrival", "corridor", "common", "study", "rest", "library", "cinema", "music", "workshop", "private", "lift", "artifact"]
const SHARED_TYPES := ["arrival", "corridor", "common", "study", "rest", "library", "cinema", "music", "workshop", "lift", "artifact"]

var rooms: Array = []
var residents: Dictionary = {}
var media: Dictionary = {"books": [], "films": [], "tracks": []}
var next_room_id := 1

func cell_key(x: int, level: int) -> String:
	return "%d:%d" % [x, level]

func get_room(x: int, level: int) -> Dictionary:
	for room in rooms:
		if int(room["x"]) == x and int(room["level"]) == level:
			return room
	return {}

func room_by_id(room_id: String) -> Dictionary:
	for room in rooms:
		if str(room["id"]) == room_id:
			return room
	return {}

func world_pos(x: int, level: int) -> Vector3:
	return Vector3(float(x) * MODULE_W, float(level) * FLOOR_H, 0.0)

func make_room(x: int, level: int, room_type: String) -> Dictionary:
	var room := {
		"id": "ROOM_%04d" % next_room_id,
		"x": x,
		"level": level,
		"type": room_type,
		"privacy": "door_only" if room_type == "private" else "public",
		"owner_id": "",
	}
	next_room_id += 1
	rooms.append(room)
	return room

func can_build(x: int, level: int, room_type: String) -> bool:
	if not ROOM_TYPES.has(room_type) or not get_room(x, level).is_empty():
		return false
	if abs(x) > 28 or abs(level) > 5:
		return false
	if rooms.is_empty():
		return true
	if not get_room(x - 1, level).is_empty() or not get_room(x + 1, level).is_empty():
		return true
	# Vertical shafts must be continuous lift-to-lift.
	if room_type == "lift":
		return get_room(x, level - 1).get("type", "") == "lift" or get_room(x, level + 1).get("type", "") == "lift"
	return false

func build(x: int, level: int, room_type: String) -> bool:
	if not can_build(x, level, room_type):
		return false
	make_room(x, level, room_type)
	save_world()
	return true

func is_accessible(room: Dictionary, actor_id: String = "") -> bool:
	if room.is_empty():
		return false
	if room.get("privacy", "public") != "public":
		# The private interior is not rendered or routed by the public simulation.
		return actor_id != "" and room.get("owner_id", "") == actor_id
	return true

func neighbors(room: Dictionary, actor_id: String = "") -> Array:
	var out: Array = []
	var x: int = int(room["x"])
	var level: int = int(room["level"])
	for dx in [-1, 1]:
		var candidate: Dictionary = get_room(x + dx, level)
		if is_accessible(candidate, actor_id):
			out.append(candidate)
	if room["type"] == "lift":
		for dy in [-1, 1]:
			var candidate: Dictionary = get_room(x, level + dy)
			if candidate.get("type", "") == "lift":
				out.append(candidate)
	return out

func find_route(start_id: String, destination_id: String, actor_id: String = "") -> Array:
	var start: Dictionary = room_by_id(start_id)
	var target: Dictionary = room_by_id(destination_id)
	if start.is_empty() or target.is_empty() or not is_accessible(target, actor_id):
		return []
	if start_id == destination_id:
		return [start_id]
	var seen: Dictionary = {start_id: true}
	var previous: Dictionary = {}
	var queue: Array = [start]
	var q_index := 0
	while q_index < queue.size():
		var current: Dictionary = queue[q_index]
		q_index += 1
		for next_room in neighbors(current, actor_id):
			var key: String = next_room["id"]
			if seen.has(key):
				continue
			seen[key] = true
			previous[key] = current["id"]
			if key == destination_id:
				var path: Array = [destination_id]
				var cursor: String = destination_id
				while cursor != start_id:
					cursor = previous[cursor]
					path.push_front(cursor)
				return path
			queue.append(next_room)
	return []

func matching_rooms(types: Array, actor_id: String = "") -> Array:
	var out: Array = []
	for room in rooms:
		if types.has(room["type"]) and is_accessible(room, actor_id):
			out.append(room)
	return out

func merged_run_length(x: int, level: int) -> int:
	var original: Dictionary = get_room(x, level)
	if original.is_empty():
		return 0
	var t: String = original["type"]
	var length := 1
	var at := x - 1
	while get_room(at, level).get("type", "none") == t:
		length += 1
		at -= 1
	at = x + 1
	while get_room(at, level).get("type", "none") == t:
		length += 1
		at += 1
	return length

func seed_world() -> void:
	rooms.clear()
	residents.clear()
	next_room_id = 1
	# CORE, a working lift shaft, two residential terraces, genuine cutaway depth.
	for record in [
		[-5, 0, "arrival"], [-4, 0, "corridor"], [-3, 0, "study"],
		[-2, 0, "common"], [-1, 0, "common"], [0, 0, "common"],
		[1, 0, "rest"], [2, 0, "library"], [3, 0, "music"],
		[4, 0, "cinema"], [5, 0, "lift"],
		[5, 1, "lift"], [4, 1, "corridor"], [3, 1, "private"],
		[2, 1, "private"], [1, 1, "rest"],
		[5, -1, "lift"], [4, -1, "corridor"], [3, -1, "private"],
		[2, -1, "private"], [1, -1, "artifact"]
	]:
		make_room(record[0], record[1], record[2])
	# Known display names are provenance-backed. Others are not invented.
	var names: Array = ["Мора", "Ника", "Шелест", "Иконочка", "Огонёк", "Тенька Дракона", "ЭВМочка", "Архитектор Сестринства"]
	for i in range(names.size()):
		var r: Dictionary = get_room(-3 + i, 0)
		if r.is_empty() or not is_accessible(r):
			r = get_room(1, 0)
		var id := "RES_%02d" % (i + 1)
		residents[id] = {
			"id": id, "name": names[i], "active": true,
			"room_id": r["id"], "x": float(r["x"]) * MODULE_W,
			"level": int(r["level"]), "z": 0.15,
			"intent": "REST", "phase": "idle", "until": 0.0,
			"needs": {"rest": 0.5, "social": 0.4, "curiosity": 0.5},
			"traits": {"reading": 0.45 + float(i % 3) * 0.15,
				"music": 0.2 + float(i % 4) * 0.12},
			"habits": {}, "last_location": "", "route": [], "path_index": 0
		}
	# Slots 9..24 are reserved without fabricated identities or appearance.
	for i in range(9, 25):
		var id := "RES_%02d" % i
		residents[id] = {"id": id, "name": "", "active": false, "room_id": "",
			"visual_status": "ASSET_AND_IDENTITY_GATED"}
	# Manka is not a generic human resident.
	residents["MANJKA"] = {"id": "MANJKA", "name": "Манька", "active": true,
		"room_id": get_room(0, 0)["id"], "x": 0.0, "level": 0, "z": 0.7,
		"intent": "EXPLORE", "phase": "idle", "until": 0.0,
		"needs": {"rest": 0.4, "social": 0.15, "curiosity": 0.9},
		"traits": {"reading": 0.0, "music": 0.0}, "habits": {}, "last_location": "",
		"route": [], "path_index": 0}
	media = {"books": [], "films": [], "tracks": []}

func load_or_seed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		seed_world()
		save_world()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		seed_world()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("rooms") or not parsed.has("residents"):
		seed_world()
		return
	rooms.assign(parsed["rooms"])
	residents = parsed["residents"]
	media = parsed.get("media", {"books": [], "films": [], "tracks": []})
	next_room_id = int(parsed.get("next_room_id", rooms.size() + 1))

func save_world() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"schema": 1, "rooms": rooms, "residents": residents,
		"media": media, "next_room_id": next_room_id}, "\t"))
	f.close()
	return true

func import_catalog(path: String) -> bool:
	# Import is explicit; no scraping or invented book/film/song content.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for category in ["books", "films", "tracks"]:
		var items = parsed.get(category, [])
		if typeof(items) != TYPE_ARRAY:
			return false
		for item in items:
			if typeof(item) != TYPE_DICTIONARY or not item.has("id") or not item.has("title"):
				return false
	media = {"books": parsed.get("books", []), "films": parsed.get("films", []),
		"tracks": parsed.get("tracks", [])}
	return save_world()

