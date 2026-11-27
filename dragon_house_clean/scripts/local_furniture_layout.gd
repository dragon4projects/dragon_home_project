extends RefCounted
## Owner-authored rigid translations of measured floor pieces and their
## dependent station/support geometry. Event-backed physical objects remain
## excluded until a multi-object durable transaction exists.
const KEY="local_furniture_offsets_v1"
const D=preload("res://scripts/depth7_space.gd")
const NAV=preload("res://scripts/teea008_navigation.gd")
const CUP_TX=preload("res://scripts/local_cup_support_transaction.gd")
const REVIEW=preload("res://scripts/dense_v2_review.gd")

static func vec(p:Array)->Vector3:return Vector3(float(p[0]),float(p[1]),float(p[2]))
static func signature(p:Dictionary)->String:
 return JSON.stringify([p.get("path",""),p.get("pivot",[]),p.get("bounds_min",[]),p.get("bounds_max",[]),p.get("scale",0),p.get("yaw",0)],"",true).sha256_text()

static func linked(compiled:Dictionary,id:String)->Dictionary:
 var ids:Dictionary={id:true}
 # Resolve only explicit support relations, never nearby objects.
 for i in range(compiled.placements.size()):
  var changed:=false
  for p in compiled.placements:
   if ids.has(p.id):continue
   if ids.has(str(p.get("support_host",""))) or ids.has(str(p.get("support_slot","")).get_slice(".",0)):
    ids[p.id]=true;changed=true
  if not changed:break
 return ids

static func allowed(compiled:Dictionary,p:Dictionary)->bool:
 if compiled.get("key","") in ["L1_gallery","L1_common"]:return false
 if p.get("role","")!="floor" or not p.get("fits",false) or p.has("special") or p.has("device_kind") or p.has("support_host"):return false
 if str(p.get("asset","")).begins_with("owner_"):return false
 var id:String=str(p.get("id",""))
 if id=="":return false
 var ids:=linked(compiled,id)
 for other in compiled.placements:
  if not ids.has(other.id):continue
  if not other.get("fits",false) or other.has("special") or other.get("pivot",[]).size()!=3 or other.get("bounds_min",[]).size()!=3 or other.get("bounds_max",[]).size()!=3:return false
  if other.id!=id and other.role!="supported_decor":return false
 return true

static func translate_array(row:Dictionary,field:String,shift:Vector3)->void:
 var a=row.get(field,[])
 if typeof(a)!=TYPE_ARRAY:return
 if a.size()==3:row[field]=[float(a[0])+shift.x,float(a[1])+shift.y,float(a[2])+shift.z]
 elif a.size()==2:row[field]=[float(a[0])+shift.x,float(a[1])+shift.z]

static func translate_station(st:Dictionary,shift:Vector3)->void:
 for field in ["room_approach_xz","room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz"]:
  translate_array(st,field,shift)

static func translate_piece(p:Dictionary,shift:Vector3)->void:
 for field in ["pivot","bounds_min","bounds_max","contact","approach","host_pivot"]:
  translate_array(p,field,shift)
 for st in p.get("station_candidates",[]):translate_station(st,shift)
 for slot in p.get("support_slots",[]):translate_array(slot,"room_xyz",shift)

static func find(compiled:Dictionary,id:String)->Dictionary:
 for p in compiled.get("placements",[]):
  if p.id==id:return p
 return {}

static func proposal(compiled:Dictionary,id:String,delta:Vector2)->Dictionary:
 if not delta.is_finite() or delta.length()<=.0001:return {}
 var next:Dictionary=compiled.duplicate(true)
 var p:Dictionary=find(next,id)
 if p.is_empty() or not allowed(next,p):return {}
 var origin:Vector3=vec(p.pivot)
 var shift:=Vector3(delta.x,0,delta.y)
 var lo:=vec(p.bounds_min)+shift
 var hi:=vec(p.bounds_max)+shift
 var hw:float=float(next.width)*.5
 if lo.x< -hw+.18 or hi.x>hw-.18 or lo.z< -8.04 or hi.z>1.65 or lo.y<0 or hi.y>3.02:return {}
 # Preserve depth scaling and keep all passage bands physically clear.
 var band:int=D.band(origin.z)
 if band not in [2,4,6,7] or D.band(origin.z+shift.z)!=band or D.band(lo.z+.001)!=band or D.band(hi.z-.001)!=band:return {}
 var ids:=linked(next,id)
 for piece in next.placements:
  if not ids.has(piece.id):continue
  var low:=vec(piece.bounds_min)+shift
  var high:=vec(piece.bounds_max)+shift
  if low.x< -hw+.18 or high.x>hw-.18 or low.z< -8.04 or high.z>1.65 or low.y<0 or high.y>3.02:return {}
  var bounds:=AABB(low,high-low)
  for other in next.placements:
   if ids.has(other.id) or not other.get("fits",false) or not other.has("bounds_min") or other.get("role","")=="rug":continue
   var a:=vec(other.bounds_min);var b:=vec(other.bounds_max)
   if bounds.grow(.008).intersects(AABB(a,b-a)):return {}
  translate_piece(piece,shift)
 for field in ["service_sources","service_cups"]:
  for rec in next.get(field,[]):
   if ids.has(str(rec.get("host",""))) or ids.has(str(rec.get("furniture_id",""))) or ids.has(str(rec.get("id",""))):
    for point in ["xyz","instance_xyz","approach"]:translate_array(rec,point,shift)
 return next

static func load_saved(world,rid:String,compiled:Dictionary)->Dictionary:
 var raw=world.runtime_state.get(KEY,{})
 if typeof(raw)!=TYPE_DICTIONARY:return {}
 var rows=raw.get(rid,{})
 if typeof(rows)!=TYPE_DICTIONARY:return {}
 var result:Dictionary=compiled
 for id in rows:
  var entry=rows[id]
  var p:Dictionary=find(result,str(id))
  if typeof(entry)!=TYPE_DICTIONARY or p.is_empty() or entry.get("source","")!=signature(p) or entry.get("delta",[]).size()!=2:return {}
  var d:Array=entry.delta
  if typeof(d[0]) not in [TYPE_FLOAT,TYPE_INT] or typeof(d[1]) not in [TYPE_FLOAT,TYPE_INT]:return {}
  result=proposal(result,str(id),Vector2(float(d[0]),float(d[1])))
  if result.is_empty():return {}
 return result

static func free_room(world,rid:String)->bool:
 for collection in [world.residents,world.creatures]:
  for a in collection.values():
   if not a.get("active",false):continue
   if a.get("room_id","")==rid or a.get("station_room_id","")==rid:return false
   if a.get("phase","")=="travel":
    var points:Array=a.get("waypoints",[])
    for i in range(clampi(int(a.get("waypoint_index",0)),0,points.size()),points.size()):
     if points[i].get("room_id","")==rid:return false
 return true

# A stationary resident is not a reason to freeze the room. Require
# real positions and existing active paths to remain valid instead.
static func safe_occupants(world,nav,room:Dictionary,row:Dictionary,old_piece:Dictionary,new_piece:Dictionary)->bool:
 var rid:String=room.id
 var trial=NAV.new()
 trial.configure({nav.key(room):row})
 var lo:=vec(new_piece.bounds_min);var hi:=vec(new_piece.bounds_max)
 var old_lo:=vec(old_piece.bounds_min);var old_hi:=vec(old_piece.bounds_max)
 var cup_plan:Dictionary=CUP_TX.plan(world,nav,trial,room)
 if not cup_plan.ok:return false
 var footprint:=Rect2(Vector2(lo.x,lo.z),Vector2(hi.x-lo.x,hi.z-lo.z)).grow(.08)
 var original:=Rect2(Vector2(old_lo.x,old_lo.z),Vector2(old_hi.x-old_lo.x,old_hi.z-old_lo.z)).grow(.08)
 for obj in world.objects.values():
  for prefix in ["home","current"]:
   if obj.get(prefix+"_room_id","")!=rid or obj.get("display_mode","")=="wall":continue
   var p:Array=obj.get(prefix+"_anchor",[])
   if p.size()!=2:continue
   var at:=Vector2(float(p[0]),float(p[1]))
   if footprint.has_point(at) or original.has_point(at):
    if not cup_plan.changes.get(obj.id,{}).has(prefix+"_anchor"):return false
 var half:float=float(room.size_modules)*2.4
 var entrances:Array=[Vector2(-half+.08,1.5),Vector2(half-.08,1.5)]
 for collection in [world.residents,world.creatures]:
  for a in collection.values():
   if not a.get("active",false):continue
   if a.get("room_id","")==rid:
    var at:Vector2=world.room_world_to_local(room,Vector3(float(a.get("x",0)),float(a.get("visual_y",0)),float(a.get("z",0))))
    if not trial.clear(room,at):return false
    for e in entrances:
     if not nav.path(room,at,e).is_empty() and trial.path(room,at,e).is_empty():return false
   # Future routes are immutable commitments during this edit. Conservatively
   # defer any edit that would need to rewrite an active route in this room.
   if a.get("phase","")=="travel":
    var points:Array=a.get("waypoints",[])
    for i in range(clampi(int(a.get("waypoint_index",0)),0,points.size()),points.size()):
     if points[i].get("room_id","")==rid:return false
 return true

static func row_after(row:Dictionary,compiled:Dictionary,id:String)->Dictionary:
 var result:Dictionary=row.duplicate(true)
 var ids:=linked(compiled,id)
 var shifts:Dictionary={}
 for item in result.instances:
  if not ids.has(item.instance_id):continue
  var p:Dictionary=find(compiled,item.instance_id)
  var shift:=vec(p.pivot)-vec(item.room_local_xyz)
  shifts[item.instance_id]=shift
  for field in ["room_local_xyz","bounds_min_m","bounds_max_m"]:translate_array(item,field,shift)
  # Preserve qualified/withheld station subset and any repaired approach.
  for st in item.get("station_candidates",[]):translate_station(st,shift)
  for slot in item.get("support_slots",[]):translate_array(slot,"room_xyz",shift)
 for slot in result.get("measured_book_slots",[]):
  if shifts.has(str(slot.furniture_id)):
   for field in ["xyz","instance_xyz","box_min","box_max"]:translate_array(slot,field,shifts[slot.furniture_id])
 for field in ["service_sources","service_cups"]:
  for rec in result.get(field,[]):
   var host:String=str(rec.get("host",rec.get("furniture_id",rec.get("id",""))))
   if shifts.has(host):
    for point in ["xyz","instance_xyz","approach"]:translate_array(rec,point,shifts[host])
 return result

static func paths_preserved(nav,room:Dictionary,next_row:Dictionary)->bool:
 var k:String=nav.key(room)
 var trial=NAV.new();trial.configure({k:next_row})
 var half:float=float(room.size_modules)*2.4
 var ends:Array=[Vector2(-half+.08,1.5),Vector2(half-.08,1.5)]
 var next_spots:Dictionary={}
 for s in trial.candidate_spots(room):next_spots[s.id]=s
 for s in nav.candidate_spots(room):
  if not s.has("candidate_kind") and not s.has("cup_slot_id"):continue
  if not next_spots.has(s.id):return false
  var dest:Vector2=next_spots[s.id].offset
  if not trial.clear(room,dest):return false
  for start in ends:
   if not nav.path(room,start,s.offset).is_empty() and trial.path(room,start,dest).is_empty():return false
 # Book/cup identities are immutable; moved books resolve by stable slot.
 var next_books:Dictionary={}
 for s in trial.book_slots(room):next_books[s.id]=s
 for s in nav.book_slots(room):
  if not next_books.has(s.id):return false
 var next_cups:Dictionary={}
 for s in trial.cup_slots(room):next_cups[s.id]=s
 for s in nav.cup_slots(room):
  if not next_cups.has(s.id):return false
  for start in ends:
   if not nav.path(room,start,s.approach).is_empty() and trial.path(room,start,next_cups[s.id].approach).is_empty():return false
 var new_sources:Dictionary={}
 for s in next_row.get("service_sources",[]):new_sources[s.id]=s
 for s in nav.layouts[k].get("service_sources",[]):
  var p=s.get("approach",[])
  if typeof(p)!=TYPE_ARRAY or p.size()!=2:continue
  var point:=Vector2(p[0],p[1])
  if not new_sources.has(s.id):return false
  var dest:Array=new_sources[s.id].approach
  for start in ends:
   if not nav.path(room,start,point).is_empty() and trial.path(room,start,Vector2(dest[0],dest[1])).is_empty():return false
 return true

static func claims_preserved(scene,room:Dictionary,row:Dictionary,moving:Dictionary={})->bool:
 var nav=scene.life.candidate_navigation
 var trial=NAV.new();trial.configure({nav.key(room):row})
 var stations=scene.life.stations
 var anchors:Array=stations._display_anchor_data(scene.world,room)
 var points:Array=trial.candidate_spots(room,anchors)
 for actor in scene.world.residents.values():
  if actor.get("station_room_id","")!=room.id:continue
  if moving.has(str(actor.get("station_furniture_id",""))):return false
  var anchor:String=str(actor.get("station_anchor_id",""))
  for id in moving:
   if anchor==id or anchor.begins_with(str(id)+"."):return false
  # Cup station IDs do not necessarily begin with their furniture ID.
  for slot in nav.cup_slots(room):
   if slot.id==anchor and moving.has(slot.furniture_id):return false
  var index:int=int(actor.get("station_slot",-1))
  var at:Array=actor.get("station_point",[])
  # No moving an occupied seat, a reserved station, or a current claim
  # index. No actor teleport or cancellation to make the edit fit.
  if index<0 or index>=points.size() or at.size()!=2:return false
  if str(points[index].id)!=str(actor.get("station_anchor_id","")) or points[index].offset.distance_to(Vector2(at[0],at[1]))>.0001:return false
 return true

static func commit(scene,rid:String,id:String,delta:Vector2)->bool:
 var w=scene.world
 var room:Dictionary=w.room_by_id(rid)
 if w.recovery_blocked or w.runtime_state.has(CUP_TX.KEY) or not w.public_cutaway_allowed(room) or not scene.dense_v2.has_room(rid):return false
 var entry:Dictionary=scene.dense_v2.by_room[rid]
 var current:Dictionary=entry.compiled
 var next:Dictionary=proposal(current,id,delta)
 if next.is_empty():return false
 var nav=scene.life.candidate_navigation
 var k:String=entry.variant
 var row:Dictionary=row_after(nav.layouts[k],next,id)
 if not safe_occupants(w,nav,room,row,find(current,id),find(next,id)) or not paths_preserved(nav,room,row) or not claims_preserved(scene,room,row,linked(current,id)):return false
 var trial=NAV.new();trial.configure({k:row})
 var cup_plan:Dictionary=CUP_TX.plan(w,nav,trial,room)
 if not cup_plan.ok:return false
 var old:Dictionary=w.runtime_state.get(KEY,{}).duplicate(true)
 var saved:Dictionary=old.duplicate(true)
 if not saved.has(rid):saved[rid]={}
 var previous:Dictionary=saved[rid].get(id,{})
 var old_delta:Array=previous.get("delta",[0,0])
 var total:=Vector2(float(old_delta[0]),float(old_delta[1]))+delta
 saved[rid][id]={"source":previous.get("source",signature(find(current,id))),"delta":[total.x,total.y]}
 # Validate the composed move will be reconstructable, not an incremental
 # path whose final placement could disagree with the original base.
 if total.length()<.0001:saved[rid].erase(id)
 w.runtime_state[KEY]=saved
 var replayed:Dictionary=load_saved(w,rid,entry.base_compiled)
 if replayed.is_empty():
  w.runtime_state[KEY]=old;return false
 for p in next.placements:
  var q:Dictionary=find(replayed,p.id)
  if q.is_empty() or vec(q.pivot).distance_to(vec(p.pivot))>.0001:
   w.runtime_state[KEY]=old;return false
 var journal:Array=w.journal.duplicate(true)
 w._append_journal("FURNITURE_OFFSET_ASSIGNED","LOCAL_DRAGON",id,rid,rid,{"delta_xz":[total.x,total.y]})
 if not cup_plan.changes.is_empty():w.runtime_state[CUP_TX.KEY]={"room_id":rid,"changes":cup_plan.changes}
 if not w.save_world():
  w.runtime_state[KEY]=old;w.runtime_state.erase(CUP_TX.KEY);w.journal=journal;return false
 # Mirror the pending intent to the backup before appending durable events.
 if w.runtime_state.has(CUP_TX.KEY) and not w.save_world():return false
 entry["compiled"]=next
 nav.layouts[k]=row
 # Invalidate geometry caches only. Never lose calibrated sprite profiles.
 for cache in [nav.grids,nav.blockers,nav.path_cache,nav.social_segment_cache,nav.static_spots,nav.display_cache,nav.cup_slot_cache,nav.book_slot_cache,nav.artifact_slot_cache]:cache.clear()
 nav.path_cache_order.clear()
 if not CUP_TX.finish(w,nav):
  w._block_world_recovery("CUP_SUPPORT_EDIT_RECOVERY_REQUIRED","Cannot complete saved furniture support edit.")
  return false
 scene.make_rooms()
 scene.update_render_lod()
 scene.update_physical_objects()
 scene._update_physical_books()
 scene._update_teea008_media_previews()
 return true
