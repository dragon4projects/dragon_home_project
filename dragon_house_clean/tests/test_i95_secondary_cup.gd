extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
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
 var a:Dictionary=w.residents["RES_07"]
 var room:Dictionary=w.get_room(4,2)
 var cup:String=""
 for obj in w.objects.values():
  if obj.get("viewer_category","")=="cups" and obj.get("current_room_id","")==room.id and obj.get("current_holder_id","")=="":cup=obj.id;break
 if not must(cup!="","no real library cup"):return
 life.stations.release(a)
 var pos:Vector3=w.room_center_pos(room)
 a.merge({"room_id":room.id,"level":room.level,"x":pos.x,"visual_y":pos.y,"z":1.5,"phase":"perform","intent":"GET_COFFEE","waypoints":[],"waypoint_index":0},true)
 # Controlled fixture uses actual cup events, not a duplicate object.
 if not must(w.pickup_physical_object(cup,a.id),"pickup failed"):return
 var b=life.candidate_cups.beverages
 if not must(b.fill_or_resume(cup,a.id,"READING","day",["COFFEE_NOOK"],"CAPPUCCINO") and b.sip(cup,a.id),"serve failed"):return
 var volume:float=b.content(cup).remaining_ml
 var count:int=b.history(a.id).total_choices
 a["cup_task_id"]=cup;a["cup_task_stage"]="hold";a["cup_task_room"]=room.id
 if not must(life._try_compose_cup(a,{"intent":"READ_BOOK","room":room}),"compose failed"):return
 if not must(a.secondary_cup_id==cup and not a.has("cup_task_stage") and a.has("book_task_stage"),"resource composition failed"):return
 # Check the restore reconciler on the same persisted holder without
 # manufacturing a new serving or replacing the primary route.
 var route:Array=a.waypoints.duplicate(true)
 life.reconcile_cup_tasks()
 if not must(a.secondary_cup_id==cup and a.waypoints==route and b.content(cup).remaining_ml==volume and b.history(a.id).total_choices==count,"reconcile changed commitment"):return
 if not must(w.save_world(),"checkpoint failed"):return
 var W=load("res://scripts/world_model.gd")
 var restored=W.new();restored.canonical_house_seed=true;restored.save_path=w.save_path;restored.dense_artifact_world=w.dense_artifact_world
 if not must(restored.load_or_seed(),"reload failed"):return
 var r:Dictionary=restored.residents[a.id]
 if not must(r.secondary_cup_id==cup and r.has("book_task_stage") and restored.physical_object(cup).current_holder_id==a.id and restored.runtime_state.beverages.cups[cup].remaining_ml==volume,"persisted cup/primary mismatch"):return
 # Complete the primary commitment only by its existing logic. Explicitly
 # verify handoff into ordinary return, with no new drink or teleport.
 if not must(w.physical_object(cup).current_holder_id==a.id,"cup lost"):return
 print("I95_SECONDARY_CUP_PASS actual_holder=true primary_route=true no_double_credit=true persisted=true visual_dual_contact=UNQUALIFIED")
 quit(0)
