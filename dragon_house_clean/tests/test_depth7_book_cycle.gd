extends SceneTree
func _initialize()->void:call_deferred("run")
func arrive(life,actor:Dictionary)->void:
 for i in range(3200):
  life.clock+=.125
  life.world.sim_clock=life.clock
  life._move(actor,.125)
  if actor.get("phase")!="travel" or int(actor.get("waypoint_index",0))==0:break
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life;var media=life.media_runtime
 var actor:Dictionary=w.residents["RES_07"]
 var book:Dictionary={};var slot:Dictionary={}
 for item in media.available_shelf_books(str(actor.id)):
  var candidate:Dictionary=media.book_slot(str(item.id))
  if str(candidate.get("id","")).begins_with("library_depth7_shelf_"):
   book=item;slot=candidate;break
 assert(not book.is_empty(),"no source-backed book on new shelves")
 var room:Dictionary=w.room_by_id(str(slot.room_id))
 var c:Vector3=w.room_center_pos(room)
 life.stations.release(actor)
 actor["room_id"]=room.id;actor["level"]=room.level;actor["x"]=c.x;actor["z"]=1.5;actor["visual_y"]=c.y;actor["phase"]="idle"
 assert(life._book_route(actor,room,"FETCH_BOOK",slot.station_id))
 actor["book_task_stage"]="fetch";actor["book_task_id"]=book.id;actor["book_source_room"]=room.id;actor["book_read_room"]=room.id
 assert(not media.borrow_at_shelf(actor.id,book.id,room.id))
 arrive(life,actor)
 assert(actor.get("book_task_stage")=="read" and book.holder_id==actor.id,str(actor.get("book_task_stage")))
 arrive(life,actor)
 assert(actor.get("phase")=="perform" and actor.get("intent")=="READ_BOOK")
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 scene.update_residents();scene._update_physical_books()
 assert(scene.book_nodes.has(book.id))
 var node:Node3D=scene.book_nodes[book.id]
 var contact:String=str(node.get_meta("hand_contact_status",""))
 assert(contact=="READ_FRAME_MARKED",contact)
 assert(node.to_global(Vector3(0,.09,0)).distance_to(node.get_meta("hand_contact_target"))<.0001)
 if DisplayServer.get_name()!="headless":
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter73_library.png")==OK)
 life.clock+=40.0;w.sim_clock=life.clock
 assert(life._continue_book_task(actor))
 assert(actor.get("book_task_stage")=="return")
 arrive(life,actor)
 assert(book.holder_id=="" and not actor.has("held_book"))
 assert(float(book.progress_by_actor.get(actor.id,0))>=40.0)
 assert(not media.book_slot(book.id).is_empty())
 assert(w.save_world())
 var W=load("res://scripts/world_model.gd")
 var again=W.new();again.canonical_house_seed=true;again.save_path=w.save_path
 assert(again.load_or_seed())
 var reloaded:Dictionary={}
 for item in again.media.books:
  if item.id==book.id:reloaded=item
 assert(not reloaded.is_empty() and reloaded.holder_id=="" and float(reloaded.progress_by_actor.get(actor.id,0))>=40.0)
 assert(again.runtime_state["teea008_book_slot_assignments"][book.id]==w.runtime_state["teea008_book_slot_assignments"][book.id])
 print("DEPTH7_BOOK_CYCLE_PASS new_shelf_pickup=true contact=",contact," return=true reload=true")
 quit()
