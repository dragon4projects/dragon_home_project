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
const HUNT_SECONDS:=18.0
const HUNT_COOLDOWN:=65.0
const HUNT_CONTACT:=.28
const DECISION_MIN := 6.0
const DECISION_MAX := 18.0

func setup(p_world) -> void:
	world = p_world
	rng = world.decision_rng("creatures")
	for id in world.creatures:
		var creature: Dictionary = world.creatures[id]
		if not creature.has("next_decision_at"):
			creature["next_decision_at"] = world.sim_clock
		if not creature.has("carried_object_id"):
			creature["carried_object_id"] = ""
	_reconcile_hunt()

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
	if str(creature.get("phase","idle")) in ["travel","flee","caught"]:
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
			"cinema","music","workshop","artifact","lift","kitchen"
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
	_tick_hunt(delta)
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
		if str(creature.get("phase","idle")) in ["travel","flee","caught"]:
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

# Manka is one existing resident, not a duplicate ambient entity.
# A hunt owns only the two actors' local movement until contact/release.
func _hunt_room(predator:Dictionary,mouse:Dictionary)->Dictionary:
	if predator.is_empty() or mouse.is_empty() or not predator.get("active",false) or not mouse.get("active",false) or not predator.get("autonomy_enabled",true):return {}
	if not str(mouse.get("bank_id","")).begins_with("npc_mouse_") or predator.get("room_id")!=mouse.get("room_id"):return {}
	var room:Dictionary=world.room_by_id(str(predator.get("room_id","")))
	if room.is_empty() or room.get("type")=="lift" or not world.public_cutaway_allowed(room) or not world.is_accessible(room,"MANJKA"):return {}
	var center:Vector3=world.room_center_pos(room)
	for a in [predator,mouse]:
		var pos:=Vector3(float(a.get("x",INF)),float(a.get("visual_y",float(a.get("level",0))*world.FLOOR_H)),float(a.get("z",INF)))
		if not pos.is_finite() or absf(pos.y-center.y)>.035 or absf(pos.x-center.x)>float(room.get("size_modules",1))*2.4-.02:return {}
		if locomotion.candidate_navigation==null or not locomotion.candidate_navigation.has_layout(room) or not locomotion.candidate_navigation.clear(room,Vector2(pos.x-center.x,pos.z)):return {}
	return room

func _hunt_local(a:Dictionary,room:Dictionary)->Vector2:
	var c:Vector3=world.room_center_pos(room)
	return Vector2(float(a["x"])-c.x,float(a["z"]))

func _hunt_move(a:Dictionary,room:Dictionary,to:Vector2,speed:float,dt:float)->bool:
	var nav=locomotion.candidate_navigation
	var at:=_hunt_local(a,room)
	var next:=at.move_toward(to,speed*minf(dt,.15))
	if not nav.segment_clear(room,at,next):return false
	var c:Vector3=world.room_center_pos(room)
	a["x"]=c.x+next.x
	a["z"]=next.y
	a["visual_y"]=c.y
	if absf(next.x-at.x)>.001:a["moving_axis"]="left" if next.x<at.x else "right"
	return true

func hunt_target_room(predator:Dictionary)->Dictionary:
	if float(predator.get("hunt_next_at",0))>world.sim_clock:return {}
	var best:Dictionary={}
	var cost:=999
	for mouse in world.creatures.values():
		if not mouse.get("active",false) or not str(mouse.get("bank_id","")).begins_with("npc_mouse_"):continue
		var room:Dictionary=world.room_by_id(str(mouse.get("room_id","")))
		if room.is_empty() or room.get("type")=="lift" or not world.public_cutaway_allowed(room) or locomotion.candidate_navigation==null or not locomotion.candidate_navigation.has_layout(room):continue
		if room.get("id")==predator.get("room_id"):continue
		var route:Array=world.find_route(str(predator.get("room_id","")),str(room["id"]),"MANJKA")
		if not route.is_empty() and route.size()<cost:best=room;cost=route.size()
	return best

func try_begin_hunt(predator:Dictionary)->bool:
	if predator.get("id")!="MANJKA" or predator.get("phase") in ["travel","hunt"] or float(predator.get("hunt_next_at",0))>world.sim_clock:return false
	# Do not simultaneously hunt while holding an artifact.
	for obj in world.objects.values():
		if obj.get("current_holder_id")=="MANJKA":return false
	for mouse in world.creatures.values():
		var room:Dictionary=_hunt_room(predator,mouse)
		if room.is_empty() or mouse.get("phase","idle") in ["caught","flee"]:continue
		predator["hunt_target_id"]=mouse["id"]
		predator["hunt_deadline"]=world.sim_clock+HUNT_SECONDS
		predator["hunt_stage"]="chase"
		predator["hunt_replan_at"]=0.0
		predator["hunt_path"]=[]
		predator["phase"]="hunt"
		predator["intent"]="HUNT_MOUSE"
		predator["until"]=predator["hunt_deadline"]
		predator["waypoints"]=[]
		predator["waypoint_index"]=0
		mouse["phase"]="flee"
		mouse["hunted_by"]="MANJKA"
		mouse["waypoints"]=[]
		mouse["waypoint_index"]=0
		mouse.erase("route_target_room_id")
		mouse.erase("route_origin_room_id")
		mouse["flee_goal"]=[]
		world._append_journal("MANKA_HUNT_STARTED","MANJKA",mouse["id"],room["id"],room["id"])
		return true
	return false

func _end_hunt(predator:Dictionary,reason:String,reset_predator:bool=true)->void:
	var target:String=str(predator.get("hunt_target_id",""))
	var mouse:Dictionary=world.creatures.get(target,{})
	if not mouse.is_empty() and mouse.get("hunted_by")=="MANJKA":
		mouse.erase("hunted_by")
		mouse.erase("flee_goal")
		mouse["phase"]="idle"
		mouse["next_decision_at"]=world.sim_clock+3.0
	for key in ["hunt_target_id","hunt_stage","hunt_deadline","hunt_path","hunt_replan_at","hunt_release_at"]:predator.erase(key)
	predator["hunt_next_at"]=world.sim_clock+HUNT_COOLDOWN
	if reset_predator:
		predator["phase"]="idle"
		predator["intent"]="REST"
		predator["until"]=world.sim_clock
	world._append_journal("MANKA_HUNT_ENDED","MANJKA",target,str(predator.get("room_id","")),str(predator.get("room_id","")),{"reason":reason})

func _reconcile_hunt()->void:
	var predator:Dictionary=world.residents.get("MANJKA",{})
	if predator.get("phase")=="hunt":
		var mouse:Dictionary=world.creatures.get(str(predator.get("hunt_target_id","")),{})
		var stage:String=str(predator.get("hunt_stage",""))
		if _hunt_room(predator,mouse).is_empty() or mouse.get("hunted_by")!="MANJKA" or not stage in ["chase","hold"] or (stage=="chase" and mouse.get("phase")!="flee") or (stage=="hold" and mouse.get("phase")!="caught"):
			_end_hunt(predator,"INVALID_RESTORED_HUNT")
		else:
			predator["hunt_path"]=[]
			predator["hunt_replan_at"]=0.0
			mouse["flee_goal"]=[]
	for mouse in world.creatures.values():
		if mouse.get("phase") in ["flee","caught"] and (predator.get("phase")!="hunt" or predator.get("hunt_target_id")!=mouse.get("id")):
			mouse["phase"]="idle"
			mouse.erase("hunted_by")
			mouse.erase("flee_goal")

func _tick_hunt(delta:float)->void:
	var p:Dictionary=world.residents.get("MANJKA",{})
	if p.get("phase")!="hunt":
		if p.has("hunt_target_id"):_end_hunt(p,"PREDATOR_REPLANNED",false)
		return
	var m:Dictionary=world.creatures.get(str(p.get("hunt_target_id","")),{})
	var room:Dictionary=_hunt_room(p,m)
	if room.is_empty() or m.get("hunted_by")!="MANJKA":
		_end_hunt(p,"TARGET_UNAVAILABLE");return
	if p.get("hunt_stage")=="hold":
		if _hunt_local(p,room).distance_to(_hunt_local(m,room))>HUNT_CONTACT+.01:
			_end_hunt(p,"CONTACT_LOST");return
		if world.sim_clock>=float(p.get("hunt_release_at",0)):
			_end_hunt(p,"RELEASED")
		return
	if world.sim_clock>=float(p.get("hunt_deadline",0)):
		_end_hunt(p,"ESCAPED");return
	var nav=locomotion.candidate_navigation
	var pp:=_hunt_local(p,room)
	var mp:=_hunt_local(m,room)
	if pp.distance_to(mp)<=HUNT_CONTACT and nav.segment_clear(room,pp,mp):
		p["hunt_stage"]="hold"
		p["hunt_release_at"]=world.sim_clock+1.5
		m["phase"]="caught"
		world._append_journal("MANKA_MOUSE_CAUGHT","MANJKA",m["id"],room["id"],room["id"],{"distance_m":pp.distance_to(mp)})
		return
	var raw:Array=m.get("flee_goal",[])
	if raw.size()!=2 or mp.distance_to(Vector2(raw[0],raw[1]))<.15:
		var away:Vector2=(mp-pp).normalized()
		var best:Vector2=mp
		var score:float=mp.distance_to(pp)
		for angle in [0.0,.8,-.8,1.57,-1.57,2.35,-2.35]:
			var to:Vector2=mp+away.rotated(angle)*1.0
			if nav.segment_clear(room,mp,to) and to.distance_to(pp)>score:
				best=to;score=to.distance_to(pp)
		m["flee_goal"]=[best.x,best.y]
		raw=m["flee_goal"]
	_hunt_move(m,room,Vector2(raw[0],raw[1]),2.45,delta)
	mp=_hunt_local(m,room)
	if nav.segment_clear(room,pp,mp):
		_hunt_move(p,room,mp,3.85,delta)
		p["hunt_path"]=[]
	elif world.sim_clock>=float(p.get("hunt_replan_at",0)):
		var path:Array=nav.path(room,pp,mp)
		p["hunt_path"]=path.map(func(v):return [v.x,v.y])
		p["hunt_replan_at"]=world.sim_clock+.5
	var points:Array=p.get("hunt_path",[])
	if not points.is_empty():
		var point:Vector2=Vector2(points[0][0],points[0][1])
		if not _hunt_move(p,room,point,3.85,delta):p["hunt_path"]=[]
		elif _hunt_local(p,room).distance_to(point)<.04:points.pop_front()
