extends SceneTree
func _initialize()->void:call_deferred("run")
func require(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func at(world,actor:Dictionary,room:Dictionary,p:Vector2)->void:
 var v:Vector3=world.room_local_to_world(room,p)
 actor["room_id"]=room.id;actor["x"]=v.x;actor["visual_y"]=v.y;actor["z"]=v.z
 actor["phase"]="perform"
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 if not require(scene.dense_services_qa and w.save_path=="user://dragon_house_dense_services_qa_v1.json","QA services mode"):return
 var life=scene.life
 var nav=life.candidate_navigation
 var cups=life.candidate_cups
 var actor:Dictionary=w.residents["RES_01"]
 actor["active"]=true
 var count:=0
 var source_count:=0
 var cup_count:=0
 var routes:=0
 var actual_mounts:=0
 var lifecycle:=0
 var restart:bool=OS.get_environment("DRAGON_SERVICE_RESTART")=="1"
 for id in scene.dense_v2.by_room:
  var room:Dictionary=w.room_by_id(id)
  var row:Dictionary=nav.layouts[nav.key(room)]
  if not row.has("service_sources"):continue
  count+=1
  var slots:Array=nav.cup_slots(room)
  var sources:Array=cups.service_sources(actor,room)
  if not require(slots.size()==2 and sources.size()==2,"missing services or cup slots "+str(id)):return
  var parent:=Node3D.new()
  root.add_child(parent)
  var compiled:Dictionary=scene.dense_v2.by_room[id].compiled
  var equipment:Array=compiled.placements.filter(func(p):return p.get("review_status","")=="I89_SERVICE_MEASURED")
  if not require(scene.dense_v2.review.mount_review(parent,{"placements":equipment})==equipment.size(),"mount failed "+str(id)):return
  actual_mounts+=equipment.size()
  parent.free()
  for source in sources:
   source_count+=1
   for x in [-7.12,7.12]:
    if not require(not nav.path(room,Vector2(x,1.5),source.approach).is_empty(),"service path "+str(source.id)):return
    routes+=1
  for slot in slots:
   cup_count+=1
   var obj:Dictionary=w.physical_object(slot.object_id)
   if not require(not obj.is_empty() and obj.get("viewer_category","")=="cups" and obj.home_room_id==id and cups.slot_for_object(obj).get("id","")==slot.id,"cup identity "+str(slot.object_id)):return
   var claim:Dictionary=life.stations.cup_claim(w,actor,room,slot.id)
   if not require(not claim.is_empty(),"cup claim "+str(slot.id)):return
   for x in [-7.12,7.12]:
    if not require(not nav.path(room,Vector2(x,1.5),claim.offset).is_empty(),"cup path "+str(slot.id)):return
    routes+=1
   if restart:continue
   # Each fixture uses actual event gate pickup, service source validation,
   # drink plan/fill, sip and return. Teleport only the test actor to the
   # measured approach; a separate live run exercises natural motion.
   life.stations.commit_claim(actor,claim)
   actor["cup_task_id"]=slot.object_id;actor["cup_task_room"]=id;actor["cup_task_slot"]=slot.id;actor["cup_task_stage"]="fetch"
   at(w,actor,room,slot.approach)
   if not require(cups.pickup(actor),"pickup "+str(slot.object_id)):return
   var target_type:String="COFFEE_NOOK" if slot==slots[0] else "BAR"
   var selected:Dictionary={}
   for source in sources:
    if source.type==target_type:selected=source
   var plan:Dictionary=cups.beverages.plan_new(slot.object_id,actor.id,"GENERIC","morning",[target_type])
   if not require(not plan.is_empty() and plan.source_station==target_type,"beverage planning "+str(id)):return
   actor["cup_task_stage"]="serve";actor["drink_service_id"]=selected.id;actor["drink_service_plan"]=plan
   actor["drink_service_approach"]=[selected.approach.x,selected.approach.y]
   at(w,actor,room,selected.approach)
   if not require(cups.service_plan_valid(actor,true),"service source qualification "+str(id)):return
   life._complete_drink_service(actor)
   if not require(float(cups.beverages.content(slot.object_id).get("remaining_ml",0))>0 and cups.beverages.sip(slot.object_id,actor.id),"fill/sip "+str(id)):return
   life.stations.commit_claim(actor,claim)
   actor["cup_task_stage"]="return"
   at(w,actor,room,slot.approach)
   if not require(cups.put_back(actor),"cup return "+str(id)):return
   life._clear_cup_task(actor)
   life.stations.release(actor)
   lifecycle+=1
  print("DENSE_SERVICE_ROOM ",compiled.key," sources=2 cups=2")
 if not require(count==11 and source_count==22 and cup_count==22 and routes==88,"unexpected service coverage"):return
 if restart:
  for obj in w.objects.values():
   if str(obj.get("id","")).contains("_SERVICE_CUP_") and not require(float(cups.beverages.content(obj.id).get("remaining_ml",0))>0,"lost beverage content "+str(obj.id)):return
 if not require(w.save_world(),"save failed"):return
 print("DENSE_SERVICES_PASS rooms=",count," sources=",source_count," cups=",cup_count," routes=",routes," equipment_mounts=",actual_mounts," lifecycle=",lifecycle," restart=",restart)
 quit(0)
