extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 root.size=Vector2i(1280,800)
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 if not scene.dense_services_qa or not scene.complete_sprite_ready:quit(2);return
 for key in ["L2_library","L0_cinema","L2_music","L0_workshop"]:
  for rid in scene.dense_v2.by_room:
   if scene.dense_v2.by_room[rid].compiled.key!=key:continue
   scene.selected_room=rid;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
   for i in range(4):await process_frame
   await RenderingServer.frame_post_draw
   var im:Image=root.get_texture().get_image()
   if im.save_jpg("/home/user/dragon_qa/i96_"+key+".jpg",.82)!=OK:quit(3);return
   print("I96_CAPTURE ",key," ",im.get_size())
 print("I96_RENDER_PASS")
 quit(0)
