extends "res://tests/audit_dense_v2_support_surfaces.gd"
const DESIGN=preload("res://scripts/dense_v2_owner_design.gd")
const RUNTIME=preload("res://scripts/dense_v2_runtime.gd")
const WORLD=preload("res://scripts/world_model.gd")
const LIB="res://assets/teea008_review/decor_bank/"
const DEC="res://assets/decor_bank/"
const TARGETS={
 "L0_cinema":[["F23","classic_laptop",LIB],["F27","owner_hp_notebook_lowpoly",DEC],["F30","classic_laptop",LIB],["F32","owner_hp_notebook_lowpoly",DEC]],
 "L2_cinema":[["F23","classic_laptop",LIB],["F27","owner_hp_notebook_lowpoly",DEC],["F30","classic_laptop",LIB],["F32","owner_hp_notebook_lowpoly",DEC]],
 "L2_music":[["F12","portable_cassette_player",LIB],["F14","cassette_player",LIB],["F17","classic_laptop",LIB],["F19","portable_cassette_player",LIB],["F22","cassette_player",LIB],["F24","portable_cassette_player",LIB],["F28","cassette_player",LIB],["F31","portable_cassette_player",LIB],["F32","classic_laptop",LIB],["F35","portable_cassette_player",LIB],["F37","cassette_player",LIB],["F39","portable_cassette_player",LIB],["F41","cassette_player",LIB],["F42","portable_cassette_player",LIB]],
 "L0_workshop":[["F08","blendkit_beaker_flask",DEC],["F12","blendkit_glass_ceramic_and_glass_pots",DEC],["F15","blendkit_dome_01_glass",DEC],["F17","blendkit_beaker_flask",DEC],["F20","blendkit_kitchen_set_6_glass_conteiner_2",DEC],["F21","blendkit_beaker_flask",DEC],["F24","blendkit_decorational_glass_cover_storage",DEC],["F29","classic_laptop",LIB],["F03","blendkit_beaker_flask",DEC],["F10","blendkit_dome_01_glass",DEC]]
}
func _place(room:Dictionary,host:Dictionary,asset:String,path:String,occupied:Array,idx:int)->Dictionary:
 var geometry:=_geometry(host)
 if geometry.is_empty():return {}
 var pivot:=_v(host.pivot)
 var hb:=_box(host)
 var yaw:float=float(host.yaw)
 var m:Dictionary=review.measured_bounds(path,yaw)
 if m.is_empty():return {}
 var mb:AABB=m.bounds
 # Retain model aspect and use room depth scale. Caps are a physical
 # width limit for portable objects, not a fabricated surface.
 var scale:float=minf(float(host.scale),.43/maxf(mb.size.x,mb.size.z))
 var size:Vector3=mb.size*scale
 if size.x<.045 or size.z<.035:return {}
 for ix in [0.5,0.25,0.75,0.15,0.85,0.35,0.65]:
  for iz in [0.5,0.25,0.75,0.35,0.65]:
   var x:float=hb.position.x+hb.size.x*float(ix)
   var z:float=hb.position.z+hb.size.z*float(iz)
   var hits:Array=_hits(geometry,Vector2(x-pivot.x,z-pivot.z))
   hits.reverse()
   for hit in hits:
    var y:float=float(hit.y)+pivot.y
    if not hit.flat or y<.24 or y>1.75:continue
    var at:=Vector3(x,y,z)
    var bb:=AABB(at-Vector3(size.x*.5,0,size.z*.5),size)
    if bb.end.y>2.85:continue
    if occupied.any(func(o):return o.id!=host.id and bb.grow(.015).intersects(o.box)):continue
    if not _probe(geometry,at-pivot,size):continue
    if not _host_clear(geometry,AABB(bb.position-pivot,bb.size)):continue
    var center:=mb.get_center()
    var pos:=at-Vector3(center.x,mb.position.y,center.z)*scale
    return {"id":room.key+"_I96_DECOR_%02d"%idx,"asset":asset,"path":path,"role":"supported_decor","fits":true,"scale":scale,"yaw":yaw,"pivot":_a(pos),"bounds_min":_a(bb.position),"bounds_max":_a(bb.end),"support_host":host.id,"host_asset":host.asset,"host_pivot":host.pivot,"host_scale":host.scale,"host_yaw":host.yaw,"evidence":"ACTUAL_TRIANGLE_SUPPORT_CLEARANCE"}
 return {}
func _run()->void:
 if not review.initialize() or not _self_test():quit(1);return
 var w=WORLD.new();w.canonical_house_seed=true;w.seed_world()
 var runtime=RUNTIME.new()
 var layouts:Dictionary={}
 if not runtime.install(w,layouts,true):quit(2);return
 var results:Dictionary={}
 for rid in runtime.by_room:
  var room:Dictionary=runtime.by_room[rid].compiled
  if not TARGETS.has(room.key):continue
  var occupied:Array=[]
  var hosts:Dictionary={}
  for p in room.placements:
   hosts[p.id]=p
   if p.get("fits",false) and p.has("bounds_min"):occupied.append({"id":p.id,"box":_box(p)})
   # Reserve all authored and dynamically registered support slots.
   for s in p.get("support_slots",[]):
    if s.get("room_xyz",[]).size()!=3 or s.get("max_dimensions_m",[]).size()!=3:continue
    var size:=_v(s.max_dimensions_m);var at:=_v(s.room_xyz)
    occupied.append({"id":s.room_slot_id,"box":AABB(at-Vector3(size.x*.5,0,size.z*.5),size)})
  for c in room.get("service_cups",[]):
   var at:=_v(c.xyz)
   occupied.append({"id":c.id,"box":AABB(at-Vector3(.12,0,.12),Vector3(.24,.20,.24))})
  var additions:Array=[]
  var withheld:Array=[]
  var idx:=0
  for spec in TARGETS[room.key]:
   idx+=1
   var host:Dictionary=hosts.get(room.key+"_"+str(spec[0]),{})
   if host.is_empty():continue
   var p:=_place(room,host,str(spec[1]),str(spec[2])+str(spec[1])+"/model.gltf",occupied,idx)
   if p.is_empty():
    withheld.append(spec[0]);continue
   additions.append(p);occupied.append({"id":p.id,"box":_box(p)})
  results[room.key]={"placements":additions,"withheld_hosts":withheld}
  print("I96_DECOR ",room.key," placed=",additions.size()," withheld=",withheld)
 var sources:Dictionary={}
 for path in [REVIEW.SOURCE,RUNTIME.SERVICES.PATH,RUNTIME.BOOKS.PATH,RUNTIME.SEATS.PATH,"res://data/interior_v2/dense_v2_compiled_0.zip","res://data/interior_v2/dense_v2_compiled_1.zip","res://data/interior_v2/dense_v2_compiled_2.zip"]:
  sources[path]=FileAccess.get_sha256(path)
 var f:=FileAccess.open("user://owner_design_qa.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"schema":1,"sources":sources,"rooms":results}," "));f.close()
 print("I96_DECOR_AUDIT_PASS")
 quit(0)
