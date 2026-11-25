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
	var home_count:=0
	for profile in world.read_resident_profiles():
		var id:String=str(profile["id"])
		var room:Dictionary=world.room_by_id(str(world.residents[id]["home_room_id"]))
		var node:Node3D=scene.room_root.get_node(str(room["id"]))
		assert(node.get_node_or_null("PrivateFrontWall")!=null)
		assert(node.get_node_or_null("PrivateFrontWall/DoorOwnerSign")!=null)
		assert(scene.door_note_anchors.has(str(room["id"])))
		assert(node.get_node_or_null("LocalFurniture")==null)
		assert(scene.open_door_note(str(room["id"])))
		assert(scene.door_note_panel.visible)
		assert(not world.public_cutaway_allowed(room))
		scene.close_door_note()
		home_count+=1
	assert(home_count==24)
	var gallery:Dictionary=world.get_room(1,1)
	assert(scene.artifact_cubes.object_to_source.size()==10)
	var placed:=0
	var slots:Dictionary={}
	for id in scene.artifact_cubes.object_to_source:
		var obj:Dictionary=world.physical_object(str(id))
		assert(not obj.is_empty(),str(id))
		var support_id:String=str(obj.get("home_support_id",""))
		assert(support_id!="" and not slots.has(support_id),str([id,support_id]))
		slots[support_id]=true
		var slot:Dictionary=scene.life.candidate_navigation.artifact_support(gallery,support_id)
		assert(not slot.is_empty())
		assert(scene.object_nodes[id].get_node_or_null("ArtifactShortLabel")!=null)
		assert(scene.object_nodes[id].get_node_or_null("Visual")==null)
		placed+=1
	assert(placed==10)
	var sphere_count:=0
	for id in world.creatures:
		var creature:Dictionary=world.creatures[id]
		if str(creature.get("bank_id","")).contains("sphere") and scene.creature_nodes.has(id):
			var node:Node3D=scene.creature_nodes[id]
			if node.visible:
				assert(node.position.y-float(creature["visual_y"])>=0.60)
			sphere_count+=1
	print("RC2_OWNER_CORRECTIONS_PASS doors=",home_count," actual_cubes=",placed," sphere_banks=",sphere_count)
	quit(0)
