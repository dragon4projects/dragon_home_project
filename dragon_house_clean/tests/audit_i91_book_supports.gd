extends "res://tests/audit_dense_v2_support_surfaces.gd"
const NAV=preload("res://scripts/teea008_navigation.gd")
const SERVICE=preload("res://scripts/dense_v2_service_overlay.gd")
const KEYS=["L2_library","L0_reading"]
var nav=NAV.new()
var room:Dictionary={}
var result:Dictionary={}
var occupied:Array=[]
func _route(host:Dictionary)->String:
 for spot in nav.candidate_spots(room):
  if str(spot.get("furniture_id",""))!=str(host.id) or spot.kind!="standing":continue
  if not nav.path(room,Vector2(-7.12,1.5),spot.offset).is_empty() and not nav.path(room,Vector2(7.12,1.5),spot.offset).is_empty():return spot.id
 return ""
func _candidate(host:Dictionary,g:Dictionary,at:Vector3,size:Vector3,sid:String,station:String)->Dictionary:
 var pivot:=_v(host.pivot)
 var box:=AABB(at-Vector3(size.x*.5,0,size.z*.5),size)
 if occupied.any(func(o):return o.id!=host.id and box.grow(.008).intersects(o.box)):return {}
 if not _probe(g,at-pivot,size) or not _host_clear(g,AABB(box.position-pivot,box.size)):return {}
 return {"id":sid,"station_id":station,"xyz":_a(at),"instance_xyz":host.pivot,"furniture_id":host.id,"dimensions":_a(size),"box_min":_a(box.position),"box_max":_a(box.end),"support_evidence":"ACTUAL_IMPORTED_TRIANGLE_FOOTPRINT_CLEARANCE"}
func _remember(slot:Dictionary)->void:
 occupied.append({"id":slot.id,"box":AABB(_v(slot.box_min),_v(slot.box_max)-_v(slot.box_min))})
func _host(host:Dictionary)->Dictionary:
 var g:=_geometry(host)
 var station:=_route(host)
 if g.is_empty() or station=="":return {"slots":[],"old_fail":[]}
 var pivot:=_v(host.pivot)
 var scale:float=NAV.DEPTH7.scale_at(pivot.z)
 # Closed book mesh (0.16 x 0.18 x 0.045) and its cover quad (.023)
 # are depth-scaled in the renderer. Extra X/Z clearance is conservative.
 var size:=Vector3(.16*scale+.012,.18*scale+.008,.046*scale+.012)
 var old:Array=[]
 for s in host.get("support_slots",[]):
  var q:=_v(s.room_xyz)
  if q.y<.35*scale or q.y>1.65:continue
  old.append(s)
 var slots:Array=[]
 var failed:Array=[]
 var levels:Array=[]
 for s in old:
  var point:=_v(s.room_xyz)
  var best:Dictionary={}
  for hit in _hits(g,Vector2(point.x-pivot.x,point.z-pivot.z)):
   if not hit.flat or absf(float(hit.y)+pivot.y-point.y)>.025:continue
   var at:=Vector3(point.x,float(hit.y)+pivot.y,point.z)
   var slot:=_candidate(host,g,at,size,s.room_slot_id,station)
   if slot.is_empty():continue
   best=slot;break
  if best.is_empty():failed.append(s.room_slot_id);continue
  slots.append(best);_remember(best)
  var y:float=float(best.xyz[1])
  if not levels.any(func(v):return absf(float(v)-y)<.025):levels.append(y)
 var hb:=_box(host)
 # Retain old support identities first. Additional centres are sampled
 # only on the same verified physical planes; no replacement of furniture.
 for index in range(levels.size()):
  var y:float=levels[index]
  var used:=0
  var z:float=pivot.z
  var n:=floori((hb.size.x-size.x-.02)/.035)
  for ix in range(n+1):
   var x:float=hb.position.x+size.x*.5+.01+ix*.035
   var sid:String="%s.I91_B_%02d_%02d"%[host.id,index+1,ix]
   var slot:=_candidate(host,g,Vector3(x,y,z),size,sid,station)
   if slot.is_empty():continue
   slots.append(slot);_remember(slot);used+=1
 print("I91_BOOK_HOST ",host.id," old=",old.size()," old_fail=",failed.size()," qualified=",slots.size()," levels=",levels)
 return {"slots":slots,"old_fail":failed}
func _run()->void:
 if not _self_test() or not review.initialize():quit(1);return
 var overlay=SERVICE.new()
 if not overlay.initialize():quit(2);return
 var source_sha:=FileAccess.get_sha256(REVIEW.SOURCE)
 var shas:Dictionary={}
 var rooms:Dictionary={}
 for i in range(3):
  var path:String="res://data/interior_v2/dense_v2_compiled_%d.zip"%i
  shas[str(i)]=FileAccess.get_sha256(path)
  var z:=ZIPReader.new()
  if z.open(path)!=OK:quit(3);return
  var d=JSON.parse_string(z.read_file("compiled.json").get_string_from_utf8());z.close()
  if d.source_sha256!=source_sha:quit(4);return
  rooms.merge(d.rooms)
 var total:=0
 for k in KEYS:
  var compiled:Dictionary=rooms[k]
  if not overlay.apply(compiled):quit(5);return
  var row:=review.navigation_row(compiled,"library",3)
  room={"type":"library","size_modules":3,"depth7":true,"dense_v2_layout":row.variant_id}
  row["service_sources"]=compiled.service_sources
  row["service_cups"]=compiled.service_cups
  nav.configure({row.variant_id:row})
  occupied.clear()
  for p in compiled.placements:
   if p.get("fits",false) and p.has("bounds_min"):occupied.append({"id":p.id,"box":_box(p)})
  for c in compiled.service_cups:
   var at:=_v(c.xyz)
   occupied.append({"id":c.id,"box":AABB(at-Vector3(.12,0,.12),Vector3(.24,.20,.24))})
  var slots:Array=[]
  var fails:Array=[]
  for host in compiled.placements:
   if host.get("asset","")!="wooden_bookshelf_worn":continue
   var measured:=_host(host)
   slots.append_array(measured.slots);fails.append_array(measured.old_fail)
  result[k]={"slots":slots,"withheld_old":fails}
  print("I91_BOOK_ROOM ",k," qualified=",slots.size()," withheld_old=",fails.size())
  total+=slots.size()
 var f:=FileAccess.open("user://i91_book_supports.json",FileAccess.WRITE)
 if f==null:quit(6);return
 f.store_string(JSON.stringify({"schema":1,"source_sha256":source_sha,"compiled_sha256":shas,"services_sha256":FileAccess.get_sha256(SERVICE.PATH),"rooms":result}," "));f.close()
 print("I91_BOOK_GEOMETRY_AUDIT total=",total)
 quit(0)
