extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://dragon_house_dense_services_qa_v1.json"))
 var start:float=expected.sim_clock
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life;var nav=life.candidate_navigation
 if not must(is_equal_approx(w.sim_clock,start) and is_equal_approx(life.clock,start),"clock mismatch"):return
 for room in expected.rooms:
  var restored:Dictionary=w.room_by_id(str(room.id))
  if not must(not restored.is_empty() and restored.type==room.type and restored.level==room.level,"topology mismatch"):return
 if not must(w.residents.size()==expected.residents.size() and w.objects.size()==expected.objects.size(),"roster or object count mismatch"):return
 var cups:=0
 for id in expected.residents:
  if not must(w.residents.has(id),"missing actor"):return
  var cup:String=str(expected.residents[id].get("secondary_cup_id",""))
  if cup!="":
   if not must(str(w.residents[id].get("secondary_cup_id",""))==cup and str(w.physical_object(cup).get("current_holder_id",""))==id,"secondary cup recovery mismatch"):return
   cups+=1
 for id in expected.objects:
  if not must(w.objects.has(id) and w.objects[id].get("current_holder_id","")==expected.objects[id].get("current_holder_id",""),"object holder mismatch "+str(id)):return
 var samples:=0
 for tick in range(960):
  life.tick(.125)
  if not must(w.checkpoint_if_due(),"checkpoint failed"):return
  for holders in life.canonical_lifts.occupied.values():
   if not must(holders.size()<=6,"lift overflow"):return
  for a in w.residents.values():
   if not bool(a.get("active",false)):continue
   var room:Dictionary=w.room_by_id(str(a.get("room_id","")))
   if not must(not room.is_empty(),"lost room"):return
   var y:float=float(a.get("visual_y",float(room.level)*w.FLOOR_H))
   if absf(y-float(room.level)*w.FLOOR_H)>.05:
    if not must(room.type=="lift","non-lift vertical movement"):return
    continue
   var p:Vector2=w.room_world_to_local(room,Vector3(float(a.x),y,float(a.z)))
   if absf(p.x)>float(room.size_modules)*2.4:continue
   if nav.has_layout(room):
    if not must(nav.clear(room,p),"invalid position "+str(a.id)):return
    samples+=1
 if not must(is_equal_approx(life.clock,start+120) and w.save_world(),"continued clock or save failure"):return
 print("I95_FULL_WORLD_RESTART_PASS start=",start," end=",life.clock," residents=",w.residents.size()," objects=",w.objects.size()," recovered_secondary_cups=",cups," samples=",samples," paths=",nav.path_calls," failures=",nav.path_failures)
 quit(0)
