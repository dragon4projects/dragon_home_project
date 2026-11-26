extends SceneTree
func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var nav=scene.life.candidate_navigation
	var count:=0
	for id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
		var room:Dictionary=world.guest_room_for(id)
		var key:String=nav.key(room)
		var row:Dictionary=nav.layouts[key]
		assert(row.get("guest_display_revision","")=="GUEST_DISPLAY_V1")
		var hw:float=float(room["size_modules"])*2.4
		assert(nav.segment_clear(room,Vector2(-hw+0.08,1.5),Vector2(hw-0.08,1.5)),key)
		for spot in nav.candidate_spots(room):
			if str(spot["kind"]) in ["seat","floor_rest"]:
				assert(not nav.path(room,Vector2(-hw+0.08,1.5),spot["offset"]).is_empty(),str([key,spot["id"]]))
		count+=1
	var gallery:Dictionary=world.get_room(1,1)
	var row:Dictionary=nav.layouts["artifact/R3"]
	var cubes:=0
	for item in row["instances"]:
		if str(item["asset_id"]).begins_with("artifact_glass_cube_"):
			assert(item["station_candidates"].is_empty())
			var slot:Dictionary=nav.artifact_support(gallery,str(item.get("decor_slot_id","")))
			assert(not slot.is_empty())
			assert(slot["xyz"]==item["room_local_xyz"])
			assert(float(item["bounds_min_m"][1])==float(slot["xyz"][1]))
			assert(float(item["uniform_scale"])==0.9)
			cubes+=1
	assert(cubes==0) # physical artifacts own the cubes, not empty substitutes
	var library:Dictionary=world.get_room(-6,0)
	assert(not nav.book_slots(library).is_empty())
	assert(not nav.artifact_slots(gallery).is_empty())
	# Actual artifact, not a decorative substitute: one glass mesh, one record,
	# exact shelf support, real hit volume, and original image in viewer.
	var img:=Image.create(256,128,false,Image.FORMAT_RGB8)
	img.fill(Color("#6d253b"))
	assert(img.save_png("user://qa_artifact_cube.png")==OK)
	var rid:String=str(gallery["id"])
	var aid:="QA_ARTIFACT_CUBE"
	# Fresh runtime restores the existing historical master when available.
	if scene.asset_banks.prop_master_path("CUBE_LETTERS")!="":
		var letters:Dictionary=world.physical_object("CUBE_LETTERS")
		assert(not letters.is_empty() and str(letters.get("home_support_id",""))!="")
		assert(letters["home_support_id"]==letters["current_support_id"])
		assert(not world.object_is_displaced(letters))
		assert(not scene._ensure_canonical_artifact_cube())
	var init_slot:Dictionary=nav.artifact_support(gallery,"artifact_r3_shelf_c.shelf_3_1")
	assert(not init_slot.is_empty())
	var init_pos:Array=init_slot["xyz"]
	var init_metadata:Dictionary={"viewer_category":"artifacts","home_anchor":[init_pos[0],init_pos[2]],"home_support_id":init_slot["id"],"preview_path":"user://qa_artifact_cube.png","display_world_height":0.8}
	assert(world.register_physical_object(aid,"QA стеклянный куб","RES_01",rid,true,true,false,false,true,init_metadata))
	assert(not world.register_physical_object("QA_DUPLICATE_SUPPORT","QA duplicate","RES_01",rid,true,true,false,false,true,init_metadata))
	assert(world.physical_object(aid)["current_support_id"]==init_slot["id"])
	scene.make_physical_objects()
	scene.selected_room=rid
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var slot:Dictionary=nav.artifact_support(gallery,"artifact_r3_shelf_c.shelf_3_1")
	assert(not slot.is_empty())
	assert(world.physical_object(aid)["home_support_id"]==slot["id"])
	scene.update_physical_objects()
	scene._refresh_conditional_dressing()
	var node:Node3D=scene.object_nodes[aid]
	assert(node.visible and node.get_node_or_null("ArtifactGlassCube")!=null)
	assert(is_equal_approx(float(node.get_meta("artifact_cube_side")),0.18))
	assert(is_equal_approx(float(node.get_node("Visual").position.y),scene.ARTIFACT_CUBE_SIDE*0.5))
	var visible_substitutes:=0
	for sample in get_nodes_in_group("canonical_conditional_dressing"):
		if str(sample.get_meta("room_id",""))==rid and str(sample.get_meta("decor_slot_id",""))==str(slot["id"]):
			if sample.visible:visible_substitutes+=1
	# Empty decorative cubes were removed: absence of a placeholder is
	# valid, but any visible substitute occupying the real cube is not.
	assert(visible_substitutes==0)
	var screen:Vector2=scene.camera.unproject_position(node.to_global(Vector3(0,0.09,0.0)))
	var hit:Dictionary=scene.content_hotspot_at_screen(screen)
	assert(str(hit.get("item_id",""))==aid)
	assert(scene.open_content_hotspot(hit))
	assert(scene.content_viewer.item["id"]==aid)
	assert(scene.content_viewer.preview.texture.get_width()==256)
	assert(scene.content_viewer.preview.texture.get_height()==128)
	scene.content_viewer.close_viewer()
	print("CANONICAL_GUEST_DISPLAYS_PASS artifact_cube=true original_viewer=true  guests=",count," empty_cubes=",cubes," book_slots=",nav.book_slots(library).size()," artifact_slots=",nav.artifact_slots(gallery).size())
	quit(0)
