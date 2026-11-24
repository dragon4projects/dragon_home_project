extends SceneTree
func _initialize()->void:
	call_deferred("run")
func shot(scene:Node,room:Dictionary,label:String)->void:
	scene.selected_room=str(room["id"])
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	for i in range(12):await process_frame
	var im:Image=root.get_texture().get_image()
	assert(im!=null and im.save_png("res://private_review/"+label+".png")==OK)
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	assert(scene.teea008_review.enabled,scene.teea008_review.error)
	await shot(scene,scene.world.get_room(-2,0),"teea008_common")
	await shot(scene,scene.world.get_room(4,0),"teea008_cinema")
	await shot(scene,scene.world.get_room(1,-1),"teea008_artifact")
	var guest:Dictionary={}
	for room in scene.world.rooms:
		if str(room.get("candidate_room_id",""))=="guest_centaur_01":guest=room;break
	assert(not guest.is_empty())
	await shot(scene,guest,"teea008_centaur")
	print("TEEA008_FULL_SCENE_RENDER_PASS")
	quit(0)
