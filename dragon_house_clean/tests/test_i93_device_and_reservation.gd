extends SceneTree
func _initialize()->void:call_deferred("run")
func must(v:bool,msg:String)->bool:
 if not v:push_error(msg);quit(2)
 return v
func select(scene,rid:String)->void:
 scene.selected_room=rid;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var stations=scene.life.stations
 if not must(scene.dense_services_qa and scene.complete_sprite_ready,"scene not ready"):return
 var rooms:Dictionary={}
 for rid in scene.dense_v2.by_room:
  rooms[scene.dense_v2.by_room[rid].compiled.key]=w.room_by_id(rid)
 var a:Dictionary=w.residents["RES_01"]
 var home:Dictionary=w.room_by_id(a.home_room_id)
 if not must(not stations.single(w,a,home,"SLEEP").is_empty(),"own home sleep"):return
 for r in w.rooms:
  if r.id!=a.home_room_id and not must(stations.single(w,a,r,"SLEEP").is_empty(),"foreign/public sleep claim"):return
 var lib:Dictionary=rooms.L2_library
 var points:Array=stations.layout_for_world(w,lib)
 if not must(points.size()>16,"physical stations retained"):return
 var actors:Array=w.residents.values().filter(func(x):return x.get("active",false))
 for actor in actors:stations.release(actor)
 for i in range(16):
  stations.commit_claim(actors[i],stations._claim(lib,i,points[i]))
  actors[i]["phase"]="perform"
 var next:Dictionary=actors[16]
 if not must(stations.available_count(w,lib)==0 and stations.single(w,next,lib,"REST").is_empty() and not stations.can_reserve_group(w,lib,next.id),"capacity guard"):return
 stations.release(actors[15])
 if not must(stations.available_count(w,lib)==1,"release capacity"):return
 for actor in actors:stations.release(actor);actor["phase"]="idle"
 print("I93_HOME_SLEEP_CAPACITY_PASS physical_stations=",points.size()," limit=16")
 var restart:bool=OS.get_environment("I93_RESTART")=="1"
 var film_id:="QA_I93_FILM"
 var track_id:="QA_I93_TRACK"
 var film_surface:="cinema.r3.film.screen"
 var audio_surface:="music.r3.audio.01"
 var player_surface:="music.r3.audio.now_playing"
 if not restart:
  var image:=Image.create_empty(400,250,false,Image.FORMAT_RGBA8);image.fill(Color("#815c53"))
  if not must(image.save_png("user://qa_i93_cover.png")==OK,"preview fixture"):return
  var f:=FileAccess.open("user://qa_i93_media.json",FileAccess.WRITE)
  f.store_string(JSON.stringify({"films":[{"id":film_id,"title":"QA film","runtime_seconds":100,"preview":"qa_i93_cover.png"}],"tracks":[{"id":track_id,"title":"QA audio","runtime_seconds":60,"preview":"qa_i93_cover.png"}]}));f.close()
  scene._import_media("user://qa_i93_media.json")
  scene._assign_teea008_media(rooms.L2_cinema.id,film_surface,"films",film_id)
  scene._assign_teea008_media(rooms.L2_music.id,player_surface,"tracks",track_id)
  if not must(w.save_world(),"save"):return
 for k in ["L2_cinema","L0_cinema","L2_music"]:
  var r:Dictionary=rooms[k];select(scene,r.id)
  var anchors:Array=get_nodes_in_group("teea008_media_surface").filter(func(n):return n.is_visible_in_tree() and n.get_meta("room_id","")==r.id and n.has_meta("dense_media_device") and not str(n.get_meta("dense_media_device","")).contains("_I96_"))
  var expected:int=2 if k=="L2_music" else 1
  if not must(anchors.size()==expected,"mounted devices "+k+" "+str(anchors.size())):return
  scene._update_teea008_media_previews()
  for anchor in anchors:
   var sid:String=anchor.get_meta("surface_id")
   var rec:Dictionary=scene.teea008_media_bindings.resolve(r.id,sid)
   if k=="L0_cinema":
    if not must(rec.is_empty(),"room binding leaked"):return
   else:
    if not must(rec.get("id","")== (track_id if k=="L2_music" else film_id),"binding missing "+sid):return
    if not must((anchor.get_node_or_null("BoundPreview")!=null)==not bool(anchor.get_meta("carrier_hit_only")),"physical preview "+sid):return
   if not must(scene.open_content_hotspot({"category":"teea008_surface","item_id":sid,"room_id":r.id}),"device click "+sid):return
   if not must(scene.media_panel.surface_room_id==r.id,"device panel"):return
  print("I93_DEVICE_ROOM ",k," devices=",anchors.size())
 print("I93_DEVICES_PASS restart=",restart," physical=4 exact_room_bindings=true no_playback=true")
 quit(0)
