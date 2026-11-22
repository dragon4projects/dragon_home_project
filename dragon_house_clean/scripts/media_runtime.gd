extends RefCounted
## Physical-media lifecycle, independent from camera and autonomous planner.
## Catalogue entries are explicit. No invented titles, playback or ownership.
var world

func setup(model) -> void:
	world = model
	_normalize_catalogue()

func _normalize_catalogue() -> void:
	for book in world.media.get("books", []):
		if not book.has("holder_id"):
			book["holder_id"] = ""
		if not book.has("location_room_id"):
			var rooms: Array = world.matching_rooms(["library"])
			book["location_room_id"] = rooms[0]["id"] if not rooms.is_empty() else ""
		if not book.has("idle_since"):
			book["idle_since"] = 0
		if not book.has("progress_by_actor"):
			book["progress_by_actor"] = {}
		if not book.has("owner_id"):
			book["owner_id"] = ""

func _lookup(kind: String, id: String) -> Dictionary:
	for entry in world.media.get(kind, []):
		if entry.get("id", "") == id:
			return entry
	return {}

func available_books() -> Array:
	var out: Array = []
	for book in world.media.get("books", []):
		if book.get("holder_id", "") == "" and book.get("location_room_id", "") != "":
			out.append(book)
	return out

func borrow(actor_id: String, book_id: String, now: int = 0) -> bool:
	var actor: Dictionary = world.residents.get(actor_id, {})
	var book: Dictionary = _lookup("books", book_id)
	if not actor.get("active", false) or book.is_empty():
		return false
	if book.get("holder_id", "") != "" or book.get("location_room_id", "") == "":
		return false
	book["holder_id"] = actor_id
	book["location_room_id"] = ""
	book["idle_since"] = 0
	book["borrowed_at"] = now
	return true

func read(actor_id: String, book_id: String, seconds: float) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	var progress: Dictionary = book.get("progress_by_actor", {})
	progress[actor_id] = maxf(0.0, float(progress.get(actor_id, 0.0)) + seconds)
	book["progress_by_actor"] = progress
	return true

func drop_book(actor_id: String, book_id: String, now: int) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	book["holder_id"] = ""
	book["idle_since"] = now
	# No shelf location while abandoned. This is not a second copy.
	return true

func return_book(actor_id: String, book_id: String, destination_id: String = "") -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	var room: Dictionary = world.room_by_id(destination_id)
	if room.is_empty() or not ["library", "rest", "study"].has(room.get("type", "")):
		var rooms: Array = world.matching_rooms(["library", "rest", "study"])
		if rooms.is_empty():
			return false
		room = rooms[0]
	book["holder_id"] = ""
	book["location_room_id"] = room["id"]
	book["idle_since"] = 0
	return true

func cleanup_abandoned(now: int) -> int:
	var count := 0
	for book in world.media.get("books", []):
		if book.get("holder_id", "") != "" or book.get("location_room_id", "") != "":
			continue
		var abandoned_at: int = int(book.get("idle_since", 0))
		if abandoned_at <= 0 or now - abandoned_at < 86400:
			continue
		var rooms: Array = world.matching_rooms(["library", "rest", "study"])
		if rooms.is_empty():
			continue
		book["location_room_id"] = rooms[0]["id"]
		book["idle_since"] = 0
		count += 1
	return count

func playable(kind: String) -> Array:
	var out: Array = []
	for item in world.media.get(kind, []):
		var file_path: String = str(item.get("file_path", ""))
		if file_path != "" and (FileAccess.file_exists(file_path) or ResourceLoader.exists(file_path)):
			out.append(item)
	return out

func can_watch(actor_id: String, item_id: String, room_id: String) -> bool:
	return world.residents.get(actor_id, {}).get("active", false) and world.room_by_id(room_id).get("type", "") == "cinema" and not _lookup("films", item_id).is_empty() and playable("films").any(func(item): return item["id"] == item_id)

func can_listen(actor_id: String, item_id: String, room_id: String) -> bool:
	return world.residents.get(actor_id, {}).get("active", false) and world.room_by_id(room_id).get("type", "") == "music" and not _lookup("tracks", item_id).is_empty() and playable("tracks").any(func(item): return item["id"] == item_id)

