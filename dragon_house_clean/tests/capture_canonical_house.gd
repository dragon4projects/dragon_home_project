extends SceneTree
func _initialize()->void:
	call_deferred("run")

func capture(scene,label:String)->void:
	for i in range(8):await process_frame
	var img:Image=root.get_texture().get_image()
	assert(img!=null and img.get_width()>0)
	assert(img.save_png("res://private_review/"+label+".png")==OK)
	print("CANONICAL_CAPTURE ",label," ",img.get_size()," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
	await capture(scene,"canonical_house")
	for spec in [[4,0,"canonical_kitchen"],[-3,2,"canonical_lounge_upper"],[-6,1,"canonical_lounge_lower"],[-3,1,"canonical_hearth"],[-6,-2,"canonical_centaur"],[1,0,"canonical_cinema"],[-6,0,"canonical_library"]]:
		var room:Dictionary=scene.world.get_room(int(spec[0]),int(spec[1]))
		scene.selected_room=room["id"]
		scene.set_mode("ROOM")
		scene.zoom_current=scene.zoom
		scene.smooth_focus=scene.desired_focus
		scene.apply_camera(1.0)
		scene.update_render_lod()
		await capture(scene,str(spec[2]))
	print("CANONICAL_RENDER_CAPTURE_PASS")
	quit(0)
