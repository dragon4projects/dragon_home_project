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
 var w=scene.world;var life=scene.life;var nav=life.candidate_navigation
 if not must(scene.dense_services_qa and scene.complete_sprite_ready,"scene not ready"):return
 var total:=0
 for id in ["RES_04","RES_07"]:
  var actor:Dictionary=w.residents[id]
  for state in ["READ_E","READ_W"]:
   if not must(scene.asset_banks.frame_count(id,"HOME",state)==1 and not nav.pose_profile(actor,state).is_empty(),"missing side read "+id+state):return
   var tex:Texture2D=scene.asset_banks.texture_for(id,"HOME",state,0)
   if not must(tex!=null and tex.get_size()==Vector2(512,512),"decode "+id+state):return
   var matched:=false
   for room in w.matching_rooms(["library"]):
    if not scene.dense_v2.has_room(room.id):continue
    var spots:Array=life.stations.layout_for_world(w,room)
    for i in range(spots.size()):
     var spot:Dictionary=spots[i]
     var c:Dictionary=nav.pose_contact(actor,spot,"READ_BOOK")
     if c.get("state","")!=state:continue
     var claim:Dictionary=life.stations._candidate_claim(actor,room,i,spot,"READ_BOOK")
     if claim.is_empty():continue
     life.stations.release(actor);life.stations.commit_claim(actor,claim)
     var at:Vector3=w.room_local_to_world(room,spot.offset)
     actor["room_id"]=room.id;actor["level"]=room.level;actor["x"]=at.x;actor["z"]=at.z;actor["visual_y"]=at.y;actor["phase"]="perform";actor["intent"]="READ_BOOK"
     scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
     scene.update_residents(0)
     if not must(scene._active_station_render_contact(actor).get("state","")==state,"actual contact "+id+state):return
     if not must(scene.actor_animations[id].state==state,"render state "+id+state):return
     if not must(scene.actor_sprites[id].get_node("Body").texture==tex,"render texture "+id+state):return
     total+=1;matched=true
     print("I93_READ_CONTACT ",id," ",state," station=",spot.id)
     break
    if matched:break
   if not must(matched,"no compatible side seat "+id+state):return
   life.stations.release(actor);actor["phase"]="idle"
 print("I93_SIDE_READ_PASS bank_frames=4 actual_render_contacts=",total)
 quit(0)
