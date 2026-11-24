extends RefCounted
const InteractionAnchors = preload("res://scripts/interaction_anchor_registry.gd")
const REVIEW_MARKER := "res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"
const REVIEW_FURNITURE := "res://data/integration_candidates/furniture_interactions_iter1_review.json"
## Explicit, deterministic local station reservations. No AI/external dependency.
## Reservations live on actor state so save/load can reconstruct occupancy.
## PRIVATE rooms are never public station pools.
const CAPACITY_BY_SIZE := {1:4,2:8,3:16}
const MODULE_W := 4.8
const BACK_Z := -1.95
const FRONT_Z := 1.65
var furniture = InteractionAnchors.new()

func _init() -> void:
	var selected := REVIEW_FURNITURE if FileAccess.file_exists(REVIEW_MARKER) else InteractionAnchors.DEFAULT_PATH
	if not furniture.initialize(selected):
		push_warning("Interaction anchor manifest unavailable: "+furniture.last_error)
		if selected != InteractionAnchors.DEFAULT_PATH:
			furniture.initialize(InteractionAnchors.DEFAULT_PATH)

func capacity(room: Dictionary) -> int:
	if room.is_empty() or str(room.get("privacy","public"))!="public" or (
			str(room.get("type",""))=="lift"):
		return 0
	var modules: int = clampi(int(room.get("size_modules",1)),1,3)
	return int(CAPACITY_BY_SIZE[modules])

func _spot(x: float, z: float, kind: String = "standing", object_id: String = "") -> Dictionary:
	return {"offset":Vector2(x,z),"kind":kind,"furniture_id":object_id}

func _physical_anchor_data(room: Dictionary) -> Array:
	var width: int = clampi(int(room.get("size_modules",1)),1,3)
	var result:Array=[]
	var center_index:float=(float(width)-1.0)*0.5
	var per_module:Array=[]
	var max_count: int = 0
	for module_index in range(width):
		var module_room:Dictionary=room.duplicate(true)
		module_room["x"]=int(room.get("x",0))+module_index
		var anchors:Array=furniture.for_room_variant(module_room,width,module_index)
		per_module.append(anchors)
		max_count=maxi(max_count,anchors.size())
	# Round-robin across modules: truncating to R1/R2/R3 capacity must not
	# populate only the left side of a wide physical room.
	for anchor_index in range(max_count):
		for module_index in range(width):
			var anchors:Array=per_module[module_index]
			if anchor_index>=anchors.size():
				continue
			var raw:Dictionary=anchors[anchor_index]
			var item:Dictionary=raw.duplicate(true)
			item["id"]="m%d_%s" % [module_index,str(item.get("id","station"))]
			item["x"]=(float(module_index)-center_index)*MODULE_W+float(item.get("x",0.0))
			result.append(item)
	return result

func _layout_from_anchors(room: Dictionary, anchors: Array) -> Array:
	var count:int=capacity(room)
	if count<=0:
		return []
	var width:=clampi(int(room.get("size_modules",1)),1,3)
	var half_width:=float(width)*MODULE_W*0.5
	var positions:Array=[]
	for item in anchors:
		if positions.size()>=count:
			break
		var offset: Vector2 = Vector2(float(item.get("x",0.0)),float(item.get("z",0.0)))
		if offset.x<=-half_width+0.10 or offset.x>=half_width-0.10 or (
				offset.y<BACK_Z or offset.y>FRONT_Z):
			continue
		positions.append({
			"id":str(item.get("id","station")),
			"offset":offset,
			"kind":str(item.get("kind","standing")),
			"furniture_id":str(item.get("furniture_id","")),
			"pose_hint":str(item.get("pose_hint","IDLE_S")),
			"approach_z":clampf(float(item.get("approach_z",1.25)),BACK_Z,FRONT_Z)
		})
	var candidates:Array=[]
	var idx:=0
	var center_index:float=(float(width)-1.0)*0.5
	for z in [1.34,0.42,-0.66,-1.52]:
		for module_index in range(width):
			var module_center:float=(float(module_index)-center_index)*MODULE_W
			for local_x in [-1.55,-0.52,0.52,1.55]:
				var xx: float = module_center+float(local_x)
				if xx<=-half_width+0.18 or xx>=half_width-0.18:
					continue
				candidates.append({
					"id":"stand_%02d" % idx,
					"offset":Vector2(xx,float(z)),
					"kind":"standing","furniture_id":"",
					"pose_hint":"IDLE_S",
					"approach_z":clampf(float(z)+0.35,BACK_Z,FRONT_Z)
				})
				idx+=1
	for place in candidates:
		if positions.size()>=count:
			break
		var pos:Vector2=place["offset"]
		var conflict: bool = false
		for existing in positions:
			if pos.distance_to(existing["offset"])<0.73:
				conflict=true
				break
		if not conflict:
			positions.append(place)
	assert(positions.size()==count,"A physical room must expose distinct X/Z stations")
	for place in positions:
		var p:Vector2=place["offset"]
		assert(p.x>-half_width and p.x<half_width)
		assert(p.y>=BACK_Z and p.y<=FRONT_Z)
	return positions

func layout(room: Dictionary) -> Array:
	if room.is_empty() or str(room.get("privacy","public"))!="public":
		return []
	return _layout_from_anchors(room,_physical_anchor_data(room))

func layout_for_world(_world, room: Dictionary) -> Array:
	return layout(room)

func _intent_prefers_station(intent: String, kind: String) -> bool:
	match intent:
		"REST","SLEEP":
			return kind in ["seat","floor_rest"]
		"READ_BOOK":
			return kind in ["seat","work"]
		"WORK_CREATE","BROWSE_BOOK_CATALOG":
			return kind=="work"
		"WATCH_FILM":
			return kind=="seat"
		"TALK_PAIR":
			return kind=="seat"
		_:
			return kind=="standing"

func used_slots(world, room_id: String, ignore_ids: Array = []) -> Dictionary:
	var used: Dictionary = {}
	for id in world.residents:
		if ignore_ids.has(id):
			continue
		var actor: Dictionary = world.residents[id]
		if not bool(actor.get("active",false)):
			continue
		if str(actor.get("station_room_id","")) == room_id:
			var slot := int(actor.get("station_slot",-1))
			if slot >= 0 and str(actor.get("phase","idle")) in ["travel","perform"]:
				used[slot] = id
	return used

func available_count(world, room: Dictionary) -> int:
	if room.is_empty() or room.get("privacy","public") != "public":
		return 0
	return maxi(0,capacity(room)-used_slots(world,str(room["id"])).size())

func _claim(room: Dictionary, index: int, spot: Dictionary) -> Dictionary:
	return {"room_id":str(room["id"]),"slot":index,
		"offset":spot["offset"],"kind":str(spot.get("kind","standing")),
		"furniture_id":str(spot.get("furniture_id","")),
		"anchor_id":str(spot.get("id","")),
		"pose_hint":str(spot.get("pose_hint","IDLE_S")),
		"approach_z":float(spot.get("approach_z",0.95))}

func single(world, actor: Dictionary, room: Dictionary, intent: String = "") -> Dictionary:
	var id: String = str(actor.get("id",""))
	if room.is_empty() or room.get("privacy","public") != "public" or not world.is_accessible(room,id) or capacity(room)==0:
		return {}
	var used: Dictionary = used_slots(world,str(room["id"]),[id])
	var points: Array = layout_for_world(world,room)
	# If the actor is continuing a reservation, keep its exact location.
	var prior := int(actor.get("station_slot",-1))
	if str(actor.get("station_room_id","")) == room["id"] and prior >= 0 and prior < points.size() and not used.has(prior):
		return _claim(room,prior,points[prior])
	# Deterministic id rotation distributes arrivals across the room.
	var start: int = 0
	for ch in id:
		start = posmod(start*31+ch.unicode_at(0),997)
	# Prefer a real seat/work surface. When full, side-space is safer than
	# putting a standing person's sprite directly in front of two seated
	# people, even if its (x,z) coordinates are technically unique.
	var resting: bool=intent in ["REST","SLEEP","READ_BOOK","WATCH_FILM"]
	for pass_id in range(3):
		if pass_id==1 and not resting:
			continue
		var prefer_functional: bool=pass_id==0
		var prefer_side: bool=pass_id==1
		for step in range(points.size()):
			var idx: int=(start+step)%points.size()
			if used.has(idx):
				continue
			var spot: Dictionary=points[idx]
			var matches: bool=_intent_prefers_station(intent,str(spot.get("kind","standing")))
			if matches!=prefer_functional:
				continue
			if prefer_side and absf(float(spot["offset"].x))<1.45:
				continue
			return _claim(room,idx,spot)
	return {}

func _paired_spots(points: Array, used: Dictionary, seats_only: bool = false) -> Array:
	for left in range(points.size()-1):
		if used.has(left):
			continue
		for right in range(left+1,points.size()):
			if used.has(right):
				continue
			var a: Dictionary=points[left]
			var b: Dictionary=points[right]
			if seats_only and (a.get("kind","")!="seat" or b.get("kind","")!="seat"):
				continue
			var one: Vector2=a["offset"]
			var two: Vector2=b["offset"]
			if absf(one.y-two.y)>0.04:
				continue
			var dx:float=absf(one.x-two.x)
			# Authored R1 sofa seats are 0.6608 m apart; TEEA review anchors
			# legally reach ~0.605 m. Both are distinct physical seats, so the
			# social-pair gate must match the accepted X/Z spacing contract.
			if dx>=0.60 and dx<=1.35:
				return [left,right]
	return []

func pair(world, actor: Dictionary, partner: Dictionary, room: Dictionary) -> Dictionary:
	if room.is_empty() or room.get("privacy","public") != "public" or not world.is_accessible(room,str(actor.get("id",""))) or not world.is_accessible(room,str(partner.get("id",""))):
		return {}
	var used: Dictionary=used_slots(world,str(room["id"]),[str(actor["id"]),str(partner["id"])])
	var points: Array=layout_for_world(world,room)
	var indexes: Array=_paired_spots(points,used,true)
	if indexes.is_empty():
		indexes=_paired_spots(points,used,false)
	if indexes.size()!=2:
		return {}
	return {"actor":_claim(room,int(indexes[0]),points[int(indexes[0])]),
		"partner":_claim(room,int(indexes[1]),points[int(indexes[1])])}

func can_reserve(world, room: Dictionary, pair_needed: bool = false) -> bool:
	if available_count(world,room)<(2 if pair_needed else 1):
		return false
	if not pair_needed:
		return true
	return not _paired_spots(layout_for_world(world,room),used_slots(world,str(room["id"]))).is_empty()

func commit_claim(actor: Dictionary, claim: Dictionary) -> void:
	if claim.is_empty():
		return
	actor["station_room_id"] = claim["room_id"]
	actor["station_slot"] = claim["slot"]
	var offset: Vector2 = claim["offset"]
	actor["station_point"] = [offset.x,offset.y]
	actor["station_kind"] = str(claim.get("kind","standing"))
	actor["station_furniture_id"] = str(claim.get("furniture_id",""))
	actor["station_anchor_id"] = str(claim.get("anchor_id",""))
	actor["station_pose_hint"] = str(claim.get("pose_hint","IDLE_S"))
	actor["station_approach_z"] = float(claim.get("approach_z",0.95))

func release(actor: Dictionary) -> void:
	actor.erase("station_room_id")
	actor.erase("station_slot")
	actor.erase("station_point")
	actor.erase("station_kind")
	actor.erase("station_furniture_id")
	actor.erase("station_anchor_id")
	actor.erase("station_pose_hint")
	actor.erase("station_approach_z")

func reconcile(world) -> int:
	# Restore station invariants after loading a snapshot, without new life.
	# Prefer the lexicographically first existing claim if an old save has
	# duplicates; later actors replan normally instead of overlapping.
	var claimed: Dictionary = {}
	var fixed := 0
	var ordered: Array = world.residents.keys()
	ordered.sort()
	for id in ordered:
		var actor: Dictionary = world.residents[id]
		var room_id: String = str(actor.get("station_room_id",""))
		var slot: int = int(actor.get("station_slot",-1))
		if room_id == "" and slot == -1:
			continue
		var room: Dictionary = world.room_by_id(room_id)
		var authored: Array = layout_for_world(world,room) if not room.is_empty() else []
		var stable_id: String=str(actor.get("station_anchor_id",""))
		if stable_id!="":
			slot = -1
			for index in range(authored.size()):
				if str(authored[index].get("id",""))==stable_id:
					slot=index
					break
			if slot>=0:
				actor["station_slot"]=slot
		var key: String = "%s:%d" % [room_id,slot]
		var invalid: bool = not bool(actor.get("active",false)) or room.is_empty() or (
			not world.is_accessible(room,str(id))) or slot < 0 or slot >= capacity(room) or (
			not ["travel","perform"].has(str(actor.get("phase","idle")))) or claimed.has(key)
		if not invalid and str(actor.get("phase",""))=="travel":
			var route: Array=actor.get("waypoints",[])
			invalid = route.is_empty() or typeof(route[-1])!=TYPE_DICTIONARY or (
				str(route[-1].get("kind",""))!="station") or (
				str(route[-1].get("room_id",""))!=room_id)
		if invalid:
			release(actor)
			# Old/corrupt reservations cannot continue a phantom activity
			# while another resident legitimately claims their former seat.
			actor["phase"] = "idle"
			actor["waypoints"] = []
			actor["waypoint_index"] = 0
			actor["until"] = world.sim_clock
			fixed += 1
		else:
			claimed[key] = true
			# v0.7 stored generic coordinates and the SAME slot IDs. Rewrite
			# the actor's true body location/terminal waypoint, not just the
			# station metadata, or old saves still visually stack on furniture.
			var spot: Dictionary = authored[slot]
			actor["station_kind"] = str(spot.get("kind","standing"))
			actor["station_furniture_id"] = str(spot.get("furniture_id",""))
			actor["station_anchor_id"] = str(spot.get("id",""))
			actor["station_pose_hint"] = str(spot.get("pose_hint","IDLE_S"))
			actor["station_approach_z"] = float(spot.get("approach_z",0.95))
			var offset: Vector2 = spot["offset"]
			actor["station_point"] = [offset.x,offset.y]
			var room_center:Vector3=world.room_center_pos(room)
			var new_x:float=room_center.x+offset.x
			var new_y:float=room_center.y
			if str(actor.get("phase",""))=="perform":
				actor["x"]=new_x
				actor["visual_y"]=new_y
				actor["z"]=offset.y
			else:
				var route: Array=actor["waypoints"]
				var last: Dictionary=route[-1]
				last["position"]=[new_x,new_y,offset.y]
				route[route.size()-1]=last
				actor["waypoints"]=route
	return fixed

func migrate_legacy_positions(world) -> int:
	# v0.6 and older snapshots have positions and paths but no reserved seats.
	# Reconcile immediately at load, before the first render, rather than
	# waiting for the next autonomous task and showing stacked actors for 40s.
	var changed := 0
	var sorted_ids: Array = world.residents.keys()
	sorted_ids.sort()
	for id in sorted_ids:
		var actor: Dictionary=world.residents[id]
		if not bool(actor.get("active",false)) or actor.has("station_slot"):
			continue
		var phase: String=str(actor.get("phase","idle"))
		if not phase in ["travel","perform"]:
			continue
		var room: Dictionary={}
		var waypoint: Dictionary={}
		if phase=="travel":
			var route: Array=actor.get("waypoints",[])
			if route.is_empty() or typeof(route[-1])!=TYPE_DICTIONARY:
				continue
			waypoint = route[-1]
			if str(waypoint.get("kind",""))!="station":
				continue
			room=world.room_by_id(str(waypoint.get("room_id","")))
		else:
			room=world.room_by_id(str(actor.get("room_id","")))
		if room.is_empty() or room.get("privacy","public")!="public":
			continue
		var claim: Dictionary=single(world,actor,room,str(actor.get("intent","")))
		if claim.is_empty():
			# An overfilled legacy room has no vacant station. Pause/replan,
			# rather than leaving two people at the same destination.
			actor["phase"]="idle"
			actor["until"]=world.sim_clock
			actor["waypoints"]=[]
			actor["waypoint_index"]=0
			changed+=1
			continue
		commit_claim(actor,claim)
		var offset: Vector2=claim["offset"]
		if phase=="travel":
			var points: Array=actor["waypoints"]
			var last: Dictionary=points[-1]
			var center:Vector3=world.room_center_pos(room)
			last["position"]=[center.x+offset.x,center.y,offset.y]
			points[points.size()-1]=last
			actor["waypoints"]=points
		else:
			var center:Vector3=world.room_center_pos(room)
			actor["x"]=center.x+offset.x
			actor["z"]=offset.y
			actor["visual_y"]=center.y
		changed+=1
	return changed
