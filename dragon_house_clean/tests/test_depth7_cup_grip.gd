extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var actor:Dictionary=w.residents["RES_07"]
 var cid:=""
 for id in w.objects:
  var obj:Dictionary=w.objects[id]
  if obj.get("viewer_category")=="cups" and obj.get("current_holder_id","")=="" and obj.get("canonical_owner_id","")=="":cid=id;break
 assert(cid!="")
 var room:Dictionary=w.room_by_id(w.physical_object(cid).home_room_id)
 var center:Vector3=w.room_center_pos(room)
 scene.life.stations.release(actor)
 actor["room_id"]=room.id;actor["level"]=room.level;actor["visual_y"]=center.y;actor["x"]=center.x;actor["z"]=0.1
 actor["phase"]="perform";actor["intent"]="GET_COFFEE"
 actor["visual_wardrobe"]="HOME"
 assert(w.pickup_physical_object(cid,actor.id))
 actor["cup_task_id"]=cid;actor["cup_task_stage"]="hold";actor["drink_sips_left"]=0
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 assert(scene.desired_actor_animation(actor)=="CARRY_USE")
 scene.update_residents();scene.update_physical_objects()
 var cup:Node3D=scene.object_nodes[cid]
 var marker:Node3D=cup.find_child("PICKUP_ANCHOR",true,false)
 assert(marker!=null)
 assert(cup.get_meta("hand_contact_status")=="CARRY_USE_FRAME_MARKED")
 assert(marker.global_position.distance_to(cup.get_meta("hand_contact_target"))<.0001)
 var node:Node3D=scene.actor_sprites[actor.id];var body:Sprite3D=node.get_node("Body")
 # Exercise all four textures and their independent grip calibrations. No
 # beverage event is fabricated merely to drive this rendering test.
 for i in range(4):
  var profile:Dictionary=scene.life.candidate_navigation.cup_hand_contact(actor,"DRINK",i)
  assert(not profile.is_empty())
  body.texture=scene.asset_banks.texture_for(actor.id,"HOME","DRINK",i)
  scene.actor_animations[actor.id]={"state":"DRINK","frame":i,"wardrobe":"HOME","elapsed":0.0}
  assert(scene._place_cup_at_verified_hand(cup,actor))
  assert(marker.global_position.distance_to(cup.get_meta("hand_contact_target"))<.0001)
  assert(cup.get_meta("hand_contact_status")=="DRINK_FRAME_MARKED")
  if DisplayServer.get_name()!="headless" and i==2:
   for k in scene.actor_sprites:
    if k!=actor.id:scene.actor_sprites[k].visible=false
   for j in range(2):await process_frame;await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter71_drink.png")==OK)
 actor["visual_wardrobe"]="CITY"
 assert(scene._held_cup_animation(actor)=="")
 assert(scene.life.candidate_navigation.cup_hand_contact(actor,"DRINK",0).is_empty())
 actor["visual_wardrobe"]="HOME";actor["cup_task_id"]="NOT_A_CUP"
 assert(scene._held_cup_animation(actor)=="")
 print("DEPTH7_CUP_GRIP_PASS four_drink_frames=4 carry=1 wardrobe_gate=true ownership_gate=true")
 quit()
