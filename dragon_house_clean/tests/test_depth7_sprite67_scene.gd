extends SceneTree
func _initialize()->void:call_deferred("run")
func capture(scene,room:Dictionary,actor:Dictionary,intent:String,preferred:Array)->void:
 var nav=scene.life.candidate_navigation
 var spots:Array=nav.candidate_spots(room)
 var selected:Dictionary={}
 var claim:Dictionary={}
 for i in range(spots.size()):
  var candidate:Dictionary=scene.life.stations._candidate_claim(actor,room,i,spots[i],intent)
  if candidate.get("contact",{}).get("state","") in preferred:
   selected=spots[i];claim=candidate;break
 assert(not claim.is_empty(),str([actor.id,room.id,intent,preferred]))
 var c:Vector3=scene.world.room_center_pos(room);var approach:Vector2=selected.offset
 actor["room_id"]=room.id;actor["level"]=room.level;actor["visual_y"]=c.y;actor["x"]=c.x+approach.x;actor["z"]=approach.y
 actor["phase"]="perform";actor["intent"]=intent
 scene.life.stations.commit_claim(actor,claim)
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 scene.update_residents()
 var contact:Dictionary=scene._active_station_render_contact(actor)
 assert(not contact.is_empty(),str([actor.id,claim,actor.get("visual_wardrobe")]))
 var node:Node3D=scene.actor_sprites[actor.id]
 var sprite:Sprite3D=node.get_node("Body")
 assert(node.visible and sprite.texture!=null and not sprite.no_depth_test)
 var px:Array=contact.contact_px
 var actual:Vector3=scene._sprite_pixel_world(node,sprite,px)
 var p:Array=contact.local_xyz
 var expected:=Vector3(c.x+float(p[0]),c.y+float(p[1]),float(p[2]))
 var screen_gap:float=scene.camera.unproject_position(actual).distance_to(scene.camera.unproject_position(expected))
 assert(screen_gap<0.10,str([actor.id,screen_gap]))
 assert(is_equal_approx(float(actor.z),approach.y))
 print("SPRITE67_SCENE_CONTACT ",actor.id," ",room.id," ",contact.state," screen_px=",screen_gap," simulation_position_unchanged=true")
 if DisplayServer.get_name()!="headless":
  for id in scene.actor_sprites:
   if id!=actor.id:scene.actor_sprites[id].visible=false
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter67_"+str(actor.id)+".png")==OK)
 scene.life.stations.release(actor);actor["phase"]="idle"
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var hearth:Dictionary=scene.world.get_room(-3,1)
 var cinema:Dictionary={};var library:Dictionary={}
 for room in scene.world.rooms:
  if room.type=="cinema" and cinema.is_empty():cinema=room
  if room.type=="library" and library.is_empty():library=room
 await capture(scene,hearth,scene.world.residents["RES_04"],"WATCH_FIRE",["SIT_N","SIT_NW","SIT_NE"])
 await capture(scene,cinema,scene.world.residents["RES_08"],"WATCH_FILM",["SIT_E"])
 await capture(scene,library,scene.world.residents["RES_07"],"READ_BOOK",["READ"])
 print("SPRITE67_SCENE_PASS")
 quit(0)
