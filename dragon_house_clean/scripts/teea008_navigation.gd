extends RefCounted
## Candidate-only X/Z navigation. The immutable room graph remains authoritative.
## Conservative 0.65 m diameter proxy; guest body-depth and sprite pose fit are separate gates.
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

func configure(rows:Dictionary)->void:
	layouts=rows
	grids.clear()
	blockers.clear()

func key(room:Dictionary)->String:
	var kind:String=str(room.get("type",""))
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

func clear(room:Dictionary,p:Vector2)->bool:
	if not has_layout(room):
		return true
	var hw:float=float(room.get("size_modules",1))*2.4
	# The front/side openings connect to adjacent volumes; don't shrink them.
	if absf(p.x)>hw+0.001 or p.y<BACK+RADIUS-0.001 or p.y>FRONT+0.001:
		return false
	for box:Rect2 in _obstacles(room):
		var near:=Vector2(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y))
		if p.distance_squared_to(near)<RADIUS*RADIUS-0.000001:
			return false
	return true

func segment_clear(room:Dictionary,a:Vector2,b:Vector2)->bool:
	# Sample at 2.5 cm; circle clearance is independent of grid resolution.
	var steps:int=maxi(1,ceili(a.distance_to(b)/0.025))
	for i in range(steps+1):
		if not clear(room,a.lerp(b,float(i)/float(steps))):
			return false
	return true

func _grid(room:Dictionary)->AStarGrid2D:
	var k:=key(room)
	if grids.has(k):
		return grids[k]
	var hw:float=float(room.get("size_modules",1))*2.4
	var g:=AStarGrid2D.new()
	g.region=Rect2i(0,0,roundi(hw*2.0/STEP)+1,roundi((FRONT-BACK)/STEP)+1)
	g.cell_size=Vector2(STEP,STEP)
	g.offset=Vector2(-hw,BACK)
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
	var points:Array=[a]
	for p in raw:
		points.append(p)
	points.append(b)
	# Greedy line-of-sight simplification; every resulting segment rechecked.
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
	var row:Dictionary=layouts.get(key(room),{})
	if row.is_empty():
		return []
	var cap:int=[0,4,8,16][clampi(int(room.get("size_modules",1)),1,3)]
	var out:Array=[]
	# Wall display IDs are real world IDs; safe approach is derived without
	# moving the actual object or changing its canonical home.
	for d in display_anchors:
		var p:=Vector2(float(d["x"]),float(d["z"]))
		p=nearest_clear(room,p)
		if segment_clear(room,p,p) and absf(p.x)<float(room["size_modules"])*2.4-0.18:
			_add_spot(out,{"id":d["id"],"offset":p,"kind":"standing","furniture_id":"DISPLAY_WALL","pose_hint":"VIEW","approach_z":p.y},cap,0.60)
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
				continue
			var spot:Dictionary={"id":str(station["station_candidate_id"]),"offset":p,"kind":"standing","furniture_id":str(item["instance_id"]),"pose_hint":"IDLE_S","approach_z":p.y,"candidate_kind":kind}
			if kind=="standing":
				spot["pose_hint"]="VIEW"
				if str(room.get("type","")) in ["study","workshop"]:
					spot["kind"]="work"
					spot["pose_hint"]="USE"
			elif kind=="seat":
				spot["candidate_contact"]={"pelvis":station.get("room_pelvis_contact_xyz",[]),"feet":station.get("room_feet_contact_xyz",[]),"facing":station.get("room_facing_xyz",[])}
				# Still a standing approach until a particular actor pose is calibrated.
			elif kind=="floor_rest":
				spot["candidate_contact"]={"floor":station.get("room_local_xyz",[])}
			_add_spot(out,spot,cap,0.60)
	# Standing positions must themselves be clear and reachable from the aisle.
	var width:int=int(room.get("size_modules",1))
	for z in [0.75,0.05,-0.65,-1.35,1.25]:
		for module in range(width):
			for xx in [-1.55,-0.52,0.52,1.55]:
				var p:=Vector2((float(module)-(float(width)-1.0)*0.5)*4.8+float(xx),float(z))
				if not clear(room,p):
					continue
				_add_spot(out,{"id":"teea008_stand_%d_%d_%d" % [module,roundi(p.x*100),roundi(p.y*100)],"offset":p,"kind":"standing","furniture_id":"","pose_hint":"IDLE_S","approach_z":p.y},cap,0.73)
	return out

func _add_spot(out:Array,spot:Dictionary,cap:int,gap:float)->void:
	if out.size()>=cap:
		return
	for previous in out:
		if (previous["offset"] as Vector2).distance_to(spot["offset"])<gap:
			return
	out.append(spot)
