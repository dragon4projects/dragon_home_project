extends SceneTree
const F=preload("res://scripts/local_furniture_layout.gd")
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func near(a:Array,b:Array,d:Vector2)->bool:
 return F.vec(b).distance_to(F.vec(a)+Vector3(d.x,0,d.y))<.0001
func find_move(scene,kind:String)->Dictionary:
 var w=scene.world;var nav=scene.life.candidate_navigation
 for rid in scene.dense_v2.by_room:
  var entry:Dictionary=scene.dense_v2.by_room[rid]
  var room:Dictionary=w.room_by_id(rid)
  var c:Dictionary=entry.compiled
  for p in c.placements:
   if not F.allowed(c,p):continue
   var slots:Array=nav.book_slots(room).filter(func(x):return x.furniture_id==p.id)
   var links:Dictionary=F.linked(c,p.id)
   var seat:bool=p.get("station_candidates",[]).any(func(s):return s.kind=="seat")
   if kind=="seat" and not seat:continue
   if kind=="cup" and not nav.cup_slots(room).any(func(x):return x.furniture_id==p.id):continue
   if kind=="book" and slots.is_empty():continue
   if kind=="device" and not c.placements.any(func(x):return links.has(x.id) and str(x.id).contains("_I96_DECOR_") and c.key in ["L2_music","L2_cinema","L0_cinema"]):continue
   if kind=="book" and not w.runtime_state.get("teea008_book_slot_assignments",{}).values().any(func(x):return x.room_id==rid and slots.any(func(y):return y.id==x.slot_id)):continue
   for d in [Vector2(.05,0),Vector2(-.05,0),Vector2(.10,0),Vector2(-.10,0),Vector2(0,.05),Vector2(0,-.05),Vector2(.15,0),Vector2(-.15,0),Vector2(0,.10),Vector2(0,-.10)]:
    var next:=F.proposal(c,p.id,d)
    if next.is_empty():continue
    var row:=F.row_after(nav.layouts[entry.variant],next,p.id)
    if not F.safe_occupants(w,nav,room,row,p,F.find(next,p.id)) or not F.paths_preserved(nav,room,row) or not F.claims_preserved(scene,room,row,F.linked(c,p.id)):continue
    return {"rid":rid,"id":p.id,"delta":d}
 return {}
func verify_move(scene,kind:String)->bool:
 var choice:=find_move(scene,kind)
 if not must(not choice.is_empty(),"no valid "+kind+" fixture"):return false
 var rid:String=choice.rid;var id:String=choice.id;var d:Vector2=choice.delta
 var w=scene.world;var nav=scene.life.candidate_navigation
 var room:Dictionary=w.room_by_id(rid);var e:Dictionary=scene.dense_v2.by_room[rid]
 var before:Dictionary=e.compiled.duplicate(true)
 var old_row:Dictionary=nav.layouts[e.variant].duplicate(true)
 var assignments:Dictionary=w.runtime_state.get("teea008_book_slot_assignments",{}).duplicate(true)
 var catalog:Array=w.media.books.duplicate(true)
 var ids:=F.linked(before,id)
 var old_cups:Array=nav.cup_slots(room).filter(func(x):return x.furniture_id==id)
 var old_objects:Dictionary=w.objects.duplicate(true)
 # Inject a reserved claim into a test actor without moving the actor.
 if kind=="seat":
  var spots:Array=scene.life.stations.layout_for_world(w,room)
  for i in range(spots.size()):
   if spots[i].get("furniture_id","")!=id:continue
   var a:Dictionary=w.residents["RES_07"];var backup:Dictionary=a.duplicate(true)
   a["station_room_id"]=rid;a["station_slot"]=i;a["station_anchor_id"]=spots[i].id;a["station_point"]=[spots[i].offset.x,spots[i].offset.y]
   var rejected:bool=not F.commit(scene,rid,id,d)
   a.clear();a.merge(backup,true)
   if not must(rejected,"occupied/reserved seat edit accepted"):return false
   break
 if not must(F.commit(scene,rid,id,d),"commit failed "+kind):return false
 for p in before.placements:
  var now:=F.find(e.compiled,p.id)
  if not ids.has(p.id):continue
  if not must(near(p.pivot,now.pivot,d),"linked transform "+str(p.id)):return false
  for i in range(p.get("station_candidates",[]).size()):
   var a:Dictionary=p.station_candidates[i];var b:Dictionary=now.station_candidates[i]
   if not must(a.station_candidate_id==b.station_candidate_id,"station identity changed"):return false
   for field in ["room_pelvis_contact_xyz","room_feet_contact_xyz","room_local_xyz"]:
    if a.get(field,[]).size()==3 and not must(near(a[field],b[field],d),"contact didn't follow"):return false
 var books:=0
 for b in old_row.get("measured_book_slots",[]):
  if b.furniture_id!=id:continue
  var actual:Dictionary={}
  for q in nav.book_slots(room):
   if q.id==b.id:actual=q;break
  if not must(not actual.is_empty() and near(b.xyz,actual.xyz,d),"book slot didn't follow"):return false
  books+=1
 if not must(w.runtime_state.get("teea008_book_slot_assignments",{})==assignments and w.media.books==catalog,"book metadata changed"):return false
 var cup_count:=0
 if kind=="cup":
  for cup in old_cups:
   var new_slot:Dictionary={}
   for q in nav.cup_slots(room):
    if q.id==cup.id:new_slot=q;break
   if not must(not new_slot.is_empty() and near(cup.xyz,new_slot.xyz,d),"cup support not translated"):return false
   var obj:Dictionary=w.physical_object(cup.object_id)
   if not must(not obj.is_empty() and Vector2(obj.home_anchor[0],obj.home_anchor[1]).distance_to(Vector2(new_slot.xyz[0],new_slot.xyz[2]))<.0001 and Vector2(obj.current_anchor[0],obj.current_anchor[1]).distance_to(Vector2(new_slot.xyz[0],new_slot.xyz[2]))<.0001,"cup object anchors not translated"):return false
   cup_count+=1
  if not must(cup_count>0 and not w.runtime_state.has(F.CUP_TX.KEY),"pending transaction remained"):return false
 print("I97_LINKED_MOVE_PASS ",kind," room=",rid," host=",id," delta=",d," dependent_nodes=",ids.size()-1," book_slots=",books," cup_slots=",cup_count)
 return true
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var nav=scene.life.candidate_navigation
 if not must(scene.dense_services_qa and scene.dense_v2.by_room.size()==14,"scene not ready"):return
 if OS.get_environment("I97_RESTART")=="1":
  var offsets:Dictionary=w.runtime_state.get(F.KEY,{})
  var count:=0
  for rid in offsets:
   var e:Dictionary=scene.dense_v2.by_room[rid]
   for id in offsets[rid]:
    var d:Array=offsets[rid][id].delta
    var shift:=Vector2(d[0],d[1])
    for linked_id in F.linked(e.base_compiled,id):
     if not must(near(F.find(e.base_compiled,linked_id).pivot,F.find(e.compiled,linked_id).pivot,shift),"restart linked geometry"):return
    var room:Dictionary=w.room_by_id(rid)
    for b in nav.book_slots(room):
     if b.furniture_id==id and not must(F.vec(b.instance_xyz).distance_to(F.vec(F.find(e.compiled,id).pivot))<.0001,"restart book slot"):return
    for slot in nav.cup_slots(room):
     if slot.furniture_id!=id or not slot.has("object_id"):continue
     var obj:Dictionary=w.physical_object(slot.object_id)
     if not must(not obj.is_empty() and Vector2(obj.home_anchor[0],obj.home_anchor[1]).distance_to(Vector2(slot.xyz[0],slot.xyz[2]))<.0001,"restart cup home mismatch"):return
    count+=1
  if not must(count==4,"restart offset count "+str(count)):return
  print("I97_LINKED_RESTART_PASS edits=",count)
  quit(0);return
 for kind in ["seat","book","device","cup"]:
  if not verify_move(scene,kind):return
 print("I97_LINKED_FURNITURE_PASS")
 quit(0)
