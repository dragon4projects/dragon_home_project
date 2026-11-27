extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func catalog(d:Dictionary)->void:
 var f:=FileAccess.open("user://qa_i91_manifest.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(d));f.close()
func select_room(scene,rid:String)->void:
 scene.selected_room=rid;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod();scene.update_physical_objects()
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var m=scene.life.media_runtime
 if not must(scene.dense_services_qa and scene.complete_sprite_ready,"I90 scene unavailable"):return
 var restart:bool=OS.get_environment("I91_RESTART")=="1"
 var rid:String=w.dense_artifact_world.room_id
 select_room(scene,rid)
 var holders:Array=get_nodes_in_group("dense_v2_wall_holder").filter(func(n):return n.is_visible_in_tree() and str(n.get_meta("room_id",""))==rid)
 holders.sort_custom(func(a,b):return str(a.get_meta("slot_id",""))<str(b.get_meta("slot_id","")))
 if not must(holders.size()>=2,"real frame holders missing"):return
 var painting:MeshInstance3D=holders[0]
 var poster:MeshInstance3D=holders[1]
 var pid:String=painting.get_meta("slot_id")
 var qid:String=poster.get_meta("slot_id")
 var src1:="user://qa_i91_painting.jpg"
 var src2:="user://qa_i91_poster.png"
 var src3:="user://qa_i91_artifact.webp"
 var state_path:="user://qa_i91_fixture_ids.json"
 var state:Dictionary={}
 if not restart:
  var img:=Image.create_empty(800,400,false,Image.FORMAT_RGB8);img.fill(Color("#9966aa"))
  if not must(img.save_jpg(src1,.9)==OK,"painting fixture"):return
  img=Image.create_empty(300,900,false,Image.FORMAT_RGBA8);img.fill(Color("#245a65"))
  if not must(img.save_png(src2)==OK,"poster fixture"):return
  img=Image.create_empty(900,450,false,Image.FORMAT_RGBA8);img.fill(Color("#994633"))
  if not must(img.save_webp(src3)==OK,"artifact fixture"):return
  catalog({"books":[{"id":"QA_I91_SCENE_BOOK","title":"QA scene book","preview":"qa_i91_painting.jpg"}],"films":[{"id":"QA_I91_SCENE_FILM","title":"QA scene film","runtime_seconds":150,"preview":"qa_i91_painting.jpg"}],"tracks":[{"id":"QA_I91_SCENE_TRACK","title":"QA scene track","runtime_seconds":45,"preview":"qa_i91_poster.png"}]})
  scene._import_media("user://qa_i91_manifest.json")
  if not must(m._lookup("films","QA_I91_SCENE_FILM").get("local_import_v1",false),"new media button path not registered"):return
  scene._import_media("user://qa_i91_manifest.json")
  if not must(w.media.films.filter(func(x):return x.id=="QA_I91_SCENE_FILM").size()==1,"reimport duplicate"):return
  for pair in [[pid,src1,"paintings","QA Painting"],[qid,src2,"posters","QA Poster"]]:
   if not must(scene.open_content_hotspot({"category":"dense_v2_frame","item_id":pair[0]}) and scene.content_viewer.artwork_kind.visible,"frame assignment affordance"):return
   scene.dense_v2_pending_frame=pair[0]
   scene.dense_v2_pending_art_category=pair[2]
   scene.dense_v2_pending_art_title=pair[3]
   scene._assign_dense_v2_artwork(pair[1])
   if not must(scene.content_viewer.category==pair[2] and scene.content_viewer.title_label.text==pair[3],"art type/name assignment"):return
  if not must(scene.dense_artifact_empty_nodes.size()>0,"empty cube unavailable"):return
  var sid:String=scene.dense_artifact_empty_nodes.keys()[0]
  if not must(scene.open_content_hotspot({"category":"dense_artifact_empty","item_id":sid}),"cube click"):return
  scene.dense_v2_pending_frame=sid
  scene._assign_dense_v2_artwork(src3)
  var aid:String="LOCAL_GRID_"+FileAccess.get_sha256(src3)
  if not must(not w.physical_object(aid).is_empty(),"cube registered"):return
  state={"painting":pid,"poster":qid,"artifact":aid,"painting_sha":FileAccess.get_sha256(src1),"poster_sha":FileAccess.get_sha256(src2),"artifact_sha":FileAccess.get_sha256(src3)}
  var f:=FileAccess.open(state_path,FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close()
  for source in [src1,src2,src3]:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(source))
  if not must(w.save_world(),"persist world"):return
 else:
  state=JSON.parse_string(FileAccess.get_file_as_string(state_path))
 for pair in [[state.painting,"paintings","QA Painting",Vector2(800,400),state.painting_sha],[state.poster,"posters","QA Poster",Vector2(300,900),state.poster_sha]]:
  var frame:MeshInstance3D=scene._dense_v2_find_frame(pair[0])
  if not must(frame!=null,"frame missing after restart"):return
  var rec:Dictionary=scene.DenseWallArt.load_record(pair[0])
  if not must(FileAccess.get_sha256(rec.full_image_path)==pair[4],"frame original bytes"):return
  if not must(scene.open_content_hotspot({"category":"dense_v2_frame","item_id":pair[0]}) and scene.content_viewer.category==pair[1] and scene.content_viewer.title_label.text==pair[2] and scene.content_viewer.preview.texture.get_size()==pair[3],"frame viewer full master"):return
  if not must(absf(frame.mesh.size.x/frame.mesh.size.y-pair[3].x/pair[3].y)<.003,"frame aspect"):return
 var art:Dictionary=w.physical_object(state.artifact)
 if not must(not art.is_empty() and FileAccess.get_sha256(art.full_image_path)==state.artifact_sha,"cube original"):return
 if not must(scene.open_content_hotspot({"category":"artifacts","item_id":state.artifact}) and scene.content_viewer.preview.texture.get_size()==Vector2(900,450),"cube master viewer"):return
 for pair in [["books","QA_I91_SCENE_BOOK",Vector2(800,400)],["films","QA_I91_SCENE_FILM",Vector2(800,400)],["tracks","QA_I91_SCENE_TRACK",Vector2(300,900)]]:
  if not must(scene.open_content_hotspot({"category":pair[0],"item_id":pair[1]}) and scene.content_viewer.preview.texture.get_size()==pair[2],"media viewer "+pair[0]):return
 print("I91_DENSE_CONTENT_PASS restart=",restart," six_classes=true original_bytes=true scene_import=true")
 quit(0)
