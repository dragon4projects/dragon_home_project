extends SceneTree
func _initialize()->void:call_deferred("run")
func must(v:bool,msg:String)->bool:
 if not v:push_error(msg);quit(2)
 return v
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var m=scene.life.media_runtime;var st=scene.life.stations
 if not must(scene.dense_services_qa and scene.complete_sprite_ready,"scene"):return
 var rooms:Dictionary={}
 for rid in scene.dense_v2.by_room:rooms[scene.dense_v2.by_room[rid].compiled.key]=w.room_by_id(rid)
 var f:=FileAccess.open("user://qa_i93_active.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"films":[{"id":"QA_I93_PIN","title":"Pinned","runtime_seconds":90,"preview":"qa_i93_cover.png"},{"id":"QA_I93_ACTIVE","title":"Active movie","runtime_seconds":100,"preview":"qa_i93_active.png"}],"tracks":[{"id":"QA_I93_ACTIVE_TRACK","title":"Active audio","runtime_seconds":60,"preview":"qa_i93_active.png"}]}));f.close()
 var im:=Image.create_empty(320,180,false,Image.FORMAT_RGBA8);im.fill(Color("#633425"));im.save_png("user://qa_i93_cover.png");im.fill(Color("#325e86"));im.save_png("user://qa_i93_active.png")
 scene._import_media("user://qa_i93_active.json")
 var cinema:Dictionary=rooms.L2_cinema;var music:Dictionary=rooms.L2_music
 scene._assign_teea008_media(cinema.id,"cinema.r3.film.screen","films","QA_I93_PIN")
 var specs:Array=[[cinema,"WATCH_FILM","films","QA_I93_ACTIVE","RES_04"],[music,"LISTEN_MUSIC","tracks","QA_I93_ACTIVE_TRACK","RES_07"]]
 for p in specs:
  var a:Dictionary=w.residents[p[4]]
  st.release(a);m.cancel_timed_media(a,w.sim_clock)
  var claim:Dictionary=st.single(w,a,p[0],p[1])
  if not must(not claim.is_empty(),"no real station "+p[1]):return
  st.commit_claim(a,claim)
  var pos:Vector3=w.room_local_to_world(p[0],claim.offset)
  a["phase"]="perform";a["intent"]=p[1];a["room_id"]=p[0].id;a["level"]=p[0].level;a["x"]=pos.x;a["z"]=pos.z;a["visual_y"]=pos.y
  a["activity_media_category"]=p[2];a["activity_media_id"]=p[3]
  if not must(m.begin_watch(a,w.sim_clock) if p[2]=="films" else m.begin_listen(a,w.sim_clock),"begin media "+p[2]):return
  scene.selected_room=p[0].id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
  scene._update_teea008_media_previews()
  var found:=0
  for anchor in get_nodes_in_group("teea008_media_surface"):
   if not anchor.is_visible_in_tree() or anchor.get_meta("room_id","")!=p[0].id or not anchor.has_meta("dense_media_device") or str(anchor.get_meta("dense_media_device","")).contains("_I96_"):continue
   var rec:Dictionary=scene.teea008_media_bindings.resolve(p[0].id,anchor.get_meta("surface_id"))
   if not must(rec.get("id","")==p[3],"active preview priority"):return
   if not anchor.get_meta("carrier_hit_only",false):
    if not must(anchor.get_node_or_null("BoundPreview")!=null and anchor.get_meta("preview_source","")==rec.preview,"preview actual resource"):return
   found+=1
  if not must(found==(1 if p[2]=="films" else 2),"active mounted count"):return
  m.cancel_timed_media(a,w.sim_clock);st.release(a);a["phase"]="idle"
 if not must(scene.teea008_media_bindings.resolve(cinema.id,"cinema.r3.film.screen").get("id","")=="QA_I93_PIN","pinned restored after end"):return
 if not must(scene.teea008_media_bindings.resolve(rooms.L0_cinema.id,"cinema.r3.film.screen").is_empty(),"independent second cinema"):return
 print("I93_ACTIVE_DEVICE_PASS film_and_audio=true active_over_pin=true independent_cinema=true")
 quit(0)
