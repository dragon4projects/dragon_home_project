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
	# Passing a private door is permitted only in the public hallway in front of it.
	return PUBLIC_FRONTAGE_Z if bool(room.get("public_frontage", false)) else AISLE_Z

func build_waypoints(world, actor: Dictionary, room_path: Array, intent: String, override_station: Variant = null) -> Array:
	if room_path.is_empty():
		return []
	var travel: Array = []
	var first: Dictionary = world.room_by_id(room_path[0])
	if first.is_empty():
		return []
	var previous: Dictionary = first
	var x: float = float(first["x"]) * world.MODULE_W
	var y: float = float(first["level"]) * world.FLOOR_H
	travel.append(waypoint(float(actor.get("x",x)), y, corridor_depth(first), first["id"], "leave_station"))
	travel.append(waypoint(x, y, corridor_depth(first), first["id"], "room_center"))
	for i in range(1,room_path.size()):
		var room: Dictionary = world.room_by_id(room_path[i])
		if room.is_empty() or not world.allows_transit(room):
			return []
		var nx: float = float(room["x"]) * world.MODULE_W
		var ny: float = float(room["level"]) * world.FLOOR_H
		if room["level"] != previous["level"]:
			if room["type"] != "lift" or previous["type"] != "lift" or room["x"] != previous["x"]:
				return [] # never jump floors outside actual lift shaft
			travel.append(waypoint(nx, ny, AISLE_Z, room["id"], "lift"))
		else:
			var direction: float = signf(nx-x)
			var depth: float = maxf(corridor_depth(previous),corridor_depth(room))
			if depth > corridor_depth(previous):
				travel.append(waypoint(x,y,depth,previous["id"],"approach_public_frontage"))
			travel.append(waypoint(x+direction*world.MODULE_W*0.49,y,depth,previous["id"],"door_out"))
			travel.append(waypoint(nx-direction*world.MODULE_W*0.49,ny,depth,room["id"],"door_in"))
			travel.append(waypoint(nx,ny,corridor_depth(room),room["id"],"room_center"))
		x=nx
		y=ny
		previous=room
	# Only public destinations can become activity stations.
	if not world.is_accessible(previous,str(actor.get("id",""))):
		return []
	var anchor: Vector2 = station(intent,str(actor.get("id","")))
	if override_station is Vector2:
		anchor = override_station
		# Walk along the public aisle to the correct sofa/work position first,
		# instead of taking a diagonal shortcut through other furniture.
		if anchor.y < AISLE_Z - 0.45:
			travel.append(waypoint(x+anchor.x,y,AISLE_Z,previous["id"],"station_approach"))
	travel.append(waypoint(x+anchor.x,y,anchor.y,previous["id"],"station"))
	return travel

func get_target(actor: Dictionary) -> Vector3:
	var points: Array = actor.get("waypoints",[])
	var i: int = int(actor.get("waypoint_index",0))
	if i >= points.size():
		return Vector3(float(actor.get("x",0.0)),float(actor.get("visual_y",0.0)),float(actor.get("z",0.0)))
	var p: Array = points[i]["position"]
	return Vector3(float(p[0]),float(p[1]),float(p[2]))
