extends RefCounted
const RoomLocomotion = preload("res://scripts/room_locomotion.gd")
## Low-frequency ambient creature actions.
## This layer may move only explicit creature actors and explicit opt-in objects.
## It never opens private rooms, invents ownership, or duplicates an object identity.

var world
var rng := RandomNumberGenerator.new()
var locomotion := RoomLocomotion.new()
var canonical_lifts=null
var max_actions_per_tick := 1
const DECISION_MIN := 6.0
const DECISION_MAX := 18.0

func setup(p_world) -> void:
	world = p_world
	rng.seed = 923118
	for id in world.creatures:
		var creature: Dictionary = world.creatures[id]
		if not creature.has("next_decision_at"):
			creature["next_decision_at"] = world.sim_clock
		if not creature.has("carried_object_id"):
			creature["carried_object_id"] = ""

func _creature(creature_id: String) -> Dictionary:
	return world.creatures.get(creature_id, {}) if world != null else {}

func public_neighbors(creature_id: String) -> Array:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty():
		return []
	var room: Dictionary = world.room_by_id(str(creature.get("room_id","")))
	if room.is_empty():
		return []
	var out: Array = []
	for candidate in world.neighbors(room, ""):
		# Public frontage of a private room is transit geometry, not creature access.
		if str(candidate.get("privacy","public")) == "public":
			out.append(candidate)
	return out

func _reject_target(creature_id: String, creature: Dictionary,
		target_room_id: String) -> void:
	var rejected: Dictionary = world.room_by_id(target_room_id)
	if rejected.is_empty():
		return
	world._append_journal("CREATURE_ACCESS_REJECTED",creature_id,creature_id,
		str(creature.get("room_id","")),target_room_id,
		{"reason":"ROOM_NOT_ACCESSIBLE","privacy":str(rejected.get("privacy",""))})

func begin_roam(creature_id: String, target_room_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	if str(creature.get("phase","idle")) == "travel":
		return false
	var target: Dictionary = {}
	if target_room_id != "":
		target = world.room_by_id(target_room_id)
		if target.is_empty() or str(target.get("privacy","public")) != "public":
			_reject_target(creature_id,creature,target_room_id)
			return false
	else:
		var candidates: Array = world.matching_rooms([
			"arrival","corridor","common","study","rest","library",
			"cinema","music","workshop","artifact","lift"
		],"")
		for room in candidates:
			if str(room.get("id","")) != str(creature.get("room_id","")):
				var route: Array = world.find_route(
					str(creature.get("room_id","")),str(room.get("id","")),"")
				if not route.is_empty():
					candidates = candidates.filter(
						func(candidate): return str(candidate.get("id","")) != str(creature.get("room_id","")))
					break
		if candidates.is_empty():
			return false
		# Try a bounded number of random public destinations until one has a route.
		for _attempt in range(mini(8,candidates.size())):
			var candidate: Dictionary = candidates[rng.randi_range(0,candidates.size()-1)]
			var route: Array = world.find_route(
				str(creature.get("room_id","")),str(candidate.get("id","")),"")
			if not route.is_empty():
				target = candidate
				break
		if target.is_empty():
			return false
	var route: Array = world.find_route(
		str(creature.get("room_id","")),str(target.get("id","")),"")
	if route.is_empty():
		if target_room_id != "":
			_reject_target(creature_id,creature,target_room_id)
		return false
	var points: Array = locomotion.build_waypoints(
		world,creature,route,"PURPOSEFUL_EXPLORE")
	if points.is_empty():
		return false
	creature["waypoints"] = points
	creature["waypoint_index"] = 0
	creature["phase"] = "travel"
	creature["route_target_room_id"] = str(target["id"])
	creature["route_origin_room_id"] = str(creature.get("room_id",""))
	return true

func advance_travel(creature_id: String, delta: float) -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or str(creature.get("phase","idle")) != "travel":
		return false
	var points: Array = creature.get("waypoints",[])
	var index := int(creature.get("waypoint_index",0))
	if index >= points.size():
		creature["phase"] = "idle"
		return false
	var point: Dictionary = points[index]
	var target: Vector3 = locomotion.get_target(creature)
	var at := Vector3(
		float(creature.get("x",0.0)),
		float(creature.get("visual_y",float(creature.get("level",0))*world.FLOOR_H)),
		float(creature.get("z",0.25)))
	if canonical_lifts!=null and str(point.get("kind",""))=="lift":
		var lift_move:Dictionary=canonical_lifts.target(creature,at,target)
		if bool(lift_move.get("wait",false)):
			creature["moving_axis"]="wait"
			return true
		target=lift_move["target"]
		if bool(lift_move.get("boarding",false)):
			var aligned:=at.move_toward(target,2.65*minf(delta,0.15))
			creature["x"]=aligned.x
			creature["z"]=aligned.z
			creature["moving_axis"]="depth"
			return true
	var speed := 2.65
	if str(point.get("kind","")) == "lift":
		speed = 1.55
	var next := at.move_toward(target,speed*minf(delta,0.15))
	creature["x"] = next.x
	creature["visual_y"] = next.y
	creature["z"] = next.z
	creature["moving_axis"] = "right" if next.x > at.x else (
		"left" if next.x < at.x else "depth")
	if next.distance_to(target) <= 0.03:
		creature["room_id"] = str(point.get("room_id",creature.get("room_id","")))
		var current: Dictionary = world.room_by_id(str(creature["room_id"]))
		if not current.is_empty():
			creature["level"] = int(current["level"])
		creature["waypoint_index"] = index + 1
		if canonical_lifts!=null and str(point.get("kind",""))=="lift" and (index+1>=points.size() or str(points[index+1]["kind"])!="lift"):
			canonical_lifts.release(creature)
		if int(creature["waypoint_index"]) >= points.size():
			var origin := str(creature.get("route_origin_room_id",""))
			var destination := str(creature.get("route_target_room_id",creature.get("room_id","")))
			creature["phase"] = "idle"
			creature["waypoints"] = []
			creature["waypoint_index"] = 0
			creature.erase("route_origin_room_id")
			creature.erase("route_target_room_id")
			world._append_journal("CREATURE_ROAMED",creature_id,creature_id,
				origin,destination,
				{"carrying":str(creature.get("carried_object_id",""))})
	return true

func roam_one_step(creature_id: String, target_room_id: String = "") -> bool:
	# Compatibility name retained for tests/callers: this now STARTS real travel.
	return begin_roam(creature_id,target_room_id)

func pickup_eligible_here(creature_id: String, object_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	if not bool(creature.get("can_pickup_objects",false)):
		return false
	if str(creature.get("carried_object_id","")) != "":
		return false
	var room_id: String = str(creature.get("room_id",""))
	var candidates: Array = []
	for id in world.objects:
		var object: Dictionary = world.objects[id]
		if str(object.get("current_room_id","")) != room_id:
			continue
		if not world.can_ambient_pickup_object(str(id)):
			continue
		if object_id != "" and str(id) != object_id:
			continue
		candidates.append(str(id))
	if candidates.is_empty():
		return false
	var selected: String = candidates[0] if object_id != "" else candidates[rng.randi_range(0,candidates.size()-1)]
	if not world.pickup_physical_object(selected, creature_id):
		return false
	creature["carried_object_id"] = selected
	return true

func stash_carried(creature_id: String, target_room_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	if not bool(creature.get("can_hide_objects",false)):
		return false
	var object_id: String = str(creature.get("carried_object_id",""))
	if object_id == "":
		return false
	var object: Dictionary = world.physical_object(object_id)
	if object.is_empty() or not bool(object.get("ambient_hide_allowed",false)):
		return false
	var room_id: String = str(creature.get("room_id",""))
	if target_room_id != "" and target_room_id != room_id:
		# Hiding is physical: the creature must actually be in the destination room.
		return false
	var room: Dictionary = world.room_by_id(room_id)
	if room.is_empty() or str(room.get("privacy","public")) != "public":
		return false
	if not world.place_physical_object(object_id, creature_id, room_id, "STASHED"):
		return false
	creature["carried_object_id"] = ""
	return true

func tick(delta: float) -> void:
	if world == null or world.creatures.is_empty():
		return
	# Movement is frame-driven; decisions stay low-frequency.
	for id in world.creatures:
		var moving: Dictionary = world.creatures[id]
		if bool(moving.get("active",false)) and str(moving.get("phase","idle")) == "travel":
			advance_travel(str(id),delta)
	var actions := 0
	for id in world.creatures:
		if actions >= max_actions_per_tick:
			break
		var creature: Dictionary = world.creatures[id]
		if not bool(creature.get("active",false)):
			continue
		if str(creature.get("phase","idle")) == "travel":
			continue
		if float(creature.get("next_decision_at",0.0)) > world.sim_clock:
			continue
		var acted := false
		if str(creature.get("carried_object_id","")) != "":
			if bool(creature.get("can_hide_objects",false)) and rng.randf() < 0.38:
				acted = stash_carried(str(id))
			if not acted:
				acted = begin_roam(str(id))
		else:
			if bool(creature.get("can_pickup_objects",false)) and rng.randf() < 0.24:
				acted = pickup_eligible_here(str(id))
			if not acted:
				acted = begin_roam(str(id))
		creature["next_decision_at"] = world.sim_clock + rng.randf_range(DECISION_MIN,DECISION_MAX)
		if acted:
			actions += 1
