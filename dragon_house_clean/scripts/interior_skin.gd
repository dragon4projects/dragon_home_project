extends RefCounted
## Safe modular cutaway art layers. Geometry and life still work without assets.
## Asset-agent outputs are candidates until each layer has explicit approved=true.
const PATH := "res://data/interior_layers_v1.json"
const REVIEW_MARKER := "res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"
const REVIEW_PATH := "res://data/integration_candidates/ITER1_ROOM_ART_REVIEW.json"
const COMPONENT_PATH := "res://data/room_visual_components_v2.json"
const VALID_ROLES := ["backdrop","back_decor","furniture_back","foreground","front_trim","light_overlay"]
const VALID_VARIANTS := ["R1","R2","R3"]
const VALID_IMAGE_FORMATS := ["png","webp","jpg","jpeg"]
const Z_FOR_ROLE := {
	"backdrop": -2.02,
	"back_decor": -1.68,
	"furniture_back": -0.82,
	"foreground": 1.42,
	"front_trim": 1.56,
	"light_overlay": 1.60
}
var config: Dictionary = {}
var textures: Dictionary = {}
var max_cache := 6
var cache_order: Array = []
var error := ""
var candidate_config: Dictionary = {}
var candidate_review_enabled := false
var component_config: Dictionary = {}
var component_textures: Dictionary = {}

func initialize(path: String = PATH) -> bool:
	config = {}
	textures.clear()
	cache_order.clear()
	error = ""
	candidate_config = {}
	candidate_review_enabled = false
	component_config = {}
	component_textures.clear()
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
	_load_component_config()
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

func _load_component_config() -> void:
	component_config={}
	if not FileAccess.file_exists(COMPONENT_PATH):
		return
	var f:=FileAccess.open(COMPONENT_PATH,FileAccess.READ)
	if f==null:
		return
	var parsed=JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed)!=TYPE_DICTIONARY or int(parsed.get("schema",0))!=1:
		push_warning("Room visual component manifest is malformed")
		return
	component_config=parsed

func _component_variant(room_type: String, width: int) -> Dictionary:
	if component_config.is_empty():
		return {}
	var key:="%s/R%d" % [room_type,width]
	var raw=component_config.get("variants",{}).get(key,{})
	return raw if typeof(raw)==TYPE_DICTIONARY else {}

func _component_texture(source_path: String, component: Dictionary) -> Texture2D:
	var rect_raw=component.get("rect",[])
	if typeof(rect_raw)!=TYPE_ARRAY or rect_raw.size()!=4:
		return null
	var rect:=Rect2i(int(rect_raw[0]),int(rect_raw[1]),
		int(rect_raw[2]),int(rect_raw[3]))
	var key:="%s:%d:%d:%d:%d" % [
		source_path,rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	if component_textures.has(key):
		return component_textures[key]
	var source:Texture2D=texture_for(source_path)
	if source==null:
		return null
	var image:Image=source.get_image()
	if image==null or image.is_empty():
		return null
	var bounds:=Rect2i(Vector2i.ZERO,image.get_size())
	if not bounds.encloses(rect) or rect.size.x<=0 or rect.size.y<=0:
		return null
	var crop:Image=image.get_region(rect)
	if crop==null or crop.is_empty():
		return null
	var tex:=ImageTexture.create_from_image(crop)
	component_textures[key]=tex
	return tex

func _add_component_furniture(parent: Node3D, room_type: String, width: int,
		source_path: String, candidate_review: bool) -> int:
	var variant:Dictionary=_component_variant(room_type,width)
	if variant.is_empty() or str(variant.get("source_path",""))!=source_path:
		return 0
	var entries=variant.get("components",[])
	if typeof(entries)!=TYPE_ARRAY:
		return 0
	var count:=0
	for raw in entries:
		if typeof(raw)!=TYPE_DICTIONARY:
			continue
		var item:Dictionary=raw
		var tex:Texture2D=_component_texture(source_path,item)
		if tex==null:
			continue
		var sprite:=Sprite3D.new()
		sprite.name="Art_furniture_back_"+str(item.get("id","component"))
		sprite.texture=tex
		sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		sprite.pixel_size=float(item.get("pixel_size",
			component_config.get("pixel_size",0.003125)))
		sprite.position=Vector3(float(item.get("x",0.0)),
			float(item.get("y",0.0)),float(item.get("z",-0.8)))
		sprite.no_depth_test=false
		sprite.shaded=false
		sprite.render_priority=0
		sprite.set_meta("physical_component",true)
		sprite.set_meta("source_anchor",str(item.get("source_anchor","")))
		if candidate_review:
			sprite.set_meta("candidate_review",true)
		parent.add_child(sprite)
		count+=1
	return count

func _safe_path(room_type: String, variant: String, path: String,
		candidate_review: bool = false) -> bool:
	if not VALID_VARIANTS.has(variant):
		return false
	if path.contains("..") or path.contains("\\") or path.begins_with("/"):
		return false
	if candidate_review:
		if not path.begins_with("assets/room_candidates/"):
			return false
		var expected_tail := "/%s/%s/" % [room_type,variant]
		return path.contains(expected_tail) and VALID_IMAGE_FORMATS.has(path.get_extension().to_lower())
	if not path.begins_with("assets/rooms/"):
		return false
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
	var count:=0
	var component_variant:Dictionary=_component_variant(room_type,width)
	var suppressed:Array=component_variant.get("suppress_roles",[]) if not component_variant.is_empty() else []
	for item in validated_layers(room_type,width):
		var role:String=item["role"]
		if suppressed.has(role):
			continue
		var source_path:String=str(item["path"])
		if role=="furniture_back" and not component_variant.is_empty():
			var component_count:int=_add_component_furniture(parent,room_type,width,
				source_path,bool(item.get("candidate_review",false)))
			if component_count>0:
				count+=component_count
				continue
		var tex:Texture2D=texture_for(source_path)
		if tex==null:
			continue
		var sprite:=Sprite3D.new()
		sprite.name="Art_"+role
		sprite.texture=tex
		sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		sprite.pixel_size=physical_width/maxf(1.0,float(tex.get_width()))
		var layer_z:float=float(Z_FOR_ROLE[role])
		if item.has("physical_z"):
			layer_z=float(item["physical_z"])
			sprite.set_meta("physical_z",layer_z)
		sprite.position=Vector3(0.0,1.50,layer_z)
		if bool(item.get("candidate_review",false)):
			sprite.set_meta("candidate_review",true)
		sprite.no_depth_test=false
		sprite.shaded=false
		sprite.render_priority=0
		parent.add_child(sprite)
		count+=1
	return count

