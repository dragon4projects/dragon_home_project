extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func move(life,a:Dictionary)->bool:
 for i in range(6000):
  if a.get("phase","")!="travel":return true
  life.clock+=.125;life.world.sim_clock=life.clock
  life._move(a,.125)
 return false
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life
 var a:Dictionary=w.residents["RES_07"]
 var b=life.candidate_cups.beverages
 if OS.get_environment("DRAGON_I95_CUP_RESTART")!="1":
  var room:Dictionary=w.get_room(4,2)
  var cup:String=""
  for obj in w.objects.values():
   if obj.get("viewer_category","")=="cups" and obj.get("current_room_id","")==room.id and obj.get("current_holder_id","")=="":cup=obj.id;break
  if not must(cup!="","no cup"):return
  life.stations.release(a)
  var pos:Vector3=w.room_center_pos(room)
  a.merge({"room_id":room.id,"level":room.level,"x":pos.x,"visual_y":pos.y,"z":1.5,"phase":"perform","intent":"GET_COFFEE","waypoints":[],"waypoint_index":0},true)
  if not must(w.pickup_physical_object(cup,a.id) and b.fill_or_resume(cup,a.id,"READING","day",["COFFEE_NOOK"],"CAPPUCCINO") and b.sip(cup,a.id),"cup setup"):return
  a["cup_task_id"]=cup;a["cup_task_stage"]="hold";a["cup_task_room"]=room.id
  if not must(life._try_compose_cup(a,{"intent":"READ_BOOK","room":room}),"compose"):return
  if not must(move(life,a) and a.get("intent","")=="READ_BOOK" and a.get("phase","")=="perform" and life.media_runtime.reading_session_valid(a,life.clock),"actual book arrival"):return
  if not must(w.physical_object(cup).current_holder_id==a.id and a.secondary_cup_id==cup,"two resources not held"):return
  if not must(w.save_world(),"save"):return
  print("I95_CUP_READING_SAVED cup=",cup," book=",a.held_book," clock=",life.clock," until=",a.until)
  quit(0);return
 var cup:String=str(a.get("secondary_cup_id",""))
 var book:String=str(a.get("held_book",""))
 if not must(cup!="" and book!="" and a.get("intent","")=="READ_BOOK" and life.media_runtime.reading_session_valid(a,life.clock) and w.physical_object(cup).current_holder_id==a.id,"full scene recovery failed"):return
 var volume:float=b.content(cup).remaining_ml
 var count:int=b.history(a.id).total_choices
 var before:float=float(life.media_runtime._lookup("books",book).get("progress_by_actor",{}).get(a.id,0))
 # Finish the already saved reading slice using the authoritative clock.
 life.clock=float(a.until)+.01;w.sim_clock=life.clock
 life._process_due_actor(a.id,"QA_READ_COMPLETED")
 if not must(move(life,a) and not a.has("held_book") and a.secondary_cup_id==cup,"book return failed"):return
 if not must(float(life.media_runtime._lookup("books",book).get("progress_by_actor",{}).get(a.id,0))>before,"reading progress not credited"):return
 life.clock=maxf(life.clock,float(a.get("until",0)))+.1;w.sim_clock=life.clock
 life._process_due_actor(a.id,"QA_RETURN_SECONDARY")
 if not must(move(life,a),"cup return route failed"):return
 life.clock=maxf(life.clock,float(a.get("until",0)))+.1;w.sim_clock=life.clock
 life._process_due_actor(a.id,"QA_PLACE_SECONDARY")
 if not must(w.physical_object(cup).current_holder_id=="" and not a.has("secondary_cup_id") and b.content(cup).remaining_ml==volume and b.history(a.id).total_choices==count,"cup not returned or beverage changed"):return
 print("I95_CUP_READING_CYCLE_PASS full_scene_restart=true reading_progress=true physical_return=true no_double_credit=true")
 quit(0)
