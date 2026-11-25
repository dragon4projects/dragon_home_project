extends RefCounted
## Authored local stations and corridor/lift waypoints, inspired by observed
## Fallout Shelter room-path principles; completely original implementation.
const STATIONS := {
	"REST": Vector2(-0.78, -0.42),
	"SLEEP": Vector2(-1.24, -0.42),
	"WORK_CREATE": Vector2(-0.58, -1.05),
	"READ_BOOK": Vector2(0.82, -0.55),
	"GET_COFFEE": Vector2(-0.83, -0.70),
	"WATCH_FIRE": Vector2(-1.27, -0.65),
	"TALK_PAIR": Vector2(0.0, -0.48),
	"LISTEN_MUSIC": Vector2(0.34, -0.63),
	"WATCH_FILM": Vector2(0.0, 0.94),
	"VIEW_ART": Vector2(-0.32, -0.77),
	"PURPOSEFUL_EXPLORE": Vector2(0.7, 0.05)
}
const AISLE_Z := 0.95
const PUBLIC_FRONTAGE_Z := 1.54
const STATION_OFFSET := 0.66
var candidate_navigation=null

func station(intent: String, actor_id: String) -> Vector2:
	var base: Vector2 = STATIONS.get(intent, Vector2(0.0, 0.0))
	var variety := float(_stable_suffix(actor_id) % 4)
	if intent == "TALK_PAIR":
		base.x += (variety - 1.5) * STATION_OFFSET
	elif intent == "PURPOSEFUL_EXPLORE":
		base.x = -1.25 + variety * 0.82
		base.y = -0.72 + float(_stable_suffix(actor_id) % 3) * 0.44
	return base

func _stable_suffix(actor_id: String) -> int:
	var v := 0
	for ch in actor_id:
		v = (v * 37 + ch.unicode_at(0)) % 9973
	return v

func waypoint(x: float, y: float, z: float, room_id: String, kind: String) -> Dictionary:
	return {"position": [x, y, z], "room_id": room_id, "kind": kind}

func corridor_depth(room: Dictionary) -> float:
	return PUBLIC_FRONTAGE_Z if bool(room.get("public_frontage", false)) else AISLE_Z

func _append_if_distinct(travel: Array, point: Dictionary) -> void:
	if travel.is_empty():
		travel.append(point)
		return
	var previous:Array=travel[-1].get("position",[])
	var current:Array=point.get("position",[])
	if previous.size()!=3 or current.size()!=3:
		travel.append(point)
		return
	var a: Vector3 = Vector3(float(previous[0]),float(previous[1]),float(previous[2]))
	var b: Vector3 = Vector3(float(current[0]),float(current[1]),float(current[2]))
	if a.distance_to(b)>0.01 or str(travel[-1].get("room_id",""))!=str(point.get("room_id","")):
		travel.append(point)

func _last_position(travel: Array) -> Vector3:
	if travel.is_empty():
		return Vector3.ZERO
	var p:Array=travel[-1].get("position",[0.0,0.0,0.0])
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func _route_manhattan(travel: Array, room_id: String, target: Vector3,
		z_first: bool, first_kind: String, second_kind: String) -> void:
	if travel.is_empty():
		_append_if_distinct(travel,waypoint(target.x,target.y,target.z,room_id,second_kind))
		return
	var current:Vector3=_last_position(travel)
	if z_first:
		_append_if_distinct(travel,waypoint(
			current.x,target.y,target.z,room_id,first_kind))
		_append_if_distinct(travel,waypoint(
			target.x,target.y,target.z,room_id,second_kind))
	else:
		_append_if_distinct(travel,waypoint(
			target.x,target.y,current.z,room_id,first_kind))
		_append_if_distinct(travel,waypoint(
			target.x,target.y,target.z,room_id,second_kind))

func build_waypoints(world, actor: Dictionary, room_path: Array, intent: String,
		override_station: Variant = null, override_approach_z: float = AISLE_Z) -> Array:
	if room_path.is_empty():
		return []
	if candidate_navigation!=null:
		return _candidate_waypoints(world,actor,room_path,intent,override_station)
	var travel:Array=[]
	var first:Dictionary=world.room_by_id(str(room_path[0]))
	if first.is_empty():
		return []
	var y: float = float(first.get("level",0))*float(world.FLOOR_H)
	var actor_x: float = float(actor.get("x",world.room_center_pos(first).x))
	var actor_z: float = float(actor.get("z",0.0))
	_append_if_distinct(travel,waypoint(actor_x,y,actor_z,str(first["id"]),"leave_station"))
	var previous:Dictionary=first
	for i in range(1,room_path.size()):
		var room:Dictionary=world.room_by_id(str(room_path[i]))
		if room.is_empty() or not world.allows_transit(room):
			return []
		var connection:Dictionary=world.connection_between(previous,room)
		if connection.is_empty():
			return []
		var from_point:Vector3=connection["from"]
		var to_point:Vector3=connection["to"]
		var kind: String = str(connection.get("kind","horizontal"))
		if kind=="lift":
			# Inside the lift: align X to the core first, then move in Z.
			# This keeps the shaft route inside the lift X/Z volume.
			_route_manhattan(travel,str(previous["id"]),from_point,
				false,"lift_align","lift_core")
		else:
			# In a room: move out to the front connector aisle first, then
			# traverse X. This prevents diagonal cuts through furniture.
			_route_manhattan(travel,str(previous["id"]),from_point,
				true,"local_aisle_entry","connector_out")
		_append_if_distinct(travel,waypoint(
			to_point.x,to_point.y,to_point.z,str(room["id"]),
			"lift" if kind=="lift" else "connector_in"))
		previous=room
	if not world.is_accessible(previous,str(actor.get("id",""))):
		return []
	var anchor:Vector2=station(intent,str(actor.get("id","")))
	if override_station is Vector2:
		anchor=override_station
	var station_world:Vector3=world.room_local_to_world(previous,anchor)
	var front_aisle_z:float=minf(
		float(world.room_space.SIDE_CONNECTOR_Z),
		float(world.room_space.FRONT_Z)-0.12)
	var aisle_world:Vector3=world.room_local_to_world(
		previous,Vector2(anchor.x,front_aisle_z))
	# Whether we arrived from another room or started inside this room,
	# normalize travel through the clear front aisle before diving to a
	# station's authored approach lane.
	_route_manhattan(travel,str(previous["id"]),aisle_world,
		true,"local_aisle_entry","local_aisle")
	if override_station is Vector2:
		var safe_approach_z: float = clampf(override_approach_z,
			float(world.room_space.BACK_Z),float(world.room_space.FRONT_Z))
		if absf(anchor.y-safe_approach_z)>0.20:
			var approach_world:Vector3=world.room_local_to_world(
				previous,Vector2(anchor.x,safe_approach_z))
			_append_if_distinct(travel,waypoint(
				approach_world.x,approach_world.y,approach_world.z,
				str(previous["id"]),"station_approach"))
	_append_if_distinct(travel,waypoint(
		station_world.x,station_world.y,station_world.z,
		str(previous["id"]),"station"))
	return travel

func get_target(actor: Dictionary) -> Vector3:
	var points: Array = actor.get("waypoints",[])
	var i: int = int(actor.get("waypoint_index",0))
	if i >= points.size():
		return Vector3(float(actor.get("x",0.0)),float(actor.get("visual_y",0.0)),float(actor.get("z",0.0)))
	var p: Array = points[i]["position"]
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func _candidate_local_route(world,travel:Array,room:Dictionary,target:Vector3,kind:String)->bool:
	var start:=_last_position(travel)
	if not candidate_navigation.has_layout(room):
		_route_manhattan(travel,str(room["id"]),target,true,"local_aisle_entry",kind)
		return true
	var a:Vector2=world.room_space.world_to_local(room,start)
	var b:Vector2=world.room_space.world_to_local(room,target)
	var path:Array=candidate_navigation.path(room,a,b)
	if path.is_empty():
		return false
	for i in range(path.size()):
		var p:Vector3=world.room_local_to_world(room,path[i])
		_append_if_distinct(travel,waypoint(p.x,p.y,p.z,str(room["id"]),kind if i==path.size()-1 else "candidate_path"))
	return true

func _candidate_waypoints(world,actor:Dictionary,room_path:Array,intent:String,override_station:Variant)->Array:
	var travel:Array=[]
	var previous:Dictionary=world.room_by_id(str(room_path[0]))
	if previous.is_empty():
		return []
	var center:Vector3=world.room_center_pos(previous)
	_append_if_distinct(travel,waypoint(float(actor.get("x",center.x)),center.y,float(actor.get("z",0.0)),str(previous["id"]),"candidate_path"))
	for i in range(1,room_path.size()):
		var room:Dictionary=world.room_by_id(str(room_path[i]))
		if room.is_empty() or not world.allows_transit(room):
			return []
		var conn:Dictionary=world.connection_between(previous,room)
		if conn.is_empty():
			return []
		var from:Vector3=conn["from"]
		var to:Vector3=conn["to"]
		var lift:bool=str(conn.get("kind",""))=="lift"
		if lift:
			_route_manhattan(travel,str(previous["id"]),from,false,"lift_align","lift_core")
		elif not _candidate_local_route(world,travel,previous,from,"candidate_path"):
			return []
		_append_if_distinct(travel,waypoint(to.x,to.y,to.z,str(room["id"]),"lift" if lift else "connector_in"))
		previous=room
	if not world.is_accessible(previous,str(actor.get("id",""))):
		return []
	var anchor:Vector2=override_station if override_station is Vector2 else station(intent,str(actor.get("id","")))
	if candidate_navigation.has_layout(previous) and not (override_station is Vector2):
		anchor=candidate_navigation.nearest_clear(previous,anchor)
	var target:Vector3=world.room_local_to_world(previous,anchor)
	if not _candidate_local_route(world,travel,previous,target,"station"):
		return []
	# A same-position destination is still a station, not an endless idle path.
	if not travel.is_empty():
		travel[-1]["kind"]="station"
	return travel
