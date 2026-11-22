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

func _real_image_bytes(relative: String) -> bool:
	# A Git LFS pointer is a file too. Require actual PNG/WebP magic before QA.
	var path: String = "res://" + relative
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null:
			return false
		var head: PackedByteArray = file.get_buffer(12)
		var ext: String = relative.get_extension().to_lower()
		if ext == "png":
			return head.size() >= 8 and head.slice(0,8) == PackedByteArray([
				137,80,78,71,13,10,26,10])
		if ext == "webp":
			return head.size() >= 12 and head.slice(0,4).get_string_from_ascii() == "RIFF" and head.slice(8,12).get_string_from_ascii() == "WEBP"
		return false
	if ResourceLoader.exists(path):
		# .ctex remap may be the only path in an exported PCK.
		return load(path) is Texture2D
	return false

func candidate_bank(resident_id: String, appearance_profile: String, wardrobe: String = "HOME") -> bool:
	# Technical QA preview: path/state validation only. NOT artistic approval.
	if manifest.is_empty() or not VALID_WARDROBES.has(wardrobe):
		return false
	var actor: Dictionary = manifest.get("residents",{}).get(resident_id,{})
	if actor.is_empty() or str(actor.get("appearance_profile","")) != appearance_profile:
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
			if not _real_image_bytes(relative):
				return false
	return true

func verified_bank(resident_id: String, appearance_profile: String, wardrobe: String = "HOME") -> bool:
	var actor: Dictionary = manifest.get("residents",{}).get(resident_id,{})
	return bool(actor.get("visual_bank_ready",false)) and candidate_bank(resident_id,appearance_profile,wardrobe)

func wardrobe_options(resident_id: String) -> Array:
	var actor: Dictionary = manifest.get("residents",{}).get(resident_id,{})
	var order: Array = []
	var preferred: String = str(actor.get("default_wardrobe",""))
	# The November migration registry, not the render code, owns the outfit choice.
	if VALID_WARDROBES.has(preferred):
		order.append(preferred)
	for item in ["HOME","CITY","SHORT"]:
		if not order.has(item):
			order.append(item)
	return order

func preferred_wardrobe(resident_id: String, appearance_profile: String, allow_candidate: bool = false) -> String:
	for wardrobe in wardrobe_options(resident_id):
		if verified_bank(resident_id, appearance_profile,wardrobe):
			return wardrobe
	if allow_candidate:
		for wardrobe in wardrobe_options(resident_id):
			if candidate_bank(resident_id,appearance_profile,wardrobe):
				return wardrobe
	return ""

func technical_states(resident_id: String, wardrobe: String) -> Array:
	var actor: Dictionary = manifest.get("residents",{}).get(resident_id,{})
	if str(actor.get("appearance_profile","")) == "":
		return []
	var states: Dictionary = actor.get("wardrobes",{}).get(wardrobe,{}).get("states",{})
	var keys: Array = []
	for key in states.keys():
		if str(states[key].get("status","")) != "PASS":
			continue
		var frames: Array = states[key].get("frames",[])
		if frames.is_empty() or frames.size() > MAX_FRAMES_PER_STATE:
			continue
		keys.append(key)
	keys.sort()
	return keys

func feet_anchor(resident_id: String, wardrobe: String, height: int) -> float:
	var w: Dictionary = manifest.get("residents",{}).get(resident_id,{}).get("wardrobes",{}).get(wardrobe,{})
	var anchor: Array = w.get("feet_anchor",[])
	if anchor.size() >= 2:
		var y: float = float(anchor[1])
		if y >= 0 and y <= height:
			return y
	return float(height)-minf(12.0,float(height)*0.07)

func manka_frame_count(state: String) -> int:
	var entry: Dictionary = manifest.get("creatures",{}).get("manjka",{}).get("states",{}).get(state,{})
	if str(entry.get("status","")) != "PASS":
		return 0
	return entry.get("frames",[]).size()

func manka_fps(state: String) -> float:
	var entry: Dictionary = manifest.get("creatures",{}).get("manjka",{}).get("states",{}).get(state,{})
	return clampf(float(entry.get("fps",2)),1.0,30.0)

func manka_texture(state: String, index: int) -> Texture2D:
	var entry: Dictionary = manifest.get("creatures",{}).get("manjka",{}).get("states",{}).get(state,{})
	if str(entry.get("status","")) != "PASS":
		return null
	var frames: Array = entry.get("frames",[])
	if frames.is_empty() or frames.size() > 24:
		return null
	var path: String = _normalize_frame(frames[posmod(index,frames.size())])
	if not path.begins_with("assets/creatures/manjka/") or path.contains("..") or path.contains("\\"):
		return null
	if not ["png","webp"].has(path.get_extension().to_lower()) or not _real_image_bytes(path):
		return null
	return _load_checked_texture(path)

func prop_master_path(prop_id: String) -> String:
	var items: Array = manifest.get("props",{}).get("display_previews",[])
	for item in items:
		if str(item.get("id","")) != prop_id:
			continue
		var path: String = str(item.get("master_path","")).trim_prefix("res://")
		if not path.begins_with("assets/props/") or path.contains("..") or path.contains("\\"):
			return ""
		if path.get_extension().to_lower() != "png":
			return ""
		if _real_image_bytes(path):
			return path
	return ""

func prop_display_texture(prop_id: String) -> Texture2D:
	# Low-memory runtime preview from the approved historical master pair.
	var items: Array = manifest.get("props",{}).get("display_previews",[])
	for item in items:
		if str(item.get("id","")) != prop_id:
			continue
		var path: String = str(item.get("path","")).trim_prefix("res://")
		if path.contains("..") or path.contains("\\") or not path.begins_with("assets/props/"):
			return null
		if not ["png","webp"].has(path.get_extension().to_lower()):
			return null
		return _load_checked_texture(path)
	return null

func _load_checked_texture(path: String) -> Texture2D:
	var url: String = "res://"+path
	if not (FileAccess.file_exists(url) or ResourceLoader.exists(url)):
		return null
	if cache.has(url):
		return cache[url]
	var res: Texture2D = null
	if ResourceLoader.exists(url):
		var loaded = load(url)
		if loaded is Texture2D:
			res=loaded
	if res == null:
		var image := Image.new()
		if image.load(url) == OK:
			res=ImageTexture.create_from_image(image)
	if res != null:
		cache[url]=res
		cache_order.append(url)
		while cache_order.size() > cache_capacity:
			cache.erase(cache_order.pop_front())
	return res

func available_wardrobes(resident_id: String, appearance_profile: String) -> Array:
	var result: Array = []
	for wardrobe in ["HOME", "CITY", "SHORT"]:
		if verified_bank(resident_id, appearance_profile, wardrobe):
			result.append(wardrobe)
	return result

func preview_count(profiles: Array) -> int:
	var count := 0
	for profile in profiles:
		if preferred_wardrobe(str(profile.get("id","")),str(profile.get("appearance_profile","")),true) != "":
			count += 1
	return count

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
	return _load_checked_texture(chosen)

func accepted_count(profiles: Array) -> int:
	var count := 0
	for profile in profiles:
		if preferred_wardrobe(str(profile.get("id","")),str(profile.get("appearance_profile",""))) != "":
			count += 1
	return count
