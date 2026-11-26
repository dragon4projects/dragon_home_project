extends SceneTree
func _initialize()->void:call_deferred("run")
func require(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var life=scene.life
 var cups=life.candidate_cups
 var actor:Dictionary=w.residents["RES_01"]
 actor["active"]=true
 var rooms:=0
 var completed:=0
 var total_steps:=0
 for id in scene.dense_v2.by_room:
  var room:Dictionary=w.room_by_id(id)
  var row:Dictionary=life.candidate_navigation.layouts[life.candidate_navigation.key(room)]
  if not row.has("service_sources"):continue
  rooms+=1
  var center:Vector3=w.room_center_pos(room)
  for drink in ["RED_WINE","ESPRESSO"]:
   life.stations.release(actor)
   life._clear_cup_task(actor)
   # Independent scenario begins at a legitimate entry, then uses the
   # normal task assignment and movement; no teleport to a source.
   actor["room_id"]=room.id;actor["level"]=room.level
   actor["x"]=center.x;actor["visual_y"]=center.y;actor["z"]=1.5
   actor["phase"]="idle"
   actor.erase("social_session_id");actor.erase("social_join_session_id")
   cups.beverages.forced_drinks[actor.id]=drink
   life._assign(actor,{"room":room,"intent":"GET_COFFEE"})
   if not require(actor.get("cup_task_stage","")=="fetch","fetch task "+str(id)):return
   var cup_id:String=str(actor.cup_task_id)
   var served:=false
   for i in range(2400):
    life.clock+=.125;w.sim_clock=life.clock;life._move(actor,.125);total_steps+=1
    if actor.get("cup_task_stage","")=="serve":
     served=true
     if not require(float(cups.beverages.content(cup_id).get("remaining_ml",0))==0,"filled before arrival"):return
    if actor.get("cup_task_stage","")=="hold":break
   if not require(served and actor.get("cup_task_stage","")=="hold","service movement failed "+str(id)+" "+drink+" "+str(actor.get("cup_task_stage",""))):return
   if not require(cups.beverages.content(cup_id).get("content_id","")==drink,"wrong drink "+str(id)+" "+drink):return
   if not require(cups.beverages.sip(cup_id,actor.id),"sip failed"):return
   actor["drink_sips_left"]=0;actor.erase("drink_service_id")
   if not require(life._route_cup_return(actor),"no return route "+str(id)):return
   for i in range(2400):
    life.clock+=.125;w.sim_clock=life.clock;life._move(actor,.125);total_steps+=1
    if actor.get("phase","")!="travel":break
   if not require(cups.put_back(actor),"return failed "+str(id)):return
   if not require(w.physical_object(cup_id).get("current_holder_id","")=="","cup still held"):return
   cups.beverages.empty_cup(cup_id)
   life._clear_cup_task(actor);life.stations.release(actor)
   completed+=1
  print("SERVICE_WALK ",room.id," coffee_and_bar=true")
 if not require(rooms==11 and completed==22,"coverage mismatch"):return
 print("DENSE_SERVICE_WALK_PASS rooms=",rooms," complete_routes=",completed," movement_steps=",total_steps)
 quit(0)
