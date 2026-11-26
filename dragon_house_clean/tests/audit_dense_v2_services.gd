extends "res://tests/audit_dense_v2_support_surfaces.gd"
const NAV=preload("res://scripts/teea008_navigation.gd")
const ROOM_KINDS={"L0_workshop":"workshop","L1_gallery":"artifact","L1_study":"study","L2_library":"library","L0_reading":"library","L0_kitchen":"kitchen","L0_cinema":"cinema","L2_cinema":"cinema","L2_music":"music","L1_lounge":"rest","L2_lounge":"rest"}
const MUGS=["candidate_dragon_mug_red","candidate_guest_mug_blue"]
const GRID_FILE="res://data/interior_v2/artifact_grids_qa.json"
var nav=NAV.new()
var nav_room:Dictionary={}
var reserved:Array=[]
var occupied:Array=[]
var output:Dictionary={}
var grid_doc:Dictionary={}
var red:Dictionary={}
var blue:Dictionary={}

func _approach(host:Dictionary,at:Vector3)->Vector2:
 var b:=_box(host)
 # Front-facing equipment only: do not claim it can be operated from behind.
 for offset in [.0,-.15,.15,-.30,.30]:
  var p:=Vector2(at.x+offset,b.end.z+.38)
  if p.distance_to(Vector2(at.x,at.z))>1.05:continue
  if nav.clear(nav_room,p) and not nav.path(nav_room,Vector2(-7.12,1.5),p).is_empty() and not nav.path(nav_room,Vector2(7.12,1.5),p).is_empty():return p
 return Vector2.INF

func _pick(model:Dictionary,host:Dictionary,id:String,service:bool,used_approaches:Array)->Dictionary:
 var geometry:=_geometry(host)
 if geometry.is_empty():return {}
 var hbox:=_box(host)
 var pivot:=_v(host.pivot)
 var measurement:Dictionary=review.measured_bounds(model.path,0.0)
 if measurement.is_empty():return {}
 var b:AABB=measurement.bounds
 # Preserve physical depth scale of the host, not arbitrary shrink-to-fit.
 var scale:float=clampf(float(host.get("depth_scale",NAV.DEPTH7.scale_at(hbox.get_center().z))),.60,1.0)
 var size:=b.size*scale
 var nx:=floori((hbox.size.x-size.x-.02)/.055)
 var nz:=floori((hbox.size.z-size.z-.02)/.055)
 for iz in range(nz,-1,-1):
  for ix in range(nx+1):
   var x:float=hbox.position.x+size.x*.5+.01+ix*.055
   var z:float=hbox.position.z+size.z*.5+.01+iz*.055
   var hits:=_hits(geometry,Vector2(x-pivot.x,z-pivot.z))
   hits.reverse()
   for hit in hits:
    var y:float=float(hit.y)+pivot.y
    if not hit.flat or y<.28 or y>1.40 or y<hbox.end.y-.035:continue
    var at:=Vector3(x,y,z)
    var box:=AABB(at-Vector3(size.x*.5,0,size.z*.5),size)
    if occupied.any(func(o):return o.id!=host.id and box.grow(.015).intersects(o.box)):continue
    if not _probe(geometry,at-pivot,size) or not _host_clear(geometry,AABB(box.position-pivot,box.size)):continue
    var approach:=_approach(host,at) if service else Vector2.ZERO
    if not approach.is_finite() or (service and used_approaches.any(func(p):return approach.distance_to(p)<.62)):continue
    var center:=b.get_center()
    return {"id":id,"asset":model.id,"path":model.path,"role":"supported_decor","fits":true,"yaw":0.0,"scale":scale,"pivot":_a(at-Vector3(center.x,b.position.y,center.z)*scale),"bounds_min":_a(box.position),"bounds_max":_a(box.end),"support_host":host.id,"support_slot":id+".surface","contact":_a(at),"approach":[approach.x,approach.y],"review_status":"I89_SERVICE_MEASURED"}
 return {}

func _accept(p:Dictionary)->void:
 occupied.append({"id":p.id,"box":_box(p)})

func _room(compiled:Dictionary,key:String)->Dictionary:
 var row:=review.navigation_row(compiled,ROOM_KINDS[key],3)
 nav_room={"type":ROOM_KINDS[key],"size_modules":3,"depth7":true,"dense_v2_layout":row.variant_id}
 nav.configure({row.variant_id:row})
 occupied.clear()
 var hosts:Array=[]
 var by_id:Dictionary={}
 for p in compiled.placements:
  by_id[p.id]=p
  if p.get("fits",false) and p.has("bounds_min"):occupied.append({"id":p.id,"box":_box(p)})
  if p.get("role","")=="floor" and p.id!="L1_gallery_F20" and ["table","cabinet","commode","drawer","counter","sideboard","desk"].any(func(t):return str(p.asset).to_lower().contains(t)):hosts.append(p)
  for slot in p.get("support_slots",[]):
   if slot.get("room_xyz",[]).size()!=3 or slot.get("max_dimensions_m",[]).size()!=3:continue
   var s:=_v(slot.max_dimensions_m)
   if absf(fposmod(float(p.yaw),180.0)-90.0)<.01:s=Vector3(s.z,s.y,s.x)
   if minf(s.x,minf(s.y,s.z))<=0:continue
   var at:=_v(slot.room_xyz)
   occupied.append({"id":str(slot.room_slot_id),"box":AABB(at-Vector3(s.x*.5,0,s.z*.5),s)})
 if key=="L1_gallery":
  for g in grid_doc.grids:occupied.append({"id":g.id,"box":AABB(_v(g.bounds_min),_v(g.bounds_max)-_v(g.bounds_min))})
 var source:Dictionary={}
 for item in review.load_json(key+".json"):source[item.instance]=item
 var result:Dictionary={"placements":[],"services":[],"cups":[],"unresolved":[]}
 var used_approaches:Array=[]
 var used_hosts:Array=[]
 for suffix in ["D01","D03","D04","D05"]:
  var id:String=key+"_"+suffix
  if not source.has(id):continue
  var item:Dictionary=source[id]
  var preferred:String=str(item.support).get_slice(" | ",0)
  var model:Dictionary=review.index.models[str(int(item.catalog))]
  var service_type:String="COFFEE_NOOK" if suffix=="D01" else ("BAR" if suffix=="D03" else "")
  if suffix=="D03" and by_id.has(id):continue
  if by_id.has(id):
   # Existing verified bottle remains decorative; do not duplicate or promote
   # it without a new explicit measured bar source.
   continue
  var options:Array=hosts.duplicate()
  if service_type=="BAR":
   options=options.filter(func(h):return not used_hosts.has(h.id))
  elif service_type=="":
   var bar:Dictionary={}
   for s in result.services:
    if s.type=="BAR":bar=s
   if not bar.is_empty():preferred=bar.host
   options=options.filter(func(h):return h.id==preferred)
  options.sort_custom(func(a,b):return int(a.id!=preferred)<int(b.id!=preferred))
  var found:Dictionary={}
  for host in options:
   found=_pick(model,host,id,service_type!="",used_approaches)
   if not found.is_empty():break
  # A compact whiskey bottle is a real alternative bar marker if a
  # bottle rack cannot fit. Keep the original authored rack pending.
  if found.is_empty() and service_type=="BAR":
   var alternate:Dictionary=review.index.models[str(int(source[key+"_D04"].catalog))]
   for host in options:
    found=_pick(alternate,host,key+"_SERVICE_BAR",true,used_approaches)
    if not found.is_empty():break
  if found.is_empty():
   result.unresolved.append(id);continue
  result.placements.append(found);_accept(found)
  if service_type!="":
   result.services.append({"id":found.id,"type":service_type,"host":found.support_host,"approach":found.approach})
   used_hosts.append(found.support_host)
   used_approaches.append(Vector2(found.approach[0],found.approach[1]))
 # Put two real cups on free, reachable supports, not mere decorative
 # placeholders. Keep service approaches separate from cup pickup points.
 for i in range(2):
  var model:Dictionary=red if i==0 else blue
  var id:String=key+"_SERVICE_CUP_"+str(i+1)
  var found:Dictionary={}
  var options:Array=hosts.duplicate()
  options.sort_custom(func(a,b):return int(used_hosts.has(a.id))>int(used_hosts.has(b.id)))
  for host in options:
   found=_pick(model,host,id,true,used_approaches)
   if not found.is_empty():break
  if found.is_empty():result.unresolved.append(id);continue
  result.cups.append({"id":found.support_slot,"object_id":id,"asset":found.asset,"path":found.path,"xyz":found.contact,"instance_xyz":found.pivot,"furniture_id":found.support_host,"approach":found.approach,"scale":found.scale})
  _accept(found)
  used_approaches.append(Vector2(found.approach[0],found.approach[1]))
 return result

func _run()->void:
 if not _self_test() or not review.initialize():quit(1);return
 for m in review.index.models.values():
  if m.id==MUGS[0]:red=m
  if m.id==MUGS[1]:blue=m
 var f:=FileAccess.open(GRID_FILE,FileAccess.READ)
 if f==null:quit(2);return
 grid_doc=JSON.parse_string(f.get_as_text())
 var compiled_sha:Dictionary={}
 var source_sha:=FileAccess.get_sha256(REVIEW.SOURCE)
 var rooms:Dictionary={}
 for i in range(3):
  var path:String="res://data/interior_v2/dense_v2_compiled_%d.zip"%i
  compiled_sha[str(i)]=FileAccess.get_sha256(path)
  var z:=ZIPReader.new()
  if z.open(path)!=OK:quit(3);return
  var d=JSON.parse_string(z.read_file("compiled.json").get_string_from_utf8());z.close()
  if d.source_sha256!=source_sha:quit(4);return
  rooms.merge(d.rooms)
 for k in ROOM_KINDS:
  output[k]=_room(rooms[k],k)
  print("SERVICE_GEOMETRY ",k," sources=",output[k].services.size()," cups=",output[k].cups.size()," models=",output[k].placements.size()," unresolved=",output[k].unresolved)
 var out:=FileAccess.open("user://dense_v2_services_qa.json",FileAccess.WRITE)
 if out==null:quit(5);return
 out.store_string(JSON.stringify({"schema":1,"source_sha256":source_sha,"compiled_sha256":compiled_sha,"grid_sha256":FileAccess.get_sha256(GRID_FILE),"rooms":output}," "))
 out.close()
 quit(0)
