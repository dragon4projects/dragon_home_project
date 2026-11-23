extends RefCounted
## Review-only adapter for richer artist-authored station metadata.
## It NEVER installs candidate geometry and NEVER elevates approval state.
const ROOM_TYPES := ["arrival","corridor","common","study","rest","library",
	"cinema","music","workshop","artifact"]
const VARIANTS := ["R1","R2","R3"]
const KIND_MAP := {
	"seat":"seat",
	"floor_rest":"floor_rest",
	"work":"work",
	"standing":"standing",
	"view":"standing"
}
const POSE_MAP := {
	"IDLE_S":"IDLE_S",
	"RELAXED_SIT":"RELAXED_SIT",
	"SLEEP":"SLEEP",
	"READ":"READ",
	"USE":"USE",
	"VIEW":"VIEW",
	"TALK":"TALK",
	"DRINK":"DRINK",
	"LISTEN":"RELAXED_SIT",
	"WATCH":"RELAXED_SIT",
	"INSPECT":"VIEW"
}
const MAX_STATIONS_PER_VARIANT := 10

func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and not is_nan(float(value)) and not is_inf(float(value))

func _valid_footprint(value: Variant) -> bool:
	if typeof(value)!=TYPE_ARRAY or value.size()<3 or value.size()>16:
		return false
	for point in value:
		if typeof(point)!=TYPE_ARRAY or point.size()!=2:
			return false
		if not _finite_number(point[0]) or not _finite_number(point[1]):
			return false
		if absf(float(point[0]))>2.40 or float(point[1]) < -2.10 or float(point[1]) > 0.95:
			return false
	return true

func inspect(path: String) -> Dictionary:
	var report := {
		"valid":false,
		"approved":false,
		"integrated":false,
		"errors":[],
		"warnings":[],
		"normalized_room_variants":{},
		"semantic_mappings":[],
		"station_count":0,
		"non_station_furniture_count":0
	}
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:
		report["errors"].append("Candidate not found: "+path)
		return report
	var parsed=JSON.parse_string(f.get_as_text())
	if typeof(parsed)!=TYPE_DICTIONARY:
		report["errors"].append("Candidate is not a JSON object")
		return report
	var doc:Dictionary=parsed
	if int(doc.get("schema",0))!=2:
		report["errors"].append("Expected schema=2")
		return report
	if bool(doc.get("approved",false)):
		report["errors"].append("Artist candidate must remain approved=false")
		return report
	if typeof(doc.get("room_variants",null))!=TYPE_DICTIONARY:
		report["errors"].append("room_variants must be a dictionary")
		return report

	var all_ids:Dictionary={}
	for variant_key in doc["room_variants"]:
		var key:String=str(variant_key)
		var parts:PackedStringArray=key.split("/")
		if parts.size()!=2 or not ROOM_TYPES.has(parts[0]) or not VARIANTS.has(parts[1]):
			report["errors"].append("Invalid room variant key: "+key)
			continue
		var entry=doc["room_variants"][variant_key]
		if typeof(entry)!=TYPE_DICTIONARY:
			report["errors"].append("Variant entry is not an object: "+key)
			continue
		var stations=entry.get("stations",[])
		var obstacles=entry.get("non_station_furniture",[])
		if typeof(stations)!=TYPE_ARRAY or stations.size()>MAX_STATIONS_PER_VARIANT:
			report["errors"].append("Invalid station array: "+key)
			continue
		if typeof(obstacles)!=TYPE_ARRAY:
			report["errors"].append("Invalid non_station_furniture array: "+key)
			continue

		var normalized:Array=[]
		var local_positions:Array=[]
		for raw in stations:
			if typeof(raw)!=TYPE_DICTIONARY:
				report["errors"].append("Station is not an object: "+key)
				continue
			var item:Dictionary=raw
			var id:String=str(item.get("id",""))
			var artist_kind:String=str(item.get("kind",""))
			var artist_pose:String=str(item.get("pose_hint",""))
			var furniture_id:String=str(item.get("furniture_id",""))
			if not id.is_valid_identifier() or all_ids.has(id):
				report["errors"].append("Invalid/duplicate station id: "+id)
				continue
			if not KIND_MAP.has(artist_kind):
				report["errors"].append("Unsupported artist kind for "+id+": "+artist_kind)
				continue
			if not POSE_MAP.has(artist_pose):
				report["errors"].append("Unsupported artist pose for "+id+": "+artist_pose)
				continue
			for field in ["cell_local_x","cell_local_z","approach_local_z"]:
				if not _finite_number(item.get(field,null)):
					report["errors"].append("Invalid "+field+" for "+id)
			if not report["errors"].is_empty() and report["errors"][-1].contains(id):
				continue
			var x:float=float(item["cell_local_x"])
			var z:float=float(item["cell_local_z"])
			var approach:float=float(item["approach_local_z"])
			if absf(x)>1.90 or z < -1.65 or z>1.55 or approach < -1.50 or approach>1.65:
				report["errors"].append("Station coordinate out of runtime bounds: "+id)
				continue
			if int(item.get("occupancy_capacity",1))!=1:
				report["errors"].append("Only occupancy_capacity=1 is supported: "+id)
				continue
			if artist_kind in ["seat","work","floor_rest","view"] and (
				furniture_id=="" or not furniture_id.is_valid_identifier()):
				report["errors"].append("Invalid furniture_id for "+id)
				continue
			if item.has("collision_footprint") and not _valid_footprint(item["collision_footprint"]):
				report["errors"].append("Invalid collision footprint for "+id)
				continue
			var point:=Vector2(x,z)
			var too_close:=false
			for prior in local_positions:
				if point.distance_to(prior)<0.65:
					too_close=true
					break
			if too_close:
				report["errors"].append("Station spacing below 0.65 m: "+id)
				continue
			local_positions.append(point)
			all_ids[id]=true
			var runtime_kind:String=KIND_MAP[artist_kind]
			var runtime_pose:String=POSE_MAP[artist_pose]
			if runtime_kind!=artist_kind or runtime_pose!=artist_pose:
				report["semantic_mappings"].append({
					"id":id,
					"artist_kind":artist_kind,
					"runtime_kind":runtime_kind,
					"artist_pose":artist_pose,
					"runtime_pose":runtime_pose
				})
			normalized.append({
				"id":id,
				"x":x,
				"z":z,
				"kind":runtime_kind,
				"furniture_id":furniture_id,
				"pose_hint":runtime_pose,
				"approach_z":approach,
				"source_batch":str(doc.get("batch_id","")),
				"approved":false
			})
			report["station_count"]=int(report["station_count"])+1

		for raw_obstacle in obstacles:
			if typeof(raw_obstacle)!=TYPE_DICTIONARY:
				report["errors"].append("Collision-only furniture is not an object: "+key)
				continue
			var obstacle:Dictionary=raw_obstacle
			var oid:String=str(obstacle.get("furniture_id",""))
			if oid=="" or not oid.is_valid_identifier():
				report["errors"].append("Invalid collision-only furniture id: "+oid)
				continue
			if not _finite_number(obstacle.get("group_local_x",null)) or (
				not _finite_number(obstacle.get("authored_center_z",null))):
				report["errors"].append("Invalid collision-only coordinates: "+oid)
				continue
			if not _valid_footprint(obstacle.get("collision_footprint",null)):
				report["errors"].append("Invalid collision-only footprint: "+oid)
				continue
			report["non_station_furniture_count"]=int(report["non_station_furniture_count"])+1

		report["normalized_room_variants"][key]=normalized

	report["valid"]=report["errors"].is_empty()
	if report["valid"]:
		report["warnings"].append("Review PASS only: normalized metadata is NOT installed")
		if not report["semantic_mappings"].is_empty():
			report["warnings"].append("Artist semantics require explicit runtime mapping; source geometry is unchanged")
	return report
