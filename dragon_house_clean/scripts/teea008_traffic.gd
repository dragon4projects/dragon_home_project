extends RefCounted
## Local swept-disc avoidance for candidate resident traffic.
## Proxy radii are not anatomical measurements. No change to room geometry.
const GAP:=0.65
const EPS:=0.0001
var world
var nav
var positions:Dictionary={}
var enabled:=false
var detours:=0
var waits:=0
var checked:=0
var initial_overlap_steps:=0
var min_clearance:=INF
var progress:Dictionary={}
var stalled_replans:=0

func begin(model,navigation)->void:
	world=model
	nav=navigation
	positions.clear()
	if world.canonical_house_seed:
		enabled=true
		return
	for id in world.residents:
		var actor:Dictionary=world.residents[id]
		if bool(actor.get("active",false)):
			positions[str(id)]=Vector3(float(actor.get("x",0)),float(actor.get("visual_y",float(actor.get("level",0))*world.FLOOR_H)),float(actor.get("z",0)))
	enabled=true

func finish()->void:
	enabled=false
	positions.clear()
	world=null
	nav=null

func publish(id:String,at:Vector3)->void:
	if enabled and not world.canonical_house_seed:
		positions[id]=at

func _safe_peer(id:String,a:Vector3,b:Vector3)->bool:
	var start:=Vector2(a.x,a.z)
	var end:=Vector2(b.x,b.z)
	for other in positions:
		if other==id:continue
		var p:Vector3=positions[other]
		if absf(p.y-a.y)>0.35 or absf(p.y-b.y)>0.35:continue
		var q:=Vector2(p.x,p.z)
		if start.distance_squared_to(q)>4.0:continue
		var before:=start.distance_to(q)
		var after:=end.distance_to(q)
		var swept:=Geometry2D.get_closest_point_to_segment(q,start,end).distance_to(q)
		if before>=GAP-EPS:
			if swept<GAP-EPS:return false
		else:
			# A legacy/save spawn may already overlap. Allow only non-worsening
			# separation; never claim the inherited overlap was collision-free.
			if after<before-EPS or swept<before-EPS:return false
	return true

func _safe_room(actor:Dictionary,a:Vector3,b:Vector3)->bool:
	var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
	if room.is_empty():return false
	var aa:Vector2=world.room_space.world_to_local(room,a)
	var bb:Vector2=world.room_space.world_to_local(room,b)
	if world.canonical_house_seed:
		# The absence of furniture is not permission to leave a room shell.
		# Side connector crossings are handled separately by step().
		if not world.room_space.local_contains(room,bb):
			return false
		if not world.is_accessible(room,str(actor.get("id",""))):
			# Closed doors retain a public front passage. A walker may not
			# use the hidden interior as a shortcut to pass another walker.
			# If access was revoked while inside, allow monotone egress only.
			const FRONTAGE_MIN:=1.35
			if aa.y>=FRONTAGE_MIN-EPS:
				if bb.y<FRONTAGE_MIN-EPS:return false
			elif bb.y<=aa.y+EPS or absf(bb.x-aa.x)>EPS:
				return false
	if not nav.has_layout(room):return true
	return nav.segment_clear(room,aa,bb)

func _record(id:String,a:Vector3,b:Vector3)->void:
	checked+=1
	for other in positions:
		if other==id:continue
		var p:Vector3=positions[other]
		if absf(p.y-a.y)>0.35 or absf(p.y-b.y)>0.35:continue
		var q:=Vector2(p.x,p.z)
		var from:=Vector2(a.x,a.z)
		var to:=Vector2(b.x,b.z)
		var d:=Geometry2D.get_closest_point_to_segment(q,from,to).distance_to(q)
		min_clearance=minf(min_clearance,d)
		if from.distance_to(q)<GAP-EPS:
			initial_overlap_steps+=1

func step(actor:Dictionary,a:Vector3,target:Vector3,direct:Vector3,distance:float,kind:String)->Vector3:
	if not enabled:return direct
	var id:=str(actor["id"])
	# Lift vertical movement is a separate connector contract; local horizontal
	# steering must never displace a lift trajectory or side-connector crossing.
	if absf(direct.y-a.y)>0.001 or kind=="lift":
		return direct
	if a.distance_squared_to(direct)<EPS*EPS:return direct
	if world.canonical_house_seed:
		# Owner-approved: characters may overlap. Only authored geometry,
		# privacy and station reservations constrain movement.
		checked+=1
		if kind=="connector_in" or _safe_room(actor,a,direct):
			return direct
		waits+=1
		return a
	if _safe_peer(id,a,direct) and (kind=="connector_in" or _safe_room(actor,a,direct)):
		_record(id,a,direct)
		return direct
	# Connector crossing must stay on its authored lane. A detour on the
	# previous local leg must retain a clear path to the authored waypoint.
	if kind=="connector_in":
		waits+=1
		_record(id,a,a)
		return a
	var f:=Vector2(target.x-a.x,target.z-a.z).normalized()
	if f.length_squared()<EPS:return a
	var best:=a
	var best_score:=-INF
	# Stable right-hand side preference. Reverse/sideways escape is allowed;
	# every candidate is checked against furniture and already moved peers.
	for angle in [35.0,-35.0,70.0,-70.0,100.0,-100.0,145.0,-145.0,180.0]:
		var d:Vector2=f.rotated(deg_to_rad(angle))*distance
		var b:=a+Vector3(d.x,0,d.y)
		if not _safe_room(actor,a,b) or not _safe_room(actor,b,target) or not _safe_peer(id,a,b):continue
		var score:=a.distance_to(target)-b.distance_to(target)
		# Prefer separation from the obstructing person over a tiny forward gain.
		var nearest:=GAP*2.0
		for other in positions:
			if other==id:continue
			var p:Vector3=positions[other]
			if absf(p.y-a.y)<0.35:
				nearest=minf(nearest,Vector2(p.x-b.x,p.z-b.z).length())
		score+=0.22*nearest+(0.005 if angle>0 else 0.0)
		if score>best_score:
			best_score=score
			best=b
	if best==a:
		waits+=1
	else:
		detours+=1
	_record(id,a,best)
	return best

func metrics()->Dictionary:
	return {"checks":checked,"detours":detours,"waits":waits,"inherited_overlap_pairs":initial_overlap_steps,"minimum_observed_m":min_clearance,"stalled_replans":stalled_replans}

func stalled(actor_id:String,waypoint_index:int,at:Vector3,target:Vector3,delta:float)->bool:
	var remaining:=at.distance_to(target)
	var previous:Dictionary=progress.get(actor_id,{})
	if previous.is_empty() or int(previous["index"])!=waypoint_index or previous["target"]!=target:
		progress[actor_id]={"index":waypoint_index,"target":target,"best":remaining,"seconds":0.0}
		return false
	if remaining<float(previous["best"])-0.10:
		previous["best"]=remaining
		previous["seconds"]=0.0
	else:
		previous["seconds"]=float(previous["seconds"])+delta
	if float(previous["seconds"])>=5.0:
		progress.erase(actor_id)
		stalled_replans+=1
		return true
	return false

func clear_progress(id:String)->void:
	progress.erase(id)
