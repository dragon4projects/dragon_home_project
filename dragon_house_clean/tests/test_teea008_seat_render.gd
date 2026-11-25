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
	var room:Dictionary=scene.world.get_room(-2,0)
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom=6.5
	scene.zoom_current=scene.zoom
	scene.desired_focus=scene.world.room_center_pos(room)+Vector3(-4.55,1.0,0)
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var actor:Dictionary=scene.world.residents["RES_01"]
	var spot:Dictionary={}
	for candidate in scene.life.candidate_navigation.candidate_spots(room):
		if str(candidate.get("furniture_id",""))=="common_r3_p3_sofa_center":
			spot=candidate
			break
	assert(not spot.is_empty())
	var contact:Dictionary=scene.life.candidate_navigation.pose_contact(actor,spot,"REST")
	assert(contact.has("seat_front_z"))
	var c:Vector3=scene.world.room_center_pos(room)
	var p:Array=contact["local_xyz"]
	var inst:Array=contact["instance_xyz"]
	var scale_value:float=scene.depth_visual_scale(float(inst[2]))
	var original:=Vector3(c.x+float(p[0])*scale_value,c.y+float(inst[1])+(float(p[1])-float(inst[1]))*scale_value,float(inst[2])+(float(p[2])-float(inst[2]))*scale_value)
	var front:float=float(inst[2])+(float(contact["seat_front_z"])-float(inst[2]))*scale_value
	var projection:Dictionary=scene._seat_render_projection(original,front,scale_value)
	assert(float(projection["position"].z)>front)
	assert(scene.camera.unproject_position(original).distance_to(scene.camera.unproject_position(projection["position"]))<0.05)
	actor["room_id"]=room["id"]
	actor["level"]=room["level"]
	actor["station_room_id"]=room["id"]
	actor["station_contact"]=contact
	actor["phase"]="perform"
	actor["intent"]="REST"
	var approach:Vector2=spot["offset"]
	actor["x"]=c.x+approach.x
	actor["z"]=approach.y
	actor["visual_y"]=c.y
	var before:Array=[actor["x"],actor["z"],actor["visual_y"]]
	scene.update_residents()
	assert(scene.actor_sprites["RES_01"].position.distance_to(projection["position"])<0.001)
	assert(before==[actor["x"],actor["z"],actor["visual_y"]])
	assert(scene.actor_sprites["RES_01"].get_node("Body").no_depth_test==false)
	if DisplayServer.get_name()!="headless":
		# Isolate the exact seating comparison without other residents
		# obscuring the actor. This is QA-only, not a runtime visibility rule.
		for id in scene.actor_sprites:
			if id!="RES_01":scene.actor_sprites[id].visible=false
		scene.creature_root.visible=false
		for i in range(5):await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
		assert(root.get_texture().get_image().save_png("res://private_review/seat_render_review.png")==OK)
		var without_projection:Dictionary=contact.duplicate()
		without_projection.erase("seat_front_z")
		actor["station_contact"]=without_projection
		scene.update_residents()
		for id in scene.actor_sprites:
			if id!="RES_01":scene.actor_sprites[id].visible=false
		for i in range(3):await process_frame
		assert(root.get_texture().get_image().save_png("res://private_review/seat_render_before.png")==OK)
	print("TEEA008_SEAT_RENDER_PASS projected_contact_preserved=true depth_test=true physical_position_unchanged=true")
	quit(0)
