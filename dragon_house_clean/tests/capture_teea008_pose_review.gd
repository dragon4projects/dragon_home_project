extends SceneTree
func _initialize()->void:
	call_deferred("run")
func settle(scene:Node,room:Dictionary,label:String)->void:
	scene.selected_room=str(room["id"])
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	scene.update_residents()
	for frame in range(8):
		await process_frame
	var image:Image=root.get_texture().get_image()
	assert(image!=null)
	assert(image.save_png("res://private_review/"+label+".png")==OK)
func place(scene:Node,id:String,room:Dictionary,intent:String)->void:
	var actor:Dictionary=scene.world.residents[id]
	scene.life._assign(actor,{"room":room,"intent":intent})
	assert(str(actor["phase"])=="travel",str([id,intent]))
	for step in range(1200):
		scene.life._move(actor,0.125)
		if str(actor["phase"])!="travel":break
	assert(str(actor["phase"])=="perform",id)
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	OS.set_environment("DRAGON_TEEA008_LIVE","1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.teea008_live)
	var common:Dictionary=scene.world.get_room(-2,0)
	for id in ["RES_01","RES_02","RES_03","RES_04"]:
		place(scene,id,common,"REST")
	await settle(scene,common,"teea008_live_common")
	var artifact:Dictionary=scene.world.get_room(1,-1)
	await settle(scene,artifact,"teea008_live_artifact")
	var guest:Dictionary=scene.world.guest_room_for("NPC_CENTAUR")
	place(scene,"NPC_CENTAUR",guest,"SLEEP")
	assert(not scene.world.residents["NPC_CENTAUR"].get("station_contact",{}).is_empty())
	await settle(scene,guest,"teea008_live_centaur")
	print("TEEA008_POSE_RENDER_PASS")
	quit(0)
