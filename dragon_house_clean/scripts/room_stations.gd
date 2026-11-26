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
var candidate_navigation=null
# Read-only memoization scoped to exactly one planner decision. Never reused
# across reservation commits, object moves, door changes or room construction.
var planning_snapshot:=false
var planning_layouts:Dictionary={}
var planning_occupancy:Dictionary={}

func begin_planning_snapshot()->void:
	planning_snapshot=true
	planning_layouts.clear()
	planning_occupancy.clear()

func end_planning_snapshot()->void:
	planning_snapshot=false
	planning_layouts.clear()
	planning_occupancy.clear()

func _init() -> void:
	var selected := REVIEW_FURNITURE if FileAccess.file_exists(REVIEW_MARKER) else InteractionAnchors.DEFAULT_PATH
	if not furniture.initialize(selected):
		push_warning("Interaction anchor manifest unavailable: "+furniture.last_error)
		if selected != InteractionAnchors.DEFAULT_PATH:
			furniture.initialize(InteractionAnchors.DEFAULT_PATH)

func _owned_hidden_room(room:Dictionary)->bool:
	return str(room.get("type",""))=="private" and str(room.get("architecture_revision","")).begins_with("CANONICAL_HOUSE_") and str(room.get("owner_id",""))!=""

func _private_layout()->Array:
	# Logical bed/rest station. Never instantiated as visible room art.
	return [{"id":"PRIVATE_HOME_REST","offset":Vector2(0,-0.90),"kind":"floor_rest","furniture_id":"PRIVATE_HOME","pose_hint":"IDLE_S","approach_z":1.5}]

func capacity(room: Dictionary) -> int:
	if _owned_hidden_room(room):return 1
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
	if _owned_hidden_room(room):return _private_layout()
	if room.is_empty() or str(room.get("privacy","public"))!="public":
		return []
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		return candidate_navigation.candidate_spots(room)
	return _layout_from_anchors(room,_physical_anchor_data(room))

func _display_anchor_data(world, room: Dictionary) -> Array:
	var result:Array=[]
	var seen:Dictionary={}
	for object_id in world.objects:
		var object:Dictionary=world.objects[object_id]
		if str(object.get("current_room_id",""))!=str(room.get("id","")) or str(object.get("state",""))!="PLACED":
			continue
		var station_id:String=str(object.get("interaction_station_id",""))
		var point=object.get("interaction_point",[])
		if station_id=="" or seen.has(station_id) or typeof(point)!=TYPE_ARRAY or point.size()<2:
			continue
		seen[station_id]=true
		result.append({
			"id":station_id,
			"x":float(point[0]),"z":float(point[1]),
			"kind":"standing","furniture_id":"DISPLAY_WALL",
			"pose_hint":"VIEW",
			"approach_z":float(object.get("interaction_approach_z",0.95))
		})
	return result

func layout_for_world(world, room: Dictionary) -> Array:
	if world.canonical_house_seed and _owned_hidden_room(room):return _private_layout()
	if room.is_empty() or str(room.get("privacy","public"))!="public":
		return []
	var rid:String=str(room.get("id",""))
	if planning_snapshot and planning_layouts.has(rid):
		return planning_layouts[rid]
	var anchors:Array=_display_anchor_data(world,room)
	var result:Array=[]
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		result=candidate_navigation.candidate_spots(room,anchors)
	else:
		anchors.append_array(_physical_anchor_data(room))
		result=_layout_from_anchors(room,anchors)
	if planning_snapshot:
		planning_layouts[rid]=result
	return result

func display_objects(world, room: Dictionary) -> Array:
	var result:Array=[]
	for object_id in world.objects:
		var object:Dictionary=world.objects[object_id]
		if str(object.get("current_room_id",""))!=str(room.get("id","")) or str(object.get("state",""))!="PLACED":
			continue
		if str(object.get("display_mode",""))!="wall" or str(object.get("interaction_station_id",""))=="":
			continue
		result.append(object)
	result.sort_custom(func(a,b): return str(a.get("id",""))<str(b.get("id","")))
	return result

func display_claim(world, actor: Dictionary, room: Dictionary,
		object: Dictionary) -> Dictionary:
	var station_id:String=str(object.get("interaction_station_id",""))
	if station_id=="":
		return {}
	var id:String=str(actor.get("id",""))
	if not world.is_accessible(room,id):
		return {}
	var used:Dictionary=used_slots(world,str(room["id"]),[id])
	var points:Array=layout_for_world(world,room)
	for idx in range(points.size()):
		if used.has(idx):
			continue
		if str(points[idx].get("id",""))==station_id:
			return _claim(room,idx,points[idx])
	return {}

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
	var cache_key:String=room_id+"|"+str(ignore_ids)
	if planning_snapshot and planning_occupancy.has(cache_key):
		return planning_occupancy[cache_key]
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
				if bool(actor.get("station_exclusive_furniture",false)):
					var room:Dictionary=world.room_by_id(room_id)
					var spots:Array=layout_for_world(world,room)
					for idx in range(spots.size()):
						if str(spots[idx].get("furniture_id",""))==str(actor.get("station_furniture_id","")):
							used[idx]=id
	if planning_snapshot:
		planning_occupancy[cache_key]=used
	return used

func available_count(world, room: Dictionary) -> int:
	if world.canonical_house_seed and _owned_hidden_room(room):
		return maxi(0,1-used_slots(world,str(room["id"])).size())
	if room.is_empty() or room.get("privacy","public") != "public":
		return 0
	var slots:int=capacity(room)
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		slots=layout_for_world(world,room).size()
	return maxi(0,slots-used_slots(world,str(room["id"])).size())

func _claim(room: Dictionary, index: int, spot: Dictionary) -> Dictionary:
	return {"room_id":str(room["id"]),"slot":index,
		"offset":spot["offset"],"kind":str(spot.get("kind","standing")),
		"furniture_id":str(spot.get("furniture_id","")),
		"anchor_id":str(spot.get("id","")),
		"pose_hint":str(spot.get("pose_hint","IDLE_S")),
		"approach_z":float(spot.get("approach_z",0.95))}

func single(world, actor: Dictionary, room: Dictionary, intent: String = "") -> Dictionary:
	var id: String = str(actor.get("id",""))
	if world.canonical_house_seed and _owned_hidden_room(room):
		if not world.is_accessible(room,id) or not intent in ["REST","SLEEP"]:return {}
		if not used_slots(world,str(room["id"]),[id]).is_empty():return {}
		return _claim(room,0,_private_layout()[0])
	if room.is_empty() or room.get("privacy","public") != "public" or not world.is_accessible(room,id) or capacity(room)==0:
		return {}
	var used: Dictionary = used_slots(world,str(room["id"]),[id])
	var points: Array = layout_for_world(world,room)
	if points.is_empty():
		return {}
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		return _candidate_single(world,actor,room,intent,points,used)
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

func social_pair_geometry(room:Dictionary,positions:Array)->bool:
	if positions.size()!=2:return false
	var a:Vector2=positions[0]
	var b:Vector2=positions[1]
	if not a.is_finite() or not b.is_finite():return false
	var distance:float=a.distance_to(b)
	if distance<0.65 or distance>2.2:return false
	return candidate_navigation==null or not candidate_navigation.has_layout(room) or candidate_navigation.segment_clear(room,a,b)

func pair(world, actor: Dictionary, partner: Dictionary, room: Dictionary) -> Dictionary:
	if room.is_empty() or room.get("privacy","public") != "public" or not world.is_accessible(room,str(actor.get("id",""))) or not world.is_accessible(room,str(partner.get("id",""))):
		return {}
	var used: Dictionary=used_slots(world,str(room["id"]),[str(actor["id"]),str(partner["id"])])
	var points: Array=layout_for_world(world,room)
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		# Facing inward with existing directional standing art is physically
		# honest; do not turn a front-facing calibrated seated sprite.
		for i in range(points.size()-1):
			if used.has(i) or str(points[i].get("kind",""))!="standing" or str(points[i].get("furniture_id",""))!="":continue
			for j in range(i+1,points.size()):
				if used.has(j) or str(points[j].get("kind",""))!="standing" or str(points[j].get("furniture_id",""))!="":continue
				if social_pair_geometry(room,[points[i]["offset"],points[j]["offset"]]):
					return {"actor":_claim(room,i,points[i]),"partner":_claim(room,j,points[j])}
		return {}
	var indexes: Array=_paired_spots(points,used,true)
	if indexes.is_empty():
		indexes=_paired_spots(points,used,false)
	if indexes.size()!=2:
		return {}
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		var first:Dictionary=_candidate_claim(actor,room,int(indexes[0]),points[int(indexes[0])],"TALK_PAIR")
		var second:Dictionary=_candidate_claim(partner,room,int(indexes[1]),points[int(indexes[1])],"TALK_PAIR")
		if first.has("contact")!=second.has("contact"):
			first=_claim(room,int(indexes[0]),points[int(indexes[0])])
			second=_claim(room,int(indexes[1]),points[int(indexes[1])])
			first["kind"]="standing"
			second["kind"]="standing"
		return {"actor":first,"partner":second}
	return {"actor":_claim(room,int(indexes[0]),points[int(indexes[0])]),
		"partner":_claim(room,int(indexes[1]),points[int(indexes[1])])}

# A group uses only existing unobstructed standing stations. No virtual seats.
func group_geometry(room:Dictionary,positions:Array)->bool:
	if positions.size()<3 or positions.size()>6:return false
	var center:=Vector2.ZERO
	for point in positions:
		center+=point
	center/=float(positions.size())
	var angles:Array=[]
	for i in range(positions.size()):
		var p:Vector2=positions[i]
		# Keep the physical front connector aisle at z=1.50 free of gatherings.
		if candidate_navigation!=null and candidate_navigation.has_layout(room) and p.y>0.75:return false
		var v:Vector2=p-center
		if v.length()<0.25 or v.length()>2.0:return false
		angles.append(v.angle())
		for j in range(i):
			var q:Vector2=positions[j]
			if p.distance_to(q)<0.65 or p.distance_to(q)>3.6:return false
			if candidate_navigation!=null and candidate_navigation.has_layout(room) and not candidate_navigation.segment_clear(room,p,q):return false
	angles.sort()
	for i in range(angles.size()):
		var gap:float=float(angles[(i+1)%angles.size()])-float(angles[i])
		if i==angles.size()-1:gap+=TAU
		if gap>=PI-0.05:return false
	return true

func group_claims(world,actors:Array,room:Dictionary)->Dictionary:
	if actors.size()<3 or actors.size()>6 or room.is_empty() or str(room.get("privacy",""))!="public":return {}
	var ids:Array=[]
	for actor in actors:
		var id:String=str(actor.get("id",""))
		if id=="" or ids.has(id) or not world.is_accessible(room,id):return {}
		ids.append(id)
	var used:Dictionary=used_slots(world,str(room["id"]),ids)
	var points:Array=layout_for_world(world,room)
	var selected:Array=_group_indexes(room,points,used,actors.size())
	if selected.size()!=actors.size():return {}
	var claims:Dictionary={}
	for i in range(ids.size()):
		var ix:int=int(selected[i])
		claims[ids[i]]=_claim(room,ix,points[ix])
	return claims

func can_reserve_group(world,room:Dictionary,actor_id:String="")->bool:
	if room.is_empty() or str(room.get("privacy",""))!="public":return false
	var points:Array=layout_for_world(world,room)
	var used:Dictionary=used_slots(world,str(room["id"]),[actor_id])
	return _group_indexes(room,points,used,3).size()==3

func _group_indexes(room:Dictionary,points:Array,used:Dictionary,count:int)->Array:
	var available:Array=[]
	for i in range(mini(points.size(),capacity(room))):
		var spot:Dictionary=points[i]
		if not used.has(i) and str(spot.get("kind",""))=="standing" and str(spot.get("furniture_id",""))=="":available.append(i)
	if available.size()<count:return []
	for a in range(available.size()-2):
		for b in range(a+1,available.size()-1):
			for c in range(b+1,available.size()):
				var selected:Array=[available[a],available[b],available[c]]
				var pos:Array=[points[selected[0]]["offset"],points[selected[1]]["offset"],points[selected[2]]["offset"]]
				if not group_geometry(room,pos):continue
				for index in available:
					if selected.size()>=count:break
					if selected.has(index):continue
					var trial:Array=pos.duplicate()
					trial.append(points[index]["offset"])
					if group_geometry(room,trial):
						selected.append(index)
						pos=trial
				if selected.size()==count:return selected
	return []

# Extend an existing circle without moving any of its members.
func group_join_claim(world,actor:Dictionary,room:Dictionary,positions:Array)->Dictionary:
	if positions.size()<3 or positions.size()>=6 or not world.is_accessible(room,str(actor.get("id",""))):return {}
	var used:Dictionary=used_slots(world,str(room["id"]),[str(actor["id"])])
	var points:Array=layout_for_world(world,room)
	var at:Vector2=world.room_world_to_local(room,Vector3(float(actor.get("x",0)),float(actor.get("visual_y",0)),float(actor.get("z",0))))
	var best:Dictionary={}
	var nearest:float=INF
	for i in range(mini(points.size(),capacity(room))):
		var spot:Dictionary=points[i]
		if used.has(i) or str(spot.get("kind",""))!="standing" or str(spot.get("furniture_id",""))!="":continue
		var trial:Array=positions.duplicate()
		trial.append(spot["offset"])
		if not group_geometry(room,trial):continue
		var distance:float=at.distance_to(spot["offset"])
		if distance<nearest:
			best=_claim(room,i,spot)
			nearest=distance
	return best

func can_reserve(world, room: Dictionary, pair_needed: bool = false) -> bool:
	if available_count(world,room)<(2 if pair_needed else 1):
		return false
	if not pair_needed:
		return true
	var points:Array=layout_for_world(world,room)
	var used:Dictionary=used_slots(world,str(room["id"]))
	if candidate_navigation!=null and candidate_navigation.has_layout(room):
		for i in range(points.size()-1):
			if used.has(i) or str(points[i].get("kind",""))!="standing" or str(points[i].get("furniture_id",""))!="":continue
			for j in range(i+1,points.size()):
				if used.has(j) or str(points[j].get("kind",""))!="standing" or str(points[j].get("furniture_id",""))!="":continue
				if social_pair_geometry(room,[points[i]["offset"],points[j]["offset"]]):return true
		return false
	return not _paired_spots(points,used).is_empty()

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
	actor.erase("station_contact")
	actor.erase("station_exclusive_furniture")
	if claim.has("contact"):
		actor["station_contact"]=claim["contact"].duplicate(true)
		actor["station_exclusive_furniture"]=bool(claim["contact"].get("exclusive",false))

func release(actor: Dictionary) -> void:
	actor.erase("station_room_id")
	actor.erase("station_slot")
	actor.erase("station_point")
	actor.erase("station_kind")
	actor.erase("station_furniture_id")
	actor.erase("station_anchor_id")
	actor.erase("station_pose_hint")
	actor.erase("station_approach_z")
	actor.erase("station_contact")
	actor.erase("station_exclusive_furniture")

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
			not world.is_accessible(room,str(id))) or slot < 0 or slot >= authored.size() or (
			not ["travel","perform"].has(str(actor.get("phase","idle")))) or claimed.has(key)
		if not invalid and str(actor.get("phase",""))=="travel":
			var route: Array=actor.get("waypoints",[])
			invalid = route.is_empty() or typeof(route[-1])!=TYPE_DICTIONARY or (
				str(route[-1].get("kind",""))!="station") or (
				str(route[-1].get("room_id",""))!=room_id)
		var restored_claim:Dictionary={}
		if not invalid and candidate_navigation!=null and candidate_navigation.has_layout(room):
			var prior:Array=actor.get("station_point",[])
			var spot:Dictionary=authored[slot]
			var offset:Vector2=spot["offset"]
			restored_claim=_candidate_claim(actor,room,slot,spot,str(actor.get("intent","")))
			invalid=restored_claim.is_empty() or prior.size()!=2 or offset.distance_to(Vector2(float(prior[0]),float(prior[1])))>0.01
		if invalid:
			release(actor)
			# A rider between floors must drain the current physical lift leg.
			var waypoints:Array=actor.get("waypoints",[])
			var waypoint_index:int=int(actor.get("waypoint_index",0))
			var y:float=float(actor.get("visual_y",0))
			if world.canonical_house_seed and str(actor.get("phase",""))=="travel" and waypoint_index>=0 and waypoint_index<waypoints.size() and str(waypoints[waypoint_index].get("kind",""))=="lift" and absf(y-roundf(y/world.FLOOR_H)*world.FLOOR_H)>0.035:
				actor["station_replan_lift_pending"]=true
				fixed+=1
				continue
			# Old/corrupt reservations cannot continue a phantom activity
			# while another resident legitimately claims their former seat.
			actor["phase"] = "idle"
			actor["waypoints"] = []
			actor["waypoint_index"] = 0
			actor["until"] = world.sim_clock
			fixed += 1
		else:
			claimed[key] = true
			if not restored_claim.is_empty():
				commit_claim(actor,restored_claim)
				continue
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
		if not bool(actor.get("active",false)) or actor.has("station_slot") or actor.has("station_replan_lift_pending"):
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

func _candidate_claim(actor:Dictionary,room:Dictionary,index:int,spot:Dictionary,intent:String)->Dictionary:
	var claim:Dictionary=_claim(room,index,spot)
	var kind:String=str(spot.get("kind","standing"))
	if intent=="GET_COFFEE":
		if str(spot.get("cup_slot_id",""))=="":
			return {}
		claim["kind"]="standing"
		claim["pose_hint"]="IDLE_S"
		return claim
	if intent in ["FETCH_BOOK","RETURN_BOOK"]:
		if kind!="standing":return {}
		var compatible:bool=false
		for support in candidate_navigation.book_slots(room):
			if str(support.get("station_id",""))==str(spot.get("id","")):
				compatible=true
				break
		if not compatible:return {}
		claim["pose_hint"]="VIEW"
		return claim
	if intent in ["REST","SLEEP","READ_BOOK","TALK_PAIR","LISTEN_MUSIC"]:
		var contact:Dictionary={}
		if intent=="SLEEP" or kind=="seat" or (intent=="REST" and kind=="floor_rest"):
			contact=candidate_navigation.pose_contact(actor,spot,intent)
		if not contact.is_empty():
			claim["contact"]=contact
			claim["kind"]="floor_rest" if str(contact["state"])=="LIE_SIDE_CURLED" else "seat"
			claim["pose_hint"]=str(contact["state"])
			return claim
		if intent in ["REST","SLEEP","READ_BOOK"]:
			return {}
	if intent=="WATCH_FILM":
		if str(spot.get("candidate_kind",""))!="seat":
			return {}
		claim["pose_hint"]="IDLE_N"
	elif intent=="WORK_CREATE" and kind!="work":
		return {}

	elif intent=="VIEW_ART" and str(spot.get("furniture_id",""))=="":
		return {}
	if kind in ["seat","floor_rest"]:
		claim["kind"]="standing"
		claim["pose_hint"]="IDLE_S"
	return claim

func _candidate_single(world,actor:Dictionary,room:Dictionary,intent:String,points:Array,used:Dictionary)->Dictionary:
	var start:=0
	for ch in str(actor.get("id","")):
		start=posmod(start*31+ch.unicode_at(0),997)
	var fallback:Dictionary={}
	for step in range(points.size()):
		var idx:int=(start+step)%points.size()
		if used.has(idx):
			continue
		var spot:Dictionary=points[idx]
		var claim:=_candidate_claim(actor,room,idx,spot,intent)
		if claim.is_empty():
			continue
		if bool(claim.get("contact",{}).get("exclusive",false)):
			var blocked:=false
			for other in used:
				if int(other)<points.size() and str(points[int(other)].get("furniture_id",""))==str(spot.get("furniture_id","")):
					blocked=true
					break
			if blocked:
				continue
		if claim.has("contact") or intent in ["WORK_CREATE","WATCH_FILM"]:
			return claim
		if fallback.is_empty():
			fallback=claim
	return fallback

func cup_claim(world,actor:Dictionary,room:Dictionary,slot_id:String)->Dictionary:
	if not world.is_accessible(room,str(actor["id"])):
		return {}
	var used:Dictionary=used_slots(world,str(room["id"]),[str(actor["id"])])
	var points:Array=layout_for_world(world,room)
	for index in range(points.size()):
		if not used.has(index) and str(points[index].get("cup_slot_id",""))==slot_id:
			return _candidate_claim(actor,room,index,points[index],"GET_COFFEE")
	return {}

func book_shelf_claim(world,actor:Dictionary,room:Dictionary,intent:String,station_id:String)->Dictionary:
	if station_id=="" or not world.is_accessible(room,str(actor["id"])):
		return {}
	var used:Dictionary=used_slots(world,str(room["id"]),[str(actor["id"])])
	var points:Array=layout_for_world(world,room)
	for index in range(points.size()):
		if not used.has(index) and str(points[index].get("id",""))==station_id:
			return _candidate_claim(actor,room,index,points[index],intent)
	return {}
