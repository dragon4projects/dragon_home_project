extends RefCounted
## Iteration 2 physical room topology.
## A room is one immutable-sized X/Z volume (R1/R2/R3), not a dynamic merge
## of neighboring logical cells. Connectors are explicit room-owned geometry.
const DEPTH7=preload("res://scripts/depth7_space.gd")
const MODULE_W := 4.8
const FLOOR_H := 4.6
const BACK_Z := -1.95
const FRONT_Z := 1.65
const SIDE_CONNECTOR_Z := 1.50
const LIFT_CORE_Z := 0.0
const CONNECTOR_INSET := 0.08

const VALID_SIZES := [1,2,3]

func normalize_size(value: int) -> int:
	return clampi(value,1,3)

func size_id(value: int) -> String:
	return "R%d" % normalize_size(value)

func size_modules(room: Dictionary) -> int:
	return normalize_size(int(room.get("size_modules",1)))

func x_start(room: Dictionary) -> int:
	return int(room.get("x",0))

func x_end(room: Dictionary) -> int:
	return x_start(room)+size_modules(room)-1

func center_cell(room: Dictionary) -> float:
	return float(x_start(room))+(float(size_modules(room))-1.0)*0.5

func physical_width(room: Dictionary) -> float:
	return float(size_modules(room))*MODULE_W

func half_width(room: Dictionary) -> float:
	return physical_width(room)*0.5

func center_world(room: Dictionary) -> Vector3:
	return Vector3(center_cell(room)*MODULE_W,
		float(room.get("level",0))*FLOOR_H,0.0)

func covers_cell(room: Dictionary, x: int, level: int) -> bool:
	return int(room.get("level",0))==level and x>=x_start(room) and x<=x_end(room)

func local_to_world(room: Dictionary, local: Vector2) -> Vector3:
	var center: Vector3 = center_world(room)
	return Vector3(center.x+local.x,center.y,local.y)

func world_to_local(room: Dictionary, position: Vector3) -> Vector2:
	var center:=center_world(room)
	return Vector2(position.x-center.x,position.z)

func back_z(room:Dictionary)->float:
	return DEPTH7.BACK if DEPTH7.enabled_for(room) else BACK_Z

func local_contains(room: Dictionary, local: Vector2, margin: float = 0.0) -> bool:
	return local.x>=-half_width(room)+margin and local.x<=half_width(room)-margin and (
		local.y>=back_z(room)+margin and local.y<=FRONT_Z-margin)

func default_connectors(room_type: String, modules: int) -> Array:
	var safe: int = normalize_size(modules)
	var hw: float = float(safe)*MODULE_W*0.5
	var result:Array=[
		{"id":"west","side":"west","axis":"x","kind":"passage",
			"local":[-hw,SIDE_CONNECTOR_Z],"enabled":true},
		{"id":"east","side":"east","axis":"x","kind":"passage",
			"local":[hw,SIDE_CONNECTOR_Z],"enabled":true}
	]
	if room_type=="lift":
		result.append({"id":"down","side":"down","axis":"y","kind":"lift",
			"local":[0.0,LIFT_CORE_Z],"enabled":true})
		result.append({"id":"up","side":"up","axis":"y","kind":"lift",
			"local":[0.0,LIFT_CORE_Z],"enabled":true})
	return result

func ensure_room_shape(room: Dictionary) -> void:
	var modules: int = normalize_size(int(room.get("size_modules",1)))
	room["size_modules"]=modules
	room["size_id"]=size_id(modules)
	room["topology_version"]=2
	if typeof(room.get("connectors",null))!=TYPE_ARRAY:
		room["connectors"]=default_connectors(str(room.get("type","")),modules)

func virtual_modules(room: Dictionary) -> Array:
	var result:Array=[]
	var start: int = x_start(room)
	for module_index in range(size_modules(room)):
		var module:Dictionary=room.duplicate(true)
		module["x"]=start+module_index
		module["module_index"]=module_index
		module["module_id"]="%s#M%d" % [str(room.get("id","ROOM")),module_index]
		module["physical_room_id"]=str(room.get("id",""))
		result.append(module)
	return result

func _connector(room: Dictionary, side: String) -> Dictionary:
	for raw in room.get("connectors",[]):
		if typeof(raw)!=TYPE_DICTIONARY:
			continue
		var connector:Dictionary=raw
		if str(connector.get("side",""))==side and bool(connector.get("enabled",true)):
			return connector
	return {}

func connector_world(room: Dictionary, side: String, inside: bool = false) -> Vector3:
	var connector: Dictionary = _connector(room,side)
	if connector.is_empty():
		return center_world(room)
	var local:Array=connector.get("local",[0.0,SIDE_CONNECTOR_Z])
	var x: float = float(local[0])
	var z: float = float(local[1])
	if inside:
		if side=="west":
			x+=CONNECTOR_INSET
		elif side=="east":
			x-=CONNECTOR_INSET
	return local_to_world(room,Vector2(x,z))

func connection_between(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty() or b.is_empty() or str(a.get("id",""))==str(b.get("id","")):
		return {}
	var a_level: int = int(a.get("level",0))
	var b_level: int = int(b.get("level",0))
	if a_level==b_level:
		if x_end(a)+1==x_start(b):
			if _connector(a,"east").is_empty() or _connector(b,"west").is_empty():
				return {}
			return {
				"kind":"horizontal","from_side":"east","to_side":"west",
				"from":connector_world(a,"east",true),
				"to":connector_world(b,"west",true)
			}
		if x_end(b)+1==x_start(a):
			if _connector(a,"west").is_empty() or _connector(b,"east").is_empty():
				return {}
			return {
				"kind":"horizontal","from_side":"west","to_side":"east",
				"from":connector_world(a,"west",true),
				"to":connector_world(b,"east",true)
			}
		return {}
	if abs(a_level-b_level)!=1:
		return {}
	if str(a.get("type",""))!="lift" or str(b.get("type",""))!="lift":
		return {}
	if not is_equal_approx(center_cell(a),center_cell(b)):
		return {}
	var from_side: String = "up" if b_level>a_level else "down"
	var to_side: String = "down" if b_level>a_level else "up"
	if _connector(a,from_side).is_empty() or _connector(b,to_side).is_empty():
		return {}
	return {
		"kind":"lift","from_side":from_side,"to_side":to_side,
		"from":connector_world(a,from_side,true),
		"to":connector_world(b,to_side,true)
	}

func perspective_scale(z: float) -> float:
	var t: float = clampf((z-BACK_Z)/(FRONT_Z-BACK_Z),0.0,1.0)
	# The perspective camera now provides most of the apparent depth. Keep only
	# a mild artistic correction so far actors/props retain Shelter readability.
	return lerpf(0.85,1.0,t)
