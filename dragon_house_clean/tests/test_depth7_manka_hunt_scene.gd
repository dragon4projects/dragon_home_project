extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life
 var m:Dictionary=w.creatures["CREATURE_MOUSE_GRAY_REVIEW"]
 var a:Dictionary=w.residents.MANJKA
 var room:Dictionary=w.matching_rooms(["library"])[0]
 var c:Vector3=w.room_center_pos(room)
 life.stations.release(a)
 a.merge({"room_id":room.id,"level":room.level,"x":c.x-3,"z":1.5,"visual_y":c.y,"phase":"idle","hunt_next_at":0.0},true)
 m.merge({"room_id":room.id,"level":room.level,"x":c.x,"z":1.5,"visual_y":c.y,"phase":"idle"},true)
 assert(life.creature_runtime.try_begin_hunt(a))
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 var frames:Dictionary={}
 for i in range(6):
  w.sim_clock+=.125;life.creature_runtime._tick_hunt(.125)
  scene.update_residents(.125);scene.update_creatures(.125)
  assert(a.phase=="hunt" and m.phase=="flee")
  var anim:Dictionary=scene.actor_animations[a.id]
  assert(anim.state=="CHASE_RIGHT")
  frames[anim.frame]=true
  assert(scene.actor_sprites[a.id].visible and scene.creature_nodes[m.id].visible)
  assert(scene.actor_sprites[a.id].get_node("Body").texture==scene.asset_banks.manka_texture("CHASE_RIGHT",anim.frame))
  if DisplayServer.get_name()!="headless" and i==3:
   for id in scene.actor_sprites:
    if id!=a.id:scene.actor_sprites[id].visible=false
   for j in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter77_hunt.png")==OK)
 assert(frames.size()>=4)
 print("DEPTH7_MANKA_SCENE_PASS distinct_rendered_frames=",frames.size()," mouse_flee=true")
 quit()
