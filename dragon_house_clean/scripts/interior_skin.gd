extends RefCounted
## Safe modular cutaway art layers. Geometry and life still work without assets.
## Asset-agent outputs are candidates until each layer has explicit approved=true.
const PATH := "res://data/interior_layers_v1.json"
const REVIEW_MARKER := "res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"
const REVIEW_PATH := "res://data/integration_candidates/ITER1_ROOM_ART_REVIEW.json"
const VALID_ROLES := ["backdrop","back_decor","furniture_back","foreground","front_trim","light_overlay"]
const VALID_VARIANTS := ["R1","R2","R3"]
const VALID_IMAGE_FORMATS := ["png","webp","jpg","jpeg"]
const Z_FOR_ROLE := {
	"backdrop": -1.79,
	"back_decor": -1.63,
	"furniture_back": -1.37,
	"foreground": 1.63,
	"front_trim": 1.91,
	"light_overlay": 1.96
}
var config: Dictionary = {}
var textures: Dictionary = {}
var max_cache := 6
var cache_order: Array = []
var error := ""
var candidate_config: Dictionary = {}
var candidate_review_enabled := false

func initialize(path: String = PATH) -> bool:
	config = {}
	textures.clear()
	cache_order.clear()
	error = ""
	candidate_config = {}
	candidate_review_enabled = false
	if not FileAccess.file_exists(path):
		error = "No accepted room layers found; using structural geometry"
		return false
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null:
		error = "Room layer manifest could not be opened"
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		error = "Invalid room layer JSON"
		return false
	if int(json.data.get("schema",0)) != 1:
		error = "Room layer schema mismatch"
		return false
	var types = json.data.get("room_types",{})
	if typeof(types) != TYPE_DICTIONARY:
		error = "room_types must be a dictionary"
		return false
	config = json.data
	_load_candidate_overlay()
	return true

func _load_candidate_overlay() -> void:
	candidate_config = {}
	candidate_review_enabled = false
	if not FileAccess.file_exists(REVIEW_MARKER) or not FileAccess.file_exists(REVIEW_PATH):
		return
	var f := FileAccess.open(REVIEW_PATH,FileAccess.READ)
	if f == null:
		push_warning("Iteration-1 review art manifest could not be opened")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Iteration-1 review art manifest is malformed")
		return
	var doc: Dictionary = parsed
	if int(doc.get("schema",0)) != 2 or bool(doc.get("approved",true)) or bool(doc.get("owner_approved",true)):
		push_warning("Iteration-1 review art manifest violates candidate approval boundary")
		return
	if typeof(doc.get("room_types",null)) != TYPE_DICTIONARY:
		push_warning("Iteration-1 review art manifest has no room_types")
		return
	candidate_config = doc
	candidate_review_enabled = true

func _safe_path(room_type: String, variant: String, path: String,
		candidate_review: bool = false) -> bool:
	if not VALID_VARIANTS.has(variant) or not path.begins_with("assets/rooms/"):
		return false
	if path.contains("..") or path.contains("\\") or path.begins_with("/"):
		return false
	if candidate_review:
		if not path.begins_with("assets/room_candidates/"):
			return false
		var expected_tail := "/%s/%s/" % [room_type,variant]
		return path.contains(expected_tail) and VALID_IMAGE_FORMATS.has(path.get_extension().to_lower())
	var allowed_prefix := "assets/rooms/%s/%s/" % [room_type,variant]
	return path.begins_with(allowed_prefix) and VALID_IMAGE_FORMATS.has(path.get_extension().to_lower())

func _actual_image_source(path: String) -> bool:
	# A Git LFS pointer has a .png filename but no pixels. Do not hide
	# procedural furniture in favor of missing/undecodable room artwork.
	var source: String="res://"+path
	if FileAccess.file_exists(source):
		var file := FileAccess.open(source,FileAccess.READ)
		if file == null:
			return false
		var head: PackedByteArray=file.get_buffer(12)
		var ext: String=path.get_extension().to_lower()
		if ext=="png":
			return head.size()>=8 and head.slice(0,8)==PackedByteArray(
				[137,80,78,71,13,10,26,10])
		if ext=="webp":
			return head.size()>=12 and head.slice(0,4).get_string_from_ascii()=="RIFF" and (
				head.slice(8,12).get_string_from_ascii()=="WEBP")
		if ext in ["jpg","jpeg"]:
			return head.size()>=3 and head[0]==255 and head[1]==216 and head[2]==255
		return false
	# In exported PCKs a valid imported texture can exist only as a remapped
	# Godot Resource, without the source PNG bytes.
	return ResourceLoader.exists(source)

func validated_layers(room_type: String, width: int) -> Array:
	var result: Array = []
	if config.is_empty() or room_type == "private" or width < 1 or width > 3:
		return result
	var variant := "R%d" % width
	var entry: Dictionary = config.get("room_types",{}).get(room_type,{}).get(variant,{})
	var candidate_review := false
	if candidate_review_enabled:
		var raw_candidate = candidate_config.get("room_types",{}).get(room_type,{}).get(variant,{})
		if typeof(raw_candidate) == TYPE_DICTIONARY:
			var candidate_entry: Dictionary = raw_candidate
			if not candidate_entry.is_empty():
				entry = candidate_entry
				candidate_review = true
	var layers = entry.get("layers",[])
	if typeof(layers) != TYPE_ARRAY:
		return result
	for item in layers:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if candidate_review:
			if bool(item.get("approved",true)) or bool(item.get("owner_approved",true)):
				continue
		elif not bool(item.get("approved",false)):
			continue
		var role := str(item.get("role",""))
		if not VALID_ROLES.has(role) or result.any(func(existing):return existing["role"] == role):
			continue
		var path := str(item.get("path","")).trim_prefix("res://")
		if not _safe_path(room_type,variant,path,candidate_review):
			continue
		if not _actual_image_source(path):
			continue
		var accepted:Dictionary={"role":role,"path":path}
		if candidate_review:
			accepted["candidate_review"] = true
		if item.has("physical_z"):
			var physical_z:float=float(item["physical_z"])
			if is_nan(physical_z) or is_inf(physical_z) or physical_z < -1.65 or physical_z > 0.90:
				continue
			accepted["physical_z"]=physical_z
		result.append(accepted)
	return result

func texture_for(path: String) -> Texture2D:
	if textures.has(path):
		return textures[path]
	var loc: String = "res://"+path
	var tex: Texture2D = null
	if ResourceLoader.exists(loc):
		var existing = load(loc)
		if existing is Texture2D:
			tex = existing
	if tex == null and FileAccess.file_exists(loc):
		var image := Image.new()
		if image.load(loc) == OK:
			tex = ImageTexture.create_from_image(image)
	if tex != null:
		textures[path] = tex
		cache_order.append(path)
		while cache_order.size() > max_cache:
			textures.erase(cache_order.pop_front())
	return tex

func add_layers(parent: Node3D, room_type: String, width: int, physical_width: float) -> int:
	var count := 0
	for item in validated_layers(room_type,width):
		var role: String = item["role"]
		var tex: Texture2D = texture_for(item["path"])
		if tex == null:
			continue
		var sprite := Sprite3D.new()
		sprite.name = "Art_" + role
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.pixel_size = physical_width / maxf(1.0,float(tex.get_width()))
		sprite.position = Vector3(0.0,1.50,Z_FOR_ROLE[role])
		if item.has("physical_z"):
			sprite.set_meta("physical_z",float(item["physical_z"]))
		if bool(item.get("candidate_review",false)):
			sprite.set_meta("candidate_review",true)
		sprite.no_depth_test = false
		sprite.shaded = false
		sprite.render_priority = 0
		parent.add_child(sprite)
		count += 1
	return count

