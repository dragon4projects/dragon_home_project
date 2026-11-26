extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 assert(scene.dense_v2_qa and scene.dense_v2.by_room.size()>=11)
 assert(scene.world.save_path=="user://dragon_house_dense_services_qa_v1.json")
 var w=scene.world;var l=scene.life;var nav=l.candidate_navigation
 var routes:=0;var failures:Array=[];var seats:Dictionary={}
 for id in scene.dense_v2.by_room:
  var room:Dictionary=w.room_by_id(id)
  assert(nav.key(room)==scene.dense_v2.by_room[id].variant)
  var points:Array=nav.candidate_spots(room)
  var valid_seats:=0
  for spot in points:
   for x in [-float(room.size_modules)*2.4+.08,float(room.size_modules)*2.4-.08]:
    routes+=1
    if nav.path(room,Vector2(x,1.5),spot.offset).is_empty():failures.append({"room":id,"station":spot.id,"from":x})
   if spot.kind=="seat":valid_seats+=1
  seats[scene.dense_v2.by_room[id].compiled.key]=valid_seats
  for band in [1,3,5]:
   assert(nav.segment_clear(room,Vector2(-float(room.size_modules)*2.4+.08,scene.Depth7Space.center(band)),Vector2(float(room.size_modules)*2.4-.08,scene.Depth7Space.center(band))))
 print("DENSE_V2_ROUTE_AUDIT routes=",routes," failures=",failures," seats=",seats)
 var invalid_positions:=0;var visits:Dictionary={};var sampled:=0
 var cup_events_before:int=w.object_events.store.last_sequence()
 var cup_phases:Dictionary={}
 for i in range(2400):
  l.tick(.125)
  if i%4!=0:continue
  for actor in w.residents.values():
   if str(actor.get("cup_task_id","")).contains("_SERVICE_CUP_"):
    var stage:String=str(actor.get("cup_task_stage",""))
    cup_phases[stage]=int(cup_phases.get(stage,0))+1
  for actors in [w.residents,w.creatures]:
   for a in actors.values():
    if not a.get("active",false):continue
    var room:Dictionary=w.room_by_id(str(a.get("room_id","")))
    if room.is_empty() or not scene.dense_v2.has_room(room.id):continue
    var point:Vector2=w.room_world_to_local(room,Vector3(float(a.x),float(a.get("visual_y",0)),float(a.z)))
    if absf(point.x)>float(room.size_modules)*2.4:continue
    sampled+=1;visits[room.id]=true
    if not nav.clear(room,point):invalid_positions+=1
 assert(sampled>0)
 print("DENSE_V2_LIVE_QA samples=",sampled," visited_rooms=",visits.size()," blocked_positions=",invalid_positions," route_failures=",failures.size()," clock=",l.clock)
 print("DENSE_SERVICE_AUTONOMY phases=",cup_phases," events_before=",cup_events_before," events_after=",w.object_events.store.last_sequence())
 assert(w.dense_artifact_world.validate_projection(w.objects))
 assert(w.save_world())
 # Fresh QA only: never treat this as production migration or release acceptance.
 quit(0 if failures.is_empty() and invalid_positions==0 else 2)
