extends "res://tests/audit_dense_v2_support_surfaces.gd"
const NAV=preload("res://scripts/teea008_navigation.gd")
const SERVICE=preload("res://scripts/dense_v2_service_overlay.gd")
const BOOK=preload("res://scripts/dense_v2_book_overlay.gd")
const KEYS=["L2_library","L0_reading"]
const TARGETS=["mid_century_lounge_chair","modern_arm_chair_01","gallinera_chair","painted_wooden_chair_02","blendkit_sofa"]
var nav=NAV.new()
var room:Dictionary={}
func _top(g:Dictionary,x:float,z:float)->float:
 var hits:=_hits(g,Vector2(x,z))
 if hits.is_empty():return -INF
 return float(hits[-1].y)
func _seat(p:Dictionary)->Array:
 var local:Dictionary=p.duplicate(true)
 local.scale=1.0;local.yaw=0.0
 var g:=_geometry(local)
 if g.is_empty():return []
 var bounds:Dictionary=review.measured_bounds(p.path,0)
 if bounds.is_empty():return []
 var b:AABB=bounds.bounds
 var k:float=p.scale
 var xf:=Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.yaw))).scaled(Vector3.ONE*k),_v(p.pivot))
 var facing:Vector3=(xf.basis*Vector3.FORWARD*-1).normalized()
 var out:Array=[]
 var surface_count:=0
 var reachable_count:=0
 var centers:Array=[0.0] if not str(p.asset).begins_with("blendkit_sofa") else [-.45,.45]
 for c in centers:
  var best:Dictionary={}
  var score:float=-INF
  for zi in range(19):
   var z:float=lerpf(b.position.z+b.size.z*.34,b.position.z+b.size.z*.68,float(zi)/18.0)
   var y:float=_top(g,c,z)
   if not is_finite(y) or y-b.position.y<.28 or y-b.position.y>.57:continue
   var halfwidth:=0.0
   for wi in range(1,50):
    var w:float=wi*.01
    var pass_sample:=true
    for dz in [-.09,0.0,.09]:
     for dx in [-w,0.0,w]:
      var h:=_top(g,c+dx,z+dz)
      if not is_finite(h) or absf(h-y)>.036:pass_sample=false;break
     if not pass_sample:break
    if not pass_sample:break
    halfwidth=w
   if halfwidth<.12:continue
   var anchor:Vector3=xf*Vector3(c,y,z)
   var front:Vector3=xf*Vector3(c,b.position.y,b.end.z)
   surface_count+=1
   var approach:=Vector2.INF
   var origin:=Vector2(anchor.x,anchor.z)
   var f:=Vector2(facing.x,facing.z)
   var hb:=_box(p)
   var lo:=Vector2(hb.position.x,hb.position.z)
   var hi:=Vector2(hb.end.x,hb.end.z)
   var options:Array=[]
   # Enter from the front or either side; the narrow table-facing gap
   # need not be wide enough to stand in. Never choose behind the back.
   for distance in [.40,.50,.60,.70,.80,.90,.95]:
    for deg in [0,30,-30,60,-60,90,-90]:
     var a:Vector2=origin+f.rotated(deg_to_rad(float(deg)))*float(distance)
     if a.distance_to(a.clamp(lo,hi))<.12 or not nav.clear(room,a):continue
     if nav._obstacles(room).any(func(ob):return ob.has_point(a)):continue
     options.append(a)
   for a in options:
    if nav.path(room,Vector2(-7.12,1.5),a).is_empty() or nav.path(room,Vector2(7.12,1.5),a).is_empty():continue
    approach=a;break
   if not approach.is_finite():continue
   reachable_count+=1
   var quality:float=halfwidth-absf(z)*.035
   if quality<=score:continue
   score=quality
   var feet:Vector3=front+facing*.06
   best={"kind":"seat","id":"seat_"+str(out.size()+1),"station_candidate_id":p.id+".seat_"+str(out.size()+1),"room_local_xyz":_a(anchor),"room_pelvis_contact_xyz":_a(anchor),"room_feet_contact_xyz":_a(feet),"room_facing_xyz":_a(facing),"room_approach_xz":[approach.x,approach.y],"seating_width_m":2*halfwidth*k,"seat_depth_m":.18*k,"pose_hint":"RELAXED_SIT","status":"I92_SAMPLED_SEAT_SURFACE_AND_ROUTE_CANDIDATE","support_variation_max_m":.036*k}
  if not best.is_empty():out.append(best)
 print("I92_DIAG ",p.id," surface_samples=",surface_count," reachable_samples=",reachable_count)
 return out
func _run()->void:
 if not review.initialize():quit(1);return
 var services=SERVICE.new()
 var books=BOOK.new()
 if not services.initialize() or not books.initialize():quit(2);return
 var rooms:Dictionary={}
 var hashes:Dictionary={}
 for i in range(3):
  var path:String="res://data/interior_v2/dense_v2_compiled_%d.zip"%i
  hashes[str(i)]=FileAccess.get_sha256(path)
  var z:=ZIPReader.new()
  if z.open(path)!=OK:quit(3);return
  var d=JSON.parse_string(z.read_file("compiled.json").get_string_from_utf8());z.close()
  rooms.merge(d.rooms)
 var results:Dictionary={}
 for key in KEYS:
  var compiled:Dictionary=rooms[key]
  if not services.apply(compiled):quit(4);return
  var row:=review.navigation_row(compiled,"library",3)
  row["service_sources"]=compiled.service_sources;row["service_cups"]=compiled.service_cups
  if not books.apply(compiled,row):quit(5);return
  room={"type":"library","size_modules":3,"depth7":true,"dense_v2_layout":row.variant_id}
  nav.configure({row.variant_id:row})
  var rows:Array=[]
  var count:=0
  for p in compiled.placements:
   if not p.get("fits",false) or not p.get("asset","") in TARGETS or not p.get("station_candidates",[]).is_empty():continue
   var original:Dictionary=p.duplicate(true)
   var replacement:Dictionary={}
   var seats:=_seat(p)
   if (seats.is_empty() and p.asset in ["mid_century_lounge_chair","blendkit_sofa"]) or p.asset=="painted_wooden_chair_02":
    var candidate:Dictionary=p.duplicate(true)
    if p.asset=="mid_century_lounge_chair":
     candidate.asset="modern_arm_chair_01"
     candidate.path="res://assets/teea008_review/decor_bank/modern_arm_chair_01/model.gltf"
    elif p.asset=="blendkit_sofa":
     candidate.asset="blendkit_sofa/repaired.glb"
     candidate.path="res://assets/decor_bank/blendkit_sofa/repaired.glb"
    var geometry:Dictionary=review.measured_bounds(candidate.path,float(candidate.yaw))
    if not geometry.is_empty():
     var bb:AABB=geometry.bounds
     var old:AABB=_box(p)
     var scale:float=minf(float(p.scale),minf(old.size.x/bb.size.x,minf(old.size.y/bb.size.y,old.size.z/bb.size.z)))
     if p.asset=="painted_wooden_chair_02":scale=minf(scale,.93)
     var pivot:=Vector3(old.get_center().x-bb.get_center().x*scale,old.position.y-bb.position.y*scale,old.get_center().z-bb.get_center().z*scale)
     var bounds:=AABB(pivot+bb.position*scale,bb.size*scale)
     if old.grow(.001).encloses(bounds) and scale>=float(p.scale)*.75:
      candidate.scale=scale;candidate.pivot=_a(pivot);candidate.bounds_min=_a(bounds.position);candidate.bounds_max=_a(bounds.end)
      # Old navigation obstacles are intentionally retained for conservative
      # approach qualification; the replacement never exceeds the envelope.
      var fixed:=_seat(candidate)
      if not fixed.is_empty():
       replacement=candidate
       seats=fixed
       print("I92_REPLACEMENT ",p.id," ",p.asset," -> ",candidate.asset," scale=",scale," enclosed=true")
   count+=seats.size()
   print("I92_SEAT ",p.id," ",p.asset," count=",seats.size()," ",seats)
   rows.append({"id":p.id,"path":p.path,"yaw":p.yaw,"scale":p.scale,"pivot":p.pivot,"stations":seats,"replacement":replacement})
  results[key]={"hosts":rows,"count":count}
  print("I92_SEAT_ROOM ",key," additional_candidates=",count)
 var f:=FileAccess.open("user://i92_seat_candidates.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"schema":1,"source_sha256":FileAccess.get_sha256(REVIEW.SOURCE),"compiled_sha256":hashes,"services_sha256":FileAccess.get_sha256(SERVICE.PATH),"books_sha256":FileAccess.get_sha256(BOOK.PATH),"rooms":results}," "));f.close()
 quit(0)
