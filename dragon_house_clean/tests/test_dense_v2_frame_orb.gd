extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var room:Dictionary=scene.world.get_room(1,1)
 scene.selected_room=room.id;scene.set_mode("ROOM");scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 var holder:MeshInstance3D=null
 var count:=0
 for node in get_nodes_in_group("dense_v2_wall_holder"):
  if not node.is_visible_in_tree() or node.get_meta("room_id","")!=room.id:continue
  count+=1
  if holder==null and absf(node.rotation.y)<.01:holder=node
 assert(holder!=null and count>10)
 var id:String=str(holder.get_meta("slot_id",""))
 var screen:Vector2=scene.camera.unproject_position(holder.global_position)
 var hit:Dictionary=scene._dense_v2_frame_hit(screen)
 assert(hit.get("item_id","")==id,str([id,hit]))
 assert(scene.open_content_hotspot(hit))
 assert(scene.content_viewer.visible and scene.content_viewer.artwork_assign.visible)
 assert(scene.content_viewer.preview.texture==null)
 var path:="user://qa_frame_input.png"
 var image:=Image.create_empty(80,160,false,Image.FORMAT_RGBA8)
 image.fill(Color("#884a75"));assert(image.save_png(path)==OK)
 scene.dense_v2_pending_frame=id;scene._assign_dense_v2_artwork(path)
 assert(scene.content_viewer.preview.texture!=null)
 assert(scene.content_viewer.preview.texture.get_size()==Vector2(80,160))
 assert(is_equal_approx(holder.mesh.size.x/holder.mesh.size.y,.5))
 scene.content_viewer.close_viewer()
 var group:Node3D=scene.room_root.get_node(room.id)
 var orb:Sprite3D=group.find_child("L1_gallery_ORB",true,false)
 assert(orb!=null and orb.texture!=null)
 var start:float=orb.position.y
 await create_timer(.7).timeout
 assert(absf(orb.position.y-start)>.01)
 assert(orb.pixel_size*375.0>=.99)
 # Restore the QA-only test image to empty. Real owner slots were never accessed.
 DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.DenseWallArt.record_path(id)))
 scene.DenseV2Runtime.REVIEW.refresh_artwork(holder)
 if DisplayServer.get_name()!="headless":
  scene.update_residents();scene.update_creatures(.125)
  for i in range(3):await process_frame;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter84_live_gallery.png")==OK)
 print("DENSE_V2_FRAME_ORB_PASS holders=",count," assignment=true aspect=true real_hover=true")
 quit()
