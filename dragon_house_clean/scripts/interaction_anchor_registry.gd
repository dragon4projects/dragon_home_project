extends RefCounted
## Source of truth for existing procedural furniture stations.
## Candidate art patches MUST NOT rewrite this file without validation/approval.
const DEFAULT_PATH := "res://data/furniture_interactions_v1.json"
const REVIEW_PATH := "res://data/integration_candidates/furniture_interactions_iter1_review.json"
const ALLOWED_KINDS := ["seat","floor_rest","work","standing"]
const ALLOWED_POSES := ["IDLE_S","RELAXED_SIT","SLEEP","READ","USE","VIEW","TALK","DRINK"]
const TYPES := ["common","rest","cinema","study","library","workshop",
	"music","arrival","corridor","artifact","lift"]
const MAX_ANCHORS := 10

var profiles: Dictionary = {}
var cell_overrides: Dictionary = {}
var variant_cell_overrides: Dictionary = {}
var source_path := ""
var last_error := ""

func initialize(path: String = DEFAULT_PATH) -> bool:
	profiles.clear()
	cell_overrides.clear()
	variant_cell_overrides.clear()
	source_path = ""
	last_error = ""
	var input: FileAccess = FileAccess.open(path,FileAccess.READ)
	if input == null:
		last_error = "No furniture anchor manifest: "+path
		return false
	var json: Variant = JSON.parse_string(input.get_as_text())
	if typeof(json) != TYPE_DICTIONARY:
		last_error = "Furniture anchor manifest is not a JSON object"
		return false
	var doc: Dictionary = json
	if doc.get("schema",-1)!=1 or typeof(doc.get("room_profiles"))!=TYPE_DICTIONARY or (
		typeof(doc.get("cell_overrides"))!=TYPE_DICTIONARY):
		last_error = "Invalid schema/profiles/overrides"
		return false
	var proposed_profiles: Dictionary = doc.get("room_profiles",{})
	var proposed_overrides: Dictionary = doc.get("cell_overrides",{})
	var proposed_variant_overrides: Dictionary = doc.get("variant_cell_overrides",{})
	var min_spacing := 0.60 if path == REVIEW_PATH else 0.65
	for kind in proposed_profiles:
		if not TYPES.has(str(kind)) or not _valid_spots(proposed_profiles[kind],min_spacing):
			last_error = "Invalid room profile: "+str(kind)
			return false
	for key in proposed_overrides:
		var parts: PackedStringArray = str(key).split(":")
		if parts.size()!=2 or not TYPES.has(parts[0]) or not parts[1].is_valid_int() or (
			not _valid_spots(proposed_overrides[key],min_spacing)):
			last_error = "Invalid cell override: "+str(key)
			return false
	for key in proposed_variant_overrides:
		var parts: PackedStringArray = str(key).split(":")
		var width_ok: bool = parts.size()==3 and parts[1] in ["R1","R2","R3"]
		var module_ok: bool = width_ok and parts[2].is_valid_int() and (
			int(parts[2])>=0 and int(parts[2])<int(parts[1].substr(1)))
		if not width_ok or not module_ok or not TYPES.has(parts[0]) or (
			not _valid_spots(proposed_variant_overrides[key],min_spacing)):
			last_error = "Invalid variant cell override: "+str(key)
			return false
	# No partial acceptance: one bad profile prevents ALL new interaction data
	# from being mistaken for a trusted authoring decision.
	profiles = proposed_profiles.duplicate(true)
	cell_overrides = proposed_overrides.duplicate(true)
	variant_cell_overrides = proposed_variant_overrides.duplicate(true)
	source_path = path
	return true

func _valid_spots(items: Variant, min_spacing: float = 0.65) -> bool:
	if typeof(items)!=TYPE_ARRAY or items.size()>MAX_ANCHORS:
		return false
	var ids: Dictionary={}
	var coords: Array=[]
	for raw in items:
		if typeof(raw)!=TYPE_DICTIONARY:
			return false
		var item: Dictionary=raw
		var id: String=str(item.get("id",""))
		var kind: String=str(item.get("kind",""))
		var prop: String=str(item.get("furniture_id",""))
		var pose: String=str(item.get("pose_hint","IDLE_S"))
		if not id.is_valid_identifier() or ids.has(id) or not ALLOWED_KINDS.has(kind) or (
			not ALLOWED_POSES.has(pose)):
			return false
		if kind in ["seat","work","floor_rest"] and (prop=="" or not prop.is_valid_identifier()):
			return false
		for coordinate in ["x","z","approach_z"]:
			if typeof(item.get(coordinate)) not in [TYPE_INT,TYPE_FLOAT]:
				return false
			var value: float=float(item[coordinate])
			if is_nan(value) or is_inf(value):
				return false
		var x:float=float(item["x"])
		var z:float=float(item["z"])
		var approach:float=float(item["approach_z"])
		if absf(x)>1.90 or z < -1.65 or z>1.55 or (
			approach < -1.5 or approach>1.65):
			return false
		for other in coords:
			if Vector2(x,z).distance_to(other)<min_spacing:
				return false
		coords.append(Vector2(x,z))
		ids[id]=true
	return true

func for_room(room: Dictionary) -> Array:
	if room.is_empty() or str(room.get("privacy","public"))!="public":
		return []
	var kind:String=str(room.get("type",""))
	if not TYPES.has(kind) or kind=="lift":
		return []
	var special:String=kind+":"+str(int(room.get("x",0)))
	var data: Array=cell_overrides.get(special,profiles.get(kind,[]))
	return data.duplicate(true)

func for_room_variant(room: Dictionary, width: int, module_index: int) -> Array:
	# Width-specific art contracts win only when that exact merged variant is
	# actually present. This prevents an accepted R2/R3 chair from leaking into
	# an R1 cell merely because it happens to share the same world X coordinate.
	if room.is_empty() or str(room.get("privacy","public"))!="public":
		return []
	var kind:String=str(room.get("type",""))
	if not TYPES.has(kind) or kind=="lift":
		return []
	var safe_width:int=clampi(width,1,3)
	if module_index<0 or module_index>=safe_width:
		return for_room(room)
	var key:String="%s:R%d:%d" % [kind,safe_width,module_index]
	if variant_cell_overrides.has(key):
		return (variant_cell_overrides[key] as Array).duplicate(true)
	return for_room(room)

func check_candidate_patch(path: String) -> Dictionary:
	# Review-only read, NEVER dynamically installs new, unapproved geometry.
	var dry_run= get_script().new()
	var valid: bool=dry_run.initialize(path)
	return {"valid":valid,"error":dry_run.last_error,
		"integrated":false,"approved":false}

