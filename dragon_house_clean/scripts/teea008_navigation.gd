extends RefCounted
## Candidate-only X/Z navigation. The immutable room graph remains authoritative.
## Conservative 0.65 m diameter proxy; guest body-depth and sprite pose fit are separate gates.
const DEPTH7=preload("res://scripts/depth7_space.gd")
const STEP:=0.10
const RADIUS:=0.325
const BACK:=-1.95
const FRONT:=1.65
const AISLE:=1.50
var layouts:Dictionary={}
var grids:Dictionary={}
var blockers:Dictionary={}
var path_calls:=0
var path_failures:=0
var path_cache:Dictionary={}
var path_cache_order:Array=[]
var path_cache_hits:=0
var social_segment_cache:Dictionary={}
var social_segment_hits:int=0
const SOCIAL_SEGMENT_LIMIT:=4096
const PATH_CACHE_LIMIT:=1024
const POSE_PATH:="res://data/teea008_pose_contacts_review.json"
const CANVAS_HEIGHT:=2.45
var pose_profiles:Dictionary={}
var hand_profiles:Dictionary={}
var cup_hand_profiles:Dictionary={}
var static_spots:Dictionary={}
var display_cache:Dictionary={}
var cup_slot_cache:Dictionary={}
var book_slot_cache:Dictionary={}
var artifact_slot_cache:Dictionary={}

func configure(rows:Dictionary)->void:
	layouts=rows
	grids.clear()
	blockers.clear()
	path_cache.clear()
	path_cache_order.clear()
	path_cache_hits=0
	social_segment_cache.clear()
	social_segment_hits=0
	static_spots.clear()
	display_cache.clear()
	cup_slot_cache.clear()
	book_slot_cache.clear()
	artifact_slot_cache.clear()
	pose_profiles.clear()
	if FileAccess.file_exists(POSE_PATH):
		var f:=FileAccess.open(POSE_PATH,FileAccess.READ)
		var doc=JSON.parse_string(f.get_as_text())
		if typeof(doc)==TYPE_DICTIONARY and not bool(doc.get("owner_approved",true)):
			for id in doc.get("profiles",{}):
				var profile:Dictionary=doc["profiles"][id].duplicate(true)
				for state in profile.get("states",{}).keys():
					var entry:Dictionary=profile["states"][state]
					var path:String="res://"+str(entry.get("path",""))
					if not _pose_source_valid(path,entry):
						profile["states"].erase(state)
				pose_profiles[id]=profile
	hand_profiles.clear()
	cup_hand_profiles.clear()
	var hand_file:=FileAccess.open("res://data/teea008_hand_contacts_review.json",FileAccess.READ)
	if hand_file!=null:
		var hand_doc=JSON.parse_string(hand_file.get_as_text())
		if typeof(hand_doc)==TYPE_DICTIONARY and not bool(hand_doc.get("owner_approved",true)) and str(hand_doc.get("state",""))=="IDLE_S":
			for id in hand_doc.get("profiles",{}):
				var record:Dictionary=hand_doc["profiles"][id]
				var validated:Dictionary=pose_profiles.get(id,{}).get("states",{}).get("IDLE_S",{})
				var point:Array=record.get("hand_px",[])
				var canvas:Array=record.get("canvas",[])
				if not validated.is_empty() and record.get("path","")==validated.get("path","") and record.get("sha256","")==validated.get("sha256","") and canvas==validated.get("canvas",[]) and point.size()==2 and canvas.size()==2 and float(point[0])>=0 and float(point[1])>=0 and float(point[0])<float(canvas[0]) and float(point[1])<float(canvas[1]):
					hand_profiles[id]=record

func install_depth7_pose_intake()->int:
	var f:=FileAccess.open("res://data/asset_proposals/DH_SPRITE_20261126_INTAKE/pose_contacts.json",FileAccess.READ)
	if f==null:return 0
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY:return 0
	var count:=0
	for id in doc.get("profiles",{}):
		var incoming:Dictionary=doc["profiles"][id]
		var existing:Dictionary=pose_profiles.get(id,{})
		if existing.get("wardrobe")!=incoming.get("wardrobe") or existing.get("appearance_profile")!=incoming.get("appearance_profile"):continue
		for state in incoming.get("states",{}):
			var p:Dictionary=incoming["states"][state]
			if _pose_source_valid("res://"+str(p.get("path","")),p):
				existing["states"][state]=p.duplicate(true)
				count+=1
	return count

func install_depth7_cup_hands()->int:
	var f:=FileAccess.open("res://data/asset_proposals/DH_SPRITE_20261126_INTAKE/cup_hand_contacts.json",FileAccess.READ)
	if f==null:return 0
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or doc.get("actor_id")!="RES_07":return 0
	var count:=0
	for state in ["DRINK","CARRY_USE"]:
		var frames:Array=doc.get("states",{}).get(state,[])
		var valid:bool=frames.size()==(4 if state=="DRINK" else 1)
		for record in frames:
			var pt:Array=record.get("hand_px",[])
			var canvas:Array=record.get("canvas",[])
			if not _pose_source_valid("res://"+str(record.get("path","")),record) or pt.size()!=2 or canvas.size()!=2 or int(canvas[0])!=512 or int(canvas[1])!=512 or not Rect2(0,0,512,512).has_point(Vector2(pt[0],pt[1])):
				valid=false;break
		if valid:
			cup_hand_profiles[state]={"appearance_profile":doc["appearance_profile"],"wardrobe":doc["wardrobe"],"frames":frames}
			count+=frames.size()
	return count

func cup_hand_contact(actor:Dictionary,state:String,frame:int)->Dictionary:
	if state=="IDLE_S":return hand_contact(actor,state,frame)
	if actor.get("id")!="RES_07":return {}
	var p:Dictionary=cup_hand_profiles.get(state,{})
	if p.get("appearance_profile")!=actor.get("appearance_profile") or p.get("wardrobe")!=actor.get("visual_wardrobe"):return {}
	var frames:Array=p.get("frames",[])
	if frame<0 or frame>=frames.size():return {}
	return frames[frame]

func hand_contact(actor:Dictionary,state:String,frame:int)->Dictionary:
	if state!="IDLE_S" or frame!=0:return {}
	var record:Dictionary=hand_profiles.get(str(actor.get("id","")),{})
	if str(record.get("appearance_profile",""))!=str(actor.get("appearance_profile","")) or str(record.get("wardrobe",""))!=str(actor.get("visual_wardrobe","")):
		return {}
	return record

func key(room:Dictionary)->String:
	if layouts.has(str(room.get("dense_v2_layout",""))):return str(room["dense_v2_layout"])
	var kind:String=str(room.get("interior_variant",room.get("type","")))
	if kind=="guest":
		kind=str(room.get("candidate_room_id","")).trim_suffix("_01")
	return "%s/R%d" % [kind,int(room.get("size_modules",1))]

func has_layout(room:Dictionary)->bool:
	return layouts.has(key(room))

func _v2(p:Array)->Vector2:
	return Vector2(float(p[0]),float(p[1]))

func _xz(p:Array)->Vector2:
	return Vector2(float(p[0]),float(p[2]))

func _obstacles(room:Dictionary)->Array:
	var k:=key(room)
	if blockers.has(k):
		return blockers[k]
	var out:Array=[]
	var row:Dictionary=layouts.get(k,{})
	var raw:Array=[]
	for item in row.get("instances",[]):
		if str(item.get("placement_policy",""))=="floor_fixed":
			raw.append(item)
	raw.append_array(row.get("preserve_existing_runtime_geometry",[]))
	for item in raw:
		var lo:Vector2=_xz(item["bounds_min_m"])
		var hi:Vector2=_xz(item["bounds_max_m"])
		out.append(Rect2(lo,hi-lo))
	blockers[k]=out
	return out

func _back(room:Dictionary)->float:
	return DEPTH7.BACK if DEPTH7.enabled_for(room) else BACK

func clear(room:Dictionary,p:Vector2)->bool:
	if not has_layout(room):
		return true
	var hw:float=float(room.get("size_modules",1))*2.4
	# The front/side openings connect to adjacent volumes; don't shrink them.
	if absf(p.x)>hw+0.001 or p.y<_back(room)+RADIUS-0.001 or p.y>FRONT+0.001:
		return false
	if DEPTH7.enabled_for(room) and DEPTH7.passage(p.y):return true
	for box:Rect2 in _obstacles(room):
		var near:=Vector2(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y))
		if p.distance_squared_to(near)<RADIUS*RADIUS-0.000001:
			return false
	return true

func _point_box_distance_sq(p:Vector2,box:Rect2)->float:
	var near:=Vector2(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y))
	return p.distance_squared_to(near)

func _segment_box_intersects(a:Vector2,b:Vector2,box:Rect2)->bool:
	# Slab clipping of the segment, not an infinite ray.
	var lo:=0.0
	var hi:=1.0
	var direction:=b-a
	for axis in range(2):
		if absf(direction[axis])<0.000001:
			if a[axis]<box.position[axis] or a[axis]>box.end[axis]:
				return false
			continue
		var t1:float=(box.position[axis]-a[axis])/direction[axis]
		var t2:float=(box.end[axis]-a[axis])/direction[axis]
		lo=maxf(lo,minf(t1,t2))
		hi=minf(hi,maxf(t1,t2))
		if lo>hi:
			return false
	return true

# Only authored standing-station pairs call this. Geometry does not
# depend on current occupancy, and configure() invalidates the cache.
func social_segment_clear(room:Dictionary,a:Vector2,b:Vector2)->bool:
	var left:Vector2=a
	var right:Vector2=b
	if a.x>b.x or (a.x==b.x and a.y>b.y):left=b;right=a
	var cache_key:Array=[key(room),DEPTH7.enabled_for(room),left,right]
	if social_segment_cache.has(cache_key):
		social_segment_hits+=1
		return social_segment_cache[cache_key]
	var result:bool=segment_clear(room,left,right)
	if social_segment_cache.size()>=SOCIAL_SEGMENT_LIMIT:social_segment_cache.clear()
	social_segment_cache[cache_key]=result
	return result

func segment_clear(room:Dictionary,a:Vector2,b:Vector2)->bool:
	if not has_layout(room):
		return true
	var hw:float=float(room.get("size_modules",1))*2.4
	for p in [a,b]:
		if absf(p.x)>hw+0.001 or p.y<_back(room)+RADIUS-0.001 or p.y>FRONT+0.001:
			return false
	if DEPTH7.enabled_for(room):
		# Use the same round body clearance as point navigation, including the
		# explicit exception for furniture on the three passage bands.
		return sampled_segment_clear(room,a,b)
	# Exact segment-to-AABB distance (rounded clearance rather than square
	# expansion). Independent QA still samples the segment at 2.5 cm.
	var sweep:=Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y)),Vector2(absf(a.x-b.x),absf(a.y-b.y))).grow(RADIUS)
	var threshold:float=RADIUS*RADIUS-0.000001
	for box:Rect2 in _obstacles(room):
		if not sweep.intersects(box,true):
			continue
		if _segment_box_intersects(a,b,box):
			return false
		if _point_box_distance_sq(a,box)<threshold or _point_box_distance_sq(b,box)<threshold:
			return false
		for corner in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
			var nearest:Vector2=Geometry2D.get_closest_point_to_segment(corner,a,b)
			if corner.distance_squared_to(nearest)<threshold:
				return false
	return true

func sampled_segment_clear(room:Dictionary,a:Vector2,b:Vector2)->bool:
	# Preserve the exact 2.5cm samples and passage exceptions. Resolve
	# immutable room bounds and broad-phase obstacles ONCE, not per sample.
	if not has_layout(room):return true
	var hw:float=float(room.get("size_modules",1))*2.4
	var min_z:float=_back(room)+RADIUS-0.001
	for p in [a,b]:
		if absf(p.x)>hw+0.001 or p.y<min_z or p.y>FRONT+0.001:return false
	var sweep:=Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y)),Vector2(absf(a.x-b.x),absf(a.y-b.y))).grow(RADIUS+.00001)
	var relevant:Array=[]
	for box:Rect2 in _obstacles(room):
		if sweep.intersects(box,true):relevant.append(box)
	if relevant.is_empty():return true
	var depth7:bool=DEPTH7.enabled_for(room)
	var threshold:float=RADIUS*RADIUS-0.000001
	var steps:int=maxi(1,ceili(a.distance_to(b)/0.025))
	for i in range(steps+1):
		var p:Vector2=a.lerp(b,float(i)/float(steps))
		if depth7 and DEPTH7.passage(p.y):continue
		for box:Rect2 in relevant:
			var near:=Vector2(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y))
			if p.distance_squared_to(near)<threshold:return false
	return true

func _grid(room:Dictionary)->AStarGrid2D:
	var k:=key(room)+"|"+str(DEPTH7.enabled_for(room))
	if grids.has(k):
		return grids[k]
	var hw:float=float(room.get("size_modules",1))*2.4
	var g:=AStarGrid2D.new()
	g.region=Rect2i(0,0,roundi(hw*2.0/STEP)+1,roundi((FRONT-_back(room))/STEP)+1)
	g.cell_size=Vector2(STEP,STEP)
	g.offset=Vector2(-hw,_back(room))
	g.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	g.update()
	for z in range(g.region.size.y):
		for x in range(g.region.size.x):
			var id:=Vector2i(x,z)
			if not clear(room,g.get_point_position(id)):
				g.set_point_solid(id)
	grids[k]=g
	return g

func _near_grid(room:Dictionary,g:AStarGrid2D,p:Vector2)->Vector2i:
	var approx:=Vector2i(roundi((p.x-g.offset.x)/STEP),roundi((p.y-g.offset.y)/STEP))
	var best:=Vector2i(-1,-1)
	var distance:=INF
	for z in range(-3,4):
		for x in range(-3,4):
			var id:=approx+Vector2i(x,z)
			if not g.region.has_point(id) or g.is_point_solid(id):
				continue
			var pt:=g.get_point_position(id)
			var d:=p.distance_squared_to(pt)
			if d<distance and segment_clear(room,p,pt):
				best=id
				distance=d
	return best

func nearest_clear(room:Dictionary,p:Vector2)->Vector2:
	if clear(room,p):
		return p
	if not has_layout(room):
		return p
	var g:=_grid(room)
	var best:=Vector2(p.x,AISLE)
	var distance:=INF
	for z in range(g.region.size.y):
		for x in range(g.region.size.x):
			var id:=Vector2i(x,z)
			if g.is_point_solid(id):
				continue
			var pt:=g.get_point_position(id)
			var d:=pt.distance_squared_to(p)
			if d<distance:
				distance=d
				best=pt
	return best

func path(room:Dictionary,a:Vector2,b:Vector2)->Array:
	path_calls+=1
	var cache_key:String="%s|%s|%.5f,%.5f|%.5f,%.5f" % [key(room),str(DEPTH7.enabled_for(room)),a.x,a.y,b.x,b.y]
	if path_cache.has(cache_key):
		var entry:Dictionary=path_cache[cache_key]
		if a==entry["a"] and b==entry["b"]:
			path_cache_hits+=1
			return entry["points"].duplicate()
	var points:Array=_compute_path(room,a,b)
	if not points.is_empty() and has_layout(room):
		if not path_cache.has(cache_key):
			path_cache_order.append(cache_key)
		path_cache[cache_key]={"a":a,"b":b,"points":points.duplicate()}
		while path_cache_order.size()>PATH_CACHE_LIMIT:
			path_cache.erase(path_cache_order.pop_front())
	return points

func _compute_path(room:Dictionary,a:Vector2,b:Vector2)->Array:
	if not has_layout(room) or segment_clear(room,a,b):
		return [b]
	if not clear(room,a) or not clear(room,b):
		path_failures+=1
		return []
	var g:=_grid(room)
	var start:=_near_grid(room,g,a)
	var end:=_near_grid(room,g,b)
	if start.x<0 or end.x<0:
		path_failures+=1
		return []
	var raw:=g.get_point_path(start,end)
	if raw.is_empty():
		path_failures+=1
		return []
	# Collapse only collinear runs before line-of-sight simplification.
	# Grid adjacency alone is not enough: exact swept-body checks remain.
	var points:Array=[a]
	for i in range(raw.size()):
		if i==0 or i==raw.size()-1:
			points.append(raw[i])
			continue
		var before:Vector2=raw[i]-raw[i-1]
		var after:Vector2=raw[i+1]-raw[i]
		if not before.normalized().is_equal_approx(after.normalized()):
			points.append(raw[i])
	points.append(b)
	var out:Array=[]
	var at:=0
	while at<points.size()-1:
		var next:=points.size()-1
		while next>at and not segment_clear(room,points[at],points[next]):
			next-=1
		if next<=at:
			# A collapsed straight run can meet a rounded obstacle corner
			# between cells; retry the uncompressed exact path before denial.
			return _uncompressed_path(room,a,b,raw)
		out.append(points[next])
		at=next
	return out

func _uncompressed_path(room:Dictionary,a:Vector2,b:Vector2,raw:PackedVector2Array)->Array:
	var points:Array=[a]
	for p in raw:points.append(p)
	points.append(b)
	var out:Array=[]
	var at:=0
	while at<points.size()-1:
		var next:=points.size()-1
		while next>at and not segment_clear(room,points[at],points[next]):
			next-=1
		if next<=at:
			path_failures+=1
			return []
		out.append(points[next])
		at=next
	return out

func candidate_spots(room:Dictionary,display_anchors:Array=[])->Array:
	var variant_key:=key(room)
	if display_anchors.is_empty() and static_spots.has(variant_key):
		return static_spots[variant_key]
	var row:Dictionary=layouts.get(variant_key,{})
	if row.is_empty():
		return []
	var cap:int=int(row.get("station_cap",[0,4,8,16][clampi(int(room.get("size_modules",1)),1,3)]))
	var out:Array=[]
	# Wall display IDs are real world IDs; safe approach is derived without
	# moving the actual object or changing its canonical home.
	for d in display_anchors:
		var p:=Vector2(float(d["x"]),float(d["z"]))
		var cache_key:String="%s:%s:%.3f:%.3f" % [variant_key,str(d["id"]),p.x,p.y]
		if display_cache.has(cache_key):
			p=display_cache[cache_key]
		else:
			p=nearest_clear(room,p)
			if display_cache.size()>256:
				display_cache.clear()
			display_cache[cache_key]=p
		if segment_clear(room,p,p) and absf(p.x)<float(room["size_modules"])*2.4-0.18:
			_add_spot(out,{"id":d["id"],"offset":p,"kind":"standing","furniture_id":"DISPLAY_WALL","pose_hint":"VIEW","approach_z":p.y},cap,0.60)
	if row.has("service_cups"):
		for slot in cup_slots(room):
			var p:Vector2=slot.approach
			_add_spot(out,{"id":slot.id,"offset":p,"kind":"standing","furniture_id":slot.furniture_id,"pose_hint":"IDLE_S","approach_z":p.y,"cup_slot_id":slot.id},cap,0.60)
	for item in row.get("instances",[]):
		for station in item.get("station_candidates",[]):
			var raw:Array=station.get("room_approach_xz",[])
			var kind:String=str(station.get("kind",""))
			if raw.size()!=2:
				# Fur mats have a measured rest surface, not an authored approach.
				# Explicitly derive a safe path to its center; no seated pose inferred.
				if kind!="floor_rest" or station.get("room_local_xyz",[]).size()!=3:
					continue
				var at:=_xz(station["room_local_xyz"])
				raw=[at.x,at.y]
			var p:=_v2(raw)
			if not clear(room,p):
				if bool(row.get("depth7_measured",false)):p=nearest_clear(room,p)
				else:continue
			var spot:Dictionary={"id":str(station["station_candidate_id"]),"offset":p,"kind":"standing","furniture_id":str(item["instance_id"]),"pose_hint":"IDLE_S","approach_z":p.y,"candidate_kind":kind,"candidate_asset_id":str(item["asset_id"]),"candidate_supports":item.get("support_slots",[])}
			if kind=="standing":
				spot["pose_hint"]="VIEW"
				if str(room.get("type","")) in ["study","workshop"]:
					spot["kind"]="work"
					spot["pose_hint"]="USE"
			elif kind=="seat":
				spot["candidate_contact"]={"pelvis":station.get("room_pelvis_contact_xyz",[]),"feet":station.get("room_feet_contact_xyz",[]),"facing":station.get("room_facing_xyz",[]),"instance_xyz":item["room_local_xyz"],"width_m":station.get("seating_width_m",0.0),"front_z":float(item["bounds_max_m"][2]),"depth7_measured":bool(row.get("depth7_measured",false))}
				var facing:Array=spot["candidate_contact"]["facing"]
				if facing.size()==3 and (DEPTH7.enabled_for(room) or float(facing[2])>0.5 or (str(item.get("asset_id",""))=="owner_theatre_seat_pair" and float(facing[0])>.9)):
					spot["kind"]="seat"
					spot["pose_hint"]="RELAXED_SIT"
				if str(item.get("asset_id",""))=="vintage_day_bed":
					var lo:Array=item["bounds_min_m"]
					var hi:Array=item["bounds_max_m"]
					var pelvis:Array=spot["candidate_contact"]["pelvis"]
					spot["candidate_contact"]["lie_surface"]=[(float(lo[0])+float(hi[0]))*0.5,float(pelvis[1]),float(pelvis[2])]
					spot["candidate_contact"]["lie_width_m"]=float(hi[0])-float(lo[0])
			elif kind=="floor_rest":
				var lo:Array=item["bounds_min_m"]
				var hi:Array=item["bounds_max_m"]
				spot["candidate_contact"]={"floor":station.get("room_local_xyz",[]),"instance_xyz":item["room_local_xyz"],"lie_width_m":float(hi[0])-float(lo[0]),"depth7_measured":bool(row.get("depth7_measured",false))}
				spot["kind"]="floor_rest"
				spot["pose_hint"]="LIE_SIDE_CURLED"
			if bool(row.get("depth7_measured",false)) and kind=="seat":
				if out.size()<cap:out.append(spot)
			else:_add_spot(out,spot,cap,0.60)
	for slot in cup_slots(room):
		var p:Vector2=slot["approach"]
		_add_spot(out,{"id":slot["id"],"offset":p,"kind":"standing","furniture_id":slot["furniture_id"],"pose_hint":"IDLE_S","approach_z":p.y,"cup_slot_id":slot["id"]},cap,0.60)
	# Standing positions must themselves be clear and reachable from the aisle.
	var width:int=int(room.get("size_modules",1))
	# Preserve all authored furniture approaches. Fill remaining capacity with
	# a measured clear conversational cluster before ordinary standing slots.
	if str(room.get("type","")) in ["common","rest","kitchen"] and cap-out.size()>=3:
		var free:Array=[]
		for z in [0.75,0.05,-0.65,-1.35]:
			for module in range(width):
				for xx in [-1.55,-0.52,0.52,1.55]:
					var p:=Vector2((float(module)-(float(width)-1.0)*0.5)*4.8+float(xx),float(z))
					if not clear(room,p):continue
					if out.any(func(spot):return p.distance_to(spot["offset"])<0.73):continue
					free.append(p)
		# Hearth has narrow gaps between fixed furniture; sample them more
		# closely without adding extra stations or encroaching on the aisle.
		if str(room.get("type",""))=="common" and width==3:
			for zi in range(-6,4):
				for xi in range(-13,14):
					var p:=Vector2(float(xi)*0.5,float(zi)*0.25)
					if not clear(room,p) or out.any(func(spot):return p.distance_to(spot["offset"])<0.73):continue
					if not free.has(p):free.append(p)
		for p in _social_cluster(room,free,mini(6,cap-out.size())):
			var module:int=clampi(floori((p.x+float(width)*2.4)/4.8),0,width-1)
			_add_spot(out,{"id":"teea008_stand_%d_%d_%d" % [module,roundi(p.x*100),roundi(p.y*100)],"offset":p,"kind":"standing","furniture_id":"","pose_hint":"IDLE_S","approach_z":p.y},cap,0.73)
	for z in [0.75,0.05,-0.65,-1.35,1.25]:
		for module in range(width):
			for xx in [-1.55,-0.52,0.52,1.55]:
				var p:=Vector2((float(module)-(float(width)-1.0)*0.5)*4.8+float(xx),float(z))
				if not clear(room,p):
					continue
				_add_spot(out,{"id":"teea008_stand_%d_%d_%d" % [module,roundi(p.x*100),roundi(p.y*100)],"offset":p,"kind":"standing","furniture_id":"","pose_hint":"IDLE_S","approach_z":p.y},cap,0.73)
	if display_anchors.is_empty():
		static_spots[variant_key]=out
	return out

# Build a compact clique from the sampled floor, using the same clearance
# rules as group_geometry. Bounded grid, at most 48 points in R3.
func _social_cluster(room:Dictionary,points:Array,limit:int)->Array:
	var linked:Dictionary={}
	for i in range(points.size()):
		linked[i]={}
		for j in range(i):
			var d:float=points[i].distance_to(points[j])
			if d>=0.73 and d<=3.6 and segment_clear(room,points[i],points[j]):
				linked[i][j]=true
				linked[j][i]=true
	var best:Array=[]
	for a in range(points.size()):
		for b in linked[a]:
			if b<=a:continue
			for c in linked[b]:
				if c<=b or not linked[a].has(c):continue
				var chosen:Array=[a,b,c]
				if not _social_ring(points,chosen):continue
				for d in range(points.size()):
					if chosen.size()>=limit:break
					if chosen.has(d) or not chosen.all(func(i):return linked[d].has(i)):continue
					var trial:Array=chosen+[d]
					if _social_ring(points,trial):chosen=trial
				if chosen.size()>best.size():
					best=chosen.map(func(i):return points[i])
					if best.size()>=limit:return best
	return best

func _social_ring(points:Array,indices:Array)->bool:
	var center:=Vector2.ZERO
	for i in indices:center+=points[i]
	center/=float(indices.size())
	var angles:Array=[]
	for i in indices:
		var v:Vector2=points[i]-center
		if v.length()<0.25 or v.length()>2.0:return false
		angles.append(v.angle())
	angles.sort()
	for i in range(angles.size()):
		var gap:float=float(angles[(i+1)%angles.size()])-float(angles[i])
		if i==angles.size()-1:gap+=TAU
		if gap>=PI-0.05:return false
	return true

func _add_spot(out:Array,spot:Dictionary,cap:int,gap:float)->void:
	if out.size()>=cap:
		return
	for previous in out:
		if (previous["offset"] as Vector2).distance_to(spot["offset"])<gap:
			return
	out.append(spot)

func pose_profile(actor:Dictionary,state:String)->Dictionary:
	var profile:Dictionary=pose_profiles.get(str(actor.get("id","")),{})
	if str(profile.get("appearance_profile",""))!=str(actor.get("appearance_profile","")) or str(profile.get("wardrobe",""))!=str(actor.get("teea008_pose_wardrobe","")):
		return {}
	return profile.get("states",{}).get(state,{})

func pose_contact(actor:Dictionary,spot:Dictionary,intent:String,view_yaw:float=0.0)->Dictionary:
	var raw:Dictionary=spot.get("candidate_contact",{})
	if raw.is_empty():
		return {}
	var state: String="RELAXED_SIT"
	var direction:Array=raw.get("facing",[])
	var measured:bool=bool(raw.get("depth7_measured",false))
	var directional:String=""
	if measured and direction.size()==3:
		var f:=Vector2(float(direction[0]),float(direction[2]))
		var angle:float=atan2(f.dot(Vector2(cos(view_yaw),-sin(view_yaw))),f.dot(Vector2(sin(view_yaw),cos(view_yaw))))
		directional=["RELAXED_SIT","SIT_SE","SIT_E","SIT_NE","SIT_N","SIT_NW","SIT_W","SIT_SW"][posmod(roundi(angle/(PI/4.0)),8)]
		state=directional
		if pose_profile(actor,state).is_empty() and float(direction[2])>.5 and state!="SIT_N":
			state="RELAXED_SIT"
	var anchor:Array=[]
	var exclusive:=false
	var kind:String=str(spot.get("kind",""))
	if intent=="SLEEP" or (intent=="REST" and kind=="floor_rest"):
		state="LIE_SIDE_CURLED"
		anchor=raw.get("floor",raw.get("lie_surface",[]))
		exclusive=raw.has("lie_surface") and not raw.has("floor")
	elif intent=="READ_BOOK":
		state="READ"
		anchor=raw.get("pelvis",[])
	elif intent=="WATCH_FILM":
		if measured and directional!="" and not pose_profile(actor,directional).is_empty():state=directional
		else:state="SIT_E_OCCLUDED" if str(spot.get("candidate_asset_id",""))=="owner_theatre_seat_pair" else "SIT_N"
		anchor=raw.get("pelvis",[])
	else:
		anchor=raw.get("pelvis",[])
	if anchor.size()!=3:
		return {}
	var profile:Dictionary=pose_profile(actor,state)
	if profile.is_empty():
		return {}
	var canvas:Array=profile["canvas"]
	var px:Array=profile["contact_px"]
	var bbox:Array=profile["alpha_bbox"]
	var ratio:float=CANVAS_HEIGHT/float(canvas[1])
	if bool(raw.get("depth7_measured",false)):
		ratio*=DEPTH7.scale_at(float(raw["instance_xyz"][2]))
	if state=="LIE_SIDE_CURLED":
		if (float(bbox[2])-float(bbox[0]))*ratio>float(raw.get("lie_width_m",0.0))-0.04:
			return {}
	else:
		var facing:Array=raw.get("facing",[])
		if facing.size()!=3:return {}
		if state=="SIT_E_OCCLUDED":
			if float(facing[0])<0.9:return {}
			return {"state":state,"local_xyz":anchor,"instance_xyz":raw["instance_xyz"],"contact_px":px,"canvas":canvas,"exclusive":false,"book_baked":false,"evidence":"OCCLUDED_SIDE_CROP_NOT_FULL_BODY"}
		if measured and state.begins_with("SIT_") and state!="SIT_E_OCCLUDED":
			if state!=directional:return {}
		elif state=="SIT_N":
			if float(facing[2])> -0.5:return {}
		elif float(facing[2])<0.5:return {}
		var feet:Array=raw.get("feet",[])
		if feet.size()!=3:
			return {}
		var foot_gap:float=float(anchor[1])-float(feet[1])-(float(bbox[3])-float(px[1]))*ratio
		if absf(foot_gap)>0.15 or float(profile["contact_span_px"])*ratio>float(raw.get("width_m",0.0))+0.06:
			return {}
	var result:Dictionary={"state":state,"local_xyz":anchor,"instance_xyz":raw["instance_xyz"],"contact_px":px,"canvas":canvas,"exclusive":exclusive,"book_baked":bool(profile.get("book_baked",false)),"evidence":"VISUAL_ESTIMATE_REVIEW_ONLY"}
	if state in ["RELAXED_SIT","READ","SIT_SE","SIT_SW"] and raw.has("front_z"):
		result["seat_front_z"]=float(raw["front_z"])
	return result

func prepare_rooms(rooms:Array)->void:
	# Build each existing variant once, off the live planner's hot path.
	for room in rooms:
		if has_layout(room):
			_grid(room)
			candidate_spots(room)

func cup_slots(room:Dictionary)->Array:
	var k:=key(room)
	if cup_slot_cache.has(k):
		return cup_slot_cache[k]
	var out:Array=[]
	var row:Dictionary=layouts.get(k,{})
	if row.has("service_cups"):
		for raw in row.service_cups:
			var slot:Dictionary=raw.duplicate(true)
			slot["approach"]=Vector2(float(raw.approach[0]),float(raw.approach[1]))
			if clear(room,slot.approach):out.append(slot)
		cup_slot_cache[k]=out
		return out
	if not str(room.get("type","")) in ["common","rest","kitchen"]:
		return out
	var by_id:Dictionary={}
	for item in row.get("instances",[]):
		by_id[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		var asset:String=str(item.get("asset_id",""))
		if asset in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:
			var ref:String=str(item.get("support_ref",""))
			var parent:Dictionary=by_id.get(ref.get_slice(".",0),{})
			if not parent.is_empty():
				_add_cup_slot(room,out,ref,parent,item["room_local_xyz"])
		elif asset.to_lower().contains("table"):
			for slot in item.get("support_slots",[]):
				if str(slot.get("status",""))=="MEASURED_SURFACE_CANDIDATE":
					_add_cup_slot(room,out,str(slot["room_slot_id"]),item,slot["room_xyz"])
	cup_slot_cache[k]=out
	return out

func _add_cup_slot(room:Dictionary,out:Array,id:String,item:Dictionary,pos:Array)->void:
	var lo:Array=item["bounds_min_m"]
	var hi:Array=item["bounds_max_m"]
	var x:float=float(pos[0])
	var z:float=float(pos[2])
	var options:Array=[Vector2(x,float(hi[2])+RADIUS+0.025),Vector2(x,float(lo[2])-RADIUS-0.025),Vector2(float(lo[0])-RADIUS-0.025,z),Vector2(float(hi[0])+RADIUS+0.025,z)]
	for at in options:
		if not clear(room,at):
			continue
		if out.any(func(s):return at.distance_to(s["approach"])<0.60):
			continue
		out.append({"id":id,"furniture_id":str(item["instance_id"]),"xyz":pos,"instance_xyz":item["room_local_xyz"],"approach":at})
		return

func _pose_source_valid(path:String,entry:Dictionary)->bool:
	if FileAccess.file_exists(path):
		return FileAccess.get_sha256(path)==str(entry.get("sha256",""))
	# Imported textures in exported PCK are remapped, not original PNG bytes.
	# The export tool verifies original frame hashes before emitting its proof
	# manifest; PCK audit separately verifies the texture dimensions.
	if OS.has_feature("editor") or not FileAccess.file_exists("res://data/integration_candidates/TEEA008_LIVE_REVIEW.enabled"):
		return false
	var f:=FileAccess.open("res://data/integration_candidates/TEEA008_POSE_EXPORT_PROOF.json",FileAccess.READ)
	if f==null:return false
	var proof=JSON.parse_string(f.get_as_text())
	if typeof(proof)!=TYPE_DICTIONARY or str(proof.get("frames",{}).get(path,""))!=str(entry.get("sha256","")):
		return false
	var tex:=ResourceLoader.load(path,"Texture2D") as Texture2D
	var canvas:Array=entry.get("canvas",[])
	return tex!=null and canvas.size()==2 and tex.get_width()==int(canvas[0]) and tex.get_height()==int(canvas[1])

func book_slots(room:Dictionary)->Array:
	var variant:=key(room)
	if book_slot_cache.has(variant):
		return book_slot_cache[variant]
	var out:Array=[]
	if not str(room.get("type","")) in ["library","rest"]:
		return out
	var row:Dictionary=layouts.get(variant,{})
	var used:Dictionary={}
	for item in row.get("instances",[]):
		var ref:String=str(item.get("support_ref",""))
		if ref!="":used[ref]=true
	var spots:Array=candidate_spots(room)
	for item in row.get("instances",[]):
		if not str(item.get("asset_id","")).contains("shelf"):continue
		var station_id:=""
		for spot in spots:
			if str(spot.get("furniture_id",""))==str(item["instance_id"]) and str(spot.get("kind",""))=="standing":
				station_id=str(spot["id"])
				break
		if station_id=="":continue
		for slot in item.get("support_slots",[]):
			var p:Array=slot.get("room_xyz",[])
			var fit:Array=slot.get("unscaled_dimensions_m",slot.get("max_dimensions_m",[]))
			if p.size()!=3 or fit.size()!=3 or used.has(str(slot["room_slot_id"])):
				continue
			if float(p[1])<0.35*(DEPTH7.scale_at(float(item["room_local_xyz"][2])) if DEPTH7.enabled_for(room) else 1.0) or float(p[1])>1.65 or float(fit[0])<0.16 or float(fit[1])<0.18 or float(fit[2])<0.045:
				continue
			out.append({"id":str(slot["room_slot_id"]),"station_id":station_id,"xyz":p,"instance_xyz":item["room_local_xyz"],"furniture_id":str(item["instance_id"])})
	# Measured rest-room surfaces with an existing accessible approach.
	if str(room.get("type",""))=="rest":
		for item in row.get("instances",[]):
			if not str(item.get("asset_id","")).to_lower().contains("table"):continue
			for slot in item.get("support_slots",[]):
				var sid:String=str(slot.get("room_slot_id",""))
				var p:Array=slot.get("room_xyz",[])
				var fit:Array=slot.get("unscaled_dimensions_m",slot.get("max_dimensions_m",[]))
				if used.has(sid) or str(slot.get("status",""))!="MEASURED_SURFACE_CANDIDATE" or p.size()!=3 or fit.size()!=3:continue
				if float(fit[0])<0.16 or float(fit[1])<0.18 or float(fit[2])<0.045:continue
				for spot in spots:
					if str(spot.get("cup_slot_id",""))==sid:
						out.append({"id":sid,"station_id":str(spot["id"]),"xyz":p,"instance_xyz":item["room_local_xyz"],"furniture_id":str(item["instance_id"])})
						break
	out.sort_custom(func(a,b):return str(a["id"])<str(b["id"]))
	book_slot_cache[variant]=out
	return out

func artifact_slots(room:Dictionary)->Array:
	var variant:=key(room)
	if artifact_slot_cache.has(variant):return artifact_slot_cache[variant]
	var out:Array=[]
	if str(room.get("type",""))!="artifact":return out
	var row:Dictionary=layouts.get(variant,{})
	if row.has("artifact_grid_slots"):
		artifact_slot_cache[variant]=row["artifact_grid_slots"]
		return artifact_slot_cache[variant]
	var used:Dictionary={}
	for item in row.get("instances",[]):
		var ref:String=str(item.get("support_ref",""))
		if ref!="":used[ref]=true
	for item in row.get("instances",[]):
		var asset:String=str(item.get("asset_id","")).to_lower()
		if not (asset.contains("shelf") or asset.contains("shelv") or asset.contains("commode") or asset.contains("cabinet")):continue
		for slot in item.get("support_slots",[]):
			var p:Array=slot.get("room_xyz",[])
			var dims:Array=slot.get("max_dimensions_m",[])
			var sid:String=str(slot.get("room_slot_id",""))
			if p.size()!=3 or dims.size()!=3 or used.has(sid):continue
			# Avoid any shelf-top position occupied by a separate authored prop,
			# including phase-2 props with nonstandard support identifiers.
			var blocked:=false
			for prop in row.get("instances",[]):
				if str(prop.get("instance_id",""))==str(item["instance_id"]):continue
				if str(prop.get("support_ref",""))=="":
					continue
				var lo:Array=prop.get("bounds_min_m",[])
				var hi:Array=prop.get("bounds_max_m",[])
				if lo.size()==3 and hi.size()==3 and float(p[0])+float(dims[0])*0.5>float(lo[0]) and float(p[0])-float(dims[0])*0.5<float(hi[0]) and float(p[2])+float(dims[2])*0.5>float(lo[2]) and float(p[2])-float(dims[2])*0.5<float(hi[2]) and float(p[1])+float(dims[1])>float(lo[1]) and float(p[1])-0.015<float(hi[1]):
					blocked=true
					break
			if blocked:continue
			out.append({"id":sid,"xyz":p,"dimensions":dims,"unscaled_dimensions":slot.get("unscaled_dimensions_m",dims),"instance_xyz":item["room_local_xyz"],"furniture_id":str(item["instance_id"])})
	out.sort_custom(func(a,b):return str(a["id"])<str(b["id"]))
	artifact_slot_cache[variant]=out
	return out

func artifact_support(room:Dictionary,id:String)->Dictionary:
	for slot in artifact_slots(room):
		if str(slot["id"])==id:return slot
	return {}
