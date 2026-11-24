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
	var a:=Vector3(float(previous[0]),float(previous[1]),float(previous[2]))
	var b:=Vector3(float(current[0]),float(current[1]),float(current[2]))
	if a.distance_to(b)>0.01 or str(travel[-1].get("room_id",""))!=str(point.get("room_id","")):
		travel.append(point)

func build_waypoints(world, actor: Dictionary, room_path: Array, intent: String,
		override_station: Variant = null, override_approach_z: float = AISLE_Z) -> Array:
	if room_path.is_empty():
		return []
	var travel:Array=[]
	var first:Dictionary=world.room_by_id(str(room_path[0]))
	if first.is_empty():
		return []
	var y:=float(first.get("level",0))*world.FLOOR_H
	var actor_x:=float(actor.get("x",world.room_center_pos(first).x))
	var actor_z:=float(actor.get("z",0.0))
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
		var kind:=str(connection.get("kind","horizontal"))
		_append_if_distinct(travel,waypoint(
			from_point.x,from_point.y,from_point.z,str(previous["id"]),
			"lift_core" if kind=="lift" else "connector_out"))
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
	if override_station is Vector2:
		var safe_approach_z:=clampf(override_approach_z,
			world.room_space.BACK_Z,world.room_space.FRONT_Z)
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
