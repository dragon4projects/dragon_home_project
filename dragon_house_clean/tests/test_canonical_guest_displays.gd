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
			cubes+=1
	assert(cubes==3)
	var library:Dictionary=world.get_room(-6,0)
	assert(not nav.book_slots(library).is_empty())
	assert(not nav.artifact_slots(gallery).is_empty())
	print("CANONICAL_GUEST_DISPLAYS_PASS guests=",count," empty_cubes=",cubes," book_slots=",nav.book_slots(library).size()," artifact_slots=",nav.artifact_slots(gallery).size())
	quit(0)
