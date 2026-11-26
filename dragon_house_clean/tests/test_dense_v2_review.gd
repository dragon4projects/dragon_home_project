extends SceneTree
const V=preload("res://scripts/dense_v2_review.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var v=V.new();assert(v.initialize())
 var compiled:Dictionary={}
 var totals={"measured":0,"special":0,"pending":0,"issues":0,"seat_candidates":0,"support_slots":0,"supported":0,"wall":0,"excluded":0,"added":0}
 for room in v.index.rooms:
  var r:Dictionary=v.compile_room(room.key)
  assert(not r.is_empty())
  compiled[room.key]=r
  totals.pending+=r.pending.size()
  totals.excluded+=r.excluded.size()
  totals.issues+=r.issues.size()
  for p in r.placements:
   if str(p.id).contains("_SIDE_FRAME_") or str(p.id).ends_with("_TV_MONITOR") or str(p.id).ends_with("_ORB"):totals.added+=1
   elif p.has("special"):totals.special+=1
   else:
    if p.role=="supported_decor":totals.supported+=1
    elif p.role=="wall_or_ceiling":totals.wall+=1
    else:totals.measured+=1
    totals.seat_candidates+=p.get("station_candidates",[]).filter(func(x):return x.kind=="seat").size()
    totals.support_slots+=p.get("support_slots",[]).size()
  print("DENSE_V2 ",room.key," measured=",r.placements.size()," pending=",r.pending.size()," issues=",r.issues.size())
 assert(totals.measured+totals.special+totals.pending+totals.supported+totals.wall+totals.excluded==1438)
 var path:="user://dense_v2_measurement.json"
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"totals":totals,"rooms":compiled,"corrections":v.corrections}));file.close()
 print("DENSE_V2_MEASURED ",totals," report=",ProjectSettings.globalize_path(path))
 if DisplayServer.get_name()=="headless":quit();return
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 for spec in [["L2_library",4,2],["L2_cinema",-6,2],["L1_gallery",1,1]]:
  var room:Dictionary=scene.world.get_room(int(spec[1]),int(spec[2]))
  assert(not room.is_empty() and scene.world.public_cutaway_allowed(room))
  scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
  var node:Node3D=scene.room_root.get_node(str(room.id))
  for layer in ["LocalFurniture","Layer_OverviewCues"]:
   var old:Node3D=node.get_node_or_null(layer)
   if old!=null:old.visible=false
  var overlay:=Node3D.new();overlay.name="DenseV2ReviewOnly";node.add_child(overlay)
  var mounted:int=v.mount_review(overlay,compiled[spec[0]])
  assert(mounted>0)
  for actor in scene.actor_sprites.values():actor.visible=false
  for o in scene.object_nodes.values():o.visible=false
  for o in scene.book_nodes.values():o.visible=false
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/dense_v2/qa/"+str(spec[0])+".png")==OK)
  print("DENSE_V2_RENDER ",spec[0]," mounted=",mounted)
  overlay.free()
  for layer in ["LocalFurniture","Layer_OverviewCues"]:
   var old:Node3D=node.get_node_or_null(layer)
   if old!=null:old.visible=true
 quit()
