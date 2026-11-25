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
	scene.zoom=9.0
	scene.zoom_current=scene.zoom
	var c:Vector3=scene.world.room_center_pos(room)
	scene.desired_focus=c+Vector3(-2,1.2,0)
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var nav=scene.life.candidate_navigation
	assert(nav.hand_profiles.size()==27)
	var ids:Array=["RES_01","NPC_CENTAUR"]
	var cups:Array=["TEEA008_REVIEW_candidate_dragon_mug_red","TEEA008_REVIEW_candidate_guest_mug_blue"]
	var checked:=0
	for i in range(ids.size()):
		var id:String=ids[i]
		var actor:Dictionary=scene.world.residents[id]
		actor["room_id"]=room["id"]
		actor["level"]=room["level"]
		actor["x"]=c.x-2.7+float(i)*1.5
		actor["z"]=1.3
		actor["visual_y"]=c.y
		actor["phase"]="perform"
		actor["intent"]="GET_COFFEE"
		actor.erase("station_contact")
		assert(scene.world.pickup_physical_object(cups[i],id))
		scene.update_residents()
		scene.update_physical_objects()
		var anchor:Node3D=scene.object_nodes[cups[i]]
		assert(str(anchor.get_meta("hand_contact_status",""))=="IDLE_FRAME_MARKED",id)
		var marker:Node3D=anchor.find_child("PICKUP_ANCHOR",true,false)
		assert(marker!=null)
		assert(marker.global_position.distance_to(anchor.get_meta("hand_contact_target"))<0.0001)
		assert(scene.world.physical_object(cups[i])["current_holder_id"]==id)
		checked+=1
	# Missing exact frame/wardrobe must not masquerade as a calibrated grip.
	var first:Dictionary=scene.world.residents[ids[0]]
	assert(nav.hand_contact(first,"WALK_LEFT",0).is_empty())
	var altered:Dictionary=first.duplicate()
	altered["visual_wardrobe"]="OTHER"
	assert(nav.hand_contact(altered,"IDLE_S",0).is_empty())
	if DisplayServer.get_name()!="headless":
		for i in range(5):await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
		assert(root.get_texture().get_image().save_png("res://private_review/hand_contact_review.png")==OK)
	print("TEEA008_HAND_CONTACT_SCENE_PASS profiles=27 mounted=",checked," exact_marker=true unverified_frame_denied=true")
	quit(0)
