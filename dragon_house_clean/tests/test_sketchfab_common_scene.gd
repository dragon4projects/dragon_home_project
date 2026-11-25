extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	OS.set_environment("DRAGON_TEEA008_LIVE","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.teea008_review.sketchfab_common_enabled)
	var room:Dictionary=scene.world.get_room(-2,0)
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var group:Node3D=scene.room_root.get_node(str(room["id"]))
	assert(group!=null)
	var hearth:Node3D=group.find_child("common_r3_animated_hearth_review",true,false)
	var coffee:Node3D=group.find_child("common_r3_steampunk_machine_review",true,false)
	assert(hearth!=null and coffee!=null)
	assert(group.find_child("Dressing_Fireplace",true,false)==null)
	assert(bool(hearth.get_meta("fire_playing",false)))
	for intent in ["TALK_PAIR","REST","SLEEP","READ_BOOK","WORK_CREATE","GET_COFFEE"]:
		assert(scene.desired_actor_animation({"phase":"perform","intent":intent,"station_kind":"seat","station_pose_hint":"RELAXED_SIT"})=="IDLE_S",intent)
	assert(scene.desired_actor_animation({"phase":"perform","intent":"REST","station_contact":{"state":"RELAXED_SIT"}})=="RELAXED_SIT")
	if DisplayServer.get_name()!="headless":
		for i in range(8):await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
		assert(root.get_texture().get_image().save_png("res://private_review/sketchfab_common_r3.png")==OK)
	print("SKETCHFAB_COMMON_SCENE_PASS animated_hearth=true coffee_visible=true duplicate_hearth=false contactless_pose_guard=true")
	quit(0)
