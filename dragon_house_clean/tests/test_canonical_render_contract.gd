extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var life=scene.life
	var room:Dictionary=world.get_room(-3,1)
	var actor:Dictionary=world.residents["RES_01"]
	var spot:Dictionary={}
	for candidate in life.candidate_navigation.candidate_spots(room):
		if str(candidate.get("furniture_id",""))=="common_r3_p3_sofa_center":
			spot=candidate
			break
	assert(not spot.is_empty())
	var contact:Dictionary=life.candidate_navigation.pose_contact(actor,spot,"REST")
	assert(contact.has("seat_front_z"))
	var center:Vector3=world.room_center_pos(room)
	var p:Array=contact["local_xyz"]
	var inst:Array=contact["instance_xyz"]
	var scale_value:float=scene.depth_visual_scale(float(inst[2]))
	var original:=Vector3(center.x+float(p[0])*scale_value,center.y+float(inst[1])+(float(p[1])-float(inst[1]))*scale_value,float(inst[2])+(float(p[2])-float(inst[2]))*scale_value)
	var front:float=float(inst[2])+(float(contact["seat_front_z"])-float(inst[2]))*scale_value
	actor["room_id"]=room["id"]
	actor["level"]=room["level"]
	actor["station_room_id"]=room["id"]
	actor["station_contact"]=contact
	actor["phase"]="perform"
	actor["intent"]="REST"
	var approach:Vector2=spot["offset"]
	actor["x"]=center.x+approach.x
	actor["z"]=approach.y
	actor["visual_y"]=center.y
	var before:Array=[actor["x"],actor["z"],actor["visual_y"]]
	for mode in ["ROOM","HOUSE"]:
		scene.selected_room=room["id"]
		scene.set_mode(mode)
		if mode=="ROOM":
			scene.zoom=8.0
			scene.desired_focus=center+Vector3(-4.55,1.0,0)
		scene.zoom_current=scene.zoom
		scene.smooth_focus=scene.desired_focus
		scene.apply_camera(1.0)
		scene.update_render_lod()
		scene.update_residents()
		var expected:Dictionary=scene._seat_render_projection(original,front,scale_value)
		var node:Node3D=scene.actor_sprites["RES_01"]
		assert(node.position.distance_to(expected["position"])<0.001)
		assert(node.position.z>front and before==[actor["x"],actor["z"],actor["visual_y"]])
		assert(scene.camera.unproject_position(original).distance_to(scene.camera.unproject_position(node.position))<0.05)
		var sprite:Sprite3D=node.get_node("Body")
		assert(not sprite.no_depth_test)
		assert(sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISCARD)
		if DisplayServer.get_name()!="headless":
			for id in scene.actor_sprites:
				if id!="RES_01":scene.actor_sprites[id].visible=false
			for i in range(5):await process_frame
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
			assert(root.get_texture().get_image().save_png("res://private_review/canonical_pose_"+mode+".png")==OK)
	# Negative cases must not move a standing sprite up to a furniture contact.
	var invalid:Dictionary=contact.duplicate(true)
	invalid["state"]="QA_NONEXISTENT_POSE"
	actor["station_contact"]=invalid
	scene.update_residents()
	assert(scene._active_station_render_contact(actor).is_empty())
	assert(scene.desired_actor_animation(actor)=="IDLE_S")
	var standing:Node3D=scene.actor_sprites["RES_01"]
	assert(absf(standing.position.y-float(actor["visual_y"]))<0.001)
	actor["station_contact"]=contact
	var saved_station_room:String=str(actor["station_room_id"])
	actor["station_room_id"]="QA_STALE_ROOM"
	scene.update_residents()
	assert(scene._active_station_render_contact(actor).is_empty())
	assert(absf(standing.position.y-float(actor["visual_y"]))<0.001)
	actor["station_room_id"]=saved_station_room
	actor["station_contact"]=contact
	var guest:Dictionary=world.guest_room_for("NPC_CENTAUR")
	var id:String=str(guest["id"])
	assert(world.set_guest_room_open(id,false))
	scene.update_render_lod()
	var closed:Node3D=scene.room_root.get_node(id)
	assert(bool(closed.get_meta("facade_only")))
	assert(closed.get_node_or_null("LocalFurniture")==null and closed.get_node_or_null("Layer_OverviewCues")==null)
	assert(world.is_accessible(guest,"NPC_CENTAUR") and not world.is_accessible(guest,"RES_01"))
	assert(world.set_guest_room_open(id,true))
	scene.update_render_lod()
	var opened:Node3D=scene.room_root.get_node(id)
	assert(not bool(opened.get_meta("facade_only")))
	assert(opened.get_node_or_null("Layer_OverviewCues")!=null)
	assert(opened.get_node_or_null("LocalFurniture")!=null)
	var library:Dictionary=world.get_room(-6,0)
	scene.selected_room=library["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var rid:String=str(library["id"])
	var original_assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{}).duplicate(true)
	var occupied:Node3D=null
	var occupied_book:String=""
	var free_decor:Node3D=null
	for node in get_nodes_in_group("canonical_conditional_dressing"):
		if str(node.get_meta("room_id",""))!=rid:continue
		var slot_id:String=str(node.get_meta("decor_slot_id",""))
		for bid in original_assignments:
			if str(original_assignments[bid].get("room_id",""))==rid and str(original_assignments[bid].get("slot_id",""))==slot_id:
				assert(not node.visible,"Assigned book must suppress decorative filler")
				occupied=node
				occupied_book=str(bid)
		if node.visible:free_decor=node
	assert(occupied!=null and occupied_book!="" and free_decor!=null)
	# Real measured book support, not an invented free decoration slot.
	var measured:Dictionary=life.media_runtime.book_slot(occupied_book)
	assert(not measured.is_empty())
	var book:Dictionary=life.media_runtime._lookup("books",occupied_book)
	var original_book:Dictionary=book.duplicate(true)
	var original_actor:Dictionary=actor.duplicate(true)
	world.runtime_state["teea008_book_slot_assignments"].erase(occupied_book)
	book["holder_id"]="RES_01"
	book["location_room_id"]=""
	scene._refresh_conditional_dressing()
	assert(occupied.visible)
	actor["active"]=true
	actor["autonomy_enabled"]=true
	actor["phase"]="travel"
	actor["book_task_id"]=occupied_book
	actor["book_task_stage"]="return"
	actor["book_return_room"]=rid
	actor["book_return_slot"]=measured["id"]
	scene._refresh_conditional_dressing()
	assert(not occupied.visible and free_decor.visible)
	scene._update_physical_books()
	assert(scene.book_nodes.has(occupied_book),"Held book without shelf assignment must remain visible")
	actor.erase("book_task_stage")
	scene._refresh_conditional_dressing()
	assert(occupied.visible)
	book.clear()
	book.merge(original_book)
	actor.clear()
	actor.merge(original_actor)
	world.runtime_state["teea008_book_slot_assignments"]=original_assignments
	scene._refresh_conditional_dressing()
	assert(not occupied.visible and free_decor.visible)
	print("CANONICAL_RENDER_CONTRACT_PASS near_far_seat=true missing_pose_floor_fallback=true stale_room_floor_fallback=true depth_test=true guest_facade_roundtrip=true conditional_slot_visibility=true")
	quit(0)
