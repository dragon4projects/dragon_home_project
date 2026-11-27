extends SceneTree
const DESIGN=preload("res://scripts/dense_v2_owner_design.gd")
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
 var w=scene.world;var nav=scene.life.candidate_navigation
 if not must(scene.dense_services_qa and scene.complete_sprite_ready and scene.dense_v2.by_room.size()==14,"full scene readiness"):return
 var im:=Image.create_empty(320,180,false,Image.FORMAT_RGBA8);im.fill(Color("#376b83"));im.save_png("user://i96_cover.png")
 var f:=FileAccess.open("user://i96_media.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"films":[{"id":"I96_TEST_FILM","title":"QA film","runtime_seconds":90,"preview":"i96_cover.png"}],"tracks":[{"id":"I96_TEST_TRACK","title":"QA audio","runtime_seconds":60,"preview":"i96_cover.png"}]}));f.close()
 scene._import_media("user://i96_media.json")
 var device_counts:Dictionary={}
 var cases:=0;var booksets:=0;var labs:=0;var repairs:=0
 for rid in scene.dense_v2.by_room:
  var room:Dictionary=w.room_by_id(rid)
  var compiled:Dictionary=scene.dense_v2.by_room[rid].compiled
  var library:bool=compiled.key in ["L2_library","L0_reading"]
  for p in compiled.placements:
   if not p.get("fits",false):continue
   if not must(p.asset!="blendkit_sofa","unrepaired sofa "+str(p.id)):return
   if p.asset=="blendkit_sofa/repaired.glb":repairs+=1
   if library:
    if not must(not (p.role=="wall_or_ceiling" and (p.get("frame_holder",false) or str(p.asset).contains("picture_frame"))),"library frame remains"):return
    if str(p.id).contains("_WALL_SHELF_"):cases+=1
    if str(p.id).contains("_SHELF_BOOK_"):booksets+=1
   if compiled.key=="L0_workshop" and str(p.id).contains("_I96_DECOR_"):labs+=1
   if compiled.key in ["L2_cinema","L0_cinema"] and p.asset=="owner_theatre_screen":
    if not must(absf(float(p.bounds_max[0])-7.0)<.0001,"screen wall alignment"):return
  if library:
   var seats:Array=nav.candidate_spots(room).filter(func(s):return s.kind=="seat")
   if not must(seats.size()==16 and nav.book_slots(room).size()==(60 if compiled.key=="L2_library" else 65) and nav.cup_slots(room).size()==2,"library regression "+compiled.key):return
  if compiled.key not in ["L2_cinema","L0_cinema","L2_music"]:continue
  scene.selected_room=rid;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
  var added:=0
  for anchor in get_nodes_in_group("teea008_media_surface"):
   if not anchor.is_visible_in_tree() or anchor.get_meta("room_id","")!=rid or not str(anchor.get_meta("dense_media_device","")).contains("_I96_"):continue
   var sid:String=anchor.get_meta("surface_id")
   var cat:String=anchor.get_meta("surface_category")
   var item:String="I96_TEST_FILM" if cat=="films" else "I96_TEST_TRACK"
   if not must(scene.teea008_media_bindings.assign(rid,sid,cat,item),"bind "+sid):return
   scene._update_teea008_media_previews()
   if not must(scene.teea008_media_bindings.resolve(rid,sid).get("id","")==item,"resolve "+sid):return
   if not anchor.get_meta("carrier_hit_only",false) and not must(anchor.get_node_or_null("BoundPreview")!=null,"preview "+sid):return
   if not must(scene.open_content_hotspot({"category":"teea008_surface","item_id":sid,"room_id":rid}),"viewer "+sid):return
   added+=1
  device_counts[compiled.key]=added
 if not must(device_counts=={"L0_cinema":4,"L2_cinema":3,"L2_music":8},"new device counts "+str(device_counts)):return
 if not must(cases==14 and booksets==97 and labs==9,"decor counts"):return
 var landings:=0
 for room in w.rooms:
  if room.type!="lift":continue
  var node:Node3D=scene.room_root.get_node_or_null(str(room.id))
  if node!=null and node.get_node_or_null("Layer_Structure/LiftFinishedLanding")!=null:landings+=1
 if not must(landings==18,"lift landings "+str(landings)):return
 if not must(w.save_world(),"save"):return
 print("I96_OWNER_DESIGN_PASS cases=",cases," booksets=",booksets," workshop=",labs," repaired_sofas=",repairs," devices=",device_counts," landings=",landings," preserved_books=125 seats=32")
 quit(0)
