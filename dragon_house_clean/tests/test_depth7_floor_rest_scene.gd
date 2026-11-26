extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world;var life=scene.life;var room:Dictionary=w.get_room(-3,1)
 var a:Dictionary=w.residents.RES_07
 var points:Array=life.stations.layout_for_world(w,room)
 var claim:Dictionary={}
 for i in range(points.size()):
  if points[i].kind!="floor_rest":continue
  var candidate:Dictionary=life.stations._candidate_claim(a,room,i,points[i],"REST")
  if candidate.get("pose_hint")=="LIE_SIDE_CURLED":claim=candidate;break
 assert(not claim.is_empty())
 var p:Vector3=w.room_local_to_world(room,claim.offset)
 a.merge({"room_id":room.id,"level":room.level,"x":p.x,"z":p.z,"visual_y":p.y,"phase":"perform","intent":"REST"},true)
 life.stations.release(a);life.stations.commit_claim(a,claim)
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 scene.update_residents()
 var node:Node3D=scene.actor_sprites[a.id];var sprite:Sprite3D=node.get_node("Body")
 var c:Dictionary=scene._active_station_render_contact(a)
 assert(c.state=="LIE_SIDE_CURLED")
 var room_center:Vector3=w.room_center_pos(room)
 var target:=room_center+Vector3(c.local_xyz[0],c.local_xyz[1],c.local_xyz[2])
 assert(scene._sprite_pixel_world(node,sprite,c.contact_px).distance_to(target)<.0001)
 assert(not sprite.no_depth_test and node.visible)
 if DisplayServer.get_name()!="headless":
  for id in scene.actor_sprites:
   if id!=a.id:scene.actor_sprites[id].visible=false
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter75_floor_rest.png")==OK)
 # A stale claim must not teleport a visible body back onto the mat.
 a["x"]=p.x+.4
 scene.update_residents()
 assert(scene._active_station_render_contact(a).is_empty())
 assert(scene.actor_animations[a.id].state=="IDLE_S")
 a["x"]=p.x
 life.stations.release(a);a["phase"]="idle"
 scene.update_residents()
 assert(scene.actor_animations[a.id].state=="IDLE_S")
 assert(scene._active_station_render_contact(a).is_empty())
 assert(node.position.distance_to(p)<.0001)
 assert(sprite.texture==scene.asset_banks.texture_for(a.id,a.visual_wardrobe,"IDLE_S",0))
 assert(a.x==p.x and a.z==p.z and a.visual_y==p.y)
 print("DEPTH7_FLOOR_REST_SCENE_PASS contact=true release_standing=true physical_position_unchanged=true")
 quit()
