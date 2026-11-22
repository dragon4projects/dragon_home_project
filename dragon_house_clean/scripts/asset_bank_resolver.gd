extends RefCounted
## Strict, read-only adapter for the November migration agent's manifest.
## Never edits imported art or elevates a QA/archived bank to approved status.
const REGISTRY_PATH := "res://data/asset_registry_nov2026.json"
const REQUIRED_PREVIEW_STATES := ["IDLE_S", "WALK_LEFT", "WALK_RIGHT"]
const VALID_WARDROBES := ["HOME", "SHORT", "CITY"]
const ALLOWED_EXTENSIONS := ["png", "webp"]
const MAX_FRAMES_PER_STATE := 24
var manifest: Dictionary = {}
var source_path: String = REGISTRY_PATH
var cache: Dictionary = {}
var cache_order: Array = []
var cache_capacity := 36
var last_error := ""

func initialize(path: String = REGISTRY_PATH) -> bool:
	source_path = path
	manifest = {}
	cache.clear()
	cache_order.clear()
	last_error = ""
	if not FileAccess.file_exists(source_path):
		last_error = "Asset registry not delivered by migration agent"
		return false
	var file := FileAccess.open(source_path,FileAccess.READ)
	if file == null:
		last_error = "Asset registry unreadable"
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		last_error = "Asset registry malformed JSON"
		return false
	var parsed: Dictionary = parser.data
	if int(parsed.get("schema",0)) != 1 or typeof(parsed.get("residents",null)) != TYPE_DICTIONARY:
		last_error = "Asset registry must provide schema=1 and residents map"
		return false
	manifest = parsed
	return true

func _root(resident_id: String, wardrobe: String) -> String:
	return "assets/residents/%s/wardrobes/%s/" % [resident_id,wardrobe]

func _safe_frame_path(resident_id: String, wardrobe: String, path: String) -> bool:
	if not VALID_WARDROBES.has(wardrobe):
		return false
	if path.begins_with("res://"):
		path = path.trim_prefix("res://")
	if path.contains("..") or path.contains("\\") or path.begins_with("/"):
		return false
	if not path.begins_with(_root(resident_id,wardrobe)):
		return false
	return ALLOWED_EXTENSIONS.has(path.get_extension().to_lower())

func _normalize_frame(frame) -> String:
	if typeof(frame) == TYPE_STRING:
		return str(frame).trim_prefix("res://")
	if typeof(frame) == TYPE_DICTIONARY:
		return str(frame.get("path",frame.get("file",""))).trim_prefix("res://")
	return ""

func _entry(resident_id: String, wardrobe: String, state: String) -> Dictionary:
	if manifest.is_empty():
		return {}
	var actors: Dictionary = manifest.get("residents",{})
	var actor: Dictionary = actors.get(resident_id,{})
	if actor.is_empty():
		return {}
	var wardrobes: Dictionary = actor.get("wardrobes",{})
	var bank: Dictionary = wardrobes.get(wardrobe,{})
	var states: Dictionary = bank.get("states",{})
	return states.get(state,{})

func verified_bank(resident_id: String, appearance_profile: String, wardrobe: String = "HOME") -> bool:
	if manifest.is_empty() or not VALID_WARDROBES.has(wardrobe):
		return false
	var actor: Dictionary = manifest.get("residents",{}).get(resident_id,{})
	if actor.is_empty():
		return false
	if str(actor.get("appearance_profile","")) != appearance_profile:
		return false
	if not bool(actor.get("visual_bank_ready",false)):
		return false
	for state in REQUIRED_PREVIEW_STATES:
		var entry: Dictionary = _entry(resident_id,wardrobe,state)
		if entry.is_empty() or str(entry.get("status","")) != "PASS":
			return false
		var frames = entry.get("frames",[])
		if typeof(frames) != TYPE_ARRAY or frames.is_empty() or frames.size() > MAX_FRAMES_PER_STATE:
			return false
		if state.begins_with("WALK") and (int(entry.get("fps",0)) < 1 or int(entry.get("fps",0)) > 30):
			return false
		for frame in frames:
			var relative: String = _normalize_frame(frame)
			if not _safe_frame_path(resident_id,wardrobe,relative):
				return false
			if not (FileAccess.file_exists("res://"+relative) or ResourceLoader.exists("res://"+relative)):
				return false
	return true

func frame_count(resident_id: String, wardrobe: String, state: String) -> int:
	var entry: Dictionary = _entry(resident_id,wardrobe,state)
	if str(entry.get("status","")) != "PASS":
		return 0
	return entry.get("frames",[]).size()

func fps(resident_id: String, wardrobe: String, state: String) -> int:
	return clampi(int(_entry(resident_id,wardrobe,state).get("fps",18)),1,30)

func texture_for(resident_id: String, wardrobe: String, state: String, frame_index: int) -> Texture2D:
	var entry: Dictionary = _entry(resident_id,wardrobe,state)
	if str(entry.get("status","")) != "PASS":
		return null
	var frames: Array = entry.get("frames",[])
	if frames.is_empty() or frames.size() > MAX_FRAMES_PER_STATE:
		return null
	var chosen: String = _normalize_frame(frames[posmod(frame_index,frames.size())])
	if not _safe_frame_path(resident_id,wardrobe,chosen):
		return null
	var url: String = "res://"+chosen
	if not (FileAccess.file_exists(url) or ResourceLoader.exists(url)):
		return null
	if cache.has(url):
		return cache[url]
	var resource: Texture2D = null
	if ResourceLoader.exists(url):
		var loaded = load(url)
		if loaded is Texture2D:
			resource = loaded
	if resource == null:
		# Useful for freshly generated/imported files before a Godot editor scan.
		var image := Image.new()
		if image.load(url) == OK:
			resource = ImageTexture.create_from_image(image)
	if resource == null:
		return null
	cache[url] = resource
	cache_order.append(url)
	while cache_order.size() > cache_capacity:
		var eldest: String = cache_order.pop_front()
		cache.erase(eldest)
	return resource

func accepted_count(profiles: Array) -> int:
	var count := 0
	for profile in profiles:
		if verified_bank(str(profile.get("id","")),str(profile.get("appearance_profile",""))):
			count += 1
	return count
