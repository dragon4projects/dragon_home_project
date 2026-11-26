extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 # QA-only user profile: a test texture, not owner artwork.
 var folder:="user://hearth_pictures"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var path:=folder+"/HEARTH_PICTURE_03.png"
 assert(not FileAccess.file_exists(path))
 var img:=Image.create_empty(90,180,false,Image.FORMAT_RGBA8)
 img.fill(Color("#9f7c55"))
 assert(img.save_png(path)==OK)
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var room:Dictionary=scene.world.get_room(-3,1)
 scene.selected_room=room.id;scene.set_mode("ROOM")
 scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
 var group:Node3D=scene.room_root.get_node(str(room.id))
 var frames:Array=group.find_children("HEARTH_PICTURE_*","MeshInstance3D",true,false)
 assert(frames.size()==10)
 for frame in frames:
  var screen:Vector2=scene.camera.unproject_position(frame.to_global(Vector3(0,0,frame.mesh.size.z*.5)))
  var entry:Dictionary=scene.content_hotspot_at_screen(screen)
  assert(entry.get("item_id","")==str(frame.name),str([frame.name,screen,entry]))
  assert(scene.open_content_hotspot(entry))
  assert(scene.content_viewer.visible and scene.content_viewer.item.id==str(frame.name))
  if str(frame.name)=="HEARTH_PICTURE_03":
   assert(scene.content_viewer.preview.texture!=null)
   assert(scene.content_viewer.preview.texture.get_size()==Vector2(90,180))
   var quad:MeshInstance3D=frame.get_parent().get_node("Artwork_03")
   assert(is_equal_approx(quad.mesh.size.x,.115) and is_equal_approx(quad.mesh.size.y,.23))
  else:
   assert(scene.content_viewer.preview.texture==null and scene.content_viewer.meta_label.text.contains("Рамка пока пуста"))
  scene.content_viewer.close_viewer()
 assert(not scene.open_content_hotspot({"category":"hearth_picture","item_id":"HEARTH_PICTURE_99","room_id":room.id}))
 var lib_count:=0
 for library in scene.world.rooms:
  if library.type!="library":continue
  var node:Node3D=scene.room_root.get_node(str(library.id))
  assert(node.get_node_or_null("Layer_Structure/LibraryRearFinish/WalnutWainscot")!=null)
  assert(scene.life.candidate_navigation.book_slots(library).size()==10)
  lib_count+=1
  if lib_count==1:
   scene.selected_room=library.id;scene.set_mode("ROOM")
   scene.zoom_current=scene.zoom;scene.smooth_focus=scene.desired_focus;scene.apply_camera(1.0);scene.update_render_lod()
   if DisplayServer.get_name()!="headless":
    for i in range(3):await process_frame;await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("/home/user/dragon_qa/iter69_library.png")==OK)
 assert(lib_count==2)
 assert(scene._hearth_picture_hit(Vector2(0,0)).is_empty())
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("DEPTH7_PICTURE_PASS slots=10 filled=1 empty=9 invalid_rejected=true libraries=2 book_slots=10 each")
 quit(0)
