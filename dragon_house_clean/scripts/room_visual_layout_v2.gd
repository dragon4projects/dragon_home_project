extends RefCounted
## Read-only visual-layout contract for one physical R1/R2/R3 room.
## Source positions are pinned from TEEA authoring layouts; this script never
## changes room topology, interaction ownership, or simulation state.
const PATH := "res://data/room_visual_layout_v2.json"
var config: Dictionary = {}
var error := ""

func initialize(path: String = PATH) -> bool:
	config={}
	error=""
	if not FileAccess.file_exists(path):
		error="room_visual_layout_v2.json missing"
		return false
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:
		error="room visual layout could not be opened"
		return false
	var parsed=JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed)!=TYPE_DICTIONARY or int(parsed.get("schema",0))!=1:
		error="room visual layout schema mismatch"
		return false
	config=parsed
	return true

func key(room_type: String, width: int) -> String:
	return "%s/R%d" % [room_type,clampi(width,1,3)]

func variant(room_type: String, width: int) -> Dictionary:
	var raw=config.get("variants",{}).get(key(room_type,width),{})
	return raw if typeof(raw)==TYPE_DICTIONARY else {}

func has_variant(room_type: String, width: int) -> bool:
	return not variant(room_type,width).is_empty()

func objects(room_type: String, width: int) -> Array:
	var value=variant(room_type,width).get("objects",[])
	return value if typeof(value)==TYPE_ARRAY else []

func procedural(room_type: String, width: int) -> Array:
	var value=variant(room_type,width).get("procedural",[])
	return value if typeof(value)==TYPE_ARRAY else []

func physical_width(width: int) -> float:
	var contract=config.get("calibration",{}).get("width_contract",{})
	var label:="R%d" % clampi(width,1,3)
	return float(contract.get(label,float(clampi(width,1,3))*4.8))
